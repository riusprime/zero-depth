// The Star Warper's avatar on a batch row (zd_avatar.h SW_*): StarWarperAvatar's sync (apply_state), frame step
// (advance, _turning) and pose (_pose, _slash_weight, _hover_pose, _glide_pose, _turn_pose, _reel_pose, _hurt_pose,
// _death_pose), ported line by line in the same order and float width as the GDScript
// (src/presentation/world_view/star_warper_avatar.gd): its clocks, form, reel, glide, wave, orbit and glows are doubles
// (GDScript floats), its raw drives floats (its PackedFloat32Array: each `d[j] += x` reads the float, adds in double
// and stores a float), the glide's direction and the velocity's turn into the facing's frame float vectors, the
// visor's glow and the ground disc's scale floats (what its material and its node store).
// tests/unit/native/test_native_crowd_star_warper.gd holds the drawn buffers and the ground disc equal to the GDScript
// avatar's bit for bit.

#include "zd_avatar.h"
#include "zd_legged_rig.h"

#include <cmath>
#include <cstdint>

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/vector2.hpp>

using namespace godot;

namespace zd {
namespace av {

namespace {

constexpr double PI_D = 3.1415926535897932384626433833;
constexpr double TAU_D = 6.2831853071795864769252867666;
// AvatarBase
constexpr int MOTION_GAP_TICKS = 30;
// StarWarperAvatar
constexpr double TELEPORT_SPEED = 12.0;
constexpr double HOVER_LIFT = 0.22;
constexpr double SHARD_REST = 1.2;
constexpr double SHARD_TELL = 4.0;
constexpr double VISOR_REST = 1.5;
constexpr double VISOR_TELL = 3.5;
constexpr double SLASH_SNAP_S = 0.08;
constexpr double SLASH_HOLD_S = 0.14;
constexpr double SLASH_END_S = 0.8;
constexpr double HURT_SECONDS = 0.8;
constexpr double DEATH_SECONDS = 1.2;
constexpr double DISSOLVE_FROM = 0.86;
constexpr double REFORM_RATE = 7.0;
constexpr double BOB_HZ = 0.55;
constexpr double WAVE_HZ = 0.6;
constexpr double WAVE_GLIDE_HZ = 1.4;
constexpr double ORBIT_RATE = 1.4;
constexpr double GLIDE_MPS = 3.0;
constexpr double TURN_REF = 3.0;
constexpr double CALM = 0.4;
constexpr double TELL_LIFT = 0.1;
constexpr double STRIKE_LIFT = -0.08;
constexpr int TAILS = 3;

// The raw drives (StarWarperAvatar's ROLL ... VISOR).
enum Drive {
	ROLL = 0,
	PITCH = 1,
	YAW = 2,
	FORM = 3,
	HEAD_F = 4,
	HEAD_S = 5,
	ARM_L = 6,
	ARM_R = 9,
	SWEEP = 0,
	RAISE = 1,
	ELBOW = 2,
	TAIL0 = 12,
	SWING = 0,
	SWAY = 1,
	ORBIT = 18,
	SCATTER = 19,
	VISOR = 20,
	DRIVES = 21,
};

// VAT_DRIVES: [lo, hi, loop] (the shards' turn loops; the visor's [0, 0] is sent as it is).
struct Spec {
	double lo, hi;
	bool loop;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.9, 0.9, false }, // ROLL
	{ -0.6, 0.7, false }, // PITCH
	{ -0.7, 0.7, false }, // YAW
	{ -1.0, 0.0, false }, // FORM
	{ -0.7, 0.8, false }, // HEAD_F
	{ -0.7, 0.7, false }, // HEAD_S
	{ -1.2, 1.4, false }, // ARM_L SWEEP
	{ -0.8, 0.9, false }, // ARM_L RAISE
	{ -0.5, 1.4, false }, // ARM_L ELBOW
	{ -1.2, 1.4, false }, // ARM_R SWEEP
	{ -0.8, 0.9, false }, // ARM_R RAISE
	{ -0.5, 1.4, false }, // ARM_R ELBOW
	{ -0.8, 1.0, false }, // TAIL a SWING
	{ -0.7, 0.7, false }, // TAIL a SWAY
	{ -0.9, 1.1, false }, // TAIL b SWING
	{ -0.8, 0.8, false }, // TAIL b SWAY
	{ -1.0, 1.2, false }, // TAIL c SWING
	{ -0.9, 0.9, false }, // TAIL c SWAY
	{ 0.0, TAU_D, true }, // ORBIT
	{ -0.5, 1.0, false }, // SCATTER
	{ 0.0, 0.0, false }, // VISOR
};

// TELL_POSE and STRIKE_POSE: [drive, value] at full weight.
struct Pair {
	int drive;
	double value;
};
const Pair TELL_POSE[] = {
	{ ARM_L + SWEEP, -0.9 },
	{ ARM_R + SWEEP, -0.9 },
	{ ARM_L + RAISE, 0.55 },
	{ ARM_R + RAISE, 0.55 },
	{ ARM_L + ELBOW, 0.9 },
	{ ARM_R + ELBOW, 0.9 },
	{ HEAD_F, -0.35 },
	{ PITCH, -0.18 },
	{ TAIL0 + SWING, -0.35 },
	{ TAIL0 + 2 + SWING, 0.5 },
	{ TAIL0 + 4 + SWING, 0.7 },
	{ SCATTER, -0.35 },
};
const Pair STRIKE_POSE[] = {
	{ ARM_L + SWEEP, 1.15 },
	{ ARM_R + SWEEP, 1.15 },
	{ ARM_L + RAISE, -0.45 },
	{ ARM_R + RAISE, -0.45 },
	{ ARM_L + ELBOW, 1.2 },
	{ ARM_R + ELBOW, 1.2 },
	{ HEAD_F, 0.15 },
	{ PITCH, 0.25 },
	{ TAIL0 + SWING, 0.6 },
	{ TAIL0 + 2 + SWING, 0.5 },
	{ TAIL0 + 4 + SWING, 0.4 },
};

const Vector3 UP(0, 1, 0);

// GDScript's utility functions on doubles.
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

// `d[j] += x` on the PackedFloat32Array (`-= x` is the same sum with -x: IEEE subtraction is that addition).
inline void add(float *d, int j, double x) {
	d[j] = f32(double(d[j]) + x);
}

// StarWarperAvatar._add
template <int N>
void add_pose(float *d, const Pair (&pose)[N], double w) {
	if (Math::is_zero_approx(w)) {
		return;
	}
	for (int q = 0; q < N; q++) {
		add(d, pose[q].drive, pose[q].value * w);
	}
}

// StarWarperAvatar._slash_weight
double slash_weight(const double *s, bool calm) {
	const double e = s[SW_SLASH];
	if (e < 0.0) {
		return 0.0;
	}
	if (e < SLASH_SNAP_S) {
		return e / SLASH_SNAP_S;
	}
	if (e < SLASH_SNAP_S + SLASH_HOLD_S) {
		return 1.0;
	}
	const double u = (e - SLASH_SNAP_S - SLASH_HOLD_S) / (SLASH_END_S - SLASH_SNAP_S - SLASH_HOLD_S);
	return (1.0 - sstep(0.0, 1.0, u)) * (calm ? 1.0 : 1.0 - 0.2 * sin_d(u * TAU_D));
}

// StarWarperAvatar._hover_pose
void hover_pose(const double *s, float *d, double sc) {
	const double t = s[T];
	add(d, ROLL, 0.06 * sc * sin_d(0.7 * t));
	add(d, PITCH, 0.05 * sc * sin_d(0.55 * t + 1.0));
	add(d, HEAD_S, 0.08 * sc * sin_d(0.45 * t + 0.4));
	add(d, HEAD_F, 0.05 * sc * sin_d(0.6 * t + 2.0));
	for (int k = 0; k < TAILS; k++) {
		const double ph = s[SW_WAVE] - 0.9 * double(k);
		add(d, TAIL0 + 2 * k + SWAY, (0.14 + 0.08 * double(k)) * sc * sin_d(ph));
		add(d, TAIL0 + 2 * k + SWING, (0.08 + 0.04 * double(k)) * sc * sin_d(ph * 0.5 + 0.7));
	}
	for (int side = 0; side < 2; side++) {
		const int a = side == 0 ? ARM_L : ARM_R;
		const double ph = 0.8 * t + 1.7 * double(side);
		add(d, a + SWEEP, 0.08 * sc * sin_d(ph));
		add(d, a + RAISE, 0.06 * sc * sin_d(ph * 0.8 + 0.5));
		add(d, a + ELBOW, 0.2 * sc + 0.12 * sc * sin_d(1.3 * t + double(side)));
	}
}

// StarWarperAvatar._glide_pose
void glide_pose(const double *s, float *d, double sc) {
	const double g = s[SW_GLIDE] * sc;
	if (g <= 0.0) {
		return;
	}
	const double vx = double(f32(s[SW_DIR]));
	const double vy = double(f32(s[SW_DIR + 1]));
	add(d, PITCH, 0.3 * g * vx);
	add(d, ROLL, 0.25 * g * vy);
	add(d, HEAD_F, -(0.12 * g * vx));
	for (int k = 0; k < TAILS; k++) {
		add(d, TAIL0 + 2 * k + SWING, (0.4 - 0.08 * double(k)) * g * vx);
		add(d, TAIL0 + 2 * k + SWAY, -((0.3 + 0.1 * double(k)) * g * vy));
	}
	for (int side = 0; side < 2; side++) {
		const int a = side == 0 ? ARM_L : ARM_R;
		add(d, a + SWEEP, -(0.45 * g * maxd(vx, 0.0)));
		add(d, a + RAISE, 0.15 * g);
	}
}

// StarWarperAvatar._turn_pose
void turn_pose(const double *s, float *d, double sc) {
	const double w = clampd(s[SW_OMEGA] / TURN_REF, -1.0, 1.0);
	add(d, YAW, -(0.35 * w * sc));
	add(d, ROLL, 0.1 * w * sc);
	for (int k = 0; k < TAILS; k++) {
		add(d, TAIL0 + 2 * k + SWAY, (0.2 + 0.1 * double(k)) * w * sc);
	}
}

// StarWarperAvatar._reel_pose: returns the lift's change.
double reel_pose(const double *s, float *d, double sc, bool calm) {
	const double reel = s[SW_REEL];
	if (reel <= 0.0) {
		return 0.0;
	}
	const double r = sstep(0.0, 1.0, reel);
	const double wob = calm ? 1.0 : sin_d(s[T] * TAU_D * 1.4);
	add(d, ROLL, 0.22 * r * wob * sc);
	add(d, PITCH, 0.14 * r);
	add(d, HEAD_F, 0.38 * r);
	add(d, HEAD_S, 0.25 * r * wob * sc);
	for (int side = 0; side < 2; side++) {
		const int a = side == 0 ? ARM_L : ARM_R;
		add(d, a + RAISE, -(0.45 * r));
		add(d, a + SWEEP, -(0.1 * r));
	}
	return -0.12 * r;
}

// StarWarperAvatar._hurt_pose: returns the lift's change.
double hurt_pose(const double *s, float *d, double sc, bool calm) {
	const double ht = s[SW_HURT_T];
	if (ht < 0.0) {
		return 0.0;
	}
	const double u = ht / HURT_SECONDS;
	double env = (1.0 - sstep(0.0, 1.0, u)) * sstep(0.0, 0.05, u);
	double swing = cos_d(TAU_D * 2.0 * ht);
	if (calm) {
		swing = 1.0;
		env = sin_d(PI_D * clampd(u / 0.7, 0.0, 1.0));
	}
	add(d, ROLL, 0.25 * s[SW_HURT_SIDE] * env * swing * sc);
	add(d, PITCH, -(0.15 * env * swing * sc));
	add(d, HEAD_F, -(0.35 * env * swing));
	add(d, TAIL0 + SWING, 0.3 * env * swing * sc);
	return -0.1 * env * (0.5 + 0.5 * swing);
}

// StarWarperAvatar._death_pose: returns the lift.
double death_pose(float *d, double u, double limp, bool calm, double lift) {
	const double jolt = sin_d(PI_D * clampd(u / 0.2, 0.0, 1.0)) * (calm ? 0.5 : 1.0);
	add(d, HEAD_F, -0.5 * jolt + 0.6 * limp);
	add(d, PITCH, -0.2 * jolt + 0.4 * limp);
	add(d, ROLL, 0.3 * limp);
	for (int side = 0; side < 2; side++) {
		const int a = side == 0 ? ARM_L : ARM_R;
		add(d, a + RAISE, 0.4 * jolt - 0.6 * limp);
		add(d, a + ELBOW, 0.6 * limp);
	}
	for (int k = 0; k < TAILS; k++) {
		const int sw = TAIL0 + 2 * k + SWING;
		const int sy = TAIL0 + 2 * k + SWAY;
		d[sw] = f32(double(d[sw]) * (1.0 - limp));
		d[sy] = f32(double(d[sy]) * (1.0 - limp));
	}
	const double fall = sstep(0.15, 0.6, u);
	return lerpd(lift, 0.06, fall * fall);
}

// StarWarperAvatar._pose on a VAT avatar (no nodes): the drives, the lift, the glows and the ground disc's scale.
void sw_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double k = calm ? CALM : 1.0;
	float d[DRIVES] = {};
	const double t = s[T];
	const double die_t = s[SW_DIE];
	const bool dead = die_t >= 0.0;
	const double die_u = dead ? clampd(die_t / DEATH_SECONDS, 0.0, 1.0) : 0.0;
	const double limp = dead ? sstep(0.1, 0.55, die_u) : 0.0;
	const double wind = s[SW_WIND];
	const double tell = sstep(0.0, 0.85, wind);
	const double strike = slash_weight(s, calm);
	const double busy = clampd(maxd(tell, strike), 0.0, 1.0);
	const double free = (1.0 - 0.6 * busy) * (1.0 - limp);
	double lift = HOVER_LIFT + (calm ? 0.0 : 0.05 * sin_d(TAU_D * BOB_HZ * t)) * free;
	hover_pose(s, d, k * free);
	glide_pose(s, d, k * (1.0 - limp));
	turn_pose(s, d, k * (1.0 - limp));
	add_pose(d, TELL_POSE, tell);
	lift += TELL_LIFT * tell;
	add_pose(d, STRIKE_POSE, strike);
	lift += STRIKE_LIFT * strike;
	lift += reel_pose(s, d, k, calm);
	lift += hurt_pose(s, d, k, calm);
	const double rise = s[SW_RISE];
	if (rise < 1.0 && !dead) { // the rise-in: forming, rising to its hover
		lift = lerpd(lift, 0.08, (1.0 - rise) * (1.0 - rise));
	}
	double gone = s[SW_GONE];
	if (dead) {
		lift = death_pose(d, die_u, limp, calm, lift);
		gone = maxd(gone, sstep(0.55, 1.0, die_u));
	}
	d[FORM] = f32(-gone);
	d[SCATTER] = f32(lerpd(double(d[SCATTER]), 1.0, gone));
	for (int j = 0; j < DRIVES; j++) {
		if (!VAT_DRIVES[j].loop && VAT_DRIVES[j].hi > VAT_DRIVES[j].lo) {
			d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
		}
	}
	d[ORBIT] = f32(s[SW_ORBIT]);
	double glow = SHARD_REST + SHARD_TELL * tell;
	double visor = VISOR_REST + VISOR_TELL * tell;
	if (wind > 0.6 && !calm) { // the star flickers as it gathers to blink
		visor += 0.8 * sin_d(t * TAU_D * 9.0) * (wind - 0.6) / 0.4;
	}
	const double dim = 1.0 - 0.75 * s[SW_REEL];
	glow *= dim * lerpd(0.3, 1.0, rise);
	visor *= dim * lerpd(0.3, 1.0, rise);
	if (dead) {
		const double flare = sin_d(PI_D * clampd(die_u / 0.2, 0.0, 1.0));
		const double out = 1.0 - sstep(0.3, 0.9, die_u);
		glow = (glow + 3.0 * flare) * out;
		visor = (visor + 2.0 * flare) * out;
	}
	d[VISOR] = f32(visor);
	for (int j = 0; j < DRIVES; j++) {
		s[SW_VD + j] = d[j];
	}
	s[SW_LIFT] = lift;
	s[SW_SHARD_GLOW] = maxd(glow, 0.0);
	const double sh = clampd(1.25 - 0.3 * lift / HOVER_LIFT, 0.5, 1.2) * (1.0 - 0.8 * gone);
	s[SW_SHADOW] = f32(sh);
}

} // namespace

// StarWarperAvatar.apply_state from a sync (`more`: its HP, whether it is stunned).
void sw_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const int was = int(s[SW_STATE]);
	const bool fresh = s[FRESH] != 0.0;
	s[SW_STATE] = state;
	s[SW_WIND] = state == c.st.windup ? clampd(windup, 0.0, 1.0) : 0.0;
	s[SW_STUN] = more[1] != 0.0 ? 1.0 : 0.0;
	const int64_t hp = int64_t(more[0]);
	const int64_t had = int64_t(s[SW_HP]);
	if (!fresh && hp >= 0 && had >= 0 && hp < had) {
		s[SW_HURT_T] = 0.0;
		s[SW_HURT_SIDE] = -s[SW_HURT_SIDE];
	}
	s[SW_HP] = double(hp);
	if (state == c.st.active && was != c.st.active) {
		s[SW_SLASH] = 0.0; // the blink: it reforms on its mark, striking
	}
	// _track_motion(tick, pos, TELEPORT_SPEED)
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
		const bool spawning = state == c.st.spawn;
		s[SW_RISE] = spawning ? 0.0 : 1.0;
		s[SW_GONE] = spawning ? 1.0 : 0.0;
		sw_pose(s, c);
	}
}

// StarWarperAvatar.advance (`f`: the facing's yaw, get_parent().rotation.y).
void sw_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[SW_DIE] >= 0.0;
	const bool calm = c.calm;
	// _turning
	const double fy = double(f.facing_yaw);
	s[SW_OMEGA] = rig::turning(s[SW_OMEGA], fy, s[SW_LAST_FY], s[SW_HAVE_FY] != 0.0 && !dying, dt, ease_rate(6.0, dt));
	s[SW_LAST_FY] = fy;
	s[SW_HAVE_FY] = 1.0;
	const int state = int(s[SW_STATE]);
	if (!dying) {
		const bool spawning = state == c.st.spawn;
		s[SW_RISE] = toward(s[SW_RISE], spawning ? 0.0 : 1.0, dt * 1.5);
		// The form: whole, broken into shards through the windup's end, reforming fast after; formed out of the
		// shards as it rises in.
		double gone = 0.0;
		if (state == c.st.windup) {
			gone = sstep(DISSOLVE_FROM, 1.0, s[SW_WIND]);
		} else if (spawning) {
			gone = 1.0 - sstep(0.0, 0.8, s[SW_RISE]);
		}
		s[SW_GONE] = gone > s[SW_GONE] ? gone : toward(s[SW_GONE], gone, dt * REFORM_RATE);
		s[SW_REEL] = toward(s[SW_REEL], s[SW_STUN] != 0.0 ? 1.0 : 0.0, dt * 4.0);
	}
	if (s[SW_SLASH] >= 0.0) {
		s[SW_SLASH] += dt;
		if (s[SW_SLASH] >= SLASH_END_S) {
			s[SW_SLASH] = -1.0;
		}
	}
	s[SW_HURT_T] = rig::clip(s[SW_HURT_T], dt, HURT_SECONDS);
	if (dying) {
		s[SW_DIE] += dt;
	}
	// Basis(Vector3.UP, -_last_fy) * SimPlane.to_3d(_vel)
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	const Vector3 v3 = axis_angle(UP, f32(-s[SW_LAST_FY])).xform(Vector3(vel.x, 0.0f, -vel.y));
	const Vector2 local(v3.x, v3.z);
	const double speed = dying ? 0.0 : double(local.length());
	s[SW_GLIDE] = lerpd(s[SW_GLIDE], clampd(speed / GLIDE_MPS, 0.0, 1.0), ease_rate(6.0, dt));
	if (speed > 0.05) {
		const Vector2 dir(f32(s[SW_DIR]), f32(s[SW_DIR + 1]));
		const Vector2 now = dir.lerp(local / f32(speed), f32(ease_rate(8.0, dt))).normalized();
		s[SW_DIR] = now.x;
		s[SW_DIR + 1] = now.y;
	}
	s[SW_WAVE] = Math::fposmod(
			s[SW_WAVE] + TAU_D * lerpd(WAVE_HZ, WAVE_GLIDE_HZ, s[SW_GLIDE]) * dt * (calm ? CALM : 1.0), TAU_D);
	if (!calm && !dying) {
		const double spin = ORBIT_RATE * (1.0 + 3.0 * s[SW_WIND]) * (1.0 - 0.7 * s[SW_REEL]);
		s[SW_ORBIT] = Math::fposmod(s[SW_ORBIT] + spin * dt, TAU_D);
	}
	sw_pose(s, c);
}

// StarWarperAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the shards' turn looped, the visor's glow sent as
// it is).
int sw_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[SW_VD + i]));
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
