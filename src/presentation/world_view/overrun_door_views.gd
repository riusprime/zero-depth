class_name OverrunDoorViews
extends Node3D
## The Overrun room's doorways (v0.4.0 AB): each framed in red — two glowing jambs and a lintel across the gap, a red
## strip on the floor of the passage. The frames dim once the room is cleared. Presentation only: reads
## WorldReader.overrun() and the floor's doorways (EI-07). The frame's emission is set once when it is built; clearing
## only lowers its energy (emission_enabled is never toggled at runtime).

const RED := Color("#E2321F")
const ENERGY := 2.2
const ENERGY_CLEARED := 0.2
const JAMB_HEIGHT := 2.6
const JAMB_W := 0.35
const FRAME_DEPTH := 0.5

var frame_material := StandardMaterial3D.new()
var _frames: Array[Node3D] = []
var _cleared := false


func _init() -> void:
	name = "OverrunDoors"
	frame_material.albedo_color = RED
	frame_material.emission_enabled = true
	frame_material.emission = RED
	frame_material.emission_energy_multiplier = ENERGY


func setup(reader: WorldReader) -> void:
	var o := reader.overrun()
	if not o["active"]:
		return
	for d: int in o["doors"]:
		_frames.append(_frame(reader.floor_door_rect(d), reader.floor_door_angle(d)))


func sync(reader: WorldReader) -> void:
	if _frames.is_empty():
		return
	var cleared: bool = reader.overrun()["cleared"]
	if cleared != _cleared:
		_cleared = cleared
		frame_material.emission_energy_multiplier = ENERGY_CLEARED if cleared else ENERGY


## The number of framed doorways (tests).
func frame_count() -> int:
	return _frames.size()


func is_lit() -> bool:
	return frame_material.emission_energy_multiplier > 1.0


## A frame over the doorway `rect` (the passage through the wall) whose rooms face along `angle`.
func _frame(rect: Rect2, angle: int) -> Node3D:
	var root := Node3D.new()
	root.name = "OverrunFrame"
	add_child(root)
	var c := rect.get_center()
	root.position = SimPlane.to_3d(c)
	var along_x := angle % 2048 == 0  # the rooms face along x: the gap runs along sim y
	var width := rect.size.y if along_x else rect.size.x
	var depth := rect.size.x if along_x else rect.size.y
	# Local boxes in 3D: sim y is -z.
	var across := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var d := minf(depth, FRAME_DEPTH)  # a slim frame in the middle of the passage, however thick the wall
	var thick := Vector3(d, 0, 0) if along_x else Vector3(0, 0, d)
	for side in [-1.0, 1.0]:
		var size := thick + across * JAMB_W + Vector3(0, JAMB_HEIGHT, 0)
		_box(
			root,
			size,
			across * side * (width * 0.5 + JAMB_W * 0.5) + Vector3(0, JAMB_HEIGHT * 0.5, 0)
		)
	_box(
		root,
		thick + across * (width + JAMB_W * 2.0) + Vector3(0, 0.3, 0),
		Vector3(0, JAMB_HEIGHT, 0)
	)
	var strip := Vector3(depth, 0, 0) if along_x else Vector3(0, 0, depth)
	_box(root, strip + across * width * 0.3 + Vector3(0, 0.02, 0), Vector3(0, 0.02, 0))
	return root


func _box(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = at
	m.material_override = frame_material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
