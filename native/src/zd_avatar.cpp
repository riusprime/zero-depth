#include "zd_avatar.h"

#include <cmath>
#include <limits>

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector4.hpp>

using namespace godot;

namespace zd {
namespace av {

namespace {

// GDScript's sin, cos, exp and asin are the engine's (its C library's), and this library's C library rounds some
// arguments differently (sin near PI, seen at a flinch's last frame): each goes through the engine's own function,
// so the numbers are the GDScript ones bit for bit.
inline double dsin(double x) {
	return UtilityFunctions::sin(x);
}
inline double dcos(double x) {
	return UtilityFunctions::cos(x);
}
inline double dexp(double x) {
	return UtilityFunctions::exp(x);
}
inline double dasin(double x) {
	return UtilityFunctions::asin(x);
}

} // namespace

namespace {

// GDScript's constants (doubles), by the names of the GDScript.
constexpr double PI_D = 3.1415926535897932384626433833;
constexpr double TAU_D = 6.2831853071795864769252867666;
// AvatarBase
constexpr double TELL_CROUCH_BY = 0.6;
constexpr double TELL_FLASH_FROM = 0.8;
constexpr double TELL_GLOW_CLIMB = 1.5;
constexpr double TELL_GLOW_FLASH = 2.5;
constexpr double TELL_FLICKER_HZ = 9.0;
constexpr double FLINCH_SECONDS = 0.2;
constexpr double FLINCH_LEAN = 0.3;
constexpr double FLINCH_SQUASH = 0.16;
constexpr double FLINCH_PEAK = 0.25;
constexpr double FLINCH_SNAP = 0.18;
constexpr double STRIKE_RAISE_BY = 0.35;
constexpr double STRIKE_SNAP_S = 0.07;
constexpr double STRIKE_HOLD_S = 0.12;
constexpr double STRIKE_BACK_S = 0.35;
constexpr int MOTION_GAP_TICKS = 30;
// HordeAvatar
constexpr double SPLITLING_SCALE = 0.62;
constexpr double WALK_FULL_MPS = 2.0;
constexpr double WALK_HZ = 2.2;
constexpr double DEATH_SECONDS = 0.4;
constexpr double MUZZLE_ENERGY = 4.0;
constexpr double BOB_RATE = 7.0;
constexpr double BOB_M = 0.015;
constexpr double SNIPER_AIM_MIN = -0.16;
constexpr double SNIPER_AIM_SPAN = 0.28;
// ChargerAvatar, ChargerVat
constexpr double STRIDE_M = 0.55;
constexpr double MAX_CYCLES = 7.0;
constexpr double WALK_SPEED = 3.0;
constexpr double TELEPORT_SPEED = 40.0;
constexpr double RISE_TIME = 0.35;
constexpr double VISOR_ENERGY = 1.4;
constexpr double BODY_Y_LO = -0.32;
constexpr double BODY_Y_HI = 0.12;

// GDScript's utility functions on doubles (clampf, maxf, minf, lerpf, smoothstep, move_toward).
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
inline double smooth(double from, double to, double s) {
	return Math::smoothstep(from, to, s);
}
inline double toward(double from, double to, double delta) {
	return Math::move_toward(from, to, delta);
}
inline float f32(double v) {
	return float(v);
}

bool flinching(const double *s) {
	return s[FLINCH_T] < FLINCH_SECONDS;
}

double flinch_envelope(double u) {
	if (u <= 0.0 || u >= 1.0) {
		return 0.0;
	}
	if (u < FLINCH_PEAK) {
		const double a = u / FLINCH_PEAK;
		return 1.0 - (1.0 - a) * (1.0 - a);
	}
	const double b = (u - FLINCH_PEAK) / (1.0 - FLINCH_PEAK);
	return (1.0 - b) * (1.0 - b) * (1.0 - b) - FLINCH_SNAP * dsin(PI_D * b) * (1.0 - b);
}

double consume_hold(double *s, double delta) {
	if (s[HOLD] <= 0.0) {
		return delta;
	}
	const double used = mind(s[HOLD], maxd(delta, 0.0));
	s[HOLD] -= used;
	return delta - used;
}

void advance_flinch(double *s, double delta, const Frame &f) {
	if (!flinching(s)) {
		return;
	}
	s[FLINCH_T] += clampd(delta, 0.0, 0.05);
	const Transform3D rest = get_xf(s, REST_XF);
	if (!flinching(s)) {
		put_xf(s, XF, rest);
		return;
	}
	const double k = flinch_envelope(s[FLINCH_T] / FLINCH_SECONDS) * s[FLINCH_S];
	const double yaw = double(f.facing_yaw);
	const Basis turn = axis_angle(Vector3(0, 1, 0), f32(yaw + double(rest.basis.get_euler().y)));
	const Vector3 d = turn.inverse().xform(Vector3(f32(s[FLINCH_DX]), 0.0f, -f32(s[FLINCH_DY])));
	const Vector3 axis = Vector3(0, 1, 0).cross(d).normalized();
	const Vector3 squash(f32(1.0 + 0.5 * FLINCH_SQUASH * k), f32(1.0 - FLINCH_SQUASH * k),
			f32(1.0 + 0.5 * FLINCH_SQUASH * k));
	const Basis b = axis_angle(axis, f32(FLINCH_LEAN * k)) * Basis::from_scale(squash);
	const Vector3 p(0, 0, 0); // _flinch_pivot(): 0 for the batched kinds
	const double knock = maxd(flinch_envelope(s[FLINCH_T] / FLINCH_SECONDS), 0.0) * s[FLINCH_KNOCK];
	put_xf(s, XF, rest * Transform3D(b, p - b.xform(p) + d * f32(knock)));
}

double strike_raise(double p) {
	return smooth(0.0, STRIKE_RAISE_BY, clampd(p, 0.0, 1.0));
}

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
	return 1.0 - smooth(0.0, 1.0, (after - STRIKE_HOLD_S) / STRIKE_BACK_S);
}

bool strike_snapping(const double *s) {
	return s[STRIKE_S] >= 0.0 && s[STRIKE_S] < STRIKE_SNAP_S;
}

double strike_raised(const double *s, bool winding, double p, double rest) {
	if (winding) {
		return strike_raise(p);
	}
	if (strike_snapping(s)) {
		return mind(rest, 1.0 - s[STRIKE_S] / STRIKE_SNAP_S);
	}
	return s[STRIKE_S] < 0.0 ? rest : 0.0;
}

double tell_crouch(double p) {
	return smooth(0.0, TELL_CROUCH_BY, clampd(p, 0.0, 1.0));
}

double tell_glow(double p, double t, bool calm) {
	const double q = clampd(p, 0.0, 1.0);
	double g = 1.0 + TELL_GLOW_CLIMB * smooth(0.0, TELL_FLASH_FROM, q);
	if (q >= TELL_FLASH_FROM && q <= 1.0) {
		const double flicker = calm ? 1.0 : 0.75 + 0.25 * dcos(t * TAU_D * TELL_FLICKER_HZ);
		g += TELL_GLOW_FLASH * flicker;
	}
	return g;
}

double rate(double per_second, double dt) {
	return 1.0 - dexp(-per_second * dt);
}

// --- HordeAvatar ---

bool strike_kind(int c) {
	return c == SWARMER || c == SPLITTER || c == SPLITLING || c == SHIELD_BEARER;
}
bool tell_kind(int c) {
	return c == SWARMER || c == SPLITTER || c == SPLITLING || c == SHIELD_BEARER || c == SNIPER;
}
bool leg_kind(int c) {
	return c == SPLITTER || c == SPLITLING || c == SHIELD_BEARER;
}

double h_crouch(const double *s, int c, const States &st) {
	if (!tell_kind(c) || int(s[H_STATE]) != st.windup) {
		return 0.0;
	}
	return tell_crouch(s[H_TELL]);
}

// _pose_parts on a VAT avatar: HordeVat.grid_of.
void pose_parts(double *s, int c, const Vector4 &d) {
	Vector4 g;
	switch (c) {
		case MENDER:
			g = Vector4(d.x, 0.0f, 0.0f, f32(Math::fposmod(double(d.w) / TAU_D, 1.0)));
			break;
		case MINE_LAYER:
			g = Vector4(d.x, d.y, 0.0f, 0.0f);
			break;
		case SNIPER:
			g = Vector4(f32((double(d.x) - SNIPER_AIM_MIN) / SNIPER_AIM_SPAN), f32((double(d.y) - 0.4) / 0.6), 0.0f,
					f32(s[H_MUZZLE]));
			break;
		default:
			g = Vector4(d.x, d.y, d.z, f32(dasin(clampd(double(d.w), -1.0, 1.0)) / TAU_D));
			break;
	}
	s[H_D] = g.x;
	s[H_D + 1] = g.y;
	s[H_D + 2] = g.z;
	s[H_D + 3] = g.w;
}

void place_body(double *s, int c, const Vector3 &bp, double brz, double mrx, double ms) {
	const double bs = c == SPLITLING ? SPLITLING_SCALE : 1.0;
	Transform3D xf(euler_yxz(Vector3(0.0f, 0.0f, f32(brz))) * Basis::from_scale(Vector3(1, 1, 1) * f32(bs)),
			bp);
	if (s[H_IS_MODEL] != 0.0) {
		xf = xf *
				Transform3D(euler_yxz(Vector3(f32(mrx), 0.0f, 0.0f)) * Basis::from_scale(Vector3(1, 1, 1) * f32(ms)),
						Vector3());
	}
	put_xf(s, H_BODY, xf);
}

void pose_model(double *s, int c, double energy, bool calm, Vector3 bp, double brz) {
	const double t = s[T];
	const double d = s[H_DIE] >= 0.0 ? clampd(s[H_DIE] / DEATH_SECONDS, 0.0, 1.0) : 0.0;
	double mrx = 0.0;
	Vector4 drives(f32(s[H_WIND]), f32(s[H_STRIKE]), 0.0f, f32(dsin(s[H_WALK_T]) * s[H_WALK]));
	if (leg_kind(c)) {
		bp.y = f32(double(bp.y) + std::fabs(dsin(s[H_WALK_T])) * 0.025 * s[H_WALK]);
	}
	switch (c) {
		case SHIELD_BEARER:
			brz += -s[H_STRIKE] * 0.05;
			break;
		case SPLITTER:
		case SPLITLING:
			drives.z = f32(d);
			break;
		case MENDER: {
			const bool healing = s[H_HEALING] != 0.0;
			bp.y = f32(double(bp.y) + (0.22 + (calm ? 0.0 : dsin(t * 2.2) * 0.06)));
			if (!calm) {
				mrx = dsin(t * 1.3) * 0.05;
			}
			drives = Vector4(healing ? 1.0f : 0.0f, 0.0f, 0.0f, f32(t * 2.0));
			energy = 1.5 + (healing ? 2.5 + dsin(t * 9.0) : 0.0);
		} break;
		default:
			break;
	}
	if (d > 0.0) {
		brz += d * 0.7;
		bp.y = f32(double(bp.y) + d * 0.04 * s[H_HEIGHT]);
	}
	place_body(s, c, bp, brz, mrx, 1.0 - 0.35 * d);
	pose_parts(s, c, drives);
	s[H_GLOW] = energy * lerpd(0.2, 1.0, s[H_RISE]) * (1.0 - d);
}

void h_pose(double *s, int c, const Ctx &cx) {
	const bool calm = cx.calm;
	const double t = s[T];
	const double wind = s[H_WIND], strike = s[H_STRIKE], rise = s[H_RISE], height = s[H_HEIGHT];
	const double bob = calm ? 0.0 : dsin(t * BOB_RATE) * BOB_M;
	const double crouch = h_crouch(s, c, cx.st);
	const bool telling = tell_kind(c) && int(s[H_STATE]) == cx.st.windup;
	const double tell = telling ? tell_glow(s[H_TELL], t, calm) : 1.0;
	double energy = (1.5 + wind * 3.0) * tell + strike * 2.0;
	if (c == SWARMER) {
		s[H_LIFT] = bob - (1.0 - rise) * height;
		s[H_GLOW] = energy * lerpd(0.2, 1.0, rise);
		return;
	}
	const Vector3 bp(f32(-wind * 0.06 - crouch * 0.08 * height + strike * 0.12),
			f32(bob - (1.0 - rise) * height - crouch * 0.1 * height), 0.0f);
	const double brz = crouch * 0.12;
	if (s[H_IS_MODEL] != 0.0) {
		pose_model(s, c, energy, calm, bp, brz);
		return;
	}
	if (c == MINE_LAYER) {
		pose_parts(s, c, Vector4(f32(wind), strike < 0.5 ? 1.0f : 0.0f, 0.0f, 0.0f));
	} else if (c == SNIPER) {
		const double charge = telling ? smooth(0.0, 1.0, s[H_TELL]) : 0.0;
		const double muzzle = MUZZLE_ENERGY * charge * tell / (1.0 + TELL_GLOW_CLIMB + TELL_GLOW_FLASH);
		s[H_MUZZLE] = maxd(muzzle, strike * MUZZLE_ENERGY);
		pose_parts(s, c,
				Vector4(f32(-wind * 0.04 + strike * 0.12 - crouch * 0.12), f32(0.4 + 0.6 * maxd(charge, strike)), 0.0f,
						0.0f));
	}
	place_body(s, c, bp, brz, 0.0, 1.0);
	s[H_GLOW] = energy * lerpd(0.2, 1.0, rise);
}

// AvatarBase._view_position for a detached avatar: its transform under the facing under the root.
Vector3 view_position(const double *s, const Frame &f) {
	Transform3D xf = get_xf(s, XF);
	xf = f.facing * xf;
	xf = Transform3D(Basis(), f.root) * xf;
	return xf.origin;
}

void h_advance(double *s, int c, double delta, const Frame &f, const Ctx &cx) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	if (s[H_DIE] >= 0.0) {
		s[H_DIE] += dt;
	}
	if (s[H_IS_MODEL] != 0.0) { // The walk's pace from how fast the body moves
		const Vector3 at = view_position(s, f);
		const float inf = std::numeric_limits<float>::infinity();
		const Vector3 last(f32(s[H_LAST_AT]), f32(s[H_LAST_AT + 1]), f32(s[H_LAST_AT + 2]));
		const double speed = last == Vector3(inf, inf, inf)
				? 0.0
				: double(Vector2(f32(double(at.x) - double(last.x)), f32(double(at.z) - double(last.z))).length()) / dt;
		s[H_LAST_AT] = at.x;
		s[H_LAST_AT + 1] = at.y;
		s[H_LAST_AT + 2] = at.z;
		s[H_WALK] = toward(s[H_WALK], clampd(speed / WALK_FULL_MPS, 0.0, 1.0), dt * 4.0);
		s[H_WALK_T] += dt * lerpd(0.0, WALK_HZ * TAU_D, s[H_WALK]);
	}
	const int state = int(s[H_STATE]);
	const bool spawning = state == cx.st.spawn;
	s[H_RISE] = toward(s[H_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 2.5));
	const bool winding = state == cx.st.windup;
	strike_advance(s, dt);
	if (strike_kind(c)) {
		s[H_WIND] = strike_raised(s, winding, s[H_TELL], toward(s[H_WIND], 0.0, dt * 5.0));
		s[H_STRIKE] = strike_swing(s);
	} else {
		s[H_WIND] = toward(s[H_WIND], winding ? 1.0 : 0.0, dt * (winding ? 2.2 : 5.0));
		if (state == cx.st.active) {
			s[H_STRIKE] = 1.0;
		} else {
			s[H_STRIKE] = toward(s[H_STRIKE], 0.0, dt * 4.0);
		}
	}
	h_pose(s, c, cx);
}

// --- ChargerAvatar ---

void c_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double t = s[T];
	const double wind = s[C_WIND], daze = s[C_DAZE], walk = s[C_WALK];
	const double rise = smooth(0.0, 1.0, s[C_RISE]);
	const double lunge = s[C_LUNGE] * (1.0 - daze);
	const double bob = std::fabs(dsin(s[C_PHASE] * 2.0)) * 0.02 * walk;
	const double breath = dsin(t * 2.4) * 0.008 * (1.0 - walk);
	const double tremble = calm ? 0.0 : dsin(t * 47.0) * 0.006 * wind;
	const bool winding = int(s[C_STATE]) == cx.st.windup;
	const double crouch = winding ? tell_crouch(s[C_TELL]) : 0.0;
	const double drop = daze * 0.09 - wind * 0.05 + lunge * 0.07 + crouch * 0.09;
	const double y = bob + breath + tremble - drop;
	const float sink_y = f32(-(1.0 - rise) * 0.45);
	s[C_RISE_NOW] = rise;
	s[C_LUNGE_NOW] = lunge;
	s[C_CROUCH_NOW] = crouch;
	s[C_Y_NOW] = y;
	s[C_LIFT] = sink_y;
	const double shimmer = calm ? 0.0 : 0.5 * dsin(t * 30.0);
	const double tell = winding ? tell_glow(s[C_TELL], t, calm) : 1.0;
	const double glow = VISOR_ENERGY * (1.0 + wind * (1.6 + shimmer) + lunge * 1.2) * tell * (1.0 - daze * 0.7);
	if (!(std::fabs(glow - s[C_VISOR]) <= 1e-4)) { // set_visor_energy: written on a change only
		s[C_VISOR] = glow;
	}
}

void c_advance(double *s, double delta, const Ctx &cx) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const double vlen = double(Vector2(f32(s[VEL_X]), f32(s[VEL_Y])).length());
	s[C_SPEED] = lerpd(s[C_SPEED], vlen, rate(12.0, dt));
	const int st = int(s[C_STATE]);
	strike_advance(s, dt);
	s[C_WIND] = strike_raised(s, st == cx.st.windup, s[C_TELL], toward(s[C_WIND], 0.0, dt * 6.0));
	s[C_LUNGE] = strike_swing(s);
	s[C_DAZE] = toward(s[C_DAZE], st == cx.st.recover ? 1.0 : 0.0, dt * 4.0);
	if (st != cx.st.spawn) {
		s[C_RISE] = toward(s[C_RISE], 1.0, dt / RISE_TIME);
	}
	const bool walking = st == cx.st.move || st == cx.st.active;
	const double walk_target = walking ? clampd(s[C_SPEED] / WALK_SPEED, 0.0, 1.0) : 0.0;
	s[C_WALK] = lerpd(s[C_WALK], walk_target, rate(10.0, dt));
	s[C_PHASE] += mind(s[C_SPEED] / STRIDE_M, MAX_CYCLES) * TAU_D * dt;
	c_pose(s, cx);
}

inline double loop(double u) {
	return u - std::floor(u);
}

} // namespace

Transform3D get_xf(const double *s, int at) {
	const double *o = s + at;
	Transform3D xf;
	xf.basis.rows[0] = Vector3(f32(o[0]), f32(o[1]), f32(o[2]));
	xf.origin.x = f32(o[3]);
	xf.basis.rows[1] = Vector3(f32(o[4]), f32(o[5]), f32(o[6]));
	xf.origin.y = f32(o[7]);
	xf.basis.rows[2] = Vector3(f32(o[8]), f32(o[9]), f32(o[10]));
	xf.origin.z = f32(o[11]);
	return xf;
}

void put_xf(double *s, int at, const Transform3D &xf) {
	double *o = s + at;
	for (int r = 0; r < 3; r++) {
		o[r * 4] = xf.basis.rows[r].x;
		o[r * 4 + 1] = xf.basis.rows[r].y;
		o[r * 4 + 2] = xf.basis.rows[r].z;
	}
	o[3] = xf.origin.x;
	o[7] = xf.origin.y;
	o[11] = xf.origin.z;
}

// The engine's float sin/cos (Math::sin(float): its own C library's sinf/cosf), which its Basis builders call. Which
// function gives the engine's bits depends on the platform (the equality test, tests/unit/native/test_native_crowd.gd,
// catches a wrong choice on either):
// - Windows: the engine's C library and this library's (MSVC) differ in the last bit of some sinf/cosf values, and
//   the engine's float result equals its double function rounded to float;
// - elsewhere: the engine and this library share the system's C library, whose sinf/cosf are not always the double
//   function rounded, so its sinf/cosf are called themselves.
float fsin(float x) {
#ifdef _WIN32
	return float(dsin(double(x)));
#else
	return ::sinf(x);
#endif
}

float fcos(float x) {
#ifdef _WIN32
	return float(dcos(double(x)));
#else
	return ::cosf(x);
#endif
}

Basis axis_angle(const Vector3 &axis, float angle) {
	Basis b;
	const Vector3 axis_sq(axis.x * axis.x, axis.y * axis.y, axis.z * axis.z);
	const float cosine = fcos(angle);
	b.rows[0][0] = axis_sq.x + cosine * (1.0f - axis_sq.x);
	b.rows[1][1] = axis_sq.y + cosine * (1.0f - axis_sq.y);
	b.rows[2][2] = axis_sq.z + cosine * (1.0f - axis_sq.z);
	const float sine = fsin(angle);
	const float t = 1 - cosine;
	float xyzt = axis.x * axis.y * t;
	float zyxs = axis.z * sine;
	b.rows[0][1] = xyzt - zyxs;
	b.rows[1][0] = xyzt + zyxs;
	xyzt = axis.x * axis.z * t;
	zyxs = axis.y * sine;
	b.rows[0][2] = xyzt + zyxs;
	b.rows[2][0] = xyzt - zyxs;
	xyzt = axis.y * axis.z * t;
	zyxs = axis.x * sine;
	b.rows[1][2] = xyzt - zyxs;
	b.rows[2][1] = xyzt + zyxs;
	return b;
}

Basis euler_yxz(const Vector3 &e) {
	float c = fcos(e.x);
	float s = fsin(e.x);
	const Basis xmat(1, 0, 0, 0, c, -s, 0, s, c);
	c = fcos(e.y);
	s = fsin(e.y);
	const Basis ymat(c, 0, s, 0, 1, 0, -s, 0, c);
	c = fcos(e.z);
	s = fsin(e.z);
	const Basis zmat(c, -s, 0, s, c, 0, 0, 0, 1);
	return ymat * xmat * zmat;
}

void advance(double *s, int cls, double delta, const Frame &f, const Ctx &c) {
	if (is_charger(cls)) {
		c_advance(s, delta, c);
	} else if (cls != NONE) {
		h_advance(s, cls, delta, f, c);
	}
}

void process(double *s, int cls, double delta, const Frame &f, const Ctx &c) {
	const double dt = consume_hold(s, delta);
	if (dt > 0.0) {
		advance(s, cls, dt, f, c);
		advance_flinch(s, dt, f);
	}
}

void apply(double *s, int cls, int64_t tick, int state, bool healing, double windup, float pos_x, float pos_y,
		const Ctx &c) {
	if (is_charger(cls)) {
		s[C_TELL] = clampd(windup, 0.0, 1.0);
		// _track_motion(tick, pos, TELEPORT_SPEED)
		const bool fresh = s[FRESH] != 0.0;
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
		const int prev = int(s[C_STATE]);
		s[C_STATE] = state;
		strike_note(s, state, c.st);
		if (state == c.st.spawn) {
			s[C_RISE] = 0.0;
		} else if (fresh && prev != c.st.spawn) {
			s[C_RISE] = 1.0;
		}
		s[FRESH] = 0.0;
		return;
	}
	if (cls == NONE) {
		return;
	}
	s[H_HEALING] = healing ? 1.0 : 0.0;
	s[H_TELL] = clampd(windup, 0.0, 1.0);
	const bool fresh = s[FRESH] != 0.0;
	if (fresh || state != int(s[H_STATE])) {
		s[H_STATE] = state;
		s[H_STATE_TICK] = double(tick);
	}
	s[H_TICKS_IN] = double(tick - int64_t(s[H_STATE_TICK]));
	strike_note(s, state, c.st);
	if (fresh) {
		s[FRESH] = 0.0;
		s[H_RISE] = state == c.st.spawn ? 0.0 : 1.0;
		h_pose(s, cls, c);
	}
}

double glow_energy(const double *s, int cls) {
	return is_charger(cls) ? s[C_VISOR] : s[H_GLOW];
}

Transform3D body_offset(const double *s, int cls, const Transform3D &xf) {
	if (is_charger(cls)) {
		return xf.translated_local(Vector3(0.0f, f32(s[C_LIFT]), 0.0f));
	}
	if (cls == SWARMER) {
		return xf * Transform3D(Basis(), Vector3(0.0f, f32(s[H_LIFT]), 0.0f));
	}
	return xf * get_xf(s, H_BODY);
}

int drives(const double *s, int cls, double period, const Ctx &c, float *out) {
	if (is_charger(cls)) {
		const double t = s[T];
		out[0] = f32(s[C_WIND]);
		out[1] = f32(s[C_LUNGE_NOW]);
		out[2] = f32(s[C_DAZE]);
		out[3] = f32(loop(s[C_PHASE] / TAU_D));
		out[4] = f32(s[C_WALK]);
		out[5] = f32(s[C_CROUCH_NOW]);
		out[6] = f32(s[C_RISE_NOW]);
		const double lo = BODY_Y_LO;
		out[7] = f32((s[C_Y_NOW] - lo) / (BODY_Y_HI - lo));
		out[8] = f32(loop(t * 0.9 / TAU_D));
		out[9] = f32((1.0 - s[C_WALK]) * (1.0 - s[C_WIND]));
		out[10] = f32(loop(t * 9.0 / TAU_D));
		out[11] = 0.0f;
		return 12;
	}
	if (cls == SWARMER) {
		out[0] = f32(clampd(s[H_WIND], 0.0, 1.0));
		out[1] = f32(clampd(s[H_STRIKE], 0.0, 1.0));
		out[2] = f32(clampd(h_crouch(s, cls, c.st), 0.0, 1.0));
		double g = 0.0;
		if (period > 0.0) {
			const double u = s[T] / period;
			g = u - std::floor(u);
		}
		out[3] = f32(g);
		return 4;
	}
	for (int k = 0; k < 4; k++) {
		out[k] = f32(s[H_D + k]);
	}
	return 4;
}

} // namespace av
} // namespace zd
