class_name BatchLurker
extends RefCounted
## A Rock Lurker's own fields in its BatchAvatars row (native/src/zd_avatar.h L_*, the same numbers): what its sync,
## frame step and pose change after setup, and its body joint's rest place (set once). BatchAvatars copies the
## AvatarBase fields itself and these with fields() and take(). Presentation only (EI-07).

const VISOR := 43
const CRACK := 44
const LIFT := 45
const STATE := 46
const STATE_TICKS := 47
const WINDUP := 48
const HIDDEN := 49
const RUMBLING := 50
const TUCK := 51
const RUMBLE := 52
const BURST := 53
const BURST_SLAM := 54
const SPEED := 55
const WALK := 56
const PHASE := 57
const REAR := 58
const SLAM := 59
const IMPACT := 60
const DIE := 61
const RISE := 62
const REST := 63
const VD := 65
## The first of them in the row, and how many.
const FIRST := VISOR
const COUNT := VD + 18 - FIRST


## The Lurker's fields from FIRST on, in the row's order.
static func fields(a: RockLurkerAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[VISOR - FIRST] = a._visor
	r[CRACK - FIRST] = a._crack
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[STATE_TICKS - FIRST] = a._state_ticks
	r[WINDUP - FIRST] = a._windup
	r[HIDDEN - FIRST] = 1.0 if a._hidden else 0.0
	r[RUMBLING - FIRST] = 1.0 if a._rumbling else 0.0
	r[TUCK - FIRST] = a._tuck
	r[RUMBLE - FIRST] = a._rumble
	r[BURST - FIRST] = a._burst
	r[BURST_SLAM - FIRST] = 1.0 if a._burst_slam else 0.0
	r[SPEED - FIRST] = a._speed
	r[WALK - FIRST] = a._walk
	r[PHASE - FIRST] = a._phase
	r[REAR - FIRST] = a._rear
	r[SLAM - FIRST] = a._slam
	r[IMPACT - FIRST] = a._impact
	r[DIE - FIRST] = a._die
	r[RISE - FIRST] = a._rise
	var rest: Vector3 = a._rest[&"body"]
	r[REST - FIRST] = rest.x
	r[REST + 1 - FIRST] = rest.y
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	return r


## Row `st` at `o` into the Lurker's fields, its glow materials (only when a glow changed) and its joint nodes.
static func take(a: RockLurkerAvatar, st: PackedFloat64Array, o: int) -> void:
	a._visor = st[o + VISOR]
	a._crack = st[o + CRACK]
	if a._crack_mat.emission_energy_multiplier != a._crack:
		a._crack_mat.emission_energy_multiplier = a._crack
	if a._visor_mat.emission_energy_multiplier != a._visor:
		a._visor_mat.emission_energy_multiplier = a._visor
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._state_ticks = int(st[o + STATE_TICKS])
	a._windup = st[o + WINDUP]
	a._hidden = st[o + HIDDEN] != 0.0
	a._rumbling = st[o + RUMBLING] != 0.0
	a._tuck = st[o + TUCK]
	a._rumble = st[o + RUMBLE]
	a._burst = st[o + BURST]
	a._burst_slam = st[o + BURST_SLAM] != 0.0
	a._speed = st[o + SPEED]
	a._walk = st[o + WALK]
	a._phase = st[o + PHASE]
	a._rear = st[o + REAR]
	a._slam = st[o + SLAM]
	a._impact = st[o + IMPACT]
	a._die = st[o + DIE]
	a._rise = st[o + RISE]
	var vd := PackedFloat32Array()
	vd.resize(RockLurkerAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd
	a._write_nodes()
