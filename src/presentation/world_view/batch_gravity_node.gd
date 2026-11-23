class_name BatchGravityNode
extends RefCounted
## The Gravity Node in the enemy batch (EnemyBatch, BatchAvatars): its own fields in its batch row (the GN_* columns,
## native/src/zd_avatar.h: the same numbers; ZdCrowd runs its sync, frame step and pose in
## zd_avatar_gravity_node.cpp), its sync run on the object, and its ground disc kept in the tree. The disc is the one
## node of a VAT node's that is drawn as a node (SoloVat.LIVE): it hangs from the avatar's copy in BatchHeld's holder
## (the root's place, the facing, the avatar, which a flinch leans), so the engine draws it where it drew the node
## Gravity Node's. Presentation only (EI-07).

const CORE_GLOW := 43
const LIFT := 44
const SHADOW := 45
const STATE := 46
const HP := 47
const DRAW := 48
const DRAW_TO := 49
const RISE := 50
const SPIN_A := 51
const SPIN_B := 52
const BEAT := 53
const OMEGA := 54
const HURT := 55
const HURT_SIDE := 56
const DIE := 57
const LAST_FY := 58
const HAVE_FY := 59
const VD := 60
## The first of them in the row, and how many.
const FIRST := CORE_GLOW
const COUNT := VD + 17 - FIRST


## The node's fields from FIRST on, in the row's order.
static func fields(a: GravityNodeAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[CORE_GLOW - FIRST] = a._core_glow
	r[LIFT - FIRST] = a._lift
	r[SHADOW - FIRST] = a.shadow.scale.x
	r[STATE - FIRST] = a._state
	r[HP - FIRST] = a._hp
	r[DRAW - FIRST] = a._draw
	r[DRAW_TO - FIRST] = a._draw_to
	r[RISE - FIRST] = a._rise
	r[SPIN_A - FIRST] = a._spin_a
	r[SPIN_B - FIRST] = a._spin_b
	r[BEAT - FIRST] = a._beat
	r[OMEGA - FIRST] = a._omega
	r[HURT - FIRST] = a._hurt_t
	r[HURT_SIDE - FIRST] = a._hurt_side
	r[DIE - FIRST] = a._die_t
	r[LAST_FY - FIRST] = a._last_fy
	r[HAVE_FY - FIRST] = 1.0 if a._have_fy else 0.0
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	return r


## Row `st` at `o` into the node's fields, its glow materials and its ground disc's scale (each only when it changed).
static func take(a: GravityNodeAvatar, st: PackedFloat64Array, o: int) -> void:
	a._core_glow = st[o + CORE_GLOW]
	a._lift = st[o + LIFT]
	var sh := Vector3(st[o + SHADOW], 1, st[o + SHADOW])
	if is_instance_valid(a.shadow) and a.shadow.scale != sh:
		a.shadow.scale = sh
	a._state = int(st[o + STATE])
	a._hp = int(st[o + HP])
	a._draw = st[o + DRAW]
	a._draw_to = st[o + DRAW_TO]
	a._rise = st[o + RISE]
	a._spin_a = st[o + SPIN_A]
	a._spin_b = st[o + SPIN_B]
	a._beat = st[o + BEAT]
	a._omega = st[o + OMEGA]
	a._hurt_t = st[o + HURT]
	a._hurt_side = st[o + HURT_SIDE]
	a._die_t = st[o + DIE]
	a._last_fy = st[o + LAST_FY]
	a._have_fy = st[o + HAVE_FY] != 0.0
	var vd := PackedFloat32Array()
	vd.resize(GravityNodeAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd
	if a._core_mat.emission_energy_multiplier != a._core_glow:
		a._core_mat.emission_energy_multiplier = a._core_glow
	var visor := vd[GravityNodeAvatar.VISOR]
	if a._visor_mat.emission_energy_multiplier != visor:
		a._visor_mat.emission_energy_multiplier = visor


## Its sync's inputs past the common ones (BatchAvatars.note_sync, at `o` of `more`): its HP, its draw on the hero.
static func note(reader: WorldReader, i: int, more: PackedFloat64Array, o: int) -> void:
	more[o] = reader.actor_hp(i)
	more[o + 1] = reader.gravity_hero_pull(i)


## GravityNodeAvatar.sync's values from the batch's inputs (note's), run on the object (the rows turned off with a
## sync pending).
static func apply_in_script(
	a: GravityNodeAvatar, state: int, more: PackedFloat64Array, o: int
) -> void:
	a.apply_state({"state": state, "hp": int(more[o]), "draw": more[o + 1]})


## Batched node `id`'s ground disc into the tree, under the avatar's copy in its holder (BatchHeld.hold).
static func hold(
	batch: EnemyBatch, id: int, a: GravityNodeAvatar, root: Node3D, facing: Node3D
) -> Array:
	var h := BatchHeld.hold(batch, id, a, root, facing)
	a.remove_child(a.shadow)
	(h[BatchHeld.BODY] as Node3D).add_child(a.shadow)
	BatchHeld.follow(h)
	return h


## After the avatars' frame step (batched node `id`, slot `k` of the batch's avatars): the root's place now, the
## disc's scale from the row (the native rows: the avatar's own pose sets it otherwise) and the avatar's transform now
## (the flinch leans the disc with the body).
static func show(h: Array, batch: EnemyBatch, id: int, k: int) -> void:
	var a: GravityNodeAvatar = h[BatchHeld.AVATAR]
	if not is_instance_valid(a) or not is_instance_valid(a.shadow):
		return
	BatchHeld.place(h, batch, id)
	var avatars := batch.avatars
	if avatars.on:
		var s := avatars.row_value(k, SHADOW)
		var sh := Vector3(s, 1, s)
		if a.shadow.scale != sh:
			a.shadow.scale = sh
	BatchHeld.lean(h, avatars, k)
