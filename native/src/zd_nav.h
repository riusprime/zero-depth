#pragma once
// The flow field's flood toward the hero (NavField, NATIVE_CORE.md §3.6): the same bucketed octile Dijkstra as
// NavField._run, over the nav grid cache (ZdWorld::nav_), run whole in one call. Integer arithmetic only, the same
// step order and the same bucket order, so the distances are NavField.flood's cell for cell. The goal's seeds (a
// hero in a blocked cell seeds the free cells near it, a test against the walls' boxes) come from GDScript
// (NavField._seeds), so the native side never repeats that float test.

#include <cstdint>
#include <vector>

namespace zd {

struct NavGrid;

namespace nav {
// NavField's constants.
constexpr int32_t UNREACHED = 1 << 30;
constexpr int32_t ORTHO = 5;
constexpr int32_t DIAG = 7;
constexpr int32_t RING = 8;
constexpr int32_t TARGET_MARGIN = 8 * ORTHO;
constexpr float CELL = 0.5f;

// The flood's working vectors (derived, rebuilt every call): the bucket ring (RING buckets of the grid's cell count;
// a bucket holds one distance and a cell enters it at most once) and the target marks (all zero between calls).
struct Scratch {
	std::vector<int32_t> ring;
	std::vector<uint8_t> want;
};

// The flood's result beside the distances (which it writes into g.dist).
struct FloodOut {
	int32_t work = 0; // cells taken from the buckets (NavField.last_work)
	bool stopped = false; // ended TARGET_MARGIN past its last target with cells still queued (the key's z flips)
};

// The flood from `seeds` (flat cell, distance pairs), bounded at `max_steps` sides, stopping TARGET_MARGIN past the
// last of `targets` (cell indices; out-of-range ones skipped) to settle. NavField._begin plus _run(UNREACHED).
FloodOut flood(NavGrid &g, Scratch &s, const int32_t *seeds, int64_t seed_count, int64_t max_steps,
		const int32_t *targets, int64_t target_count);

// NavField.direction: the unit step from (px, py) toward the neighbouring cell nearest the goal, or (0, 0).
void direction(const NavGrid &g, float px, float py, float &dx, float &dy);
} // namespace nav

} // namespace zd
