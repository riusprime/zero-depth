// The Frost Spitter's avatar on a batch row (zd_avatar.h FS_*): FrostSpitterAvatar's sync (apply_state), frame step
// (advance, _turning) and pose (_pose and its clips, the legs' reach, leg_cycle, the glows), ported line by line in the
// same order and float width as the GDScript (src/presentation/world_view/frost_spitter_avatar.gd): its numbers are
// doubles, its raw drives floats (a PackedFloat32Array), its feet, pivots, direction and the body's transform floats
// (Vector2/Vector3/Transform3D, the engine's float sine, cosine and arc tangent), and a value read off one of those a
// double in the arithmetic around it, as GDScript reads it.
// tests/unit/native/test_native_crowd_frost_spitter.gd holds the drawn buffers equal to the GDScript avatar's bit for
// bit.

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
// FrostSpitterAvatar
constexpr double SAC_REST = 0.5;
constexpr double SAC_FULL = 1.4;
constexpr double SAC_FLASH = 2.5;
constexpr double VISOR_REST = 1.6;
constexpr double VISOR_TELL = 6.5;
constexpr double TELEPORT_SPEED = 30.0;
constexpr double SPIT_SECONDS = 0.7;
constexpr double HURT_SECONDS = 0.35;
constexpr double DEATH_SECONDS = 1.0;
constexpr double MOVE_SPEED = 2.6;
constexpr double DUTY = 0.5;
constexpr double SWEEP = 0.15;
constexpr double LIFT = 0.07;
constexpr double STRIDE_MAX = 1.3;
constexpr double STEP_HZ = MOVE_SPEED * DUTY / (2.0 * SWEEP);
constexpr double GATHER[4] = { -0.1, -0.1, 0.09, 0.09 };
constexpr double CROUCH = 0.025;
constexpr double TURN_REF = 3.0;
constexpr double TURN_SWING = 0.22;
constexpr int LEGS = 4;
constexpr double STRIDE_AT[LEGS] = { 0.0, 0.5, 0.53, 0.03 };
constexpr double BREATH_HZ = 0.5;
constexpr double CALM = 0.45;

// The raw drives (FrostSpitterAvatar's SURGE ... VISOR).
enum Drive {
	SURGE = 0,
	ROLL = 1,
	PITCH = 2,
	SWAY = 3,
	HEAD_P = 4,
	HEAD_Y = 5,
	SHELL_UP = 6,
	SHELL_P = 7,
	SAC = 8,
	LEG0 = 9,
	VISOR = 21,
	DRIVES = 22,
};

// VAT_DRIVES: [lo, hi] (none loops; the visor's spans nothing: sent as it is).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.1, 0.1 },
	{ -0.3, 0.3 },
	{ -0.35, 0.45 },
	{ -0.3, 0.3 },
	{ -0.45, 0.6 },
	{ -0.6, 0.6 },
	{ -0.03, 0.05 },
	{ -0.25, 0.25 },
	{ -0.7, 0.7 },
	{ -0.7, 0.7 }, { -1.3, 1.3 }, { -1.8, 1.8 }, // fr
	{ -0.7, 0.7 }, { -1.3, 1.3 }, { -1.8, 1.8 }, // fl
	{ -0.7, 0.7 }, { -1.3, 1.3 }, { -1.8, 1.8 }, // br
	{ -0.7, 0.7 }, { -1.3, 1.3 }, { -1.8, 1.8 }, // bl
	{ 0.0, 0.0 },
};

const Vector3 UP(0, 1, 0);
const Vector3 RIGHT(1, 0, 0);
const Vector3 BACK(0, 0, 1);
const Vector3 ROLL_AT(0.0f, 0.2f, 0.0f);
const Vector3 PITCH_AT(-0.36f, 0.05f, 0.0f);

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
inline float f32(double v) {
	return float(v);
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

inline Transform3D at(const Vector3 &p) {
	return Transform3D(Basis(), p);
}

// The pose's inputs read off the row once (the GDScript's fields), and each foot's offset the clips ask for (_foot).
struct P {
	double t, tell, speed, omega, phase, stride, coil, rise, spit, hurt, die;
	int state, hurt_leg;
	Vector2 dir;
	Vector3 hips[LEGS], knees[LEGS], feet[LEGS];
	Vector3 foot[LEGS];
};

double gulp(double t) {
	const double u = t / 3.6 + 2.0;
	const double seg = std::floor(u);
	if (rig::hash01(seg + 41.0) < 0.5) {
		return 0.0;
	}
	const double f = (u - seg - 0.5) / 0.08;
	return sin_d(PI_D * clampd(f, 0.0, 1.0)) - 0.4 * sin_d(PI_D * clampd(f - 1.0, 0.0, 1.0));
}

double gulps(double p) {
	const double g = clampd(p / 0.85, 0.0, 1.0) * 3.0;
	return (std::floor(g) + sstep(0.0, 0.45, g - std::floor(g))) / 3.0;
}

double walk_pose(P &p, float *d, double k) {
	const double g = clampd(p.stride, 0.0, 1.0);
	const double walk = clampd(p.speed / MOVE_SPEED, 0.0, STRIDE_MAX);
	const double turn = clampd(p.omega / TURN_REF, -1.0, 1.0);
	const Vector3 dir(p.dir.x, 0.0f, p.dir.y);
	for (int j = 0; j < LEGS; j++) {
		const Vector2 c = rig::leg_cycle(Math::fposmod(p.phase - STRIDE_AT[j], 1.0), DUTY);
		const Vector3 tip = p.feet[j];
		const double th = turn * TURN_SWING * double(c.x);
		p.foot[j] += dir * f32(walk * SWEEP * double(c.x)) +
				Vector3(f32(mind(walk, 1.0) * GATHER[j] + th * double(tip.z)), f32(LIFT * g * double(c.y)),
						f32(-th * double(tip.x)));
	}
	if (g <= 0.0) {
		return 0.0;
	}
	const double ph = p.phase;
	const double w = mind(walk, 1.0);
	add(d, ROLL, g * k * 0.04 * sin_d(TAU_D * (ph - 0.1)));
	add(d, SWAY, w * k * 0.05 * sin_d(TAU_D * (ph + 0.15)));
	add(d, PITCH, w * k * 0.015 * sin_d(2.0 * TAU_D * (ph - 0.1)) - w * 0.03);
	sub(d, HEAD_Y, w * k * 0.045 * sin_d(TAU_D * (ph + 0.15))); // the head holds its line against the sway
	add(d, HEAD_P, w * k * 0.04 * cos_d(2.0 * TAU_D * (ph - 0.2)));
	add(d, SAC, g * k * 0.07 * sin_d(2.0 * TAU_D * (ph - 0.2)));
	add(d, SHELL_UP, g * k * 0.006 * sin_d(2.0 * TAU_D * (ph - 0.15)));
	add(d, SHELL_P, g * k * 0.025 * sin_d(2.0 * TAU_D * (ph - 0.22)));
	return -CROUCH * w - g * k * 0.012 * cos_d(2.0 * TAU_D * (ph - 0.05));
}

double idle_pose(P &p, float *d, double k, bool calm, double breath) {
	const double idle = (1.0 - clampd(p.stride, 0.0, 1.0)) * (1.0 - p.coil) * (p.die < 0.0 ? 1.0 : 0.0);
	if (idle <= 0.0) {
		return 0.0;
	}
	const double t = p.t;
	add(d, SAC, idle * k * 0.08 * breath);
	add(d, SHELL_UP, idle * k * 0.004 * (breath + 1.0));
	sub(d, SHELL_P, idle * k * 0.015 * breath);
	add(d, HEAD_Y, idle * k * 0.35 * rig::scan(t, 2.4, 0.0));
	add(d, HEAD_P, idle * k * (0.07 * rig::scan(t, 3.3, 5.0) + 0.025 * (breath + 1.0)));
	if (!calm) {
		add(d, HEAD_P, idle * 0.08 * rig::twitch(t, 3.9, 11.0));
		add(d, HEAD_Y, idle * 0.07 * rig::twitch(t, 4.6, 23.0));
		add(d, SAC, idle * 0.14 * gulp(t));
	}
	add(d, ROLL, idle * k * 0.025 * sin_d(0.6 * t));
	add(d, PITCH, idle * k * 0.015 * sin_d(0.6 * t + 1.7));
	add(d, SWAY, idle * k * 0.03 * sin_d(0.4 * t + 0.4));
	// A foot re-planted now and then (a different one each time): lifted, carried a little and set down.
	const double u = t / 2.8;
	const double seg = std::floor(u);
	if (rig::hash01(seg + 7.0) > 0.4) {
		const int j = int(int64_t(rig::hash01(seg + 3.0) * double(LEGS)) % LEGS);
		const double e = sin_d(PI_D * clampd((u - seg - 0.2) / 0.2, 0.0, 1.0));
		p.foot[j] += Vector3(0.025f, 0.05f, 0.0f) * f32(e) * f32(idle);
	}
	return idle * k * 0.006 * breath;
}

double tell_pose(P &p, float *d, double k, bool calm, const States &st) {
	const double q = p.coil;
	if (q <= 0.0) {
		return 0.0;
	}
	const double crouch = sin_d(PI_D * clampd(q / 0.3, 0.0, 1.0)) * (1.0 - sstep(0.1, 0.35, q));
	const double rear = sstep(0.1, 0.7, q);
	add(d, SAC, 0.55 * gulps(q));
	add(d, PITCH, (0.24 * rear - 0.05 * crouch) * k);
	sub(d, SURGE, 0.04 * rear * k);
	add(d, HEAD_P, 0.3 * rear * k - 0.08 * crouch);
	mul(d, HEAD_Y, 1.0 - rear);
	add(d, SHELL_P, 0.08 * rear * k);
	add(d, SHELL_UP, 0.01 * rear);
	for (int j = 0; j < 2; j++) { // the front feet lift and reach
		p.foot[j] += Vector3(0.05f, 0.06f, 0.0f) * f32(rear) * f32(k);
	}
	if (!calm && p.state == st.windup) {
		const double top = sstep(0.75, 0.9, q);
		add(d, ROLL, 0.012 * top * sin_d(TAU_D * 14.0 * p.t));
		add(d, SAC, 0.035 * top * sin_d(TAU_D * 11.0 * p.t));
		add(d, HEAD_P, 0.03 * top * sin_d(TAU_D * 9.0 * p.t + 1.0));
	}
	return -0.02 * crouch * k - 0.03 * rear;
}

double spit_pose(P &p, float *d, double k, bool calm) {
	if (p.spit < 0.0) {
		return 0.0;
	}
	const double u = p.spit / SPIT_SECONDS;
	const double snap = sstep(0.0, 0.06, u) * (1.0 - sstep(0.25, 0.8, u));
	const double gape = sstep(0.0, 0.04, u) * (1.0 - sstep(0.2, 0.65, u));
	const double recoil = sin_d(PI_D * clampd((u - 0.08) / 0.3, 0.0, 1.0));
	const double empty = sstep(0.0, 0.08, u) * (1.0 - sstep(0.3, 1.0, u));
	add(d, PITCH, (-0.12 * snap + 0.06 * recoil) * k);
	add(d, SURGE, (0.06 * snap - 0.05 * recoil) * k);
	add(d, HEAD_P, 0.5 * gape - 0.1 * snap);
	sub(d, SAC, 0.75 * empty);
	add(d, SHELL_UP, 0.015 * recoil);
	add(d, SHELL_P, (-0.06 * snap + 0.05 * recoil) * k);
	for (int j = 0; j < 2; j++) { // (thrust out stiff: the lunge keeps the wrists off the ground)
		p.foot[j] += Vector3(0.08f, 0.0f, 0.0f) * f32(snap);
	}
	if (!calm) {
		add(d, SAC, 0.08 * empty * sin_d(TAU_D * 16.0 * p.spit));
		add(d, ROLL, 0.02 * recoil * sin_d(TAU_D * 10.0 * p.spit));
	}
	return (-0.015 * snap + 0.02 * recoil) * k;
}

double hurt_pose(P &p, float *d, double k, bool calm) {
	if (p.hurt < 0.0) {
		return 0.0;
	}
	const double h = p.hurt / HURT_SECONDS;
	const double e = sin_d(PI_D * mind(h / 0.25, 1.0)) * (1.0 - sstep(0.25, 1.0, h));
	sub(d, SURGE, 0.035 * e * k);
	add(d, PITCH, 0.05 * e * k);
	sub(d, HEAD_P, 0.15 * e * k);
	sub(d, SAC, 0.12 * e);
	p.foot[p.hurt_leg] += Vector3(0.0f, 0.05f, 0.0f) * f32(e) * f32(k);
	if (!calm) {
		add(d, SAC, 0.08 * e * sin_d(TAU_D * 9.0 * p.hurt));
		add(d, ROLL, 0.03 * e * sin_d(TAU_D * 12.0 * p.hurt));
	}
	return -0.01 * e * k;
}

double rise_pose(P &p, float *d) {
	const double r = 1.0 - p.rise;
	if (r <= 0.0) {
		return 0.0;
	}
	const double low = r * r * (1.0 - clampd(p.stride, 0.0, 1.0));
	for (int j = 0; j < 2; j++) {
		p.foot[j] += Vector3(0.1f, 0.0f, f32(0.02 * signd(double(p.feet[j].z)))) * f32(low);
	}
	sub(d, SAC, 0.45 * r);
	sub(d, HEAD_P, 0.2 * r);
	sub(d, SHELL_UP, 0.01 * r);
	return -0.14 * low;
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
	const double burst = sstep(0.02, 0.3, u);
	const double sag = sstep(0.12, 0.55, u);
	lerp_to(d, SAC, -0.65, burst);
	lerp_to(d, HEAD_P, -0.12, sag);
	sub(d, PITCH, 0.03 * sag);
	add(d, ROLL, 0.1 * sag);
	lerp_to(d, SHELL_P, -0.06, sag);
	lerp_to(d, SHELL_UP, -0.012, sag);
	for (int j = 0; j < LEGS; j++) {
		const Vector3 tip = p.feet[j];
		const Vector3 out(tip.x > 0.0f ? 0.14f : -0.04f, 0.0f, f32(signd(double(tip.z)) * 0.06));
		p.foot[j] = p.foot[j] * f32(keep) + out * f32(sag);
	}
	if (!calm) {
		add(d, SAC, 0.15 * burst * (1.0 - sstep(0.2, 0.45, u)) * sin_d(TAU_D * 13.0 * p.die));
		const double kick = sin_d(PI_D * clampd((u - 0.68) / 0.16, 0.0, 1.0));
		p.foot[2] += Vector3(-0.04f, 0.07f, 0.0f) * f32(kick);
	}
	return lift - 0.14 * sag;
}

double sac_energy(const P &p, bool calm, double breath, double swell) {
	double e = SAC_REST + SAC_FULL * maxd(0.0, swell);
	e *= 1.0 + 0.25 * (calm ? 0.4 : 1.0) * breath;
	if (p.spit >= 0.0) {
		e += SAC_FLASH * (1.0 - sstep(0.0, 0.35, p.spit / SPIT_SECONDS));
	}
	if (p.hurt >= 0.0) {
		e += 1.0 * (1.0 - p.hurt / HURT_SECONDS);
	}
	e *= lerpd(0.3, 1.0, p.rise);
	if (p.die >= 0.0) {
		const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
		e = lerpd(e, 0.05, sstep(0.15, 0.7, u));
		e += SAC_FLASH * sin_d(PI_D * clampd(u / 0.25, 0.0, 1.0));
	}
	return e;
}

double visor(const P &p, bool calm, const States &st) {
	double e = VISOR_REST;
	if (p.state == st.windup && p.die < 0.0) {
		e = VISOR_REST + (VISOR_TELL - VISOR_REST) * crouch_of_tell(p.tell);
		if (tell_flashing(p.tell)) {
			e = calm || int64_t(p.t * TELL_FLICKER_HZ * 2.0) % 2 == 0 ? VISOR_TELL * 1.2 : VISOR_TELL * 0.8;
		}
	}
	if (p.spit >= 0.0) {
		e = maxd(e, VISOR_TELL * (1.0 - sstep(0.0, 0.5, p.spit / SPIT_SECONDS)));
	}
	if (p.die >= 0.0) {
		e = lerpd(e, 0.1, sstep(0.1, 0.6, clampd(p.die / DEATH_SECONDS, 0.0, 1.0)));
	}
	return e;
}

// FrostSpitterAvatar._body_xf: the rig's transform (the lift, the surge, the roll, the pitch and the sway).
Transform3D body_xf(const float *d, double lift) {
	const Transform3D roll(axis_angle(RIGHT, d[ROLL]), Vector3());
	const Transform3D pitch(axis_angle(BACK, d[PITCH]), Vector3());
	return Transform3D(Basis(), Vector3(d[SURGE], f32(lift), 0.0f)) * at(ROLL_AT) * roll * at(-ROLL_AT) * at(PITCH_AT) *
			pitch * at(-PITCH_AT) * Transform3D(axis_angle(UP, d[SWAY]), Vector3());
}

// FrostSpitterAvatar._reach: each leg's yaw turns its plane through its foot, its hip and knee bend in it.
void reach(const P &p, float *d, double lift) {
	const Transform3D inv = body_xf(d, lift).affine_inverse();
	for (int j = 0; j < LEGS; j++) {
		const Vector3 hip = p.hips[j];
		const Vector3 knee = p.knees[j];
		const Vector3 tip = p.feet[j];
		const Vector3 v = inv.xform(tip + p.foot[j]) - hip;
		const Vector3 r0 = tip - hip;
		const double across = acos_d(
				clampd(double(r0.z) / maxd(double(Vector2(v.x, v.z).length()), 0.0001), -1.0, 1.0));
		const double to = atan2_d(double(v.x), double(v.z));
		const double y1 = Math::wrapf(to - across, -PI_D, PI_D);
		const double y2 = Math::wrapf(to + across, -PI_D, PI_D);
		const double yaw = std::fabs(y1) < std::fabs(y2) ? y1 : y2;
		const Vector3 t = axis_angle(UP, f32(-yaw)).xform(v);
		const Vector2 aim(t.x, t.y);
		const Vector2 u0(knee.x - hip.x, knee.y - hip.y);
		const Vector2 l0(tip.x - knee.x, tip.y - knee.y);
		const double a = double(u0.length());
		const double b = double(l0.length());
		const double r = clampd(double(aim.length()), std::fabs(a - b) + 0.002, (a + b) * 0.998);
		const double bend = signd(double(Vector2(r0.x, r0.y).cross(u0)));
		const double off = acos_d(clampd((a * a + r * r - b * b) / (2.0 * a * r), -1.0, 1.0));
		const double hip_turn = Math::wrapf(double(rig::angle(aim)) + bend * off - double(rig::angle(u0)), -PI_D, PI_D);
		const Vector2 l1 = aim.normalized() * f32(r) - rig::rotated(u0, f32(hip_turn));
		d[LEG0 + 3 * j] = f32(yaw);
		d[LEG0 + 3 * j + 1] = f32(hip_turn);
		d[LEG0 + 3 * j + 2] =
				f32(Math::wrapf(double(rig::angle(l1)) - double(rig::angle(l0)) - hip_turn, -PI_D, PI_D));
	}
}

inline Vector3 v3(const double *s, int at) {
	return Vector3(f32(s[at]), f32(s[at + 1]), f32(s[at + 2]));
}

// FrostSpitterAvatar._pose: the raw drives, the lift and the glows from the state.
void fs_pose(double *s, const Ctx &c) {
	const bool calm = c.calm;
	const double k = calm ? CALM : 1.0;
	P p;
	p.t = s[T];
	p.tell = s[FS_TELL];
	p.speed = s[FS_SPEED];
	p.omega = s[FS_OMEGA];
	p.phase = s[FS_PHASE];
	p.stride = s[FS_STRIDE];
	p.coil = s[FS_COIL];
	p.rise = s[FS_RISE];
	p.spit = s[FS_SPIT];
	p.hurt = s[FS_HURT];
	p.die = s[FS_DIE];
	p.state = int(s[FS_STATE]);
	p.hurt_leg = int(s[FS_HURT_LEG]);
	p.dir = Vector2(f32(s[FS_DIR]), f32(s[FS_DIR + 1]));
	for (int j = 0; j < LEGS; j++) {
		p.hips[j] = v3(s, FS_HIPS + 3 * j);
		p.knees[j] = v3(s, FS_KNEES + 3 * j);
		p.feet[j] = v3(s, FS_FEET + 3 * j);
		p.foot[j] = Vector3();
	}
	float d[DRIVES] = {};
	const double breath = sin_d(TAU_D * p.t * BREATH_HZ);
	double lift = walk_pose(p, d, k);
	lift += idle_pose(p, d, k, calm, breath);
	lift += tell_pose(p, d, k, calm, c.st);
	lift += spit_pose(p, d, k, calm);
	lift += hurt_pose(p, d, k, calm);
	lift += rise_pose(p, d);
	lift = death_pose(p, d, lift, calm);
	for (int j = 0; j < LEG0; j++) {
		d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	s[FS_LIFT] = lift;
	reach(p, d, lift);
	for (int j = LEG0; j < VISOR; j++) {
		d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	s[FS_SAC_GLOW] = sac_energy(p, calm, breath, double(d[SAC]));
	d[VISOR] = f32(visor(p, calm, c.st));
	for (int j = 0; j < DRIVES; j++) {
		s[FS_VD + j] = d[j];
	}
}

double clip(double t, double dt, double length) {
	if (t < 0.0) {
		return t;
	}
	t += dt;
	return t < length ? t : -1.0;
}

} // namespace

// FrostSpitterAvatar.apply_state from a sync (`more`: its HP first).
void fs_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const int64_t hp = int64_t(more[0]);
	const bool fresh = s[FRESH] != 0.0;
	const int was = int(s[FS_STATE]);
	if (fresh) {
		s[FS_RISE] = state == c.st.spawn ? 0.0 : 1.0;
	} else {
		const bool spat = state == c.st.active && was != c.st.active;
		const bool missed = state == c.st.recover && was == c.st.windup;
		if (spat || missed) { // (a tick's throw missed between two syncs still spits)
			s[FS_SPIT] = 0.0;
		}
		const int64_t had = int64_t(s[FS_HP]);
		if (hp >= 0 && had >= 0 && hp < had) {
			s[FS_HURT] = 0.0;
			s[FS_HURT_LEG] = double((int64_t(s[FS_HURT_LEG]) + 1) % LEGS);
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
	s[FS_STATE] = state;
	s[FS_TELL] = windup;
	s[FS_HP] = double(hp);
	if (fresh) {
		s[FRESH] = 0.0;
		fs_pose(s, c);
	}
}

// FrostSpitterAvatar.advance (`f`: the facing's yaw, get_parent().rotation.y).
void fs_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[FS_DIE] >= 0.0;
	const int state = int(s[FS_STATE]);
	const bool moving = state == c.st.move && !dying;
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	s[FS_SPEED] = lerpd(s[FS_SPEED], moving ? double(vel.length()) : 0.0, ease_rate(moving ? 8.0 : 14.0, dt));
	const double fy = double(f.facing_yaw);
	s[FS_OMEGA] = rig::turning(s[FS_OMEGA], fy, s[FS_LAST_FY], s[FS_HAVE_FY] != 0.0 && !dying, dt, ease_rate(10.0, dt));
	s[FS_LAST_FY] = fy;
	s[FS_HAVE_FY] = 1.0;
	const Vector3 local = axis_angle(UP, f32(-s[FS_LAST_FY])).xform(Vector3(vel.x, 0.0f, -vel.y));
	if (moving && double(local.length()) > 0.2) {
		const Vector2 dir(f32(s[FS_DIR]), f32(s[FS_DIR + 1]));
		const Vector2 to = dir.lerp(Vector2(local.x, local.z).normalized(), f32(ease_rate(10.0, dt)));
		const Vector2 now = double(to.length()) > 0.05 ? to.normalized() : dir;
		s[FS_DIR] = now.x;
		s[FS_DIR + 1] = now.y;
	}
	// The stride: the walk's and the turn's share, at a steady cadence.
	const double most = maxd(s[FS_SPEED] / MOVE_SPEED, std::fabs(s[FS_OMEGA]) / TURN_REF);
	s[FS_STRIDE] = toward(s[FS_STRIDE], mind(most, 1.0), dt * 5.0);
	s[FS_PHASE] = Math::fposmod(
			s[FS_PHASE] + STEP_HZ * maxd(1.0, most / STRIDE_MAX) * dt * signd(s[FS_STRIDE]), 1.0);
	const bool winding = state == c.st.windup && !dying;
	s[FS_COIL] = winding ? s[FS_TELL] : toward(s[FS_COIL], 0.0, dt * 10.0);
	const bool spawning = state == c.st.spawn;
	s[FS_RISE] = toward(s[FS_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 2.2));
	s[FS_SPIT] = clip(s[FS_SPIT], dt, SPIT_SECONDS);
	s[FS_HURT] = clip(s[FS_HURT], dt, HURT_SECONDS);
	if (dying) {
		s[FS_DIE] += dt;
	}
	fs_pose(s, c);
}

// FrostSpitterAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the visor's spec spans nothing: as it is).
int fs_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[FS_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		const double span = VAT_DRIVES[i].hi - lo;
		out[i] = Math::is_zero_approx(span) ? f32(v) : f32((v - lo) / span);
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
