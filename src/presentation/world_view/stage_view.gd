class_name StageView
extends Node3D
## Ground, walls, props, light and environment for one room, drawn from a biome palette
## (docs/art/ART_DIRECTION.md). Props come from the cosmetic stream: never from, and never into, the sim.

const TILE_M := 4.0
const EDGE_WALL_HEIGHT := 1.0
const SLAB_HEIGHT := 2.4
const FADED_ALPHA := 0.3
## Soft-shadow blur: 0.5 straightens the edges; 1.0 and above wiped out the props' small shadows in the test
## renders (evidence/SHADOWS.md).
const SHADOW_BLUR := 0.5

var palette := {}
var wall_specs: Array = []
var _wall_nodes: Array[MeshInstance3D] = []
var _wall_solid: StandardMaterial3D
var _wall_faded: StandardMaterial3D


func build(reader: WorldReader, p_palette: Dictionary, arena_half: float) -> void:
	palette = p_palette
	_build_environment()
	_build_light()
	_build_ground(arena_half)
	_build_walls(reader)
	_build_props(reader.seed_value(), arena_half)


func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = palette["edge"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = palette["ambient"]
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	# Crisp, long shadows that fall toward the lower left of the screen, as in the reference. Edges are straight
	# and clean, not stair-stepped (v0.2.0 L2, evidence/SHADOWS.md): one orthogonal split over the whole view
	# (a 2-split PSSM test was no smoother and striped the wall tops), an 8192 atlas and high soft-shadow
	# filtering (project.godot), and a small blur that smooths the texel steps without softening the shape.
	# For an orthographic camera the shadow fits the camera's near..far range, so IsoRig keeps `far` short.
	light.rotation_degrees = Vector3(-38, 168, 0)
	light.light_energy = 1.05
	light.light_color = Color(1, 0.98, 0.95)
	light.shadow_enabled = true
	light.shadow_blur = SHADOW_BLUR
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 80.0
	add_child(light)


func _build_ground(arena_half: float) -> void:
	var tiles := int(ceil(arena_half * 2.0 / TILE_M)) + 2
	var mats := [_mat(palette["ground"]), _mat(palette["ground_alt"])]
	var plane := PlaneMesh.new()
	plane.size = Vector2(TILE_M, TILE_M)
	for i in tiles:
		for j in tiles:
			var tile := MeshInstance3D.new()
			tile.mesh = plane
			tile.material_override = mats[(i + j) % 2]
			var start := -tiles * TILE_M * 0.5 + TILE_M * 0.5
			tile.position = Vector3(start + i * TILE_M, 0, start + j * TILE_M)
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tile)


func _build_walls(reader: WorldReader) -> void:
	_wall_solid = _mat(palette["cover"])
	_wall_faded = _mat(palette["cover"])
	_wall_faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wall_faded.albedo_color.a = FADED_ALPHA
	for i in reader.wall_count():
		var w := reader.wall(i)
		var height := EDGE_WALL_HEIGHT if i < 4 else SLAB_HEIGHT
		var box := BoxMesh.new()
		box.size = Vector3(w.half.x * 2.0, height, w.half.y * 2.0)
		var node := MeshInstance3D.new()
		node.mesh = box
		node.material_override = _wall_solid
		node.position = SimPlane.to_3d(w.center, height * 0.5)
		node.rotation = Vector3(0, SimPlane.yaw_of(w.angle), 0)
		add_child(node)
		_wall_nodes.append(node)
		wall_specs.append([w.center, w.half, SimPlane.yaw_of(w.angle), height])


func _build_props(seed_value: int, arena_half: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17  # the cosmetic stream: presentation only
	var rubble_mat := _mat(Color(palette["cover"]).darkened(0.25))
	var grass_mat := _mat(palette["accent"])
	for i in 70:
		var p := Vector2(
			rng.randf_range(-arena_half, arena_half), rng.randf_range(-arena_half, arena_half)
		)
		var s := rng.randf_range(0.12, 0.3)
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(s, s * 0.8, s)
		cube.mesh = box
		cube.material_override = rubble_mat
		cube.position = SimPlane.to_3d(p, s * 0.4)
		cube.rotation = Vector3(0, rng.randf() * TAU, 0)
		add_child(cube)
	for i in 40:
		var p := Vector2(
			rng.randf_range(-arena_half, arena_half), rng.randf_range(-arena_half, arena_half)
		)
		for blade in 3:
			var g := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.04, rng.randf_range(0.18, 0.35), 0.04)
			g.mesh = b
			g.material_override = grass_mat
			g.position = SimPlane.to_3d(
				p + Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08)), 0.12
			)
			g.rotation = Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
			add_child(g)


## Fades the walls at the given indices (dithered alpha) and restores the rest.
func apply_occlusion(indices: PackedInt32Array) -> void:
	for i in _wall_nodes.size():
		_wall_nodes[i].material_override = _wall_faded if i in indices else _wall_solid
