// The Rock Lurker's avatar on a batch row (zd_avatar.h L_*): RockLurkerAvatar's sync (apply_state), frame step
// (advance) and pose (_pose, _about_feet, _blend_tucked) with AvatarBase's strike clock, ported line by line in the
// same order and float width as the GDScript (src/presentation/world_view/rock_lurker_avatar.gd): its clocks and
// glows are doubles (GDScript floats), the raw drives floats (its PackedFloat32Array: each `v[d] += x` reads the float,
// adds in double and stores a float), the hind feet's slide a float Vector2. tests/unit/native/test_native_crowd.gd
// holds the drawn buffers equal to the GDScript avatar's bit for bit.

#include "zd_avatar.h"

#include <cmath>
#include <cstdint>

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2.hpp>

using namespace godot;

namespace zd {
namespace av {

namespace {

constexpr double PI_D = 3.1415926535897932384626433833;
constexpr double TAU_D = 6.2831853071795864769252867666;
// AvatarBase
constexpr double FLINCH_SECONDS = 0.2;
constexpr double STRIKE_SNAP_S = 0.07;
constexpr double STRIKE_HOLD_S = 0.12;
constexpr double STRIKE_BACK_S = 0.35;
constexpr int MOTION_GAP_TICKS = 30;
// RockLurkerAvatar
constexpr double CRACK_REST = 0.6;
constexpr double CRACK_RUMBLE = 2.2;
constexpr double CRACK_OUT = 2.0;
constexpr double VISOR_REST = 1.6;
constexpr float HIND_FOOT_X = -0.34f;
constexpr float HIND_FOOT_Y = 0.0f;
constexpr double STRIDE_M = 1.1;
constexpr double ARM_SWING = 0.5;
constexpr double LEG_SWING = 0.55;
constexpr double HAND_LIFT = 0.6;
constexpr double BREATH_HZ = 0.42;
constexpr double REAR_PITCH = 0.62;
constexpr double SLAM_PITCH = 0.15;
constexpr int RECOVER_TICKS = 48;
constexpr double RECOVER_HOLD = 0.4;
constexpr double BURST_S = 0.55;
constexpr double BURST_SLAM_S = 0.34;
constexpr double DEATH_SECONDS = 1.1;
constexpr double TELEPORT_SPEED = 30.0;

// The raw drives (RockLurkerAvatar's BX ... CRACK).
enum Drive {
	BX = 0,
	BY = 1,
	BW = 2,
	BR = 3,
	BP = 4,
	HX = 5,
	HY = 6,
	HP = 7,
	AO_R = 8,
	AS_R = 10,
	EL_R = 12,
	LO = 14,
	LS_R = 15,
	CRACK = 17,
	DRIVES = 18,
};

// VAT_DRIVES: [lo, hi] (none loops; the cracks' [0, 0] is sent as it is).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.16, 0.2 }, // BX
	{ -0.3, 0.26 }, // BY
	{ -0.16, 0.16 }, // BW
	{ -0.3, 0.3 }, // BR
	{ -0.6, 0.9 }, // BP
	{ -0.1, 0.3 }, // HX
	{ -0.45, 0.45 }, // HY
	{ -0.6, 0.5 }, // HP
	{ -0.7, 0.7 }, // AO r
	{ -0.7, 0.7 }, // AO l
	{ -1.5, 2.2 }, // AS r
	{ -1.5, 2.2 }, // AS l
	{ -0.7, 1.9 }, // EL r
	{ -0.7, 1.9 }, // EL l
	{ -0.5, 0.7 }, // LO
	{ -1.4, 1.4 }, // LS r
	{ -1.4, 1.4 }, // LS l
	{ 0.0, 0.0 }, // CRACK
};

// _blend_tucked's targets, by drive (CRACK untouched).
const double TUCKED[CRACK] = { 0.0, -0.25, 0.0, 0.0, -0.05, 0.24, 0.0, -0.3, 0.25, -0.25, -1.0, -1.0, 0.6, 0.6, 0.15,
	-0.45, -0.45 };

// GDScript's utility functions on doubles, and the engine's sin, cos and exp (zd_avatar.cpp's reason).
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
inline double dexp(double x) {
	return UtilityFunctions::exp(x);
}

// `v[d] += x` on the PackedFloat32Array.
inline void add(float *v, int d, double x) {
	v[d] = f32(double(v[d]) + x);
}

// AvatarBase's strike clock (strike_note, strike_advance, strike_swing, strike_snapping) and flinch_amount.
void strike_note(double *s, int state, const States &st) {
	if (state == st.active) {
		if (s[STRIKE_S] < 0.0 || s[STRIKE_END] >= 0.0) {
			s[STRIKE_S] = 0.0;
			s[STRIKE_END] = -1.0;
		}
	} else if (s[STRIKE_S] >= 0.0 && s[STRIKE_END] < 0.0) {
		s[STRIKE_END] = s[STRIKE_S];
	}
}

void strike_advance(double *s, double dt) {
	if (s[STRIKE_S] < 0.0) {
		return;
	}
	s[STRIKE_S] += dt;
	const double after = s[STRIKE_S] - maxd(STRIKE_SNAP_S, s[STRIKE_END]);
	if (s[STRIKE_END] >= 0.0 && after > STRIKE_HOLD_S + STRIKE_BACK_S) {
		s[STRIKE_S] = -1.0;
		s[STRIKE_END] = -1.0;
	}
}

double strike_swing(const double *s) {
	if (s[STRIKE_S] < 0.0) {
		return 0.0;
	}
	if (s[STRIKE_S] < STRIKE_SNAP_S) {
		const double u = s[STRIKE_S] / STRIKE_SNAP_S;
		return u * u;
	}
	if (s[STRIKE_END] < 0.0) {
		return 1.0;
	}
	const double after = s[STRIKE_S] - maxd(STRIKE_SNAP_S, s[STRIKE_END]);
	if (after <= STRIKE_HOLD_S) {
		return 1.0;
	}
	return 1.0 - sstep(0.0, 1.0, (after - STRIKE_HOLD_S) / STRIKE_BACK_S);
}

bool strike_snapping(const double *s) {
	return s[STRIKE_S] >= 0.0 && s[STRIKE_S] < STRIKE_SNAP_S;
}

double flinch_amount(const double *s) {
	return envelope(s[FLINCH_T] / FLINCH_SECONDS) * s[FLINCH_S];
}

// RockLurkerAvatar._about_feet: the body's slide that turns it by `pitch` about the hind feet.
Vector2 about_feet(const double *s, double pitch) {
	const Vector2 d = Vector2(HIND_FOOT_X, HIND_FOOT_Y) - Vector2(f32(s[L_REST]), f32(s[L_REST + 1]));
	const double c = cos_d(pitch);
	const double sn = sin_d(pitch);
	return d - Vector2(f32(double(d.x) * c - double(d.y) * sn), f32(double(d.x) * sn + double(d.y) * c));
}

void blend_tucked(float *v, double k) {
	if (k <= 0.0) {
		return;
	}
	for (int d = 0; d < CRACK; d++) {
		v[d] = f32(lerpd(double(v[d]), TUCKED[d], k));
	}
}

double rear_at(const double *s, double p) {
	if (s[L_BURST_SLAM] != 0.0) {
		return sstep(0.28, 0.75, p);
	}
	return sstep(0.0, 0.55, p);
}

// RockLurkerAvatar._pose on a VAT avatar (its nodes are not drawn): the drives, the lift, the glows.
void l_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double m = calm ? 0.4 : 1.0;
	float v[DRIVES] = {};
	const double t = s[T];
	const bool winding = int(s[L_STATE]) == cx.st.windup;
	const double rear0 = s[L_REAR];
	const double slam = s[L_SLAM];
	const double walk = s[L_WALK];
	const double phase = s[L_PHASE];
	const double windup = s[L_WINDUP];
	const double burst = s[L_BURST];
	const double die = s[L_DIE];
	const double impact = s[L_IMPACT];
	const double busy = clampd(maxd(rear0, slam), 0.0, 1.0);
	// Idle awake: slow heavy breathing, the head scanning and nodding against it, the weight shifting.
	const double br = sin_d(t * TAU_D * BREATH_HZ);
	const double idle = (1.0 - clampd(walk, 0.0, 1.0)) * (1.0 - busy);
	v[BY] = f32(0.014 * br * idle);
	v[BP] = f32(0.03 * br * idle);
	v[HP] = f32(-0.06 * br * idle);
	v[HY] = f32(0.3 * sin_d(t * 0.43) * sin_d(t * 0.19 + 1.0) * idle * m);
	v[BR] = f32(0.03 * sin_d(t * 0.31) * idle * m);
	for (int k = 0; k < 2; k++) {
		v[AS_R + k] = f32(0.05 * br * idle);
		v[EL_R + k] = f32(-0.04 * br * idle);
	}
	// The knuckle walk.
	const double w = clampd(walk, 0.0, 1.2);
	for (int k = 0; k < 2; k++) {
		const double sg = k == 0 ? 1.0 : -1.0;
		const double pa = phase + PI_D * k;
		const double lift = sstep(0.0, 1.0, maxd(0.0, cos_d(pa)));
		add(v, AS_R + k, w * (ARM_SWING * sin_d(pa) + 0.1 * lift));
		add(v, EL_R + k, w * HAND_LIFT * lift);
		add(v, AO_R + k, -sg * w * 0.07 * lift);
		add(v, LS_R + k, w * LEG_SWING * sin_d(pa + PI_D * 0.5));
	}
	add(v, BY, w * 0.024 * cos_d(2.0 * phase) * (calm ? 0.5 : 1.0));
	add(v, BX, -w * 0.012 * cos_d(2.0 * phase) * m);
	add(v, BR, -w * 0.055 * cos_d(phase) * m);
	add(v, BW, w * 0.05 * sin_d(phase) * m);
	add(v, BP, -0.07 * w + w * 0.025 * cos_d(2.0 * phase + 0.5) * m);
	add(v, HP, 0.06 * w - w * 0.02 * cos_d(2.0 * phase) * m);
	add(v, LO, 0.05 * w);
	// The slam: reared back about the hind feet, then the smash.
	const double coil = winding ? sstep(0.75, 1.0, windup) : 0.0;
	const double rear = rear0 * (calm ? 0.8 : 1.0);
	const double pitch = REAR_PITCH * rear + 0.07 * coil * rear - SLAM_PITCH * slam;
	const Vector2 about = about_feet(s, pitch);
	add(v, BX, double(about.x) + 0.06 * slam);
	add(v, BY, double(about.y) + 0.03 * rear - 0.03 * slam);
	add(v, BP, pitch);
	add(v, HP, -0.3 * rear + 0.12 * slam);
	add(v, HX, -0.04 * rear);
	for (int k = 0; k < 2; k++) {
		const double sg = k == 0 ? 1.0 : -1.0;
		add(v, AS_R + k, 1.6 * rear + 0.4 * slam);
		add(v, EL_R + k, 0.6 * rear - 0.2 * slam);
		add(v, AO_R + k, sg * (0.14 * rear - 0.12 * slam));
		add(v, LS_R + k, -0.85 * pitch);
	}
	if (winding && !calm && rear0 > 0.9) {
		add(v, BX, 0.006 * sin_d(t * 53.0) * rear0);
		add(v, BR, 0.014 * sin_d(t * 41.0) * rear0);
	}
	// The shell's follow-through after the smash.
	if (impact >= 0.0 && !calm) {
		const double wob = dexp(-5.0 * impact) * sin_d(17.0 * impact);
		add(v, BP, -0.07 * wob);
		add(v, BY, 0.018 * wob);
		for (int k = 0; k < 2; k++) {
			add(v, AS_R + k, 0.08 * wob);
		}
	}
	// The burst.
	double flare = 0.0;
	if (burst >= 0.0) {
		const double u = burst / (s[L_BURST_SLAM] != 0.0 ? BURST_SLAM_S : BURST_S);
		const double ant = sstep(0.0, 0.14, u) * (1.0 - sstep(0.14, 0.26, u));
		const double heave = sstep(0.16, 0.45, u) * (1.0 - sstep(0.45, 0.85, u)) * (calm ? 0.6 : 1.0);
		const double land = sstep(0.68, 0.82, u) * (1.0 - sstep(0.82, 1.0, u));
		flare = maxd(ant, heave);
		add(v, BY, -0.025 * ant + 0.1 * heave - 0.03 * land);
		add(v, BP, 0.2 * heave - 0.04 * land);
		add(v, HX, -0.05 * heave);
		add(v, HP, 0.15 * heave);
		for (int k = 0; k < 2; k++) {
			const double sg = k == 0 ? 1.0 : -1.0;
			add(v, AS_R + k, 0.45 * heave - 0.12 * land);
			add(v, AO_R + k, -sg * 0.3 * heave);
			add(v, EL_R + k, 0.25 * heave);
		}
		if (!calm && u < 0.3) {
			add(v, BX, 0.01 * sin_d(t * 61.0) * ant);
			add(v, BR, 0.02 * sin_d(t * 47.0) * ant);
		}
	}
	// The flinch.
	const double fl = maxd(flinch_amount(s), 0.0);
	add(v, HX, 0.06 * fl);
	add(v, HP, 0.12 * fl);
	add(v, BY, -0.015 * fl);
	for (int k = 0; k < 2; k++) {
		add(v, AO_R + k, -(k == 0 ? 1.0 : -1.0) * 0.18 * fl);
	}
	// Disguised, and the death's rock.
	double tuck = sstep(0.0, 1.0, s[L_TUCK]);
	double dead = 0.0;
	if (die >= 0.0) {
		dead = sstep(0.0, 0.5, die / DEATH_SECONDS * 1.1);
		dead = dead * dead * (3.0 - 2.0 * dead);
		tuck = maxd(tuck, dead);
	}
	blend_tucked(v, tuck);
	const double ru = s[L_RUMBLE] * tuck * (1.0 - dead);
	add(v, BY, 0.022 * ru);
	add(v, HX, -0.035 * ru);
	add(v, HP, 0.1 * ru);
	if (!calm) {
		add(v, BX, 0.01 * ru * sin_d(t * 47.0));
		add(v, BR, 0.02 * ru * sin_d(t * 39.0 + 1.0));
		add(v, BW, 0.012 * ru * sin_d(t * 31.0 + 2.0));
	}
	if (die >= 0.0) {
		const double d = die / DEATH_SECONDS;
		add(v, BR, 0.12 * dead);
		add(v, BP, -0.03 * dead);
		add(v, BY, -0.02 * dead + 0.016 * sin_d(PI_D * clampd((d - 0.45) / 0.25, 0.0, 1.0)));
	}
	// The glows.
	const double pulse_hz = calm ? 0.8 : 2.4;
	double hidden_e = CRACK_REST + 0.15 * sin_d(t * 1.1);
	hidden_e += (CRACK_RUMBLE + 0.7 - hidden_e) * ru * (0.55 + 0.45 * sin_d(t * TAU_D * pulse_hz));
	const double awake_e = CRACK_OUT + 0.4 * br * idle + 1.6 * rear0 + 0.8 * flare;
	double e = lerpd(awake_e, hidden_e, tuck);
	if (impact >= 0.0) {
		e += 2.5 * dexp(-4.0 * impact);
	}
	e += 1.5 * fl;
	double vis = VISOR_REST * (winding ? glow_of_tell(windup, t, calm) : 1.0) + 2.0 * flare;
	vis = lerpd(vis, 0.3 + 1.6 * ru, tuck);
	if (die >= 0.0) {
		const double d = die / DEATH_SECONDS;
		e *= 1.0 - sstep(0.1, 0.85, d);
		vis *= 1.0 - sstep(0.0, 0.4, d);
	}
	v[CRACK] = f32(maxd(e, 0.0));
	s[L_CRACK] = double(v[CRACK]);
	s[L_VISOR] = maxd(vis, 0.0);
	// The spawn's rise.
	const double sink = 1.0 - s[L_RISE];
	s[L_LIFT] = -0.6 * sink * sink * (3.0 - 2.0 * sink);
	for (int k = 0; k < DRIVES; k++) {
		if (VAT_DRIVES[k].hi > VAT_DRIVES[k].lo) {
			v[k] = f32(clampd(double(v[k]), VAT_DRIVES[k].lo, VAT_DRIVES[k].hi));
		}
	}
	for (int k = 0; k < DRIVES; k++) {
		s[L_VD + k] = v[k];
	}
}

} // namespace

// RockLurkerAvatar.apply_state from a sync (`more`: hidden, rumbling).
void l_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c) {
	const bool hidden = more[0] != 0.0;
	const bool fresh = s[FRESH] != 0.0;
	const int64_t last = int64_t(s[LAST_TICK]);
	if (fresh || state != int(s[L_STATE])) {
		s[L_STATE_TICKS] = 0.0;
	} else if (tick > last) {
		s[L_STATE_TICKS] = double(int64_t(s[L_STATE_TICKS]) + (tick - last));
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
	if (fresh) {
		s[L_TUCK] = hidden ? 1.0 : 0.0;
		s[L_RISE] = state == c.st.spawn ? 0.0 : 1.0;
	} else if (s[L_HIDDEN] != 0.0 && !hidden) { // it stops hiding: the burst
		s[L_BURST] = 0.0;
		s[L_BURST_SLAM] = state == c.st.windup ? 1.0 : 0.0;
	}
	if (state != c.st.windup && s[L_BURST] < 0.0) {
		s[L_BURST_SLAM] = 0.0;
	}
	s[L_STATE] = state;
	s[L_HIDDEN] = hidden ? 1.0 : 0.0;
	s[L_RUMBLING] = (more[1] != 0.0 && hidden) ? 1.0 : 0.0;
	s[L_WINDUP] = clampd(windup, 0.0, 1.0);
	strike_note(s, state, c.st);
	if (fresh) {
		s[FRESH] = 0.0;
		l_pose(s, c);
	}
}

// RockLurkerAvatar.advance
void l_advance(double *s, double delta, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	if (s[L_DIE] >= 0.0) {
		s[L_DIE] += dt;
		l_pose(s, c);
		return;
	}
	const double vlen = double(Vector2(f32(s[VEL_X]), f32(s[VEL_Y])).length());
	s[L_SPEED] = lerpd(s[L_SPEED], vlen, ease_rate(8.0, dt));
	const int state = int(s[L_STATE]);
	const bool spawning = state == c.st.spawn;
	s[L_RISE] = toward(s[L_RISE], spawning ? 0.0 : 1.0, dt / 0.5);
	const bool rumbling = s[L_RUMBLING] != 0.0;
	s[L_RUMBLE] = toward(s[L_RUMBLE], rumbling ? 1.0 : 0.0, dt * (rumbling ? 3.0 : 1.5));
	if (s[L_BURST] >= 0.0) {
		s[L_BURST] += dt;
		const double u = s[L_BURST] / (s[L_BURST_SLAM] != 0.0 ? BURST_SLAM_S : BURST_S);
		s[L_TUCK] = 1.0 - sstep(0.2, 0.62, u);
		if (u >= 1.0) {
			s[L_BURST] = -1.0;
		}
	} else if (s[L_HIDDEN] != 0.0) {
		s[L_TUCK] = toward(s[L_TUCK], 1.0, dt * 2.0);
	} else {
		s[L_TUCK] = toward(s[L_TUCK], 0.0, dt * 4.0);
	}
	const bool was_snapping = strike_snapping(s);
	strike_advance(s, dt);
	if (state == c.st.windup) {
		s[L_REAR] = rear_at(s, s[L_WINDUP]);
	} else if (strike_snapping(s)) {
		s[L_REAR] = mind(s[L_REAR], 1.0 - s[STRIKE_S] / STRIKE_SNAP_S);
	} else {
		s[L_REAR] = toward(s[L_REAR], 0.0, dt * 4.0);
	}
	double hold = 0.0;
	if (state == c.st.recover) {
		hold = 1.0 - sstep(RECOVER_HOLD, 1.0, double(int64_t(s[L_STATE_TICKS])) / RECOVER_TICKS);
	}
	const double swing = strike_swing(s);
	if (strike_snapping(s)) {
		s[L_SLAM] = maxd(swing, s[L_SLAM]);
	} else if (swing > 0.0 || hold > 0.0) {
		s[L_SLAM] = maxd(swing, hold);
	} else {
		s[L_SLAM] = toward(s[L_SLAM], 0.0, dt * 3.0);
	}
	if (was_snapping && !strike_snapping(s)) {
		s[L_IMPACT] = 0.0;
	}
	if (s[L_IMPACT] >= 0.0) {
		s[L_IMPACT] += dt;
		if (s[L_IMPACT] > 1.5) {
			s[L_IMPACT] = -1.0;
		}
	}
	const double busy = maxd(maxd(s[L_REAR], s[L_SLAM]), s[L_TUCK]);
	const double walk_to = busy > 0.3 ? 0.0 : clampd(s[L_SPEED] / 2.2, 0.0, 1.2);
	s[L_WALK] = lerpd(s[L_WALK], walk_to, ease_rate(6.0, dt));
	s[L_PHASE] = Math::fposmod(s[L_PHASE] + s[L_SPEED] * dt * TAU_D / STRIDE_M * (1.0 - busy), TAU_D * 8.0);
	l_pose(s, c);
}

// RockLurkerAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the cracks' drive as it is).
int l_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[L_VD + i]));
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
