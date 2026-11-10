#pragma once
// The enemy AI kernels (NATIVE_CORE.md §3.2, §3.3): ZdWorld::think (tick phase 3: the staggered walk plan and the
// per-tick state machine) and ZdWorld::move (phase 5: the table kinds' steering, before the collision passes) for
// every row whose kind is NATIVE or HOOKED in the per-kind table (zd_kinds.h). The rules are EnemyAi's and
// CritterAi's (src/sim/ai/enemy_ai.gd, critter_ai.gd): the same speeds, ranges, cooldowns, turn rates and windup
// timings. What needs a random draw or a GDScript rule is handed back as an intent, ascending by row, then by code,
// which GDScript applies in that order (NativeAi, src/sim/world/native_ai.gd). The kernels draw nothing and keep
// nothing between calls: every value they change goes back into the store's columns.
// ZdWorld's methods think, move, ai_intents_i, ai_intents_f and kind_layout are defined in zd_ai.cpp.

#include <cstdint>
#include <vector>

#include "zd_geom.h"

namespace zd {

// The hero as think and move read it (NativeAi.hero_of): one float each.
enum Hero : int {
	H_X = 0,
	H_Y,
	H_VX,
	H_VY,
	H_RADIUS,
	H_DEAD, // 1 dead
	H_DASHING, // 1 while a dash runs (aim at its landing)
	H_LAND_X, // where the dash in progress ends (BossChallenge.dash_landing)
	H_LAND_Y,
	HERO_SIZE,
};

// Intent codes (NativeAi.Intent), in the order a row's intents are listed.
enum Intent : int32_t {
	I_FLOW = 1, // think: a plan blocked by a wall; GDScript takes the flow field's way (f0: the walk's length)
	I_THINK_TICK = 2, // think: Variants.on_think (the Rubble Warden's crust), before the frozen check
	I_MOVE_TICK = 3, // think: the Mender's _mend, in place of an attack
	I_WINDUP_START = 4, // think: an attack began (a: its aim); GDScript draws its length and runs the kind's extras
	I_WINDUP_END = 5, // think: a windup ran out for a kind that may cancel (the Star Warper); GDScript decides
	I_RELOCATE = 6, // think: a Sniper's RECOVER ended; GDScript draws its next spot
	I_CHARGE_STEP = 7, // move: a charge stepped for a kind with a trail (Variants.on_charge_step)
	I_RELOCATE_STEP = 8, // move: a relocating Sniper's walk, left to GDScript while the flow field is GDScript's
};

// EnemyAi.State
enum AiState : int32_t { S_SPAWN = 0, S_MOVE = 1, S_WINDUP = 2, S_ACTIVE = 3, S_RECOVER = 4 };

struct AiScratch {
	// The columns a kernel may change, loaded at its start and sent back when changed.
	std::vector<int32_t> state, state_t, cd, fire_cd, facing, lock_a, windup, pick, plan_block;
	std::vector<float> pos_x, pos_y, lock_x, lock_y, lock_len, plan_x, plan_y;
	BodyGrid grid;
	std::vector<int> near;
	// The intents of the last call, stride 4: (code, row, a, b) and (f0, f1, f2, f3).
	std::vector<int32_t> out_i;
	std::vector<float> out_f;

	void emit(int32_t code, int32_t row, int32_t a = 0, float f0 = 0.0f) {
		out_i.push_back(code);
		out_i.push_back(row);
		out_i.push_back(a);
		out_i.push_back(0);
		out_f.push_back(f0);
		out_f.push_back(0.0f);
		out_f.push_back(0.0f);
		out_f.push_back(0.0f);
	}
};

} // namespace zd
