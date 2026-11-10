#pragma once
// The move phase's collision kernel (World._resolve_bodies' rules): each pass pushes the bodies out of the walls
// and the standing solids, then parts overlapping bodies, half to each. A body flagged `through` is skipped by both;
// a heavy body against a light one shoves the light one the whole way, stopped at the first wall on the way.
// Deterministic against itself: fixed iteration order, single-precision floats, no threads. Not bit-for-bit the
// GDScript passes: its own grid, and the pairs are visited in its grid's order.
// ZdWorld's methods resolve, resolve_actors, get_x, get_y, bench_pairs, touch and determinism_probe are defined
// in zd_collide.cpp; this header holds the kernel's working state (scratch, rebuilt on every call).

#include <cstdint>
#include <vector>

#include "zd_geom.h"

namespace zd {

struct CollideScratch {
	// Bodies larger than this radius (m) stay out of the pair grid and are paired with every body instead.
	static constexpr float BIG_R = 1.0f;

	std::vector<float> x, y, r;
	std::vector<int32_t> through, heavy;
	bool has_flags = false;
	BodyGrid grid;

	void load(const float *px, const float *py, const float *rad, size_t n);
	// `iters` passes over the loaded bodies; ghost0: body 0 (the hero) takes no pair push. Returns the pushes.
	int run(WallGrid &walls, const std::vector<Box> &solids, bool ghost0, int iters);
	void wall_pass(WallGrid &walls, const std::vector<Box> &solids);
	int pair_pass(WallGrid &walls, bool ghost0);
	void pair(WallGrid &walls, int a, int b, int &pushes);
	void shove(WallGrid &walls, int i, float dx, float dy);
};

} // namespace zd
