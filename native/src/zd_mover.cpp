#include "zd_mover.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace zd {

namespace {

constexpr float NO_HIT = -1.0f;

inline float clampf(float v, float lo, float hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

// Collide.circle_vs_obb: the push that moves a circle at (px, py) of radius r out of the box (zero when apart).
inline void circle_vs_obb(float px, float py, float r, const Box &b, float &ox, float &oy) {
	const float dx = px - b.cx;
	const float dy = py - b.cy;
	const float lx = dx * b.ux + dy * b.uy;
	const float ly = dx * b.vx + dy * b.vy;
	const float cx = clampf(lx, -b.hx, b.hx);
	const float cy = clampf(ly, -b.hy, b.hy);
	if (cx == lx && cy == ly) {
		// Centre inside the box: leave through the nearest face.
		const float fx = b.hx - std::fabs(lx) + r;
		const float fy = b.hy - std::fabs(ly) + r;
		if (fx < fy) {
			const float s = lx >= 0.0f ? fx : -fx;
			ox = b.ux * s;
			oy = b.uy * s;
		} else {
			const float s = ly >= 0.0f ? fy : -fy;
			ox = b.vx * s;
			oy = b.vy * s;
		}
		return;
	}
	const float qx = lx - cx;
	const float qy = ly - cy;
	const float d2 = qx * qx + qy * qy;
	if (d2 >= r * r) {
		ox = 0.0f;
		oy = 0.0f;
		return;
	}
	const float dist = std::sqrt(d2);
	const float k = (r - dist) / dist;
	ox = b.ux * (qx * k) + b.vx * (qy * k);
	oy = b.uy * (qx * k) + b.vy * (qy * k);
}

// Collide.sweep_vs_obb: the first t in [0, 1] where the segment a..b thickened by r touches the box; NO_HIT otherwise.
inline float sweep_vs_obb(float ax, float ay, float bx, float by, float r, const Box &box) {
	const float dax = ax - box.cx, day = ay - box.cy;
	const float dbx = bx - box.cx, dby = by - box.cy;
	const float la[2] = { dax * box.ux + day * box.uy, dax * box.vx + day * box.vy };
	const float lb[2] = { dbx * box.ux + dby * box.uy, dbx * box.vx + dby * box.vy };
	const float h[2] = { box.hx + r, box.hy + r };
	float t0 = 0.0f, t1 = 1.0f;
	for (int axis = 0; axis < 2; axis++) {
		const float p = la[axis];
		const float dd = lb[axis] - la[axis];
		if (dd == 0.0f) {
			if (p < -h[axis] || p > h[axis]) {
				return NO_HIT;
			}
			continue;
		}
		float ta = (-h[axis] - p) / dd;
		float tb = (h[axis] - p) / dd;
		if (ta > tb) {
			std::swap(ta, tb);
		}
		t0 = std::max(t0, ta);
		t1 = std::min(t1, tb);
		if (t0 > t1) {
			return NO_HIT;
		}
	}
	return t0;
}

} // namespace

void ZdMover::read_boxes(const PackedFloat32Array &obbs, std::vector<Box> &out) {
	out.clear();
	const float *s = obbs.ptr();
	const int64_t n = obbs.size() / 8;
	out.reserve(size_t(n));
	for (int64_t i = 0; i < n; i++) {
		const float *o = s + i * 8;
		Box b{ o[0], o[1], o[2], o[3], o[4], o[5], o[6], o[7], 0, 0, 0, 0 };
		const float ex = std::fabs(b.ux) * b.hx + std::fabs(b.vx) * b.hy;
		const float ey = std::fabs(b.uy) * b.hx + std::fabs(b.vy) * b.hy;
		b.x0 = b.cx - ex;
		b.x1 = b.cx + ex;
		b.y0 = b.cy - ey;
		b.y1 = b.cy + ey;
		out.push_back(b);
	}
}

void ZdMover::set_walls(const PackedFloat32Array &obbs) {
	read_boxes(obbs, walls_);
	wall_stamp_.assign(walls_.size(), 0u);
	wall_query_ = 0;
	wg_w_ = wg_h_ = 0;
	wg_start_.clear();
	wg_items_.clear();
	if (walls_.empty()) {
		return;
	}
	float x0 = walls_[0].x0, y0 = walls_[0].y0, x1 = walls_[0].x1, y1 = walls_[0].y1;
	for (const Box &b : walls_) {
		x0 = std::min(x0, b.x0);
		y0 = std::min(y0, b.y0);
		x1 = std::max(x1, b.x1);
		y1 = std::max(y1, b.y1);
	}
	wg_cell_ = WALL_CELL;
	while ((x1 - x0) / wg_cell_ + 1.0f > float(MAX_SIDE) || (y1 - y0) / wg_cell_ + 1.0f > float(MAX_SIDE)) {
		wg_cell_ *= 2.0f;
	}
	wg_ox_ = x0;
	wg_oy_ = y0;
	wg_w_ = int((x1 - x0) / wg_cell_) + 1;
	wg_h_ = int((y1 - y0) / wg_cell_) + 1;
	const int cells = wg_w_ * wg_h_;
	std::vector<int> count(size_t(cells) + 1, 0);
	auto span = [&](const Box &b, int &c0, int &r0, int &c1, int &r1) {
		c0 = std::clamp(int((b.x0 - wg_ox_) / wg_cell_), 0, wg_w_ - 1);
		c1 = std::clamp(int((b.x1 - wg_ox_) / wg_cell_), 0, wg_w_ - 1);
		r0 = std::clamp(int((b.y0 - wg_oy_) / wg_cell_), 0, wg_h_ - 1);
		r1 = std::clamp(int((b.y1 - wg_oy_) / wg_cell_), 0, wg_h_ - 1);
	};
	for (const Box &b : walls_) {
		int c0, r0, c1, r1;
		span(b, c0, r0, c1, r1);
		for (int r = r0; r <= r1; r++) {
			for (int c = c0; c <= c1; c++) {
				count[size_t(r * wg_w_ + c)]++;
			}
		}
	}
	wg_start_.assign(size_t(cells) + 1, 0);
	for (int i = 0; i < cells; i++) {
		wg_start_[size_t(i) + 1] = wg_start_[size_t(i)] + count[size_t(i)];
	}
	wg_items_.assign(size_t(wg_start_[size_t(cells)]), 0);
	std::vector<int> fill(wg_start_.begin(), wg_start_.end() - 1);
	for (int w = 0; w < int(walls_.size()); w++) {
		int c0, r0, c1, r1;
		span(walls_[size_t(w)], c0, r0, c1, r1);
		for (int r = r0; r <= r1; r++) {
			for (int c = c0; c <= c1; c++) {
				wg_items_[size_t(fill[size_t(r * wg_w_ + c)]++)] = w;
			}
		}
	}
}

void ZdMover::set_solids(const PackedFloat32Array &obbs) {
	read_boxes(obbs, solids_);
}

// Calls f for each wall whose bounds overlap the box (each once, in the grid's order).
template <typename F>
void ZdMover::walls_in(float x0, float y0, float x1, float y1, F &&f) {
	if (wg_w_ == 0) {
		return;
	}
	const int c0 = std::clamp(int(std::floor((x0 - wg_ox_) / wg_cell_)), 0, wg_w_ - 1);
	const int c1 = std::clamp(int(std::floor((x1 - wg_ox_) / wg_cell_)), 0, wg_w_ - 1);
	const int r0 = std::clamp(int(std::floor((y0 - wg_oy_) / wg_cell_)), 0, wg_h_ - 1);
	const int r1 = std::clamp(int(std::floor((y1 - wg_oy_) / wg_cell_)), 0, wg_h_ - 1);
	if (++wall_query_ == 0) {
		std::fill(wall_stamp_.begin(), wall_stamp_.end(), 0u);
		wall_query_ = 1;
	}
	for (int r = r0; r <= r1; r++) {
		for (int c = c0; c <= c1; c++) {
			const int cell = r * wg_w_ + c;
			for (int k = wg_start_[size_t(cell)]; k < wg_start_[size_t(cell) + 1]; k++) {
				const int w = wg_items_[size_t(k)];
				if (wall_stamp_[size_t(w)] == wall_query_) {
					continue;
				}
				wall_stamp_[size_t(w)] = wall_query_;
				const Box &b = walls_[size_t(w)];
				if (b.x1 < x0 || b.x0 > x1 || b.y1 < y0 || b.y0 > y1) {
					continue;
				}
				f(b);
			}
		}
	}
}

void ZdMover::load_columns(const PackedFloat32Array &px, const PackedFloat32Array &py, const PackedFloat32Array &rad) {
	const size_t n = size_t(px.size());
	x_.assign(px.ptr(), px.ptr() + n);
	y_.assign(py.ptr(), py.ptr() + n);
	r_.assign(rad.ptr(), rad.ptr() + n);
}

void ZdMover::wall_pass() {
	const int n = int(x_.size());
	for (int i = 0; i < n; i++) {
		if (has_flags_ && through_[size_t(i)] == 1) {
			continue;
		}
		float ax = x_[size_t(i)];
		float ay = y_[size_t(i)];
		const float r = r_[size_t(i)];
		walls_in(ax - r, ay - r, ax + r, ay + r, [&](const Box &b) {
			float ox, oy;
			circle_vs_obb(ax, ay, r, b, ox, oy);
			ax += ox;
			ay += oy;
		});
		if (!solids_.empty()) {
			// Solids.push: the sum over the footprints the circle overlaps, each tested from the running sum.
			float sx = 0.0f, sy = 0.0f;
			for (const Box &b : solids_) {
				const float reach = r + std::sqrt(b.hx * b.hx + b.hy * b.hy);
				if (std::fabs(ax - b.cx) <= reach && std::fabs(ay - b.cy) <= reach) {
					float ox, oy;
					circle_vs_obb(ax + sx, ay + sy, r, b, ox, oy);
					sx += ox;
					sy += oy;
				}
			}
			ax += sx;
			ay += sy;
		}
		x_[size_t(i)] = ax;
		y_[size_t(i)] = ay;
	}
}

void ZdMover::build_pair_grid() {
	const int n = int(x_.size());
	big_.clear();
	ag_cell_of_.assign(size_t(n), -1);
	float rmax = 0.0f;
	float x0 = 0.0f, y0 = 0.0f, x1 = 0.0f, y1 = 0.0f;
	bool any = false;
	for (int i = 0; i < n; i++) {
		const float r = r_[size_t(i)];
		if (r > BIG_R) {
			big_.push_back(i);
			continue;
		}
		rmax = std::max(rmax, r);
		const float x = x_[size_t(i)], y = y_[size_t(i)];
		if (!any) {
			x0 = x1 = x;
			y0 = y1 = y;
			any = true;
		} else {
			x0 = std::min(x0, x);
			x1 = std::max(x1, x);
			y0 = std::min(y0, y);
			y1 = std::max(y1, y);
		}
	}
	// Two small bodies touch only within 2 * rmax of each other: the 3x3 cells around a body hold all it can touch.
	ag_cell_ = std::max(2.0f * rmax, 0.25f);
	while ((x1 - x0) / ag_cell_ + 1.0f > 512.0f || (y1 - y0) / ag_cell_ + 1.0f > 512.0f) {
		ag_cell_ *= 2.0f;
	}
	ag_ox_ = x0;
	ag_oy_ = y0;
	ag_w_ = any ? int((x1 - x0) / ag_cell_) + 1 : 1;
	ag_h_ = any ? int((y1 - y0) / ag_cell_) + 1 : 1;
	const int cells = ag_w_ * ag_h_;
	ag_start_.assign(size_t(cells) + 1, 0);
	for (int i = 0; i < n; i++) {
		if (r_[size_t(i)] > BIG_R) {
			continue;
		}
		const int c = std::min(int((x_[size_t(i)] - ag_ox_) / ag_cell_), ag_w_ - 1);
		const int r = std::min(int((y_[size_t(i)] - ag_oy_) / ag_cell_), ag_h_ - 1);
		const int cell = r * ag_w_ + c;
		ag_cell_of_[size_t(i)] = cell;
		ag_start_[size_t(cell) + 1]++;
	}
	for (int i = 0; i < cells; i++) {
		ag_start_[size_t(i) + 1] += ag_start_[size_t(i)];
	}
	ag_items_.assign(size_t(ag_start_[size_t(cells)]), 0);
	ag_fill_.assign(ag_start_.begin(), ag_start_.end() - 1);
	for (int i = 0; i < n; i++) {
		const int cell = ag_cell_of_[size_t(i)];
		if (cell >= 0) {
			ag_items_[size_t(ag_fill_[size_t(cell)]++)] = i;
		}
	}
}

void ZdMover::shove(int i, float dx, float dy) {
	const float ax = x_[size_t(i)], ay = y_[size_t(i)];
	const float bx = ax + dx, by = ay + dy;
	const float r = r_[size_t(i)];
	float t = 1.0f;
	walls_in(std::min(ax, bx) - r, std::min(ay, by) - r, std::max(ax, bx) + r, std::max(ay, by) + r,
			[&](const Box &b) {
				const float hit = sweep_vs_obb(ax, ay, bx, by, r, b);
				if (hit >= 0.0f && hit < t) {
					t = hit;
				}
			});
	x_[size_t(i)] = ax + dx * t;
	y_[size_t(i)] = ay + dy * t;
}

inline void ZdMover::pair(int a, int b, int &pushes) {
	const float ra = r_[size_t(a)], rb = r_[size_t(b)];
	const float dx = x_[size_t(a)] - x_[size_t(b)];
	const float dy = y_[size_t(a)] - y_[size_t(b)];
	const float rr = ra + rb;
	const float d2 = dx * dx + dy * dy;
	if (d2 >= rr * rr) {
		return;
	}
	float pxv = rr * 0.5f, pyv = 0.0f;  // Coincident centres part along x.
	if (d2 != 0.0f) {
		const float dist = std::sqrt(d2);
		const float k = (rr - dist) * 0.5f / dist;
		pxv = dx * k;
		pyv = dy * k;
	}
	if (has_flags_) {
		if (through_[size_t(a)] == 1 || through_[size_t(b)] == 1) {
			return;
		}
		if (heavy_[size_t(a)] != heavy_[size_t(b)]) {
			if (heavy_[size_t(a)] == 1) {
				shove(b, -pxv * 2.0f, -pyv * 2.0f);
			} else {
				shove(a, pxv * 2.0f, pyv * 2.0f);
			}
			pushes++;
			return;
		}
	}
	x_[size_t(a)] += pxv;
	y_[size_t(a)] += pyv;
	x_[size_t(b)] -= pxv;
	y_[size_t(b)] -= pyv;
	pushes++;
}

int ZdMover::pair_pass(bool ghost0) {
	const int n = int(x_.size());
	int pushes = 0;
	for (int a = 0; a < n; a++) {
		if (ghost0 && a == 0) {
			continue;
		}
		if (r_[size_t(a)] > BIG_R) {
			for (int b = a + 1; b < n; b++) {
				pair(a, b, pushes);
			}
			continue;
		}
		const int cell = ag_cell_of_[size_t(a)];
		const int cx = cell % ag_w_;
		const int cy = cell / ag_w_;
		for (int r = std::max(cy - 1, 0); r <= std::min(cy + 1, ag_h_ - 1); r++) {
			for (int c = std::max(cx - 1, 0); c <= std::min(cx + 1, ag_w_ - 1); c++) {
				const int k1 = ag_start_[size_t(r * ag_w_ + c) + 1];
				for (int k = ag_start_[size_t(r * ag_w_ + c)]; k < k1; k++) {
					const int b = ag_items_[size_t(k)];
					if (b > a) {
						pair(a, b, pushes);
					}
				}
			}
		}
		for (int b : big_) {
			if (b > a) {
				pair(a, b, pushes);
			}
		}
	}
	return pushes;
}

int ZdMover::resolve(const PackedFloat32Array &px, const PackedFloat32Array &py, const PackedFloat32Array &rad,
		const PackedInt32Array &through, const PackedInt32Array &heavy, bool ghost0, int iters) {
	load_columns(px, py, rad);
	const size_t n = x_.size();
	has_flags_ = !through.is_empty();
	if (has_flags_) {
		through_.assign(through.ptr(), through.ptr() + n);
		heavy_.assign(heavy.ptr(), heavy.ptr() + n);
	}
	int pushes = 0;
	for (int it = 0; it < iters; it++) {
		wall_pass();
		build_pair_grid();
		pushes += pair_pass(ghost0);
	}
	out_x_.resize(int64_t(n));
	out_y_.resize(int64_t(n));
	std::copy(x_.begin(), x_.end(), out_x_.ptrw());
	std::copy(y_.begin(), y_.end(), out_y_.ptrw());
	return pushes;
}

int64_t ZdMover::bench_pairs(const PackedFloat32Array &px, const PackedFloat32Array &py, const PackedFloat32Array &rad,
		int reps) {
	has_flags_ = false;
	int64_t ns = 0;
	int sink = 0;
	for (int i = 0; i < reps; i++) {
		load_columns(px, py, rad);
		const auto t0 = std::chrono::steady_clock::now();
		build_pair_grid();
		sink += pair_pass(false);
		const auto t1 = std::chrono::steady_clock::now();
		ns += std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count();
	}
	return sink < 0 ? -1 : ns;
}

int ZdMover::touch(const PackedFloat32Array &px, const PackedFloat32Array &py, const PackedFloat32Array &rad) const {
	return int(px.size() + py.size() + rad.size());
}

String ZdMover::determinism_probe() {
	// A fixed scene from an integer generator: every input float is an exact integer divided by a power of ten or
	// a correctly rounded sqrt, so it is the same bits on every compiler before the first pass runs.
	uint32_t seed = 12345u;
	auto next = [&seed](uint32_t mod) {
		seed = seed * 1664525u + 1013904223u;
		return int((seed >> 8) % mod);
	};
	auto boxes = [&next](int count) {
		PackedFloat32Array out;
		out.resize(int64_t(count) * 8);
		float *w = out.ptrw();
		for (int k = 0; k < count; k++) {
			const float a = float(1 + next(7));
			const float b = float(next(7) - 3);
			const float len = std::sqrt(a * a + b * b);
			const float ux = a / len, uy = b / len;
			const float vals[8] = { float(next(3601) - 1800) / 100.0f, float(next(3601) - 1800) / 100.0f, ux, uy, -uy,
				ux, 0.5f + float(next(30)) / 10.0f, 0.25f + float(next(10)) / 10.0f };
			std::copy(vals, vals + 8, w + k * 8);
		}
		return out;
	};
	set_walls(boxes(16));
	set_solids(boxes(3));

	constexpr int N = 240;
	PackedFloat32Array px, py, rad;
	PackedInt32Array through, heavy;
	px.resize(N);
	py.resize(N);
	rad.resize(N);
	through.resize(N);
	heavy.resize(N);
	for (int i = 0; i < N; i++) {
		px.set(i, float(next(4001) - 2000) / 100.0f);
		py.set(i, float(next(4001) - 2000) / 100.0f);
		rad.set(i, i % 40 == 39 ? 1.25f : 0.25f + float(next(50)) / 100.0f);
		through.set(i, i % 17 == 16 ? 1 : 0);
		heavy.set(i, i % 23 == 22 ? 1 : 0);
	}

	// 60 ticks of three passes each; between ticks every body steps 1/32 of the way to the centre.
	uint64_t h = 14695981039346656037ull; // FNV-1a, 64 bits, over the float bits
	auto mix = [&h](uint32_t v) {
		for (int s = 0; s < 32; s += 8) {
			h = (h ^ ((v >> s) & 0xffu)) * 1099511628211ull;
		}
	};
	for (int t = 0; t < 60; t++) {
		mix(uint32_t(resolve(px, py, rad, through, heavy, t % 2 == 0, 3)));
		const float *ox = out_x_.ptr();
		const float *oy = out_y_.ptr();
		for (int i = 0; i < N; i++) {
			uint32_t bx, by;
			std::memcpy(&bx, ox + i, 4);
			std::memcpy(&by, oy + i, 4);
			mix(bx);
			mix(by);
			px.set(i, ox[i] - ox[i] * 0.03125f);
			py.set(i, oy[i] - oy[i] * 0.03125f);
		}
	}
	char hex[17];
	for (int k = 0; k < 16; k++) {
		hex[k] = "0123456789abcdef"[(h >> (60 - 4 * k)) & 0xfu];
	}
	hex[16] = '\0';
	return String(hex);
}

void ZdMover::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_walls", "obbs"), &ZdMover::set_walls);
	ClassDB::bind_method(D_METHOD("set_solids", "obbs"), &ZdMover::set_solids);
	ClassDB::bind_method(D_METHOD("wall_count"), &ZdMover::wall_count);
	ClassDB::bind_method(D_METHOD("resolve", "px", "py", "rad", "through", "heavy", "ghost0", "iters"),
			&ZdMover::resolve);
	ClassDB::bind_method(D_METHOD("get_x"), &ZdMover::get_x);
	ClassDB::bind_method(D_METHOD("get_y"), &ZdMover::get_y);
	ClassDB::bind_method(D_METHOD("bench_pairs", "px", "py", "rad", "reps"), &ZdMover::bench_pairs);
	ClassDB::bind_method(D_METHOD("touch", "px", "py", "rad"), &ZdMover::touch);
	ClassDB::bind_method(D_METHOD("determinism_probe"), &ZdMover::determinism_probe);
}

} // namespace zd
