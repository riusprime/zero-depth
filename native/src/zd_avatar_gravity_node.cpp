// The Gravity Node's avatar on a batch row (zd_avatar.h GN_*): GravityNodeAvatar's sync (apply_state), frame step
// (advance, _turning) and pose (_pose, _hover_pose, _pull_pose, _turn_pose, _hurt_pose, _rise_pose, _death_pose,
// _core_energy, _visor), ported line by line in the same order and float width as the GDScript
// (src/presentation/world_view/gravity_node_avatar.gd): its clocks, spins, draw, lift and glows are doubles (GDScript
// floats), its raw drives floats (its PackedFloat32Array: each `d[j] += x` reads the float, works in double and
// stores a float), the ground disc's scale a float (what its node's Vector3 stores). The swirl on the floor is
// StarfallViews', read from the sim, not the avatar's.
// tests/unit/native/test_native_crowd_gravity_node.gd holds the drawn buffers and the ground disc equal to the
// GDScript avatar's bit for bit.

#include "zd_avatar.h"
#include "zd_legged_rig.h"

#include <cmath>
#include <cstdint>
#include <initializer_list>

#include <godot_cpp/core/math.hpp>

using namespace godot;

namespace zd {
namespace av {

namespace {

constexpr double PI_D = 3.1415926535897932384626433833;
constexpr double TAU_D = 6.2831853071795864769252867666;
// GravityNodeAvatar
constexpr double HOVER_LIFT = 0.72;
constexpr double CORE_REST = 0.12;
constexpr double CORE_DRAW = 1.5;
constexpr double CORE_FLASH = 1.2;
constexpr double VISOR_REST = 1.4;
constexpr double VISOR_DRAW = 3.2;
constexpr double SPIN_A = 1.3;
constexpr double SPIN_B = -1.7;
constexpr double SPIN_DRAW = 2.2;
constexpr double SPIN_CALM = 0.6;
constexpr double BEATS = 2.0;
constexpr double HURT_SECONDS = 0.9;
constexpr double DEATH_SECONDS = 1.4;
constexpr double BOB_HZ = 0.45;
constexpr double BREATH_HZ = 0.35;
constexpr double CALM = 0.45;
constexpr double TURN_REF = 3.0;
constexpr double FLOOR_LIFT = 0.03;
constexpr int RINGS = 2;

// The raw drives (GravityNodeAvatar's ROLL ... VISOR; each ring's FLY, TIP, SIZE, SPIN from RING0).
enum Drive {
	ROLL = 0,
	PITCH = 1,
	YAW = 2,
	CORE = 3,
	UP_LIFT = 4,
	UP_TILT = 5,
	LOW_DROP = 6,
	LOW_TILT = 7,
	RING0 = 8,
	FLY = 0,
	TIP = 1,
	SIZE = 2,
	SPIN = 3,
	VISOR = 16,
	DRIVES = 17,
};

// VAT_DRIVES: [lo, hi, loop] (the rings' spins loop; the visor's [0, 0] is sent as it is).
struct Spec {
	double lo, hi;
	bool loop;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.8, 0.8, false }, // ROLL
	{ -0.8, 0.8, false }, // PITCH
	{ -0.7, 0.7, false }, // YAW
	{ -0.4, 0.3, false }, // CORE
	{ -0.03, 0.2, false }, // UP_LIFT
	{ -0.3, 0.9, false }, // UP_TILT
	{ -0.03, 0.2, false }, // LOW_DROP
	{ -0.3, 0.9, false }, // LOW_TILT
	{ 0.0, 1.0, false }, // ring_a FLY
	{ -1.7, 1.7, false }, // ring_a TIP
	{ -0.35, 0.15, false }, // ring_a SIZE
	{ 0.0, TAU_D, true }, // ring_a SPIN
	{ 0.0, 1.0, false }, // ring_b FLY
	{ -1.7, 1.7, false }, // ring_b TIP
	{ -0.35, 0.15, false }, // ring_b SIZE
	{ 0.0, TAU_D, true }, // ring_b SPIN
	{ 0.0, 0.0, false }, // VISOR
};

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

// d[j] op= x on the PackedFloat32Array: the float read as a double, the result stored as a float.
inline void add(float *d, int j, double x) {
	d[j] = f32(double(d[j]) + x);
}
inline void sub(float *d, int j, double x) {
	d[j] = f32(double(d[j]) - x);
}
inline void mul(float *d, int j, double x) {
	d[j] = f32(double(d[j]) * x);
}

// The pose's inputs read off the row once (the GDScript's fields).
struct P {
	double t, draw, rise, beat, omega, hurt, hurt_side, die;
};

// GravityNodeAvatar._hover_pose
void hover_pose(const P &p, float *d, double k, double breath) {
	const double t = p.t;
	add(d, ROLL, k * 0.06 * sin_d(0.7 * t));
	add(d, PITCH, k * 0.05 * sin_d(0.55 * t + 1.0));
	add(d, YAW, k * 0.08 * sin_d(0.3 * t + 0.5));
	const double open = 0.5 * (breath + 1.0);
	add(d, UP_LIFT, 0.012 * open);
	add(d, UP_TILT, 0.05 * open * k);
	add(d, LOW_DROP, 0.008 * open);
	add(d, LOW_TILT, 0.035 * open * k);
	add(d, CORE, 0.03 * breath * k);
	const double settle = 1.0 - 0.7 * p.draw;
	add(d, RING0 + TIP, k * settle * 0.12 * sin_d(0.8 * t));
	add(d, RING0 + 4 + TIP, k * settle * 0.1 * sin_d(0.65 * t + 2.0));
}

// GravityNodeAvatar._pull_pose
void pull_pose(const P &p, float *d, double k) {
	const double q = sstep(0.0, 1.0, p.draw);
	if (q <= 0.0) {
		return;
	}
	for (int r = 0; r < RINGS; r++) {
		sub(d, RING0 + 4 * r + SIZE, 0.14 * q);
	}
	add(d, UP_LIFT, 0.07 * q);
	add(d, UP_TILT, 0.32 * q);
	add(d, LOW_DROP, 0.05 * q);
	add(d, LOW_TILT, 0.22 * q);
	const double sink = p.beat < 0.25 ? sin_d(PI_D * clampd(p.beat / 0.25, 0.0, 1.0)) : 0.0;
	add(d, CORE, 0.06 * q - 0.18 * q * sink * k);
}

// GravityNodeAvatar._turn_pose
void turn_pose(const P &p, float *d, double k) {
	const double w = clampd(p.omega / TURN_REF, -1.0, 1.0);
	sub(d, YAW, 0.35 * w * k);
	add(d, ROLL, 0.12 * w * k);
	add(d, RING0 + TIP, 0.25 * w * k);
	sub(d, RING0 + 4 + TIP, 0.3 * w * k);
}

// GravityNodeAvatar._hurt_pose: returns the lift's change.
double hurt_pose(const P &p, float *d, double k, bool calm) {
	if (p.hurt < 0.0) {
		return 0.0;
	}
	const double u = p.hurt / HURT_SECONDS;
	double env = (1.0 - sstep(0.0, 1.0, u)) * sstep(0.0, 0.05, u);
	double swing = sin_d(TAU_D * 2.2 * p.hurt);
	if (calm) {
		swing = 1.0;
		env = sin_d(PI_D * clampd(u / 0.7, 0.0, 1.0));
	}
	const double s = p.hurt_side;
	add(d, ROLL, 0.22 * s * env * swing * k);
	add(d, PITCH, 0.12 * env * swing * k);
	add(d, RING0 + TIP, 0.45 * s * env * swing * k);
	sub(d, RING0 + 4 + TIP, 0.5 * s * env * (calm ? swing : sin_d(TAU_D * 1.8 * p.hurt + 0.3)) * k);
	const double clap = 1.0 - sstep(0.0, 0.5, u);
	mul(d, UP_TILT, 1.0 - clap);
	mul(d, LOW_TILT, 1.0 - clap);
	mul(d, UP_LIFT, 1.0 - clap);
	mul(d, LOW_DROP, 1.0 - clap);
	return -0.06 * env * k;
}

// GravityNodeAvatar._rise_pose: returns the lift.
double rise_pose(const P &p, float *d, double lift) {
	if (p.die >= 0.0) {
		return lift;
	}
	const double r = 1.0 - p.rise;
	if (r <= 0.0) {
		return lift;
	}
	const double e = r * r;
	for (int k = 0; k < RINGS; k++) {
		sub(d, RING0 + 4 * k + SIZE, 0.3 * e);
		mul(d, RING0 + 4 * k + TIP, 1.0 - r);
	}
	for (int j : { UP_LIFT, UP_TILT, LOW_DROP, LOW_TILT }) {
		mul(d, j, 1.0 - r);
	}
	sub(d, CORE, 0.25 * e);
	return lerpd(lift, 0.12, e);
}

// GravityNodeAvatar._death_pose: returns the lift.
double death_pose(const P &p, float *d, double lift, bool calm) {
	if (p.die < 0.0) {
		return lift;
	}
	const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
	const double keep = 1.0 - sstep(0.0, 0.25, u);
	for (int j = 0; j < RING0; j++) {
		mul(d, j, keep);
	}
	for (int r = 0; r < RINGS; r++) {
		mul(d, RING0 + 4 * r + TIP, keep);
		mul(d, RING0 + 4 * r + SIZE, keep);
	}
	const double flare = sin_d(PI_D * clampd(u / 0.2, 0.0, 1.0));
	add(d, CORE, 0.15 * flare);
	const double split = sstep(0.08, 0.4, u);
	add(d, UP_LIFT, 0.16 * split * (1.0 - sstep(0.45, 0.75, u))); // thrown up, then down onto it
	add(d, UP_TILT, 0.75 * split);
	add(d, LOW_DROP, 0.05 * split);
	add(d, LOW_TILT, 0.5 * split);
	const double fly = sstep(0.1, 0.55, u);
	for (int r = 0; r < RINGS; r++) {
		d[RING0 + 4 * r + FLY] = f32(fly);
		add(d, RING0 + 4 * r + TIP, (r == 0 ? 1.2 : -1.3) * fly);
	}
	// The fall: eased in (it drops), a small bounce on landing (none with reduced motion), then it lies there.
	const double f = clampd((u - 0.15) / 0.4, 0.0, 1.0);
	double at = lerpd(lift, FLOOR_LIFT, f * f);
	if (!calm && u > 0.55) {
		at += 0.06 * sin_d(PI_D * clampd((u - 0.55) / 0.15, 0.0, 1.0));
	}
	const double tip = sstep(0.45, 0.85, u);
	add(d, ROLL, 0.6 * tip);
	sub(d, PITCH, 0.2 * tip);
	return at;
}

// GravityNodeAvatar._core_energy
double core_energy(const P &p, bool calm, double breath) {
	double e = CORE_REST * (1.0 + 0.3 * (calm ? 0.4 : 1.0) * breath) + CORE_DRAW * p.draw;
	if (p.beat > 0.0) {
		e += CORE_FLASH * p.draw * (1.0 - sstep(0.0, 0.5, p.beat));
	}
	if (p.hurt >= 0.0) {
		e += 1.5 * (1.0 - p.hurt / HURT_SECONDS);
	}
	e *= p.die < 0.0 ? lerpd(0.25, 1.0, p.rise) : 1.0;
	if (p.die >= 0.0) {
		const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
		e = lerpd(e, 0.03, sstep(0.2, 0.6, u)) + 3.0 * sin_d(PI_D * clampd(u / 0.2, 0.0, 1.0));
	}
	return e;
}

// GravityNodeAvatar._visor
double visor(const P &p, double breath) {
	double e = VISOR_REST + 0.3 * breath + (VISOR_DRAW - VISOR_REST) * p.draw;
	e *= p.die < 0.0 ? lerpd(0.3, 1.0, p.rise) : 1.0;
	if (p.die >= 0.0) {
		e = lerpd(e, 0.1, sstep(0.15, 0.6, clampd(p.die / DEATH_SECONDS, 0.0, 1.0)));
	}
	return e;
}

// GravityNodeAvatar._pose on a VAT avatar (no nodes): the drives, the lift, the core's glow and the ground disc's
// scale.
void gn_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double k = calm ? CALM : 1.0;
	float d[DRIVES] = {};
	P p;
	p.t = s[T];
	p.draw = s[GN_DRAW];
	p.rise = s[GN_RISE];
	p.beat = s[GN_BEAT];
	p.omega = s[GN_OMEGA];
	p.hurt = s[GN_HURT];
	p.hurt_side = s[GN_HURT_SIDE];
	p.die = s[GN_DIE];
	const double breath = sin_d(TAU_D * p.t * BREATH_HZ);
	double lift = HOVER_LIFT + 0.05 * k * sin_d(TAU_D * p.t * BOB_HZ);
	hover_pose(p, d, k, breath);
	pull_pose(p, d, k);
	turn_pose(p, d, k);
	lift += hurt_pose(p, d, k, calm);
	lift = rise_pose(p, d, lift);
	lift = death_pose(p, d, lift, calm);
	for (int r = 0; r < RINGS; r++) {
		d[RING0 + 4 * r + SPIN] = f32(r == 0 ? s[GN_SPIN_A] : s[GN_SPIN_B]);
	}
	for (int j = 0; j < VISOR; j++) {
		if (!VAT_DRIVES[j].loop) {
			d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
		}
	}
	s[GN_CORE_GLOW] = core_energy(p, calm, breath);
	d[VISOR] = f32(visor(p, breath));
	for (int j = 0; j < DRIVES; j++) {
		s[GN_VD + j] = d[j];
	}
	s[GN_LIFT] = lift;
	s[GN_SHADOW] = f32(clampd(1.15 - 0.45 * lift / HOVER_LIFT, 0.5, 1.2));
}

} // namespace

// GravityNodeAvatar.apply_state from a sync (`more`: its HP, then its draw on the hero).
void gn_apply(double *s, int state, const double *more, const Ctx &c) {
	const int64_t hp = int64_t(more[0]);
	const bool fresh = s[FRESH] != 0.0;
	if (fresh) {
		s[GN_RISE] = state == c.st.spawn ? 0.0 : 1.0;
	} else {
		const int64_t had = int64_t(s[GN_HP]);
		if (hp >= 0 && had >= 0 && hp < had) {
			s[GN_HURT] = 0.0;
			s[GN_HURT_SIDE] = -s[GN_HURT_SIDE];
		}
	}
	s[GN_STATE] = state;
	s[GN_HP] = double(hp);
	s[GN_DRAW_TO] = clampd(more[1], 0.0, 1.0);
	if (fresh) {
		s[FRESH] = 0.0;
		gn_pose(s, c);
	}
}

// GravityNodeAvatar.advance (`f`: the facing's yaw, get_parent().rotation.y).
void gn_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[GN_DIE] >= 0.0;
	const bool calm = c.calm;
	// _turning
	const double fy = double(f.facing_yaw);
	s[GN_OMEGA] = rig::turning(s[GN_OMEGA], fy, s[GN_LAST_FY], s[GN_HAVE_FY] != 0.0 && !dying, dt, ease_rate(6.0, dt));
	s[GN_LAST_FY] = fy;
	s[GN_HAVE_FY] = 1.0;
	const bool spawning = int(s[GN_STATE]) == c.st.spawn;
	if (!dying) {
		s[GN_RISE] = toward(s[GN_RISE], spawning ? 0.0 : 1.0, dt * 1.6);
	}
	s[GN_DRAW] = toward(s[GN_DRAW], dying ? 0.0 : s[GN_DRAW_TO], dt * 2.0);
	// The rings' turn: steady at rest, faster with the draw, spun up through the rise-in, slowing to a stop in the
	// death; one slow steady rate with reduced motion.
	double rate = 1.0 + SPIN_DRAW * s[GN_DRAW];
	if (calm) {
		rate = SPIN_CALM;
	}
	rate *= !dying ? lerpd(2.5, 1.0, s[GN_RISE]) : maxd(0.0, 1.0 - s[GN_DIE] / (DEATH_SECONDS * 0.6));
	s[GN_SPIN_A] = Math::fposmod(s[GN_SPIN_A] + SPIN_A * rate * dt, TAU_D);
	s[GN_SPIN_B] = Math::fposmod(s[GN_SPIN_B] + SPIN_B * rate * dt, TAU_D);
	s[GN_BEAT] = s[GN_DRAW] > 0.0 && !calm ? Math::fposmod(s[GN_BEAT] + dt * BEATS * s[GN_DRAW], 1.0) : 0.0;
	s[GN_HURT] = rig::clip(s[GN_HURT], dt, HURT_SECONDS);
	if (dying) {
		s[GN_DIE] += dt;
	}
	gn_pose(s, c);
}

// GravityNodeAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the rings' spins looped, the visor's glow sent
// as it is).
int gn_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[GN_VD + i]));
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
