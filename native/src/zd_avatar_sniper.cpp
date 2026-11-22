// The Sniper's avatar on a batch row (zd_avatar.h SN_*): SniperAvatar's sync (apply_state), frame step (advance) and
// pose (_pose and its clips, _body_xf, _lens, _muzzle), ported line by line in the same order and float width as the
// GDScript (src/presentation/world_view/sniper_avatar.gd): its numbers are doubles, its raw drives floats (its
// PackedFloat32Array, each += rounded back to a float), its feet, places and transforms float ones; the legs reach
// through LeggedRig's port (zd_legged_rig.cpp). tests/unit/native/test_native_crowd.gd holds the rows equal to the
// GDScript avatar's fields bit for bit.

#include "zd_avatar.h"
#include "zd_legged_rig.h"

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
constexpr double TELL_FLASH_FROM = 0.8;
constexpr double TELL_FLICKER_HZ = 9.0;
constexpr int MOTION_GAP_TICKS = 30;
// SniperAvatar
constexpr double LENS_REST = 1.8;
constexpr double LENS_SHOT = 7.0;
constexpr double MUZZLE_CHARGE = 4.0;
constexpr double MUZZLE_FLARE = 8.0;
constexpr double TELEPORT_SPEED = 20.0;
constexpr double SHOT_SECONDS = 0.52;
constexpr double VENT_SECONDS = 0.7;
constexpr double HURT_SECONDS = 0.35;
constexpr double DEATH_SECONDS = 1.1;
constexpr double SETTLE_SECONDS = 0.45;
constexpr double SECOND_KICK = 0.15;
constexpr double MOVE_SPEED = 2.6;
constexpr double DUTY = 0.7;
constexpr double SWEEP = 0.17;
constexpr double LIFT = 0.1;
constexpr double STRIDE_MAX = 1.4;
constexpr double STEP_HZ = MOVE_SPEED * DUTY / (2.0 * SWEEP);
constexpr double GATHER = 0.09;
constexpr double CROUCH = 0.06;
constexpr double TURN_REF = 3.0;
constexpr double TURN_SWING = 0.2;
constexpr int LEGS = 3;
constexpr double STRIDE_AT[LEGS] = { 0.0, 0.333, 0.667 };
constexpr double BRACE_DROP = 0.08;
constexpr double BRACE_WIDE = 0.04;
constexpr double SEARCH = 0.14;
constexpr double BREATH_HZ = 0.45;
constexpr double CALM = 0.45;

// The raw drives (SniperAvatar's SURGE ... MUZZLE).
enum Drive {
	SURGE = 0,
	ROLL = 1,
	PITCH = 2,
	SWAY = 3,
	SHELL_UP = 4,
	SHELL_P = 5,
	BARREL = 6,
	LEG0 = 7,
	MUZZLE = 16,
	DRIVES = 17,
};

// VAT_DRIVES: [lo, hi] (none loops; the muzzle's spans nothing: sent as it is).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.12, 0.08 }, // SURGE
	{ -0.3, 0.3 }, // ROLL
	{ -0.4, 0.4 }, // PITCH
	{ -0.5, 0.5 }, // SWAY
	{ -0.04, 0.08 }, // SHELL_UP
	{ -0.25, 0.25 }, // SHELL_P
	{ -0.2, 0.06 }, // BARREL
	{ -0.8, 0.8 }, { -1.3, 1.3 }, { -1.8, 1.8 }, // leg f
	{ -0.8, 0.8 }, { -1.3, 1.3 }, { -1.8, 1.8 }, // leg r
	{ -0.8, 0.8 }, { -1.3, 1.3 }, { -1.8, 1.8 }, // leg l
	{ 0.0, 0.0 }, // MUZZLE
};

const Vector3 UP(0, 1, 0);
const Vector3 RIGHT(1, 0, 0);
const Vector3 BACK(0, 0, 1);
const Vector3 HUB(0.0f, 0.66f, 0.0f);

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
inline Vector3 v3(const double *s, int at) {
	return Vector3(f32(s[at]), f32(s[at + 1]), f32(s[at + 2]));
}
inline Transform3D at_xf(const Vector3 &at) {
	return Transform3D(Basis(), at);
}

// d[j] += x on a PackedFloat32Array: the float read as a double, the sum stored back as a float.
inline void add(float *d, int j, double x) {
	d[j] = f32(double(d[j]) + x);
}

// AvatarBase.tell_flashing
bool tell_flashing(double p) {
	return p >= TELL_FLASH_FROM && p <= 1.0;
}

// A foot's rest tip flattened onto the ground and made a unit (Vector3(tip.x, 0.0, tip.z).normalized()).
inline Vector3 flat_unit(const Vector3 &tip) {
	return Vector3(tip.x, 0.0f, tip.z).normalized();
}

// The pose's working numbers: the row, the drives, the feet's offsets the clips ask for (_foot).
struct Pose {
	double *s;
	float d[DRIVES];
	Vector3 foot[LEGS];
	Vector3 feet[LEGS];

	double alive() const {
		const double die_t = s[SN_DIE];
		return die_t < 0.0 ? 1.0 : 1.0 - sstep(0.0, 0.2, clampd(die_t / DEATH_SECONDS, 0.0, 1.0));
	}

	// SniperAvatar._walk_pose
	double walk_pose(double k) {
		const double g = clampd(s[SN_STRIDE], 0.0, 1.0);
		const double walk = clampd(s[SN_SPEED] / MOVE_SPEED, 0.0, STRIDE_MAX);
		const double turn = clampd(s[SN_OMEGA] / TURN_REF, -1.0, 1.0);
		const Vector3 dir(f32(s[SN_DIR]), 0.0f, f32(s[SN_DIR + 1]));
		Vector2 lean;
		for (int j = 0; j < LEGS; j++) {
			const Vector2 c = rig::leg_cycle(Math::fposmod(s[SN_PHASE] - STRIDE_AT[j], 1.0), DUTY);
			const Vector3 tip = feet[j];
			const double th = turn * TURN_SWING * double(c.x);
			const Vector3 inward = (-flat_unit(tip)) * f32(GATHER) * f32(g);
			foot[j] += dir * f32(walk * SWEEP * double(c.x)) + inward +
					Vector3(f32(th * double(tip.z)), f32(LIFT * g * double(c.y)), f32(-th * double(tip.x)));
			lean += Vector2(tip.x, tip.z).normalized() * c.y; // toward the leg in the air
		}
		if (g <= 0.0) {
			return 0.0;
		}
		const double p = s[SN_PHASE];
		const double w = mind(walk, 1.0);
		add(d, PITCH, g * k * 0.03 * double(lean.x) - w * 0.03);
		add(d, ROLL, -(g * k * 0.04 * double(lean.y)));
		add(d, SWAY, w * k * 0.04 * sin_d(TAU_D * (p + 0.1)));
		add(d, SHELL_UP, g * k * 0.008 * sin_d(3.0 * TAU_D * (p - 0.15)));
		add(d, SHELL_P, g * k * 0.03 * sin_d(3.0 * TAU_D * (p - 0.2)));
		return -CROUCH * g - g * k * 0.018 * cos_d(3.0 * TAU_D * (p - 0.08));
	}

	// SniperAvatar._idle_pose
	double idle_pose(double k, bool calm, double breath) {
		const double t = s[T];
		const double idle = (1.0 - clampd(s[SN_STRIDE], 0.0, 1.0)) * (1.0 - s[SN_BRACE]) * alive();
		if (idle <= 0.0) {
			return 0.0;
		}
		add(d, SWAY, idle * k * 0.4 * rig::scan(t, 2.8, 0.0));
		add(d, PITCH, idle * k * 0.06 * rig::scan(t, 3.6, 4.0));
		add(d, ROLL, idle * k * 0.02 * sin_d(0.6 * t + 0.5));
		add(d, SHELL_UP, idle * k * 0.006 * (breath + 1.0));
		add(d, SHELL_P, -(idle * k * 0.02 * breath));
		if (!calm) {
			add(d, SWAY, idle * 0.07 * rig::twitch(t, 4.3, 9.0));
			add(d, PITCH, idle * 0.04 * rig::twitch(t, 3.9, 21.0));
		}
		int leg = -1;
		const double up = rig::replant(t, 3.1, LEGS, leg);
		if (leg >= 0) {
			foot[leg] += Vector3(0.03f, 0.07f, 0.0f) * f32(up) * f32(idle);
		}
		return idle * k * 0.008 * breath;
	}

	// SniperAvatar._aim_pose
	double aim_pose(double k, bool calm, const Ctx &cx) {
		const double b = sstep(0.0, 1.0, s[SN_BRACE]);
		if (b <= 0.0) {
			return 0.0;
		}
		for (int j = 0; j < LEGS; j++) {
			foot[j] += flat_unit(feet[j]) * f32(BRACE_WIDE) * f32(b);
		}
		const double t = s[T];
		const bool aiming = int(s[SN_STATE]) == cx.st.windup;
		const double p = aiming ? s[SN_TELL] : 1.0;
		const double search = (1.0 - sstep(0.25, 0.6, p)) * b;
		add(d, SWAY, search * k * SEARCH * sin_d(TAU_D * 0.9 * t));
		add(d, PITCH, search * k * 0.03 * sin_d(TAU_D * 0.6 * t + 1.0));
		add(d, PITCH, -(0.035 * sstep(0.3, 0.7, p) * b));
		add(d, SHELL_UP, -(0.01 * b));
		add(d, SHELL_P, -(0.05 * b * k));
		add(d, BARREL, 0.03 * b);
		double lift = -BRACE_DROP * b * lerpd(0.7, 1.0, k);
		const double settle_t = s[SN_SETTLE_T];
		if (settle_t >= 0.0) { // the tripod settles: a small bounce as the weight comes onto it
			const double u = settle_t / SETTLE_SECONDS;
			lift -= 0.02 * k * sin_d(PI_D * 3.0 * u) * (1.0 - u);
		}
		if (!calm && aiming) {
			const double top = sstep(0.8, 0.92, p);
			add(d, PITCH, 0.004 * top * sin_d(TAU_D * 13.0 * t));
		}
		return lift;
	}

	// SniperAvatar.kick
	static double kick(double t) {
		if (t < 0.0) {
			return 0.0;
		}
		return sstep(0.0, 0.025, t) * (1.0 - sstep(0.03, 0.12, t));
	}

	// SniperAvatar._shot_pose
	double shot_pose(double k, bool calm) {
		const double shot_t = s[SN_SHOT_T];
		if (shot_t < 0.0) {
			return 0.0;
		}
		double e = kick(shot_t);
		if (s[SN_DOUBLE] != 0.0) {
			e = maxd(e, 0.85 * kick(shot_t - SECOND_KICK));
		}
		const double u = shot_t / SHOT_SECONDS;
		const double rock = sin_d(PI_D * clampd(u / 0.6, 0.0, 1.0)) * (1.0 - u * 0.5);
		add(d, BARREL, -(0.15 * e));
		add(d, SURGE, -((0.04 * rock + 0.02 * e) * k));
		add(d, PITCH, (0.12 * rock + 0.04 * e) * k);
		add(d, SHELL_UP, 0.02 * rock);
		add(d, SHELL_P, 0.06 * rock * k);
		if (!calm) {
			add(d, ROLL, 0.025 * rock * sin_d(TAU_D * 14.0 * shot_t));
		}
		return 0.01 * rock * k;
	}

	// SniperAvatar._vent_pose
	double vent_pose(double k) {
		const double vent_t = s[SN_VENT_T];
		if (vent_t < 0.0) {
			return 0.0;
		}
		const double e = sin_d(PI_D * clampd(vent_t / VENT_SECONDS, 0.0, 1.0));
		add(d, SHELL_UP, 0.035 * e);
		add(d, SHELL_P, 0.1 * e * k);
		return 0.0;
	}

	// SniperAvatar._hurt_pose
	double hurt_pose(double k, bool calm) {
		const double hurt_t = s[SN_HURT_T];
		if (hurt_t < 0.0) {
			return 0.0;
		}
		const int hurt_leg = int(s[SN_HURT_LEG]);
		const double h = hurt_t / HURT_SECONDS;
		const double e = sin_d(PI_D * mind(h / 0.25, 1.0)) * (1.0 - sstep(0.25, 1.0, h));
		add(d, SURGE, -(0.04 * e * k));
		add(d, PITCH, 0.07 * e * k);
		add(d, ROLL, 0.07 * e * k * (hurt_leg % 2 == 0 ? 1.0 : -1.0));
		foot[hurt_leg] += Vector3(0.0f, 0.06f, 0.0f) * f32(e) * f32(k);
		if (!calm) {
			add(d, SHELL_UP, 0.012 * e * std::fabs(sin_d(TAU_D * 10.0 * hurt_t)));
			add(d, SHELL_P, 0.05 * e * sin_d(TAU_D * 12.0 * hurt_t));
		}
		return -0.015 * e * k;
	}

	// SniperAvatar._rise_pose
	double rise_pose() {
		const double r = 1.0 - s[SN_RISE];
		if (r <= 0.0) {
			return 0.0;
		}
		const double low = r * r * (1.0 - clampd(s[SN_STRIDE], 0.0, 1.0));
		for (int j = 0; j < LEGS; j++) {
			foot[j] += flat_unit(feet[j]) * f32(0.12) * f32(low);
		}
		add(d, SHELL_UP, -(0.02 * r));
		add(d, PITCH, -(0.1 * r));
		add(d, BARREL, -(0.12 * r));
		return -0.22 * low;
	}

	// SniperAvatar._death_pose
	double death_pose(double lift, bool calm) {
		const double die_t = s[SN_DIE];
		if (die_t < 0.0) {
			return lift;
		}
		const double u = clampd(die_t / DEATH_SECONDS, 0.0, 1.0);
		const double keep = 1.0 - sstep(0.0, 0.2, u);
		for (int j : { SURGE, ROLL, PITCH, SWAY }) {
			d[j] = f32(double(d[j]) * keep);
		}
		lift *= keep;
		const double splay = sstep(0.05, 0.6, u);
		const double land = sstep(0.45, 0.85, u);
		add(d, PITCH, 0.18 * splay - 0.3 * land);
		add(d, ROLL, 0.14 * splay);
		d[SHELL_P] = f32(lerpd(double(d[SHELL_P]), -0.15, land));
		d[SHELL_UP] = f32(lerpd(double(d[SHELL_UP]), -0.02, land));
		d[BARREL] = f32(lerpd(double(d[BARREL]), 0.05, splay));
		for (int j = 0; j < LEGS; j++) {
			foot[j] = foot[j] * f32(keep) + flat_unit(feet[j]) * f32(0.2) * f32(splay);
		}
		if (!calm) {
			const double kick_e = sin_d(PI_D * clampd((u - 0.7) / 0.15, 0.0, 1.0));
			foot[1] += Vector3(-0.03f, 0.08f, 0.0f) * f32(kick_e);
		}
		return lift - 0.3 * splay;
	}

	// SniperAvatar._lens
	double lens(bool calm, double breath, const Ctx &cx) const {
		const double die_t = s[SN_DIE];
		const double shot_t = s[SN_SHOT_T];
		const double hurt_t = s[SN_HURT_T];
		double e = LENS_REST * (1.0 + 0.2 * (calm ? 0.4 : 1.0) * breath);
		if (int(s[SN_STATE]) == cx.st.windup && die_t < 0.0) {
			e = LENS_REST * glow_of_tell(s[SN_TELL], s[T], calm);
		}
		if (shot_t >= 0.0) {
			e = maxd(e, LENS_SHOT * (1.0 - shot_t / SHOT_SECONDS));
		}
		if (hurt_t >= 0.0) {
			e += 1.0 * (1.0 - hurt_t / HURT_SECONDS);
		}
		e *= lerpd(0.25, 1.0, s[SN_RISE]);
		if (die_t >= 0.0) {
			e = lerpd(e, 0.05, sstep(0.1, 0.6, clampd(die_t / DEATH_SECONDS, 0.0, 1.0)));
		}
		return e;
	}

	// SniperAvatar._muzzle
	double muzzle(bool calm, const Ctx &cx) const {
		const double die_t = s[SN_DIE];
		const double shot_t = s[SN_SHOT_T];
		double e = MUZZLE_CHARGE * sstep(0.0, 1.0, s[SN_CHARGE]);
		if (int(s[SN_STATE]) == cx.st.windup && tell_flashing(s[SN_TELL]) && !calm) {
			e *= 0.8 + 0.4 * double(int64_t(s[T] * TELL_FLICKER_HZ * 2.0) % 2);
		}
		e = maxd(e, MUZZLE_CHARGE * 0.5 * s[SN_HEAT]);
		if (shot_t >= 0.0) {
			e = maxd(e, MUZZLE_FLARE * (1.0 - sstep(0.0, 0.4, shot_t / SHOT_SECONDS)));
		}
		if (die_t >= 0.0) {
			e *= 1.0 - sstep(0.0, 0.4, clampd(die_t / DEATH_SECONDS, 0.0, 1.0));
		}
		return e;
	}
};

// SniperAvatar._body_xf: the lift, the surge, the roll and the pitch at the hub, the sway.
Transform3D body_xf(const float *d, double lift) {
	return Transform3D(Basis(), Vector3(d[SURGE], f32(lift), 0.0f)) * at_xf(HUB) *
			Transform3D(axis_angle(RIGHT, d[ROLL]), Vector3()) * Transform3D(axis_angle(BACK, d[PITCH]), Vector3()) *
			at_xf(-HUB) * Transform3D(axis_angle(UP, d[SWAY]), Vector3());
}

// SniperAvatar._pose on a VAT avatar (no nodes): the drives, the lift and the glows.
void sn_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double k = calm ? CALM : 1.0;
	Pose p;
	p.s = s;
	for (int j = 0; j < DRIVES; j++) {
		p.d[j] = 0.0f;
	}
	Vector3 hips[LEGS], knees[LEGS];
	for (int j = 0; j < LEGS; j++) {
		p.foot[j] = Vector3();
		hips[j] = v3(s, SN_HIPS + 3 * j);
		knees[j] = v3(s, SN_KNEES + 3 * j);
		p.feet[j] = v3(s, SN_FEET + 3 * j);
	}
	const double breath = sin_d(TAU_D * s[T] * BREATH_HZ);
	double lift = p.walk_pose(k);
	lift += p.idle_pose(k, calm, breath);
	lift += p.aim_pose(k, calm, cx);
	lift += p.shot_pose(k, calm);
	lift += p.vent_pose(k);
	lift += p.hurt_pose(k, calm);
	lift += p.rise_pose();
	lift = p.death_pose(lift, calm);
	for (int j = 0; j < LEG0; j++) {
		p.d[j] = f32(clampd(double(p.d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	s[SN_LIFT] = lift;
	Vector3 want[LEGS];
	for (int j = 0; j < LEGS; j++) {
		want[j] = p.feet[j] + p.foot[j];
	}
	rig::reach(p.d, LEG0, body_xf(p.d, lift), hips, knees, p.feet, want, LEGS);
	for (int j = LEG0; j < MUZZLE; j++) {
		p.d[j] = f32(clampd(double(p.d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	p.d[MUZZLE] = f32(p.muzzle(calm, cx));
	for (int j = 0; j < DRIVES; j++) {
		s[SN_VD + j] = p.d[j];
	}
	s[SN_LENS] = f32(p.lens(calm, breath, cx));
}

} // namespace

// SniperAvatar.apply_state from a sync (`more`: its HP first).
void sn_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const int64_t hp = int64_t(more[0]);
	const bool fresh = s[FRESH] != 0.0;
	if (fresh) {
		s[SN_RISE] = state == c.st.spawn ? 0.0 : 1.0;
	} else {
		const int was_state = int(s[SN_STATE]);
		const bool shot = state == c.st.active && was_state != c.st.active;
		const bool missed = state == c.st.recover && was_state == c.st.windup;
		if (shot || missed) { // (a one-tick shot between two syncs still kicks)
			s[SN_SHOT_T] = 0.0;
			s[SN_HEAT] = 1.0;
		}
		if (state == c.st.recover && was_state != c.st.recover) {
			s[SN_VENT_T] = 0.0;
		}
		if (state == c.st.windup && was_state != c.st.windup) {
			s[SN_SETTLE_T] = 0.0;
		}
		const int64_t was = int64_t(s[SN_HP]);
		if (hp >= 0 && was >= 0 && hp < was) {
			s[SN_HURT_T] = 0.0;
			s[SN_HURT_LEG] = double((int64_t(s[SN_HURT_LEG]) + 1) % LEGS);
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
	s[SN_STATE] = state;
	s[SN_TELL] = windup;
	s[SN_HP] = double(hp);
	if (fresh) {
		s[FRESH] = 0.0;
		sn_pose(s, c);
	}
}

// SniperAvatar.advance (`f`: the facing's yaw, get_parent().rotation.y).
void sn_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const int state = int(s[SN_STATE]);
	const bool dying = s[SN_DIE] >= 0.0;
	const bool moving = state == c.st.move && !dying;
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	s[SN_SPEED] = lerpd(s[SN_SPEED], moving ? double(vel.length()) : 0.0, ease_rate(moving ? 8.0 : 5.0, dt));
	const double fy = double(f.facing_yaw);
	s[SN_OMEGA] =
			rig::turning(s[SN_OMEGA], fy, s[SN_LAST_FY], s[SN_HAVE_FY] != 0.0 && !dying, dt, ease_rate(10.0, dt));
	s[SN_LAST_FY] = fy;
	s[SN_HAVE_FY] = 1.0;
	const Vector3 local = axis_angle(UP, f32(-s[SN_LAST_FY])).xform(Vector3(vel.x, 0.0f, -vel.y));
	if (moving && double(local.length()) > 0.2) {
		const Vector2 dir(f32(s[SN_DIR]), f32(s[SN_DIR + 1]));
		const Vector2 to = dir.lerp(Vector2(local.x, local.z).normalized(), f32(ease_rate(10.0, dt)));
		const Vector2 now = double(to.length()) > 0.05 ? to.normalized() : dir;
		s[SN_DIR] = now.x;
		s[SN_DIR + 1] = now.y;
	}
	const double most = maxd(s[SN_SPEED] / MOVE_SPEED, std::fabs(s[SN_OMEGA]) / TURN_REF);
	s[SN_STRIDE] = toward(s[SN_STRIDE], mind(most, 1.0), dt * (most > s[SN_STRIDE] ? 4.0 : 2.5));
	s[SN_PHASE] =
			Math::fposmod(s[SN_PHASE] + STEP_HZ * maxd(1.0, most / STRIDE_MAX) * dt * signd(s[SN_STRIDE]), 1.0);
	const bool planted = state != c.st.move && state != c.st.spawn && !dying;
	s[SN_BRACE] = toward(s[SN_BRACE], planted ? 1.0 : 0.0, dt * (planted ? 4.0 : 2.0));
	const double charge = state == c.st.windup ? s[SN_TELL] : 0.0;
	s[SN_CHARGE] = toward(s[SN_CHARGE], charge, dt * (charge > s[SN_CHARGE] ? 20.0 : 4.0));
	const bool spawning = state == c.st.spawn;
	s[SN_RISE] = toward(s[SN_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 2.2));
	s[SN_SETTLE_T] = rig::clip(s[SN_SETTLE_T], dt, SETTLE_SECONDS);
	s[SN_SHOT_T] = rig::clip(s[SN_SHOT_T], dt, SHOT_SECONDS);
	s[SN_VENT_T] = rig::clip(s[SN_VENT_T], dt, VENT_SECONDS);
	s[SN_HURT_T] = rig::clip(s[SN_HURT_T], dt, HURT_SECONDS);
	s[SN_HEAT] = toward(s[SN_HEAT], 0.0, dt * 1.2);
	if (dying) {
		s[SN_DIE] += dt;
	}
	sn_pose(s, c);
}

// SniperAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (a drive spanning nothing sent as it is).
int sn_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[SN_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		const double span = VAT_DRIVES[i].hi - lo;
		out[i] = Math::is_zero_approx(span) ? f32(v) : f32((v - lo) / span);
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
