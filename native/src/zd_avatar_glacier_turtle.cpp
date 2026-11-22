// The Glacier Turtle's avatar on a batch row (zd_avatar.h GT_*): GlacierTurtleAvatar's sync (apply_state), frame step
// (advance, _turning) and pose (_pose and its clips, _body_xf, _reach, _shield_size, _heft, the visor's glow), ported
// line by line in the same order and float width as the GDScript (src/presentation/world_view/glacier_turtle_avatar.gd):
// its numbers are doubles, its raw drives (a PackedFloat32Array), its Vector2s, Vector3s and transforms floats, the
// visor's glow a material's float, and a component read off one of those a double in the arithmetic around it, as
// GDScript reads it. Its clips' timers and idle motions are the Frost Spitter's helpers, which are LeggedRig's
// (zd_legged_rig.h). tests/unit/native/test_native_crowd_glacier_turtle.gd holds the drawn buffers equal to the
// GDScript avatar's bit for bit.

#include "zd_avatar.h"

#include <cmath>
#include <cstdint>
#include <initializer_list>

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include "zd_legged_rig.h"

using namespace godot;

namespace zd {
namespace av {

namespace {

constexpr double PI_D = 3.1415926535897932384626433833;
constexpr double TAU_D = 6.2831853071795864769252867666;
constexpr int MOTION_GAP_TICKS = 30;
// AvatarBase
constexpr double TELL_FLASH_FROM = 0.8;
constexpr double TELL_FLICKER_HZ = 9.0;
// GlacierTurtleAvatar
constexpr double VISOR_REST = 1.6;
constexpr double VISOR_TELL = 6.5;
constexpr double VISOR_BRACE = 2.0;
constexpr double TELEPORT_SPEED = 30.0;
constexpr double SLAM_SECONDS = 0.9;
constexpr double BRACE_SECONDS = 0.4;
constexpr double BREAK_SECONDS = 0.75;
constexpr double HURT_SECONDS = 0.35;
constexpr double DEATH_SECONDS = 1.2;
constexpr double POP_SECONDS = 0.06;
constexpr double MOVE_SPEED = 1.1;
constexpr double DUTY = 0.6;
constexpr double SWEEP = 0.11;
constexpr double BARE_SWEEP = 0.75;
constexpr double LIFT = 0.06;
constexpr double STRIDE_MAX = 1.3;
constexpr double GATHER[4] = { -0.04, -0.04, 0.04, 0.04 };
constexpr double CROUCH = 0.045;
constexpr double TURN_REF = 0.8;
constexpr double TURN_SWING = 0.2;
constexpr int LEGS = 4;
constexpr double STRIDE_AT[LEGS] = { 0.0, 0.5, 0.56, 0.06 };
constexpr double BREATH_HZ = 0.32;
constexpr double BARE_BREATH = 1.7;
constexpr double CALM = 0.45;

const Vector3 UP(0, 1, 0);
const Vector3 RIGHT(1, 0, 0);
const Vector3 BACK(0, 0, 1);
const Vector3 ROLL_AT(0.0, 0.2, 0.0);
const Vector3 PITCH_AT(-0.5, 0.03, 0.0);
// FEET: the feet's tips (m, the model's frame, before its scale).
const Vector3 FEET[LEGS] = {
	Vector3(0.279, 0.013, 0.386),
	Vector3(0.279, 0.013, -0.386),
	Vector3(-0.506, 0.013, 0.399),
	Vector3(-0.506, 0.013, -0.399),
};

// The raw drives (GlacierTurtleAvatar's SURGE ... the legs').
enum Drive {
	SURGE = 0,
	ROLL = 1,
	PITCH = 2,
	SWAY = 3,
	HEAD_P = 4,
	HEAD_Y = 5,
	BACK_UP = 6,
	BACK_P = 7,
	SHIELD_UP = 8,
	SHIELD_P = 9,
	SHIELD_R = 10,
	SHIELD_ON = 11,
	LEG0 = 12,
	DRIVES = 24,
};

// VAT_DRIVES: [lo, hi] (none loops, none spans nothing).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.12, 0.12 },
	{ -0.3, 0.3 },
	{ -0.35, 0.45 },
	{ -0.3, 0.3 },
	{ -0.6, 0.6 },
	{ -0.7, 0.7 },
	{ -0.04, 0.05 },
	{ -0.2, 0.2 },
	{ -0.1, 0.4 },
	{ -1.4, 0.5 },
	{ -0.3, 0.3 },
	{ 0.0, 1.15 },
	{ -0.7, 0.7 }, { -1.3, 1.3 }, { -1.8, 1.8 },
	{ -0.7, 0.7 }, { -1.3, 1.3 }, { -1.8, 1.8 },
	{ -0.7, 0.7 }, { -1.3, 1.3 }, { -1.8, 1.8 },
	{ -0.7, 0.7 }, { -1.3, 1.3 }, { -1.8, 1.8 },
};

// GDScript's utility functions on doubles.
inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline double maxd(double a, double b) {
	return a > b ? a : b;
}
inline double mind(double a, double b) {
	return a < b ? a : b;
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
inline double signd(double v) {
	return v > 0.0 ? 1.0 : (v < 0.0 ? -1.0 : 0.0);
}
inline double wrap_pi(double v) {
	return Math::wrapf(v, -PI_D, PI_D);
}
inline float f32(double v) {
	return float(v);
}
inline Transform3D at(const Vector3 &p) {
	return Transform3D(Basis(), p);
}

// d[j] op= x: the packed float read as a double, the result stored as a float.
inline void add(float *d, int j, double x) {
	d[j] = f32(double(d[j]) + x);
}
inline void sub(float *d, int j, double x) {
	d[j] = f32(double(d[j]) - x);
}
inline void mul(float *d, int j, double x) {
	d[j] = f32(double(d[j]) * x);
}
inline void lerp_to(float *d, int j, double to, double w) {
	d[j] = f32(lerpd(double(d[j]), to, w));
}

inline bool tell_flashing(double p) {
	return p >= TELL_FLASH_FROM && p <= 1.0;
}

inline Vector3 vec_at(const double *s, int at) {
	return Vector3(f32(s[at]), f32(s[at + 1]), f32(s[at + 2]));
}

// The pose's inputs read off the row once (the GDScript's fields), and the feet's offsets the clips ask for (_foot).
struct P {
	double t, bare, speed, omega, phase, stride, coil, rise, slam, brace, brk, hurt, die, tell;
	int state, shell, hurt_leg;
	Vector2 dir;
	Vector3 hips[LEGS], knees[LEGS], feet[LEGS];
	Vector3 foot[LEGS];
	double lift = 0.0;
};

double sweep_of(double bare) {
	return SWEEP * lerpd(1.0, BARE_SWEEP, bare);
}

double heft(double t) {
	const double u = t / 5.2 + 1.0;
	const double seg = std::floor(u);
	if (rig::hash01(seg + 53.0) < 0.45) {
		return 0.0;
	}
	const double f = u - seg;
	const double up = sstep(0.3, 0.38, f) * (1.0 - sstep(0.5, 0.56, f));
	return up - 0.35 * sin_d(PI_D * clampd((f - 0.56) / 0.05, 0.0, 1.0));
}

double walk_pose(P &p, float *d, double k) {
	const double g = clampd(p.stride, 0.0, 1.0);
	const double walk = clampd(p.speed / MOVE_SPEED, 0.0, STRIDE_MAX);
	const double turn = clampd(p.omega / TURN_REF, -1.0, 1.0);
	const Vector3 dir(p.dir.x, 0.0f, p.dir.y);
	const double sweep = sweep_of(p.bare);
	for (int j = 0; j < LEGS; j++) {
		const Vector2 c = rig::leg_cycle(Math::fposmod(p.phase - STRIDE_AT[j], 1.0), DUTY);
		const Vector3 tip = p.feet[j];
		const double th = turn * TURN_SWING * double(c.x);
		p.foot[j] += dir * f32(walk * sweep * double(c.x)) +
				Vector3(f32(mind(walk, 1.0) * GATHER[j] + th * double(tip.z)), f32(LIFT * g * double(c.y)),
						f32(-th * double(tip.x)));
	}
	add(d, HEAD_Y, 0.3 * turn * k); // the head leads a turn
	sub(d, SHIELD_R, 0.04 * turn * k); // and the shield swings after it
	if (g <= 0.0) {
		return 0.0;
	}
	const double ph = p.phase;
	const double w = mind(walk, 1.0);
	const double rock = 1.0 + 0.6 * p.bare;
	add(d, ROLL, g * k * 0.05 * rock * sin_d(TAU_D * (ph - 0.1)));
	add(d, SWAY, w * k * 0.04 * sin_d(TAU_D * (ph + 0.15)));
	add(d, PITCH, w * k * 0.012 * sin_d(2.0 * TAU_D * (ph - 0.1)));
	sub(d, HEAD_Y, w * k * 0.04 * sin_d(TAU_D * (ph + 0.15)));
	add(d, HEAD_P, w * k * 0.05 * cos_d(2.0 * TAU_D * (ph - 0.2)) - w * 0.04);
	add(d, BACK_UP, g * k * 0.006 * sin_d(2.0 * TAU_D * (ph - 0.18)));
	add(d, BACK_P, g * k * 0.02 * sin_d(2.0 * TAU_D * (ph - 0.25)));
	add(d, SHIELD_P, g * k * 0.025 * sin_d(2.0 * TAU_D * (ph - 0.3)));
	add(d, SHIELD_R, g * k * 0.03 * sin_d(TAU_D * (ph - 0.3)));
	return -CROUCH * w - g * k * 0.014 * cos_d(2.0 * TAU_D * (ph - 0.05));
}

double idle_pose(P &p, float *d, double k, bool calm, double breath) {
	const double idle = (1.0 - clampd(p.stride, 0.0, 1.0)) * (1.0 - p.coil) * (p.die < 0.0 ? 1.0 : 0.0);
	if (idle <= 0.0) {
		return 0.0;
	}
	const double t = p.t;
	const double every = lerpd(3.0, 1.1, p.bare); // bare, it darts its looks
	add(d, BACK_UP, idle * k * 0.007 * (breath + 1.0));
	sub(d, BACK_P, idle * k * 0.012 * breath);
	add(d, HEAD_Y, idle * k * 0.4 * rig::scan(t, every, 0.0));
	add(d, HEAD_P, idle * k * (0.08 * rig::scan(t, every * 1.3, 5.0) + 0.02 * (breath + 1.0)));
	add(d, ROLL, idle * k * 0.02 * sin_d(0.5 * t));
	add(d, SWAY, idle * k * 0.025 * sin_d(0.35 * t + 0.4));
	add(d, SHIELD_R, idle * k * 0.015 * sin_d(0.45 * t + 1.1));
	add(d, SHIELD_P, idle * k * 0.01 * breath);
	if (!calm) {
		add(d, HEAD_P, idle * 0.07 * rig::twitch(t, 4.4, 11.0)); // a sniff
		const double hf = heft(t) * (1.0 - p.bare);
		add(d, SHIELD_UP, idle * 0.035 * hf);
		add(d, SHIELD_P, idle * 0.04 * hf);
		sub(d, HEAD_P, idle * 0.05 * hf);
	}
	// A foot re-planted now and then (a different one each time): lifted, carried a little and set down.
	const double u = t / 3.4;
	const double seg = std::floor(u);
	if (rig::hash01(seg + 7.0) > 0.4) {
		const int j = int(int64_t(rig::hash01(seg + 3.0) * double(LEGS)) % LEGS);
		const double e = sin_d(PI_D * clampd((u - seg - 0.2) / 0.22, 0.0, 1.0));
		p.foot[j] += Vector3(0.02, 0.045, 0.0) * f32(e) * f32(idle);
	}
	return -idle * k * 0.004 * (breath + 1.0);
}

double bare_pose(P &p, float *d, double k, bool calm) {
	if (p.bare <= 0.0) {
		return 0.0;
	}
	const double b = p.bare;
	sub(d, BACK_UP, 0.018 * b);
	sub(d, BACK_P, 0.04 * b * k);
	sub(d, HEAD_P, 0.12 * b);
	sub(d, SURGE, 0.02 * b);
	if (!calm) {
		const double still = (1.0 - clampd(p.stride, 0.0, 1.0)) * (p.die < 0.0 ? 1.0 : 0.0);
		add(d, ROLL, 0.008 * b * still * sin_d(TAU_D * 7.0 * p.t));
		add(d, HEAD_Y, 0.02 * b * still * sin_d(TAU_D * 5.0 * p.t + 0.6));
	}
	return -0.025 * b;
}

double tell_pose(P &p, float *d, double k, bool calm, const States &st) {
	const double q = p.coil;
	if (q <= 0.0) {
		return 0.0;
	}
	const double crouch = sin_d(PI_D * clampd(q / 0.3, 0.0, 1.0)) * (1.0 - sstep(0.1, 0.35, q));
	const double rear = sstep(0.12, 0.75, q);
	add(d, PITCH, (0.27 * rear - 0.04 * crouch) * k);
	sub(d, SURGE, 0.04 * rear * k);
	add(d, HEAD_P, 0.25 * rear * k - 0.08 * crouch);
	mul(d, HEAD_Y, 1.0 - rear);
	add(d, BACK_P, 0.05 * rear * k);
	sub(d, SHIELD_P, 0.22 * rear * k); // its face kept upright as the body tips back
	add(d, SHIELD_UP, 0.05 * rear * k);
	for (int j = 0; j < 2; j++) { // the front feet lift and reach
		p.foot[j] += Vector3(0.05, 0.1, 0.0) * f32(rear) * f32(k);
	}
	if (!calm && p.state == st.windup) {
		const double top = sstep(0.75, 0.9, q);
		add(d, ROLL, 0.012 * top * sin_d(TAU_D * 13.0 * p.t));
		add(d, SHIELD_R, 0.02 * top * sin_d(TAU_D * 11.0 * p.t + 0.5));
		add(d, HEAD_P, 0.03 * top * sin_d(TAU_D * 9.0 * p.t + 1.0));
	}
	return -0.03 * crouch * k;
}

double slam_pose(P &p, float *d, double k, bool calm) {
	if (p.slam < 0.0) {
		return 0.0;
	}
	const double u = p.slam / SLAM_SECONDS;
	const double crash = sstep(0.0, 0.08, u) * (1.0 - sstep(0.35, 0.95, u));
	const double bounce = sin_d(PI_D * clampd((u - 0.06) / 0.25, 0.0, 1.0));
	sub(d, PITCH, 0.06 * crash * k);
	add(d, SURGE, 0.04 * crash * k);
	sub(d, HEAD_P, 0.18 * crash * k);
	add(d, BACK_UP, 0.025 * bounce * k);
	sub(d, BACK_P, 0.06 * bounce * k);
	sub(d, SHIELD_P, 0.2 * crash * k);
	for (int j = 0; j < 2; j++) { // the front feet stamped out wide
		p.foot[j] += Vector3(0.04f, 0.0f, f32(0.09 * signd(double(p.feet[j].z)))) * f32(crash);
	}
	if (!calm) {
		const double rattle = 1.0 - sstep(0.1, 0.5, u);
		add(d, BACK_UP, 0.006 * rattle * sin_d(TAU_D * 17.0 * p.slam));
		add(d, ROLL, 0.025 * rattle * sin_d(TAU_D * 10.0 * p.slam + 0.7));
		add(d, SHIELD_R, 0.03 * rattle * sin_d(TAU_D * 13.0 * p.slam));
	}
	return -0.035 * crash * k;
}

double brace_pose(P &p, float *d, double k, bool calm) {
	if (p.brace < 0.0) {
		return 0.0;
	}
	const double h = p.brace / BRACE_SECONDS;
	const double e = sin_d(0.5 * PI_D * mind(h / 0.2, 1.0)) * (1.0 - sstep(0.2, 1.0, h));
	add(d, SHIELD_P, 0.1 * e * k);
	sub(d, SURGE, 0.025 * e * k);
	sub(d, HEAD_P, 0.12 * e * k);
	sub(d, BACK_UP, 0.008 * e);
	if (!calm) {
		add(d, SHIELD_R, 0.05 * e * sin_d(TAU_D * 18.0 * p.brace));
		add(d, SHIELD_P, 0.035 * e * sin_d(TAU_D * 15.0 * p.brace + 0.4));
	}
	return -0.018 * e * k;
}

double break_pose(P &p, float *d, double k, bool calm) {
	if (p.brk < 0.0) {
		return 0.0;
	}
	const double u = p.brk / BREAK_SECONDS;
	const double reel = sin_d(PI_D * mind(u / 0.25, 1.0) * 0.5) * (1.0 - sstep(0.35, 1.0, u));
	add(d, PITCH, 0.16 * reel * k);
	sub(d, SURGE, 0.06 * reel * k);
	add(d, HEAD_P, 0.3 * reel * k);
	add(d, BACK_UP, 0.012 * reel);
	for (int j = 0; j < 2; j++) {
		p.foot[j] += Vector3(-0.02, 0.06, 0.0) * f32(reel) * f32(k);
	}
	if (!calm) {
		const double shake = 1.0 - sstep(0.2, 0.7, u);
		add(d, HEAD_Y, 0.18 * shake * reel * sin_d(TAU_D * 7.0 * p.brk));
		add(d, ROLL, 0.03 * shake * sin_d(TAU_D * 9.0 * p.brk));
	}
	return 0.0;
}

double hurt_pose(P &p, float *d, double k, bool calm) {
	if (p.hurt < 0.0) {
		return 0.0;
	}
	const double h = p.hurt / HURT_SECONDS;
	const double e = sin_d(0.5 * PI_D * mind(h / 0.25, 1.0)) * (1.0 - sstep(0.25, 1.0, h));
	sub(d, SURGE, 0.03 * e * k);
	add(d, PITCH, 0.04 * e * k);
	sub(d, HEAD_P, 0.15 * e * k);
	add(d, BACK_UP, 0.008 * e);
	const int hl = p.hurt_leg;
	p.foot[hl] += Vector3(0.0f, 0.03f, f32(0.04 * signd(double(p.feet[hl].z)))) * f32(e) * f32(k);
	if (!calm) {
		add(d, BACK_P, 0.04 * e * sin_d(TAU_D * 12.0 * p.hurt));
		add(d, ROLL, 0.025 * e * sin_d(TAU_D * 11.0 * p.hurt));
	}
	return -0.012 * e * k;
}

double rise_pose(P &p, float *d) {
	const double r = 1.0 - p.rise;
	if (r <= 0.0) {
		return 0.0;
	}
	const double low = r * r * (1.0 - clampd(p.stride, 0.0, 1.0));
	for (int j = 0; j < LEGS; j++) {
		p.foot[j] += Vector3(f32(0.03 * signd(double(p.feet[j].x))), 0.0f, f32(0.03 * signd(double(p.feet[j].z)))) *
				f32(low);
	}
	sub(d, HEAD_P, 0.25 * r);
	sub(d, BACK_UP, 0.015 * r);
	return -0.12 * low;
}

double death_pose(P &p, float *d, double lift, bool calm) {
	if (p.die < 0.0) {
		return lift;
	}
	const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
	const double keep = 1.0 - sstep(0.0, 0.2, u);
	for (int j : { SURGE, ROLL, PITCH, SWAY, HEAD_Y, SHIELD_R }) {
		mul(d, j, keep);
	}
	lift *= keep;
	const double sag = sstep(0.08, 0.5, u);
	lerp_to(d, HEAD_P, -0.45, sstep(0.2, 0.7, u));
	add(d, ROLL, 0.09 * sag);
	lerp_to(d, BACK_P, -0.05, sag);
	lerp_to(d, BACK_UP, -0.02, sag);
	for (int j = 0; j < LEGS; j++) {
		const Vector3 tip = p.feet[j];
		const Vector3 out(f32(0.08 * signd(double(tip.x))), 0.0f, f32(signd(double(tip.z)) * 0.17));
		p.foot[j] = p.foot[j] * f32(keep) + out * f32(sag);
	}
	double fall = clampd((u - 0.1) / 0.45, 0.0, 1.0);
	fall *= fall;
	lerp_to(d, SHIELD_P, -1.3, fall);
	add(d, SHIELD_UP, 0.04 * fall);
	if (!calm) {
		const double land = sin_d(PI_D * clampd((u - 0.55) / 0.15, 0.0, 1.0));
		add(d, SHIELD_P, 0.12 * land);
		add(d, SHIELD_UP, 0.02 * land);
	}
	return lift - 0.1 * sag;
}

double visor(const P &p, bool calm, const States &st) {
	double e = VISOR_REST;
	if (p.state == st.windup && p.die < 0.0) {
		e = VISOR_REST + (VISOR_TELL - VISOR_REST) * crouch_of_tell(p.tell);
		if (tell_flashing(p.tell)) {
			e = calm || int64_t(p.t * TELL_FLICKER_HZ * 2.0) % 2 == 0 ? VISOR_TELL * 1.2 : VISOR_TELL * 0.8;
		}
	}
	if (p.slam >= 0.0) {
		e = maxd(e, VISOR_TELL * (1.0 - sstep(0.0, 0.5, p.slam / SLAM_SECONDS)));
	}
	if (p.brace >= 0.0) {
		e += VISOR_BRACE * (1.0 - p.brace / BRACE_SECONDS);
	}
	if (p.brk >= 0.0) {
		e += 2.0 * VISOR_BRACE * (1.0 - p.brk / BREAK_SECONDS);
	}
	e *= lerpd(0.4, 1.0, p.rise);
	if (p.die >= 0.0) {
		e = lerpd(e, 0.1, sstep(0.1, 0.6, clampd(p.die / DEATH_SECONDS, 0.0, 1.0)));
	}
	return e;
}

double shield_size(const P &p) {
	if (p.shell != 0) {
		return 1.0;
	}
	if (p.brk >= 0.0 && p.brk < POP_SECONDS) {
		return 1.0 + 0.12 * sstep(0.0, POP_SECONDS, p.brk);
	}
	return 0.0;
}

// GlacierTurtleAvatar._body_xf: the rig's transform from the drives and the lift.
Transform3D body_xf(const float *d, double lift) {
	return Transform3D(Basis(), Vector3(d[SURGE], f32(lift), 0.0f)) * at(ROLL_AT) *
			Transform3D(axis_angle(RIGHT, d[ROLL]), Vector3()) * at(-ROLL_AT) * at(PITCH_AT) *
			Transform3D(axis_angle(BACK, d[PITCH]), Vector3()) * at(-PITCH_AT) *
			Transform3D(axis_angle(UP, d[SWAY]), Vector3());
}

// The engine's float atan2 (Vector2.angle), as fsin and fcos are its float sine and cosine (zd_avatar.cpp).
inline double angle_of(const Vector2 &v) {
	return double(rig::angle(v));
}

// GlacierTurtleAvatar._reach: each leg's yaw, hip and knee turns so its foot's tip lands on its rest plus _foot.
void reach(const P &p, float *d) {
	const Transform3D inv = body_xf(d, p.lift).affine_inverse();
	for (int j = 0; j < LEGS; j++) {
		const Vector3 hip = p.hips[j];
		const Vector3 knee = p.knees[j];
		const Vector3 tip = p.feet[j];
		const Vector3 v = inv.xform(tip + p.foot[j]) - hip;
		const Vector3 r0 = tip - hip;
		const double across =
				acos_d(clampd(double(r0.z) / maxd(double(Vector2(v.x, v.z).length()), 0.0001), -1.0, 1.0));
		const double to = atan2_d(double(v.x), double(v.z));
		const double y1 = wrap_pi(to - across);
		const double y2 = wrap_pi(to + across);
		const double yaw = std::fabs(y1) < std::fabs(y2) ? y1 : y2;
		const Vector3 t = axis_angle(UP, f32(-yaw)).xform(v);
		const Vector2 aim(t.x, t.y);
		const Vector2 u0(f32(double(knee.x) - double(hip.x)), f32(double(knee.y) - double(hip.y)));
		const Vector2 l0(f32(double(tip.x) - double(knee.x)), f32(double(tip.y) - double(knee.y)));
		const double a = double(u0.length());
		const double b = double(l0.length());
		const double rch = clampd(double(aim.length()), std::fabs(a - b) + 0.002, (a + b) * 0.998);
		const double bend = signd(double(Vector2(r0.x, r0.y).cross(u0)));
		const double off = acos_d(clampd((a * a + rch * rch - b * b) / (2.0 * a * rch), -1.0, 1.0));
		const double hip_turn = wrap_pi(angle_of(aim) + bend * off - angle_of(u0));
		const Vector2 l1 = aim.normalized() * f32(rch) - rig::rotated(u0, f32(hip_turn));
		d[LEG0 + 3 * j] = f32(yaw);
		d[LEG0 + 3 * j + 1] = f32(hip_turn);
		d[LEG0 + 3 * j + 2] = f32(wrap_pi(angle_of(l1) - angle_of(l0) - hip_turn));
	}
}

// GlacierTurtleAvatar._pose: the raw drives, the lift and the visor's glow from the state.
void gt_pose(double *s, const Ctx &c) {
	const bool calm = c.calm;
	const double k = calm ? CALM : 1.0;
	P p;
	p.t = s[T];
	p.bare = s[GT_BARE];
	p.speed = s[GT_SPEED];
	p.omega = s[GT_OMEGA];
	p.phase = s[GT_PHASE];
	p.stride = s[GT_STRIDE];
	p.coil = s[GT_COIL];
	p.rise = s[GT_RISE];
	p.slam = s[GT_SLAM];
	p.brace = s[GT_BRACE];
	p.brk = s[GT_BREAK];
	p.hurt = s[GT_HURT];
	p.die = s[GT_DIE];
	p.tell = s[GT_TELL];
	p.state = int(s[GT_STATE]);
	p.shell = int(s[GT_SHELL]);
	p.hurt_leg = int(s[GT_HURT_LEG]);
	p.dir = Vector2(f32(s[GT_DIR]), f32(s[GT_DIR + 1]));
	const float scale = f32(s[GT_SCALE]);
	for (int j = 0; j < LEGS; j++) {
		p.hips[j] = vec_at(s, GT_HIPS + 3 * j);
		p.knees[j] = vec_at(s, GT_KNEES + 3 * j);
		p.feet[j] = FEET[j] * scale;
		p.foot[j] = Vector3();
	}
	float d[DRIVES] = {};
	const double breath = sin_d(TAU_D * (p.t * BREATH_HZ * lerpd(1.0, BARE_BREATH, p.bare)));
	double lift = walk_pose(p, d, k);
	lift += idle_pose(p, d, k, calm, breath);
	lift += bare_pose(p, d, k, calm);
	lift += tell_pose(p, d, k, calm, c.st);
	lift += slam_pose(p, d, k, calm);
	lift += brace_pose(p, d, k, calm);
	lift += break_pose(p, d, k, calm);
	lift += hurt_pose(p, d, k, calm);
	lift += rise_pose(p, d);
	lift = death_pose(p, d, lift, calm);
	sub(d, SHIELD_UP, lift); // a held shield stands on the ground under the body's bob
	d[SHIELD_ON] = f32(shield_size(p));
	for (int j = 0; j < LEG0; j++) {
		d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	p.lift = lift;
	reach(p, d);
	for (int j = LEG0; j < DRIVES; j++) {
		d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	for (int j = 0; j < DRIVES; j++) {
		s[GT_VD + j] = d[j];
	}
	s[GT_LIFT] = lift;
	s[GT_VISOR] = f32(visor(p, calm, c.st)); // the material's emission energy (a float)
}

// GlacierTurtleAvatar._turning: the facing's turn rate from its yaw now (the facing node's rotation.y).
void turning(double *s, double dt, bool dying, const Frame &f) {
	const double fy = double(f.facing_yaw);
	double w = 0.0;
	if (s[GT_HAVE_FY] != 0.0 && !dying) {
		w = clampd(wrap_pi(fy - s[GT_LAST_FY]) / dt, -6.0, 6.0);
	}
	s[GT_OMEGA] = lerpd(s[GT_OMEGA], w, ease_rate(10.0, dt));
	s[GT_LAST_FY] = fy;
	s[GT_HAVE_FY] = 1.0;
}

} // namespace

// GlacierTurtleAvatar.apply_state from a sync (`more`: its HP, its shield's HP).
void gt_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const int64_t hp = int64_t(more[0]);
	const int64_t shell = int64_t(more[1]);
	const bool fresh = s[FRESH] != 0.0;
	const int was = int(s[GT_STATE]);
	if (fresh) {
		s[GT_RISE] = state == c.st.spawn ? 0.0 : 1.0;
		s[GT_BARE] = shell == 0 ? 1.0 : 0.0;
	} else {
		const bool slammed = state == c.st.active && was != c.st.active;
		const bool missed = state == c.st.recover && was == c.st.windup;
		if (slammed || missed) { // (a tick's slam missed between two syncs still slams)
			s[GT_SLAM] = 0.0;
		}
		const int64_t had_shell = int64_t(s[GT_SHELL]);
		if (shell == 0 && had_shell != 0) {
			s[GT_BREAK] = 0.0;
		} else if (shell >= 0 && had_shell > 0 && shell < had_shell) {
			s[GT_BRACE] = 0.0;
		}
		const int64_t had = int64_t(s[GT_HP]);
		if (hp >= 0 && had >= 0 && hp < had) {
			s[GT_HURT] = 0.0;
			s[GT_HURT_LEG] = double((int64_t(s[GT_HURT_LEG]) + 1) % LEGS);
		}
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
	s[GT_STATE] = state;
	s[GT_TELL] = windup;
	s[GT_HP] = double(hp);
	s[GT_SHELL] = double(shell);
	if (fresh) {
		s[FRESH] = 0.0;
		gt_pose(s, c);
	}
}

// GlacierTurtleAvatar.advance
void gt_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[GT_DIE] >= 0.0;
	const int state = int(s[GT_STATE]);
	const bool moving = state == c.st.move && !dying;
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	s[GT_SPEED] = lerpd(s[GT_SPEED], moving ? double(vel.length()) : 0.0, ease_rate(moving ? 8.0 : 14.0, dt));
	turning(s, dt, dying, f);
	const Vector3 local = axis_angle(UP, f32(-s[GT_LAST_FY])).xform(Vector3(vel.x, 0.0f, f32(-double(vel.y))));
	if (moving && double(local.length()) > 0.2) {
		const Vector2 dir(f32(s[GT_DIR]), f32(s[GT_DIR + 1]));
		const Vector2 to = dir.lerp(Vector2(local.x, local.z).normalized(), f32(ease_rate(10.0, dt)));
		const Vector2 now = double(to.length()) > 0.05 ? to.normalized() : dir;
		s[GT_DIR] = now.x;
		s[GT_DIR + 1] = now.y;
	}
	// The stride: the walk's and the turn's share, at the cadence that keeps a planted foot still.
	const double most = maxd(s[GT_SPEED] / MOVE_SPEED, std::fabs(s[GT_OMEGA]) / TURN_REF);
	s[GT_STRIDE] = toward(s[GT_STRIDE], mind(most, 1.0), dt * 4.0);
	const double hz = MOVE_SPEED * DUTY / (2.0 * sweep_of(s[GT_BARE]));
	s[GT_PHASE] = Math::fposmod(s[GT_PHASE] + hz * maxd(1.0, most / STRIDE_MAX) * dt * signd(s[GT_STRIDE]), 1.0);
	const bool winding = state == c.st.windup && !dying;
	s[GT_COIL] = winding ? s[GT_TELL] : toward(s[GT_COIL], 0.0, dt * 10.0);
	const bool spawning = state == c.st.spawn;
	s[GT_RISE] = toward(s[GT_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 1.8));
	s[GT_BARE] = toward(s[GT_BARE], int(s[GT_SHELL]) == 0 ? 1.0 : 0.0, dt * 1.6);
	s[GT_SLAM] = rig::clip(s[GT_SLAM], dt, SLAM_SECONDS);
	s[GT_BRACE] = rig::clip(s[GT_BRACE], dt, BRACE_SECONDS);
	s[GT_BREAK] = rig::clip(s[GT_BREAK], dt, BREAK_SECONDS);
	s[GT_HURT] = rig::clip(s[GT_HURT], dt, HURT_SECONDS);
	if (dying) {
		s[GT_DIE] += dt;
	}
	gt_pose(s, c);
}

// GlacierTurtleAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES).
int gt_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[GT_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		const double span = VAT_DRIVES[i].hi - lo;
		if (Math::is_zero_approx(span)) {
			out[i] = f32(v);
			continue;
		}
		out[i] = f32((v - lo) / span);
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
