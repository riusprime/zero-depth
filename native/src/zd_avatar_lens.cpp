// The Lens Drone's avatar on a batch row (zd_avatar.h LD_*): LensDroneAvatar's sync (apply_state), frame step
// (advance) and pose (_pose: the hover and bob, the pod's roll, the ring's turn, the eye's glow, the ground shadow's
// size), ported line by line in the same order and float width as the GDScript
// (src/presentation/world_view/lens_drone_avatar.gd): its numbers are doubles, its raw drives floats (its
// PackedFloat32Array), its eye's energy a float (a material's). tests/unit/native/test_native_crowd_lens.gd holds the
// rows equal to the GDScript avatar's fields bit for bit.

#include "zd_avatar.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace zd {
namespace av {

namespace {

constexpr double TAU_D = 6.2831853071795864769252867666;
// LensDroneAvatar
constexpr double HOVER_Y = 1.3;
constexpr double BOB_M = 0.07;

// The raw drives (LensDroneAvatar's RX, RZ, SPIN).
enum Drive {
	RX = 0,
	RZ = 1,
	SPIN = 2,
	DRIVES = 3,
};

// VAT_DRIVES: [lo, hi, loop].
struct Spec {
	double lo, hi;
	bool loop;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.08, 0.08, false }, // RX
	{ -0.12, 0.07, false }, // RZ
	{ 0.0, TAU_D, true }, // SPIN
};

inline double dsin(double x) {
	return UtilityFunctions::sin(x);
}
inline double lerpd(double from, double to, double w) {
	return from + (to - from) * w;
}
inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline float f32(double v) {
	return float(v);
}

// _pose: the numbers (the hover, the drives, the eye, the shadow's size); the nodes are VatCrowd's.
void pose(double *s) {
	const double t = s[T];
	const double bob = dsin(t * TAU_D * 0.8) * BOB_M;
	const double rise = s[LD_RISE];
	const double charge = s[LD_CHARGE];
	s[LD_LIFT] = lerpd(0.4, HOVER_Y, rise) + bob;
	s[LD_VD + RX] = f32(dsin(t * 1.5) * 0.08);
	s[LD_VD + RZ] = f32(dsin(t * 1.9) * 0.06 - 0.05 * charge);
	s[LD_VD + SPIN] = f32(Math::fposmod(t * (s[LD_HAS_MODEL] != 0.0 ? 2.5 + 6.0 * charge : 2.5), TAU_D));
	s[LD_EYE] = f32(1.8 + 3.5 * charge);
	s[LD_SHADOW] = lerpd(0.6, 1.0, rise) * (1.0 - bob);
}

} // namespace

void ld_apply(double *s, int state, const Ctx &c) {
	s[LD_STATE] = state;
	if (s[FRESH] != 0.0) {
		s[FRESH] = 0.0;
		s[LD_RISE] = state == c.st.spawn ? 0.0 : 1.0;
		pose(s);
	}
}

void ld_advance(double *s, double delta, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const int state = int(s[LD_STATE]);
	const bool spawning = state == c.st.spawn;
	s[LD_RISE] = Math::move_toward(s[LD_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 2.0));
	const bool aiming = state == c.st.windup || state == c.st.active;
	s[LD_CHARGE] = Math::move_toward(s[LD_CHARGE], aiming ? 1.0 : 0.0, dt * (aiming ? 4.0 : 2.0));
	pose(s);
}

int ld_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[LD_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		const double span = VAT_DRIVES[i].hi - lo;
		if (Math::is_zero_approx(span)) {
			out[i] = f32(v);
			continue;
		}
		const double u = (v - lo) / span;
		out[i] = f32(VAT_DRIVES[i].loop ? u - Math::floor(u) : u);
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
