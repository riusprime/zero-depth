#pragma once
// The shared geometry every kernel uses: the oriented box and its circle and sweep tests (Collide), the wall grid,
// the body grid (a counting sort of bodies by cell), and the sim's direction tables (Kin). Every function here
// follows native/README.md's float rules: single-precision values, + - * / and sqrt only, no library trigonometry.

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

#include <godot_cpp/variant/packed_float32_array.hpp>

namespace zd {

constexpr float NO_HIT = -1.0f;

// An oriented box as the sim holds it (Obb): centre, axes, half-extents, plus its axis-aligned bounds.
struct Box {
	float cx, cy, ux, uy, vx, vy, hx, hy;
	float x0, y0, x1, y1;
};

// Boxes sent as 8 floats each (cx, cy, ux, uy, vx, vy, hx, hy; NativeMove.obb_floats), with their bounds.
void read_boxes(const godot::PackedFloat32Array &obbs, std::vector<Box> &out);

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

// The walls and a grid over them: every wall listed in each cell its bounds cover. Rebuilt only when the walls
// change (World._wall_rev); between calls it holds nothing but what the walls give.
struct WallGrid {
	static constexpr float CELL = 2.0f;
	static constexpr int MAX_SIDE = 256;

	std::vector<Box> boxes;
	float ox = 0.0f, oy = 0.0f, cell = CELL;
	int w = 0, h = 0;
	std::vector<int> start, items;
	// A query's stamp per wall, so a wall listed in several cells is visited once.
	std::vector<uint32_t> stamp;
	uint32_t query = 0;

	void set(const godot::PackedFloat32Array &obbs);

	// Calls f(box) for each wall whose bounds overlap the rectangle (each once, in the grid's order).
	template <typename F>
	void walls_in(float x0, float y0, float x1, float y1, F &&f) {
		if (w == 0) {
			return;
		}
		const int c0 = std::clamp(int(std::floor((x0 - ox) / cell)), 0, w - 1);
		const int c1 = std::clamp(int(std::floor((x1 - ox) / cell)), 0, w - 1);
		const int r0 = std::clamp(int(std::floor((y0 - oy) / cell)), 0, h - 1);
		const int r1 = std::clamp(int(std::floor((y1 - oy) / cell)), 0, h - 1);
		if (++query == 0) {
			std::fill(stamp.begin(), stamp.end(), 0u);
			query = 1;
		}
		for (int r = r0; r <= r1; r++) {
			for (int c = c0; c <= c1; c++) {
				const int k1 = start[size_t(r * w + c) + 1];
				for (int k = start[size_t(r * w + c)]; k < k1; k++) {
					const int i = items[size_t(k)];
					if (stamp[size_t(i)] == query) {
						continue;
					}
					stamp[size_t(i)] = query;
					const Box &b = boxes[size_t(i)];
					if (b.x1 < x0 || b.x0 > x1 || b.y1 < y0 || b.y0 > y1) {
						continue;
					}
					f(b);
				}
			}
		}
	}

	// The first t in [0, 1] at which the segment thickened by r meets a wall; 1 when none (clear_run's rule).
	float first_hit(float ax, float ay, float bx, float by, float r);
};

// Bodies by the cell of their centre: a counting sort, so each cell lists its bodies in ascending index. Bodies
// larger than big_r stay out of the cells, in `big` (ascending). The cell is twice the largest small radius, so
// the 3x3 cells around a small body hold every small body it can touch. Rebuilt inside each call that needs it.
struct BodyGrid {
	float ox = 0.0f, oy = 0.0f, cell = 1.0f;
	int w = 0, h = 0;
	std::vector<int> start, items, cell_of, fill, big;

	void build(const float *x, const float *y, const float *r, int n, float big_r);
	// Every body whose centre's cell overlaps the rectangle, plus every big body, in ascending index (a superset
	// of the bodies whose centres lie inside it).
	void query_rect(float x0, float y0, float x1, float y1, std::vector<int> &out) const;
};

// The sim's direction tables (Kin, TrigLut): cos and sin of i/4096 turns for i in 0..512, sent once from GDScript
// (World.native_factory's world, NativeWorld.setup) so both sides read the same 513 floats.
struct Trig {
	static constexpr int SIZE = 513;
	float cos_t[SIZE] = {};
	float sin_t[SIZE] = {};
	bool ready = false;

	// False (and nothing changes) unless both tables hold SIZE entries.
	bool set(const godot::PackedFloat32Array &c, const godot::PackedFloat32Array &s);
	// Kin.dir: the unit vector of an angle in 1/4096 turns.
	void dir(int angle, float &x, float &y) const;
	// Kin.angle_of: the nearest angle of a vector, 0 for the zero vector. Its products and differences run in
	// double, as GDScript's floats do, so it gives Kin's answer exactly.
	int angle_of(float x, float y) const;
	int octant_index(double ax, double ay) const;
};

// Kin.angle_diff: the shortest absolute difference between two angles, 0..2048.
inline int angle_diff(int a, int b) {
	const int d = (a - b) & 4095;
	return d > 2048 ? 4096 - d : d;
}

// Kin.turn_toward: `from` turned toward `to` by at most `step`.
inline int turn_toward(int from, int to, int step) {
	int d = (to - from) & 4095;
	if (d > 2048) {
		d -= 4096;
	}
	return (from + std::clamp(d, -step, step)) & 4095;
}

// GDScript's posmod (C++ % truncates toward zero): the result has the sign of b.
inline int posmod(int a, int b) {
	const int m = a % b;
	return (m != 0 && ((m < 0) != (b < 0))) ? m + b : m;
}

// Kin.length: sqrt in double, as GDScript computes it.
inline double length(double x, double y) {
	return std::sqrt(x * x + y * y);
}

} // namespace zd
