class_name TimedDoorView
extends Node3D
## v0.9.0 TD (owner W §2 presentation: "Slow beeps at first. Increasing frequency as time passes. Very fast beeping
## immediately before closure. A heavy impact when the door shuts. Include visual feedback, such as flashing runes, for
## accessibility"; Q23: the hidden room unseen until it opens; docs/art/requests/v0.9.0_ART_LIST.md §3.2): the floor's
## timed door and its two rune switches, reading only (WorldReader.timed_*, interactable_*).
## - The door: a heavy stone slab in a thick carved frame, a circular rune seal in its middle and rune notches round
##   the frame (the owner's `timed_door` model through ShopModels when it is listed, else this code stand-in). Shut it
##   stands in the doorway; opened it sinks into the floor (SINK_S); on the shut it slams back up (SLAM_S) and `slammed`
##   asks the camera for the door's thud (the impact sound is AudioEvents').
## - The switches: short octagonal stone columns with a rune disc on a slanted top (`rune_switch`, the same way). A
##   switch that is on glows amber; off, its rune is dark.
## - While the timer runs, every beep (beep_ticks: slow at first, faster and faster, very fast at the end; the same
##   schedule AudioEvents plays) flashes the seal, the frame's notches and the switches' runes: the beep seen.
## - The secret room (StageView.reveal_hidden) comes into sight when the door first opens, with a warm light inside.

const AMBER := Color("#FFB347")
const AMBER_CORE := Color("#FFE7B8")
const STONE := Color("#5A544C")
const SLAB_H := 3.0
const SLAB_T := 0.5
const FRAME_W := 0.45
const SWITCH_H := 1.0
## The slab's sink when the door opens and its slam when it shuts (s).
const SINK_S := 1.1
const SLAM_S := 0.14
## The beeps: the gap between two (ticks) is BEEP_SLOW at the start, shrinking with the time left to BEEP_FAST.
const BEEP_SLOW := 60
const BEEP_FAST := 6
## A beep's flash fades over this many ticks.
const FLASH_TICKS := 8
const MODEL_DOOR := &"timed_door"
const MODEL_SWITCH := &"rune_switch"

static var _schedules := {}

## True on the sync the door shut (the camera's thud).
var slammed := false
## How lit each switch's rune is now (0 off .. 1 on), and the beep flash (0 .. 1); tests read them.
var switch_glow := PackedFloat32Array()
var flash := 0.0
var slab: Node3D
var uses_model := false
var revealed := false
var _reader: WorldReader
var _stage: StageView
var _switch_roots: Array[Node3D] = []
var _switch_mats: Array[StandardMaterial3D] = []
var _seal_mat := StandardMaterial3D.new()
var _stone := StandardMaterial3D.new()
var _room_light: OmniLight3D
var _state := -1
## The slab's height share: 0 standing, 1 sunk; and its target.
var _sink := 0.0
var _open := false


func setup(reader: WorldReader, stage: StageView, cover: Color) -> void:
	name = "TimedDoor"
	_reader = reader
	_stage = stage
	_stone.albedo_color = cover.darkened(0.2) if cover != Color() else STONE
	_stone.roughness = 1.0
	_seal_mat.albedo_color = AMBER.darkened(0.6)
	_seal_mat.emission_enabled = true
	_seal_mat.emission = AMBER
	_seal_mat.emission_energy_multiplier = 0.2
	var door := Node3D.new()
	door.name = "Door"
	door.position = SimPlane.to_3d(reader.timed_door_center())
	door.rotation.y = SimPlane.yaw_of(reader.timed_door_angle())
	add_child(door)
	_build_door(door, reader.timed_door_width(), reader.timed_door_depth())
	for k in reader.timed_switch_count():
		_build_switch(
			k, reader.interactable_pos(reader.timed_switch_entry(k)), reader.timed_door_center()
		)
	_room_light = OmniLight3D.new()
	_room_light.name = "RoomLight"
	_room_light.light_color = AMBER_CORE
	_room_light.omni_range = 9.0
	_room_light.light_energy = 1.6
	_room_light.shadow_enabled = false
	_room_light.position = SimPlane.to_3d(reader.floor_room(reader.timed_room()).get_center(), 2.6)
	_room_light.visible = false
	add_child(_room_light)
	_state = reader.timed_door_state()
	_open = _state != WorldReader.TIMED_SHUT
	_sink = 1.0 if _open else 0.0
	_reveal_if_open()
	sync(reader)
	_apply_slab()


func sync(reader: WorldReader) -> void:
	slammed = false
	var st := reader.timed_door_state()
	if st != _state:
		if st == WorldReader.TIMED_SHUT and _state != WorldReader.TIMED_SHUT:
			_open = false
			_sink = minf(_sink, 1.0)
			slammed = true
		elif st != WorldReader.TIMED_SHUT:
			_open = true
		_state = st
	_reveal_if_open()
	flash = beep_flash(reader)
	switch_glow.resize(_switch_mats.size())
	for k in _switch_mats.size():
		var on := reader.interactable_state(reader.timed_switch_entry(k)) == 1
		switch_glow[k] = 1.0 if on else 0.0
		var m := _switch_mats[k]
		m.emission_energy_multiplier = (0.1 + 2.6 * switch_glow[k]) + 3.0 * flash
		m.albedo_color = AMBER.darkened(0.75 - 0.5 * maxf(switch_glow[k], flash))
	_seal_mat.emission_energy_multiplier = (
		(0.25 if st == WorldReader.TIMED_SHUT else 0.8) + 4.0 * flash
	)


func _process(delta: float) -> void:
	if slab == null:
		return
	if _open and _sink < 1.0:
		_sink = minf(1.0, _sink + delta / SINK_S)
		_apply_slab()
	elif not _open and _sink > 0.0:
		_sink = maxf(0.0, _sink - delta / SLAM_S)
		_apply_slab()


func _apply_slab() -> void:
	if slab == null:
		return
	slab.position.y = -SLAB_H * _sink
	slab.visible = _sink < 0.999


func _reveal_if_open() -> void:
	if revealed or _reader.hidden_room() >= 0:
		return
	revealed = true
	_room_light.visible = true
	if _stage != null:
		_stage.reveal_hidden(_reader.timed_room())  # v0.9.0 RA: only its own room


## The ticks (from the door opening) each beep falls on, for a timer of `timer` ticks: the gap is BEEP_SLOW at the start
## and shrinks with the square of the time left to BEEP_FAST at the end (slow, faster, very fast before the shut).
static func beep_ticks(timer: int) -> PackedInt32Array:
	if _schedules.has(timer):
		return _schedules[timer]
	var out := PackedInt32Array()
	var t := 0
	while t < timer:
		out.append(t)
		var left := 1.0 - float(t) / float(maxi(1, timer))
		t += maxi(BEEP_FAST, roundi(BEEP_FAST + (BEEP_SLOW - BEEP_FAST) * left * left))
	_schedules[timer] = out
	return out


## How many beeps have sounded since the door opened (0 while shut or held).
static func beeps_now(reader: WorldReader) -> int:
	if reader.timed_door_state() != WorldReader.TIMED_OPEN:
		return 0
	var elapsed := reader.tick() - reader.timed_open_tick()
	var n := 0
	for b in beep_ticks(reader.timed_timer_ticks()):
		if b > elapsed:
			break
		n += 1
	return n


## The flash of the latest beep now: 1 on its tick, fading to 0 over FLASH_TICKS (0 while shut or held).
static func beep_flash(reader: WorldReader) -> float:
	var n := beeps_now(reader)
	if n == 0:
		return 0.0
	var last := beep_ticks(reader.timed_timer_ticks())[n - 1]
	var since := reader.tick() - reader.timed_open_tick() - last
	return clampf(1.0 - float(since) / FLASH_TICKS, 0.0, 1.0)


## The frame (two jambs, a lintel with rune notches) and the slab with its seal. Local +X points into the secret room.
func _build_door(door: Node3D, width: float, depth: float) -> void:
	var d := maxf(depth, 0.6) + 0.2
	for side in [-1.0, 1.0]:
		_box(
			door,
			Vector3(d, SLAB_H + 0.4, FRAME_W),
			Vector3(0, (SLAB_H + 0.4) * 0.5, side * (width * 0.5 + FRAME_W * 0.5)),
			_stone
		)
		for j in 3:
			var notch := _box(
				door,
				Vector3(0.06, 0.22, 0.22),
				Vector3(-d * 0.5 - 0.03, 0.7 + j * 0.9, side * (width * 0.5 + FRAME_W * 0.5)),
				_seal_mat
			)
			notch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(
		door,
		Vector3(d + 0.1, 0.5, width + FRAME_W * 2.0 + 0.1),
		Vector3(0, SLAB_H + 0.55, 0),
		_stone
	)
	slab = Node3D.new()
	slab.name = "Slab"
	door.add_child(slab)
	var model := ShopModels.get_model(MODEL_DOOR)
	if not model.is_empty():
		uses_model = true
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = model["mesh"]
		mi.set_surface_override_material(0, model["material"])
		mi.scale = Vector3(1.0, 1.0, width / 3.0)
		slab.add_child(mi)
	else:
		_box(slab, Vector3(SLAB_T, SLAB_H, width - 0.04), Vector3(0, SLAB_H * 0.5, 0), _stone)
		for bolt in [-0.6, 0.6]:  # the two iron bolts across it
			var b := _box(
				slab,
				Vector3(SLAB_T + 0.08, 0.14, width - 0.3),
				Vector3(0, SLAB_H * 0.5 + bolt, 0),
				_stone
			)
			b.material_override = _iron()
	for face in [-1.0, 1.0]:  # the round rune seal, on both faces
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 0.05
		cyl.radial_segments = 20
		var disc := MeshInstance3D.new()
		disc.name = "Seal"
		disc.mesh = cyl
		disc.material_override = _seal_mat
		disc.rotation.z = PI * 0.5
		disc.position = Vector3(face * (SLAB_T * 0.5 + 0.06), SLAB_H * 0.5, 0)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slab.add_child(disc)


## Switch k: an octagonal column with a slanted top holding its rune disc, turned to face the door.
func _build_switch(k: int, at: Vector2, toward: Vector2) -> void:
	var root := Node3D.new()
	root.name = "RuneSwitch%d" % k
	root.position = SimPlane.to_3d(at)
	var to := SimPlane.to_3d(toward) - root.position
	root.rotation.y = atan2(to.x, to.z)
	add_child(root)
	_switch_roots.append(root)
	var rune := StandardMaterial3D.new()
	rune.albedo_color = AMBER.darkened(0.75)
	rune.emission_enabled = true
	rune.emission = AMBER
	rune.emission_energy_multiplier = 0.1
	_switch_mats.append(rune)
	var model := ShopModels.get_model(MODEL_SWITCH)
	if not model.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = model["mesh"]
		mi.set_surface_override_material(0, model["material"])
		root.add_child(mi)
	else:
		var col := CylinderMesh.new()
		col.top_radius = 0.3
		col.bottom_radius = 0.36
		col.height = SWITCH_H
		col.radial_segments = 8
		col.rings = 1
		var body := MeshInstance3D.new()
		body.name = "Column"
		body.mesh = AltarStage.faceted(col)
		body.material_override = _stone
		body.position = Vector3(0, SWITCH_H * 0.5, 0)
		root.add_child(body)
		var lever := _box(root, Vector3(0.1, 0.42, 0.12), Vector3(0.36, SWITCH_H * 0.75, 0), _stone)
		lever.rotation.z = -0.4
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.24
	disc_mesh.bottom_radius = 0.24
	disc_mesh.height = 0.05
	disc_mesh.radial_segments = 16
	var disc := MeshInstance3D.new()
	disc.name = "Rune"
	disc.mesh = disc_mesh
	disc.material_override = rune
	disc.position = Vector3(0, SWITCH_H + 0.04, 0.04)
	disc.rotation.x = 0.45  # the slanted top, toward the door
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)


func switch_count() -> int:
	return _switch_roots.size()


func _iron() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#2E2B29")
	m.metallic = 0.6
	m.roughness = 0.6
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node
