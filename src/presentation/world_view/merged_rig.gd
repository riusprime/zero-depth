class_name MergedRig
extends Skeleton3D
## v0.9.5 PF5 (owner, 2026-10-26: "merge the enemy's pieces only if that does not change how animations look"): the
## skeleton of one enemy's merged body. Each bone mirrors one Node3D of the avatar's rig (a joint or a piece), so the
## avatar's animation code keeps writing the very same transforms to those nodes; the avatar copies them to the bones
## (update_bones, from its _process, only the ones that changed). A hidden node folds its bone to a point.
## Presentation only (EI-07): nothing here reads or writes the sim.

## What a hidden node's bone is scaled to (a point: its triangles vanish).
const HIDDEN_SCALE := 1e-5

## The avatar's nodes the bones follow, in bone order (a parent comes before its children).
var nodes: Array[Node3D] = []
var _last: Array[Transform3D] = []
var _hidden: PackedByteArray = PackedByteArray()


func _init() -> void:
	modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL


## Called once the bones exist: remembers the nodes (each bone's rest pose is its node's transform now).
func bind_nodes(p_nodes: Array[Node3D]) -> void:
	nodes = p_nodes
	_last.clear()
	_hidden.resize(nodes.size())
	for i in nodes.size():
		_last.append(nodes[i].transform)
		_hidden[i] = 0


## Copies every changed node transform (or visibility) to its bone. True when any bone moved.
func update_bones() -> bool:
	var moved := false
	for i in nodes.size():
		var n := nodes[i]
		var t := n.transform
		var hide := not n.visible
		if hide:
			if _hidden[i] == 1:
				continue
			_hidden[i] = 1
			t = Transform3D(Basis.from_scale(Vector3.ONE * HIDDEN_SCALE), t.origin)
		elif _hidden[i] == 1 or t != _last[i]:
			_hidden[i] = 0
		else:
			continue
		_last[i] = n.transform
		set_bone_pose(i, t)
		moved = true
	if moved:
		force_update_all_bone_transforms()
	return moved
