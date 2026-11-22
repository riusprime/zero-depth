class_name BatchScrapHound
extends RefCounted
## A Scrap Hound's own fields in its BatchAvatars row (native/src/zd_avatar.h SH_*, the same numbers): what its sync,
## frame step and pose change after setup, and its sync's inputs past the common ones. BatchAvatars copies the
## AvatarBase fields itself and these with fields() and take(). Presentation only (EI-07).

const GLOW := 43
const LIFT := 44
const STATE := 45
const TELL := 46
const HP := 47
const SPEED := 48
const GALLOP := 49
const PHASE := 50
const YAW := 51
const TURN := 52
const BANK := 53
const LAST_H := 54
const HAVE_H := 55
const COIL := 56
const DART := 57
const RISE := 58
const BITE := 59
const YELP := 60
const HURT := 61
const DIE := 62
const VD := 63
## The first of them in the row, and how many.
const FIRST := GLOW
const COUNT := VD + 18 - FIRST


## The hound's fields from FIRST on, in the row's order.
static func fields(a: ScrapHoundAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[GLOW - FIRST] = a._glow
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[TELL - FIRST] = a._tell
	r[HP - FIRST] = a._hp
	r[SPEED - FIRST] = a._speed
	r[GALLOP - FIRST] = a._gallop
	r[PHASE - FIRST] = a._phase
	r[YAW - FIRST] = a._yaw
	r[TURN - FIRST] = a._turn
	r[BANK - FIRST] = a._bank
	r[LAST_H - FIRST] = a._last_h
	r[HAVE_H - FIRST] = 1.0 if a._have_h else 0.0
	r[COIL - FIRST] = a._coil
	r[DART - FIRST] = a._dart
	r[RISE - FIRST] = a._rise
	r[BITE - FIRST] = a._bite_t
	r[YELP - FIRST] = a._yelp_t
	r[HURT - FIRST] = a._hurt_t
	r[DIE - FIRST] = a._die_t
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	return r


## Row `st` at `o` into the hound's fields and its visor material (only when its glow changed).
static func take(a: ScrapHoundAvatar, st: PackedFloat64Array, o: int) -> void:
	a._glow = st[o + GLOW]
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._tell = st[o + TELL]
	a._hp = int(st[o + HP])
	a._speed = st[o + SPEED]
	a._gallop = st[o + GALLOP]
	a._phase = st[o + PHASE]
	a._yaw = st[o + YAW]
	a._turn = st[o + TURN]
	a._bank = st[o + BANK]
	a._last_h = st[o + LAST_H]
	a._have_h = st[o + HAVE_H] != 0.0
	a._coil = st[o + COIL]
	a._dart = st[o + DART]
	a._rise = st[o + RISE]
	a._bite_t = st[o + BITE]
	a._yelp_t = st[o + YELP]
	a._hurt_t = st[o + HURT]
	a._die_t = st[o + DIE]
	var vd := PackedFloat32Array()
	vd.resize(ScrapHoundAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd
	if a._visor_mat.emission_energy_multiplier != a._glow:
		a._visor_mat.emission_energy_multiplier = a._glow


## Its sync's inputs past the common ones into `more` at `o` (zd_avatar.h MORE): its HP, whether a hit stopped it.
static func note(reader: WorldReader, i: int, more: PackedFloat64Array, o: int) -> void:
	more[o] = reader.actor_hp(i)
	more[o + 1] = 1.0 if reader.hound_yelped(i) else 0.0


## ScrapHoundAvatar.sync's values from the batch's inputs (its HP and the yelp at `more[o]`, BatchAvatars.note_sync),
## run on the object (the rows turned off with a sync pending).
static func apply_in_script(
	a: ScrapHoundAvatar,
	tick: int,
	pos: Vector2,
	state: int,
	windup: float,
	more: PackedFloat64Array,
	o: int
) -> void:
	(
		a
		. apply_state(
			{
				"tick": tick,
				"pos": pos,
				"state": state,
				"windup": windup,
				"yelped": more[o + 1] != 0.0,
				"hp": int(more[o]),
			}
		)
	)
