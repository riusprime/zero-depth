// The Warden's avatar on a batch row (zd_avatar.h W_*): WardenAvatar's sync (apply_state), frame step (advance,
// _turning, the dust ring's clock) and pose (_pose and its clips, _body_xf, _reach_all, _reach), ported line by line in
// the same order and float width as the GDScript (src/presentation/world_view/warden_avatar.gd): its floats are
// doubles, its raw drives (a PackedFloat32Array), its Vector2s, Vector3s and transforms floats, and a component read
// off one of those a double in the arithmetic around it, as GDScript reads it. tests/unit/native/test_native_crowd.gd
// holds the rows equal to the GDScript avatar's fields bit for bit.

#include "zd_avatar.h"

#include <cmath>
#include <cstdint>
#include <initializer_list>

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/vector2.hpp>

using namespace godot;

namespace zd {
namespace av {

namespace {

constexpr double PI_D = 3.1415926535897932384626433833;
constexpr double TAU_D = 6.2831853071795864769252867666;
constexpr int MOTION_GAP_TICKS = 30;
// WardenAvatar
constexpr double TELEPORT_SPEED = 30.0;
constexpr double HURT_SECONDS = 0.4;
constexpr double DEATH_SECONDS = 1.3;
constexpr double RISE_SECONDS = 0.45;
constexpr int RECOVER_TICKS = 40;
constexpr double MOVE_SPEED = 1.6;
constexpr double DUTY = 0.5;
constexpr double SWEEP = 0.13;
constexpr double LIFT = 0.075;
constexpr double STRIDE_MAX = 1.4;
constexpr double STEP_HZ = MOVE_SPEED * DUTY / (2.0 * SWEEP);
constexpr double TURN_REF = 2.0;
constexpr double TURN_SWING = 0.18;
constexpr double STRIDE_AT[4] = { 0.5, 0.0, 0.75, 0.25 };
constexpr double BREATH_HZ = 0.35;
constexpr double CALM = 0.45;
constexpr double ARM_UP = 2.5;
constexpr double ELBOW_UP = 0.55;
constexpr double ROLL_UP = 0.4;
constexpr double DUST_SECONDS = 0.45;

const Vector3 KNUCKLES[2] = { Vector3(0.245f, 0.098f, 0.404f), Vector3(0.245f, 0.098f, -0.404f) };
const Vector3 FIST_IN(-0.08f, 0.0f, 0.0f);
const Vector3 SLAM_AT[2] = { Vector3(0.62f, 0.1f, 0.33f), Vector3(0.62f, 0.1f, -0.33f) };
const Vector3 ROLL_AT(0.0f, 0.32f, 0.0f);
const Vector3 PITCH_AT(-0.09f, 0.32f, 0.0f);
const Vector3 UP(0, 1, 0);
const Vector3 RIGHT(1, 0, 0);
const Vector3 BACK(0, 0, 1);

// The raw drives (WardenAvatar's SURGE ... EYE).
enum Drive {
	SURGE = 0,
	ROLL = 1,
	PITCH = 2,
	SWAY = 3,
	HEAD_P = 4,
	HEAD_Y = 5,
	ARM0 = 6,
	LEG0 = 14,
	EYE = 22,
	DRIVES = 23,
};

// VAT_DRIVES: [lo, hi] (none loops; the eye's spans nothing: sent as it is).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.15, 0.15 },
	{ -0.45, 0.45 },
	{ -0.75, 0.5 },
	{ -0.3, 0.3 },
	{ -0.6, 0.6 },
	{ -0.7, 0.7 },
	{ -1.0, 1.0 },
	{ -0.8, 0.8 },
	{ -1.6, 3.2 },
	{ -2.6, 2.6 },
	{ -1.0, 1.0 },
	{ -0.8, 0.8 },
	{ -1.6, 3.2 },
	{ -2.6, 2.6 },
	{ -0.8, 0.8 },
	{ -1.6, 1.6 },
	{ -2.4, 2.4 },
	{ -1.6, 1.6 },
	{ -0.8, 0.8 },
	{ -1.6, 1.6 },
	{ -2.4, 2.4 },
	{ -1.6, 1.6 },
	{ 0.0, 0.0 },
};

// The pivots in the row (BatchWardenRow.PIVOT_KEYS): the head, each arm's shoulder and elbow (r, l), each leg's hip,
// knee and ankle (r, l).
inline int arm_u(int k) {
	return 1 + 2 * k;
}
inline int arm_l(int k) {
	return 2 + 2 * k;
}
inline int leg_u(int k) {
	return 5 + 3 * k;
}
inline int leg_l(int k) {
	return 6 + 3 * k;
}
inline int leg_f(int k) {
	return 7 + 3 * k;
}

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

// The engine's float atan2 (Vector2.angle), as fsin and fcos are its float sine and cosine (zd_avatar.cpp).
inline float fatan2(float y, float x) {
#ifdef _WIN32
	return float(atan2_d(double(y), double(x)));
#else
	return ::atan2f(y, x);
#endif
}
inline float angle_of(const Vector2 &v) {
	return fatan2(v.y, v.x);
}
// Vector2.rotated and Vector3.rotated, on the engine's float sine and cosine.
inline Vector2 rotated2(const Vector2 &v, float by) {
	const float sine = fsin(by);
	const float cosi = fcos(by);
	return Vector2(v.x * cosi - v.y * sine, v.x * sine + v.y * cosi);
}
inline Vector3 rotated3(const Vector3 &v, const Vector3 &axis, float angle) {
	return axis_angle(axis, angle).xform(v);
}
inline Transform3D at(const Vector3 &p) {
	return Transform3D(Basis(), p);
}

inline Vector3 pivot(const double *s, int p) {
	const double *o = s + W_PIV + p * 3;
	return Vector3(f32(o[0]), f32(o[1]), f32(o[2]));
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

// The pose's inputs read off the row once (the GDScript's fields).
struct P {
	const double *s;
	double t, stride, speed, omega, phase, raise, slam, rise, shake, hurt, die, windup, lift, scale;
	int state;
	Vector2 dir;
	Vector3 end[4];
};

double hash(double x) {
	const double v = sin_d(x * 12.9898 + 78.233) * 43758.5453;
	return v - std::floor(v);
}

double scan(double t, double every, double seed_off) {
	const double u = t / every + seed_off;
	const double seg = std::floor(u);
	const double a = hash(seg) * 2.0 - 1.0;
	const double b = hash(seg + 1.0) * 2.0 - 1.0;
	return lerpd(a, b, sstep(0.55, 0.9, u - seg));
}

double thump(double p) {
	const double q = Math::fposmod(p, 1.0);
	if (q < 0.06) {
		return sin_d(PI_D * 0.5 * q / 0.06);
	}
	return q < 0.5 ? exp_d(-(q - 0.06) * 10.0) : 0.0;
}

Vector2 leg_cycle(double q) {
	if (q < DUTY) {
		return Vector2(f32(1.0 - 2.0 * q / DUTY), 0.0f);
	}
	const double w = (q - DUTY) / (1.0 - DUTY);
	const double up = sin_d(PI_D * w);
	return Vector2(f32(-1.0 + 2.0 * sstep(0.0, 1.0, w)), f32(up * up * (3.0 - 2.0 * up)));
}

Vector3 limb_rest(const P &p, int j) {
	if (j < 2) {
		return pivot(p.s, leg_f(j));
	}
	return KNUCKLES[j - 2] * f32(p.scale) + FIST_IN;
}

double walk_pose(P &p, float *d, double k) {
	const double g = clampd(p.stride, 0.0, 1.0);
	const double walk = clampd(p.speed / MOVE_SPEED, 0.0, STRIDE_MAX);
	const double turn = clampd(p.omega / TURN_REF, -1.0, 1.0);
	const Vector3 dir(p.dir.x, 0.0f, p.dir.y);
	for (int j = 0; j < 4; j++) {
		const Vector2 c = leg_cycle(Math::fposmod(p.phase - STRIDE_AT[j], 1.0));
		const Vector3 rest = limb_rest(p, j);
		const double th = turn * TURN_SWING * double(c.x);
		p.end[j] += dir * f32(walk * SWEEP * double(c.x)) +
				Vector3(f32(th * double(rest.z)), f32(LIFT * g * double(c.y)), f32(-th * double(rest.x)));
	}
	if (g <= 0.0) {
		return 0.0;
	}
	const double ph = p.phase;
	const double w = mind(walk, 1.0);
	const double th = thump(ph) + thump(ph - 0.5);
	add(d, ROLL, g * k * 0.045 * sin_d(TAU_D * (ph - 0.12)));
	add(d, SWAY, w * k * 0.07 * sin_d(TAU_D * (ph + 0.1)));
	sub(d, PITCH, w * 0.07 + w * k * 0.02 * sin_d(2.0 * TAU_D * ph));
	sub(d, HEAD_Y, w * k * 0.06 * sin_d(TAU_D * (ph + 0.1)));
	add(d, HEAD_P, w * k * 0.04 * cos_d(2.0 * TAU_D * (ph - 0.1)));
	return -0.05 * w - g * k * 0.03 * th;
}

double idle_pose(P &p, float *d, double k, bool calm, double breath) {
	const double busy = maxd(p.raise, p.slam);
	const double alive = p.die < 0.0 ? 1.0 : 0.0;
	const double idle = (1.0 - clampd(p.stride, 0.0, 1.0)) * (1.0 - busy) * alive;
	if (idle <= 0.0) {
		return 0.0;
	}
	const double t = p.t;
	add(d, PITCH, idle * k * 0.025 * breath);
	add(d, HEAD_P, idle * k * (0.06 * scan(t, 3.7, 5.0) + 0.02 * breath));
	add(d, HEAD_Y, idle * k * 0.3 * scan(t, 2.9, 0.0));
	add(d, ROLL, idle * k * 0.035 * sin_d(0.55 * t));
	add(d, SWAY, idle * k * 0.04 * sin_d(0.37 * t + 0.6));
	add(d, SURGE, idle * k * 0.01 * sin_d(0.55 * t + 1.4));
	if (!calm) { // a fist re-planted now and then
		const double u = t / 3.4;
		const double seg = std::floor(u);
		if (hash(seg + 5.0) > 0.35) {
			const int j = 2 + int64_t(hash(seg + 9.0) * 2.0) % 2;
			const double e = sin_d(PI_D * clampd((u - seg - 0.25) / 0.18, 0.0, 1.0));
			p.end[j] += Vector3(0.03f, 0.09f, 0.0f) * f32(e) * f32(idle);
		}
	}
	return idle * k * 0.012 * breath;
}

double crouch(const P &p, const States &st) {
	if (p.state != st.windup || p.die >= 0.0) {
		return 0.0;
	}
	return crouch_of_tell(p.windup);
}

double tell_pose(P &p, float *d, double k, bool calm, const States &st) {
	const double r = p.raise;
	const double c = crouch(p, st);
	if (r <= 0.0 && c <= 0.0) {
		return 0.0;
	}
	add(d, PITCH, 0.26 * r * k);
	sub(d, SURGE, 0.05 * r * k);
	add(d, HEAD_P, 0.3 * r * k);
	mul(d, HEAD_Y, 1.0 - r);
	if (!calm && p.state == st.windup) {
		const double top = r * sstep(0.6, 1.0, p.windup);
		add(d, SURGE, 0.012 * top * sin_d(p.t * 47.0));
		add(d, ROLL, 0.015 * top * sin_d(p.t * 39.0));
	}
	return -0.02 * r - 0.07 * c;
}

double slam_pose(P &p, float *d, double k, bool calm) {
	const double s = p.slam;
	if (s <= 0.0 && p.shake <= 0.0) {
		return 0.0;
	}
	sub(d, PITCH, 0.5 * s + 0.06 * p.shake * k);
	add(d, SURGE, 0.06 * s);
	sub(d, HEAD_P, 0.15 * s);
	mul(d, HEAD_Y, 1.0 - s);
	double lift = -0.08 * s;
	if (!calm && p.shake > 0.0) {
		lift += 0.02 * p.shake * sin_d(p.t * 60.0);
		add(d, ROLL, 0.03 * p.shake * sin_d(p.t * 53.0));
	}
	return lift;
}

double hurt_pose(P &p, float *d, double k) {
	if (p.hurt < 0.0) {
		return 0.0;
	}
	const double h = p.hurt / HURT_SECONDS;
	const double e = sin_d(PI_D * 0.5 * mind(h / 0.25, 1.0)) * (1.0 - sstep(0.25, 1.0, h));
	sub(d, SURGE, 0.05 * e * k);
	add(d, PITCH, 0.08 * e * k);
	sub(d, HEAD_P, 0.2 * e * k);
	add(d, ROLL, 0.04 * e * k);
	return -0.02 * e * k;
}

double rise_pose(P &p, float *d) {
	double sink = 1.0 - p.rise;
	if (sink <= 0.0) {
		return 0.0;
	}
	sink = sink * sink * (3.0 - 2.0 * sink);
	add(d, PITCH, 0.25 * sink);
	add(d, HEAD_P, 0.2 * sink);
	for (int j = 2; j <= 3; j++) {
		p.end[j] += Vector3(0.05f, 0.25f, 0.0f) * f32(sink);
	}
	return -1.35 * sink;
}

double death_pose(P &p, float *d, double lift, bool calm) {
	if (p.die < 0.0) {
		return lift;
	}
	const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
	const double keep = 1.0 - sstep(0.0, 0.2, u);
	for (int j : { SURGE, ROLL, PITCH, SWAY, HEAD_Y }) {
		mul(d, j, keep);
	}
	lift *= keep;
	const double buckle = sstep(0.05, 0.4, u);
	const double fall = sstep(0.35, 0.8, u);
	for (int j = 0; j < 4; j++) {
		p.end[j] *= f32(keep);
	}
	for (int j = 2; j <= 3; j++) { // the fists slide out ahead as it falls on them
		p.end[j] += Vector3(0.22f, 0.0f, 0.0f) * f32(fall);
	}
	sub(d, PITCH, 0.3 * buckle + 0.32 * fall);
	add(d, SURGE, 0.1 * fall);
	add(d, ROLL, 0.3 * fall);
	d[HEAD_P] = f32(lerpd(double(d[HEAD_P]), -0.45, buckle));
	if (!calm) {
		add(d, ROLL, 0.02 * buckle * (1.0 - fall) * sin_d(p.die * 30.0));
	}
	return lift - 0.14 * buckle - 0.12 * fall;
}

double eye(const P &p, bool calm, const States &st) {
	const bool winding = p.state == st.windup && p.die < 0.0;
	const double tell = winding ? glow_of_tell(p.windup, p.t, calm) : 1.0;
	double e = ((2.4 + 4.0 * p.raise) * tell + 2.0 * p.shake) * lerpd(0.3, 1.0, p.rise);
	if (p.die >= 0.0) {
		const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
		const double flicker = calm ? 1.0 : 0.6 + 0.4 * std::fabs(sin_d(p.die * 23.0));
		e = lerpd(e * flicker, 0.0, sstep(0.1, 0.7, u));
	}
	return e;
}

double crack_energy(const P &p, bool calm) {
	double e = 1.8 + (calm ? 0.0 : 0.5 * sin_d(p.t * 3.4)) + 1.5 * p.raise + 1.5 * p.shake;
	if (p.die >= 0.0) {
		const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
		e += 3.0 * sin_d(PI_D * clampd(u / 0.3, 0.0, 1.0));
		e = lerpd(e, 0.0, sstep(0.35, 0.9, u));
	}
	return e;
}

Transform3D body_xf(const float *d, double lift) {
	return Transform3D(Basis(), Vector3(d[SURGE], f32(lift), 0.0f)) * at(ROLL_AT) *
			Transform3D(axis_angle(RIGHT, d[ROLL]), Vector3()) * at(-ROLL_AT) * at(PITCH_AT) *
			Transform3D(axis_angle(BACK, d[PITCH]), Vector3()) * at(-PITCH_AT) *
			Transform3D(axis_angle(UP, d[SWAY]), Vector3());
}

// WardenAvatar._reach: a two-bone limb reaching for `target` (the yaw at the root, the root's and the joint's turns).
Vector3 reach(const Vector3 &root, const Vector3 &mid, const Vector3 &end, const Vector3 &target) {
	const Vector3 v = target - root;
	const Vector3 r0 = end - root;
	const double across =
			acos_d(clampd(double(r0.z) / maxd(double(Vector2(v.x, v.z).length()), 0.0001), -1.0, 1.0));
	const double to = atan2_d(double(v.x), double(v.z));
	const double y1 = wrap_pi(to - across);
	const double y2 = wrap_pi(to + across);
	const double yaw = std::fabs(y1) < std::fabs(y2) ? y1 : y2;
	const Vector3 t = rotated3(v, UP, f32(-yaw));
	const Vector2 aim(t.x, t.y);
	const Vector2 u0(f32(double(mid.x) - double(root.x)), f32(double(mid.y) - double(root.y)));
	const Vector2 l0(f32(double(end.x) - double(mid.x)), f32(double(end.y) - double(mid.y)));
	const double a = double(u0.length());
	const double b = double(l0.length());
	const double rch = clampd(double(aim.length()), std::fabs(a - b) + 0.002, (a + b) * 0.998);
	const double bend = signd(double(Vector2(r0.x, r0.y).cross(u0)));
	const double off = acos_d(clampd((a * a + rch * rch - b * b) / (2.0 * a * rch), -1.0, 1.0));
	const double root_turn = wrap_pi(double(angle_of(aim)) + bend * off - double(angle_of(u0)));
	const Vector2 l1 = aim.normalized() * f32(rch) - rotated2(u0, f32(root_turn));
	return Vector3(f32(yaw), f32(root_turn),
			f32(wrap_pi(double(angle_of(l1)) - double(angle_of(l0)) - root_turn)));
}

void reach_all(P &p, float *d) {
	const Transform3D inv = body_xf(d, p.lift).affine_inverse();
	for (int k = 0; k < 2; k++) {
		const Vector3 ankle = pivot(p.s, leg_f(k));
		const Vector3 r = reach(pivot(p.s, leg_u(k)), pivot(p.s, leg_l(k)), ankle, inv.xform(ankle + p.end[k]));
		const int l = LEG0 + 4 * k;
		d[l] = r.x;
		d[l + 1] = r.y;
		d[l + 2] = r.z;
		const double swing = clampd(double(p.end[k].y) / LIFT, 0.0, 1.0);
		d[l + 3] = f32(-(double(r.y) + double(r.z)) - double(d[PITCH]) - 0.35 * swing);
	}
	const double up = sstep(0.0, 1.0, p.raise);
	for (int k = 0; k < 2; k++) {
		const Vector3 rest = KNUCKLES[k] * f32(p.scale);
		const Vector3 aim = (rest + FIST_IN + p.end[2 + k]).lerp(SLAM_AT[k], f32(sstep(0.0, 1.0, p.slam)));
		const Vector3 r = reach(pivot(p.s, arm_u(k)), pivot(p.s, arm_l(k)), rest, inv.xform(aim));
		const int a = ARM0 + 4 * k;
		const double side = k == 0 ? 1.0 : -1.0;
		d[a] = f32(lerpd(double(r.x), 0.0, up));
		d[a + 1] = f32(lerpd(0.0, -side * ROLL_UP, up));
		d[a + 2] = f32(lerpd(double(r.y), ARM_UP, up));
		d[a + 3] = f32(lerpd(double(r.z), ELBOW_UP, up));
	}
}

// WardenAvatar._pose: the raw drives, the lift and the glows from the state.
void w_pose(double *s, const Ctx &c) {
	const bool calm = c.calm;
	const double k = calm ? CALM : 1.0;
	P p;
	p.s = s;
	p.t = s[T];
	p.stride = s[W_STRIDE];
	p.speed = s[W_SPEED];
	p.omega = s[W_OMEGA];
	p.phase = s[W_PHASE];
	p.raise = s[W_RAISE];
	p.slam = s[W_SLAM];
	p.rise = s[W_RISE];
	p.shake = s[W_SHAKE];
	p.hurt = s[W_HURT];
	p.die = s[W_DIE];
	p.windup = s[W_WINDUP];
	p.scale = s[W_SCALE];
	p.state = int(s[W_STATE]);
	p.dir = Vector2(f32(s[W_DIR]), f32(s[W_DIR + 1]));
	for (int j = 0; j < 4; j++) {
		p.end[j] = Vector3();
	}
	float d[DRIVES] = {};
	const double breath = sin_d(TAU_D * p.t * BREATH_HZ);
	double lift = walk_pose(p, d, k);
	lift += idle_pose(p, d, k, calm, breath);
	lift += tell_pose(p, d, k, calm, c.st);
	lift += slam_pose(p, d, k, calm);
	lift += hurt_pose(p, d, k);
	lift += rise_pose(p, d);
	lift = death_pose(p, d, lift, calm);
	for (int j = 0; j < ARM0; j++) {
		d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	p.lift = lift;
	s[W_LIFT] = lift;
	reach_all(p, d);
	for (int j = ARM0; j < EYE; j++) {
		d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	d[EYE] = f32(eye(p, calm, c.st));
	s[W_CRACK] = crack_energy(p, calm);
	for (int j = 0; j < DRIVES; j++) {
		s[W_VD + j] = d[j];
	}
}

// WardenAvatar._turning: the facing's turn rate from its yaw now (the facing node's rotation.y).
void turning(double *s, double dt, bool dying, const Frame &f) {
	const double fy = double(f.facing_yaw);
	double w = 0.0;
	if (s[W_HAVE_FY] != 0.0 && !dying) {
		w = clampd(wrap_pi(fy - s[W_LAST_FY]) / dt, -6.0, 6.0);
	}
	s[W_OMEGA] = lerpd(s[W_OMEGA], w, ease_rate(10.0, dt));
	s[W_LAST_FY] = fy;
	s[W_HAVE_FY] = 1.0;
}

double clip(double t, double dt, double length) {
	if (t < 0.0) {
		return t;
	}
	t += dt;
	return t < length ? t : -1.0;
}

} // namespace

// WardenAvatar.apply_state from a sync (`more`: its HP, the telegraph's radius and whether it gave one).
void w_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const int64_t hp = int64_t(more[0]);
	const bool fresh = s[FRESH] != 0.0;
	const int64_t last = int64_t(s[LAST_TICK]);
	const int64_t dt_ticks = tick - last;
	if (fresh || state != int(s[W_STATE])) {
		s[W_STATE_TICKS] = 0.0;
	} else if (dt_ticks > 0) {
		s[W_STATE_TICKS] = double(int64_t(s[W_STATE_TICKS]) + dt_ticks);
	}
	const int64_t had = int64_t(s[W_HP]);
	if (!fresh && hp >= 0 && had >= 0 && hp < had) {
		s[W_HURT] = 0.0;
	}
	// _track_motion(tick, pos, TELEPORT_SPEED)
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
	s[W_STATE] = state;
	s[W_HP] = double(hp);
	s[W_WINDUP] = clampd(windup, 0.0, 1.0);
	if (state == c.st.windup) {
		s[W_SLAM_R] = maxd(more[2] != 0.0 ? more[1] : s[W_SLAM_R], 0.5);
	}
	strike_note_of(s, state, c.st); // the hit tick starts the slam's downswing
	if (fresh) {
		s[FRESH] = 0.0;
		s[W_RISE] = state == c.st.spawn ? 0.0 : 1.0;
		w_pose(s, c);
	}
}

// WardenAvatar.advance
void w_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[W_DIE] >= 0.0;
	const double busy = maxd(s[W_RAISE], s[W_SLAM]);
	const int state = int(s[W_STATE]);
	const bool moving = state == c.st.move && !dying;
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	s[W_SPEED] = lerpd(s[W_SPEED], moving ? double(vel.length()) : 0.0, ease_rate(moving ? 8.0 : 12.0, dt));
	turning(s, dt, dying, f);
	const Vector3 local = rotated3(Vector3(vel.x, 0.0f, f32(-double(vel.y))), UP, f32(-s[W_LAST_FY]));
	if (moving && double(local.length()) > 0.2) {
		const Vector2 dir(f32(s[W_DIR]), f32(s[W_DIR + 1]));
		const Vector2 to = dir.lerp(Vector2(local.x, local.z).normalized(), f32(ease_rate(8.0, dt)));
		const Vector2 now = double(to.length()) > 0.05 ? to.normalized() : dir;
		s[W_DIR] = now.x;
		s[W_DIR + 1] = now.y;
	}
	const double most = maxd(s[W_SPEED] / MOVE_SPEED, std::fabs(s[W_OMEGA]) / TURN_REF) * (1.0 - busy);
	s[W_STRIDE] = toward(s[W_STRIDE], mind(most, 1.0), dt * 4.0);
	s[W_PHASE] = Math::fposmod(
			s[W_PHASE] + STEP_HZ * maxd(1.0, most / STRIDE_MAX) * dt * signd(s[W_STRIDE]), 1.0);
	const bool spawning = state == c.st.spawn;
	s[W_RISE] = toward(s[W_RISE], spawning ? 0.0 : 1.0, dt / RISE_SECONDS);
	const bool was_snapping = strike_snapping_of(s);
	strike_step(s, dt);
	const bool winding = state == c.st.windup && !dying;
	s[W_RAISE] = strike_raised_of(s, winding, s[W_WINDUP], toward(s[W_RAISE], 0.0, dt * 5.0));
	double hold = 0.0;
	if (state == c.st.recover) {
		hold = 1.0 - sstep(0.35, 1.0, double(int64_t(s[W_STATE_TICKS])) / RECOVER_TICKS);
	}
	const double swing = strike_swing_of(s);
	if (strike_snapping_of(s)) {
		s[W_SLAM] = maxd(swing, s[W_SLAM]);
	} else if (swing > 0.0 || hold > 0.0) {
		s[W_SLAM] = maxd(swing, hold);
	} else {
		s[W_SLAM] = lerpd(s[W_SLAM], 0.0, ease_rate(5.0, dt));
	}
	if (was_snapping && !strike_snapping_of(s)) {
		s[W_SHAKE] = 1.0; // the impact
		s[W_DUST_T] = 0.0;
	}
	s[W_SHAKE] = toward(s[W_SHAKE], 0.0, dt * 4.0);
	s[W_HURT] = clip(s[W_HURT], dt, HURT_SECONDS);
	if (dying) {
		s[W_DIE] += dt;
	}
	// _advance_dust's clock (the ring itself is a node in the tree: BatchWarden shows it from the row)
	if (s[W_DUST_T] >= 0.0) {
		s[W_DUST_T] += dt;
		if (s[W_DUST_T] / DUST_SECONDS >= 1.0) {
			s[W_DUST_T] = -1.0;
		}
	}
	w_pose(s, c);
}

// WardenAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the eye's spec spans nothing: as it is).
int w_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[W_VD + i]));
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
