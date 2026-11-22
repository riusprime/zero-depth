class_name BatchLensDrone
extends RefCounted
## The Lens Drone in the enemy batch (EnemyBatch, BatchAvatars): its own fields in its batch row (native/src/zd_avatar.h
## LD_*, the same numbers; ZdCrowd runs its sync, frame step and pose in zd_avatar_lens.cpp), and its soft ground
## shadow kept in the tree. The shadow is the one node of a VAT Lens Drone's that is drawn as a node (SoloVat.LIVE): a
## batched drone's root is outside the tree, so the shadow hangs from nodes in the tree that stand as the root, the
## facing and the avatar stood (BatchWarden.hold's: the batch's anchor, a copy of the facing, a copy of the avatar's
## transform, which a flinch leans), so the engine draws it where and as large as it drew the node drone's.
## Presentation only (EI-07).

const FIRST := 43
const EYE := 43
const STATE := 44
const RISE := 45
const CHARGE := 46
const LIFT := 47
const SHADOW := 48
const HAS_MODEL := 49
const VD := 50
const END := 53


## The drone's fields FIRST..END in row order.
static func fields(d: LensDroneAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(END - FIRST)
	r[EYE - FIRST] = d._eye_mat.emission_energy_multiplier
	r[STATE - FIRST] = d._state
	r[RISE - FIRST] = d._rise
	r[CHARGE - FIRST] = d._charge
	r[LIFT - FIRST] = d._lift
	r[SHADOW - FIRST] = d.shadow.scale.x
	r[HAS_MODEL - FIRST] = 1.0 if d.has_model else 0.0
	for q in d._vd.size():
		r[VD + q - FIRST] = d._vd[q]
	return r


## Slot row `st` at `o` (FIRST..END) into the drone (the eye's material only when its glow changed; the shadow's size is
## show()'s).
static func load(d: LensDroneAvatar, st: PackedFloat64Array, o: int) -> void:
	var eye := st[o + EYE]
	if d._eye_mat.emission_energy_multiplier != eye:
		d._eye_mat.emission_energy_multiplier = eye
	d._state = int(st[o + STATE])
	d._rise = st[o + RISE]
	d._charge = st[o + CHARGE]
	d._lift = st[o + LIFT]
	for q in d._vd.size():
		d._vd[q] = st[o + VD + q]


## Batched drone `id`'s shadow into the tree: under the batch's anchor for it, a copy of its facing and its avatar's
## transform. Returns the holder [facing copy, avatar copy, avatar, root, facing] (BatchWarden.follow keeps it).
static func hold(
	batch: EnemyBatch, id: int, d: LensDroneAvatar, root: Node3D, facing: Node3D
) -> Array:
	var turn := Node3D.new()
	turn.name = "Facing"
	turn.transform = facing.transform
	batch.anchor(id).add_child(turn)
	var body := Node3D.new()
	body.name = "Avatar"
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # (as the avatar's own)
	body.transform = d.transform
	turn.add_child(body)
	d.remove_child(d.shadow)
	body.add_child(d.shadow)
	var h := [turn, body, d, root, facing]
	BatchWarden.follow(h)
	return h


## After the avatars' frame step: the shadow's size from the row (the native rows: the avatar's own step sizes it
## otherwise), and the avatar's transform now (slot `k` of `avatars`: a flinch leans the shadow with the body).
static func show(h: Array, avatars: BatchAvatars, k: int) -> void:
	var d: LensDroneAvatar = h[2]
	if not is_instance_valid(d) or not is_instance_valid(d.shadow):
		return
	if avatars.on:
		var s := avatars.row_value(k, SHADOW)
		var v := Vector3(s, 1, s)
		if d.shadow.scale != v:
			d.shadow.scale = v
	var body: Node3D = h[1]
	var xf := avatars.avatar_xf(k)
	if body.transform != xf:
		body.transform = xf


## LensDroneAvatar.sync's values from the batch's inputs, run on the object (the rows turned off with a sync pending).
static func apply_in_script(d: LensDroneAvatar, tick: int, state: int) -> void:
	d.apply_state({"tick": tick, "state": state})
