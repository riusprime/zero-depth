class_name BatchKilnBeetle
extends RefCounted
## A Kiln Beetle's own fields in its BatchAvatars row (native/src/zd_avatar.h KB_*, the same numbers): what its sync,
## frame step and pose change after setup, and each leg's foot across the body (set once). BatchAvatars copies the
## AvatarBase fields itself and these with fields() and take(); its sync's HP and full HP ride in the slot's MORE
## inputs (apply_in_script). Presentation only (EI-07).

const HEAT_GLOW := 43
const LIFT := 44
const STATE := 45
const TELL := 46
const HP := 47
const HEAT := 48
const SPEED := 49
const OMEGA := 50
const PHASE := 51
const STRIDE := 52
const COIL := 53
const RISE := 54
const SLAM := 55
const HURT := 56
const HURT_LEG := 57
const DIE := 58
const LAST_FY := 59
const HAVE_FY := 60
const FOOT_Z := 61
const VD := 69
## The first of them in the row, and how many.
const FIRST := HEAT_GLOW
const COUNT := VD + 32 - FIRST


## The beetle's fields from FIRST on, in the row's order.
static func fields(a: KilnBeetleAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[HEAT_GLOW - FIRST] = a._heat_glow
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[TELL - FIRST] = a._tell
	r[HP - FIRST] = a._hp
	r[HEAT - FIRST] = a._heat
	r[SPEED - FIRST] = a._speed
	r[OMEGA - FIRST] = a._omega
	r[PHASE - FIRST] = a._phase
	r[STRIDE - FIRST] = a._stride
	r[COIL - FIRST] = a._coil
	r[RISE - FIRST] = a._rise
	r[SLAM - FIRST] = a._slam_t
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


## Row `st` at `o` into the beetle's fields and its glow materials (only when a glow changed).
static func take(a: KilnBeetleAvatar, st: PackedFloat64Array, o: int) -> void:
	a._heat_glow = st[o + HEAT_GLOW]
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._tell = st[o + TELL]
	a._hp = int(st[o + HP])
	a._heat = st[o + HEAT]
	a._speed = st[o + SPEED]
	a._omega = st[o + OMEGA]
	a._phase = st[o + PHASE]
	a._stride = st[o + STRIDE]
	a._coil = st[o + COIL]
	a._rise = st[o + RISE]
	a._slam_t = st[o + SLAM]
	a._hurt_t = st[o + HURT]
	a._hurt_leg = int(st[o + HURT_LEG])
	a._die_t = st[o + DIE]
	a._last_fy = st[o + LAST_FY]
	a._have_fy = st[o + HAVE_FY] != 0.0
	var vd := PackedFloat32Array()
	vd.resize(KilnBeetleAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd
	if a._heat_mat.emission_energy_multiplier != a._heat_glow:
		a._heat_mat.emission_energy_multiplier = a._heat_glow
	var visor := vd[KilnBeetleAvatar.VISOR]
	if a._visor_mat.emission_energy_multiplier != visor:
		a._visor_mat.emission_energy_multiplier = visor


## The pending sync on the avatar itself (the batch's GDScript path), from the slot's MORE inputs at `o` (its HP and
## its full HP, BatchAvatars.note_sync).
static func apply_in_script(
	a: KilnBeetleAvatar,
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
				"max_hp": int(more[o + 1]),
			}
		)
	)
