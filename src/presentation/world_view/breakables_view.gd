class_name BreakablesView
extends Node3D
## v0.9.0 DX (owner W §4 C: "Certain walls, statues, or props contain subtle visual clues indicating that they can be
## destroyed"; §5; Q23: the Skill breaks the wall, no hint text, the hidden room unseen until it breaks;
## docs/art/requests/v0.9.0_ART_LIST.md §3.2): the floor's destructibles, reading only (WorldReader.crack_*,
## breakable_*). Each piece is the owner's model through ShopModels when it is listed, else this code stand-in.
## - The cracked wall (`cracked_wall`): a stone section filling the dead end's doorway, almost like the wall round it,
##   with a faint web of cracks from one point; each Skill hit it takes darkens the cracks (CRACK_DARK). Broken
##   (`cracked_wall_broken`): a jagged frame and rubble at its foot on both sides, and the hidden room
##   (StageView.reveal_hidden) comes into sight with a warm light inside.
## - Containers (`container_crate`, `container_urn`, `container_barrel`): broken, the piece goes and a few chips fly and
##   fade (DEBRIS_S).
## - Explosive barrels (`explosive_barrel`): a battered red barrel with a fuse cap; lit, a red light on it blinks faster
##   and faster until it blows (the `barrel_fuse` sound is AudioEvents'); the blast is a flash and a ball of fire the
##   size of its reach (BLAST_S), and `blasted` asks the camera for a thud.

const STONE := Color("#5A544C")
const CRACK := Color("#2A2622")
const WOOD := Color("#7A5634")
const CLAY := Color("#A0603A")
const RED := Color("#8E2B1E")
const FIRE := Color("#FF8A2A")
const WALL_H := 3.0
## How dark the cracks are with no hit (very faint) and the share each hit adds.
const CRACK_BASE := 0.12
const CRACK_DARK := 0.25
const DEBRIS_S := 0.6
const BLAST_S := 0.35
const MODEL_WALL := &"cracked_wall"
const MODEL_WALL_BROKEN := &"cracked_wall_broken"
const MODELS := [&"container_crate", &"container_urn", &"container_barrel", &"explosive_barrel"]

## The wall section (whole) and its broken frame; the props by index; true on the sync a barrel blew (the thud).
var wall: Node3D
var rubble: Node3D
var revealed := false
var blasted := false
var props: Array[Node3D] = []
## How dark the cracks are now (CRACK_BASE .. 1) and each barrel's fuse light (0 / 1; others 0); tests read them.
var crack_shade := 0.0
var fuse_glow := PackedFloat32Array()
var _reader: WorldReader
var _stage: StageView
var _stone := StandardMaterial3D.new()
var _crack_mat := StandardMaterial3D.new()
var _room_light: OmniLight3D
var _fuse_lights: Array[OmniLight3D] = []
var _seen := PackedByteArray()
var _fx: Array = []


func setup(reader: WorldReader, stage: StageView, cover: Color) -> void:
	name = "Breakables"
	_reader = reader
	_stage = stage
	_stone.albedo_color = cover.darkened(0.15) if cover != Color() else STONE
	_stone.roughness = 1.0
	_crack_mat.albedo_color = CRACK
	_crack_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if reader.has_cracked_wall():
		_build_wall(reader)
	for i in reader.breakable_count():
		_build_prop(i, reader.breakable_kind(i), reader.breakable_pos(i))
	_seen.resize(reader.breakable_count())
	fuse_glow.resize(reader.breakable_count())
	for i in reader.breakable_count():
		_seen[i] = 1 if reader.breakable_broken(i) else 0
		props[i].visible = not reader.breakable_broken(i)
	sync(reader)


func sync(reader: WorldReader) -> void:
	blasted = false
	if wall != null:
		var hits := reader.crack_max() - reader.crack_hp()
		crack_shade = minf(1.0, CRACK_BASE + CRACK_DARK * hits)
		_crack_mat.albedo_color.a = crack_shade
		if reader.crack_broken() and not revealed:
			revealed = true
			wall.visible = false
			rubble.visible = true
			_room_light.visible = true
			if _stage != null:
				_stage.reveal_hidden(reader.crack_room())
	for i in props.size():
		if reader.breakable_broken(i) and _seen[i] == 0:
			_seen[i] = 1
			props[i].visible = false
			if reader.breakable_kind(i) == WorldReader.BREAKABLE_EXPLOSIVE:
				blasted = true
				_blast(reader.breakable_pos(i), reader.barrel_radius())
			else:
				_debris(reader.breakable_pos(i), reader.breakable_kind(i))
		fuse_glow[i] = 0.0
		if reader.breakable_fusing(i):
			fuse_glow[i] = 1.0 if fuse_blink(reader, i) else 0.0
		if i < _fuse_lights.size() and _fuse_lights[i] != null:
			_fuse_lights[i].visible = fuse_glow[i] > 0.5


## Barrel i's fuse light is on now: it blinks every 12 ticks at first, every 3 at the end.
static func fuse_blink(reader: WorldReader, i: int) -> bool:
	var total := maxi(1, reader.barrel_fuse_ticks())
	var t := reader.tick() - reader.breakable_fuse_tick(i)
	var period := maxi(3, 12 - 9 * t / total)
	return (t % period) < period / 2 + 1


func _process(delta: float) -> void:
	for k in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[k]
		var node: Node3D = fx[0]
		var life: float = fx[2]
		fx[1] = float(fx[1]) + delta
		var u := clampf(float(fx[1]) / life, 0.0, 1.0)
		if fx[3] == 0:  # a chip: falls and shrinks
			node.position += (fx[4] as Vector3) * delta
			fx[4] = (fx[4] as Vector3) + Vector3(0, -9.0 * delta, 0)
			node.scale = Vector3.ONE * (1.0 - u)
		else:  # the blast: grows to its reach and fades
			node.scale = Vector3.ONE * lerpf(0.2, float(fx[4]), u)
		if u >= 1.0:
			node.queue_free()
			_fx.remove_at(k)


func _build_wall(reader: WorldReader) -> void:
	var root := Node3D.new()
	root.name = "CrackedWall"
	root.position = SimPlane.to_3d(reader.crack_door_center())
	root.rotation.y = SimPlane.yaw_of(reader.crack_door_angle())
	add_child(root)
	var width := reader.crack_door_width()
	var depth := maxf(reader.crack_door_depth(), 0.6) + 0.1
	wall = Node3D.new()
	wall.name = "Whole"
	root.add_child(wall)
	var model := ShopModels.get_model(MODEL_WALL)
	if not model.is_empty():
		_model(wall, model, Vector3(1.0, 1.0, width / 3.0))
	else:
		_box(wall, Vector3(depth, WALL_H, width), Vector3(0, WALL_H * 0.5, 0), _stone)
	for face in [-1.0, 1.0]:  # a faint web of cracks from one point, on both faces
		var at := Vector3(face * (depth * 0.5 + 0.01), WALL_H * 0.45, width * 0.1)
		for k in 6:
			var ang := TAU * k / 6.0 + 0.3
			var bar := _box(wall, Vector3(0.02, 0.04, 0.55 + 0.1 * (k % 3)), at, _crack_mat)
			bar.rotation.x = ang
			bar.position += Vector3(0, sin(ang) * -0.3, cos(ang) * 0.3)
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rubble = Node3D.new()
	rubble.name = "Broken"
	rubble.visible = false
	root.add_child(rubble)
	var broken := ShopModels.get_model(MODEL_WALL_BROKEN)
	if not broken.is_empty():
		_model(rubble, broken, Vector3(1.0, 1.0, width / 3.0))
	else:
		for side in [-1.0, 1.0]:  # the jagged frame's sides, and rubble on both sides of the gap
			_box(
				rubble,
				Vector3(depth, WALL_H, 0.35),
				Vector3(0, WALL_H * 0.5, side * width * 0.42),
				_stone
			)
			for k in 3:
				var chunk := _box(
					rubble,
					Vector3(0.45, 0.3, 0.4),
					Vector3(side * (depth * 0.5 + 0.35), 0.15, (k - 1) * width * 0.28),
					_stone
				)
				chunk.rotation.y = 0.5 * k
	_room_light = OmniLight3D.new()
	_room_light.name = "RoomLight"
	_room_light.light_color = Color("#FFE7B8")
	_room_light.omni_range = 9.0
	_room_light.light_energy = 1.6
	_room_light.shadow_enabled = false
	_room_light.position = SimPlane.to_3d(reader.floor_room(reader.crack_room()).get_center(), 2.6)
	_room_light.visible = false
	add_child(_room_light)


func _build_prop(i: int, kind: int, at: Vector2) -> void:
	var root := Node3D.new()
	root.name = "Breakable%d" % i
	root.position = SimPlane.to_3d(at)
	root.rotation.y = 0.7 * i
	add_child(root)
	props.append(root)
	var model := ShopModels.get_model(MODELS[kind])
	var light: OmniLight3D = null
	if not model.is_empty():
		_model(root, model, Vector3.ONE)
	else:
		match kind:
			WorldReader.BREAKABLE_CRATE:
				_box(root, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.35, 0), _mat(WOOD))
			WorldReader.BREAKABLE_URN:
				_cyl(root, 0.18, 0.26, 0.75, Vector3(0, 0.375, 0), _mat(CLAY))
				_cyl(root, 0.2, 0.2, 0.08, Vector3(0, 0.76, 0), _mat(CLAY.darkened(0.2)))
			WorldReader.BREAKABLE_BARREL:
				_cyl(root, 0.3, 0.3, 0.9, Vector3(0, 0.45, 0), _mat(WOOD.darkened(0.1)))
				for y in [0.2, 0.7]:
					_cyl(root, 0.31, 0.31, 0.05, Vector3(0, y, 0), _mat(Color("#3A3633")))
			_:
				_cyl(root, 0.32, 0.32, 1.0, Vector3(0, 0.5, 0), _mat(RED))
				_cyl(root, 0.33, 0.33, 0.1, Vector3(0, 0.62, 0), _mat(Color("#C8A23A")))
				_cyl(root, 0.06, 0.06, 0.12, Vector3(0.12, 1.06, 0), _mat(Color("#2E2B29")))
	if kind == WorldReader.BREAKABLE_EXPLOSIVE:
		light = OmniLight3D.new()
		light.name = "Fuse"
		light.light_color = Color("#FF3B2A")
		light.omni_range = 3.0
		light.light_energy = 2.5
		light.shadow_enabled = false
		light.position = Vector3(0.12, 1.25, 0)
		light.visible = false
		root.add_child(light)
	_fuse_lights.append(light)


func _debris(at: Vector2, kind: int) -> void:
	var col := CLAY if kind == WorldReader.BREAKABLE_URN else WOOD
	for k in 5:
		var chip := _box(self, Vector3(0.14, 0.1, 0.12), SimPlane.to_3d(at, 0.4), _mat(col))
		var ang := TAU * k / 5.0
		_fx.append([chip, 0.0, DEBRIS_S, 0, Vector3(cos(ang) * 1.6, 3.0, sin(ang) * 1.6)])


func _blast(at: Vector2, radius: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(FIRE, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var ball := MeshInstance3D.new()
	ball.name = "Blast"
	ball.mesh = sphere
	ball.material_override = m
	ball.position = SimPlane.to_3d(at, 0.6)
	ball.scale = Vector3.ONE * 0.2
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flash := OmniLight3D.new()
	flash.light_color = FIRE
	flash.omni_range = radius * 3.0
	flash.light_energy = 4.0
	ball.add_child(flash)
	add_child(ball)
	_fx.append([ball, 0.0, BLAST_S, 1, radius])


## How many effects (chips, blasts) are playing (tests read it).
func fx_count() -> int:
	return _fx.size()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _model(parent: Node3D, model: Dictionary, scale_by: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Model"
	mi.mesh = model["mesh"]
	mi.set_surface_override_material(0, model["material"])
	mi.scale = scale_by
	parent.add_child(mi)


func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = h
	mesh.radial_segments = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node
