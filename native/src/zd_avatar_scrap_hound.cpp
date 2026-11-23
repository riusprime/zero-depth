// The Scrap Hound's avatar on a batch row (zd_avatar.h SH_*): ScrapHoundAvatar's sync (apply_state), frame step
// (advance, _steer) and pose (_pose, _gait_legs, _leg_cycle, _flick, the clips' poses, _visor), ported line by line in
// the same order and float width as the GDScript (src/presentation/world_view/scrap_hound_avatar.gd): its clocks,
// speeds, turn, lift and glow are doubles (GDScript floats), the raw drives floats (its PackedFloat32Array: each
// `d[j] += x` reads the float, works in double and stores a float), a leg's cycle a float Vector2, the gallop's swing
// and fold float Vector2 constants and the body's yaw a float Basis on the avatar's own transform (its flinch's rest
// while a flinch runs). tests/unit/native/test_native_crowd_scrap_hound.gd holds the drawn buffers equal to the
// GDScript avatar's bit for bit.

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
constexpr double FLINCH_SECONDS = 0.2;
constexpr int MOTION_GAP_TICKS = 30;
constexpr double TELL_FLASH_FROM = 0.8;
constexpr double TELL_FLICKER_HZ = 9.0;
// ScrapHoundAvatar
constexpr double VISOR_REST = 1.6;
constexpr double VISOR_TELL = 7.0;
constexpr double TELEPORT_SPEED = 30.0;
constexpr double YELP_SECONDS = 0.8;
constexpr double BITE_SECONDS = 0.6;
constexpr double HURT_SECONDS = 0.3;
constexpr double DEATH_SECONDS = 1.0;
constexpr double GALLOP_FROM = 2.6;
constexpr double GALLOP_FULL = 4.4;
constexpr double TROT_HZ = 1.3;
constexpr double TROT_HZ_PER = 0.42;
constexpr double GALLOP_HZ = 2.3;
constexpr double GALLOP_HZ_PER = 0.17;
constexpr double TROT_SWING = 0.38;
constexpr double TROT_FOLD = 0.6;
// GALLOP_SWING and GALLOP_FOLD are Vector2 constants: their components are floats.
const Vector2 GALLOP_SWING(0.62f, 0.55f);
const Vector2 GALLOP_FOLD(1.1f, 0.9f);
constexpr double TROT_DUTY = 0.5;
constexpr double GALLOP_DUTY = 0.36;
const double TROT_DOWN[4] = { 0.0, 0.5, 0.5, 0.0 };
const double GALLOP_DOWN[4] = { 0.42, 0.5, 0.08, 0.0 };
const double REST_U[4] = { 0.0, 0.0, 0.12, -0.12 };
constexpr double LEAN_MAX = 0.24;
constexpr double BANK_K = 0.09;
constexpr double YAW_RATE = 9.0;
constexpr double YAW_RATE_TELL = 16.0;
constexpr double PANT_HZ = 2.4;
constexpr double CALM = 0.45;

// The raw drives (ScrapHoundAvatar's ROLL ... LEG0).
enum Drive {
	ROLL = 0,
	PITCH = 1,
	SHIFT = 2,
	SPINE = 3,
	SPINE_Y = 4,
	HEAD_P = 5,
	HEAD_Y = 6,
	HEAD_R = 7,
	TAIL_P = 8,
	TAIL_Y = 9,
	LEG0 = 10,
	DRIVES = 18,
};

// VAT_DRIVES: [lo, hi] (none loops).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -1.7, 0.5 }, // ROLL
	{ -0.5, 0.5 }, // PITCH
	{ -0.3, 0.3 }, // SHIFT
	{ -0.45, 0.45 }, // SPINE
	{ -0.45, 0.45 }, // SPINE_Y
	{ -0.8, 0.8 }, // HEAD_P
	{ -0.9, 0.9 }, // HEAD_Y
	{ -0.5, 0.5 }, // HEAD_R
	{ -1.0, 0.8 }, // TAIL_P
	{ -0.9, 0.9 }, // TAIL_Y
	{ -1.4, 1.4 }, // leg fr upper
	{ -1.8, 1.0 }, // leg fr lower
	{ -1.4, 1.4 }, // leg fl upper
	{ -1.8, 1.0 }, // leg fl lower
	{ -1.4, 1.4 }, // leg hr upper
	{ -1.8, 1.0 }, // leg hr lower
	{ -1.4, 1.4 }, // leg hl upper
	{ -1.8, 1.0 }, // leg hl lower
};

// GDScript's utility functions on doubles (zd_avatar.cpp's reason for the engine's sin, cos and exp).
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
inline double wrap_pi(double v) {
	return Math::wrapf(v, -PI_D, PI_D);
}
inline float f32(double v) {
	return float(v);
}
inline double dsin(double x) {
	return sin_d(x);
}
inline double dcos(double x) {
	return cos_d(x);
}

// `d[j] += x`, `d[j] -= x`, `d[j] *= x` and `d[j] = x` on the PackedFloat32Array.
inline void add(float *d, int j, double x) {
	d[j] = f32(double(d[j]) + x);
}
inline void sub(float *d, int j, double x) {
	d[j] = f32(double(d[j]) - x);
}
inline void mul(float *d, int j, double x) {
	d[j] = f32(double(d[j]) * x);
}
inline void put(float *d, int j, double x) {
	d[j] = f32(x);
}
inline double get(const float *d, int j) {
	return double(d[j]);
}

bool flinching(const double *s) {
	return s[FLINCH_T] < FLINCH_SECONDS;
}

bool tell_flashing(double p) {
	return p >= TELL_FLASH_FROM && p <= 1.0;
}

// ScrapHoundAvatar.stride_hz
double stride_hz(const double *s) {
	const double speed = s[SH_SPEED];
	return lerpd(TROT_HZ + TROT_HZ_PER * speed, GALLOP_HZ + GALLOP_HZ_PER * speed, s[SH_GALLOP]);
}

// ScrapHoundAvatar._leg_cycle
Vector2 leg_cycle(double q, double duty, bool hind) {
	if (q < duty) {
		const double sv = q / duty;
		const double fold = -0.12 * dsin(PI_D * sv) + (hind ? 0.25 * sstep(0.65, 1.0, sv) : 0.0);
		return Vector2(f32(1.0 - 2.0 * sv), f32(fold));
	}
	const double w = (q - duty) / (1.0 - duty);
	double tuck = -dsin(PI_D * mind(w / 0.85, 1.0));
	if (!hind) {
		tuck += 0.25 * sstep(0.7, 1.0, w);
	}
	return Vector2(f32(-1.0 + 2.0 * sstep(0.0, 1.0, w)), f32(tuck));
}

// ScrapHoundAvatar._gait_legs: writes the legs' eight drives into d (upper then lower, LEGS order).
void gait_legs(const double *s, double amp, float *d) {
	const double phase = s[SH_PHASE];
	const double gallop = s[SH_GALLOP];
	for (int k = 0; k < 4; k++) {
		const bool hind = k >= 2;
		const Vector2 t = leg_cycle(Math::fposmod(phase - TROT_DOWN[k], 1.0), TROT_DUTY, hind);
		const Vector2 g = leg_cycle(Math::fposmod(phase - GALLOP_DOWN[k], 1.0), GALLOP_DUTY, hind);
		const double sw = double(hind ? GALLOP_SWING.y : GALLOP_SWING.x);
		const double fo = double(hind ? GALLOP_FOLD.y : GALLOP_FOLD.x);
		put(d, LEG0 + 2 * k, REST_U[k] + amp * lerpd(double(t.x) * TROT_SWING, double(g.x) * sw, gallop));
		put(d, LEG0 + 2 * k + 1, amp * lerpd(double(t.y) * TROT_FOLD, double(g.y) * fo, gallop));
	}
}

// ScrapHoundAvatar._flick
double flick(double t) {
	const double u = t / 2.9;
	const double seg = std::floor(u);
	if (rig::hash01(seg + 31.0) < 0.5) {
		return 0.0;
	}
	return dsin(PI_D * clampd((u - seg - 0.3) / 0.12, 0.0, 1.0));
}

// ScrapHoundAvatar._tell_pose: returns its lift.
double tell_pose(const double *s, float *d, double k, bool calm, const Ctx &cx) {
	const double c = s[SH_COIL];
	if (c <= 0.0) {
		return 0.0;
	}
	const double t = s[T];
	add(d, PITCH, 0.14 * c * k);
	sub(d, SHIFT, 0.07 * c);
	add(d, SPINE, 0.08 * c * k);
	for (int j = 0; j < 2; j++) {
		add(d, LEG0 + 2 * j, 0.3 * c);
		sub(d, LEG0 + 2 * j + 1, 0.15 * c);
		add(d, LEG0 + 4 + 2 * j, 0.45 * c);
		sub(d, LEG0 + 4 + 2 * j + 1, 0.75 * c);
	}
	sub(d, HEAD_P, 0.16 * c);
	mul(d, HEAD_R, 1.0 - c);
	put(d, TAIL_P, lerpd(get(d, TAIL_P), -0.12, c));
	mul(d, TAIL_Y, 1.0 - c);
	if (!calm && int(s[SH_STATE]) == cx.st.windup) {
		add(d, TAIL_Y, 0.06 * c * dsin(TAU_D * 16.0 * t));
		if (tell_flashing(s[SH_TELL])) {
			add(d, ROLL, 0.02 * dsin(TAU_D * 20.0 * t));
		}
	}
	return -0.075 * c * k;
}

// ScrapHoundAvatar._dart_pose: returns its lift.
double dart_pose(const double *s, float *d) {
	const double w = sstep(0.0, 1.0, s[SH_DART]) * 0.85;
	if (w <= 0.0) {
		return 0.0;
	}
	// The leap's dictionary, in its order.
	const int leap_j[8] = { PITCH, SHIFT, SPINE, HEAD_P, HEAD_Y, HEAD_R, TAIL_P, TAIL_Y };
	const double leap_v[8] = { -0.08, 0.06, -0.3, -0.12, 0.0, 0.0, 0.05, 0.0 };
	for (int q = 0; q < 8; q++) {
		put(d, leap_j[q], lerpd(get(d, leap_j[q]), leap_v[q], w));
	}
	for (int j = 0; j < 2; j++) {
		put(d, LEG0 + 2 * j, lerpd(get(d, LEG0 + 2 * j), 0.95, w));
		put(d, LEG0 + 2 * j + 1, lerpd(get(d, LEG0 + 2 * j + 1), 0.35, w));
		put(d, LEG0 + 4 + 2 * j, lerpd(get(d, LEG0 + 4 + 2 * j), -0.85, w));
		put(d, LEG0 + 4 + 2 * j + 1, lerpd(get(d, LEG0 + 4 + 2 * j + 1), 0.25, w));
	}
	return -0.02 * w;
}

// ScrapHoundAvatar._bite_envelope
double bite_envelope(const double *s) {
	const double b = s[SH_BITE];
	return b >= 0.0 ? 1.0 - sstep(0.0, 1.0, b / BITE_SECONDS) : 0.0;
}

// ScrapHoundAvatar._bite_pose: returns its lift.
double bite_pose(const double *s, float *d, double k, bool calm) {
	const double bite_t = s[SH_BITE];
	if (bite_t < 0.0) {
		return 0.0;
	}
	const double b = bite_t / BITE_SECONDS;
	const double snap = sstep(0.0, 0.1, b) * (1.0 - sstep(0.1, 0.45, b));
	const double brace = 1.0 - sstep(0.15, 0.8, b);
	add(d, HEAD_P, -0.3 * snap + 0.1 * dsin(PI_D * clampd((b - 0.25) / 0.4, 0.0, 1.0)));
	if (!calm) {
		add(d, HEAD_R, 0.28 * dsin(TAU_D * 11.0 * bite_t) * sstep(0.08, 0.2, b) * (1.0 - b));
	}
	add(d, SHIFT, 0.08 * snap);
	add(d, PITCH, (-0.09 * snap + 0.04 * brace) * k);
	const double dart = s[SH_DART];
	for (int j = 0; j < 2; j++) {
		add(d, LEG0 + 2 * j, 0.75 * brace * (1.0 - dart));
		add(d, LEG0 + 2 * j + 1, 0.3 * brace);
		add(d, LEG0 + 4 + 2 * j, 0.2 * brace);
	}
	return -0.03 * brace * k;
}

// ScrapHoundAvatar._yelp_pose: returns its lift.
double yelp_pose(const double *s, float *d, double k, bool calm) {
	const double yelp_t = s[SH_YELP];
	if (yelp_t < 0.0) {
		return 0.0;
	}
	const double y = yelp_t / YELP_SECONDS;
	const double jerk = sstep(0.0, 0.06, y) * (1.0 - sstep(0.08, 0.35, y));
	const double skid = sstep(0.0, 0.08, y) * (1.0 - sstep(0.15, 0.4, y));
	const double hop = dsin(PI_D * clampd((y - 0.12) / 0.33, 0.0, 1.0));
	const double back = sstep(0.08, 0.45, y) * (1.0 - sstep(0.6, 1.0, y));
	const double tuck = sstep(0.0, 0.12, y) * (1.0 - sstep(0.75, 1.0, y));
	const double cower = sstep(0.4, 0.55, y) * (1.0 - sstep(0.8, 1.0, y));
	add(d, HEAD_P, (0.45 * jerk - 0.2 * cower) * k);
	add(d, HEAD_R, 0.25 * jerk * k);
	add(d, HEAD_Y, 0.3 * cower * k);
	add(d, PITCH, 0.14 * jerk * k);
	sub(d, SHIFT, 0.16 * back * k);
	add(d, SPINE, 0.12 * cower * k);
	put(d, TAIL_P, lerpd(get(d, TAIL_P), -0.85, tuck));
	mul(d, TAIL_Y, 1.0 - tuck);
	for (int j = 0; j < 2; j++) {
		add(d, LEG0 + 2 * j, 0.35 * skid);
		sub(d, LEG0 + 2 * j + 1, 0.6 * hop * k);
		sub(d, LEG0 + 4 + 2 * j + 1, (0.6 * hop + 0.3 * cower) * k);
	}
	if (!calm) {
		add(d, ROLL, 0.04 * dsin(TAU_D * 14.0 * yelp_t) * jerk);
	}
	return (0.02 * jerk + 0.07 * hop - 0.05 * cower) * k;
}

// ScrapHoundAvatar._hurt_pose: returns its lift.
double hurt_pose(const double *s, float *d, double k) {
	const double hurt_t = s[SH_HURT];
	if (hurt_t < 0.0) {
		return 0.0;
	}
	const double h = hurt_t / HURT_SECONDS;
	const double e = dsin(PI_D * mind(h / 0.3, 1.0)) * (1.0 - sstep(0.3, 1.0, h)) * k;
	add(d, HEAD_P, 0.35 * e);
	add(d, HEAD_R, 0.15 * e);
	sub(d, TAIL_P, 0.4 * e);
	return -0.02 * e;
}

// ScrapHoundAvatar._rise_pose: returns its lift.
double rise_pose(const double *s, float *d) {
	const double r = 1.0 - s[SH_RISE];
	if (r <= 0.0) {
		return 0.0;
	}
	for (int j = 0; j < 4; j++) {
		add(d, LEG0 + 2 * j, 0.3 * r);
		sub(d, LEG0 + 2 * j + 1, 0.7 * r);
	}
	sub(d, HEAD_P, 0.25 * r);
	return -0.12 * r;
}

// ScrapHoundAvatar._death_pose: returns the lift.
double death_pose(const double *s, float *d, double lift, bool calm) {
	const double die_t = s[SH_DIE];
	if (die_t < 0.0) {
		return lift;
	}
	const double u = die_t / (DEATH_SECONDS * 0.9);
	const double stumble = sstep(0.0, 0.3, u);
	const double roll = sstep(0.25, 0.7, u);
	const double fold = sstep(0.45, 0.95, u);
	const double still = 1.0 - stumble;
	const int limp[7] = { ROLL, SHIFT, SPINE, SPINE_Y, HEAD_Y, HEAD_R, TAIL_Y };
	for (int q = 0; q < 7; q++) {
		mul(d, limp[q], still);
	}
	lift *= still;
	put(d, PITCH, lerpd(get(d, PITCH) * still - 0.22 * stumble, 0.0, roll));
	for (int j = 0; j < 2; j++) {
		put(d, LEG0 + 2 * j, lerpd(get(d, LEG0 + 2 * j), -0.2, stumble) + 0.75 * fold);
		put(d, LEG0 + 2 * j + 1, lerpd(get(d, LEG0 + 2 * j + 1), -0.9, stumble) - 0.8 * fold);
		put(d, LEG0 + 4 + 2 * j, lerpd(get(d, LEG0 + 4 + 2 * j), 0.1, stumble) + 0.7 * fold);
		put(d, LEG0 + 4 + 2 * j + 1, lerpd(get(d, LEG0 + 4 + 2 * j + 1), -0.3, stumble) - 1.2 * fold);
	}
	if (!calm) {
		const double twitch = dsin(PI_D * clampd((u - 0.72) / 0.25, 0.0, 1.0));
		add(d, LEG0 + 5, 0.3 * dsin(TAU_D * 7.0 * die_t) * twitch);
		add(d, LEG0 + 7, 0.3 * dsin(TAU_D * 7.0 * die_t + 1.3) * twitch);
	}
	put(d, ROLL, lerpd(get(d, ROLL), -1.3, roll));
	put(d, HEAD_P, lerpd(get(d, HEAD_P), -0.18, stumble) + 0.12 * roll);
	sub(d, HEAD_R, 0.25 * roll);
	put(d, TAIL_P, lerpd(get(d, TAIL_P), -0.3, stumble));
	add(d, TAIL_Y, 0.15 * roll);
	return lift - 0.1 * stumble * (1.0 - roll) + 0.13 * roll;
}

// ScrapHoundAvatar._visor
double visor(const double *s, bool calm, const Ctx &cx) {
	double e = VISOR_REST;
	const double tell = s[SH_TELL];
	if (int(s[SH_STATE]) == cx.st.windup) {
		e = VISOR_REST + (VISOR_TELL - VISOR_REST) * crouch_of_tell(tell);
		if (tell_flashing(tell)) {
			e = calm || int64_t(s[T] * TELL_FLICKER_HZ * 2.0) % 2 == 0 ? VISOR_TELL * 1.2 : VISOR_TELL * 0.8;
		}
	}
	e = maxd(e, VISOR_REST + (VISOR_TELL * 0.8 - VISOR_REST) * s[SH_DART]);
	if (s[SH_DIE] >= 0.0) {
		e *= 1.0 - sstep(0.3, 1.0, s[SH_DIE] / DEATH_SECONDS) * 0.95;
	}
	return e;
}

// ScrapHoundAvatar._pose on a VAT avatar (no nodes): the drives, the lift and the visor's glow.
void sh_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double k = calm ? CALM : 1.0;
	float d[DRIVES] = {};
	double lift = 0.0;
	const double speed = s[SH_SPEED];
	const double amp = clampd(speed / 2.2, 0.0, 1.0);
	// The legs' gait (the full swing even with reduced motion) and the body's rock and bound with it.
	gait_legs(s, amp, d);
	const double p = s[SH_PHASE];
	const double g = s[SH_GALLOP];
	const double c1 = dcos(TAU_D * (p - 0.93));
	const double c2 = dcos(TAU_D * (p - 0.2));
	lift += amp * k *
			lerpd(0.012 * dcos(2.0 * TAU_D * p), 0.035 * (0.5 + 0.5 * dcos(TAU_D * (p - 0.92))) - 0.02, g);
	add(d, ROLL, amp * k * lerpd(0.025 * dsin(TAU_D * p), 0.0, g));
	add(d, PITCH, amp * k * lerpd(0.0, 0.08 * c2, g));
	add(d, SPINE, amp * k * lerpd(0.02 * dsin(2.0 * TAU_D * p), 0.15 * c1, g));
	add(d, HEAD_P, amp * k * lerpd(-0.03 * dcos(2.0 * TAU_D * p), -0.1 * c2 - 0.12, g));
	add(d, TAIL_P, amp * k * lerpd(0.06 * dsin(TAU_D * (p - 0.2)), 0.15 * dcos(TAU_D * (p - 0.35)) + 0.08, g));
	add(d, TAIL_Y, amp * k * lerpd(0.12 * dsin(TAU_D * p), 0.05 * dsin(TAU_D * p), g));
	// The turn: banked into the curve, the hips swung out, the head into the turn and on the hero.
	const double bank = s[SH_BANK];
	const double yaw = s[SH_YAW];
	const double coil = s[SH_COIL];
	add(d, ROLL, -bank * LEAN_MAX * k);
	add(d, SPINE_Y, bank * 0.22 * k);
	add(d, TAIL_Y, -bank * 0.3 * k);
	add(d, HEAD_Y, clampd(-yaw * 0.4, -0.5, 0.5) * (1.0 - coil) + bank * 0.15 * k);
	// Idle: panting, the scanning glances, the tail's wag and flick, the weight shifting (fading as it runs).
	const double t = s[T];
	const double idle = 1.0 - sstep(0.2, 1.6, speed);
	const double pant = dsin(TAU_D * PANT_HZ * t) * (1.0 + 1.5 * bite_envelope(s));
	lift += idle * k * 0.004 * pant;
	add(d, HEAD_P, idle * k * (0.035 * pant - 0.04));
	add(d, SPINE, idle * k * 0.012 * pant);
	const double look = rig::scan(t, 1.7, 0.0) * idle * (1.0 - coil) * k;
	add(d, HEAD_Y, 0.35 * look * (1.0 - std::fabs(yaw) / PI_D));
	add(d, HEAD_R, idle * k * 0.14 * rig::scan(t, 2.3, 7.0));
	add(d, TAIL_Y, idle * k * 0.14 * dsin(TAU_D * 1.1 * t));
	add(d, TAIL_P, idle * k * (0.06 + 0.25 * flick(t)));
	add(d, ROLL, idle * k * 0.015 * dsin(0.8 * t));
	add(d, SHIFT, idle * k * 0.01 * dsin(0.8 * t + 1.0));
	lift += tell_pose(s, d, k, calm, cx);
	lift += dart_pose(s, d);
	lift += bite_pose(s, d, k, calm);
	lift += yelp_pose(s, d, k, calm);
	lift += hurt_pose(s, d, k);
	lift += rise_pose(s, d);
	lift = death_pose(s, d, lift, calm);
	for (int j = 0; j < DRIVES; j++) {
		put(d, j, clampd(get(d, j), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	for (int j = 0; j < DRIVES; j++) {
		s[SH_VD + j] = d[j];
	}
	s[SH_LIFT] = lift;
	s[SH_GLOW] = visor(s, calm, cx);
}

// ScrapHoundAvatar._steer (`fy`: the facing's turn, get_parent().rotation.y).
void steer(double *s, double dt, bool dying, double fy, const Ctx &cx) {
	double want = 0.0;
	const int state = int(s[SH_STATE]);
	const bool running = s[SH_SPEED] > 1.0 && state == cx.st.move && !dying;
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	if (running && double(vel.length()) > 0.5) {
		const double h = atan2_d(double(vel.y), double(vel.x));
		want = wrap_pi(h - fy);
		if (s[SH_HAVE_H] != 0.0) {
			s[SH_TURN] = lerpd(s[SH_TURN], wrap_pi(h - s[SH_LAST_H]) / dt, ease_rate(6.0, dt));
		}
		s[SH_LAST_H] = h;
		s[SH_HAVE_H] = 1.0;
	} else {
		s[SH_HAVE_H] = 0.0;
		s[SH_TURN] = lerpd(s[SH_TURN], 0.0, ease_rate(6.0, dt));
	}
	if (!dying) {
		const double r = state == cx.st.windup ? YAW_RATE_TELL : YAW_RATE;
		s[SH_YAW] = wrap_pi(s[SH_YAW] + wrap_pi(want - s[SH_YAW]) * ease_rate(r, dt));
	}
	s[SH_BANK] = running ? clampd(s[SH_TURN] * s[SH_SPEED] * BANK_K, -1.0, 1.0)
						 : s[SH_BANK] * (1.0 - ease_rate(6.0, dt));
	const Basis b = axis_angle(Vector3(0, 1, 0), f32(s[SH_YAW]));
	const int at = flinching(s) ? REST_XF : XF;
	Transform3D xf = get_xf(s, at);
	xf.basis = b;
	put_xf(s, at, xf);
}

} // namespace

// ScrapHoundAvatar.apply_state from a sync (`more`: its HP, whether a hit stopped it).
void sh_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const bool yelped = more[1] != 0.0;
	const int hp = int(more[0]);
	const bool fresh = s[FRESH] != 0.0;
	const int was = int(s[SH_STATE]);
	const int had = int(s[SH_HP]);
	if (fresh) {
		s[SH_RISE] = state == c.st.spawn ? 0.0 : 1.0;
	} else if (state == c.st.recover && was != c.st.recover) {
		if (yelped) {
			s[SH_YELP] = 0.0;
			s[SH_HURT] = -1.0;
		} else if (was == c.st.active) {
			s[SH_BITE] = 0.0;
		}
	} else if (hp >= 0 && had >= 0 && hp < had && s[SH_YELP] < 0.0) {
		s[SH_HURT] = 0.0;
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
	s[SH_STATE] = state;
	s[SH_TELL] = windup;
	s[SH_HP] = hp;
	if (fresh) {
		s[FRESH] = 0.0;
		sh_pose(s, c);
	}
}

// ScrapHoundAvatar.advance (`f`: the facing's yaw, for _steer).
void sh_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[SH_DIE] >= 0.0;
	const int state = int(s[SH_STATE]);
	const bool moving = (state == c.st.move || state == c.st.active) && !dying;
	const double target = moving ? double(Vector2(f32(s[VEL_X]), f32(s[VEL_Y])).length()) : 0.0;
	s[SH_SPEED] = lerpd(s[SH_SPEED], target, ease_rate(moving ? 10.0 : 22.0, dt));
	s[SH_GALLOP] = toward(s[SH_GALLOP], sstep(GALLOP_FROM, GALLOP_FULL, s[SH_SPEED]), dt * 3.0);
	s[SH_PHASE] = Math::fposmod(s[SH_PHASE] + stride_hz(s) * dt, 1.0);
	steer(s, dt, dying, double(f.facing_yaw), c);
	const bool winding = state == c.st.windup;
	s[SH_COIL] = winding ? crouch_of_tell(s[SH_TELL]) : toward(s[SH_COIL], 0.0, dt * 7.0);
	const bool active = state == c.st.active && !dying;
	s[SH_DART] = toward(s[SH_DART], active ? 1.0 : 0.0, dt * (active ? 16.0 : 5.0));
	const bool spawning = state == c.st.spawn;
	s[SH_RISE] = toward(s[SH_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 2.5));
	s[SH_BITE] = rig::clip(s[SH_BITE], dt, BITE_SECONDS);
	s[SH_YELP] = rig::clip(s[SH_YELP], dt, YELP_SECONDS);
	s[SH_HURT] = rig::clip(s[SH_HURT], dt, HURT_SECONDS);
	if (dying) {
		s[SH_DIE] += dt;
	}
	sh_pose(s, c);
}

// ScrapHoundAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (no drive loops or is flat).
int sh_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[SH_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		out[i] = f32((v - lo) / (VAT_DRIVES[i].hi - lo));
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
