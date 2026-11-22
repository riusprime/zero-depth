class_name BatchNeedleRow
extends RefCounted
## A Needle's own fields in its batch row (BatchAvatars; native/src/zd_avatar.h N_*, the same numbers): its state,
## clocks, raw drives, glows and its legs' rest joints, from FIRST to BatchAvatars.STRIDE. fields() gives them in row
## order (BatchAvatars copies them in), load() takes them back into the avatar (the gem's and the muzzle's materials
## only when their glow changed). Presentation only (EI-07).

const FIRST := 43
const GEM := 43
const STATE := 44
const STATE_TICK := 45
const SHOTS := 46
const TELL := 47
const HP := 48
const SPEED := 49
const DIR := 50
const OMEGA := 52
const PHASE := 53
const WALK_STRIDE := 54
const BRACE := 55
const CHARGE := 56
const RISE := 57
const SHOT_T := 58
const BURST_T := 59
const HEAT := 60
const VENT_T := 61
const HURT_T := 62
const HURT_LEG := 63
const DIE := 64
const LAST_FY := 65
const HAVE_FY := 66
const LIFT := 67
const VD := 68
const HIPS := 88
const KNEES := 100
const FEET := 112
const END := 124


## The Needle's fields FIRST..END in row order.
static func fields(n: NeedleAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(END - FIRST)
	r[GEM - FIRST] = n._gem_mat.emission_energy_multiplier
	r[STATE - FIRST] = n._state
	r[STATE_TICK - FIRST] = n._state_tick
	r[SHOTS - FIRST] = n._shots
	r[TELL - FIRST] = n._tell
	r[HP - FIRST] = n._hp
	r[SPEED - FIRST] = n._speed
	r[DIR - FIRST] = n._dir.x
	r[DIR + 1 - FIRST] = n._dir.y
	r[OMEGA - FIRST] = n._omega
	r[PHASE - FIRST] = n._phase
	r[WALK_STRIDE - FIRST] = n._stride
	r[BRACE - FIRST] = n._brace
	r[CHARGE - FIRST] = n._charge
	r[RISE - FIRST] = n._rise
	r[SHOT_T - FIRST] = n._shot_t
	r[BURST_T - FIRST] = n._burst_t
	r[HEAT - FIRST] = n._heat
	r[VENT_T - FIRST] = n._vent_t
	r[HURT_T - FIRST] = n._hurt_t
	r[HURT_LEG - FIRST] = n._hurt_leg
	r[DIE - FIRST] = n._die_t
	r[LAST_FY - FIRST] = n._last_fy
	r[HAVE_FY - FIRST] = 1.0 if n._have_fy else 0.0
	r[LIFT - FIRST] = n._lift
	for q in n._vd.size():
		r[VD + q - FIRST] = n._vd[q]
	for j in n._hips.size():
		for c in 3:
			r[HIPS + 3 * j + c - FIRST] = n._hips[j][c]
			r[KNEES + 3 * j + c - FIRST] = n._knees[j][c]
			r[FEET + 3 * j + c - FIRST] = n._feet[j][c]
	return r


## The row's fields FIRST..END (`r`, in row order) into the Needle (its rest joints never change: not read back).
static func load(n: NeedleAvatar, r: PackedFloat64Array) -> void:
	var gem := r[GEM - FIRST]
	if n._gem_mat.emission_energy_multiplier != gem:
		n._gem_mat.emission_energy_multiplier = gem
	n._state = int(r[STATE - FIRST])
	n._state_tick = int(r[STATE_TICK - FIRST])
	n._shots = int(r[SHOTS - FIRST])
	n._tell = r[TELL - FIRST]
	n._hp = int(r[HP - FIRST])
	n._speed = r[SPEED - FIRST]
	n._dir = Vector2(r[DIR - FIRST], r[DIR + 1 - FIRST])
	n._omega = r[OMEGA - FIRST]
	n._phase = r[PHASE - FIRST]
	n._stride = r[WALK_STRIDE - FIRST]
	n._brace = r[BRACE - FIRST]
	n._charge = r[CHARGE - FIRST]
	n._rise = r[RISE - FIRST]
	n._shot_t = r[SHOT_T - FIRST]
	n._burst_t = r[BURST_T - FIRST]
	n._heat = r[HEAT - FIRST]
	n._vent_t = r[VENT_T - FIRST]
	n._hurt_t = r[HURT_T - FIRST]
	n._hurt_leg = int(r[HURT_LEG - FIRST])
	n._die_t = r[DIE - FIRST]
	n._last_fy = r[LAST_FY - FIRST]
	n._have_fy = r[HAVE_FY - FIRST] != 0.0
	n._lift = r[LIFT - FIRST]
	for q in n._vd.size():
		n._vd[q] = r[VD + q - FIRST]
	var muzzle := n._vd[NeedleAvatar.MUZZLE]
	if n._hole_mat.emission_energy_multiplier != muzzle:
		n._hole_mat.emission_energy_multiplier = muzzle
