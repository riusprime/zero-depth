// The Needle's avatar on a batch row (zd_avatar.h N_*): NeedleAvatar's sync (apply_state), frame step (advance) and
// pose (_pose and its clips, _body_xf, _gem, _muzzle), ported line by line in the same order and float width as the
// GDScript (src/presentation/world_view/needle_avatar.gd): its numbers are doubles, its raw drives floats (its
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
constexpr double TELL_CROUCH_BY = 0.6;
constexpr double TELL_FLASH_FROM = 0.8;
constexpr double TELL_FLICKER_HZ = 9.0;
constexpr int MOTION_GAP_TICKS = 30;
// NeedleAvatar
constexpr double GEM_REST = 1.6;
constexpr double GEM_TELL = 6.0;
constexpr double MUZZLE_CHARGE = 3.5;
constexpr double MUZZLE_FLARE = 7.0;
constexpr int BURST_COUNT = 3;
constexpr int BURST_GAP_TICKS = 6;
constexpr double TELEPORT_SPEED = 20.0;
constexpr double SHOT_SECONDS = 0.22;
constexpr double BURST_SECONDS = 0.55;
constexpr double VENT_SECONDS = 0.6;
constexpr double HURT_SECONDS = 0.35;
constexpr double DEATH_SECONDS = 1.0;
constexpr double MOVE_SPEED = 3.2;
constexpr double DUTY = 0.5;
constexpr double SWEEP = 0.11;
constexpr double LIFT = 0.08;
constexpr double STRIDE_MAX = 1.4;
constexpr double STEP_HZ = MOVE_SPEED * DUTY / (2.0 * SWEEP);
constexpr double GATHER = 0.04;
constexpr double CROUCH = 0.035;
constexpr double TURN_REF = 3.0;
constexpr double TURN_SWING = 0.2;
constexpr int LEGS = 4;
constexpr double STRIDE_AT[LEGS] = { 0.0, 0.5, 0.5, 0.0 };
constexpr double BRACE_DROP = 0.07;
constexpr double BRACE_WIDE = 0.035;
constexpr double BREATH_HZ = 0.6;
constexpr double CALM = 0.45;

// The raw drives (NeedleAvatar's SURGE ... MUZZLE).
enum Drive {
	SURGE = 0,
	ROLL = 1,
	PITCH = 2,
	SWAY = 3,
	SHELL_UP = 4,
	SHELL_P = 5,
	BARREL = 6,
	LEG0 = 7,
	MUZZLE = 19,
	DRIVES = 20,
};

// VAT_DRIVES: [lo, hi] (none loops; the muzzle's spans nothing: sent as it is).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.1, 0.1 }, // SURGE
	{ -0.3, 0.3 }, // ROLL
	{ -0.4, 0.4 }, // PITCH
	{ -0.45, 0.45 }, // SWAY
	{ -0.04, 0.08 }, // SHELL_UP
	{ -0.3, 0.3 }, // SHELL_P
	{ -0.14, 0.06 }, // BARREL
	{ -1.2, 1.2 }, { -1.7, 1.7 }, { -2.6, 2.6 }, // leg fr
	{ -1.2, 1.2 }, { -1.7, 1.7 }, { -2.6, 2.6 }, // leg fl
	{ -1.2, 1.2 }, { -1.7, 1.7 }, { -2.6, 2.6 }, // leg br
	{ -1.2, 1.2 }, { -1.7, 1.7 }, { -2.6, 2.6 }, // leg bl
	{ 0.0, 0.0 }, // MUZZLE
};

const Vector3 UP(0, 1, 0);
const Vector3 RIGHT(1, 0, 0);
const Vector3 BACK(0, 0, 1);
const Vector3 ROLL_AT(0.0f, 0.3f, 0.0f);
const Vector3 PITCH_AT(0.0f, 0.3f, 0.0f);

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

// AvatarBase.tell_crouch, tell_flashing
double tell_crouch(double p) {
	return sstep(0.0, TELL_CROUCH_BY, clampd(p, 0.0, 1.0));
}
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
		const double die_t = s[N_DIE];
		return die_t < 0.0 ? 1.0 : 1.0 - sstep(0.0, 0.2, clampd(die_t / DEATH_SECONDS, 0.0, 1.0));
	}

	// NeedleAvatar._walk_pose
	double walk_pose(double k) {
		const double g = clampd(s[N_STRIDE], 0.0, 1.0);
		const double walk = clampd(s[N_SPEED] / MOVE_SPEED, 0.0, STRIDE_MAX);
		const double turn = clampd(s[N_OMEGA] / TURN_REF, -1.0, 1.0);
		const Vector3 dir(f32(s[N_DIR]), 0.0f, f32(s[N_DIR + 1]));
		for (int j = 0; j < LEGS; j++) {
			const Vector2 c = rig::leg_cycle(Math::fposmod(s[N_PHASE] - STRIDE_AT[j], 1.0), DUTY);
			const Vector3 tip = feet[j];
			const double th = turn * TURN_SWING * double(c.x);
			const Vector3 inward = (-flat_unit(tip)) * f32(GATHER) * f32(g);
			foot[j] += dir * f32(walk * SWEEP * double(c.x)) + inward +
					Vector3(f32(th * double(tip.z)), f32(LIFT * g * double(c.y)), f32(-th * double(tip.x)));
		}
		if (g <= 0.0) {
			return 0.0;
		}
		const double p = s[N_PHASE];
		const double w = mind(walk, 1.0);
		add(d, ROLL, g * k * 0.045 * sin_d(TAU_D * (p - 0.1)));
		add(d, SWAY, w * k * 0.04 * sin_d(TAU_D * (p + 0.15)));
		add(d, PITCH, w * k * 0.02 * sin_d(2.0 * TAU_D * (p - 0.1)) - w * 0.04);
		add(d, SHELL_UP, g * k * 0.008 * sin_d(2.0 * TAU_D * (p - 0.15)));
		add(d, SHELL_P, g * k * 0.03 * sin_d(2.0 * TAU_D * (p - 0.22)));
		return -CROUCH * g - g * k * 0.014 * cos_d(2.0 * TAU_D * (p - 0.05));
	}

	// NeedleAvatar._idle_pose
	double idle_pose(double k, bool calm, double breath) {
		const double t = s[T];
		const double idle = (1.0 - clampd(s[N_STRIDE], 0.0, 1.0)) * (1.0 - s[N_BRACE]) * alive();
		if (idle <= 0.0) {
			return 0.0;
		}
		add(d, SHELL_UP, idle * k * 0.006 * (breath + 1.0));
		add(d, SHELL_P, idle * k * 0.02 * breath);
		add(d, SWAY, idle * k * 0.3 * rig::scan(t, 2.6, 0.0));
		add(d, PITCH, idle * k * 0.04 * rig::scan(t, 3.4, 5.0));
		add(d, ROLL, idle * k * 0.02 * sin_d(0.7 * t));
		if (!calm) {
			add(d, SWAY, idle * 0.06 * rig::twitch(t, 4.1, 11.0));
			add(d, PITCH, idle * 0.03 * rig::twitch(t, 3.7, 23.0));
			add(d, SURGE, idle * 0.002 * sin_d(TAU_D * 11.0 * t)); // the servos' hum
		}
		int leg = -1;
		const double up = rig::replant(t, 2.9, LEGS, leg);
		if (leg >= 0) {
			foot[leg] += Vector3(0.02f, 0.05f, 0.0f) * f32(up) * f32(idle);
		}
		return idle * k * 0.006 * breath;
	}

	// NeedleAvatar._brace_pose
	double brace_pose(double k, bool calm, const Ctx &cx) {
		const double b = sstep(0.0, 1.0, s[N_BRACE]);
		if (b <= 0.0) {
			return 0.0;
		}
		const bool winding = int(s[N_STATE]) == cx.st.windup;
		const double tell = s[N_TELL];
		const double crouch = winding ? tell_crouch(tell) : 1.0;
		for (int j = 0; j < LEGS; j++) {
			foot[j] += flat_unit(feet[j]) * f32(BRACE_WIDE) * f32(b);
		}
		add(d, PITCH, -((0.05 + 0.04 * crouch) * b * k));
		add(d, SURGE, -(0.015 * crouch * b));
		add(d, SHELL_UP, -(0.012 * b));
		add(d, SHELL_P, -(0.06 * b * k));
		add(d, BARREL, 0.035 * b);
		if (!calm && winding) {
			const double t = s[T];
			const double top = sstep(0.75, 0.9, tell);
			add(d, ROLL, 0.01 * top * sin_d(TAU_D * 15.0 * t));
			add(d, BARREL, 0.004 * top * sin_d(TAU_D * 21.0 * t));
		}
		return -BRACE_DROP * b * (0.6 + 0.4 * crouch) * lerpd(0.7, 1.0, k);
	}

	// NeedleAvatar.kick
	static double kick(double t) {
		if (t < 0.0) {
			return 0.0;
		}
		return sstep(0.0, 0.02, t) * (1.0 - sstep(0.03, 0.09, t));
	}

	// NeedleAvatar._shot_pose
	double shot_pose(double k, bool calm) {
		const double e = kick(s[N_SHOT_T]);
		add(d, BARREL, -(0.11 * e));
		add(d, SURGE, -(0.012 * e * k));
		const double burst_t = s[N_BURST_T];
		if (burst_t < 0.0) {
			return 0.0;
		}
		const double u = burst_t / BURST_SECONDS;
		const double rock = sin_d(PI_D * clampd(u / 0.75, 0.0, 1.0));
		add(d, SURGE, -(0.025 * rock * k));
		add(d, PITCH, 0.08 * rock * k + 0.02 * e * k);
		add(d, SHELL_UP, 0.012 * rock);
		add(d, SHELL_P, 0.04 * rock * k);
		if (!calm) {
			add(d, ROLL, 0.02 * rock * sin_d(TAU_D * 18.0 * burst_t));
		}
		return 0.006 * rock * k;
	}

	// NeedleAvatar._vent_pose
	double vent_pose(double k) {
		const double vent_t = s[N_VENT_T];
		if (vent_t < 0.0) {
			return 0.0;
		}
		const double e = sin_d(PI_D * clampd(vent_t / VENT_SECONDS, 0.0, 1.0));
		add(d, SHELL_UP, 0.03 * e);
		add(d, SHELL_P, 0.12 * e * k);
		add(d, PITCH, 0.02 * e * k);
		return 0.0;
	}

	// NeedleAvatar._hurt_pose
	double hurt_pose(double k, bool calm) {
		const double hurt_t = s[N_HURT_T];
		if (hurt_t < 0.0) {
			return 0.0;
		}
		const int hurt_leg = int(s[N_HURT_LEG]);
		const double h = hurt_t / HURT_SECONDS;
		const double e = sin_d(PI_D * mind(h / 0.25, 1.0)) * (1.0 - sstep(0.25, 1.0, h));
		add(d, SURGE, -(0.035 * e * k));
		add(d, PITCH, 0.06 * e * k);
		add(d, ROLL, 0.06 * e * k * (hurt_leg % 2 == 0 ? 1.0 : -1.0));
		foot[hurt_leg] += Vector3(0.0f, 0.05f, 0.0f) * f32(e) * f32(k);
		if (!calm) {
			add(d, SHELL_UP, 0.012 * e * std::fabs(sin_d(TAU_D * 10.0 * hurt_t)));
			add(d, SHELL_P, 0.05 * e * sin_d(TAU_D * 12.0 * hurt_t));
		}
		return -0.01 * e * k;
	}

	// NeedleAvatar._rise_pose
	double rise_pose() {
		const double r = 1.0 - s[N_RISE];
		if (r <= 0.0) {
			return 0.0;
		}
		const double low = r * r * (1.0 - clampd(s[N_STRIDE], 0.0, 1.0));
		for (int j = 0; j < LEGS; j++) {
			foot[j] += flat_unit(feet[j]) * f32(0.06) * f32(low);
		}
		add(d, SHELL_UP, -(0.02 * r));
		add(d, PITCH, -(0.08 * r));
		add(d, BARREL, -(0.08 * r));
		return -0.13 * low;
	}

	// NeedleAvatar._death_pose
	double death_pose(double lift, bool calm) {
		const double die_t = s[N_DIE];
		if (die_t < 0.0) {
			return lift;
		}
		const double u = clampd(die_t / DEATH_SECONDS, 0.0, 1.0);
		const double keep = 1.0 - sstep(0.0, 0.2, u);
		for (int j : { SURGE, ROLL, PITCH, SWAY }) {
			d[j] = f32(double(d[j]) * keep);
		}
		lift *= keep;
		const double sag = sstep(0.1, 0.55, u);
		const double slip = sstep(0.35, 0.8, u);
		add(d, PITCH, -(0.22 * sag));
		add(d, ROLL, 0.12 * sag);
		d[SHELL_UP] = f32(lerpd(double(d[SHELL_UP]), 0.03, slip));
		d[SHELL_P] = f32(lerpd(double(d[SHELL_P]), 0.2, slip));
		d[BARREL] = f32(lerpd(double(d[BARREL]), 0.05, slip));
		for (int j = 0; j < LEGS; j++) {
			foot[j] = foot[j] * f32(keep) + flat_unit(feet[j]) * f32(0.1) * f32(sag);
		}
		if (!calm) {
			const double kk = sin_d(PI_D * clampd((u - 0.68) / 0.16, 0.0, 1.0));
			foot[2] += Vector3(-0.03f, 0.07f, 0.0f) * f32(kk);
		}
		return lift - 0.16 * sag;
	}

	// NeedleAvatar._gem
	double gem(bool calm, double breath, const Ctx &cx) const {
		const double die_t = s[N_DIE];
		const double shot_t = s[N_SHOT_T];
		const double hurt_t = s[N_HURT_T];
		double e = GEM_REST * (1.0 + 0.2 * (calm ? 0.4 : 1.0) * breath);
		if (int(s[N_STATE]) == cx.st.windup && die_t < 0.0) {
			e = GEM_REST * glow_of_tell(s[N_TELL], s[T], calm);
		}
		if (shot_t >= 0.0) {
			e = maxd(e, GEM_TELL * (1.0 - shot_t / SHOT_SECONDS));
		}
		if (hurt_t >= 0.0) {
			e += 1.0 * (1.0 - hurt_t / HURT_SECONDS);
		}
		e *= lerpd(0.25, 1.0, s[N_RISE]);
		if (die_t >= 0.0) {
			e = lerpd(e, 0.05, sstep(0.1, 0.6, clampd(die_t / DEATH_SECONDS, 0.0, 1.0)));
		}
		return e;
	}

	// NeedleAvatar._muzzle
	double muzzle(bool calm, const Ctx &cx) const {
		const double die_t = s[N_DIE];
		const double shot_t = s[N_SHOT_T];
		double e = MUZZLE_CHARGE * s[N_CHARGE];
		if (int(s[N_STATE]) == cx.st.windup && tell_flashing(s[N_TELL]) && !calm) {
			e *= 0.8 + 0.4 * double(int64_t(s[T] * TELL_FLICKER_HZ * 2.0) % 2);
		}
		e = maxd(e, MUZZLE_CHARGE * 0.6 * s[N_HEAT]);
		if (shot_t >= 0.0) {
			e = maxd(e, MUZZLE_FLARE * (1.0 - sstep(0.0, 1.0, shot_t / SHOT_SECONDS)));
		}
		if (die_t >= 0.0) {
			e *= 1.0 - sstep(0.0, 0.4, clampd(die_t / DEATH_SECONDS, 0.0, 1.0));
		}
		return e;
	}
};

// NeedleAvatar._body_xf: the lift, the surge, the roll, the pitch and the sway.
Transform3D body_xf(const float *d, double lift) {
	return Transform3D(Basis(), Vector3(d[SURGE], f32(lift), 0.0f)) * at_xf(ROLL_AT) *
			Transform3D(axis_angle(RIGHT, d[ROLL]), Vector3()) * at_xf(-ROLL_AT) * at_xf(PITCH_AT) *
			Transform3D(axis_angle(BACK, d[PITCH]), Vector3()) * at_xf(-PITCH_AT) *
			Transform3D(axis_angle(UP, d[SWAY]), Vector3());
}

// NeedleAvatar._pose on a VAT avatar (no nodes): the drives, the lift and the glows.
void n_pose(double *s, const Ctx &cx) {
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
		hips[j] = v3(s, N_HIPS + 3 * j);
		knees[j] = v3(s, N_KNEES + 3 * j);
		p.feet[j] = v3(s, N_FEET + 3 * j);
	}
	const double breath = sin_d(TAU_D * s[T] * BREATH_HZ);
	double lift = p.walk_pose(k);
	lift += p.idle_pose(k, calm, breath);
	lift += p.brace_pose(k, calm, cx);
	lift += p.shot_pose(k, calm);
	lift += p.vent_pose(k);
	lift += p.hurt_pose(k, calm);
	lift += p.rise_pose();
	lift = p.death_pose(lift, calm);
	for (int j = 0; j < LEG0; j++) {
		p.d[j] = f32(clampd(double(p.d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
	}
	s[N_LIFT] = lift;
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
		s[N_VD + j] = p.d[j];
	}
	s[N_GEM] = f32(p.gem(calm, breath, cx));
}

} // namespace

// NeedleAvatar.apply_state from a sync (`more`: its HP first).
void n_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const int64_t hp = int64_t(more[0]);
	const bool fresh = s[FRESH] != 0.0;
	if (fresh) {
		s[N_RISE] = state == c.st.spawn ? 0.0 : 1.0;
	} else {
		if (state == c.st.recover && int(s[N_STATE]) != c.st.recover) {
			s[N_VENT_T] = 0.0;
		}
		const int64_t was = int64_t(s[N_HP]);
		if (hp >= 0 && was >= 0 && hp < was) {
			s[N_HURT_T] = 0.0;
			s[N_HURT_LEG] = double((int64_t(s[N_HURT_LEG]) + 1) % LEGS);
		}
	}
	if (fresh || state != int(s[N_STATE])) {
		s[N_STATE_TICK] = double(tick);
		s[N_SHOTS] = 0.0;
	}
	// A bolt leaves the muzzle at the start of the burst and every gap after it: the barrel kicks.
	const int64_t shots = int64_t(s[N_SHOTS]);
	if (state == c.st.active && shots < BURST_COUNT) {
		if (tick - int64_t(s[N_STATE_TICK]) >= shots * BURST_GAP_TICKS) {
			s[N_SHOTS] = double(shots + 1);
			s[N_SHOT_T] = 0.0;
			s[N_HEAT] = 1.0;
			if (shots + 1 == 1) {
				s[N_BURST_T] = 0.0;
			}
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
	s[N_STATE] = state;
	s[N_TELL] = windup;
	s[N_HP] = double(hp);
	if (fresh) {
		s[FRESH] = 0.0;
		n_pose(s, c);
	}
}

// NeedleAvatar.advance (`f`: the facing's yaw, get_parent().rotation.y).
void n_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const int state = int(s[N_STATE]);
	const bool dying = s[N_DIE] >= 0.0;
	const bool moving = state == c.st.move && !dying;
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	s[N_SPEED] = lerpd(s[N_SPEED], moving ? double(vel.length()) : 0.0, ease_rate(moving ? 8.0 : 5.0, dt));
	const double fy = double(f.facing_yaw);
	s[N_OMEGA] = rig::turning(s[N_OMEGA], fy, s[N_LAST_FY], s[N_HAVE_FY] != 0.0 && !dying, dt, ease_rate(10.0, dt));
	s[N_LAST_FY] = fy;
	s[N_HAVE_FY] = 1.0;
	const Vector3 local = axis_angle(UP, f32(-s[N_LAST_FY])).xform(Vector3(vel.x, 0.0f, -vel.y));
	if (moving && double(local.length()) > 0.2) {
		const Vector2 dir(f32(s[N_DIR]), f32(s[N_DIR + 1]));
		const Vector2 to = dir.lerp(Vector2(local.x, local.z).normalized(), f32(ease_rate(10.0, dt)));
		const Vector2 now = double(to.length()) > 0.05 ? to.normalized() : dir;
		s[N_DIR] = now.x;
		s[N_DIR + 1] = now.y;
	}
	const double most = maxd(s[N_SPEED] / MOVE_SPEED, std::fabs(s[N_OMEGA]) / TURN_REF);
	s[N_STRIDE] = toward(s[N_STRIDE], mind(most, 1.0), dt * (most > s[N_STRIDE] ? 5.0 : 3.0));
	s[N_PHASE] = Math::fposmod(s[N_PHASE] + STEP_HZ * maxd(1.0, most / STRIDE_MAX) * dt * signd(s[N_STRIDE]), 1.0);
	const bool planted = (state == c.st.windup || state == c.st.active) && !dying;
	s[N_BRACE] = toward(s[N_BRACE], planted ? 1.0 : 0.0, dt * (planted ? 6.0 : 2.5));
	const double charge = state == c.st.windup ? s[N_TELL] : (planted ? 1.0 : 0.0);
	s[N_CHARGE] = toward(s[N_CHARGE], charge, dt * (charge > s[N_CHARGE] ? 20.0 : 2.5));
	const bool spawning = state == c.st.spawn;
	s[N_RISE] = toward(s[N_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 2.6));
	s[N_SHOT_T] = rig::clip(s[N_SHOT_T], dt, SHOT_SECONDS);
	s[N_BURST_T] = rig::clip(s[N_BURST_T], dt, BURST_SECONDS);
	s[N_VENT_T] = rig::clip(s[N_VENT_T], dt, VENT_SECONDS);
	s[N_HURT_T] = rig::clip(s[N_HURT_T], dt, HURT_SECONDS);
	s[N_HEAT] = toward(s[N_HEAT], 0.0, dt * 1.4);
	if (dying) {
		s[N_DIE] += dt;
	}
	n_pose(s, c);
}

// NeedleAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (a drive spanning nothing sent as it is).
int n_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[N_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		const double span = VAT_DRIVES[i].hi - lo;
		out[i] = Math::is_zero_approx(span) ? f32(v) : f32((v - lo) / span);
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
