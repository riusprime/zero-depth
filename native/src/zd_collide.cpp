#include "zd_collide.h"

#include <chrono>
#include <cstring>

#include "zd_world.h"

using namespace godot;

namespace zd {

void CollideScratch::load(const float *px, const float *py, const float *rad, size_t n) {
	x.assign(px, px + n);
	y.assign(py, py + n);
	r.assign(rad, rad + n);
}

int CollideScratch::run(WallGrid &walls, const std::vector<Box> &solids, bool ghost0, int iters) {
	int pushes = 0;
	for (int it = 0; it < iters; it++) {
		wall_pass(walls, solids);
		grid.build(x.data(), y.data(), r.data(), int(x.size()), BIG_R);
		pushes += pair_pass(walls, ghost0);
	}
	return pushes;
}

void CollideScratch::wall_pass(WallGrid &walls, const std::vector<Box> &solids) {
	const int n = int(x.size());
	for (int i = 0; i < n; i++) {
		if (has_flags && through[size_t(i)] == 1) {
			continue;
		}
		float ax = x[size_t(i)];
		float ay = y[size_t(i)];
		const float ri = r[size_t(i)];
		walls.walls_in(ax - ri, ay - ri, ax + ri, ay + ri, [&](const Box &b) {
			float ox, oy;
			circle_vs_obb(ax, ay, ri, b, ox, oy);
			ax += ox;
			ay += oy;
		});
		if (!solids.empty()) {
			// Solids.push: the sum over the footprints the circle overlaps, each tested from the running sum.
			float sx = 0.0f, sy = 0.0f;
			for (const Box &b : solids) {
				const float reach = ri + std::sqrt(b.hx * b.hx + b.hy * b.hy);
				if (std::fabs(ax - b.cx) <= reach && std::fabs(ay - b.cy) <= reach) {
					float ox, oy;
					circle_vs_obb(ax + sx, ay + sy, ri, b, ox, oy);
					sx += ox;
					sy += oy;
				}
			}
			ax += sx;
			ay += sy;
		}
		x[size_t(i)] = ax;
		y[size_t(i)] = ay;
	}
}

void CollideScratch::shove(WallGrid &walls, int i, float dx, float dy) {
	const float ax = x[size_t(i)], ay = y[size_t(i)];
	const float t = walls.first_hit(ax, ay, ax + dx, ay + dy, r[size_t(i)]);
	x[size_t(i)] = ax + dx * t;
	y[size_t(i)] = ay + dy * t;
}

inline void CollideScratch::pair(WallGrid &walls, int a, int b, int &pushes) {
	const float ra = r[size_t(a)], rb = r[size_t(b)];
	const float dx = x[size_t(a)] - x[size_t(b)];
	const float dy = y[size_t(a)] - y[size_t(b)];
	const float rr = ra + rb;
	const float d2 = dx * dx + dy * dy;
	if (d2 >= rr * rr) {
		return;
	}
	float pxv = rr * 0.5f, pyv = 0.0f; // Coincident centres part along x.
	if (d2 != 0.0f) {
		const float dist = std::sqrt(d2);
		const float k = (rr - dist) * 0.5f / dist;
		pxv = dx * k;
		pyv = dy * k;
	}
	if (has_flags) {
		if (through[size_t(a)] == 1 || through[size_t(b)] == 1) {
			return;
		}
		if (heavy[size_t(a)] != heavy[size_t(b)]) {
			if (heavy[size_t(a)] == 1) {
				shove(walls, b, -pxv * 2.0f, -pyv * 2.0f);
			} else {
				shove(walls, a, pxv * 2.0f, pyv * 2.0f);
			}
			pushes++;
			return;
		}
	}
	x[size_t(a)] += pxv;
	y[size_t(a)] += pyv;
	x[size_t(b)] -= pxv;
	y[size_t(b)] -= pyv;
	pushes++;
}

int CollideScratch::pair_pass(WallGrid &walls, bool ghost0) {
	const int n = int(x.size());
	const BodyGrid &g = grid;
	int pushes = 0;
	for (int a = 0; a < n; a++) {
		if (ghost0 && a == 0) {
			continue;
		}
		if (r[size_t(a)] > BIG_R) {
			for (int b = a + 1; b < n; b++) {
				pair(walls, a, b, pushes);
			}
			continue;
		}
		const int cell = g.cell_of[size_t(a)];
		const int cx = cell % g.w;
		const int cy = cell / g.w;
		for (int rr = std::max(cy - 1, 0); rr <= std::min(cy + 1, g.h - 1); rr++) {
			for (int c = std::max(cx - 1, 0); c <= std::min(cx + 1, g.w - 1); c++) {
				const int k1 = g.start[size_t(rr * g.w + c) + 1];
				for (int k = g.start[size_t(rr * g.w + c)]; k < k1; k++) {
					const int b = g.items[size_t(k)];
					if (b > a) {
						pair(walls, a, b, pushes);
					}
				}
			}
		}
		for (int b : g.big) {
			if (b > a) {
				pair(walls, a, b, pushes);
			}
		}
	}
	return pushes;
}

int ZdWorld::resolve(const PackedFloat32Array &px, const PackedFloat32Array &py, const PackedFloat32Array &rad,
		const PackedInt32Array &through, const PackedInt32Array &heavy, bool ghost0, int iters) {
	CollideScratch &s = collide_;
	const size_t n = size_t(px.size());
	s.load(px.ptr(), py.ptr(), rad.ptr(), n);
	s.has_flags = !through.is_empty();
	if (s.has_flags) {
		s.through.assign(through.ptr(), through.ptr() + n);
		s.heavy.assign(heavy.ptr(), heavy.ptr() + n);
	}
	const int pushes = s.run(walls_, solids_, ghost0, iters);
	out_x_.resize(int64_t(n));
	out_y_.resize(int64_t(n));
	std::copy(s.x.begin(), s.x.end(), out_x_.ptrw());
	std::copy(s.y.begin(), s.y.end(), out_y_.ptrw());
	return pushes;
}

int ZdWorld::resolve_actors(Object *actors, const PackedInt32Array &through, const PackedInt32Array &heavy,
		bool ghost0, int iters) {
	CollideScratch &s = collide_;
	const PackedFloat32Array px = cols::f32(actors, names_.pos_x);
	const PackedFloat32Array py = cols::f32(actors, names_.pos_y);
	const PackedFloat32Array rad = cols::f32(actors, names_.radius);
	const size_t n = size_t(px.size());
	if (size_t(py.size()) != n || size_t(rad.size()) != n) {
		return -1;
	}
	s.load(px.ptr(), py.ptr(), rad.ptr(), n);
	s.has_flags = !through.is_empty();
	if (s.has_flags) {
		s.through.assign(through.ptr(), through.ptr() + n);
		s.heavy.assign(heavy.ptr(), heavy.ptr() + n);
	}
	const int pushes = s.run(walls_, solids_, ghost0, iters);
	cols::put_f32(actors, names_.pos_x, s.x);
	cols::put_f32(actors, names_.pos_y, s.y);
	return pushes;
}

int64_t ZdWorld::bench_pairs(const PackedFloat32Array &px, const PackedFloat32Array &py, const PackedFloat32Array &rad,
		int reps) {
	CollideScratch &s = collide_;
	s.has_flags = false;
	int64_t ns = 0;
	int sink = 0;
	for (int i = 0; i < reps; i++) {
		s.load(px.ptr(), py.ptr(), rad.ptr(), size_t(px.size()));
		const auto t0 = std::chrono::steady_clock::now();
		s.grid.build(s.x.data(), s.y.data(), s.r.data(), int(s.x.size()), CollideScratch::BIG_R);
		sink += s.pair_pass(walls_, false);
		const auto t1 = std::chrono::steady_clock::now();
		ns += std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count();
	}
	return sink < 0 ? -1 : ns;
}

int ZdWorld::touch(const PackedFloat32Array &px, const PackedFloat32Array &py, const PackedFloat32Array &rad) const {
	return int(px.size() + py.size() + rad.size());
}

String ZdWorld::determinism_probe() {
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

} // namespace zd
