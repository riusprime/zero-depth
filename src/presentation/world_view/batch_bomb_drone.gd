class_name BatchBombDrone
extends RefCounted
## The Bomb Drone in the enemy batch (EnemyBatch, BatchAvatars): its own fields in its batch row (the BD_* columns,
## native/src/zd_avatar.h: the same numbers; ZdCrowd runs its sync, frame step and pose in zd_avatar_bomb_drone.cpp),
## its sync run on the object, and its ground disc kept in the tree. The disc is the one node of a VAT drone's that is
## drawn as a node (SoloVat.LIVE): a batched drone's root is outside the tree, so the disc hangs from nodes in the tree
## that stand as the root, the facing and the avatar stood, so the engine draws it where it drew the node drone's:
## - the root's place: a node not interpolated, put each frame where the batch draws the drone's contact disc
##   (EnemyBatch.origin: the place the engine drew a node root at, as the frame probe's --twin measures). The batch's
##   anchor is not used: the twin probe measured its interpolated place a part of a tick behind the root's;
## - the facing: a copy of its transform, interpolated as it was;
## - the avatar: its transform, not interpolated, as the avatar was not.
## Presentation only (EI-07).

const VISOR := 43
const SHADOW := 44
const LIFT := 45
const STATE := 46
const HP := 47
const RISE := 48
const ARMED := 49
const FUSE := 50
const LOB := 51
const AIM := 52
const ROT := 53
const SPIN := 54
const GLIDE := 55
const DIR := 56
const OMEGA := 58
const HURT_T := 59
const HURT_SIDE := 60
const DIE := 61
const LAST_FY := 62
const HAVE_FY := 63
const VD := 64
## The first of them in the row, and how many.
const FIRST := VISOR
const COUNT := VD + 12 - FIRST


## The drone's fields from FIRST on, in the row's order.
static func fields(a: BombDroneAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[VISOR - FIRST] = a._visor_mat.emission_energy_multiplier
	r[SHADOW - FIRST] = a.shadow.scale.x
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[HP - FIRST] = a._hp
	r[RISE - FIRST] = a._rise
	r[ARMED - FIRST] = a._armed
	r[FUSE - FIRST] = a._fuse
	r[LOB - FIRST] = a._lob_s
	r[AIM - FIRST] = a._aim
	r[ROT - FIRST] = a._rot
	r[SPIN - FIRST] = a._spin
	r[GLIDE - FIRST] = a._glide
	r[DIR - FIRST] = a._dir.x
	r[DIR + 1 - FIRST] = a._dir.y
	r[OMEGA - FIRST] = a._omega
	r[HURT_T - FIRST] = a._hurt_t
	r[HURT_SIDE - FIRST] = a._hurt_side
	r[DIE - FIRST] = a._die_t
	r[LAST_FY - FIRST] = a._last_fy
	r[HAVE_FY - FIRST] = 1.0 if a._have_fy else 0.0
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	return r


## Row `st` at `o` into the drone's fields, its visor's material and its ground disc's scale (each only when it
## changed). The fuse's glow is left: on the VAT crowd its material belongs to no node.
static func take(a: BombDroneAvatar, st: PackedFloat64Array, o: int) -> void:
	var visor := st[o + VISOR]
	if a._visor_mat.emission_energy_multiplier != visor:
		a._visor_mat.emission_energy_multiplier = visor
	var sh := Vector3(st[o + SHADOW], 1, st[o + SHADOW])
	if is_instance_valid(a.shadow) and a.shadow.scale != sh:
		a.shadow.scale = sh
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._hp = int(st[o + HP])
	a._rise = st[o + RISE]
	a._armed = st[o + ARMED]
	a._fuse = st[o + FUSE]
	a._lob_s = st[o + LOB]
	a._aim = st[o + AIM]
	a._rot = st[o + ROT]
	a._spin = st[o + SPIN]
	a._glide = st[o + GLIDE]
	a._dir = Vector2(st[o + DIR], st[o + DIR + 1])
	a._omega = st[o + OMEGA]
	a._hurt_t = st[o + HURT_T]
	a._hurt_side = st[o + HURT_SIDE]
	a._die_t = st[o + DIE]
	a._last_fy = st[o + LAST_FY]
	a._have_fy = st[o + HAVE_FY] != 0.0
	var vd := PackedFloat32Array()
	vd.resize(BombDroneAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd


## BombDroneAvatar.sync's values from the batch's inputs (its HP the first MORE value), run on the object (the rows
## turned off with a sync pending).
static func apply_in_script(
	a: BombDroneAvatar, tick: int, pos: Vector2, state: int, more: PackedFloat64Array, o: int
) -> void:
	a.apply_state({"tick": tick, "pos": pos, "state": state, "hp": int(more[o])})


## Batched drone `id`'s ground disc into the tree: under a node at its root's place, a copy of its facing and its
## avatar's transform. Returns the holder [facing copy, avatar copy, avatar, root, facing, the place's node]
## (BatchWarden.follow reads the first five); EnemyBatch frees the place's node with the slot.
static func hold(
	batch: EnemyBatch, id: int, a: BombDroneAvatar, root: Node3D, facing: Node3D
) -> Array:
	var at := Node3D.new()
	at.name = "Ground%d" % id
	at.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # (placed by hand each frame)
	at.position = batch.origin(id)
	batch.add_child(at)
	var turn := Node3D.new()
	turn.name = "Facing"
	turn.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON  # (as the facing's own, under the root's)
	turn.transform = facing.transform
	at.add_child(turn)
	turn.reset_physics_interpolation()
	var body := Node3D.new()
	body.name = "Avatar"
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # (as the avatar's own)
	body.transform = a.transform
	turn.add_child(body)
	a.remove_child(a.shadow)
	body.add_child(a.shadow)
	var h := [turn, body, a, root, facing, at]
	BatchWarden.follow(h)
	return h


## After the avatars' frame step (batched drone `id`, slot `k` of the batch's avatars): the root's place now, the
## disc's scale from the row (the native rows: the avatar's own pose sets it otherwise) and the avatar's transform now
## (the flinch leans the disc with the body).
static func show(h: Array, batch: EnemyBatch, id: int, k: int) -> void:
	var a: BombDroneAvatar = h[2]
	if not is_instance_valid(a) or not is_instance_valid(a.shadow):
		return
	var at: Node3D = h[5]
	var p := batch.origin(id)
	if at.position != p:
		at.position = p
	var avatars := batch.avatars
	if avatars.on:
		var s := avatars.row_value(k, SHADOW)
		var sh := Vector3(s, 1, s)
		if a.shadow.scale != sh:
			a.shadow.scale = sh
	var body: Node3D = h[1]
	var xf := avatars.avatar_xf(k)
	if body.transform != xf:
		body.transform = xf
