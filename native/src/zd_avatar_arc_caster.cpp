// The Arc Caster's avatar on a batch row (zd_avatar.h AC_*): ArcCasterAvatar's sync (apply_state), frame step
// (advance, _turning) and pose (_pose, _idle, _glide_pose, _turn_pose, _death, _add), ported line by line in the same
// order and float width as the GDScript (src/presentation/world_view/arc_caster_avatar.gd): its clocks, lift and
// glows are doubles (GDScript floats), the raw drives floats (its PackedFloat32Array: each `d[j] += x` reads the
// float, adds in double and stores a float), the glide's direction a float Vector2 and the velocity's turn into the
// facing's frame a float Basis. tests/unit/native/test_native_crowd.gd holds the drawn buffers equal to the GDScript
// avatar's bit for bit.

#include "zd_avatar.h"
#include "zd_legged_rig.h"

#include <cmath>
#include <cstdint>

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2.hpp>

using namespace godot;

namespace zd {
namespace av {

namespace {

constexpr double PI_D = 3.1415926535897932384626433833;
constexpr double TAU_D = 6.2831853071795864769252867666;
// AvatarBase
constexpr double FLINCH_SECONDS = 0.2;
constexpr int MOTION_GAP_TICKS = 30;
// ArcCasterAvatar
constexpr double HOVER_LIFT = 0.09;
constexpr double CRYSTAL_REST = 1.6;
constexpr double CRYSTAL_GATHER = 5.0;
constexpr double CRYSTAL_FLARE = 10.0;
constexpr double FLARE_DECAY = 5.0;
constexpr double VISOR_REST = 1.5;
constexpr double CAST_SNAP_S = 0.07;
constexpr double CAST_HOLD_S = 0.14;
constexpr double CAST_END_S = 0.9;
constexpr double SPAWN_SECONDS = 0.7;
constexpr double DEATH_SECONDS = 1.0;
constexpr double BOB_HZ = 0.5;
constexpr double SWAY_HZ = 0.4;
constexpr double CIRCLE_HZ = 0.5;
constexpr double ORBIT_RATE = 1.1;
constexpr double GLIDE_MPS = 3.0;
constexpr double STEP_M = 0.55;
constexpr double TURN_REF = 3.0;
constexpr double CALM = 0.35;
constexpr double CRUMPLE_K = 0.72;
constexpr double GATHER_LIFT = 0.1;
constexpr double CAST_LIFT = -0.03;
constexpr double TELEPORT_SPEED = 30.0;

// The raw drives (ArcCasterAvatar's YAW ... VISOR).
enum Drive {
	YAW = 0,
	LEAN_F = 1,
	LEAN_S = 2,
	CRUMPLE = 3,
	HEM_F = 4,
	HEM_S = 5,
	HEM_L_F = 6,
	HEM_L_S = 7,
	TORSO_F = 8,
	TORSO_S = 9,
	HOOD_F = 10,
	HOOD_S = 11,
	ARM_R_F = 12,
	ARM_R_S = 13,
	STAFF_DROP = 14,
	STAFF_F = 15,
	STAFF_S = 16,
	ARM_L_F = 17,
	ARM_L_S = 18,
	ELBOW_L = 19,
	ORBIT = 20,
	SCATTER = 21,
	VISOR = 22,
	DRIVES = 23,
};

// VAT_DRIVES: [lo, hi, loop].
struct Spec {
	double lo, hi;
	bool loop;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -1.0, 1.0, false }, // YAW
	{ -0.35, 0.5, false }, // LEAN_F
	{ -0.35, 0.35, false }, // LEAN_S
	{ 0.0, 1.0, false }, // CRUMPLE
	{ -0.5, 0.5, false }, // HEM_F
	{ -0.4, 0.4, false }, // HEM_S
	{ -0.5, 0.5, false }, // HEM_L_F
	{ -0.4, 0.4, false }, // HEM_L_S
	{ -0.6, 1.0, false }, // TORSO_F
	{ -0.35, 0.35, false }, // TORSO_S
	{ -1.0, 1.0, false }, // HOOD_F
	{ -0.45, 0.45, false }, // HOOD_S
	{ -0.8, 1.7, false }, // ARM_R_F
	{ -0.6, 0.8, false }, // ARM_R_S
	{ -0.6, 0.8, false }, // STAFF_DROP
	{ -0.8, 1.8, false }, // STAFF_F
	{ -0.6, 1.6, false }, // STAFF_S
	{ -1.0, 1.8, false }, // ARM_L_F
	{ -0.5, 1.4, false }, // ARM_L_S
	{ -0.3, 1.8, false }, // ELBOW_L
	{ 0.0, TAU_D, true }, // ORBIT
	{ -0.6, 1.0, false }, // SCATTER
	{ 0.0, 0.0, false }, // VISOR
};

// The clips' poses at full weight: {drive, value}.
struct Pair {
	int d;
	double v;
};
const Pair GATHER_POSE[] = {
	{ ARM_R_F, 1.05 },
	{ ARM_R_S, 0.2 },
	{ STAFF_F, -0.35 },
	{ STAFF_DROP, -0.12 },
	{ TORSO_F, -0.22 },
	{ HOOD_F, -0.4 },
	{ LEAN_F, -0.08 },
	{ HEM_F, 0.08 },
	{ ARM_L_F, -0.7 },
	{ ARM_L_S, 0.55 },
	{ ELBOW_L, 1.1 },
	{ SCATTER, -0.45 },
};
const Pair CAST_POSE[] = {
	{ ARM_R_F, 1.45 },
	{ ARM_R_S, -0.1 },
	{ STAFF_F, 0.95 },
	{ STAFF_DROP, 0.1 },
	{ TORSO_F, 0.16 },
	{ HOOD_F, 0.12 },
	{ LEAN_F, 0.1 },
	{ HEM_F, -0.3 },
	{ HEM_L_F, -0.28 },
	{ ARM_L_F, 1.45 },
	{ ARM_L_S, 0.25 },
	{ ELBOW_L, 0.05 },
	{ SCATTER, 0.75 },
};
const Pair FLINCH_POSE[] = {
	{ HOOD_F, -0.8 },
	{ TORSO_F, -0.3 },
	{ HEM_F, 0.12 },
	{ ARM_L_F, -0.4 },
	{ ARM_L_S, 0.6 },
	{ ARM_R_F, 0.25 },
	{ STAFF_F, -0.3 },
	{ STAFF_S, -0.2 },
	{ SCATTER, 0.3 },
};

// GDScript's utility functions on doubles (zd_avatar.cpp's reason for the engine's sin, cos and exp).
inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline double maxd(double a, double b) {
	return a > b ? a : b;
}
inline double lerpd(double from, double to, double w) {
	return from + (to - from) * w;
}
inline double sstep(double from, double to, double s) {
	return Math::smoothstep(from, to, s);
}
inline double toward(double from, double to, double delta) {
	return Math::move_toward(from, to, delta);
}
inline float f32(double v) {
	return float(v);
}
inline double dexp(double x) {
	return UtilityFunctions::exp(x);
}

// `d[j] += x` and `d[j] -= x` on the PackedFloat32Array.
inline void add(float *d, int j, double x) {
	d[j] = f32(double(d[j]) + x);
}
inline void sub(float *d, int j, double x) {
	d[j] = f32(double(d[j]) - x);
}

// ArcCasterAvatar._add: a clip's pose at weight w.
template <int N>
void add_pose(float *d, const Pair (&pose)[N], double w) {
	if (Math::is_zero_approx(w)) {
		return;
	}
	for (int q = 0; q < N; q++) {
		add(d, pose[q].d, pose[q].v * w);
	}
}

double flinch_amount(const double *s) {
	return envelope(s[FLINCH_T] / FLINCH_SECONDS) * s[FLINCH_S];
}

// ArcCasterAvatar._idle: returns the lift's change.
double idle(const double *s, float *d, double sw, double a, double held) {
	const double t = s[T];
	const double ph = t * TAU_D * SWAY_HZ;
	const double slow = t * TAU_D * 0.21;
	const double c = t * TAU_D * CIRCLE_HZ;
	add(d, LEAN_F, 0.02 * sw * sin_d(ph + 0.5));
	add(d, LEAN_S, 0.03 * sw * sin_d(slow));
	sub(d, HEM_F, 0.04 * sw * sin_d(ph - 0.8));
	sub(d, HEM_S, 0.04 * sw * sin_d(slow - 0.9));
	sub(d, HEM_L_F, 0.05 * sw * sin_d(ph - 1.6));
	sub(d, HEM_L_S, 0.05 * sw * sin_d(slow - 1.8));
	add(d, TORSO_F, 0.06 * held + 0.03 * sw * sin_d(ph + 1.0));
	add(d, HOOD_F, 0.14 * held + 0.05 * sw * sin_d(ph + 1.7));
	add(d, HOOD_S, 0.05 * sw * sin_d(t * TAU_D * 0.17));
	add(d, ARM_L_F, 0.15 * held + 0.14 * a * held * sin_d(c));
	add(d, ARM_L_S, 0.12 * held + 0.1 * a * held * cos_d(c));
	add(d, ELBOW_L, 0.35 * held + 0.12 * a * held * sin_d(c + 1.2));
	add(d, ARM_R_F, 0.03 * sw * sin_d(ph + 0.3));
	sub(d, STAFF_F, 0.03 * sw * sin_d(ph + 0.3));
	return 0.025 * sw * sin_d(t * TAU_D * BOB_HZ);
}

// ArcCasterAvatar._glide_pose: returns the lift's change.
double glide_pose(const double *s, float *d, double sw, bool calm) {
	const double k = s[AC_GLIDE] * (calm ? 0.6 : 1.0) * (sw > 0.0 ? 1.0 : 0.0);
	if (k <= 0.0) {
		return 0.0;
	}
	const double vx = double(f32(s[AC_DIR]));
	const double vy = double(f32(s[AC_DIR + 1]));
	const double step = sin_d(s[AC_STEP]);
	const double bob = calm ? 0.0 : std::fabs(step);
	add(d, LEAN_F, 0.16 * k * vx);
	add(d, LEAN_S, 0.12 * k * vy);
	add(d, HEM_F, -0.22 * k * vx);
	add(d, HEM_S, -0.16 * k * vy);
	add(d, HEM_L_F, -0.12 * k * vx + 0.1 * k * bob);
	add(d, HEM_L_S, 0.16 * k * step * (calm ? 0.4 : 1.0));
	sub(d, TORSO_S, 0.04 * k * step * (calm ? 0.0 : 1.0));
	sub(d, TORSO_F, 0.05 * k * vx);
	add(d, HOOD_F, -0.08 * k * vx + 0.04 * k * bob);
	add(d, ARM_L_F, -0.3 * k * vx);
	add(d, ARM_L_S, 0.12 * k);
	add(d, ARM_R_F, 0.12 * k * vx);
	add(d, STAFF_F, 0.08 * k * vx);
	return 0.035 * k * bob;
}

// ArcCasterAvatar._turn_pose
void turn_pose(const double *s, float *d, double k) {
	const double w = clampd(s[AC_OMEGA] / TURN_REF, -1.0, 1.0);
	sub(d, YAW, 0.3 * w * k);
	add(d, HEM_S, 0.15 * w * k);
	add(d, HEM_L_S, 0.2 * w * k);
}

// ArcCasterAvatar._death: returns the lift.
double death(float *d, double u, double fold, bool calm, double lift) {
	const double jolt = sin_d(PI_D * clampd(u / 0.22, 0.0, 1.0)) * (calm ? 0.5 : 1.0);
	double fall = sstep(0.06, 0.62, u);
	fall *= fall;
	add(d, HOOD_F, -0.55 * jolt + 0.7 * fold);
	add(d, TORSO_F, -0.2 * jolt + 0.72 * fold);
	add(d, ARM_R_F, 0.4 * jolt - 0.45 * fold);
	add(d, ARM_L_S, 0.45 * jolt - 0.1 * fold);
	add(d, ARM_L_F, -0.25 * fold);
	add(d, ELBOW_L, 0.3 * fold);
	add(d, LEAN_F, 0.04 * fold);
	add(d, CRUMPLE, 0.9 * fold);
	add(d, SCATTER, sstep(0.05, 0.5, u));
	add(d, STAFF_DROP, 0.15 * fall);
	sub(d, STAFF_F, 0.2 * fall);
	add(d, STAFF_S, 1.57 * fall);
	return lerpd(lift, 0.0, fold);
}

// ArcCasterAvatar._pose on a VAT avatar (no nodes): the drives, the lift and the crystal's glow.
void ac_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double a = calm ? CALM : 1.0;
	float d[DRIVES] = {};
	const double t = s[T];
	const double die_t = s[AC_DIE];
	const double wind = s[AC_WIND];
	const double rise = s[AC_RISE];
	const double cast_s = s[AC_CAST];
	const bool dead = die_t >= 0.0;
	const double die_u = dead ? clampd(die_t / DEATH_SECONDS, 0.0, 1.0) : 0.0;
	const double fold = dead ? sstep(0.12, 0.8, die_u) : 0.0;
	double lift = HOVER_LIFT;
	double crystal = CRYSTAL_REST * (1.0 + 0.2 * a * sin_d(t * TAU_D * SWAY_HZ * 1.3));
	double visor = VISOR_REST;
	double gather = sstep(0.0, 1.0, wind);
	double cast = 0.0;
	if (cast_s >= 0.0) {
		const double e = cast_s;
		if (e < CAST_SNAP_S) {
			cast = e / CAST_SNAP_S;
		} else if (e < CAST_SNAP_S + CAST_HOLD_S) {
			cast = 1.0;
		} else {
			const double u = (e - CAST_SNAP_S - CAST_HOLD_S) / (CAST_END_S - CAST_SNAP_S - CAST_HOLD_S);
			cast = (1.0 - sstep(0.0, 1.0, u)) * (calm ? 1.0 : 1.0 + 0.15 * sin_d(u * TAU_D));
		}
		crystal += CRYSTAL_FLARE * (calm ? 0.6 : 1.0) * dexp(-e * FLARE_DECAY);
		gather *= 1.0 - sstep(0.0, CAST_SNAP_S, e);
	}
	const double busy = clampd(maxd(gather, cast), 0.0, 1.0);
	const double still = (1.0 - 0.7 * busy) * (1.0 - fold) * rise;
	lift += idle(s, d, a * still, a, still);
	lift += glide_pose(s, d, a * (1.0 - fold), calm);
	add_pose(d, GATHER_POSE, gather);
	lift += GATHER_LIFT * gather;
	crystal += CRYSTAL_GATHER * gather;
	visor += 1.4 * gather;
	if (gather > 0.0 && wind > 0.75 && !calm) { // the staff and the crystal tremble at the top of the gather
		const double shake = 0.03 * sin_d(t * TAU_D * 11.0) * (wind - 0.75) / 0.25;
		add(d, STAFF_S, shake);
		add(d, ARM_R_F, shake * 0.5);
		add(d, ELBOW_L, shake * 2.0);
		crystal += 1.5 * sin_d(t * TAU_D * 9.0);
	}
	add_pose(d, CAST_POSE, cast);
	lift += CAST_LIFT * cast;
	turn_pose(s, d, a * (1.0 - fold));
	add_pose(d, FLINCH_POSE, flinch_amount(s));
	if (rise < 1.0 && !dead) { // the rise-in: up out of its robe, the shards gathering in
		const double r = 1.0 - rise;
		add(d, CRUMPLE, 0.9 * r);
		add(d, TORSO_F, 0.55 * r);
		add(d, HOOD_F, 0.5 * r);
		add(d, SCATTER, r * r);
		add(d, ARM_L_S, 0.4 * r);
		add(d, ELBOW_L, 0.5 * r);
		sub(d, STAFF_DROP, CRUMPLE_K * 0.9 * r * double(f32(s[AC_HEM_Y])));
		lift -= (HOVER_LIFT - 0.04) * r;
		crystal *= rise;
		visor *= rise;
	}
	if (dead) {
		lift = death(d, die_u, fold, calm, lift);
		crystal += 5.0 * sin_d(PI_D * clampd(die_u / 0.22, 0.0, 1.0));
		crystal *= 1.0 - sstep(0.2, 0.8, die_u);
		visor *= 1.0 - sstep(0.1, 0.6, die_u);
	}
	for (int j = 0; j < DRIVES; j++) {
		if (!VAT_DRIVES[j].loop && VAT_DRIVES[j].hi > VAT_DRIVES[j].lo) {
			d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
		}
	}
	d[ORBIT] = f32(s[AC_ORBIT]);
	d[VISOR] = f32(visor);
	for (int j = 0; j < DRIVES; j++) {
		s[AC_VD + j] = d[j];
	}
	s[AC_LIFT] = lift;
	s[AC_CRYSTAL] = maxd(crystal, 0.0);
}

} // namespace

// ArcCasterAvatar.apply_state from a sync.
void ac_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const Ctx &c) {
	const int was = int(s[AC_STATE]);
	s[AC_STATE] = state;
	s[AC_WIND] = state == c.st.windup ? clampd(windup, 0.0, 1.0) : 0.0;
	if (state == c.st.active && was != c.st.active) {
		s[AC_CAST] = 0.0;
	}
	// _track_motion(tick, pos, 30.0)
	const bool fresh = s[FRESH] != 0.0;
	const int64_t last = int64_t(s[LAST_TICK]);
	if (!fresh && tick > last) {
		const Vector2 v = (Vector2(pos_x, pos_y) - Vector2(f32(s[LAST_PX]), f32(s[LAST_PY]))) *
				f32(60.0 / double(tick - last));
		const bool keep = double(v.length()) <= TELEPORT_SPEED && tick - last <= MOTION_GAP_TICKS;
		s[VEL_X] = keep ? v.x : 0.0f;
		s[VEL_Y] = keep ? v.y : 0.0f;
	} else if (tick < last) {
		s[VEL_X] = 0.0;
		s[VEL_Y] = 0.0;
	}
	s[LAST_TICK] = double(tick);
	s[LAST_PX] = pos_x;
	s[LAST_PY] = pos_y;
	if (fresh) {
		s[FRESH] = 0.0;
		s[AC_RISE] = state == c.st.spawn ? 0.0 : 1.0;
		ac_pose(s, c);
	}
}

// ArcCasterAvatar.advance (`f`: the facing's yaw, get_parent().rotation.y, for _turning).
void ac_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[AC_DIE] >= 0.0;
	const double fy = double(f.facing_yaw);
	s[AC_OMEGA] = rig::turning(s[AC_OMEGA], fy, s[AC_LAST_FY], s[AC_HAVE_FY] != 0.0 && !dying, dt, ease_rate(6.0, dt));
	s[AC_LAST_FY] = fy;
	s[AC_HAVE_FY] = 1.0;
	if (!dying) {
		const bool spawning = int(s[AC_STATE]) == c.st.spawn;
		s[AC_RISE] = toward(s[AC_RISE], spawning ? 0.0 : 1.0, dt / SPAWN_SECONDS);
	}
	if (s[AC_CAST] >= 0.0) {
		s[AC_CAST] += dt;
		if (s[AC_CAST] >= CAST_END_S) {
			s[AC_CAST] = -1.0;
		}
	}
	if (dying) {
		s[AC_DIE] += dt;
	}
	// The glide: the sim's velocity in the facing's frame (x forward, y right); the step's phase by the travel.
	const Vector3 v3 =
			axis_angle(Vector3(0, 1, 0), f32(-s[AC_LAST_FY])).xform(Vector3(f32(s[VEL_X]), 0.0f, -f32(s[VEL_Y])));
	const Vector2 local(v3.x, v3.z);
	const double speed = dying ? 0.0 : double(local.length());
	s[AC_GLIDE] = lerpd(s[AC_GLIDE], clampd(speed / GLIDE_MPS, 0.0, 1.0), ease_rate(6.0, dt));
	if (speed > 0.05) {
		const Vector2 dir(f32(s[AC_DIR]), f32(s[AC_DIR + 1]));
		const Vector2 now = dir.lerp(local / f32(speed), f32(ease_rate(8.0, dt))).normalized();
		s[AC_DIR] = now.x;
		s[AC_DIR + 1] = now.y;
	}
	s[AC_STEP] = Math::fposmod(s[AC_STEP] + speed * dt / STEP_M * PI_D, TAU_D);
	// The shards circle the hood (faster through the gather); still with reduced motion, stopped in the death.
	if (!c.calm && !dying) {
		s[AC_ORBIT] = Math::fposmod(s[AC_ORBIT] + ORBIT_RATE * (1.0 + 3.0 * s[AC_WIND]) * dt, TAU_D);
	}
	ac_pose(s, c);
}

// ArcCasterAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the orbit's drive a loop, the visor's as it is).
int ac_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[AC_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		const double span = VAT_DRIVES[i].hi - lo;
		if (Math::is_zero_approx(span)) {
			out[i] = f32(v);
			continue;
		}
		const double u = (v - lo) / span;
		out[i] = f32(VAT_DRIVES[i].loop ? u - std::floor(u) : u);
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
