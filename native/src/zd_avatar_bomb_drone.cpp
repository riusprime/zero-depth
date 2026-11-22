// The Bomb Drone's avatar on a batch row (zd_avatar.h BD_*): BombDroneAvatar's sync (apply_state), frame step
// (advance, _turning) and pose (_pose, _glide_pose, _lob_pose, _hurt_pose, _death_pose), ported line by line in the
// same order and float width as the GDScript (src/presentation/world_view/bomb_drone_avatar.gd): its clocks, spins and
// glows are doubles (GDScript floats), its raw drives floats (its PackedFloat32Array: each `d[j] += x` reads the float,
// adds in double and stores a float), the glide's direction and the velocity's turn into the facing's frame float
// vectors, the visor's glow and the ground disc's scale floats (what its material and its node store). Its fuse's
// glow is not reckoned: on the VAT crowd the bomb is drawn by the crowd, and the fuse's material belongs to no node.
// tests/unit/native/test_native_crowd_bomb_drone.gd holds the drawn buffers and the ground disc equal to the GDScript
// avatar's bit for bit.

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
constexpr int MOTION_GAP_TICKS = 30;
// BombDroneAvatar
constexpr double TELEPORT_SPEED = 12.0;
constexpr double HOVER_Y = 1.8;
constexpr double BOB_M = 0.08;
constexpr double BOB_HZ = 0.9;
constexpr double LIFT = HOVER_Y - 0.35;
constexpr double LIFT_GROUND = 0.22;
constexpr double LIFT_DEAD = 0.08;
constexpr double VISOR_REST = 1.6;
constexpr double VISOR_TELL = 2.5;
constexpr double SPIN = 34.0;
constexpr double SPIN_TELL = 0.5;
constexpr double GLIDE_MPS = 2.6;
constexpr double TURN_REF = 3.0;
constexpr double CALM = 0.4;
constexpr double LOB_S = 0.5;
constexpr double HURT_SECONDS = 0.8;
constexpr double DEATH_SECONDS = 1.2;
constexpr int ARMS = 4;
// Each arm's side (ARMS: ur, ul, dr, dl; "r" the drone's right, +1).
constexpr double SIDE[ARMS] = { 1.0, -1.0, 1.0, -1.0 };

// The raw drives (BombDroneAvatar's ROLL ... VISOR).
enum Drive {
	ROLL = 0,
	PITCH = 1,
	YAW = 2,
	DROOP0 = 3,
	BREAK = 7,
	ROTOR = 8,
	CLAW = 9,
	BOMB_S = 10,
	VISOR = 11,
	DRIVES = 12,
};

// VAT_DRIVES: [lo, hi, loop] (the rotors' turn loops; the visor's [0, 0] is sent as it is).
struct Spec {
	double lo, hi;
	bool loop;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -0.9, 0.9, false }, // ROLL
	{ -0.7, 0.9, false }, // PITCH
	{ -0.6, 0.6, false }, // YAW
	{ -0.8, 1.4, false }, // DROOP ur
	{ -0.8, 1.4, false }, // DROOP ul
	{ -0.8, 1.4, false }, // DROOP dr
	{ -0.8, 1.4, false }, // DROOP dl
	{ 0.0, 1.0, false }, // BREAK
	{ 0.0, TAU_D, true }, // ROTOR
	{ 0.0, 1.0, false }, // CLAW
	{ 0.0, 1.0, false }, // BOMB_S
	{ 0.0, 0.0, false }, // VISOR
};

const Vector3 UP(0, 1, 0);

// GDScript's utility functions on doubles.
inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}
inline double maxd(double a, double b) {
	return a > b ? a : b;
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

// `d[j] += x` on the PackedFloat32Array (`-= x` is the same sum with -x: IEEE subtraction is that addition).
inline void add(float *d, int j, double x) {
	d[j] = f32(double(d[j]) + x);
}

// BombDroneAvatar.bomb_armed
inline bool armed(const double *s) {
	return s[BD_ARMED] > 0.05;
}

// BombDroneAvatar._glide_pose
void glide_pose(const double *s, float *d, double sc) {
	const double g = s[BD_GLIDE] * sc;
	add(d, PITCH, 0.28 * g * double(f32(s[BD_DIR])));
	add(d, ROLL, 0.25 * g * double(f32(s[BD_DIR + 1])));
	const double w = clampd(s[BD_OMEGA] / TURN_REF, -1.0, 1.0) * sc;
	add(d, ROLL, -(0.3 * w));
	add(d, YAW, -(0.25 * w));
	for (int a = 0; a < ARMS; a++) {
		add(d, DROOP0 + a, 0.1 * w * SIDE[a]);
	}
}

// BombDroneAvatar._lob_pose: returns the lift's change.
double lob_pose(const double *s, float *d, bool calm) {
	const double lob = s[BD_LOB];
	if (lob < 0.0) {
		return 0.0;
	}
	const double u = lob / LOB_S;
	const double snap = sin_d(PI_D * clampd(u / 0.4, 0.0, 1.0));
	const double kick = sin_d(PI_D * clampd((u - 0.25) / 0.75, 0.0, 1.0));
	const double k = calm ? 0.5 : 1.0;
	add(d, PITCH, (0.45 * snap - 0.2 * kick) * k);
	for (int a = 0; a < ARMS; a++) {
		add(d, DROOP0 + a, -(0.15 * snap * k));
	}
	return 0.12 * kick * k;
}

// BombDroneAvatar._hurt_pose: returns the lift's change.
double hurt_pose(const double *s, float *d, double sc, bool calm) {
	const double ht = s[BD_HURT_T];
	if (ht < 0.0) {
		return 0.0;
	}
	const double u = ht / HURT_SECONDS;
	double env = (1.0 - sstep(0.0, 1.0, u)) * sstep(0.0, 0.05, u);
	double swing = cos_d(TAU_D * 2.0 * ht);
	if (calm) {
		swing = 1.0;
		env = sin_d(PI_D * clampd(u / 0.7, 0.0, 1.0));
	}
	add(d, ROLL, 0.3 * s[BD_HURT_SIDE] * env * swing * sc);
	add(d, PITCH, -(0.15 * env * swing * sc));
	for (int a = 0; a < ARMS; a++) {
		add(d, DROOP0 + a, 0.3 * env * swing * sc);
	}
	return -0.12 * env * (0.5 + 0.5 * swing);
}

// BombDroneAvatar._death_pose: returns the lift.
double death_pose(const double *s, float *d, double u, double fall, double lift) {
	const double side = s[BD_HURT_SIDE];
	const double jolt = sin_d(PI_D * clampd(u / 0.15, 0.0, 1.0));
	add(d, ROLL, (0.2 * jolt + 0.3 * fall) * side);
	add(d, PITCH, -0.25 * jolt + 0.2 * fall);
	const double brk = sstep(0.5, 0.85, u);
	d[BREAK] = f32(brk);
	for (int a = 0; a < ARMS; a++) {
		const bool low = SIDE[a] == side;
		const double drop = a < 2 ? (low ? 0.9 : 1.4) : (low ? -0.4 : 0.35);
		add(d, DROOP0 + a, 0.3 * jolt + drop * brk);
	}
	d[CLAW] = f32(maxd(double(d[CLAW]), sstep(0.45, 0.7, u)));
	return lerpd(lift, LIFT_DEAD, fall * fall);
}

// BombDroneAvatar._pose on a VAT avatar (no nodes): the drives, the lift, the visor's glow and the ground disc's
// scale.
void bd_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double k = calm ? CALM : 1.0;
	float d[DRIVES] = {};
	const double t = s[T];
	const double die_t = s[BD_DIE];
	const bool dead = die_t >= 0.0;
	const double die_u = dead ? clampd(die_t / DEATH_SECONDS, 0.0, 1.0) : 0.0;
	const double fall = dead ? sstep(0.1, 0.6, die_u) : 0.0;
	const double aloft = 1.0 - fall;
	const double bob = (calm ? 0.0 : sin_d(t * TAU_D * BOB_HZ) * BOB_M) * aloft;
	const double rise = s[BD_RISE];
	double lift = lerpd(LIFT_GROUND, LIFT, rise) + bob;
	// The hover: a soft rock, the arms and claws quivering.
	add(d, ROLL, 0.06 * k * aloft * sin_d(t * 1.3));
	add(d, PITCH, 0.05 * k * aloft * sin_d(t * 1.7));
	for (int a = 0; a < ARMS; a++) {
		add(d, DROOP0 + a, 0.04 * k * aloft * sin_d(t * 2.3 + 1.6 * double(a)));
	}
	add(d, CLAW, 0.06 * k * aloft * (0.5 + 0.5 * sin_d(t * 1.1)));
	glide_pose(s, d, k * aloft);
	lift += lob_pose(s, d, calm);
	lift += hurt_pose(s, d, k, calm);
	// The rise-in: the arms unfold from tucked as it lifts off.
	const double fold = (1.0 - rise) * (1.0 - rise) * (dead ? 0.0 : 1.0);
	for (int a = 0; a < ARMS; a++) {
		add(d, DROOP0 + a, fold * (a < 2 ? 0.6 : -0.5));
	}
	add(d, CLAW, 1.0 - s[BD_ARMED]);
	d[BOMB_S] = f32(armed(s) ? maxd(s[BD_ARMED], 0.05) : 0.0);
	const double aim = s[BD_AIM];
	double visor = VISOR_REST + VISOR_TELL * aim;
	if (aim > 0.0 && !calm) { // the gem flickers as the circle fills
		visor += 0.6 * aim * sin_d(t * TAU_D * 7.0);
	}
	visor *= lerpd(0.4, 1.0, rise);
	if (dead) {
		lift = death_pose(s, d, die_u, fall, lift);
		const double flare = sin_d(PI_D * clampd(die_u / 0.2, 0.0, 1.0));
		visor = (visor + 2.0 * flare) * (1.0 - sstep(0.35, 0.8, die_u));
	}
	for (int j = 0; j < DRIVES; j++) {
		if (!VAT_DRIVES[j].loop && VAT_DRIVES[j].hi > VAT_DRIVES[j].lo) {
			d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
		}
	}
	d[ROTOR] = f32(s[BD_ROT]);
	d[VISOR] = f32(visor);
	for (int j = 0; j < DRIVES; j++) {
		s[BD_VD + j] = d[j];
	}
	s[BD_LIFT] = lift;
	s[BD_VISOR] = f32(visor);
	const double sh = lerpd(0.6, 1.0, rise) * (1.0 - bob * 0.8);
	s[BD_SHADOW] = f32(sh);
}

} // namespace

// BombDroneAvatar.apply_state from a sync (`more`: its HP first).
void bd_apply(double *s, int64_t tick, int state, float pos_x, float pos_y, const double *more, const Ctx &c) {
	const int was = int(s[BD_STATE]);
	const bool fresh = s[FRESH] != 0.0;
	s[BD_STATE] = state;
	const int64_t hp = int64_t(more[0]);
	const int64_t had = int64_t(s[BD_HP]);
	if (!fresh && hp >= 0 && had >= 0 && hp < had) {
		s[BD_HURT_T] = 0.0;
		s[BD_HURT_SIDE] = -s[BD_HURT_SIDE];
	}
	s[BD_HP] = double(hp);
	if (state == c.st.windup && was != c.st.windup && !fresh) {
		s[BD_LOB] = 0.0;
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
	if (fresh) {
		s[FRESH] = 0.0;
		s[BD_RISE] = state == c.st.spawn ? 0.0 : 1.0;
		s[BD_SPIN] = SPIN * (s[BD_RISE] < 1.0 ? 0.3 : 1.0);
		bd_pose(s, c);
	}
}

// BombDroneAvatar.advance (`f`: the facing's yaw, get_parent().rotation.y).
void bd_advance(double *s, double delta, const Frame &f, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool dying = s[BD_DIE] >= 0.0;
	const bool calm = c.calm;
	// _turning
	const double fy = double(f.facing_yaw);
	s[BD_OMEGA] = rig::turning(s[BD_OMEGA], fy, s[BD_LAST_FY], s[BD_HAVE_FY] != 0.0 && !dying, dt, ease_rate(6.0, dt));
	s[BD_LAST_FY] = fy;
	s[BD_HAVE_FY] = 1.0;
	const int state = int(s[BD_STATE]);
	if (dying) {
		s[BD_DIE] += dt;
		s[BD_ARMED] = toward(s[BD_ARMED], 0.0, dt * 6.0);
	} else {
		const bool spawning = state == c.st.spawn;
		s[BD_RISE] = toward(s[BD_RISE], spawning ? 0.0 : 1.0, dt * (spawning ? 6.0 : 1.8));
		// The bomb leaves with the windup (the lob) and a new one is slung back under the belly in the recovery.
		const bool lobbed = state == c.st.windup || state == c.st.active;
		s[BD_ARMED] = toward(s[BD_ARMED], lobbed ? 0.0 : 1.0, dt * (lobbed ? 12.0 : 1.5));
		const bool winding = state == c.st.windup;
		s[BD_AIM] = toward(s[BD_AIM], winding ? 1.0 : 0.0, dt * (winding ? 6.0 : 3.0));
	}
	s[BD_FUSE] = state == c.st.move && !dying ? 1.0 : 0.0;
	s[BD_LOB] = rig::clip(s[BD_LOB], dt, LOB_S);
	s[BD_HURT_T] = rig::clip(s[BD_HURT_T], dt, HURT_SECONDS);
	const double target = dying ? 0.0 : SPIN * (1.0 + SPIN_TELL * s[BD_AIM]) * lerpd(0.3, 1.0, s[BD_RISE]);
	s[BD_SPIN] = lerpd(s[BD_SPIN], target * (calm ? CALM : 1.0), ease_rate(dying ? 2.5 : 4.0, dt));
	s[BD_ROT] = Math::fposmod(s[BD_ROT] + s[BD_SPIN] * dt, TAU_D);
	// Basis(Vector3.UP, -_last_fy) * SimPlane.to_3d(_vel)
	const Vector2 vel(f32(s[VEL_X]), f32(s[VEL_Y]));
	const Vector3 v3 = axis_angle(UP, f32(-s[BD_LAST_FY])).xform(Vector3(vel.x, 0.0f, -vel.y));
	const Vector2 local(v3.x, v3.z);
	const double speed = dying ? 0.0 : double(local.length());
	s[BD_GLIDE] = lerpd(s[BD_GLIDE], clampd(speed / GLIDE_MPS, 0.0, 1.0), ease_rate(5.0, dt));
	if (speed > 0.05) {
		const Vector2 dir(f32(s[BD_DIR]), f32(s[BD_DIR + 1]));
		const Vector2 now = dir.lerp(local / f32(speed), f32(ease_rate(8.0, dt))).normalized();
		s[BD_DIR] = now.x;
		s[BD_DIR + 1] = now.y;
	}
	bd_pose(s, c);
}

// BombDroneAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the rotors' turn looped, the visor's glow sent as
// it is).
int bd_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[BD_VD + i]));
		const double lo = VAT_DRIVES[i].lo;
		const double span = VAT_DRIVES[i].hi - lo;
		if (Math::is_zero_approx(span)) {
			out[i] = f32(v);
			continue;
		}
		const double u = (v - lo) / span;
		out[i] = f32(VAT_DRIVES[i].loop ? u - std::floor(u) : u);
	}
	return DRIVES;
}

} // namespace av
} // namespace zd
