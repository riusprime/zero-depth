class_name BatchWireWeaver
extends RefCounted
## A Wire Weaver's own fields in its BatchAvatars row (native/src/zd_avatar.h WW_*, the same numbers): what its sync,
## frame step and pose change after setup, and each leg's foot across the body (set once). BatchRows copies the
## AvatarBase fields itself and these with fields() and take(); its sync's HP rides in the slot's MORE inputs
## (apply_in_script). Presentation only (EI-07).

const SPARK := 43
const LIFT := 44
const STATE := 45
const TELL := 46
const HP := 47
const SPEED := 48
const OMEGA := 49
const PHASE := 50
const STRIDE := 51
const COIL := 52
const RISE := 53
const PLANT := 54
const HURT := 55
const HURT_LEG := 56
const DIE := 57
const LAST_FY := 58
const HAVE_FY := 59
const FOOT_Z := 60
const VD := 64
## The first of them in the row, and how many.
const FIRST := SPARK
const COUNT := VD + 31 - FIRST


## The Weaver's fields from FIRST on, in the row's order.
static func fields(a: WireWeaverAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[SPARK - FIRST] = a._spark
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[TELL - FIRST] = a._tell
	r[HP - FIRST] = a._hp
	r[SPEED - FIRST] = a._speed
	r[OMEGA - FIRST] = a._omega
	r[PHASE - FIRST] = a._phase
	r[STRIDE - FIRST] = a._stride
	r[COIL - FIRST] = a._coil
	r[RISE - FIRST] = a._rise
	r[PLANT - FIRST] = a._plant_t
	r[HURT - FIRST] = a._hurt_t
	r[HURT_LEG - FIRST] = a._hurt_leg
	r[DIE - FIRST] = a._die_t
	r[LAST_FY - FIRST] = a._last_fy
	r[HAVE_FY - FIRST] = 1.0 if a._have_fy else 0.0
	for q in a._foot_z.size():
		r[FOOT_Z - FIRST + q] = a._foot_z[q]
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	return r


## Row `st` at `o` into the Weaver's fields and its glow materials (only when a glow changed).
static func take(a: WireWeaverAvatar, st: PackedFloat64Array, o: int) -> void:
	a._spark = st[o + SPARK]
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._tell = st[o + TELL]
	a._hp = int(st[o + HP])
	a._speed = st[o + SPEED]
	a._omega = st[o + OMEGA]
	a._phase = st[o + PHASE]
	a._stride = st[o + STRIDE]
	a._coil = st[o + COIL]
	a._rise = st[o + RISE]
	a._plant_t = st[o + PLANT]
	a._hurt_t = st[o + HURT]
	a._hurt_leg = int(st[o + HURT_LEG])
	a._die_t = st[o + DIE]
	a._last_fy = st[o + LAST_FY]
	a._have_fy = st[o + HAVE_FY] != 0.0
	var vd := PackedFloat32Array()
	vd.resize(WireWeaverAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd
	if a._spark_mat.emission_energy_multiplier != a._spark:
		a._spark_mat.emission_energy_multiplier = a._spark
	var visor := vd[WireWeaverAvatar.VISOR]
	if a._visor_mat.emission_energy_multiplier != visor:
		a._visor_mat.emission_energy_multiplier = visor


## The pending sync on the avatar itself (the batch's GDScript path), its HP from the slot's MORE inputs at `o`
## (BatchAvatars.note_sync).
static func apply_in_script(
	a: WireWeaverAvatar,
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
