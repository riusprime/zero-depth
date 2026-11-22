#include "zd_legged_rig.h"

#include <cmath>

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "zd_avatar.h"

using namespace godot;

namespace zd {
namespace rig {

namespace {

constexpr double PI_D = 3.1415926535897932384626433833;

// GDScript's double sin, atan2 and acos are the engine's (see zd_avatar.cpp: this library's C library rounds some
// arguments differently).
inline double dsin(double x) {
	return UtilityFunctions::sin(x);
}
inline double datan2(double y, double x) {
	return UtilityFunctions::atan2(y, x);
}
inline double dacos(double x) {
	return UtilityFunctions::acos(x);
}
inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline double lerpd(double from, double to, double w) {
	return from + (to - from) * w;
}
inline double signd(double v) {
	return v > 0.0 ? 1.0 : (v < 0.0 ? -1.0 : 0.0);
}
inline float f32(double v) {
	return float(v);
}

const Vector3 UP(0, 1, 0);

} // namespace

// The engine's float atan2 (Math::atan2(float, float)): as fsin and fcos (zd_avatar.cpp), on Windows its double
// function rounded to float, elsewhere the system's own.
float angle(const Vector2 &v) {
#ifdef _WIN32
	return float(datan2(double(v.y), double(v.x)));
#else
	return ::atan2f(v.y, v.x);
#endif
}

Vector2 rotated(const Vector2 &v, float by) {
	const float sine = av::fsin(by);
	const float cosi = av::fcos(by);
	return Vector2(v.x * cosi - v.y * sine, v.x * sine + v.y * cosi);
}

double heading(const Vector3 &hip, const Vector3 &tip) {
	return datan2(-(double(tip.z) - double(hip.z)), double(tip.x) - double(hip.x));
}

void reach(float *d, int leg0, const Transform3D &body, const Vector3 *hips, const Vector3 *knees,
		const Vector3 *tips, const Vector3 *want, int n) {
	const Transform3D inv = body.affine_inverse();
	for (int j = 0; j < n; j++) {
		const Vector3 hip = hips[j];
		const Basis to_leg = av::axis_angle(UP, f32(-heading(hip, tips[j])));
		const Vector3 w = to_leg.xform(inv.xform(want[j]) - hip);
		const double yaw = datan2(-double(w.z), double(w.x));
		const Vector3 t = av::axis_angle(UP, f32(-yaw)).xform(w);
		const Vector2 aim(t.x, t.y);
		const Vector3 k3 = to_leg.xform(knees[j] - hip);
		const Vector3 f3 = to_leg.xform(tips[j] - knees[j]);
		const Vector2 u0(k3.x, k3.y);
		const Vector2 l0(f3.x, f3.y);
		const double a = double(u0.length());
		const double b = double(l0.length());
		const double r = clampd(double(aim.length()), std::fabs(a - b) + 0.002, (a + b) * 0.998);
		const double bend = signd(double((u0 + l0).cross(u0)));
		const double off = dacos(clampd((a * a + r * r - b * b) / (2.0 * a * r), -1.0, 1.0));
		const double hip_turn = Math::wrapf(double(angle(aim)) + bend * off - double(angle(u0)), -PI_D, PI_D);
		const Vector2 l1 = aim.normalized() * f32(r) - rotated(u0, f32(hip_turn));
		d[leg0 + 3 * j] = f32(yaw);
		d[leg0 + 3 * j + 1] = f32(hip_turn);
		d[leg0 + 3 * j + 2] = f32(Math::wrapf(double(angle(l1)) - double(angle(l0)) - hip_turn, -PI_D, PI_D));
	}
}

Vector2 leg_cycle(double q, double duty) {
	if (q < duty) {
		return Vector2(f32(1.0 - 2.0 * q / duty), 0.0f);
	}
	const double w = (q - duty) / (1.0 - duty);
	const double up = dsin(PI_D * w);
	return Vector2(f32(-1.0 + 2.0 * Math::smoothstep(0.0, 1.0, w)), f32(up * up * (3.0 - 2.0 * up)));
}

double clip(double t, double dt, double length) {
	if (t < 0.0) {
		return t;
	}
	t += dt;
	return t < length ? t : -1.0;
}

double hash01(double x) {
	const double v = dsin(x * 12.9898 + 78.233) * 43758.5453;
	return v - std::floor(v);
}

double scan(double t, double every, double seed_off) {
	const double u = t / every + seed_off;
	const double seg = std::floor(u);
	const double a = hash01(seg) * 2.0 - 1.0;
	const double b = hash01(seg + 1.0) * 2.0 - 1.0;
	return lerpd(a, b, Math::smoothstep(0.55, 0.85, u - seg));
}

double twitch(double t, double every, double seed_off) {
	const double u = t / every + seed_off;
	const double seg = std::floor(u);
	if (hash01(seg + 31.0) < 0.55) {
		return 0.0;
	}
	const double s = hash01(seg + 17.0) > 0.5 ? 1.0 : -1.0;
	return s * dsin(PI_D * clampd((u - seg - 0.4) / 0.05, 0.0, 1.0));
}

double replant(double t, double every, int legs, int &leg) {
	const double u = t / every;
	const double seg = std::floor(u);
	if (hash01(seg + 7.0) <= 0.4) {
		leg = -1;
		return 0.0;
	}
	leg = int(int64_t(hash01(seg + 3.0) * legs) % legs);
	return dsin(PI_D * clampd((u - seg - 0.2) / 0.2, 0.0, 1.0));
}

double turning(double omega, double fy, double last, bool have, double dt, double rate) {
	double w = 0.0;
	if (have) {
		w = clampd(Math::wrapf(fy - last, -PI_D, PI_D) / dt, -6.0, 6.0);
	}
	return lerpd(omega, w, rate);
}

} // namespace rig
} // namespace zd
