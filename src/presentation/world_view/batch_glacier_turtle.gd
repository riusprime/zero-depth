class_name BatchGlacierTurtle
extends RefCounted
## A Glacier Turtle's own fields in its BatchAvatars row (native/src/zd_avatar.h GT_*, the same numbers): what its sync,
## frame step and pose change after setup, and its legs' hips and knees and the model's scale (set once: its feet are
## FEET at that scale). BatchRows copies the AvatarBase fields itself and these with fields() and take(); its sync's HP
## and shield HP ride in the slot's MORE inputs (apply_in_script). Presentation only (EI-07).

const VISOR := 43
const LIFT := 44
const STATE := 45
const TELL := 46
const HP := 47
const SHELL := 48
const BARE := 49
const SPEED := 50
const DIR := 51
const OMEGA := 53
const PHASE := 54
const STRIDE := 55
const COIL := 56
const RISE := 57
const SLAM := 58
const BRACE := 59
const BREAK := 60
const HURT := 61
const HURT_LEG := 62
const DIE := 63
const LAST_FY := 64
const HAVE_FY := 65
const VD := 66
const HIPS := 90
const KNEES := 102
const SCALE := 114
## The first of them in the row, and how many.
const FIRST := VISOR
const COUNT := SCALE + 1 - FIRST


## The turtle's fields from FIRST on, in the row's order.
static func fields(a: GlacierTurtleAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[VISOR - FIRST] = a._visor_mat.emission_energy_multiplier
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[TELL - FIRST] = a._tell
	r[HP - FIRST] = a._hp
	r[SHELL - FIRST] = a._shell
	r[BARE - FIRST] = a._bare
	r[SPEED - FIRST] = a._speed
	r[DIR - FIRST] = a._dir.x
	r[DIR + 1 - FIRST] = a._dir.y
	r[OMEGA - FIRST] = a._omega
	r[PHASE - FIRST] = a._phase
	r[STRIDE - FIRST] = a._stride
	r[COIL - FIRST] = a._coil
	r[RISE - FIRST] = a._rise
	r[SLAM - FIRST] = a._slam_t
	r[BRACE - FIRST] = a._brace_t
	r[BREAK - FIRST] = a._break_t
	r[HURT - FIRST] = a._hurt_t
	r[HURT_LEG - FIRST] = a._hurt_leg
	r[DIE - FIRST] = a._die_t
	r[LAST_FY - FIRST] = a._last_fy
	r[HAVE_FY - FIRST] = 1.0 if a._have_fy else 0.0
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	for k in GlacierTurtleAvatar.LEGS.size():
		var leg := String(GlacierTurtleAvatar.LEGS[k])
		var hip: Vector3 = a._pivots[StringName("leg_%s_u" % leg)]
		var knee: Vector3 = a._pivots[StringName("leg_%s_l" % leg)]
		for c in 3:
			r[HIPS - FIRST + 3 * k + c] = hip[c]
			r[KNEES - FIRST + 3 * k + c] = knee[c]
	r[SCALE - FIRST] = a._scale
	return r


## Row `st` at `o` into the turtle's fields and its visor's material (only when its glow changed).
static func take(a: GlacierTurtleAvatar, st: PackedFloat64Array, o: int) -> void:
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._tell = st[o + TELL]
	a._hp = int(st[o + HP])
	a._shell = int(st[o + SHELL])
	a._bare = st[o + BARE]
	a._speed = st[o + SPEED]
	a._dir = Vector2(st[o + DIR], st[o + DIR + 1])
	a._omega = st[o + OMEGA]
	a._phase = st[o + PHASE]
	a._stride = st[o + STRIDE]
	a._coil = st[o + COIL]
	a._rise = st[o + RISE]
	a._slam_t = st[o + SLAM]
	a._brace_t = st[o + BRACE]
	a._break_t = st[o + BREAK]
	a._hurt_t = st[o + HURT]
	a._hurt_leg = int(st[o + HURT_LEG])
	a._die_t = st[o + DIE]
	a._last_fy = st[o + LAST_FY]
	a._have_fy = st[o + HAVE_FY] != 0.0
	var vd := PackedFloat32Array()
	vd.resize(GlacierTurtleAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd
	var visor := st[o + VISOR]
	if a._visor_mat.emission_energy_multiplier != visor:
		a._visor_mat.emission_energy_multiplier = visor


## The pending sync on the avatar itself (the batch's GDScript path), from the slot's MORE inputs at `o` (its HP and
## its shield's HP, BatchAvatars.note_sync).
static func apply_in_script(
	a: GlacierTurtleAvatar,
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
				"shell": int(more[o + 1]),
			}
		)
	)
