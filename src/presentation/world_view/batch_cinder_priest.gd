class_name BatchCinderPriest
extends RefCounted
## A Cinder Priest's own fields in its BatchAvatars row (native/src/zd_avatar.h CP_*, the same numbers): what its sync,
## frame step and pose change after setup, its sync's inputs past the common ones (its vent's numbers, worked out
## here exactly as its sync() does) and its fallback sync. BatchAvatars copies the AvatarBase fields itself and these
## with fields() and take(). Presentation only (EI-07).

const CRYSTAL := 43
const LIFT := 44
const STATE := 45
const PULSE := 46
const ERUPT := 47
const VENT_YAW := 48
const FACING := 49
const RISE := 50
const GLIDE := 51
const DIR := 52
const TURN := 54
const YAW := 55
const DIE := 56
const VD := 57
## The first of them in the row, and how many.
const FIRST := CRYSTAL
const COUNT := VD + 18 - FIRST


## The priest's fields from FIRST on, in the row's order.
static func fields(a: CinderPriestAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[CRYSTAL - FIRST] = a._crystal
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[PULSE - FIRST] = a._pulse
	r[ERUPT - FIRST] = a._erupt_s
	r[VENT_YAW - FIRST] = a._vent_yaw
	r[FACING - FIRST] = a._facing
	r[RISE - FIRST] = a._rise
	r[GLIDE - FIRST] = a._glide
	r[DIR - FIRST] = a._dir.x
	r[DIR + 1 - FIRST] = a._dir.y
	r[TURN - FIRST] = a._turn
	r[YAW - FIRST] = a._yaw
	r[DIE - FIRST] = a._die_t
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	return r


## Row `st` at `o` into the priest's fields and its glow materials (only when a glow changed).
static func take(a: CinderPriestAvatar, st: PackedFloat64Array, o: int) -> void:
	a._crystal = st[o + CRYSTAL]
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._pulse = st[o + PULSE]
	a._erupt_s = st[o + ERUPT]
	a._vent_yaw = st[o + VENT_YAW]
	a._facing = st[o + FACING]
	a._rise = st[o + RISE]
	a._glide = st[o + GLIDE]
	a._dir = Vector2(st[o + DIR], st[o + DIR + 1])
	a._turn = st[o + TURN]
	a._yaw = st[o + YAW]
	a._die_t = st[o + DIE]
	var vd := PackedFloat32Array()
	vd.resize(CinderPriestAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd
	if a._crystal_mat.emission_energy_multiplier != a._crystal:
		a._crystal_mat.emission_energy_multiplier = a._crystal
	var visor := vd[CinderPriestAvatar.VISOR]
	if a._visor_mat.emission_energy_multiplier != visor:
		a._visor_mat.emission_energy_multiplier = visor


## Its sync's inputs past the common ones into `more` at `o` (zd_avatar.h MORE), as CinderPriestAvatar.sync reads
## them: its vent's pulse (0..1000), the ticks since its own vent erupted (-1: none), the vent's direction in the
## facing's frame (radians; NAN: none), the facing's yaw.
static func note(reader: WorldReader, i: int, more: PackedFloat64Array, o: int) -> void:
	var facing := SimPlane.yaw_of(reader.actor_facing(i))
	var age := -1
	var vent_yaw := NAN
	var id := reader.actor_id(i)
	for v: Array in reader.lava_vents():  # its own vent: its last eruption and where it stands
		if int(v[5]) != id or not bool(v[4]):
			continue
		age = int(v[3])
		var to: Vector2 = (v[0] as Vector2) - reader.actor_pos(i)
		if to.length_squared() > 1e-4:
			vent_yaw = wrapf(atan2(to.y, to.x) - facing, -PI, PI)
		break
	more[o] = reader.priest_pulse(i)
	more[o + 1] = age
	more[o + 2] = vent_yaw
	more[o + 3] = facing


## CinderPriestAvatar.sync's values from the batch's inputs (its vent's numbers and facing at `more[o]`,
## BatchAvatars.note_sync), run on the object (the rows turned off with a sync pending).
static func apply_in_script(
	a: CinderPriestAvatar, tick: int, pos: Vector2, state: int, more: PackedFloat64Array, o: int
) -> void:
	var s := {
		"tick": tick,
		"state": state,
		"pos": pos,
		"pulse": int(more[o]),
		"facing": more[o + 3],
	}
	if more[o + 1] >= 0.0:
		s["erupt_age"] = int(more[o + 1])
	if not is_nan(more[o + 2]):
		s["vent_yaw"] = more[o + 2]
	a.apply_state(s)
