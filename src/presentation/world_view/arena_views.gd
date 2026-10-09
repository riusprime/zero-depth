class_name ArenaViews
extends Node3D
## The sealed arenas (v0.5.5 AR; PLAN D2, X1 "Others go dark when sealed"). Presentation only: reads
## WorldReader.arenas() and the floor's rooms and doorways (EI-07); every fade is cosmetic.
## - Each regular arena's doorways wear an amber frame (the Overrun keeps its red ones, OverrunDoorViews), dimmed once
##   the arena is cleared.
## - While an arena is sealed, a glowing barrier stands in each of its doorways (the sim's barriers: amber, red in the
##   Overrun) and the rest of the floor goes dark: a dark veil over every other room. The veil is a layer of its own
##   on top of the stage: the biome's lighting mood (StageView: sun, ambient, fog, SSAO, the kit's lights) is never
##   touched, so it comes back as it was the moment the doors open. The minimap still shows the whole layout.

const AMBER := Color("#FFB020")
const RED := Color("#FF3B30")
const FRAME_ENERGY := 1.8
const FRAME_ENERGY_CLEARED := 0.2
const JAMB_HEIGHT := 2.4
const JAMB_W := 0.3
const FRAME_DEPTH := 0.45
const BARRIER_HEIGHT := 2.2
## The veil: how high it stands over a room (m), how dark it is, and how fast it fades (alpha per second).
const VEIL_HEIGHT := 2.2
const VEIL_ALPHA := 0.82
const VEIL_FADE := 2.6

var frame_material := StandardMaterial3D.new()
var veil_material := StandardMaterial3D.new()
var _barrier_amber := StandardMaterial3D.new()
var _barrier_red := StandardMaterial3D.new()
var _frames: Array[Node3D] = []
var _veils: Array[MeshInstance3D] = []
var _barriers: Array[MeshInstance3D] = []
var _sealed := -1
var _cleared_count := -1
var _veil_target := 0.0
var _veil_alpha := 0.0


func _init() -> void:
	name = "Arenas"
	frame_material.albedo_color = AMBER
	frame_material.emission_enabled = true
	frame_material.emission = AMBER
	frame_material.emission_energy_multiplier = FRAME_ENERGY
	for pair: Array in [[_barrier_amber, AMBER], [_barrier_red, RED]]:
		var m: StandardMaterial3D = pair[0]
		var c: Color = pair[1]
		m.albedo_color = Color(c, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	veil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil_material.albedo_color = Color(0.01, 0.012, 0.02, 0.0)
	veil_material.render_priority = 2


func setup(reader: WorldReader) -> void:
	var a := reader.arenas()
	if not a["active"]:
		return
	var over: int = a["overrun"]
	for room: int in a["rooms"]:
		if room == over:
			continue
		for d in reader.floor_door_count():
			var dr := reader.floor_door_rooms(d)
			if dr.x == room or dr.y == room:
				_frames.append(_frame(reader.floor_door_rect(d), reader.floor_door_angle(d)))
	for r in reader.floor_room_count():
		var v := MeshInstance3D.new()
		v.name = "Veil%d" % r
		var rect := reader.floor_room(r)
		var b := BoxMesh.new()
		b.size = Vector3(rect.size.x, VEIL_HEIGHT, rect.size.y)
		v.mesh = b
		v.position = SimPlane.to_3d(rect.get_center(), VEIL_HEIGHT * 0.5)
		v.material_override = veil_material
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v.visible = false
		add_child(v)
		_veils.append(v)


func sync(reader: WorldReader) -> void:
	var a := reader.arenas()
	if not a["active"]:
		return
	var sealed: int = a["sealed"]
	if sealed != _sealed:
		_sealed = sealed
		_build_barriers(reader, bool(a["overrun_sealed"]))
		_veil_target = VEIL_ALPHA if sealed >= 0 else 0.0
		for r in _veils.size():
			if sealed >= 0:
				_veils[r].visible = r != sealed
	var cleared: PackedInt32Array = a["cleared"]
	if cleared.size() != _cleared_count:
		_cleared_count = cleared.size()
		var any_open := false
		for room: int in a["rooms"]:
			if room != a["overrun"] and not cleared.has(room):
				any_open = true
		frame_material.emission_energy_multiplier = (
			FRAME_ENERGY if any_open else FRAME_ENERGY_CLEARED
		)


func _process(delta: float) -> void:
	if is_equal_approx(_veil_alpha, _veil_target):
		return
	_veil_alpha = move_toward(_veil_alpha, _veil_target, delta * VEIL_FADE)
	veil_material.albedo_color.a = _veil_alpha
	if _veil_alpha <= 0.0:
		for v in _veils:
			v.visible = false


## Tests: the doorway frames, the barriers standing, the rooms veiled now (and the veil's target darkness).
func frame_count() -> int:
	return _frames.size()


func barrier_count() -> int:
	return _barriers.size()


func veiled_rooms() -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in _veils.size():
		if _veils[r].visible and _veil_target > 0.0:
			out.append(r)
	return out


func veil_target() -> float:
	return _veil_target


func _build_barriers(reader: WorldReader, overrun: bool) -> void:
	for b in _barriers:
		b.queue_free()
	_barriers.clear()
	for rect in reader.arena_barriers():
		var m := MeshInstance3D.new()
		m.name = "ArenaBarrier"
		var box := BoxMesh.new()
		box.size = Vector3(rect.size.x, BARRIER_HEIGHT, rect.size.y)
		m.mesh = box
		m.position = SimPlane.to_3d(rect.get_center(), BARRIER_HEIGHT * 0.5)
		m.material_override = _barrier_red if overrun else _barrier_amber
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_barriers.append(m)


## An amber frame over the doorway `rect` (the passage through the wall) whose rooms face along `angle`.
func _frame(rect: Rect2, angle: int) -> Node3D:
	var root := Node3D.new()
	root.name = "ArenaFrame"
	add_child(root)
	root.position = SimPlane.to_3d(rect.get_center())
	var along_x := angle % 2048 == 0
	var width := rect.size.y if along_x else rect.size.x
	var depth := rect.size.x if along_x else rect.size.y
	var across := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var d := minf(depth, FRAME_DEPTH)
	var thick := Vector3(d, 0, 0) if along_x else Vector3(0, 0, d)
	for side in [-1.0, 1.0]:
		_box(
			root,
			thick + across * JAMB_W + Vector3(0, JAMB_HEIGHT, 0),
			across * side * (width * 0.5 + JAMB_W * 0.5) + Vector3(0, JAMB_HEIGHT * 0.5, 0)
		)
	_box(
		root,
		thick + across * (width + JAMB_W * 2.0) + Vector3(0, 0.25, 0),
		Vector3(0, JAMB_HEIGHT, 0)
	)
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
