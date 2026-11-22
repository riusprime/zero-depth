#pragma once
// The batched enemies' avatars (EnemyBatch's slots, src/presentation/world_view/batch_avatars.gd) as plain numbers:
// each slot's state is a row of doubles (the GDScript fields, a float field stored exactly as a double), and the
// functions below are AvatarBase's, HordeAvatar's and ChargerAvatar's frame step, sync and pose for the VAT kinds,
// ported line by line in the same order and float width (a GDScript float is a double; a Vector3/Basis component is
// a float, every operation on them a float one), so the numbers are the GDScript ones. Presentation only: nothing
// here reaches the sim.

#include <cstdint>

#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace zd {
namespace av {

// A slot's row (BatchAvatars' layout; the same numbers there). A transform is 12 values, the MultiMesh order: basis
// row 0 (x.x, y.x, z.x), origin.x, row 1, origin.y, row 2, origin.z.
enum Field {
	// AvatarBase
	T = 0,
	FLINCH_T = 1,
	FLINCH_S = 2,
	FLINCH_DX = 3, // f32 x2
	FLINCH_DY = 4,
	FLINCH_KNOCK = 5,
	HOLD = 6,
	STRIKE_S = 7,
	STRIKE_END = 8,
	FRESH = 9,
	LAST_TICK = 10,
	LAST_PX = 11, // f32 x2
	LAST_PY = 12,
	VEL_X = 13, // f32 x2
	VEL_Y = 14,
	HIT = 15, // f32 x4
	REST_XF = 19, // 12
	XF = 31, // 12: the avatar node's own transform
	// HordeAvatar
	H_GLOW = 43,
	H_MUZZLE = 44,
	H_TELL = 45,
	H_STATE = 46,
	H_STATE_TICK = 47,
	H_TICKS_IN = 48,
	H_HEALING = 49,
	H_RISE = 50,
	H_WIND = 51,
	H_STRIKE = 52,
	H_WALK = 53,
	H_WALK_T = 54,
	H_LAST_AT = 55, // f32 x3
	H_DIE = 58,
	H_LIFT = 59,
	H_BODY = 60, // 12 (f32)
	H_D = 72, // f32 x4
	H_IS_MODEL = 76,
	H_MODEL_SCALE = 77,
	H_HEIGHT = 78,
	H_WALK_Z = 79, // the Mine Layer's stride along +Z (MineLayerModel; its H_WALK is along +X)
	// ChargerAvatar (its own fields from 43)
	C_VISOR = 43,
	C_TELL = 44,
	C_STATE = 45,
	C_SPEED = 46,
	C_WALK = 47,
	C_PHASE = 48,
	C_WIND = 49,
	C_LUNGE = 50,
	C_DAZE = 51,
	C_RISE = 52,
	C_RISE_NOW = 53,
	C_LUNGE_NOW = 54,
	C_CROUCH_NOW = 55,
	C_Y_NOW = 56,
	C_LIFT = 57,
	C_DIE = 58, // the Hatchling's death (s in; -1 alive)
	// StoneThrowerAvatar (its own fields from 43; zd_avatar_thrower.cpp)
	S_VISOR = 43, // f32: the visor material's emission energy
	S_STATE = 44,
	S_STATE_TICKS = 45,
	S_TICKS = 46, // int x3: the lift, the flight, the recovery
	S_ATK = 49,
	S_ATK_SIM = 50,
	S_WALK = 51,
	S_PHASE = 52,
	S_SPEED = 53,
	S_FWD = 54, // f32 x2
	S_RISE = 56,
	S_PUFF = 57,
	S_DIE = 58,
	S_DROP = 59,
	S_DROP_FROM = 60, // f32 x3
	S_ROCK_SHOWN = 63,
	S_LIFT = 64,
	S_SCALE = 65, // the model's scale (set once)
	S_OFF = 66, // f32 x3 x6: the joints' offsets (pelvis, neck, shoulder, elbow, wrist, hip; set once)
	S_VD = 84, // f32 x29: the raw drives
	// WardenAvatar (its own fields from 43; zd_avatar_warden.cpp)
	W_CRACK = 43, // the cracks' glow (_crack)
	W_STATE = 44,
	W_STATE_TICKS = 45,
	W_WINDUP = 46,
	W_HP = 47,
	W_SPEED = 48,
	W_DIR = 49, // f32 x2
	W_OMEGA = 51,
	W_PHASE = 52,
	W_STRIDE = 53,
	W_RAISE = 54,
	W_SLAM = 55,
	W_RISE = 56,
	W_SHAKE = 57,
	W_HURT = 58,
	W_DIE = 59,
	W_LAST_FY = 60,
	W_HAVE_FY = 61,
	W_SLAM_R = 62,
	W_DUST_T = 63,
	W_LIFT = 64,
	W_SCALE = 65, // the model's scale (set once)
	W_PIV = 66, // f32 x3 x11: the joints' pivots (BatchWardenRow.PIVOT_KEYS order; set once)
	W_VD = 99, // f32 x23: the raw drives
	STRIDE = 122,
};

// A slot's class (BatchAvatars.CLASS_OF): which avatar code runs it (0: none native, its avatar steps in GDScript).
enum Class {
	NONE = 0,
	SWARMER = 1,
	SPLITTER = 2,
	SPLITLING = 3,
	SHIELD_BEARER = 4,
	MENDER = 5,
	MINE_LAYER = 6,
	SNIPER = 7,
	CHARGER = 8,
	HATCHLING = 9,
	STONE_THROWER = 10,
	WARDEN = 12,
};

inline bool is_charger(int c) {
	return c == CHARGER || c == HATCHLING;
}

// The most drives a class gives VatCrowd (the Stone Thrower's 29).
constexpr int MAX_DRIVES = 29;

// A Stone Thrower's sync inputs past the common ones (BatchAvatars.MORE a slot): its ticks into the state, its facing
// (Kin.dir: x, y) and the sim's lift, flight and recovery ticks.
constexpr int MORE = 6;

// A Warden's MORE inputs: its HP, the telegraph's slam radius and whether the telegraph gave one (1) or not (0).

// The sim states (WorldReader.STATE_*), handed in by the batch.
struct States {
	int spawn = 0, move = 1, windup = 2, active = 3, recover = 4;
};

// What a slot's frame step and sync read besides its own row.
struct Ctx {
	States st;
	bool calm = false; // ViewPrefs.reduced_motion
};

// The root's place and the facing's turn, for the walk's pace (_view_position) and the flinch's yaw.
struct Frame {
	godot::Vector3 root; // the root's position (its basis is the identity)
	godot::Transform3D facing; // the facing node's transform
	float facing_yaw = 0.0f; // its rotation.y
};

// The engine's float sine and cosine, as its Basis reckons them (see zd_avatar.cpp), and the two Basis builders the
// avatars use on them: Basis(axis, angle) and Basis.from_euler (YXZ), the engine's code with those two functions.
float fsin(float x);
float fcos(float x);
godot::Basis axis_angle(const godot::Vector3 &axis, float angle);
godot::Basis euler_yxz(const godot::Vector3 &euler);

godot::Transform3D get_xf(const double *s, int at);
void put_xf(double *s, int at, const godot::Transform3D &xf);

// AvatarBase._process (consume_hold, advance, advance_flinch) for a native class.
void process(double *s, int cls, double delta, const Frame &f, const Ctx &c);
// HordeAvatar.advance / ChargerAvatar.advance.
void advance(double *s, int cls, double delta, const Frame &f, const Ctx &c);
// HordeAvatar._apply / ChargerAvatar.apply_state / StoneThrowerAvatar.apply_state (`pos`: the sim place, the
// Charger's and the Stone Thrower's motion; `more`: the Stone Thrower's MORE inputs).
void apply(double *s, int cls, int64_t tick, int state, bool healing, double windup, float pos_x, float pos_y,
		const double *more, const Ctx &c);

// AvatarBase's helpers the classes share (zd_avatar.cpp): the engine's double sine and cosine, the flinch's envelope,
// the tell's glow, an exponential ease's share.
double sin_d(double x);
double cos_d(double x);
double envelope(double u);
double glow_of_tell(double p, double t, bool calm);
double ease_rate(double per_second, double dt);
// AvatarBase's strike clock and tell (the same functions the Charger's code calls).
void strike_note_of(double *s, int state, const States &st);
void strike_step(double *s, double dt);
double strike_swing_of(const double *s);
bool strike_snapping_of(const double *s);
double strike_raised_of(const double *s, bool winding, double p, double rest);
double crouch_of_tell(double p);
// The engine's double exp, acos and atan2 (GDScript's).
double exp_d(double x);
double acos_d(double x);
double atan2_d(double y, double x);

// The Stone Thrower (zd_avatar_thrower.cpp): its sync, frame step (advance: the pose included) and drives.
void s_apply(double *s, int64_t tick, int state, float pos_x, float pos_y, const double *more, const Ctx &c);
void s_advance(double *s, double delta, const Ctx &c);
int s_drives(const double *s, float *out);

// The Warden (zd_avatar_warden.cpp): its sync, frame step (advance: the pose included; the facing's turn from `f`)
// and drives.
void w_apply(double *s, int64_t tick, int state, double windup, float pos_x, float pos_y, const double *more,
		const Ctx &c);
void w_advance(double *s, double delta, const Frame &f, const Ctx &c);
int w_drives(const double *s, float *out);

// What VatCrowd draws: the accent's glow (glow_energy), the body's offset past the avatar's transform (a horde kind's
// vat_offset, a Charger's or a Stone Thrower's lift), and the drives (`out` holds MAX_DRIVES: four for a horde kind,
// ChargerVat.DRIVES for a Charger, VAT_DRIVES for a Stone Thrower; returns how many). `period`: the set's gait period (VatBake.gait_phase).
double glow_energy(const double *s, int cls);
godot::Transform3D body_offset(const double *s, int cls, const godot::Transform3D &xf);
int drives(const double *s, int cls, double period, const Ctx &c, float *out);

} // namespace av
} // namespace zd
