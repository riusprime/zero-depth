// The Kiln Beetle's avatar on a batch row (zd_avatar.h KB_*): KilnBeetleAvatar's sync (apply_state), frame step
// (advance, _turning) and pose (_pose and its clips, leg_cycle, the glows), ported line by line in the same order and
// float width as the GDScript (src/presentation/world_view/kiln_beetle_avatar.gd): its numbers are doubles, its raw
// drives and its feet across the body floats (PackedFloat32Arrays), a leg's cycle a Vector3 (floats), and a value read
// off one of those a double in the arithmetic around it, as GDScript reads it.
// tests/unit/native/test_native_crowd_kiln_beetle.gd holds the drawn buffers equal to the GDScript avatar's bit for
// bit.

#include "zd_avatar.h"

#include <cmath>
#include <cstdint>
#include <initializer_list>

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2.hpp>

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
// KilnBeetleAvatar
constexpr double HEAT_REST = 1.2;
constexpr double HEAT_FULL = 7.0;
constexpr double HEAT_PUFF = 0.22;
constexpr double HEAT_BURST = 16.0;
constexpr double VISOR_REST = 1.6;
constexpr double VISOR_TELL = 7.0;
constexpr double TELEPORT_SPEED = 30.0;
constexpr double SLAM_SECONDS = 0.8;
constexpr double HURT_SECONDS = 0.35;
constexpr double DEATH_SECONDS = 1.0;
constexpr double MOVE_SPEED = 1.2;
constexpr double LEVER = 0.24;
constexpr double DUTY = 0.58;
constexpr double SWING = 0.5;
constexpr double LIFT = 0.42;
constexpr double FOLD = 0.55;
constexpr double STRIDE_MAX = 1.3;
constexpr double STEP_HZ = MOVE_SPEED * DUTY / (2.0 * SWING * LEVER);
constexpr int LEGS = 8;
constexpr double STRIDE_AT[LEGS] = { 0.06, 0.54, 0.02, 0.5, 0.56, 0.04, 0.52, 0.0 };
constexpr double BREATH_HZ = 0.42;
constexpr double BREATH_HOT = 0.55;
constexpr double CALM = 0.45;

// The raw drives (KilnBeetleAvatar's ROLL ... VISOR).
enum Drive {
	ROLL = 0,
	PITCH = 1,
	SWAY = 2,
	HEAD_P = 3,
	HEAD_Y = 4,
	SHELL_UP = 5,
	SHELL_SW = 6,
	LEG0 = 7,
	VISOR = 31,
	DRIVES = 32,
};

// VAT_DRIVES: [lo, hi] (none loops; the visor's spans nothing: sent as it is).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.3, 0.3 },
	{ -0.3, 0.5 },
	{ -0.3, 0.3 },
	{ -0.5, 0.5 },
	{ -0.6, 0.6 },
	{ -0.02, 0.08 },
	{ -0.3, 0.3 },
	{ -1.0, 1.0 }, { -0.8, 1.4 }, { -1.2, 1.2 }, // r1
	{ -1.0, 1.0 }, { -0.8, 1.4 }, { -1.2, 1.2 }, // r2
	{ -1.0, 1.0 }, { -0.8, 1.4 }, { -1.2, 1.2 }, // r3
	{ -1.0, 1.0 }, { -0.8, 1.4 }, { -1.2, 1.2 }, // r4
	{ -1.0, 1.0 }, { -0.8, 1.4 }, { -1.2, 1.2 }, // l1
	{ -1.0, 1.0 }, { -0.8, 1.4 }, { -1.2, 1.2 }, // l2
	{ -1.0, 1.0 }, { -0.8, 1.4 }, { -1.2, 1.2 }, // l3
	{ -1.0, 1.0 }, { -0.8, 1.4 }, { -1.2, 1.2 }, // l4
	{ 0.0, 0.0 },
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
inline double powd(double x, double y) {
	return UtilityFunctions::pow(x, y);
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

// AvatarBase.tell_crouch and tell_flashing.
inline double tell_crouch(double p) {
	return crouch_of_tell(p);
}
inline bool tell_flashing(double p) {
	return p >= TELL_FLASH_FROM && p <= 1.0;
}

// The pose's inputs read off the row once (the GDScript's fields).
struct P {
	const double *s;
	double t, heat, speed, omega, phase, stride, coil, rise, slam, hurt, die, tell;
	int state, hurt_leg;
	float foot_z[LEGS];
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
	return lerpd(a, b, sstep(0.55, 0.85, u - seg));
}

double twitch(double t, double every, double seed_off) {
	const double u = t / every + seed_off;
	const double seg = std::floor(u);
	if (hash(seg + 31.0) < 0.55) {
		return 0.0;
	}
	const double s = hash(seg + 17.0) > 0.5 ? 1.0 : -1.0;
	return s * sin_d(PI_D * clampd((u - seg - 0.4) / 0.05, 0.0, 1.0));
}

double wobble(double t, double seed_off) {
	return sin_d(TAU_D * (t * 3.7 + seed_off)) * 0.5 + sin_d(TAU_D * (t * 5.3 + seed_off * 1.3)) * 0.3 +
			sin_d(TAU_D * (t * 8.9 + seed_off * 0.7)) * 0.2;
}

Vector3 leg_cycle(double q) {
	if (q < DUTY) {
		const double s = q / DUTY;
		const double press = sin_d(PI_D * mind(s / 0.35, 1.0)) * 0.2;
		return Vector3(f32(1.0 - 2.0 * s), 0.0f, f32(-press));
	}
	const double w = (q - DUTY) / (1.0 - DUTY);
	const double up = sin_d(PI_D * w);
	const double tuck = -sin_d(PI_D * mind(w / 0.75, 1.0)) + 0.5 * sstep(0.55, 0.9, w) * (1.0 - w) * 4.0;
	return Vector3(f32(-1.0 + 2.0 * sstep(0.0, 1.0, w)), f32(up * up * (3.0 - 2.0 * up)), f32(tuck));
}

double walk_pose(const P &p, float *d, double k) {
	const double g = clampd(p.stride, 0.0, 1.0);
	for (int j = 0; j < LEGS; j++) {
		const double share = clampd((p.speed + p.omega * double(p.foot_z[j])) / MOVE_SPEED, -STRIDE_MAX, STRIDE_MAX);
		const Vector3 c = leg_cycle(Math::fposmod(p.phase - STRIDE_AT[j], 1.0));
		add(d, LEG0 + 3 * j, share * SWING * double(c.x));
		add(d, LEG0 + 3 * j + 1, std::fabs(share) * LIFT * double(c.y));
		add(d, LEG0 + 3 * j + 2, std::fabs(share) * FOLD * double(c.z));
	}
	if (g <= 0.0) {
		return 0.0;
	}
	const double ph = p.phase;
	const double walk = clampd(p.speed / MOVE_SPEED, 0.0, 1.0);
	add(d, ROLL, g * k * 0.035 * sin_d(TAU_D * (ph - 0.15)));
	add(d, SWAY, walk * k * 0.045 * sin_d(TAU_D * (ph + 0.1)));
	add(d, PITCH, walk * k * 0.012 * sin_d(2.0 * TAU_D * (ph - 0.05)));
	sub(d, HEAD_Y, walk * k * 0.03 * sin_d(TAU_D * (ph + 0.1)));
	add(d, HEAD_P, walk * k * 0.03 * cos_d(2.0 * TAU_D * (ph - 0.12)));
	const double land = powd(0.5 + 0.5 * cos_d(2.0 * TAU_D * (ph - 0.03)), 4.0);
	sub(d, SHELL_SW, g * k * 0.012 * land);
	return g * k * (0.004 - 0.009 * land);
}

double idle_pose(const P &p, float *d, double k, bool calm, double breath) {
	const double idle = (1.0 - clampd(p.stride, 0.0, 1.0)) * (1.0 - p.coil) * (p.die < 0.0 ? 1.0 : 0.0);
	if (idle <= 0.0) {
		return 0.0;
	}
	const double t = p.t;
	add(d, SHELL_SW, idle * k * 0.03 * breath);
	add(d, SHELL_UP, idle * k * 0.004 * (breath + 1.0));
	add(d, HEAD_Y, idle * k * 0.3 * scan(t, 2.2, 0.0));
	add(d, HEAD_P, idle * k * (0.08 * scan(t, 3.1, 5.0) - 0.02 * breath));
	if (!calm) {
		add(d, HEAD_P, idle * 0.07 * twitch(t, 3.7, 11.0));
		add(d, HEAD_Y, idle * 0.06 * twitch(t, 4.3, 23.0));
	}
	add(d, ROLL, idle * k * 0.022 * sin_d(0.55 * t));
	add(d, PITCH, idle * k * 0.012 * sin_d(0.55 * t + 1.7));
	add(d, SWAY, idle * k * 0.02 * sin_d(0.37 * t + 0.4));
	// A leg re-planted now and then (a different one each time): lifted, set down a little forward.
	const double u = t / 2.6;
	const double seg = std::floor(u);
	if (hash(seg + 7.0) > 0.45) {
		const int j = int(int64_t(hash(seg + 3.0) * double(LEGS)) % LEGS);
		const double e = sin_d(PI_D * clampd((u - seg - 0.2) / 0.22, 0.0, 1.0));
		add(d, LEG0 + 3 * j, idle * 0.12 * e);
		add(d, LEG0 + 3 * j + 1, idle * 0.35 * e);
		sub(d, LEG0 + 3 * j + 2, idle * 0.3 * e);
	}
	return idle * k * 0.005 * breath;
}

double heat_pose(const P &p, float *d, bool calm) {
	const double h = p.heat;
	if (h <= 0.0) {
		return 0.0;
	}
	add(d, SHELL_UP, 0.02 * powd(h, 1.5));
	if (!calm) {
		const double tr = h * h;
		add(d, SHELL_UP, 0.005 * tr * wobble(p.t * 3.1, 0.0));
		add(d, SHELL_SW, 0.014 * tr * wobble(p.t * 2.7, 2.0));
		add(d, ROLL, 0.01 * tr * wobble(p.t * 2.3, 4.0));
	}
	return 0.0;
}

double tell_pose(const P &p, float *d, double k, bool calm, const States &st) {
	const double q = p.coil;
	if (q <= 0.0) {
		return 0.0;
	}
	const double crouch = sin_d(PI_D * clampd(q / 0.32, 0.0, 1.0)) * (1.0 - sstep(0.12, 0.4, q));
	const double rear = sstep(0.15, 0.65, q);
	add(d, PITCH, 0.38 * rear * k - 0.03 * crouch);
	add(d, SHELL_SW, 0.07 * rear - 0.06 * crouch);
	add(d, HEAD_P, 0.3 * rear - 0.1 * crouch);
	mul(d, HEAD_Y, 1.0 - rear);
	for (int side = 0; side < 2; side++) {
		const int o = 4 * side;
		const int j1 = LEG0 + 3 * o;
		add(d, j1, 0.35 * rear); // the front legs: up and reaching
		add(d, j1 + 1, 1.0 * rear - 0.15 * crouch);
		add(d, j1 + 2, 0.55 * rear);
		const int j2 = LEG0 + 3 * (o + 1);
		add(d, j2, 0.15 * rear);
		add(d, j2 + 1, 0.35 * rear);
		add(d, j2 + 2, 0.2 * rear);
		const int j3 = LEG0 + 3 * (o + 2); // the hind legs brace and take the weight
		sub(d, j3, 0.15 * rear);
		sub(d, j3 + 1, 0.25 * rear + 0.1 * crouch);
		sub(d, j3 + 2, 0.3 * rear);
		const int j4 = LEG0 + 3 * (o + 3);
		sub(d, j4, 0.2 * rear);
		sub(d, j4 + 1, 0.1 * rear + 0.1 * crouch);
		sub(d, j4 + 2, 0.2 * rear);
	}
	if (!calm && p.state == st.windup) {
		const double top = sstep(0.6, 0.75, q);
		add(d, ROLL, 0.012 * top * sin_d(TAU_D * 13.0 * p.t));
		add(d, SHELL_UP, 0.003 * top * sin_d(TAU_D * 17.0 * p.t));
		if (tell_flashing(q)) {
			for (int side = 0; side < 2; side++) {
				add(d, LEG0 + 3 * (4 * side) + 2, 0.15 * sin_d(TAU_D * 9.0 * p.t + double(side)));
			}
		}
	}
	return -0.02 * crouch * k;
}

double slam_pose(const P &p, float *d, double k, bool calm) {
	if (p.slam < 0.0) {
		return 0.0;
	}
	const double u = p.slam / SLAM_SECONDS;
	const double down = sstep(0.0, 0.05, u) * (1.0 - sstep(0.18, 0.65, u));
	const double squash = sstep(0.02, 0.07, u) * (1.0 - sstep(0.07, 0.3, u));
	const double rebound = sin_d(PI_D * clampd((u - 0.18) / 0.3, 0.0, 1.0));
	const double heave = sin_d(PI_D * clampd((u - 0.45) / 0.45, 0.0, 1.0));
	add(d, PITCH, (-0.16 * down + 0.04 * heave) * k);
	add(d, SHELL_SW, -0.24 * squash + 0.07 * rebound);
	add(d, HEAD_P, -0.2 * down + 0.08 * heave);
	for (int side = 0; side < 2; side++) {
		const int o = 4 * side;
		for (int leg = 0; leg < 2; leg++) { // the front pair splayed out under the blow, then re-planted in turn
			const int j = LEG0 + 3 * (o + leg);
			const double step = sin_d(PI_D * clampd((u - 0.5 - 0.12 * double(leg) - 0.06 * double(side)) / 0.22, 0.0, 1.0));
			add(d, j, (0.3 - 0.15 * double(leg)) * down + 0.15 * step);
			add(d, j + 1, -0.3 * down + 0.4 * step);
			add(d, j + 2, 0.6 * down - 0.3 * step);
		}
		for (int leg = 2; leg <= 3; leg++) {
			add(d, LEG0 + 3 * (o + leg) + 1, 0.15 * down);
		}
	}
	if (!calm) {
		const double rattle = (1.0 - sstep(0.1, 0.6, u)) * sstep(0.03, 0.06, u);
		add(d, SHELL_UP, 0.008 * rattle * sin_d(TAU_D * 19.0 * p.slam));
		add(d, ROLL, 0.03 * rattle * sin_d(TAU_D * 11.0 * p.slam + 0.7));
	}
	return (-0.045 * down + 0.012 * heave) * k;
}

double hurt_pose(const P &p, float *d, double k, bool calm) {
	if (p.hurt < 0.0) {
		return 0.0;
	}
	const double h = p.hurt / HURT_SECONDS;
	const double e = sin_d(PI_D * mind(h / 0.25, 1.0)) * (1.0 - sstep(0.25, 1.0, h));
	sub(d, SHELL_SW, 0.07 * e * k);
	add(d, SHELL_UP, 0.008 * e);
	sub(d, HEAD_P, 0.15 * e * k);
	sub(d, PITCH, 0.03 * e * k);
	const int j = LEG0 + 3 * p.hurt_leg;
	add(d, j + 1, 0.45 * e * k);
	sub(d, j + 2, 0.4 * e * k);
	if (!calm) {
		add(d, j, 0.25 * e * sin_d(TAU_D * 8.0 * p.hurt));
		add(d, ROLL, 0.03 * e * sin_d(TAU_D * 12.0 * p.hurt));
	}
	return -0.012 * e * k;
}

double rise_pose(const P &p, float *d) {
	const double r = 1.0 - p.rise;
	if (r <= 0.0) {
		return 0.0;
	}
	for (int j = 0; j < LEGS; j++) {
		add(d, LEG0 + 3 * j + 1, 0.5 * r);
		sub(d, LEG0 + 3 * j + 2, 0.9 * r);
	}
	sub(d, SHELL_SW, 0.05 * r);
	sub(d, HEAD_P, 0.25 * r);
	return -0.1 * r;
}

double death_pose(const P &p, float *d, double lift, bool calm) {
	if (p.die < 0.0) {
		return lift;
	}
	const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
	const double sag = sstep(0.0, 0.18, u);
	const double keep = 1.0 - sag;
	for (int j : { ROLL, PITCH, SWAY, HEAD_Y }) {
		mul(d, j, keep);
	}
	lift *= keep;
	const double swell_u = powd(sstep(0.08, 1.0, u), 1.6);
	lerp_to(d, SHELL_SW, 0.28 * swell_u, sag);
	lerp_to(d, SHELL_UP, 0.012 + 0.055 * swell_u, sag);
	lerp_to(d, HEAD_P, -0.18 + 0.3 * sstep(0.7, 1.0, u), sag);
	const double scrabble = sag * (1.0 - sstep(0.8, 0.97, u));
	for (int j = 0; j < LEGS; j++) {
		const bool front = j % 4 < 2;
		const int b = LEG0 + 3 * j;
		lerp_to(d, b, front ? 0.3 : -0.3, sag);
		lerp_to(d, b + 1, 0.32, sag);
		lerp_to(d, b + 2, 0.6, sag);
		if (!calm) {
			const double f = 7.0 + 5.0 * u;
			const double jd = double(j);
			add(d, b, 0.18 * scrabble * sin_d(TAU_D * f * p.die + jd * 1.7));
			add(d, b + 1, 0.3 * scrabble * sin_d(TAU_D * f * p.die + jd * 2.3 + 1.0));
			add(d, b + 2, 0.25 * scrabble * sin_d(TAU_D * f * p.die + jd * 0.9 + 2.0));
		}
	}
	if (!calm) {
		const double shake = 0.004 + 0.035 * u * u;
		add(d, ROLL, shake * wobble(p.die * 9.0, 1.0));
		add(d, PITCH, shake * wobble(p.die * 8.0, 3.0));
		add(d, SHELL_UP, shake * 0.25 * wobble(p.die * 11.0, 5.0));
	}
	return lift - 0.045 * sag + 0.03 * sstep(0.75, 1.0, u);
}

double heat_energy(const P &p, bool calm, double breath) {
	double e = HEAT_REST + HEAT_FULL * powd(p.heat, 1.2);
	e *= 1.0 + HEAT_PUFF * (calm ? 0.4 : 1.0) * maxd(0.0, breath);
	e *= 1.0 - 0.3 * sstep(0.1, 0.6, p.coil);
	if (p.slam >= 0.0) {
		e += 3.5 * (1.0 - sstep(0.0, 0.55, p.slam / SLAM_SECONDS));
	}
	if (p.hurt >= 0.0) {
		e += 1.5 * (1.0 - p.hurt / HURT_SECONDS);
	}
	if (p.die >= 0.0) {
		const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
		e = lerpd(e, HEAT_BURST, sstep(0.0, 1.0, u));
		if (!calm) {
			e *= 1.0 + 0.15 * sin_d(TAU_D * (6.0 + 10.0 * u) * p.die);
		}
	}
	return e;
}

double visor(const P &p, bool calm, const States &st) {
	double e = VISOR_REST;
	if (p.state == st.windup && p.die < 0.0) {
		e = VISOR_REST + (VISOR_TELL - VISOR_REST) * tell_crouch(p.tell);
		if (tell_flashing(p.tell)) {
			e = calm || int64_t(p.t * TELL_FLICKER_HZ * 2.0) % 2 == 0 ? VISOR_TELL * 1.2 : VISOR_TELL * 0.8;
		}
	}
	if (p.slam >= 0.0) {
		e = maxd(e, VISOR_TELL * (1.0 - sstep(0.0, 0.5, p.slam / SLAM_SECONDS)));
	}
	if (p.die >= 0.0) {
		e = maxd(e, lerpd(VISOR_REST, VISOR_TELL * 1.4, clampd(p.die / DEATH_SECONDS, 0.0, 1.0)));
	}
	return e;
}

// KilnBeetleAvatar._pose: the raw drives, the lift and the glows from the state.
void kb_pose(double *s, const Ctx &c) {
	const bool calm = c.calm;
	const double k = calm ? CALM : 1.0;
	P p;
	p.s = s;
	p.t = s[T];
	p.heat = s[KB_HEAT];
	p.speed = s[KB_SPEED];
	p.omega = s[KB_OMEGA];
	p.phase = s[KB_PHASE];
	p.stride = s[KB_STRIDE];
	p.coil = s[KB_COIL];
	p.rise = s[KB_RISE];
	p.slam = s[KB_SLAM];
	p.hurt = s[KB_HURT];
	p.die = s[KB_DIE];
	p.tell = s[KB_TELL];
	p.state = int(s[KB_STATE]);
	p.hurt_leg = int(s[KB_HURT_LEG]);
	for (int j = 0; j < LEGS; j++) {
		p.foot_z[j] = f32(s[KB_FOOT_Z + j]);
	}
	float d[DRIVES] = {};
	double lift = walk_pose(p, d, k);
	const double breath = sin_d(TAU_D * p.t * (BREATH_HZ + BREATH_HOT * p.heat));
	lift += idle_pose(p, d, k, calm, breath);
	lift += heat_pose(p, d, calm);
	lift += tell_pose(p, d, k, calm, c.st);
	lift += slam_pose(p, d, k, calm);
	lift += hurt_pose(p, d, k, calm);
	lift += rise_pose(p, d);
	lift = death_pose(p, d, lift, calm);
	s[KB_HEAT_GLOW] = heat_energy(p, calm, breath);
	d[VISOR] = f32(visor(p, calm, c.st));
	for (int j = 0; j < DRIVES; j++) {
		if (j != VISOR) {
			d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
		}
	}
	for (int j = 0; j < DRIVES; j++) {
		s[KB_VD + j] = d[j];
	}
	s[KB_LIFT] = lift;
}

// KilnBeetleAvatar._turning: the facing's turn rate from its yaw now (the facing node's rotation.y).
void turning(double *s, double dt, bool dying, const Frame &f) {
	const double fy = double(f.facing_yaw);
	double w = 0.0;
	if (s[KB_HAVE_FY] != 0.0 && !dying) {
		w = clampd(Math::wrapf(fy - s[KB_LAST_FY], -PI_D, PI_D) / dt, -4.0, 4.0);
	}
	s[KB_OMEGA] = lerpd(s[KB_OMEGA], w, ease_rate(10.0, dt));
	s[KB_LAST_FY] = fy;
	s[KB_HAVE_FY] = 1.0;
}

double clip(double t, double dt, double length) {
	if (t < 0.0) {
		return t;
	}
	t += dt;
	return t < length ? t : -1.0;
}

} // namespace

// KilnBeetleAvatar.apply_state from a sync (`more`: its HP, its full HP).
void kb_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const int64_t hp = int64_t(more[0]);
	const int64_t full = int64_t(more[1]);
	const bool fresh = s[FRESH] != 0.0;
	const int was = int(s[KB_STATE]);
	if (fresh) {
		s[KB_RISE] = state == c.st.spawn ? 0.0 : 1.0;
	} else {
		const bool struck = state == c.st.active && was != c.st.active;
		const bool missed = state == c.st.recover && was == c.st.windup;
		if (struck || missed) { // (a tick's strike missed between two syncs still slams)
			s[KB_SLAM] = 0.0;
		}
		const int64_t had = int64_t(s[KB_HP]);
		if (hp >= 0 && had >= 0 && hp < had) {
			s[KB_HURT] = 0.0;
			s[KB_HURT_LEG] = double((int64_t(s[KB_HURT_LEG]) + 3) % LEGS);
		}
	}
	if (hp >= 0 && full > 0) {
		s[KB_HEAT] = clampd(1.0 - double(hp) / double(full), 0.0, 1.0);
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
	s[KB_STATE] = state;
	s[KB_TELL] = windup;
	s[KB_HP] = double(hp);
	if (fresh) {
		s[FRESH] = 0.0;
		kb_pose(s, c);
	}
}

// KilnBeetleAvatar.advance
void kb_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[KB_DIE] >= 0.0;
	const int state = int(s[KB_STATE]);
	const bool moving = state == c.st.move && !dying;
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	s[KB_SPEED] = lerpd(s[KB_SPEED], moving ? double(vel.length()) : 0.0, ease_rate(moving ? 8.0 : 14.0, dt));
	turning(s, dt, dying, f);
	// The stride: each leg's share of the walk and the turn (its side's ground speed), at a steady cadence.
	double most = 0.0;
	for (int k = 0; k < LEGS; k++) {
		most = maxd(most, std::fabs(s[KB_SPEED] + s[KB_OMEGA] * double(f32(s[KB_FOOT_Z + k]))) / MOVE_SPEED);
	}
	s[KB_STRIDE] = toward(s[KB_STRIDE], mind(most, 1.0), dt * 4.0);
	s[KB_PHASE] = Math::fposmod(
			s[KB_PHASE] + STEP_HZ * maxd(1.0, most / STRIDE_MAX) * dt * signd(s[KB_STRIDE]), 1.0);
	const bool winding = state == c.st.windup && !dying;
	s[KB_COIL] = winding ? s[KB_TELL] : toward(s[KB_COIL], 0.0, dt * 14.0);
	const bool spawning = state == c.st.spawn;
	s[KB_RISE] = toward(s[KB_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 2.0));
	s[KB_SLAM] = clip(s[KB_SLAM], dt, SLAM_SECONDS);
	s[KB_HURT] = clip(s[KB_HURT], dt, HURT_SECONDS);
	if (dying) {
		s[KB_DIE] += dt;
	}
	kb_pose(s, c);
}

// KilnBeetleAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the visor's spec spans nothing: as it is).
int kb_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[KB_VD + i]));
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
