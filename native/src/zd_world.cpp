#include "zd_world.h"

#include <chrono>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

namespace zd {

bool ZdWorld::set_trig(const PackedFloat32Array &cos_t, const PackedFloat32Array &sin_t) {
	return trig_.set(cos_t, sin_t);
}

void ZdWorld::set_walls(const PackedFloat32Array &obbs) {
	walls_.set(obbs);
}

void ZdWorld::set_solids(const PackedFloat32Array &obbs) {
	read_boxes(obbs, solids_);
}

int ZdWorld::set_kinds(const PackedInt32Array &ints, const PackedFloat32Array &floats,
		const PackedFloat32Array &tuning, int ki, int kf) {
	if (ki <= 0 || kf <= 0 || ints.size() % ki != 0 || floats.size() % kf != 0) {
		return -1;
	}
	const int64_t count = ints.size() / ki;
	if (floats.size() / kf != count) {
		return -1;
	}
	kinds_.ints.assign(ints.ptr(), ints.ptr() + ints.size());
	kinds_.floats.assign(floats.ptr(), floats.ptr() + floats.size());
	kinds_.tuning.assign(tuning.ptr(), tuning.ptr() + tuning.size());
	kinds_.ki = ki;
	kinds_.kf = kf;
	kinds_.count = int(count);
	return kinds_.count;
}

PackedFloat32Array ZdWorld::kind_row(int kind) const {
	PackedFloat32Array out;
	if (!kinds_.has(kind)) {
		return out;
	}
	out.resize(kinds_.ki + kinds_.kf);
	float *w = out.ptrw();
	const int32_t *ri = kinds_.row_i(kind);
	const float *rf = kinds_.row_f(kind);
	for (int k = 0; k < kinds_.ki; k++) {
		w[k] = float(ri[k]);
	}
	for (int k = 0; k < kinds_.kf; k++) {
		w[kinds_.ki + k] = rf[k];
	}
	return out;
}

void ZdWorld::set_nav_grid(Vector2 origin, Vector2i size, float cell, const PackedByteArray &blocked,
		const PackedInt32Array &adj_start, const PackedInt32Array &adj, const PackedByteArray &adj_w) {
	nav_.ox = origin.x;
	nav_.oy = origin.y;
	nav_.cell = cell;
	nav_.w = size.x;
	nav_.h = size.y;
	nav_.blocked.assign(blocked.ptr(), blocked.ptr() + blocked.size());
	nav_.adj_start.assign(adj_start.ptr(), adj_start.ptr() + adj_start.size());
	nav_.adj.assign(adj.ptr(), adj.ptr() + adj.size());
	nav_.adj_w.assign(adj_w.ptr(), adj_w.ptr() + adj_w.size());
	nav_.dist.assign(size_t(std::max(0, size.x * size.y)), 1 << 30); // NavField.UNREACHED until a flood
	nav_.ready = size.x > 0 && size.y > 0;
}

void ZdWorld::set_nav_dist(const PackedInt32Array &dist) {
	nav_.dist.assign(dist.ptr(), dist.ptr() + dist.size());
}

PackedInt32Array ZdWorld::rows_for_script(const Object *actors) const {
	PackedInt32Array out;
	const PackedInt32Array kinds = cols::i32(actors, names_.kinds);
	const PackedInt32Array state = cols::i32(actors, names_.state);
	const int64_t n = kinds.size();
	if (state.size() != n) {
		return out;
	}
	const int egg = kinds_.tuning.size() > size_t(KindTable::T_EGG_STATE)
			? int(kinds_.tuning[size_t(KindTable::T_EGG_STATE)])
			: 1 << 30;
	const int32_t *k = kinds.ptr();
	const int32_t *s = state.ptr();
	for (int64_t i = 1; i < n; i++) {
		if (kinds_.mode(k[i]) == KindTable::MODE_SCRIPT || s[i] >= egg) {
			out.push_back(int32_t(i));
		}
	}
	return out;
}

PackedFloat32Array ZdWorld::dir_of(const PackedInt32Array &angles) const {
	PackedFloat32Array out;
	out.resize(angles.size() * 2);
	float *w = out.ptrw();
	for (int64_t i = 0; i < angles.size(); i++) {
		trig_.dir(angles[i], w[i * 2], w[i * 2 + 1]);
	}
	return out;
}

PackedInt32Array ZdWorld::angles_of(const PackedFloat32Array &xy) const {
	PackedInt32Array out;
	out.resize(xy.size() / 2);
	int32_t *w = out.ptrw();
	for (int64_t i = 0; i < xy.size() / 2; i++) {
		w[i] = trig_.angle_of(xy[i * 2], xy[i * 2 + 1]);
	}
	return out;
}

PackedInt32Array ZdWorld::turns_toward(const PackedInt32Array &from_to_step) const {
	PackedInt32Array out;
	out.resize(from_to_step.size() / 3);
	int32_t *w = out.ptrw();
	for (int64_t i = 0; i < from_to_step.size() / 3; i++) {
		w[i] = turn_toward(from_to_step[i * 3], from_to_step[i * 3 + 1], from_to_step[i * 3 + 2]);
	}
	return out;
}

PackedInt64Array ZdWorld::bench_columns(Object *store, const PackedStringArray &names, int reps, bool write) {
	PackedInt64Array out;
	out.resize(2);
	out.fill(0);
	if (store == nullptr) {
		return out;
	}
	std::vector<StringName> keys;
	for (int64_t k = 0; k < names.size(); k++) {
		keys.push_back(StringName(names[k]));
	}
	std::vector<Variant> got(keys.size());
	int64_t read_ns = 0, write_ns = 0;
	for (int r = 0; r < reps; r++) {
		const auto t0 = std::chrono::steady_clock::now();
		for (size_t k = 0; k < keys.size(); k++) {
			got[k] = store->get(keys[k]);
		}
		const auto t1 = std::chrono::steady_clock::now();
		read_ns += std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count();
		if (!write) {
			continue;
		}
		for (size_t k = 0; k < keys.size(); k++) {
			switch (got[k].get_type()) {
				case Variant::PACKED_FLOAT32_ARRAY: {
					const PackedFloat32Array a = got[k];
					cols::put_f32(store, keys[k], a.ptr(), a.size());
				} break;
				case Variant::PACKED_INT32_ARRAY: {
					const PackedInt32Array a = got[k];
					cols::put_i32(store, keys[k], a.ptr(), a.size());
				} break;
				case Variant::PACKED_BYTE_ARRAY: {
					const PackedByteArray a = got[k];
					cols::put_u8(store, keys[k], a.ptr(), a.size());
				} break;
				default:
					break;
			}
		}
		const auto t2 = std::chrono::steady_clock::now();
		write_ns += std::chrono::duration_cast<std::chrono::nanoseconds>(t2 - t1).count();
	}
	out.set(0, read_ns);
	out.set(1, write_ns);
	return out;
}

void ZdWorld::_bind_methods() {
	// Setup
	ClassDB::bind_method(D_METHOD("set_trig", "cos_t", "sin_t"), &ZdWorld::set_trig);
	ClassDB::bind_method(D_METHOD("has_trig"), &ZdWorld::has_trig);
	ClassDB::bind_method(D_METHOD("set_walls", "obbs"), &ZdWorld::set_walls);
	ClassDB::bind_method(D_METHOD("set_solids", "obbs"), &ZdWorld::set_solids);
	ClassDB::bind_method(D_METHOD("wall_count"), &ZdWorld::wall_count);
	ClassDB::bind_method(D_METHOD("set_kinds", "ints", "floats", "tuning", "ki", "kf"), &ZdWorld::set_kinds);
	ClassDB::bind_method(D_METHOD("kind_count"), &ZdWorld::kind_count);
	ClassDB::bind_method(D_METHOD("kind_row", "kind"), &ZdWorld::kind_row);
	ClassDB::bind_method(D_METHOD("set_nav_grid", "origin", "size", "cell", "blocked", "adj_start", "adj", "adj_w"),
			&ZdWorld::set_nav_grid);
	ClassDB::bind_method(D_METHOD("set_nav_dist", "dist"), &ZdWorld::set_nav_dist);
	ClassDB::bind_method(D_METHOD("has_nav"), &ZdWorld::has_nav);
	ClassDB::bind_method(D_METHOD("rows_for_script", "actors"), &ZdWorld::rows_for_script);
	// Probes
	ClassDB::bind_method(D_METHOD("dir_of", "angles"), &ZdWorld::dir_of);
	ClassDB::bind_method(D_METHOD("angles_of", "xy"), &ZdWorld::angles_of);
	ClassDB::bind_method(D_METHOD("turns_toward", "from_to_step"), &ZdWorld::turns_toward);
	ClassDB::bind_method(D_METHOD("bench_columns", "store", "names", "reps", "write"), &ZdWorld::bench_columns);

	// ---- KERNEL BINDINGS ----
	// Collision (zd_collide.cpp)
	ClassDB::bind_method(D_METHOD("resolve", "px", "py", "rad", "through", "heavy", "ghost0", "iters"),
			&ZdWorld::resolve);
	ClassDB::bind_method(D_METHOD("resolve_actors", "actors", "through", "heavy", "ghost0", "iters"),
			&ZdWorld::resolve_actors);
	ClassDB::bind_method(D_METHOD("get_x"), &ZdWorld::get_x);
	ClassDB::bind_method(D_METHOD("get_y"), &ZdWorld::get_y);
	ClassDB::bind_method(D_METHOD("bench_pairs", "px", "py", "rad", "reps"), &ZdWorld::bench_pairs);
	ClassDB::bind_method(D_METHOD("touch", "px", "py", "rad"), &ZdWorld::touch);
	ClassDB::bind_method(D_METHOD("determinism_probe"), &ZdWorld::determinism_probe);

	// slot: ai

	// slot: nav

	// slot: shots

	// slot: strike
	// ---- end KERNEL BINDINGS ----
}

} // namespace zd
