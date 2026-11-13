class_name BonePoser
extends RefCounted
## Poses a boss model's skeleton from turns given in the avatar's model frame (+X the front, Y up, +Z the right,
## metres), whatever the skeleton's own bone axes are (the owner's rigged Warlord and Hive Lens come with
## Tripo bones whose rest rotations are not the identity). Each frame the avatar's pose functions add turns, shifts
## and scales, then commit() writes every bone once: a bone left alone this frame goes back to its rest pose.
## A turn is applied about the bone's own pivot, in the model frame, as if the parent were at rest; children follow.
## A bone the model file's animations pose (lay_over) is the exception: the animations write it afresh every frame
## before commit(), and commit() adds the frame's turn, shift and stretch to the pose it finds there, so a flinch or
## a roar shows over the file's idle and nothing of it stays once the code stops posing the bone.
## Presentation only (EI-07): it writes the avatar's own skeleton and never reads or writes the sim.

var skeleton: Skeleton3D
# The skeleton frame's rotation in the model frame, and its scale (model metres per skeleton unit).
var _frame := Quaternion.IDENTITY
var _scale := 1.0
var _index := {}
var _global := {}
var _turns := {}
var _shifts := {}
var _scales := {}
var _posed := {}
# The bones something else writes every frame before commit() (lay_over).
var _over := {}


func _init(skel: Skeleton3D, frame: Quaternion = Quaternion.IDENTITY, scale: float = 1.0) -> void:
	skeleton = skel
	_frame = frame.normalized()
	_scale = maxf(scale, 0.0001)
	for k in skel.get_bone_count():
		_index[StringName(skel.get_bone_name(k))] = k
		_global[k] = skel.get_bone_global_rest(k).basis.get_rotation_quaternion()


## The bone's index, or -1 when the skeleton has no such bone.
func index_of(bone: StringName) -> int:
	return _index.get(bone, -1)


func has_bone(bone: StringName) -> bool:
	return _index.has(bone)


## Turns `bone` by `angle` radians about `axis` (model frame); later turns apply after earlier ones.
func turn(bone: StringName, axis: Vector3, angle: float) -> void:
	var k := index_of(bone)
	if k < 0 or angle == 0.0:
		return
	_turns[k] = Quaternion(axis.normalized(), angle) * _turns.get(k, Quaternion.IDENTITY)


## Turns `bone` by `by` (model frame), after the turns already given this frame.
func turn_by(bone: StringName, by: Quaternion) -> void:
	var k := index_of(bone)
	if k >= 0:
		_turns[k] = by * (_turns.get(k, Quaternion.IDENTITY) as Quaternion)


## The turn given to `bone` so far this frame (the identity when none).
func pending_turn(bone: StringName) -> Quaternion:
	return _turns.get(index_of(bone), Quaternion.IDENTITY)


## Moves `bone`'s pivot by `offset` metres (model frame).
func shift(bone: StringName, offset: Vector3) -> void:
	var k := index_of(bone)
	if k >= 0:
		_shifts[k] = _shifts.get(k, Vector3.ZERO) + offset


## Scales `bone` (and what hangs from it) by `factor` about its pivot.
func stretch(bone: StringName, factor: float) -> void:
	var k := index_of(bone)
	if k >= 0:
		_scales[k] = _scales.get(k, 1.0) * factor


## Says which bones (by index) something else poses afresh every frame before commit(): the model file's animations
## (BossAnimator.apply_owner). On those commit() adds to the pose it finds; on every other bone it writes over the
## rest pose.
func lay_over(bones: PackedInt32Array) -> void:
	for k in bones:
		if k >= 0 and k < skeleton.get_bone_count():
			_over[k] = true


## Writes this frame's pose: every turned, shifted or scaled bone, and every bone posed last frame back to rest. A
## bone of lay_over() already holds this frame's animated pose: the turn is added to it about the same model-frame
## axis as over the rest pose (in its parent's frame, whichever way the animation has turned the bone itself), the
## shift to its position, the stretch to its scale; left alone this frame, it keeps the animated pose it was given.
func commit() -> void:
	var now := {}
	for d: Dictionary in [_turns, _shifts, _scales]:
		for k in d:
			now[k] = true
	for k in _posed:
		now[k] = true
	var inv := _frame.inverse()
	for k: int in now:
		var g: Quaternion = _global[k]
		var q: Quaternion = inv * (_turns.get(k, Quaternion.IDENTITY) as Quaternion) * _frame
		var parent := skeleton.get_bone_parent(k)
		var pg: Quaternion = _global[parent] if parent >= 0 else Quaternion.IDENTITY
		var moved := Vector3.ZERO
		if _shifts.has(k):
			moved = pg.inverse() * (inv * (_shifts[k] as Vector3)) / _scale
		if _over.has(k):
			if _turns.has(k):
				skeleton.set_bone_pose_rotation(
					k, ((pg.inverse() * q * pg) * skeleton.get_bone_pose_rotation(k)).normalized()
				)
			if _shifts.has(k):
				skeleton.set_bone_pose_position(k, skeleton.get_bone_pose_position(k) + moved)
			if _scales.has(k):
				skeleton.set_bone_pose_scale(k, skeleton.get_bone_pose_scale(k) * float(_scales[k]))
			continue
		var rest := skeleton.get_bone_rest(k)
		skeleton.set_bone_pose_rotation(
			k, (rest.basis.get_rotation_quaternion() * (g.inverse() * q * g)).normalized()
		)
		skeleton.set_bone_pose_position(k, rest.origin + moved)
		skeleton.set_bone_pose_scale(k, Vector3.ONE * float(_scales.get(k, 1.0)))
	_posed.clear()
	for d: Dictionary in [_turns, _shifts, _scales]:
		for k in d:
			_posed[k] = true
		d.clear()


## The bone's pivot now, in the skeleton node's own space (tests and the anchors).
func bone_origin(bone: StringName) -> Vector3:
	var k := index_of(bone)
	return skeleton.get_bone_global_pose(k).origin if k >= 0 else Vector3.ZERO
