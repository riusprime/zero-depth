class_name BoneOverPoser
extends BonePoser
## A BonePoser for a model whose own animations key every bone (the Lantern Shade's file). There the file's idle
## would replace whatever a code clip turned, because BossAvatar writes the code pose first and the file's animations
## over it: a flinch, the stagger's sag or the roar would not show. This one holds the frame's turns back: commit()
## only puts last frame's bones back to rest, so the file's animations blend from a clean pose, and lay_over(), called
## once they are written, adds the turns, shifts and scales on top of them.
## A turn is still about the bone's own pivot in the model frame, as if the bone were at rest: over an animated bone
## it is carried along with that bone's own motion.


## Puts every bone laid over last frame back to its rest; this frame's turns wait for lay_over().
func commit() -> void:
	for k: int in _posed:
		var rest := skeleton.get_bone_rest(k)
		skeleton.set_bone_pose_rotation(k, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_position(k, rest.origin)
		skeleton.set_bone_pose_scale(k, Vector3.ONE)
	_posed.clear()


## Adds this frame's turns, shifts and scales to the pose the skeleton holds now.
func lay_over() -> void:
	var inv := _frame.inverse()
	for k: int in _turns:
		var g: Quaternion = _global[k]
		var q: Quaternion = inv * (_turns[k] as Quaternion) * _frame
		skeleton.set_bone_pose_rotation(
			k, (skeleton.get_bone_pose_rotation(k) * (g.inverse() * q * g)).normalized()
		)
	for k: int in _shifts:
		var parent := skeleton.get_bone_parent(k)
		var pg: Quaternion = _global[parent] if parent >= 0 else Quaternion.IDENTITY
		skeleton.set_bone_pose_position(
			k,
			(
				skeleton.get_bone_pose_position(k)
				+ pg.inverse() * (inv * (_shifts[k] as Vector3)) / _scale
			)
		)
	for k: int in _scales:
		skeleton.set_bone_pose_scale(k, skeleton.get_bone_pose_scale(k) * float(_scales[k]))
	for d: Dictionary in [_turns, _shifts, _scales]:
		for k in d:
			_posed[k] = true
		d.clear()
