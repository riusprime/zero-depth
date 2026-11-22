class_name BatchSniperRow
extends RefCounted
## A Sniper's own fields in its batch row (BatchAvatars; native/src/zd_avatar.h SN_*, the same numbers): its state,
## clocks, raw drives, glows and its legs' rest joints, from FIRST to END. fields() gives them in row order
## (BatchAvatars copies them in), load() takes them back into the avatar (the lens's and the muzzle's materials only
## when their glow changed). Presentation only (EI-07).

const FIRST := 43
const LENS := 43
const STATE := 44
const TELL := 45
const HP := 46
const SPEED := 47
const DIR := 48
const OMEGA := 50
const PHASE := 51
const WALK_STRIDE := 52
const BRACE := 53
const CHARGE := 54
const RISE := 55
const SETTLE_T := 56
const SHOT_T := 57
const DOUBLE := 58
const HEAT := 59
const VENT_T := 60
const HURT_T := 61
const HURT_LEG := 62
const DIE := 63
const LAST_FY := 64
const HAVE_FY := 65
const LIFT := 66
const VD := 67
const HIPS := 84
const KNEES := 93
const FEET := 102
const END := 111


## The Sniper's fields FIRST..END in row order.
static func fields(n: SniperAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(END - FIRST)
	r[LENS - FIRST] = n._lens_mat.emission_energy_multiplier
	r[STATE - FIRST] = n._state
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
	r[SETTLE_T - FIRST] = n._settle_t
	r[SHOT_T - FIRST] = n._shot_t
	r[DOUBLE - FIRST] = 1.0 if n._double else 0.0
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


## The row's fields FIRST..END (`r`, in row order) into the Sniper (its look and rest joints never change: not read
## back).
static func load(n: SniperAvatar, r: PackedFloat64Array) -> void:
	var lens := r[LENS - FIRST]
	if n._lens_mat.emission_energy_multiplier != lens:
		n._lens_mat.emission_energy_multiplier = lens
	n._state = int(r[STATE - FIRST])
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
	n._settle_t = r[SETTLE_T - FIRST]
	n._shot_t = r[SHOT_T - FIRST]
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
	var muzzle := n._vd[SniperAvatar.MUZZLE]
	if n._hole_mat.emission_energy_multiplier != muzzle:
		n._hole_mat.emission_energy_multiplier = muzzle
