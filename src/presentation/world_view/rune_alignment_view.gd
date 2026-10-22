class_name RuneAlignmentView
extends Node3D
## v0.9.0 RA (owner W §4 A: "Several rune pillars can be rotated. The player aligns symbols according to a visual clue
## to unlock a reward"; Q22 "3 pillars, 4 faces"; Q23 the hidden room unseen until it opens; W3 understood in under
## 5 s; docs/art/requests/v0.9.0_ART_LIST.md §3.2): the floor's rune puzzle, reading only (WorldReader.rune_*,
## interactable_*).
## - The pillars (`rune_pillar` through ShopModels when the owner's model is listed, else this code stand-in): a square
##   stone drum on a round base under a capstone, one symbol (RuneGlyphs) on each of its four sides. Each pillar stands
##   turned to the camera, so the face it shows is the one facing you; that symbol is lit, the three turned away are
##   dark. A turn (the press) grinds the drum a quarter round over TURN_S (the `pillar_turn` sound is AudioEvents').
##   A face that matches the carving glows amber. Each pillar's capstone carries its own colour and 1, 2 or 3 notches.
## - The clue (`rune_mural`, the same way): a carved panel on the face of the slab that seals the hidden room's
##   doorway, three sockets in a row, each with its symbol and framed in the colour and notches of the pillar that must
##   show it.
## - Solved: all three faces and the carving flare (FLARE_S), the slab sinks into the floor (SINK_S) and the hidden
##   room (StageView.reveal_hidden) comes into sight with a warm light inside.

const AMBER := Color("#FFB347")
const GLYPH := Color("#9FD8FF")
const STONE := Color("#5A544C")
## Each pillar's colour, on its capstone and on its socket's frame in the carving.
const PILLAR_COLORS: Array[Color] = [Color("#E0604A"), Color("#5FC46A"), Color("#5F8FE8")]
const SLAB_H := 3.0
const SLAB_T := 0.5
const DRUM_H := 1.5
const DRUM_W := 0.8
const BASE_H := 0.3
const CAM_YAW := PI * 0.25
const TURN_S := 0.35
const SINK_S := 1.1
const FLARE_S := 1.2
const MODEL_PILLAR := &"rune_pillar"
const MODEL_MURAL := &"rune_mural"

var slab: Node3D
var revealed := false
var uses_model := false
## Per pillar: the face shown, how lit that face is (0.35 shown, 1 matched) and the solved flare (0 .. 1).
var shown := PackedInt32Array()
var glow := PackedFloat32Array()
var flare := 0.0
var _reader: WorldReader
var _stage: StageView
var _drums: Array[Node3D] = []
var _glyph_mats: Array = []
var _mural_mats: Array[StandardMaterial3D] = []
var _stone := StandardMaterial3D.new()
var _room_light: OmniLight3D
var _yaw := PackedFloat32Array()
var _sink := 0.0
var _flare_t := -1.0


func setup(reader: WorldReader, stage: StageView, cover: Color) -> void:
	name = "RuneAlignment"
	_reader = reader
	_stage = stage
	_stone.albedo_color = cover.darkened(0.2) if cover != Color() else STONE
	_stone.roughness = 1.0
	var door := Node3D.new()
	door.name = "Door"
	door.position = SimPlane.to_3d(reader.rune_door_center())
	door.rotation.y = SimPlane.yaw_of(reader.rune_door_angle())
	add_child(door)
	_build_slab(door, reader.rune_door_width())
	for k in reader.rune_pillar_count():
		_build_pillar(k, reader.interactable_pos(reader.rune_pillar_entry(k)))
	_room_light = OmniLight3D.new()
	_room_light.name = "RoomLight"
	_room_light.light_color = Color("#FFE7B8")
	_room_light.omni_range = 9.0
	_room_light.light_energy = 1.6
	_room_light.shadow_enabled = false
	_room_light.position = SimPlane.to_3d(reader.floor_room(reader.rune_room()).get_center(), 2.6)
	_room_light.visible = false
	add_child(_room_light)
	for k in reader.rune_pillar_count():
		shown.append(reader.rune_face(k))
		_yaw.append(_face_yaw(reader.rune_face(k)))
		_drums[k].rotation.y = _yaw[k]
	glow.resize(reader.rune_pillar_count())
	if reader.rune_solved():
		_sink = 1.0
	sync(reader)
	_apply_slab()


func sync(reader: WorldReader) -> void:
	var solved := reader.rune_solved()
	for k in shown.size():
		var face := reader.rune_face(k)
		if face != shown[k]:
			shown[k] = face
			_yaw[k] = _face_yaw(face)
		var matched := face == reader.rune_target(k)
		glow[k] = 1.0 if matched else 0.35
		var mats: Array = _glyph_mats[k]
		for f in mats.size():
			var m: StandardMaterial3D = mats[f]
			var lit := glow[k] if f == face else 0.0
			m.emission = AMBER if matched and f == face else GLYPH
			m.emission_energy_multiplier = 0.05 + 2.4 * lit + 4.0 * flare
	if solved and _flare_t < 0.0:
		_flare_t = 0.0 if reader.tick() - reader.rune_solve_tick() < 30 else FLARE_S
	for m in _mural_mats:
		m.emission_energy_multiplier = 0.6 + 4.0 * flare
	if solved and not revealed:
		revealed = true
		_room_light.visible = true
		if _stage != null:
			_stage.reveal_hidden(reader.rune_room())


func _process(delta: float) -> void:
	for k in _drums.size():
		var d := _drums[k]
		var diff := wrapf(_yaw[k] - d.rotation.y, -PI, PI)
		if absf(diff) > 0.001:
			var step := (PI * 0.5) * delta / TURN_S
			d.rotation.y += clampf(diff, -step, step)
	if _flare_t >= 0.0 and _flare_t < FLARE_S:
		_flare_t = minf(FLARE_S, _flare_t + delta)
		flare = sin(PI * _flare_t / FLARE_S)
	if revealed and _sink < 1.0:
		_sink = minf(1.0, _sink + delta / SINK_S)
		_apply_slab()


## The drum's turn that brings face `face` to the front (toward the camera).
static func _face_yaw(face: int) -> float:
	return -PI * 0.5 * face


func pillar_count() -> int:
	return _drums.size()


## The drum of pillar k (tests read its turn).
func drum(k: int) -> Node3D:
	return _drums[k]


func _apply_slab() -> void:
	if slab == null:
		return
	slab.position.y = -SLAB_H * _sink
	slab.visible = _sink < 0.999


## The slab across the doorway (local +X into the hidden room) and the carving on its host face (-X).
func _build_slab(door: Node3D, width: float) -> void:
	slab = Node3D.new()
	slab.name = "Slab"
	door.add_child(slab)
	_box(slab, Vector3(SLAB_T, SLAB_H, width - 0.04), Vector3(0, SLAB_H * 0.5, 0), _stone)
	var mural := Node3D.new()
	mural.name = "Mural"
	mural.position = Vector3(-SLAB_T * 0.5 - 0.02, 1.6, 0)
	mural.rotation.y = -PI * 0.5  # its front (+Z) faces the host (-X)
	slab.add_child(mural)
	var model := ShopModels.get_model(MODEL_MURAL)
	if not model.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = model["mesh"]
		mi.set_surface_override_material(0, model["material"])
		mural.add_child(mi)
	else:
		_box(mural, Vector3(minf(2.4, width - 0.2), 1.6, 0.12), Vector3.ZERO, _stone)
	var n := _reader.rune_pillar_count()
	var span := minf(2.4, width - 0.2)
	for k in n:
		var x := (float(k) - (n - 1) * 0.5) * span / n
		var frame := StandardMaterial3D.new()
		frame.albedo_color = PILLAR_COLORS[k % PILLAR_COLORS.size()].darkened(0.4)
		frame.emission_enabled = true
		frame.emission = PILLAR_COLORS[k % PILLAR_COLORS.size()]
		frame.emission_energy_multiplier = 0.6
		_mural_mats.append(frame)
		var sock := _box(mural, Vector3(0.62, 0.62, 0.04), Vector3(x, 0.15, 0.08), frame)
		sock.name = "Socket%d" % k
		var g := RuneGlyphs.build(_reader.rune_target(k), 0.44, frame)
		g.position = Vector3(x, 0.15, 0.12)
		mural.add_child(g)
		for j in k + 1:  # the pillar's notches under its socket
			_box(
				mural,
				Vector3(0.08, 0.08, 0.04),
				Vector3(x + (j - k * 0.5) * 0.14, -0.4, 0.08),
				frame
			)


## Pillar k: a round base, the turning drum with a symbol on each side, a capstone in the pillar's colour.
func _build_pillar(k: int, at: Vector2) -> void:
	var root := Node3D.new()
	root.name = "RunePillar%d" % k
	root.position = SimPlane.to_3d(at)
	root.rotation.y = CAM_YAW
	add_child(root)
	var base := CylinderMesh.new()
	base.top_radius = 0.5
	base.bottom_radius = 0.55
	base.height = BASE_H
	base.radial_segments = 12
	var b := MeshInstance3D.new()
	b.name = "Base"
	b.mesh = base
	b.material_override = _stone
	b.position.y = BASE_H * 0.5
	root.add_child(b)
	var drum_node := Node3D.new()
	drum_node.name = "Drum"
	drum_node.position.y = BASE_H
	root.add_child(drum_node)
	_drums.append(drum_node)
	var model := ShopModels.get_model(MODEL_PILLAR)
	if not model.is_empty():
		uses_model = true
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = model["mesh"]
		mi.set_surface_override_material(0, model["material"])
		mi.position.y = -BASE_H
		drum_node.add_child(mi)
	else:
		_box(drum_node, Vector3(DRUM_W, DRUM_H, DRUM_W), Vector3(0, DRUM_H * 0.5, 0), _stone)
	var mats := []
	for f in RuneGlyphs.COUNT:
		var m := StandardMaterial3D.new()
		m.albedo_color = GLYPH.darkened(0.7)
		m.emission_enabled = true
		m.emission = GLYPH
		m.emission_energy_multiplier = 0.05
		mats.append(m)
		var side := Node3D.new()
		side.rotation.y = PI * 0.5 * f
		drum_node.add_child(side)
		var g := RuneGlyphs.build(f, 0.5, m)
		g.position = Vector3(0, DRUM_H * 0.55, DRUM_W * 0.5 + 0.03)
		side.add_child(g)
	_glyph_mats.append(mats)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = PILLAR_COLORS[k % PILLAR_COLORS.size()].darkened(0.3)
	cap_mat.emission_enabled = true
	cap_mat.emission = PILLAR_COLORS[k % PILLAR_COLORS.size()]
	cap_mat.emission_energy_multiplier = 0.5
	var top := BASE_H + DRUM_H
	_box(root, Vector3(DRUM_W + 0.16, 0.22, DRUM_W + 0.16), Vector3(0, top + 0.11, 0), cap_mat)
	for j in k + 1:  # its notches, on the capstone's front
		_box(
			root,
			Vector3(0.08, 0.08, 0.04),
			Vector3((j - k * 0.5) * 0.14, top + 0.11, DRUM_W * 0.5 + 0.1),
			_stone
		)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node
