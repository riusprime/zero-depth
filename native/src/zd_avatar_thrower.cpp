// The Stone Thrower's avatar on a batch row (zd_avatar.h S_*): StoneThrowerAvatar's sync (apply_state), frame step
// (advance) and pose (_pose, _pose_rock, grip_points) and StoneThrowerPoses' clips, ported line by line in the same
// order and float width as the GDScript (src/presentation/world_view/stone_thrower_avatar.gd, stone_thrower_poses.gd):
// a pose is the GDScript's {drive: value} dictionary of doubles (the drives it names), the raw drives are floats (its
// PackedFloat32Array), the joints' transforms float ones. tests/unit/native/test_native_crowd.gd holds the rows equal
// to the GDScript avatar's fields bit for bit.

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
// AvatarBase
constexpr double FLINCH_SECONDS = 0.2;
constexpr int MOTION_GAP_TICKS = 30;
// StoneThrowerAvatar
constexpr double ROCK_SCALE = 1.15;
constexpr double DEATH_SECONDS = 1.7;
constexpr double STRIDE_M = 1.15;
constexpr double LEG_SWING = 0.46;
constexpr double FOOT_LIFT = 0.07;
constexpr double WALK_SPEED = 1.8;
constexpr double TELEPORT_SPEED = 30.0;
constexpr double RISE_SECONDS = 0.5;
constexpr double VISOR_REST = 1.8;
constexpr double VISOR_LIFT = 2.6;

// The raw drives (StoneThrowerAvatar's TOPPLE ... YAW0).
enum Drive {
	TOPPLE = 0,
	HX = 1,
	HY = 2,
	HZ = 3,
	TWIST = 4,
	SWAY = 5,
	LEAN = 6,
	BREATH = 7,
	HYAW = 8,
	HNOD = 9,
	SPREAD0 = 10,
	SWING0 = 12,
	ELBOW0 = 14,
	WRIST0 = 16,
	LIFT0 = 18,
	LEG0 = 20,
	RKX = 22,
	RKY = 23,
	RKZ = 24,
	RSPIN = 25,
	RSCALE = 26,
	YAW0 = 27,
	DRIVES = 29,
};

// VAT_DRIVES: [lo, hi, loop].
struct Spec {
	double lo, hi;
	bool loop;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -1.45, 0.02, false }, // TOPPLE
	{ -0.2, 0.25, false }, // HX
	{ -0.45, 0.12, false }, // HY
	{ -0.08, 0.08, false }, // HZ
	{ -0.2, 0.2, false }, // TWIST
	{ -0.15, 0.15, false }, // SWAY
	{ -0.85, 0.55, false }, // LEAN
	{ -2.0, 2.0, false }, // BREATH
	{ -0.45, 0.45, false }, // HYAW
	{ -0.5, 0.75, false }, // HNOD
	{ -0.3, 0.8, false }, // SPREAD r
	{ -0.3, 0.8, false }, // SPREAD l
	{ -0.6, 2.4, false }, // SWING r
	{ -0.6, 2.4, false }, // SWING l
	{ -0.15, 1.3, false }, // ELBOW r
	{ -0.15, 1.3, false }, // ELBOW l
	{ -0.6, 1.2, false }, // WRIST r
	{ -0.6, 1.2, false }, // WRIST l
	{ 0.0, 0.1, false }, // LIFT r
	{ 0.0, 0.1, false }, // LIFT l
	{ -1.25, 0.6, false }, // LEG r
	{ -1.25, 0.6, false }, // LEG l
	{ -1.5, 2.5, false }, // RKX
	{ -0.8, 2.6, false }, // RKY
	{ -0.5, 0.5, false }, // RKZ
	{ 0.0, TAU_D, true }, // RSPIN
	{ 0.0, 1.2, false }, // RSCALE
	{ -0.1, 0.4, false }, // YAW r
	{ -0.1, 0.4, false }, // YAW l
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
inline float f32(double v) {
	return float(v);
}

// A pose: StoneThrowerPoses' {drive: value} (the drives it names, `has`, and their values).
struct Pose {
	double v[DRIVES] = {};
	uint32_t has = 0;

	void set(int k, double x) {
		v[k] = x;
		has |= 1u << k;
	}
	bool named(int k) const {
		return ((has >> k) & 1u) != 0;
	}
	double get(int k, double dflt) const {
		return named(k) ? v[k] : dflt;
	}
};

struct DV {
	int d;
	double v;
};

// A {drive: value} literal.
Pose dict(std::initializer_list<DV> one) {
	Pose p;
	for (const DV &e : one) {
		p.set(e.d, e.v);
	}
	return p;
}

// StoneThrowerPoses.mix: `b` laid over `a` by u (the drives `b` doesn't name stay `a`'s).
Pose mix(const Pose &a, const Pose &b, double u) {
	Pose out = a;
	for (int k = 0; k < DRIVES; k++) {
		if (b.named(k)) {
			out.set(k, lerpd(a.get(k, b.v[k]), b.v[k], u));
		}
	}
	return out;
}

// StoneThrowerPoses.smooth
double smooth01(double u) {
	const double x = clampd(u, 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}

struct Key {
	double t;
	Pose p;
};

// StoneThrowerPoses.track: keyframes at time t, each span eased; before the first and after the last, held.
Pose track(const Key *keys, int n, double t) {
	if (t <= keys[0].t) {
		return keys[0].p;
	}
	for (int k = 1; k < n; k++) {
		const double t1 = keys[k].t;
		if (t <= t1) {
			const double t0 = keys[k - 1].t;
			return mix(keys[k - 1].p, keys[k].p, smooth01((t - t0) / maxd(t1 - t0, 1e-4)));
		}
	}
	return keys[n - 1].p;
}

// StoneThrowerPoses.pose: `one`, both arms' values (right at base, left at base + 1), the legs [right, left] if given.
Pose pose_of(const Pose &one, std::initializer_list<DV> arms, const double *legs = nullptr) {
	Pose p = one;
	for (const DV &e : arms) {
		p.set(e.d, e.v);
		p.set(e.d + 1, e.v);
	}
	if (legs != nullptr) {
		p.set(LEG0, legs[0]);
		p.set(LEG0 + 1, legs[1]);
	}
	return p;
}

Pose pose(std::initializer_list<DV> one, std::initializer_list<DV> arms, const double *legs = nullptr) {
	return pose_of(dict(one), arms, legs);
}

// StoneThrowerPoses.locomotion: the idle and the walk.
Pose locomotion(double t, double walk, double phase, double speed, double puff, bool calm) {
	const double amp = calm ? 0.5 : 1.0;
	const double w = walk;
	const double breath = sin_d(t * TAU_D * 0.42) * (1.0 + 0.8 * puff);
	const double shift = sin_d(t * 0.55) * amp;
	Pose p;
	p.set(HY, (-0.02 + 0.012 * breath) * amp * (1.0 - w));
	p.set(HZ, 0.025 * shift * (1.0 - w));
	p.set(SWAY, 0.035 * shift * (1.0 - w));
	p.set(LEAN, -0.16 + 0.035 * breath * amp);
	p.set(BREATH, breath * amp);
	p.set(HNOD, -0.05 * breath * amp);
	p.set(HYAW, 0.3 * sin_d(t * 0.37) * sin_d(t * 0.23 + 1.0) * amp * (1.0 - w));
	p.set(TWIST, 0.0);
	p.set(HX, 0.0);
	p.set(TOPPLE, 0.0);
	for (int k = 0; k < 2; k++) {
		const double side = k == 0 ? 1.0 : -1.0;
		const double sway = t * TAU_D * 0.31 + side * 0.9;
		p.set(SPREAD0 + k, 0.03 + 0.025 * breath * amp);
		p.set(YAW0 + k, 0.0);
		p.set(SWING0 + k, 0.05 * sin_d(sway) * amp + 0.02 * breath * amp);
		p.set(ELBOW0 + k, 0.06 + 0.06 * sin_d(sway - 1.0) * amp);
		p.set(WRIST0 + k, 0.08 * sin_d(sway - 1.8) * amp);
		p.set(LIFT0 + k, 0.0);
		p.set(LEG0 + k, 0.0);
	}
	if (w <= 0.001) {
		return p;
	}
	const double s = sin_d(phase);
	const double c = cos_d(phase);
	const double bob = cos_d(2.0 * phase) * amp;
	Pose q;
	q.set(HY, (-0.035 + 0.035 * bob) * w);
	q.set(HZ, -0.04 * c * amp * w);
	q.set(SWAY, -0.09 * c * amp * w);
	q.set(TWIST, 0.12 * s * amp * w);
	q.set(LEAN, -0.24 + 0.035 * bob);
	q.set(HNOD, 0.06 - 0.04 * bob);
	q.set(HYAW, -0.08 * s * amp * w);
	q.set(BREATH, breath * amp * 0.6);
	for (int k = 0; k < 2; k++) {
		const double side = k == 0 ? 1.0 : -1.0;
		q.set(LEG0 + k, LEG_SWING * w * s * side);
		q.set(LIFT0 + k, FOOT_LIFT * w * maxd(0.0, c * side * (speed >= 0.0 ? 1.0 : -1.0)));
		const double arm = -0.36 * sin_d(phase - 0.35) * side * w;
		q.set(SWING0 + k, 0.04 + arm);
		q.set(SPREAD0 + k, 0.06 + 0.04 * maxd(0.0, -arm) * amp);
		q.set(ELBOW0 + k, 0.1 + 0.32 * maxd(0.0, arm) + 0.06 * w);
		q.set(WRIST0 + k, -0.25 * sin_d(phase - 1.1) * side * w * amp);
	}
	return mix(p, q, w);
}

// StoneThrowerPoses.attack: the lift, the throw and the recovery at `a` s from the lift's start, over `base`.
Pose attack(double a, const Pose &base, const int *ticks, double t, bool calm) {
	const double lift = ticks[0] / 60.0;
	const double thr = lift + ticks[1] / 60.0;
	const double rec = thr + ticks[2] / 60.0;
	const Pose still = dict({ { HYAW, 0.0 }, { TWIST, 0.0 }, { SWAY, 0.0 }, { HZ, 0.0 }, { LIFT0, 0.0 }, { LIFT0 + 1, 0.0 } });
	const Pose antic = pose({ { HY, 0.04 }, { LEAN, 0.06 }, { HNOD, 0.12 } }, { { SWING0, -0.12 }, { ELBOW0, 0.25 } });
	const double reach_legs[2] = { 0.22, -0.18 };
	const Pose reach = pose_of(mix(still, dict({ { HX, 0.08 }, { HY, -0.12 }, { LEAN, -0.6 }, { HNOD, -0.3 } }), 1.0),
			{ { SWING0, 0.3 }, { SPREAD0, -0.2 }, { YAW0, 0.0 }, { ELBOW0, -0.05 }, { WRIST0, 0.55 } }, reach_legs);
	const Pose dig = mix(reach,
			pose({ { HY, -0.17 }, { LEAN, -0.66 } }, { { SWING0, 0.26 }, { ELBOW0, 0.02 }, { WRIST0, 0.85 } }), 1.0);
	const double heave_legs[2] = { 0.15, -0.15 };
	const Pose heave = pose({ { HX, 0.02 }, { HY, -0.06 }, { LEAN, -0.12 }, { HNOD, 0.05 } },
			{ { SWING0, 1.2 }, { SPREAD0, 0.0 }, { YAW0, 0.27 }, { ELBOW0, 1.0 }, { WRIST0, 0.45 } }, heave_legs);
	const double over_legs[2] = { 0.2, -0.24 };
	const Pose over = pose({ { HX, -0.04 }, { HY, 0.06 }, { LEAN, 0.32 }, { HNOD, 0.32 } },
			{ { SWING0, 2.16 }, { SPREAD0, 0.17 }, { YAW0, 0.0 }, { ELBOW0, 0.35 }, { WRIST0, 0.5 } }, over_legs);
	const Pose hold = mix(over, pose({ { LEAN, 0.25 }, { HY, 0.04 } }, { { SWING0, 2.02 } }), 1.0);
	const Pose strain = mix(hold, pose({ { LEAN, 0.33 }, { HY, 0.0 } }, { { SWING0, 2.12 }, { ELBOW0, 0.42 } }), 1.0);
	const double whip_legs[2] = { 0.38, -0.28 };
	const Pose whip = pose({ { HX, 0.08 }, { HY, -0.06 }, { LEAN, -0.05 }, { HNOD, 0.05 } },
			{ { SWING0, 1.3 }, { SPREAD0, 0.1 }, { YAW0, 0.12 }, { ELBOW0, 0.25 }, { WRIST0, 0.2 } }, whip_legs);
	const double thrown_legs[2] = { 0.46, -0.32 };
	const Pose thrown = pose({ { HX, 0.17 }, { HY, -0.17 }, { LEAN, -0.68 }, { HNOD, -0.22 }, { TWIST, 0.08 } },
			{ { SWING0, -0.32 }, { SPREAD0, 0.08 }, { YAW0, 0.0 }, { ELBOW0, 0.12 }, { WRIST0, -0.3 } }, thrown_legs);
	const Pose past = mix(thrown, pose({ { LEAN, -0.74 } }, { { SWING0, -0.48 }, { WRIST0, -0.45 } }), 1.0);
	const Pose settle = mix(thrown, pose({ { LEAN, -0.6 }, { HY, -0.14 } }, { { SWING0, -0.18 } }), 1.0);
	const double rise_legs[2] = { 0.2, -0.1 };
	const Pose rise = pose({ { HX, 0.08 }, { HY, -0.06 }, { LEAN, -0.3 }, { HNOD, 0.0 }, { TWIST, 0.0 } },
			{ { SWING0, 0.12 }, { SPREAD0, 0.05 }, { ELBOW0, 0.15 }, { WRIST0, 0.0 } }, rise_legs);
	const Key keys[15] = {
		{ 0.0, base },
		{ lift * 0.1, mix(base, antic, 1.0) },
		{ lift * 0.3, mix(base, reach, 1.0) },
		{ lift * 0.4, mix(base, dig, 1.0) },
		{ lift * 0.53, mix(base, heave, 1.0) },
		{ lift * 0.66, mix(base, over, 1.0) },
		{ lift * 0.76, mix(base, hold, 1.0) },
		{ lift, mix(base, strain, 1.0) },
		{ lift + 0.05, mix(base, whip, 1.0) },
		{ lift + 0.11, mix(base, thrown, 1.0) },
		{ lift + 0.2, mix(base, past, 1.0) },
		{ lift + 0.45, mix(base, settle, 1.0) },
		{ thr, mix(base, settle, 1.0) },
		{ thr + (rec - thr) * 0.5, mix(base, rise, 1.0) },
		{ rec, base },
	};
	Pose p = track(keys, 15, a);
	if (a < lift) {
		const double u = a / lift;
		// the dig's grind and the strain's shudder growing to the throw
		const double grind = sstep(0.3, 0.36, u) * (1.0 - sstep(0.4, 0.46, u));
		double st = sstep(0.66, 1.0, u);
		st *= st;
		if (!calm) {
			const double q = sin_d(t * TAU_D * 21.0);
			const double q2 = sin_d(t * TAU_D * 27.0 + 1.3);
			p.set(HY, p.v[HY] + 0.012 * grind * q);
			p.set(LEAN, p.v[LEAN] + 0.02 * grind * q2 + 0.022 * st * q);
			p.set(HZ, p.get(HZ, 0.0) + 0.008 * st * q2);
			for (int k = 0; k < 2; k++) {
				p.set(SWING0 + k, p.v[SWING0 + k] + 0.03 * st * q2);
				p.set(WRIST0 + k, p.v[WRIST0 + k] + 0.12 * grind * q);
			}
		}
		p.set(BREATH, 1.2 * sstep(0.66, 1.0, u) - 0.6 * grind);
	}
	return p;
}

// StoneThrowerPoses.death: `d` s in, from the pose `base` it died in.
Pose death(double d, const Pose &base, bool calm) {
	const double flail = calm ? 0.0 : 1.0;
	const double stagger_legs[2] = { -0.28, 0.12 };
	Pose stagger = pose({ { HX, -0.12 }, { HY, -0.04 }, { LEAN, 0.32 }, { HNOD, 0.35 }, { TWIST, -0.1 }, { BREATH, 0.0 },
								{ TOPPLE, 0.0 } },
			{ { ELBOW0, 0.5 }, { WRIST0, 0.3 }, { YAW0, 0.0 } }, stagger_legs);
	stagger.set(SPREAD0, 0.25 + 0.3 * flail);
	stagger.set(SPREAD0 + 1, 0.2 + 0.25 * flail);
	stagger.set(SWING0, 0.5 + 0.35 * flail);
	stagger.set(SWING0 + 1, 0.3 + 0.2 * flail);
	const double knees_legs[2] = { -1.15, -1.15 };
	const Pose knees = pose({ { HX, 0.04 }, { HY, -0.36 }, { LEAN, -0.3 }, { HNOD, -0.35 }, { TWIST, 0.0 }, { SWAY, 0.05 },
									{ TOPPLE, 0.0 } },
			{ { SPREAD0, 0.12 }, { SWING0, 0.18 }, { ELBOW0, 0.15 }, { WRIST0, 0.2 }, { LIFT0, 0.0 } }, knees_legs);
	const double down_legs[2] = { -0.12, -0.05 };
	const Pose down = mix(knees,
			pose({ { TOPPLE, -1.38 }, { LEAN, -0.25 }, { HNOD, -0.1 } }, { { SWING0, 1.25 }, { SPREAD0, 0.3 }, { ELBOW0, 0.35 } },
					down_legs),
			1.0);
	const Pose bounce = mix(down, dict({ { TOPPLE, -1.27 } }), 1.0);
	const Pose lie = mix(down, dict({ { TOPPLE, -1.36 } }), 1.0);
	const Key keys[3] = {
		{ 0.0, base },
		{ 0.24, mix(base, stagger, 1.0) },
		{ 0.62, mix(base, knees, 1.0) },
	};
	Pose p = track(keys, 3, d);
	if (d > 0.72) {
		const double u = clampd((d - 0.72) / 0.42, 0.0, 1.0);
		p = mix(p, down, u * u);
		if (d > 1.14) {
			const double v = clampd((d - 1.14) / 0.2, 0.0, 1.0);
			p = mix(p, bounce, sin_d(v * PI_D) * (calm ? 0.4 : 1.0));
			p = mix(p, lie, v);
		}
	}
	return p;
}

// The row's float vectors and drives.
inline Vector3 v3(const double *s, int at) {
	return Vector3(f32(s[at]), f32(s[at + 1]), f32(s[at + 2]));
}
inline float vd(const double *s, int d) {
	return f32(s[S_VD + d]);
}
// StoneThrowerAvatar._mirror
inline Vector3 mirror(const Vector3 &v, double side) {
	return Vector3(v.x, v.y, f32(double(v.z) * side));
}
inline Transform3D at_xf(const Vector3 &at) {
	return Transform3D(Basis(), at);
}

// The joints' offsets in the row (S_OFF: pelvis, neck, shoulder, elbow, wrist, hip).
enum Off { OFF_PELVIS = 0, OFF_NECK = 3, OFF_SHOULDER = 6, OFF_ELBOW = 9, OFF_WRIST = 12, OFF_HIP = 15 };

// StoneThrowerAvatar.grip_points: both hands' grip points (right, left) from the raw drives, through _locals' body,
// hips, torso, arm, forearm and hand (the joints it reads; the rest of _locals is not needed here).
void grip_points(const double *s, Vector3 *out) {
	const Vector3 grip(0.1f, -0.2f, -0.06f);
	const Vector3 topple_at(0.42f, 0.0f, 0.0f);
	const Vector3 back(0, 0, 1), up(0, 1, 0), right(1, 0, 0);
	const float sc = f32(s[S_SCALE]);
	const Vector3 tp = topple_at / sc;
	const Transform3D body = Transform3D(Basis::from_scale(Vector3(1, 1, 1) * sc), Vector3()) * at_xf(tp) *
			Transform3D(axis_angle(back, vd(s, TOPPLE)), Vector3()) * at_xf(-tp);
	const Vector3 pelvis = v3(s, S_OFF + OFF_PELVIS);
	const Transform3D hips(axis_angle(up, vd(s, TWIST)) * axis_angle(right, vd(s, SWAY)),
			pelvis + Vector3(vd(s, HX), vd(s, HY), vd(s, HZ)));
	const Transform3D torso(axis_angle(back, vd(s, LEAN)), Vector3());
	const Transform3D torso_xf = body * hips * torso;
	for (int k = 0; k < 2; k++) {
		const double side = k == 0 ? 1.0 : -1.0;
		const Transform3D arm(axis_angle(up, f32(side * double(vd(s, YAW0 + k)))) *
						axis_angle(right, f32(-side * double(vd(s, SPREAD0 + k)))) *
						axis_angle(back, vd(s, SWING0 + k)),
				mirror(v3(s, S_OFF + OFF_SHOULDER), side));
		const Transform3D fore(axis_angle(back, vd(s, ELBOW0 + k)), mirror(v3(s, S_OFF + OFF_ELBOW), side));
		const Transform3D hand(axis_angle(back, vd(s, WRIST0 + k)), mirror(v3(s, S_OFF + OFF_WRIST), side));
		const Transform3D hand_xf = torso_xf * arm * fore * hand;
		out[k] = hand_xf.xform(mirror(grip, side));
	}
}

// AvatarBase.flinch_amount
double flinch_amount(const double *s) {
	return envelope(s[FLINCH_T] / FLINCH_SECONDS) * s[FLINCH_S];
}

// StoneThrowerAvatar._pose_rock: the rock in the hands from the rip to the throw, falling from a dying Thrower's.
void pose_rock(double *s, bool calm) {
	double shown = 0.0;
	Vector3 at(0.6f, -0.5f, 0.0f);
	double spin = 0.0;
	const double die_t = s[S_DIE];
	const double atk = s[S_ATK];
	const int tx = int(s[S_TICKS]);
	if (die_t >= 0.0) {
		if (s[S_DROP] != 0.0) {
			const Vector3 from = v3(s, S_DROP_FROM);
			const double d = die_t;
			const double fall = clampd(d / 0.45, 0.0, 1.0);
			const double floor_y = 0.38 * ROCK_SCALE;
			double y = lerpd(double(from.y), floor_y, fall * fall);
			if (d > 0.45) {
				y = floor_y + 0.12 * std::fabs(sin_d(clampd((d - 0.45) / 0.35, 0.0, 1.0) * PI_D));
			}
			const double roll = clampd((d - 0.45) / 0.9, 0.0, 1.0);
			const double x = double(from.x) + 0.35 * fall + 0.45 * (1.0 - (1.0 - roll) * (1.0 - roll));
			at = Vector3(f32(x), f32(y), from.z);
			spin = -(x - double(from.x)) / (0.38 * ROCK_SCALE);
			shown = 1.0;
		}
	} else if (atk >= 0.0) {
		const double lift = tx / 60.0;
		if (atk < lift) {
			const double u = atk / lift;
			Vector3 grips[2];
			grip_points(s, grips);
			const Vector3 mid = (grips[0] + grips[1]) * 0.5f;
			const double up = sstep(0.3, 0.48, u);
			at = mid + Vector3(0.0f, f32(-0.42 * (1.0 - up)), 0.0f);
			shown = u >= 0.28 ? 1.0 : 0.0;
			spin = 0.25 * (1.0 - up) + (calm ? 0.0 : 0.03 * sin_d(s[T] * TAU_D * 3.0) * sstep(0.7, 1.0, u));
		}
	}
	s[S_ROCK_SHOWN] = shown;
	double size = ROCK_SCALE * (0.82 + 0.18 * sstep(0.3, 0.48, atk * 60.0 / double(tx)));
	if (die_t >= 0.0) {
		size = ROCK_SCALE;
	}
	s[S_VD + RKX] = at.x;
	s[S_VD + RKY] = at.y;
	s[S_VD + RKZ] = at.z;
	s[S_VD + RSPIN] = f32(Math::fposmod(spin, TAU_D));
	s[S_VD + RSCALE] = f32(shown > 0.0 ? size : 0.001);
}

// StoneThrowerAvatar._pose on a VAT avatar (no joint nodes): the drives, the lift, the rock, the visor's glow.
void s_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double t = s[T];
	const double atk = s[S_ATK];
	const double die_t = s[S_DIE];
	const int ticks[3] = { int(s[S_TICKS]), int(s[S_TICKS + 1]), int(s[S_TICKS + 2]) };
	Pose p = locomotion(t, s[S_WALK], s[S_PHASE], s[S_SPEED], s[S_PUFF], calm);
	if (atk >= 0.0) { // (a death freezes it: no sync moves the sim's clock on)
		p = attack(atk, p, ticks, t, calm);
	}
	if (die_t >= 0.0) {
		p = death(die_t, p, calm);
	}
	// The hit flinch: the head snaps back, the arms flare, the chest is knocked back.
	const double f = flinch_amount(s) * (calm ? 0.5 : 1.0);
	if (f != 0.0 && die_t < 0.0) {
		p.set(LEAN, p.get(LEAN, 0.0) + 0.14 * f);
		p.set(HNOD, p.get(HNOD, 0.0) + 0.3 * f);
		p.set(HY, p.get(HY, 0.0) - 0.03 * f);
		for (int k = 0; k < 2; k++) {
			p.set(SPREAD0 + k, p.get(SPREAD0 + k, 0.0) + 0.18 * f);
			p.set(ELBOW0 + k, p.get(ELBOW0 + k, 0.0) + 0.22 * f);
		}
	}
	for (int d = 0; d < DRIVES; d++) {
		s[S_VD + d] = f32(p.get(d, 0.0));
	}
	// The rise-in: up out of the floor; the death's last moment: sinking.
	double sink = 1.0 - s[S_RISE];
	sink = sink * sink * (3.0 - 2.0 * sink);
	s[S_LIFT] = -1.7 * sink;
	if (die_t >= 0.0) {
		s[S_LIFT] = -0.45 * sstep(1.3, DEATH_SECONDS, die_t);
	}
	pose_rock(s, calm);
	double tell = 1.0;
	if (int(s[S_STATE]) == cx.st.windup && atk >= 0.0 && die_t < 0.0) {
		const double u = clampd(atk * 60.0 / double(ticks[0]), 0.0, 1.0);
		tell = (1.0 + VISOR_LIFT * sstep(0.3, 0.7, u) / VISOR_REST) * glow_of_tell(u, t, calm);
	}
	s[S_VISOR] = f32(VISOR_REST * tell);
}

// StoneThrowerAvatar._attack_clock: seconds into the attack the sim is at now, or -1 outside it.
double attack_clock(const double *s, const States &st) {
	const double t = double(int(s[S_STATE_TICKS]));
	const int state = int(s[S_STATE]);
	const int tx = int(s[S_TICKS]);
	const int ty = int(s[S_TICKS + 1]);
	if (state == st.windup) {
		return t / 60.0;
	}
	if (state == st.active) {
		return (tx + t) / 60.0;
	}
	if (state == st.recover) {
		return (double(tx + ty) + t) / 60.0;
	}
	return -1.0;
}

} // namespace

// StoneThrowerAvatar.apply_state from a sync (state_ticks, facing and ticks given: `more`).
void s_apply(double *s, int64_t tick, int state, float pos_x, float pos_y, const double *more, const Ctx &c) {
	const bool fresh = s[FRESH] != 0.0;
	const int64_t last = int64_t(s[LAST_TICK]);
	const int64_t dt_ticks = tick - last;
	if (fresh || state != int(s[S_STATE])) {
		s[S_STATE_TICKS] = 0.0;
	} else if (dt_ticks > 0) {
		s[S_STATE_TICKS] = double(int64_t(s[S_STATE_TICKS]) + dt_ticks);
	}
	s[S_STATE_TICKS] = more[0];
	s[S_TICKS] = more[3];
	s[S_TICKS + 1] = more[4];
	s[S_TICKS + 2] = more[5];
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
	s[S_FWD] = more[1];
	s[S_FWD + 1] = more[2];
	s[S_STATE] = state;
	s[S_ATK_SIM] = attack_clock(s, c.st);
	const double sim = s[S_ATK_SIM];
	if (sim < 0.0) {
		s[S_ATK] = -1.0;
	} else if (s[S_ATK] < 0.0 || std::fabs(s[S_ATK] - sim) > 2.0 / 60.0) {
		s[S_ATK] = sim;
	} else {
		s[S_ATK] = maxd(s[S_ATK], sim); // the frame clock never trails the sim's
	}
	if (fresh) {
		s[FRESH] = 0.0;
		s[S_RISE] = state == c.st.spawn ? 0.0 : 1.0;
		s_pose(s, c);
	}
}

// StoneThrowerAvatar.advance
void s_advance(double *s, double delta, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	if (s[S_DIE] >= 0.0) {
		s[S_DIE] += dt;
	}
	const int state = int(s[S_STATE]);
	const bool spawning = state == c.st.spawn;
	s[S_RISE] = toward(s[S_RISE], spawning ? 0.0 : 1.0, dt / RISE_SECONDS);
	if (s[S_ATK] >= 0.0) {
		s[S_ATK] = mind(s[S_ATK] + dt, s[S_ATK_SIM] + 1.0 / 60.0); // smooth between ticks, never a tick ahead
		if (state == c.st.windup) { // the rock leaves the hands on the sim's throw tick, not before
			s[S_ATK] = mind(s[S_ATK], int(s[S_TICKS]) / 60.0 - 0.001);
		}
	}
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	const Vector2 fwd(f32(s[S_FWD]), f32(s[S_FWD + 1]));
	double signed_speed = double(vel.length());
	if (fwd != Vector2() && double(vel.length()) > 0.05) {
		signed_speed = double(vel.dot(fwd));
	}
	s[S_SPEED] = lerpd(s[S_SPEED], signed_speed, ease_rate(10.0, dt));
	const bool busy = s[S_ATK] >= 0.0 || s[S_DIE] >= 0.0;
	s[S_WALK] = lerpd(s[S_WALK], busy ? 0.0 : clampd(std::fabs(s[S_SPEED]) / WALK_SPEED, 0.0, 1.0), ease_rate(6.0, dt));
	s[S_PHASE] += s[S_SPEED] * dt * TAU_D / STRIDE_M * (busy ? 0.0 : 1.0);
	if (state == c.st.recover) {
		s[S_PUFF] = 1.0;
	} else {
		s[S_PUFF] = toward(s[S_PUFF], 0.0, dt / 2.5);
	}
	s_pose(s, c);
}

// StoneThrowerAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES).
int s_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[S_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		const double span = VAT_DRIVES[i].hi - lo;
		const double u = (v - lo) / span;
		out[i] = f32(VAT_DRIVES[i].loop ? u - std::floor(u) : u);
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
