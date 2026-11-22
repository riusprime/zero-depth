class_name BatchFrostSpitter
extends RefCounted
## A Frost Spitter's own fields in its BatchAvatars row (native/src/zd_avatar.h FS_*, the same numbers): what its sync,
## frame step and pose change after setup, and its legs' hips, knees and feet (set once). BatchRows copies the
## AvatarBase fields itself and these with fields() and take(); its sync's HP rides in the slot's MORE inputs
## (apply_in_script). Presentation only (EI-07).

const SAC_GLOW := 43
const LIFT := 44
const STATE := 45
const TELL := 46
const HP := 47
const SPEED := 48
const DIR := 49
const OMEGA := 51
const PHASE := 52
const STRIDE := 53
const COIL := 54
const RISE := 55
const SPIT := 56
const HURT := 57
const HURT_LEG := 58
const DIE := 59
const LAST_FY := 60
const HAVE_FY := 61
const HIPS := 62
const KNEES := 74
const FEET := 86
const VD := 98
## The first of them in the row, and how many.
const FIRST := SAC_GLOW
const COUNT := VD + 22 - FIRST


## The spitter's fields from FIRST on, in the row's order.
static func fields(a: FrostSpitterAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[SAC_GLOW - FIRST] = a._sac_glow
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[TELL - FIRST] = a._tell
	r[HP - FIRST] = a._hp
	r[SPEED - FIRST] = a._speed
	r[DIR - FIRST] = a._dir.x
	r[DIR + 1 - FIRST] = a._dir.y
	r[OMEGA - FIRST] = a._omega
	r[PHASE - FIRST] = a._phase
	r[STRIDE - FIRST] = a._stride
	r[COIL - FIRST] = a._coil
	r[RISE - FIRST] = a._rise
	r[SPIT - FIRST] = a._spit_t
	r[HURT - FIRST] = a._hurt_t
	r[HURT_LEG - FIRST] = a._hurt_leg
	r[DIE - FIRST] = a._die_t
	r[LAST_FY - FIRST] = a._last_fy
	r[HAVE_FY - FIRST] = 1.0 if a._have_fy else 0.0
	for k in FrostSpitterAvatar.LEGS.size():
		var leg := String(FrostSpitterAvatar.LEGS[k])
		var hip: Vector3 = a._pivots[StringName("leg_%s_u" % leg)]
		var knee: Vector3 = a._pivots[StringName("leg_%s_l" % leg)]
		var tip: Vector3 = a._feet[k]
		for q in 3:
			r[HIPS - FIRST + 3 * k + q] = hip[q]
			r[KNEES - FIRST + 3 * k + q] = knee[q]
			r[FEET - FIRST + 3 * k + q] = tip[q]
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	return r


## Row `st` at `o` into the spitter's fields and its glow materials (only when a glow changed).
static func take(a: FrostSpitterAvatar, st: PackedFloat64Array, o: int) -> void:
	a._sac_glow = st[o + SAC_GLOW]
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._tell = st[o + TELL]
	a._hp = int(st[o + HP])
	a._speed = st[o + SPEED]
	a._dir = Vector2(st[o + DIR], st[o + DIR + 1])
	a._omega = st[o + OMEGA]
	a._phase = st[o + PHASE]
	a._stride = st[o + STRIDE]
	a._coil = st[o + COIL]
	a._rise = st[o + RISE]
	a._spit_t = st[o + SPIT]
	a._hurt_t = st[o + HURT]
	a._hurt_leg = int(st[o + HURT_LEG])
	a._die_t = st[o + DIE]
	a._last_fy = st[o + LAST_FY]
	a._have_fy = st[o + HAVE_FY] != 0.0
	var vd := PackedFloat32Array()
	vd.resize(FrostSpitterAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd
	if a._sac_mat.emission_energy_multiplier != a._sac_glow:
		a._sac_mat.emission_energy_multiplier = a._sac_glow
	var visor := vd[FrostSpitterAvatar.VISOR]
	if a._visor_mat.emission_energy_multiplier != visor:
		a._visor_mat.emission_energy_multiplier = visor


## The pending sync on the avatar itself (the batch's GDScript path), its HP from the slot's MORE inputs at `o`
## (BatchAvatars.note_sync).
static func apply_in_script(
	a: FrostSpitterAvatar,
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
				"state": state,
				"pos": pos,
				"windup": windup,
				"hp": int(more[o]),
			}
		)
	)
