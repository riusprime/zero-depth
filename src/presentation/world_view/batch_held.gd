class_name BatchHeld
extends RefCounted
## A batched enemy's node parts kept in the tree (EnemyBatch): the parts a VAT enemy draws as nodes (SoloVat.LIVE: a
## Warden's slam dust ring and a Rubble Warden's crust, a Lens Drone's ground shadow, a Bomb Drone's ground disc). A
## batched enemy's root is outside the tree, so they hang from nodes in the tree that stand as the root, the facing
## and the avatar stood, so the engine draws them where it drew the node enemy's:
## - the root's place: a node not interpolated, put each frame where the batch draws the enemy's contact disc
##   (EnemyBatch.origin: the place the engine drew a node root at, as the frame probe's --twin measures). The batch's
##   anchor is not used: the twin probe measured its interpolated place a part of a tick behind the root's;
## - the facing: a copy of its transform, interpolated as it was (a part under the facing hangs from it);
## - the avatar: its transform, not interpolated, as the avatar was not (a part under the avatar hangs from it).
## A holder is an Array: [facing copy, avatar copy, avatar, root, facing, the place's node].
## Presentation only (EI-07).

const TURN := 0
const BODY := 1
const AVATAR := 2
const ROOT := 3
const FACING := 4
const PLACE := 5


## The holder for batched enemy `id` (its avatar `a`, root and facing), in the tree under `batch`. The caller moves its
## parts under it (`h[BODY]` for the avatar's, `h[TURN]` for the facing's).
static func hold(batch: EnemyBatch, id: int, a: AvatarBase, root: Node3D, facing: Node3D) -> Array:
	var at := Node3D.new()
	at.name = "Held%d" % id
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
	return [turn, body, a, root, facing, at]


## The facing's transform and the shown flags copied when they changed (the batch's sync, the Void's lean).
static func follow(h: Array) -> void:
	var turn: Node3D = h[TURN]
	var facing: Node3D = h[FACING]
	if turn.transform != facing.transform:
		turn.transform = facing.transform
	var shown: bool = (
		facing.visible and (h[ROOT] as Node3D).visible and (h[AVATAR] as Node3D).visible
	)
	if turn.visible != shown:
		turn.visible = shown


## The root's place now (batched enemy `id`).
static func place(h: Array, batch: EnemyBatch, id: int) -> void:
	var at: Node3D = h[PLACE]
	var p := batch.origin(id)
	if at.position != p:
		at.position = p


## The avatar's transform now (slot `k` of `avatars`: a flinch leans the parts with the body).
static func lean(h: Array, avatars: BatchAvatars, k: int) -> void:
	var body: Node3D = h[BODY]
	var xf := avatars.avatar_xf(k)
	if body.transform != xf:
		body.transform = xf
