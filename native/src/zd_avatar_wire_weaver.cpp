// The Wire Weaver's avatar on a batch row (zd_avatar.h WW_*): WireWeaverAvatar's sync (apply_state), frame step
// (advance, _turning) and pose (_pose and its clips, leg_cycle, the drum's turn, the glows), ported line by line in the
// same order and float width as the GDScript (src/presentation/world_view/wire_weaver_avatar.gd): its numbers are
// doubles, its raw drives and its feet across the body floats (PackedFloat32Arrays), a leg's cycle and the facing's
// direction floats (Vector3, Vector2), and a value read off one of those a double in the arithmetic around it, as
// GDScript reads it.
// tests/unit/native/test_native_crowd_wire_weaver.gd holds the drawn buffers equal to the GDScript avatar's bit for
// bit.

#include "zd_avatar.h"

#include <cmath>
#include <cstdint>
#include <initializer_list>

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
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
// WireWeaverAvatar
constexpr double VISOR_REST = 1.6;
constexpr double VISOR_TELL = 7.0;
constexpr double SPARK_REST = 1.4;
constexpr double SPARK_TELL = 7.0;
constexpr double SPARK_PLANT = 11.0;
constexpr double TELEPORT_SPEED = 30.0;
constexpr double PLANT_SECONDS = 0.5;
constexpr double RELOAD_FROM = 0.7;
constexpr double RELOAD_SECONDS = 0.6;
constexpr double HURT_SECONDS = 0.3;
constexpr double DEATH_SECONDS = 1.0;
constexpr double MOVE_SPEED = 2.6;
constexpr double DUTY = 0.56;
constexpr double LEVER = 0.45;
constexpr double SWING = 0.42;
constexpr double LIFT = 0.5;
constexpr double FOLD = 0.75;
constexpr double STRIDE_MAX = 1.3;
constexpr double STEP_HZ = MOVE_SPEED * DUTY / (2.0 * SWING * LEVER);
constexpr int LEGS = 4;
constexpr double STRIDE_AT[LEGS] = { 0.5, 0.0, 0.04, 0.54 };
constexpr int ARMS = 2;
constexpr double CALM = 0.45;
constexpr double BREATH_HZ = 0.5;
constexpr double POST_MIN = 0.02;

// The raw drives (WireWeaverAvatar's ROLL ... VISOR).
enum Drive {
	ROLL = 0,
	PITCH = 1,
	SWAY = 2,
	HEAD_P = 3,
	HEAD_Y = 4,
	SPOOL = 5,
	LEG0 = 6,
	ARM0 = 18,
	POST0 = 24,
	VISOR = 30,
	DRIVES = 31,
};

// VAT_DRIVES: [lo, hi] (none loops; the visor's spans nothing: sent as it is).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.7, 0.4 },
	{ -0.5, 0.5 },
	{ -0.4, 0.4 },
	{ -0.5, 0.5 },
	{ -0.6, 0.6 },
	{ -0.6, 0.6 },
	{ -0.9, 0.9 }, { -0.7, 1.3 }, { -1.3, 1.3 }, // rc
	{ -0.9, 0.9 }, { -0.7, 1.3 }, { -1.3, 1.3 }, // rr
	{ -0.9, 0.9 }, { -0.7, 1.3 }, { -1.3, 1.3 }, // ml
	{ -0.9, 0.9 }, { -0.7, 1.3 }, { -1.3, 1.3 }, // fr
	{ -0.8, 1.2 }, { -1.0, 1.4 }, { -1.3, 1.3 }, // r
	{ -0.8, 1.2 }, { -1.0, 1.4 }, { -1.3, 1.3 }, // l
	{ -0.3, 0.5 }, { -1.4, 1.2 }, { POST_MIN, 1.0 }, // +Z post
	{ -0.3, 0.5 }, { -1.4, 1.2 }, { POST_MIN, 1.0 }, // -Z post
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
	double t, tell, speed, omega, phase, stride, coil, rise, plant, hurt, die;
	int state, hurt_leg;
	float foot_z[LEGS];
};

Vector3 leg_cycle(double q) {
	if (q < DUTY) {
		const double s = q / DUTY;
		return Vector3(f32(1.0 - 2.0 * s), 0.0f, f32(-sin_d(PI_D * mind(s / 0.35, 1.0)) * 0.15));
	}
	const double w = (q - DUTY) / (1.0 - DUTY);
	const double up = sin_d(PI_D * w);
	const double tuck = -sin_d(PI_D * mind(w / 0.75, 1.0)) + 0.5 * sstep(0.55, 0.9, w) * (1.0 - w) * 4.0;
	return Vector3(f32(-1.0 + 2.0 * sstep(0.0, 1.0, w)), f32(up * up * (3.0 - 2.0 * up)), f32(tuck));
}

// WireWeaverAvatar._reloading: 0 while no reload is coming, rising to 1 as the new posts stand.
double reloading(const P &p) {
	if (p.plant < RELOAD_FROM) {
		return 0.0;
	}
	return sstep(0.0, 1.0, (p.plant - RELOAD_FROM) / RELOAD_SECONDS);
}

double spool_turn(const P &p, double k) {
	double a = k * (0.06 * sin_d(TAU_D * p.phase) * clampd(p.stride, 0.0, 1.0) + 0.05 * rig::scan(p.t, 1.6, 9.0));
	a -= 0.35 * sstep(0.1, 0.7, p.coil);
	if (p.plant >= 0.0) {
		const double held = 1.0 - sstep(0.0, 0.25 * PLANT_SECONDS, p.plant);
		const double ring = sin_d(TAU_D * 2.5 * p.plant) * (1.0 - sstep(0.0, 1.2 * PLANT_SECONDS, p.plant));
		a += -0.35 * held + 0.45 * k * ring - 0.25 * sin_d(PI_D * reloading(p));
	}
	if (p.die >= 0.0) {
		a = lerpd(a, 0.3, sstep(0.0, 0.5, p.die / DEATH_SECONDS));
	}
	return a;
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
	const double walk = clampd(std::fabs(p.speed) / MOVE_SPEED, 0.0, 1.0);
	add(d, ROLL, g * k * 0.05 * sin_d(TAU_D * (ph - 0.1)));
	add(d, SWAY, walk * k * 0.06 * sin_d(TAU_D * (ph + 0.15)));
	add(d, PITCH, walk * k * (0.02 * sin_d(2.0 * TAU_D * (ph - 0.05)) - 0.04 * signd(p.speed)));
	sub(d, HEAD_Y, walk * k * 0.05 * sin_d(TAU_D * (ph + 0.15)));
	add(d, HEAD_P, walk * k * 0.04 * cos_d(2.0 * TAU_D * (ph - 0.1)));
	for (int a = 0; a < ARMS; a++) {
		const double s = a == 0 ? 1.0 : -1.0;
		add(d, ARM0 + 3 * a + 1, walk * k * (0.12 * s * sin_d(TAU_D * ph) - 0.05));
		add(d, ARM0 + 3 * a + 2, walk * k * 0.1 * sin_d(TAU_D * ph + 0.8 * s));
	}
	for (int q = 0; q < 2; q++) {
		add(d, POST0 + 3 * q + 1, walk * k * 0.06 * sin_d(2.0 * TAU_D * (ph - 0.2) + double(q)));
	}
	const double land = powd(0.5 + 0.5 * cos_d(2.0 * TAU_D * (ph - 0.05)), 3.0);
	return g * k * (0.012 - 0.022 * land);
}

double idle_pose(const P &p, float *d, double k, bool calm) {
	const double idle = (1.0 - clampd(p.stride, 0.0, 1.0)) * (1.0 - p.coil) * (p.die < 0.0 ? 1.0 : 0.0);
	if (idle <= 0.0) {
		return 0.0;
	}
	const double t = p.t;
	const double breath = sin_d(TAU_D * BREATH_HZ * t);
	add(d, HEAD_Y, idle * k * 0.35 * rig::scan(t, 2.0, 0.0));
	add(d, HEAD_P, idle * k * (0.12 * rig::scan(t, 2.9, 5.0) - 0.03 * breath));
	if (!calm) {
		add(d, HEAD_P, idle * 0.08 * rig::twitch(t, 3.3, 11.0));
		add(d, HEAD_Y, idle * 0.07 * rig::twitch(t, 4.1, 23.0));
	}
	add(d, ROLL, idle * k * 0.03 * sin_d(0.6 * t));
	add(d, PITCH, idle * k * 0.02 * sin_d(0.6 * t + 1.7));
	add(d, SWAY, idle * k * 0.04 * sin_d(0.4 * t + 0.4));
	for (int a = 0; a < ARMS; a++) {
		const double flex = sin_d(PI_D * clampd(Math::fposmod(t / 1.7 + 0.5 * double(a), 1.0) / 0.3, 0.0, 1.0));
		add(d, ARM0 + 3 * a + 1, idle * k * (0.06 * breath + 0.1 * flex));
		add(d, ARM0 + 3 * a + 2, idle * k * 0.3 * flex);
	}
	// A leg re-planted now and then (a different one each time): lifted, set down a little forward.
	const double u = t / 2.4;
	const double seg = std::floor(u);
	if (rig::hash01(seg + 7.0) > 0.4) {
		const int j = int(int64_t(rig::hash01(seg + 3.0) * double(LEGS)) % LEGS);
		const double e = sin_d(PI_D * clampd((u - seg - 0.2) / 0.2, 0.0, 1.0));
		add(d, LEG0 + 3 * j, idle * 0.15 * e);
		add(d, LEG0 + 3 * j + 1, idle * 0.45 * e);
		sub(d, LEG0 + 3 * j + 2, idle * 0.4 * e);
	}
	return idle * k * 0.008 * breath;
}

double tell_pose(const P &p, float *d, double k, bool calm, const States &st) {
	const double q = p.coil;
	if (q <= 0.0) {
		return 0.0;
	}
	const double crouch = sin_d(PI_D * clampd(q / 0.3, 0.0, 1.0)) * (1.0 - sstep(0.1, 0.35, q));
	const double brace = sstep(0.15, 0.6, q);
	const double lift_posts = sstep(0.2, 0.75, q);
	add(d, PITCH, 0.16 * brace * k - 0.05 * crouch);
	add(d, HEAD_P, 0.22 * brace - 0.12 * crouch);
	mul(d, HEAD_Y, 1.0 - brace);
	for (int j = 0; j < LEGS; j++) {
		sub(d, LEG0 + 3 * j + 1, 0.18 * brace + 0.15 * crouch);
		add(d, LEG0 + 3 * j + 2, 0.25 * brace);
	}
	for (int a = 0; a < ARMS; a++) {
		add(d, ARM0 + 3 * a, 0.35 * brace);
		add(d, ARM0 + 3 * a + 1, 0.75 * brace - 0.1 * crouch);
		add(d, ARM0 + 3 * a + 2, 0.6 * brace);
	}
	for (int r = 0; r < 2; r++) {
		add(d, POST0 + 3 * r, 0.16 * lift_posts);
		add(d, POST0 + 3 * r + 1, 0.35 * lift_posts);
	}
	if (!calm && p.state == st.windup) {
		const double top = sstep(0.6, 0.8, q);
		add(d, ROLL, 0.015 * top * sin_d(TAU_D * 13.0 * p.t));
		for (int r = 0; r < 2; r++) {
			add(d, POST0 + 3 * r + 1, 0.05 * top * sin_d(TAU_D * 11.0 * p.t + double(r)));
		}
		if (tell_flashing(q)) {
			for (int a = 0; a < ARMS; a++) {
				add(d, ARM0 + 3 * a + 2, 0.12 * sin_d(TAU_D * 9.0 * p.t + double(a)));
			}
		}
	}
	return -0.04 * crouch * k + 0.01 * brace * k;
}

double plant_pose(const P &p, float *d, double k, bool calm) {
	if (p.plant < 0.0) {
		return 0.0;
	}
	const double u = clampd(p.plant / PLANT_SECONDS, 0.0, 1.0);
	const double fly = sstep(0.0, 0.3, u);
	const double kick = sin_d(PI_D * clampd(u / 0.35, 0.0, 1.0));
	const double spread = sin_d(PI_D * clampd((u - 0.05) / 0.8, 0.0, 1.0));
	const double held = 1.0 - sstep(0.0, 0.25, u); // the tell's hold, let go
	add(d, PITCH, (0.22 * kick * held - 0.12 * kick * (1.0 - held) + 0.16 * held) * k);
	add(d, HEAD_P, 0.2 * held - 0.1 * kick);
	for (int a = 0; a < ARMS; a++) {
		add(d, ARM0 + 3 * a, 0.35 * held + 0.75 * spread);
		add(d, ARM0 + 3 * a + 1, 0.75 * held + 0.25 * spread);
		add(d, ARM0 + 3 * a + 2, 0.6 * held + 0.5 * spread);
	}
	for (int j = 0; j < LEGS; j++) {
		sub(d, LEG0 + 3 * j + 1, 0.18 * held + 0.12 * kick);
		add(d, LEG0 + 3 * j + 2, 0.25 * held);
	}
	// The posts: launched from the tell's hold, then the new ones rising out of the straps as they grow.
	const double r = reloading(p);
	for (int q = 0; q < 2; q++) {
		if (p.plant < RELOAD_FROM) {
			d[POST0 + 3 * q] = f32(0.16 + 0.3 * fly);
			d[POST0 + 3 * q + 1] = f32(0.35 + 0.8 * fly);
			d[POST0 + 3 * q + 2] = f32(lerpd(1.0, POST_MIN, fly));
		} else {
			d[POST0 + 3 * q] = f32(-0.25 * (1.0 - r));
			d[POST0 + 3 * q + 1] = 0.0f;
			d[POST0 + 3 * q + 2] = f32(lerpd(POST_MIN, 1.0, r));
		}
	}
	if (!calm) {
		add(d, ROLL, 0.03 * kick * sin_d(TAU_D * 9.0 * p.plant));
	}
	return (-0.03 * kick + 0.01 * held) * k;
}

double hurt_pose(const P &p, float *d, double k, bool calm) {
	if (p.hurt < 0.0) {
		return 0.0;
	}
	const double h = p.hurt / HURT_SECONDS;
	const double e = sstep(0.0, 0.15, h) * (1.0 - sstep(0.2, 1.0, h));
	add(d, PITCH, 0.1 * e * k);
	sub(d, HEAD_P, 0.25 * e * k);
	add(d, ROLL, 0.05 * e * k * (p.hurt_leg % 2 == 0 ? 1.0 : -1.0));
	const int j = LEG0 + 3 * p.hurt_leg;
	add(d, j + 1, 0.5 * e * k);
	sub(d, j + 2, 0.45 * e * k);
	for (int a = 0; a < ARMS; a++) {
		add(d, ARM0 + 3 * a + 1, 0.25 * e * k);
	}
	if (!calm) {
		add(d, j, 0.25 * e * sin_d(TAU_D * 8.0 * p.hurt));
		for (int q = 0; q < 2; q++) {
			add(d, POST0 + 3 * q + 1, 0.12 * e * sin_d(TAU_D * 12.0 * p.hurt + double(q)));
		}
	}
	return -0.02 * e * k;
}

double rise_pose(const P &p, float *d) {
	const double r = 1.0 - p.rise;
	if (r <= 0.0) {
		return 0.0;
	}
	for (int j = 0; j < LEGS; j++) {
		add(d, LEG0 + 3 * j + 1, 0.55 * r);
		sub(d, LEG0 + 3 * j + 2, 0.8 * r);
	}
	for (int a = 0; a < ARMS; a++) {
		sub(d, ARM0 + 3 * a + 1, 0.4 * r);
		sub(d, ARM0 + 3 * a + 2, 0.7 * r);
	}
	sub(d, HEAD_P, 0.25 * r);
	return -0.22 * r;
}

double death_pose(const P &p, float *d, double lift, bool calm) {
	if (p.die < 0.0) {
		return lift;
	}
	const double u = clampd(p.die / (DEATH_SECONDS * 0.9), 0.0, 1.0);
	const double buckle = sstep(0.0, 0.45, u);
	const double settle = sstep(0.35, 0.9, u);
	const double keep = 1.0 - buckle;
	for (int j : { SWAY, HEAD_Y }) {
		mul(d, j, keep);
	}
	lift *= keep;
	lerp_to(d, ROLL, -0.32, settle);
	lerp_to(d, PITCH, -0.12, buckle);
	lerp_to(d, HEAD_P, -0.35, buckle);
	for (int j = 0; j < LEGS; j++) {
		const int b = LEG0 + 3 * j;
		mul(d, b, keep);
		lerp_to(d, b + 1, 0.95, buckle);
		lerp_to(d, b + 2, 0.9, buckle);
		if (!calm) {
			const double scrabble = buckle * (1.0 - sstep(0.5, 0.8, u));
			add(d, b + 2, 0.3 * scrabble * sin_d(TAU_D * 8.0 * p.die + double(j) * 1.9));
		}
	}
	for (int a = 0; a < ARMS; a++) {
		lerp_to(d, ARM0 + 3 * a, 0.3, buckle);
		lerp_to(d, ARM0 + 3 * a + 1, -0.7, buckle);
		lerp_to(d, ARM0 + 3 * a + 2, -0.6, settle);
	}
	for (int q = 0; q < 2; q++) {
		lerp_to(d, POST0 + 3 * q + 1, -1.2, sstep(0.15, 0.75, u));
	}
	return lift - 0.3 * buckle;
}

double spark_energy(const P &p, bool calm) {
	double e = SPARK_REST;
	if (!calm) {
		e *= 1.0 + 0.25 * sin_d(TAU_D * 7.0 * p.t) * sin_d(TAU_D * 2.3 * p.t);
	}
	if (p.coil > 0.0) {
		e = lerpd(e, SPARK_TELL, sstep(0.1, 0.8, p.coil));
		if (!calm && tell_flashing(p.coil)) {
			e *= 1.0 + 0.35 * signd(sin_d(TAU_D * TELL_FLICKER_HZ * 2.0 * p.t));
		}
	}
	if (p.plant >= 0.0) {
		const double u = p.plant / PLANT_SECONDS;
		e = maxd(e, SPARK_PLANT * (1.0 - sstep(0.0, 0.4, u)));
		if (p.plant >= RELOAD_FROM) {
			e = SPARK_REST * reloading(p);
		}
	}
	if (p.die >= 0.0) {
		const double u = clampd(p.die / DEATH_SECONDS, 0.0, 1.0);
		const double fizz = calm ? 1.0 : 0.6 + 0.8 * std::fabs(sin_d(TAU_D * 11.0 * p.die));
		e = lerpd(e, 0.0, sstep(0.2, 1.0, u)) * fizz;
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
	if (p.plant >= 0.0) {
		e = maxd(e, VISOR_TELL * (1.0 - sstep(0.0, 0.6, p.plant / PLANT_SECONDS)));
	}
	if (p.die >= 0.0) {
		e *= 1.0 - sstep(0.3, 1.0, p.die / DEATH_SECONDS) * 0.95;
	}
	return e;
}

// WireWeaverAvatar._pose: the raw drives, the lift and the glows from the state.
void ww_pose(double *s, const Ctx &c) {
	const bool calm = c.calm;
	const double k = calm ? CALM : 1.0;
	P p;
	p.t = s[T];
	p.tell = s[WW_TELL];
	p.speed = s[WW_SPEED];
	p.omega = s[WW_OMEGA];
	p.phase = s[WW_PHASE];
	p.stride = s[WW_STRIDE];
	p.coil = s[WW_COIL];
	p.rise = s[WW_RISE];
	p.plant = s[WW_PLANT];
	p.hurt = s[WW_HURT];
	p.die = s[WW_DIE];
	p.state = int(s[WW_STATE]);
	p.hurt_leg = int(s[WW_HURT_LEG]);
	for (int j = 0; j < LEGS; j++) {
		p.foot_z[j] = f32(s[WW_FOOT_Z + j]);
	}
	float d[DRIVES] = {};
	d[POST0 + 2] = 1.0f;
	d[POST0 + 5] = 1.0f;
	d[SPOOL] = f32(spool_turn(p, k));
	double lift = walk_pose(p, d, k);
	lift += idle_pose(p, d, k, calm);
	lift += tell_pose(p, d, k, calm, c.st);
	lift += plant_pose(p, d, k, calm);
	lift += hurt_pose(p, d, k, calm);
	lift += rise_pose(p, d);
	lift = death_pose(p, d, lift, calm);
	s[WW_SPARK] = spark_energy(p, calm);
	d[VISOR] = f32(visor(p, calm, c.st));
	for (int j = 0; j < DRIVES; j++) {
		if (j != VISOR) {
			d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
		}
	}
	for (int j = 0; j < DRIVES; j++) {
		s[WW_VD + j] = d[j];
	}
	s[WW_LIFT] = lift;
}

// WireWeaverAvatar._turning: the facing's turn rate from its yaw now (the facing node's rotation.y).
void turning(double *s, double fy, double dt, bool dying) {
	double w = 0.0;
	if (s[WW_HAVE_FY] != 0.0 && !dying) {
		w = clampd(Math::wrapf(fy - s[WW_LAST_FY], -PI_D, PI_D) / dt, -4.0, 4.0);
	}
	s[WW_OMEGA] = lerpd(s[WW_OMEGA], w, ease_rate(10.0, dt));
	s[WW_LAST_FY] = fy;
	s[WW_HAVE_FY] = 1.0;
}

double clip(double t, double dt, double length) {
	if (t < 0.0) {
		return t;
	}
	t += dt;
	return t < length ? t : -1.0;
}

} // namespace

// WireWeaverAvatar.apply_state from a sync (`more`: its HP first).
void ww_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const int64_t hp = int64_t(more[0]);
	const bool fresh = s[FRESH] != 0.0;
	const int was = int(s[WW_STATE]);
	if (fresh) {
		s[WW_RISE] = state == c.st.spawn ? 0.0 : 1.0;
	} else {
		const bool planted = state == c.st.active && was != c.st.active;
		const bool skipped = state == c.st.recover && was == c.st.windup;
		if (planted || skipped) { // (the one-tick plant missed between two syncs still plants)
			s[WW_PLANT] = 0.0;
			s[WW_COIL] = 0.0; // (the plant's own pose takes the tell's hold over)
		}
		const int64_t had = int64_t(s[WW_HP]);
		if (hp >= 0 && had >= 0 && hp < had) {
			s[WW_HURT] = 0.0;
			s[WW_HURT_LEG] = double((int64_t(s[WW_HURT_LEG]) + 1) % LEGS);
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
	s[WW_STATE] = state;
	s[WW_TELL] = windup;
	s[WW_HP] = double(hp);
	if (fresh) {
		s[FRESH] = 0.0;
		ww_pose(s, c);
	}
}

// WireWeaverAvatar.advance (`f`: the facing's yaw, get_parent().rotation.y).
void ww_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[WW_DIE] >= 0.0;
	const int state = int(s[WW_STATE]);
	const bool moving = state == c.st.move && !dying;
	const double fy = double(f.facing_yaw);
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	const double ahead = moving ? double(vel.dot(Vector2(f32(cos_d(fy)), f32(sin_d(fy))))) : 0.0;
	s[WW_SPEED] = lerpd(s[WW_SPEED], ahead, ease_rate(moving ? 9.0 : 14.0, dt));
	turning(s, fy, dt, dying);
	// The stride: each leg's share of the walk and the turn (its side's ground speed), at a steady cadence.
	double most = 0.0;
	for (int k = 0; k < LEGS; k++) {
		most = maxd(most, std::fabs(s[WW_SPEED] + s[WW_OMEGA] * double(f32(s[WW_FOOT_Z + k]))) / MOVE_SPEED);
	}
	s[WW_STRIDE] = toward(s[WW_STRIDE], mind(most, 1.0), dt * 4.0);
	s[WW_PHASE] = Math::fposmod(
			s[WW_PHASE] + STEP_HZ * maxd(1.0, most / STRIDE_MAX) * dt * signd(s[WW_STRIDE]), 1.0);
	const bool winding = state == c.st.windup && !dying;
	s[WW_COIL] = winding ? s[WW_TELL] : toward(s[WW_COIL], 0.0, dt * 10.0);
	const bool spawning = state == c.st.spawn;
	s[WW_RISE] = toward(s[WW_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 2.0));
	s[WW_PLANT] = clip(s[WW_PLANT], dt, RELOAD_FROM + RELOAD_SECONDS);
	s[WW_HURT] = clip(s[WW_HURT], dt, HURT_SECONDS);
	if (dying) {
		s[WW_DIE] += dt;
	}
	ww_pose(s, c);
}

// WireWeaverAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the visor's spec spans nothing: as it is).
int ww_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[WW_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		const double span = VAT_DRIVES[i].hi - lo;
		out[i] = Math::is_zero_approx(span) ? f32(v) : f32((v - lo) / span);
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
