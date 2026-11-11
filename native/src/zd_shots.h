#pragma once
// The projectile sweep (World._projectile_hits through NativeShots, NATIVE_CORE.md §3.5): each projectile's segment for
// this tick, thickened by its radius, against the walls and the bodies, with the sweep's rules: a body of the
// projectile's own team or a dead one is never hit, a Void or Wave shot (walls_only) meets walls only, the earliest
// t wins, and a tie keeps the wall, then the lower wall index, then the lower body index. A projectile that meets
// nothing is advanced here (position plus velocity, one tick of life off); one that meets something is left where it
// is, and GDScript runs the hit (ProjectileContacts), since every rule of what a hit does lives there.
// ZdWorld's sweep_shots, shot_events, shot_t and sweep_one are defined in zd_shots.cpp; this header holds the
// kernel's working state (rebuilt on every call, nothing kept between ticks).

#include <cstdint>
#include <vector>

#include "zd_geom.h"

namespace zd {

struct ShotsScratch {
	// Bodies larger than this radius (m) stay out of the body grid and are tested by every projectile.
	static constexpr float BIG_R = 1.0f;
	// What the event list holds for a projectile (NativeShots.HOLD, CONTACT, END).
	static constexpr int HOLD = 0;
	static constexpr int CONTACT = 1;
	static constexpr int END = 2;
	// t when nothing is met (above every t a sweep gives, which lie in [0, 1]).
	static constexpr float NONE = 2.0f;

	BodyGrid grid;
	std::vector<int> cand;
	std::vector<float> out_x, out_y;
	std::vector<int32_t> out_life;
	// Four ints an event (code, projectile, body or -1, wall or -1) and its t.
	std::vector<int32_t> events;
	std::vector<float> event_t;

	// The bodies the sweep reads (the store's buffers, valid during one call).
	const float *bx = nullptr, *by = nullptr, *br = nullptr;
	const int32_t *bteam = nullptr, *bdead = nullptr;
	int bodies = 0;

	// One projectile's segment from (ax, ay) by (vx, vy), radius r, of `team`: the earliest contact's t (NONE if
	// none), the body or -1, the wall or -1. The grid must hold the bodies above.
	float sweep(WallGrid &walls, float ax, float ay, float vx, float vy, float r, int32_t team, bool walls_only,
			int &actor, int &wall);
};

} // namespace zd
