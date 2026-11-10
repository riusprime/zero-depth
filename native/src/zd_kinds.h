#pragma once
// The per-kind table's layout, as NativeKindTable (src/sim/ai/native_kind_table.gd) builds it: the offsets of a
// row's ints (K_*) and floats (KF_*), the tuning's slots (T_*), and the flag and hook bits. Every value here must equal
// the GDScript constant of the same name; ZdWorld.kind_layout() hands them back in LAYOUT order and
// tests/unit/native/test_native_ai.gd compares them one by one, so a field added on one side only fails a test.

#include <cstdint>

namespace zd {
namespace kt {

enum Mode : int32_t { NATIVE = 0, HOOKED = 1, SCRIPT = 2 };

// K_FLAGS bits
constexpr int32_t CHARGES = 1;
constexpr int32_t KEEPS_AWAY = 2;
constexpr int32_t TURNS_SLOWLY = 4;
constexpr int32_t CRITTER = 8;
constexpr int32_t FLEES_THEN_STRAFES = 16;
constexpr int32_t STATIONARY = 32;
constexpr int32_t RELOCATES = 64;
constexpr int32_t TRACKS = 128;
constexpr int32_t AIM_NO_LEAD = 256;
constexpr int32_t FACES_ON_PLAN = 512;
constexpr int32_t AIM_AT_START = 1024;
constexpr int32_t SPELLS = 2048;
constexpr int32_t HOVERS = 4096;
constexpr int32_t NEEDS_MAY = 8192;
constexpr int32_t GUARDS_FRONT = 16384;
constexpr int32_t LOCKS_AHEAD = 32768;
constexpr int32_t LOCKS_FACING = 65536;
constexpr int32_t MELEE_STOP = 131072;

// K_HOOKS bits
constexpr int32_t HOOK_THINK_TICK = 1;
constexpr int32_t HOOK_MOVE_TICK = 2;
constexpr int32_t HOOK_WINDUP_START = 4;
constexpr int32_t HOOK_WINDUP_END = 8;
constexpr int32_t HOOK_CHARGE_STEP = 16;
constexpr int32_t HOOK_BOLT = 32;
constexpr int32_t HOOK_ACTIVE = 64;

// The ints of a row
constexpr int K_MODE = 0;
constexpr int K_BEHAVIOUR = 1;
constexpr int K_FLAGS = 2;
constexpr int K_HOOKS = 3;
constexpr int K_ROLE = 4;
constexpr int K_AI_FLAGS = 5;
constexpr int K_COOLDOWN = 6;
constexpr int K_WINDUP = 7;
constexpr int K_WINDUP_MAX = 8;
constexpr int K_ACTIVE = 9;
constexpr int K_RECOVER = 10;
constexpr int K_TURN_RATE = 11;
constexpr int K_CHARGE_TURN = 12;
constexpr int K_FRONT_HALF_ARC = 13;
constexpr int K_LEAD_MAX = 14;
constexpr int K_BURST_COUNT = 15;
constexpr int K_BURST_GAP = 16;
constexpr int K_BURST_SPREAD = 17;
constexpr int K_SHAPE = 18;
constexpr int K_DAMAGE = 19;
constexpr int K_TAGS = 20;
constexpr int K_CONTACT_CD = 21;
constexpr int K_MAX_MINES = 22;
constexpr int K_RUNE_WINDUP = 23;
constexpr int K_BOLT_LIFE = 24;
constexpr int K_HEAL_AMOUNT = 25;
constexpr int K_HEAL_PERIOD = 26;
constexpr int K_TRAIL_STEP = 27;
constexpr int K_PATTERNS = 28;
constexpr int K_PATTERN = 29;
constexpr int PATTERN_KI = 6;
constexpr int P_HAS = 0;
constexpr int P_LOB = 1;
constexpr int P_GAP = 2;
constexpr int P_WAVES = 3;
constexpr int P_DURATION = 4;
constexpr int P_BURST = 5;
constexpr int MAX_PATTERNS = 3;
constexpr int KI = K_PATTERN + PATTERN_KI * MAX_PATTERNS;

// The floats of a row
constexpr int KF_RADIUS = 0;
constexpr int KF_SPEED = 1;
constexpr int KF_ATTACK_RANGE = 2;
constexpr int KF_FLEE = 3;
constexpr int KF_KEEP_DISTANCE = 4;
constexpr int KF_KEEP_MIN = 5;
constexpr int KF_CHARGE_SPEED = 6;
constexpr int KF_CHARGE_DISTANCE = 7;
constexpr int KF_REACH = 8;
constexpr int KF_SLAM_RADIUS = 9;
constexpr int KF_LANE_HALF = 10;
constexpr int KF_RUNE_RADIUS = 11;
constexpr int KF_BOLT_SPEED = 12;
constexpr int KF_BOLT_RADIUS = 13;
constexpr int KF_SPREAD_SPEED = 14;
constexpr int KF_HEAL_RANGE = 15;
constexpr int KF_STRIKE_RADIUS = 16;
constexpr int KF_PATTERN = 17;
constexpr int PATTERN_KF = 3;
constexpr int PF_SPEED = 0;
constexpr int PF_RADIUS = 1;
constexpr int PF_LAND = 2;
constexpr int KF = KF_PATTERN + PATTERN_KF * MAX_PATTERNS;

// The tuning
constexpr int T_SPAWN_IN = 0;
constexpr int T_COMMIT = 1;
constexpr int T_SNIPE_COMMIT = 2;
constexpr int T_STRAFE_PERMILLE = 3;
constexpr int T_FLANK_MIN = 4;
constexpr int T_FLANK_RANGE = 5;
constexpr int T_FLANK_PERMILLE = 6;
constexpr int T_SPREAD_RADIUS = 7;
constexpr int T_SPREAD_WEIGHT = 8;
constexpr int T_RELOCATE_SPEED_PERMILLE = 9;
constexpr int T_RELOCATE_MAX = 10;
constexpr int T_MEND_SCAN = 11;
constexpr int T_PLAN_PERIOD = 12;
constexpr int T_EGG_STATE = 13;
constexpr int T_CONTACT_SLOP = 14;
constexpr int T_CRITTER_TOUCH = 15;
constexpr int T_RELOCATE_DONE = 16;
constexpr int T_SIGHT_R = 17;
constexpr int TUNING = 18;

// kind_layout(): every constant above, in this order (the test lists the GDScript names in the same order).
constexpr int32_t LAYOUT[] = {
	NATIVE, HOOKED, SCRIPT,
	CHARGES, KEEPS_AWAY, TURNS_SLOWLY, CRITTER, FLEES_THEN_STRAFES, STATIONARY, RELOCATES, TRACKS, AIM_NO_LEAD,
	FACES_ON_PLAN, AIM_AT_START, SPELLS, HOVERS, NEEDS_MAY, GUARDS_FRONT, LOCKS_AHEAD, LOCKS_FACING, MELEE_STOP,
	HOOK_THINK_TICK, HOOK_MOVE_TICK, HOOK_WINDUP_START, HOOK_WINDUP_END, HOOK_CHARGE_STEP, HOOK_BOLT, HOOK_ACTIVE,
	K_MODE, K_BEHAVIOUR, K_FLAGS, K_HOOKS, K_ROLE, K_AI_FLAGS, K_COOLDOWN, K_WINDUP, K_WINDUP_MAX, K_ACTIVE,
	K_RECOVER, K_TURN_RATE, K_CHARGE_TURN, K_FRONT_HALF_ARC, K_LEAD_MAX, K_BURST_COUNT, K_BURST_GAP, K_BURST_SPREAD,
	K_SHAPE, K_DAMAGE, K_TAGS, K_CONTACT_CD, K_MAX_MINES, K_RUNE_WINDUP, K_BOLT_LIFE, K_HEAL_AMOUNT, K_HEAL_PERIOD,
	K_TRAIL_STEP, K_PATTERNS, K_PATTERN, PATTERN_KI, P_HAS, P_LOB, P_GAP, P_WAVES, P_DURATION, P_BURST,
	MAX_PATTERNS, KI,
	KF_RADIUS, KF_SPEED, KF_ATTACK_RANGE, KF_FLEE, KF_KEEP_DISTANCE, KF_KEEP_MIN, KF_CHARGE_SPEED,
	KF_CHARGE_DISTANCE, KF_REACH, KF_SLAM_RADIUS, KF_LANE_HALF, KF_RUNE_RADIUS, KF_BOLT_SPEED, KF_BOLT_RADIUS,
	KF_SPREAD_SPEED, KF_HEAL_RANGE, KF_STRIKE_RADIUS, KF_PATTERN, PATTERN_KF, PF_SPEED, PF_RADIUS, PF_LAND, KF,
	T_SPAWN_IN, T_COMMIT, T_SNIPE_COMMIT, T_STRAFE_PERMILLE, T_FLANK_MIN, T_FLANK_RANGE, T_FLANK_PERMILLE,
	T_SPREAD_RADIUS, T_SPREAD_WEIGHT, T_RELOCATE_SPEED_PERMILLE, T_RELOCATE_MAX, T_MEND_SCAN, T_PLAN_PERIOD,
	T_EGG_STATE, T_CONTACT_SLOP, T_CRITTER_TOUCH, T_RELOCATE_DONE, T_SIGHT_R, TUNING,
};
constexpr int LAYOUT_SIZE = int(sizeof(LAYOUT) / sizeof(LAYOUT[0]));

} // namespace kt
} // namespace zd
