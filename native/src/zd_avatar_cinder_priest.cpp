// The Cinder Priest's avatar on a batch row (zd_avatar.h CP_*): CinderPriestAvatar's sync (apply_state), frame step
// (advance) and pose (_pose, _idle, _glide_pose, _death, _add), ported line by line in the same order and float width
// as the GDScript (src/presentation/world_view/cinder_priest_avatar.gd): its clocks, lift and glows are doubles
// (GDScript floats), the raw drives floats (its PackedFloat32Array: each `d[j] += x` reads the float, adds in double
// and stores a float), the glide's direction a float Vector2 and the velocity's turn into the facing's frame a float
// Basis. Its sync's vent numbers (the pulse, the eruption's age, the vent's direction, the facing's yaw) are worked out
// in GDScript (BatchCinderPriest.note) and come in as MORE. tests/unit/native/test_native_crowd_cinder_priest.gd holds
// the drawn buffers equal to the GDScript avatar's bit for bit.

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
constexpr int MOTION_GAP_TICKS = 30;
// CinderPriestAvatar
constexpr double DEATH_SECONDS = 0.9;
constexpr double SPAWN_SECONDS = 0.6;
constexpr double SLAM_FROM = 0.9;
constexpr double SLAM_HOLD_S = 0.1;
constexpr double RECOIL_HZ = 1.5;
constexpr double RECOIL_DECAY = 5.5;
constexpr double STRIKE_END_S = 1.4;
constexpr double CRYSTAL_REST = 2.2;
constexpr double CRYSTAL_GATHER = 6.0;
constexpr double CRYSTAL_FLARE = 12.0;
constexpr double FLARE_DECAY = 6.0;
constexpr double VISOR_REST = 1.6;
constexpr double CHANT_HZ = 0.45;
constexpr double CIRCLE_HZ = 0.55;
constexpr double GLIDE_HZ = 1.4;
constexpr double GLIDE_MPS = 2.4;
constexpr double TURN_MAX = 1.1;
constexpr double CALM = 0.35;
constexpr double GATHER_LIFT = 0.09;
constexpr double SLAM_LIFT = -0.05;
constexpr double TELEPORT_SPEED = 30.0;

// The raw drives (CinderPriestAvatar's YAW ... VISOR).
enum Drive {
	YAW = 0,
	LEAN_F = 1,
	LEAN_S = 2,
	CRUMPLE = 3,
	HEM_F = 4,
	HEM_S = 5,
	TORSO_F = 6,
	TORSO_S = 7,
	HOOD_F = 8,
	HOOD_S = 9,
	ARM_L_F = 10,
	ARM_L_S = 11,
	ARM_R_F = 12,
	ARM_R_S = 13,
	STAFF_DROP = 14,
	STAFF_F = 15,
	STAFF_S = 16,
	VISOR = 17,
	DRIVES = 18,
};

// VAT_DRIVES: [lo, hi] (none loops).
struct Spec {
	double lo, hi;
};
const Spec VAT_DRIVES[DRIVES] = {
	{ -1.2, 1.2 }, // YAW
	{ -0.4, 0.4 }, // LEAN_F
	{ -0.3, 0.3 }, // LEAN_S
	{ 0.0, 1.0 }, // CRUMPLE
	{ -0.45, 0.45 }, // HEM_F
	{ -0.35, 0.35 }, // HEM_S
	{ -0.6, 1.0 }, // TORSO_F
	{ -0.3, 0.3 }, // TORSO_S
	{ -1.0, 1.0 }, // HOOD_F
	{ -0.4, 0.4 }, // HOOD_S
	{ -0.8, 1.4 }, // ARM_L_F
	{ -0.4, 1.1 }, // ARM_L_S
	{ -0.8, 1.6 }, // ARM_R_F
	{ -0.6, 0.6 }, // ARM_R_S
	{ -0.3, 0.8 }, // STAFF_DROP
	{ -0.6, 1.8 }, // STAFF_F
	{ -0.5, 1.6 }, // STAFF_S
	{ 0.0, 0.0 }, // VISOR
};

// The cycle's poses at full weight: {drive, value}.
struct Pair {
	int d;
	double v;
};
const Pair GATHER_POSE[] = {
	{ ARM_R_F, 1.12 },
	{ ARM_R_S, 0.14 },
	{ STAFF_F, 1.24 },
	{ STAFF_DROP, -0.16 },
	{ TORSO_F, -0.2 },
	{ HOOD_F, -0.42 },
	{ LEAN_F, -0.06 },
	{ HEM_F, 0.06 },
	{ ARM_L_F, 0.62 },
	{ ARM_L_S, 0.42 },
};
const Pair SLAM_POSE[] = {
	{ ARM_R_F, 0.36 },
	{ ARM_R_S, -0.06 },
	{ STAFF_F, 1.0 },
	{ STAFF_DROP, 0.06 },
	{ TORSO_F, 0.48 },
	{ HOOD_F, 0.42 },
	{ LEAN_F, 0.13 },
	{ HEM_F, -0.14 },
	{ ARM_L_F, -0.42 },
	{ ARM_L_S, 0.62 },
};
const Pair FLINCH_POSE[] = {
	{ HOOD_F, -0.8 },
	{ TORSO_F, -0.3 },
	{ HEM_F, 0.1 },
	{ ARM_L_F, -0.35 },
	{ ARM_L_S, 0.6 },
	{ ARM_R_F, 0.2 },
	{ STAFF_F, -0.2 },
	{ STAFF_S, -0.15 },
};

// GDScript's utility functions on doubles (zd_avatar.cpp's reason for the engine's sin, cos and exp).
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

// `d[j] += x` and `d[j] -= x` on the PackedFloat32Array.
inline void add(float *d, int j, double x) {
	d[j] = f32(double(d[j]) + x);
}
inline void sub(float *d, int j, double x) {
	d[j] = f32(double(d[j]) - x);
}

// CinderPriestAvatar._add: a pose at weight w.
template <int N>
void add_pose(float *d, const Pair (&pose)[N], double w) {
	if (Math::is_zero_approx(w)) {
		return;
	}
	for (int q = 0; q < N; q++) {
		add(d, pose[q].d, pose[q].v * w);
	}
}

double flinch_amount(const double *s) {
	return envelope(s[FLINCH_T] / FLINCH_SECONDS) * s[FLINCH_S];
}

// The pose's running numbers (CinderPriestAvatar's _lift and _crystal while _pose works them out).
struct Glow {
	double lift;
	double crystal;
};

// CinderPriestAvatar._idle
void idle(const double *s, float *d, Glow &g, double sw, double a, double held) {
	const double t = s[T];
	const double ph = t * TAU_D * CHANT_HZ;
	const double slow = t * TAU_D * 0.21;
	const double c = t * TAU_D * CIRCLE_HZ;
	g.lift += 0.03 * sw * sin_d(ph);
	add(d, LEAN_F, 0.02 * sw * sin_d(ph + 0.5));
	add(d, LEAN_S, 0.035 * sw * sin_d(slow));
	sub(d, HEM_F, 0.03 * sw * sin_d(ph - 0.8));
	sub(d, HEM_S, 0.035 * sw * sin_d(slow - 0.9));
	add(d, TORSO_F, 0.1 * held + 0.035 * sw * sin_d(ph + 1.0));
	add(d, TORSO_S, 0.02 * sw * sin_d(slow + 0.6));
	add(d, HOOD_F, 0.22 * held + 0.05 * sw * sin_d(ph + 1.7));
	add(d, HOOD_S, 0.05 * sw * sin_d(t * TAU_D * 0.17));
	add(d, ARM_L_F, 0.36 * held + 0.15 * a * held * sin_d(c));
	add(d, ARM_L_S, 0.16 * held + 0.12 * a * held * cos_d(c));
	add(d, ARM_R_F, 0.03 * sw * sin_d(ph + 0.3));
	add(d, STAFF_F, 0.03 * sw * sin_d(ph + 0.3));
	g.crystal *= 1.0 + 0.2 * a * sin_d(ph * 1.3);
}

// CinderPriestAvatar._glide_pose
void glide_pose(const double *s, float *d, Glow &g, double sw, bool calm) {
	const double k = s[CP_GLIDE] * (calm ? 0.6 : 1.0) * (sw > 0.0 ? 1.0 : 0.0);
	if (k <= 0.0) {
		return;
	}
	const double dx = double(f32(s[CP_DIR]));
	const double dy = double(f32(s[CP_DIR + 1]));
	const double ph = s[T] * TAU_D * GLIDE_HZ;
	const double flutter = calm ? 0.0 : 1.0;
	g.lift += 0.035 * k * sw * (0.5 + 0.5 * sin_d(ph));
	add(d, LEAN_F, 0.16 * k * dx);
	add(d, LEAN_S, 0.12 * k * dy);
	add(d, HEM_F, -0.24 * k * dx + 0.05 * k * flutter * sin_d(ph - 0.7));
	add(d, HEM_S, -0.18 * k * dy + 0.04 * k * flutter * sin_d(ph * 0.5 + 1.1));
	add(d, TORSO_F, -0.05 * k * dx);
	add(d, HOOD_F, -0.1 * k * dx + 0.04 * k * flutter * sin_d(ph - 1.4));
	add(d, ARM_L_F, -0.3 * k * dx);
	add(d, ARM_L_S, 0.12 * k);
	add(d, ARM_R_F, 0.16 * k * dx + 0.06 * k * flutter * sin_d(ph));
	add(d, STAFF_F, 0.06 * k * dx - 0.06 * k * flutter * sin_d(ph));
}

// CinderPriestAvatar._death
void death(float *d, Glow &g, double u, double fold, bool calm) {
	const double jolt = sin_d(PI_D * clampd(u / 0.22, 0.0, 1.0)) * (calm ? 0.5 : 1.0);
	double fall = sstep(0.06, 0.62, u);
	fall *= fall;
	add(d, HOOD_F, -0.55 * jolt + 0.7 * fold);
	add(d, TORSO_F, -0.2 * jolt + 0.72 * fold);
	add(d, ARM_R_F, 0.4 * jolt - 0.45 * fold);
	add(d, ARM_L_S, 0.45 * jolt - 0.1 * fold);
	add(d, ARM_L_F, -0.25 * fold);
	add(d, LEAN_F, 0.04 * fold);
	add(d, CRUMPLE, 0.88 * fold);
	add(d, STAFF_DROP, 0.34 * fall);
	sub(d, STAFF_F, 0.6 * fall);
	add(d, STAFF_S, 1.45 * fall);
	g.crystal += 5.0 * jolt;
}

// CinderPriestAvatar._pose on a VAT avatar (no nodes): the drives, the lift and the crystal's glow.
void cp_pose(double *s, const Ctx &cx) {
	const bool calm = cx.calm;
	const double a = calm ? CALM : 1.0;
	float d[DRIVES] = {};
	const double t = s[T];
	const double die_t = s[CP_DIE];
	const double rise = s[CP_RISE];
	const double erupt_s = s[CP_ERUPT];
	const bool dead = die_t >= 0.0;
	const double die_u = dead ? clampd(die_t / DEATH_SECONDS, 0.0, 1.0) : 0.0;
	const double fold = dead ? sstep(0.12, 0.8, die_u) : 0.0;
	Glow g = { 0.0, CRYSTAL_REST };
	double visor = VISOR_REST;
	// The cycle's weights: the raise through the warning (eased, a small dip first), the slam over its last part to
	// the eruption tick, then held and the recoil after it.
	const double p = s[CP_PULSE];
	double slam = 0.0;
	if (p > SLAM_FROM) {
		const double u = (p - SLAM_FROM) / (1.0 - SLAM_FROM);
		slam = u * u;
	}
	const double gather = sstep(0.0, 1.0, p) * (1.0 - slam);
	const double dip = p > 0.0 && p < 0.2 ? 0.18 * sin_d(PI_D * clampd(p / 0.2, 0.0, 1.0)) : 0.0;
	if (erupt_s >= 0.0) {
		const double e = erupt_s;
		if (e < SLAM_HOLD_S) {
			slam = 1.0;
		} else {
			const double x = e - SLAM_HOLD_S;
			slam = exp_d(-x * RECOIL_DECAY) * (calm ? 1.0 : cos_d(x * TAU_D * RECOIL_HZ));
		}
		g.crystal += CRYSTAL_FLARE * (calm ? 0.6 : 1.0) * exp_d(-e * FLARE_DECAY);
	}
	const double busy = clampd(maxd(gather, std::fabs(slam)), 0.0, 1.0);
	const double still = (1.0 - 0.75 * busy) * (1.0 - fold) * rise;
	idle(s, d, g, a * still, a, still);
	glide_pose(s, d, g, a * (1.0 - fold), calm);
	add_pose(d, GATHER_POSE, gather);
	g.lift += GATHER_LIFT * gather;
	sub(d, ARM_R_F, dip);
	add(d, STAFF_DROP, dip * 0.2);
	g.crystal += CRYSTAL_GATHER * gather;
	visor += 1.2 * gather;
	if (gather > 0.0 && p > 0.8 && !calm) { // the staff trembles at the top of the raise
		const double shake = 0.025 * sin_d(t * TAU_D * 11.0) * (p - 0.8) / 0.2;
		add(d, STAFF_S, shake);
		add(d, ARM_R_F, shake * 0.6);
		g.crystal += 1.2 * sin_d(t * TAU_D * 9.0);
	}
	add_pose(d, SLAM_POSE, slam);
	g.lift += SLAM_LIFT * slam;
	g.crystal += CRYSTAL_GATHER * maxd(slam, 0.0) * (erupt_s < 0.0 ? 1.0 : 0.0);
	d[YAW] = f32(s[CP_YAW] * s[CP_TURN] * (1.0 - fold));
	add_pose(d, FLINCH_POSE, flinch_amount(s));
	if (rise < 1.0) { // the rise-in: up out of its robe
		const double r = 1.0 - rise;
		add(d, CRUMPLE, 0.9 * r);
		add(d, TORSO_F, 0.55 * r);
		add(d, HOOD_F, 0.5 * r);
		g.crystal *= rise;
		visor *= rise;
	}
	if (dead) {
		death(d, g, die_u, fold, calm);
		g.crystal *= 1.0 - sstep(0.15, 0.75, die_u);
		visor *= 1.0 - sstep(0.1, 0.6, die_u);
	}
	for (int j = 0; j < DRIVES; j++) {
		if (VAT_DRIVES[j].hi > VAT_DRIVES[j].lo) {
			d[j] = f32(clampd(double(d[j]), VAT_DRIVES[j].lo, VAT_DRIVES[j].hi));
		}
	}
	d[VISOR] = f32(visor);
	for (int j = 0; j < DRIVES; j++) {
		s[CP_VD + j] = d[j];
	}
	s[CP_LIFT] = g.lift;
	s[CP_CRYSTAL] = maxd(g.crystal, 0.0);
}

} // namespace

// CinderPriestAvatar.apply_state from a sync (`more`: the vent's pulse 0..1000, the ticks since its eruption or -1,
// the vent's direction in the facing's frame or NAN, the facing's yaw).
void cp_apply(double *s, int64_t tick, int state, float pos_x, float pos_y, const double *more, const Ctx &c) {
	s[CP_STATE] = state;
	s[CP_PULSE] = clampd(more[0] / 1000.0, 0.0, 1.0);
	const int64_t age = int64_t(more[1]);
	s[CP_ERUPT] = age >= 0 && double(age) / 60.0 < STRIKE_END_S ? double(age) / 60.0 : -1.0;
	s[CP_VENT_YAW] = more[2];
	s[CP_FACING] = more[3];
	// _track_motion(tick, pos, 30.0)
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
	if (fresh) {
		s[FRESH] = 0.0;
		s[CP_RISE] = state == c.st.spawn ? 0.0 : 1.0;
		cp_pose(s, c);
	}
}

// CinderPriestAvatar.advance
void cp_advance(double *s, double delta, const Ctx &c) {
	const double dt = clampd(delta, 0.0, 0.05);
	if (dt <= 0.0) {
		return;
	}
	s[T] += dt;
	const bool spawning = int(s[CP_STATE]) == c.st.spawn;
	s[CP_RISE] = toward(s[CP_RISE], spawning ? 0.0 : 1.0, dt / SPAWN_SECONDS);
	if (s[CP_ERUPT] >= 0.0) {
		s[CP_ERUPT] += dt;
		if (s[CP_ERUPT] >= STRIKE_END_S) {
			s[CP_ERUPT] = -1.0;
		}
	}
	if (s[CP_DIE] >= 0.0) {
		s[CP_DIE] += dt;
	}
	// The glide: the sim's velocity in the facing's frame (x forward, y right).
	const Vector3 v3 =
			axis_angle(Vector3(0, 1, 0), f32(-s[CP_FACING])).xform(Vector3(f32(s[VEL_X]), 0.0f, -f32(s[VEL_Y])));
	const Vector2 local(v3.x, v3.z);
	const double speed = double(local.length());
	s[CP_GLIDE] = lerpd(s[CP_GLIDE], clampd(speed / GLIDE_MPS, 0.0, 1.0), ease_rate(6.0, dt));
	if (speed > 0.05) {
		const Vector2 dir(f32(s[CP_DIR]), f32(s[CP_DIR + 1]));
		const Vector2 now = dir.lerp(local / f32(speed), f32(ease_rate(8.0, dt))).normalized();
		s[CP_DIR] = now.x;
		s[CP_DIR + 1] = now.y;
	}
	// The turn to the vent: through its warning and the strike, back after.
	const double vent_yaw = s[CP_VENT_YAW];
	const bool has_vent = !std::isnan(vent_yaw);
	const double erupt_s = s[CP_ERUPT];
	const bool engaged = has_vent && (s[CP_PULSE] > 0.0 || (erupt_s >= 0.0 && erupt_s < 0.7));
	s[CP_TURN] = toward(s[CP_TURN], engaged ? 1.0 : 0.0, dt * (engaged ? 4.0 : 1.5));
	if (has_vent) {
		s[CP_YAW] = lerpd(s[CP_YAW], clampd(vent_yaw, -TURN_MAX, TURN_MAX), ease_rate(8.0, dt));
	}
	cp_pose(s, c);
}

// CinderPriestAvatar.vat_drives: SoloVat.normalized(_vd, VAT_DRIVES) (the visor's as it is).
int cp_drives(const double *s, float *out) {
	for (int i = 0; i < DRIVES; i++) {
		const double v = double(f32(s[CP_VD + i]));
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
