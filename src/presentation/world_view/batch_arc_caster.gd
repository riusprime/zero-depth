class_name BatchArcCaster
extends RefCounted
## An Arc Caster's own fields in its BatchAvatars row (native/src/zd_avatar.h AC_*, the same numbers): what its sync,
## frame step and pose change after setup, and its robe's waist height (set once). BatchAvatars copies the AvatarBase
## fields itself and these with fields() and take(). Presentation only (EI-07).

const CRYSTAL := 43
const LIFT := 44
const STATE := 45
const WIND := 46
const CAST := 47
const RISE := 48
const GLIDE := 49
const DIR := 50
const STEP := 52
const ORBIT := 53
const OMEGA := 54
const DIE := 55
const LAST_FY := 56
const HAVE_FY := 57
const HEM_Y := 58
const VD := 59
## The first of them in the row, and how many.
const FIRST := CRYSTAL
const COUNT := VD + 23 - FIRST


## The caster's fields from FIRST on, in the row's order.
static func fields(a: ArcCasterAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[CRYSTAL - FIRST] = a._crystal
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[WIND - FIRST] = a._wind
	r[CAST - FIRST] = a._cast_s
	r[RISE - FIRST] = a._rise
	r[GLIDE - FIRST] = a._glide
	r[DIR - FIRST] = a._dir.x
	r[DIR + 1 - FIRST] = a._dir.y
	r[STEP - FIRST] = a._step
	r[ORBIT - FIRST] = a._orbit
	r[OMEGA - FIRST] = a._omega
	r[DIE - FIRST] = a._die_t
	r[LAST_FY - FIRST] = a._last_fy
	r[HAVE_FY - FIRST] = 1.0 if a._have_fy else 0.0
	r[HEM_Y - FIRST] = (a._pivots[&"hem_u"] as Vector3).y
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	return r


## Row `st` at `o` into the caster's fields and its glow materials (only when a glow changed).
static func take(a: ArcCasterAvatar, st: PackedFloat64Array, o: int) -> void:
	a._crystal = st[o + CRYSTAL]
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._wind = st[o + WIND]
	a._cast_s = st[o + CAST]
	a._rise = st[o + RISE]
	a._glide = st[o + GLIDE]
	a._dir = Vector2(st[o + DIR], st[o + DIR + 1])
	a._step = st[o + STEP]
	a._orbit = st[o + ORBIT]
	a._omega = st[o + OMEGA]
	a._die_t = st[o + DIE]
	a._last_fy = st[o + LAST_FY]
	a._have_fy = st[o + HAVE_FY] != 0.0
	var vd := PackedFloat32Array()
	vd.resize(ArcCasterAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd
	if a._crystal_mat.emission_energy_multiplier != a._crystal:
		a._crystal_mat.emission_energy_multiplier = a._crystal
	var visor := vd[ArcCasterAvatar.VISOR]
	if a._visor_mat.emission_energy_multiplier != visor:
		a._visor_mat.emission_energy_multiplier = visor
