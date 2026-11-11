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
	STRIDE = 80,
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
};

inline bool is_charger(int c) {
	return c == CHARGER || c == HATCHLING;
}

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
// HordeAvatar._apply / ChargerAvatar.apply_state (`pos`: the sim place, the Charger's motion).
void apply(double *s, int cls, int64_t tick, int state, bool healing, double windup, float pos_x, float pos_y,
		const Ctx &c);

// What VatCrowd draws: the accent's glow (glow_energy), the body's offset past the avatar's transform (a horde kind's
// vat_offset, a Charger's lift), and the drives (`out` holds 12: four for a horde kind, ChargerVat.DRIVES for a
// Charger; returns how many). `period`: the set's gait period (VatBake.gait_phase).
double glow_energy(const double *s, int cls);
godot::Transform3D body_offset(const double *s, int cls, const godot::Transform3D &xf);
int drives(const double *s, int cls, double period, const Ctx &c, float *out);

} // namespace av
} // namespace zd
