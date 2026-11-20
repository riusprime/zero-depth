class_name TimedDoorView
extends Node3D
## v0.9.0 TD (owner W §2 presentation: "Slow beeps at first. Increasing frequency as time passes. Very fast beeping
## immediately before closure. A heavy impact when the door shuts. Include visual feedback, such as flashing runes, for
## accessibility"; Q23: the hidden room unseen until it opens; docs/art/requests/v0.9.0_ART_LIST.md §3.2): the floor's
## timed door and its two rune switches, reading only (WorldReader.timed_*, interactable_*).
## - The door: a heavy stone slab with a circular rune seal in its middle, in a frame of the floor's own wall blocks
##   (TimedDoorFrame: square jambs and a lintel in the walls' material, as deep as the doorway, a gate a little over
##   the walls, so it reads as part of the wall), rune notches down the jambs. The slab is the owner's from
##   `timed_door` through ShopModels when it is listed (cut by scripts/assets/props_v0120_prep.py; his rounded jambs,
##   lintel and sill stay in the model but are not drawn, as they did not fit the walls), tinted per biome; else a code
##   stand-in. Shut it stands in the doorway; opened it sinks into the floor (SINK_S); on the shut it slams back up
##   (SLAM_S) and `slammed` asks the camera for the door's thud (the impact sound is AudioEvents'). The seal's lit ring
##   lies on the slab's carved one.
## - The switches: short octagonal stone columns with a rune disc on a slanted top (`rune_switch`, the same way). A
##   switch that is on glows amber; off, its rune is dark.
## - v0.9.5 TS: the lever inside the secret room, a short stone post with a handle (code stand-in), on the
##   wall beside the doorway. Door shut, the handle stands up and its tip glows; pulled (the door open) it swings down.
## - While the timer runs, every beep (beep_ticks: slow at first, faster and faster, very fast at the end; the same
##   schedule AudioEvents plays) flashes the seal, the frame's notches and the switches' runes: the beep seen.
## - The secret room (StageView.reveal_hidden) comes into sight when the door first opens, with a warm light inside.
## - v0.9.0 BV: per biome (InteractionLooks, the stage's prop_style): the seal's, notches' and switches' rune
##   colour (Ruins amber, Night Rocks mint, Red Canyon copper, Frozen Shore ice, Starfall magenta), the bolts' metal,
##   the room's light, the owner's switch model tinted, and the biome's accent at the jambs' and switches' feet.

const AMBER := Color("#FFB347")
const AMBER_CORE := Color("#FFE7B8")
const STONE := Color("#5A544C")
## The code stand-in slab's height (m): its top hidden in the lintel.
const SLAB_H := 2.3
const SLAB_T := 0.5
const SWITCH_H := 1.0
## The slab's sink when the door opens and its slam when it shuts (s).
const SINK_S := 1.1
const SLAM_S := 0.14
## The lever handle's swing time (s) and its up and down tilt (rad).
const PULL_S := 0.25
const LEVER_UP := 0.7
const LEVER_DOWN := -0.7
## The beeps: the gap between two (ticks) is BEEP_SLOW at the start, shrinking with the time left to BEEP_FAST.
const BEEP_SLOW := 60
const BEEP_FAST := 6
## A beep's flash fades over this many ticks.
const FLASH_TICKS := 8
const MODEL_DOOR := &"timed_door"
## The owner's slab as prepared (m): its width (the frame's opening), how high its top stands (its foot on the
## sill), its faces (x from the middle) and the middle of its carved seal (y).
const DOOR_OPENING := 2.677
const DOOR_SLAB_TOP := 3.42
const DOOR_SLAB_FACE := 0.377
const DOOR_SEAL_Y := 1.9
## The slab's part of the owner's door (ShopModels.parts; the others, his jambs and middle, are not drawn).
const DOOR_SLAB := 3
const MODEL_SWITCH := &"rune_switch"
## On the owner's switch (1.3 m, its slanted top falling toward the door) the lit rune disc lies on the
## middle of the slant: its centre (m, the switch's frame) and its tilt (rad), measured from the prepared model.
const MODEL_RUNE_AT := Vector3(0.0, 1.2, 0.0)
const MODEL_RUNE_TILT := 0.58

static var _schedules := {}

## True on the sync the door shut (the camera's thud).
var slammed := false
## How lit each switch's rune is now (0 off .. 1 on), and the beep flash (0 .. 1); tests read them.
var switch_glow := PackedFloat32Array()
var flash := 0.0
var slab: Node3D
var uses_model := false
## The frame's material: the walls' own (tests read it).
var frame_material: Material
## The switches are the owner's model (tests read it).
var switch_uses_model := false
var revealed := false
## The biome whose look is drawn (InteractionLooks.resolve) and its rune colour.
var biome := &""
var rune_color := AMBER
## The handle's pull (0 up.. 1 down) and whether a lever stands here (tests read them).
var lever_pull := 0.0
var has_lever := false
var _reader: WorldReader
var _stage: StageView
var _switch_roots: Array[Node3D] = []
var _switch_mats: Array[StandardMaterial3D] = []
var _lever_arm: Node3D
var _lever_mat: StandardMaterial3D
var _seal_mat := StandardMaterial3D.new()
var _stone := StandardMaterial3D.new()
var _cover := Color()
var _room_light: OmniLight3D
var _state := -1
## The slab's height share: 0 standing, 1 sunk; and its target. How far it sinks (m): its top to the floor.
var _sink := 0.0
var _sink_m := SLAB_H
var _open := false


func setup(reader: WorldReader, stage: StageView, cover: Color) -> void:
	name = "TimedDoor"
	_reader = reader
	_stage = stage
	var raw := InteractionLooks.of_stage(stage)
	biome = InteractionLooks.resolve(raw)
	rune_color = InteractionLooks.color(biome, "rune")
	_cover = cover
	_stone.albedo_color = cover.darkened(0.2) if cover != Color() else STONE
	_stone.roughness = 1.0
	_seal_mat.albedo_color = rune_color.darkened(0.6)
	_seal_mat.emission_enabled = true
	_seal_mat.emission = rune_color
	_seal_mat.emission_energy_multiplier = 0.2
	var door := Node3D.new()
	door.name = "Door"
	door.position = SimPlane.to_3d(reader.timed_door_center())
	door.rotation.y = SimPlane.yaw_of(reader.timed_door_angle())
	add_child(door)
	var depth := maxf(reader.timed_door_depth(), 0.6)
	_build_door(door, reader.timed_door_width(), depth)
	for side in [-1.0, 1.0]:  # The biome's touch at each jamb's foot, on the side you come from
		var foot := Node3D.new()
		foot.name = "Foot"
		foot.position = Vector3(
			-depth * 0.5 - 0.5,
			0,
			side * (reader.timed_door_width() * 0.5 + TimedDoorFrame.JAMB * 0.5)
		)
		door.add_child(foot)
		InteractionLooks.add_accent(foot, raw, 0.35, 0.0)
	for k in reader.timed_switch_count():
		_build_switch(
			k, reader.interactable_pos(reader.timed_switch_entry(k)), reader.timed_door_center()
		)
		InteractionLooks.add_accent(_switch_roots[k], raw, 0.55, SWITCH_H)
	if reader.timed_lever_entry() >= 0:  # v0.9.5 TS
		_build_lever(
			reader.interactable_pos(reader.timed_lever_entry()), reader.timed_door_center()
		)
	_room_light = OmniLight3D.new()
	_room_light.name = "RoomLight"
	_room_light.light_color = InteractionLooks.color(biome, "room")  # Ruins: AMBER_CORE
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
		m.albedo_color = rune_color.darkened(0.75 - 0.5 * maxf(switch_glow[k], flash))
	_seal_mat.emission_energy_multiplier = (
		(0.25 if st == WorldReader.TIMED_SHUT else 0.8) + 4.0 * flash
	)
	if has_lever:  # Ready (bright tip) while the door is shut
		_lever_mat.emission_energy_multiplier = (
			(2.0 if st == WorldReader.TIMED_SHUT else 0.1) + 3.0 * flash
		)


func _process(delta: float) -> void:
	if has_lever:  # The handle swings (PULL_S), down while the door stands open
		var goal := 0.0 if _state == WorldReader.TIMED_SHUT else 1.0
		lever_pull = move_toward(lever_pull, goal, delta / PULL_S)
		_lever_arm.rotation.z = LEVER_UP - (LEVER_UP - LEVER_DOWN) * lever_pull
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
	slab.position.y = -_sink_m * _sink
	slab.visible = _sink < 0.999


func _reveal_if_open() -> void:
	if revealed or _reader.hidden_room() >= 0:
		return
	revealed = true
	_room_light.visible = true
	if _stage != null:
		_stage.reveal_hidden(_reader.timed_room())  # Only its own room


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


## The frame (TimedDoorFrame: the walls' own blocks, with rune notches on its jambs) and the slab with its seal. Local
## +X points into the secret room.
func _build_door(door: Node3D, width: float, depth: float) -> void:
	_build_frame(door, width, depth)
	if ShopModels.parts(MODEL_DOOR).size() > DOOR_SLAB:
		_build_model_slab(door, width, depth)
		return
	_sink_m = SLAB_H
	slab = Node3D.new()
	slab.name = "Slab"
	door.add_child(slab)
	_box(slab, Vector3(SLAB_T, SLAB_H, width - 0.04), Vector3(0, SLAB_H * 0.5, 0), _stone)
	for bolt in [-0.45, 0.45]:  # the two iron bolts across it
		var b := _box(
			slab,
			Vector3(SLAB_T + 0.08, 0.14, width - 0.3),
			Vector3(0, TimedDoorFrame.OPEN_H * 0.5 + bolt, 0),
			_stone
		)
		b.material_override = _iron(InteractionLooks.color(biome, "metal"))
	for face in [-1.0, 1.0]:  # the round rune seal, on both faces
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.45
		cyl.height = 0.05
		cyl.radial_segments = 20
		var disc := MeshInstance3D.new()
		disc.name = "Seal"
		disc.mesh = cyl
		disc.material_override = _seal_mat
		disc.rotation.z = PI * 0.5
		disc.position = Vector3(face * (SLAB_T * 0.5 + 0.06), TimedDoorFrame.OPEN_H * 0.5, 0)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slab.add_child(disc)


## The jambs and lintel in the walls' material, as deep as the doorway; three lit notches down each jamb's face on the
## side you come from.
func _build_frame(door: Node3D, width: float, depth: float) -> void:
	var frame := Node3D.new()
	frame.name = "Frame"
	door.add_child(frame)
	var face_m := ProceduralWall.FACE_M_DEFAULT
	var top_m := ProceduralWall.TOP_M_DEFAULT
	if _stage != null and _stage.mood != null:
		face_m = _stage.mood.wall_texture_m
		top_m = _stage.mood.wall_top_texture_m
	var blocks := MeshInstance3D.new()
	blocks.name = "Blocks"
	blocks.mesh = TimedDoorFrame.mesh(width, depth, face_m, top_m)
	frame_material = _wall_material()
	blocks.set_surface_override_material(0, frame_material)
	frame.add_child(blocks)
	for at in TimedDoorFrame.notch_spots(width, depth):
		var notch := _box(frame, Vector3(0.06, 0.2, 0.2), at, _seal_mat)
		notch.name = "Notch"
		notch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The walls' own material: on a floor whose walls are the procedural ruin (a mood and the kit), ProceduralWall's in
## the biome's wall textures and calm (StageView.wall_textures, WallCalm.look_of: what StageKit draws them with); else
## the plain box walls' cover colour.
func _wall_material() -> Material:
	if _stage != null and _stage.mood != null and KitModels.has_structure():
		var tex := StageView.wall_textures(_stage.prop_style)
		tex.merge(WallCalm.look_of(_stage.mood))
		return ProceduralWall.material(tex.get("face", null), tex.get("top", null), false, tex)
	var m := StandardMaterial3D.new()
	m.albedo_color = _cover if _cover != Color() else STONE
	m.roughness = 1.0
	return m


## The owner's slab with its carved seal in a doorway `width` across: as wide as the opening, at most its own height
## (so a wide doorway stretches the seal a little, never squashes it flat), its seal low enough in the opening that
## the slab's top stays hidden in the lintel, as thick as the owner made it (thinner only under a gate shallower than
## that); the seal's lit ring on its carved one, on both faces.
func _build_model_slab(door: Node3D, width: float, depth: float) -> void:
	uses_model = true
	var parts := ShopModels.parts(MODEL_DOOR)
	var mat := InteractionLooks.tinted(ShopModels.get_model(MODEL_DOOR)["material"], biome)
	var sz := width / DOOR_OPENING
	var sy := minf(sz, 1.0)
	var sx := clampf((TimedDoorFrame.gate_depth(depth) - 0.1) / (DOOR_SLAB_FACE * 2.0), 0.3, 1.0)
	var above := (DOOR_SLAB_TOP - DOOR_SEAL_Y) * sy
	var seal_y := minf(TimedDoorFrame.OPEN_H * 0.5, TimedDoorFrame.TOP - 0.05 - above)
	_sink_m = seal_y + above
	slab = Node3D.new()
	slab.name = "Slab"
	door.add_child(slab)
	var body := MeshInstance3D.new()
	body.name = "Model"
	body.mesh = parts[DOOR_SLAB]
	body.set_surface_override_material(0, mat)
	body.scale = Vector3(sx, sy, sz)
	body.position.y = seal_y - DOOR_SEAL_Y * sy
	slab.add_child(body)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.52
	ring.outer_radius = 0.62
	ring.rings = 24
	ring.ring_segments = 4
	for face in [-1.0, 1.0]:  # the carved seal's ring lit, on both faces
		var seal := MeshInstance3D.new()
		seal.name = "Seal"
		seal.mesh = ring
		seal.material_override = _seal_mat
		seal.rotation.z = PI * 0.5
		seal.scale = Vector3(sy, 0.3, sz)
		seal.position = Vector3(face * (DOOR_SLAB_FACE * sx + 0.02), seal_y, 0)
		seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slab.add_child(seal)


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
	rune.albedo_color = rune_color.darkened(0.75)
	rune.emission_enabled = true
	rune.emission = rune_color
	rune.emission_energy_multiplier = 0.1
	_switch_mats.append(rune)
	var model := ShopModels.get_model(MODEL_SWITCH)
	if not model.is_empty():
		switch_uses_model = true
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = model["mesh"]
		mi.set_surface_override_material(0, InteractionLooks.tinted(model["material"], biome))
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
	if switch_uses_model:
		disc.position = MODEL_RUNE_AT
		disc.rotation.x = MODEL_RUNE_TILT
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)


## The lever inside the secret room: a squat stone post with a pivoting handle, turned to face the
## doorway.
func _build_lever(at: Vector2, toward: Vector2) -> void:
	var root := Node3D.new()
	root.name = "Lever"
	root.position = SimPlane.to_3d(at)
	var to := SimPlane.to_3d(toward) - root.position
	root.rotation.y = atan2(to.x, to.z)
	add_child(root)
	_box(root, Vector3(0.5, 0.7, 0.4), Vector3(0, 0.35, 0), _stone)
	_lever_mat = StandardMaterial3D.new()
	_lever_mat.albedo_color = rune_color.darkened(0.6)
	_lever_mat.emission_enabled = true
	_lever_mat.emission = rune_color
	_lever_mat.emission_energy_multiplier = 2.0
	_lever_arm = Node3D.new()
	_lever_arm.name = "Handle"
	_lever_arm.position = Vector3(0, 0.7, 0)
	root.add_child(_lever_arm)
	_box(
		_lever_arm,
		Vector3(0.1, 0.7, 0.1),
		Vector3(0, 0.35, 0),
		_iron(InteractionLooks.color(biome, "metal"))
	)
	var tip := _box(_lever_arm, Vector3(0.22, 0.16, 0.22), Vector3(0, 0.74, 0), _lever_mat)
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	has_lever = true
	lever_pull = 0.0 if _state == WorldReader.TIMED_SHUT or _state < 0 else 1.0
	_lever_arm.rotation.z = LEVER_UP - (LEVER_UP - LEVER_DOWN) * lever_pull


func switch_count() -> int:
	return _switch_roots.size()


func _iron(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
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
