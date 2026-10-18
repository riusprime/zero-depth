class_name StageView
extends Node3D
## Ground, walls, props, light and environment for one room, drawn from a biome palette
## (docs/art/ART_DIRECTION.md). Props come from the cosmetic stream: never from, and never into, the sim.

const TILE_M := 4.0
const EDGE_WALL_HEIGHT := 1.0
## Cover slabs inside rooms. 1.8 m (was 2.4) so slabs hide less of the floor from the iso camera (v0.2.0).
const SLAB_HEIGHT := 1.8
const FADED_ALPHA := 0.3
## Soft-shadow blur: 0.5 straightens the edges; 1.0 and above wiped out the props' small shadows in the test
## renders (evidence/SHADOWS.md).
const SHADOW_BLUR := 0.5
## On a generated floor the ground covers the floor's footprint (WorldReader.floor_ground: each room's cells, so
## its walls at their real thickness and its doorways, and the outer walls), not the floor's whole bounding box,
## so the space between rooms reads as void (v0.2.0 I, v0.3.0 A). Any room or structural wall the footprint
## doesn't enclose (a room added after generation) gets ground too: the room grown by this margin, the wall's box.
const ROOM_GROUND_MARGIN := 0.8
## v0.5.9: the kit's ground textures by biome (prop_style; "" for any other), and the metres one texture covers.
## v0.6.0 (owner, 2026-10-09): Ruins uses the same ground as the other floors ("change the texture from first floor
## to match the rest of the floors").
const GROUND_TEXTURES := {
	&"": "res://assets/textures/kit/ground_b.png",
	&"night_rocks": "res://assets/textures/kit/ground_b.png",
	&"red_canyon": "res://assets/textures/kit/ground_b.png",
}
const GROUND_TEXTURE_M := 4.0
## v0.8.0 N10 (owners O66, O67), N13 (owner O71, D50 = A everywhere): every biome's structural walls are the
## procedural ruin (option A) in the owner's wall textures, by biome (tex_wall_<biome>, tex_wall_top_<biome>; a
## biome without its own takes Ruins').
const WALL_TEXTURE := "res://assets/textures/kit/tex_wall_%s.png"
const WALL_TOP_TEXTURE := "res://assets/textures/kit/tex_wall_top_%s.png"

## Lighting quality (v0.5.9 Step 1, GameSettings "lighting"): "high" adds contact shadow (SSAO) and bounce light
## (SSIL); "low" leaves both off for slower GPUs.
const LIGHTING_QUALITIES: Array[String] = ["high", "low"]
## v0.5.5 DS (S5): the Deep look, layered on the biome's mood (the Deep gate's violet; starting values).
const DEEP_VIOLET := Color("#8A5CFF")
const DEEP_EDGE := Color("#140A26")
const DEEP_FOG_DENSITY := 0.012

## Which biome's props to scatter (v0.3.0 B): &"night_rocks" (faceted boulders, dead trees), &"red_canyon" (mesa
## chunks, dry grass), anything else Ruins (rubble, grass). Set before build().
var prop_style := &""
var palette := {}
## The biome's lighting mood (v0.5.9 Step 1). Null keeps the pre-v0.5.9 look (one bright sun, linear tonemap), the
## G2 mockup's variant A. Set before build().
var mood: BiomeMood = null
## v0.7.5 NB1: the biome's own look (BiomeLook: square cover, decoration swaps, the edge); null for the first three
## biomes, which keep their hand-written look. Set before build().
var look: BiomeLook = null
## v0.7.5 NB1: the floor's ice patches (null without any) and what lies past the floor's edge (null: the void).
var ice: IceViews
var edge: BiomeEdge
## v0.7.5 NB2: the floor's starglow pools (Starfall's surface; null without any).
var glow: StarglowViews
## v0.8.0 FB1: the final arena's own stage (null on every other floor): its round floor, ring, seating, gate, void.
var final_arena: FinalArenaStage
var lighting := "high"
var environment: Environment
var sun: DirectionalLight3D
var vignette: TextureRect
var contact_shadows: MeshInstance3D
## The floor built from the owner's kit (v0.5.9 Step 4), when there is a mood and every wall and cover piece
## loads; otherwise the boxes and primitive props draw as before.
var kit: StageKit
## v0.6.1 SD (owner R4): the crystal-shard clusters dressing the floor (null without the kit or a floor).
var shards: ShardCluster
## v0.5.5 DS (owner S5, "Deep floors must feel different"): a Deep floor (WorldReader.floor_is_deep) keeps its biome's
## mood and gets a violet haze on top: violet-tinted fog (thicker), ambient, sun and void (_apply_deep).
var deep := false
var wall_specs: Array = []
## v0.8.0 N10: how long the procedural walls took to build (ms; 0 without them): the probes read it.
var wall_build_ms := 0.0
var _wall_nodes: Array[MeshInstance3D] = []
var _wall_solid: StandardMaterial3D
var _wall_faded: StandardMaterial3D
var _wall_classes: Array[int] = []
## v0.5.9 L8: each drawn wall's kit piece from a themed room (&"" for none).
var _wall_pieces: Array[StringName] = []
## v0.8.0 RT: each drawn wall's designed-room height (m; 0 = the kit's own; -1 for a wall that isn't a designed room's).
var _wall_layout_heights := PackedFloat64Array()
## Sim-plane rects the ground covers on a generated floor (empty in the arena: a square ground).
var _ground_rects: Array[Rect2] = []
## v0.8.0 N12: the queue the stage is being built on (build() makes its own), and whether the kit dresses the floor.
var _queue: ViewBuildQueue
var _use_kit := false
## v0.8.0 N12: the crystal shards' placement (ShardDressing.place, on a worker), and its input.
var _shard_input := {}
var _shard_placed: Array = []
## v0.8.0 N12: the dresser's input and placements, and the procedural walls' input and result (on a worker).
var _dressing := {}
var _placements: Array = []
var _proc_input := {}
var _proc := {}


func build(reader: WorldReader, p_palette: Dictionary, arena_half: float) -> void:
	var q := ViewBuildQueue.new()
	queue_build(q, reader, p_palette, arena_half)
	q.run_all()


## v0.8.0 N12 (owner O70): build()'s parts as jobs on `q` (ViewBuildQueue), in build()'s order; a load runs them over
## frames behind the loading cover. A part that learns its own pieces as it goes adds them right after itself
## (q.add_next: the crystal shards' placement on a worker, then one room's shards a job).
func queue_build(
	q: ViewBuildQueue, reader: WorldReader, p_palette: Dictionary, arena_half: float
) -> void:
	_queue = q
	palette = p_palette
	deep = reader.floor_is_deep()
	q.add("stage_light", _build_environment_and_light)
	if reader.final_arena():  # v0.8.0 FB1 (F2): the final arena draws itself
		q.add("final_arena", _build_final_arena.bind(reader))
		return
	q.add("ground", _build_floor_ground.bind(reader, arena_half))
	q.add("walls", _build_structure.bind(reader))
	q.add("kit", _build_dressing.bind(reader, arena_half))
	q.add("ice", _build_ice.bind(reader))
	q.add("edge", _build_edge.bind(reader))


func _build_environment_and_light() -> void:
	_build_environment()
	_build_light()


func _build_floor_ground(reader: WorldReader, arena_half: float) -> void:
	_ground_rects.clear()
	if reader.has_floor():
		_ground_rects = reader.floor_ground()
		for i in reader.floor_room_count():
			_add_ground(reader.floor_room(i).grow(ROOM_GROUND_MARGIN))
		for i in reader.wall_count():
			if reader.wall_class(i) == 0:
				_add_ground(reader.wall(i).bounds())
	if _ground_rects.is_empty():
		_build_ground(arena_half)
	else:
		_build_room_ground()


func _build_structure(reader: WorldReader) -> void:
	_use_kit = mood != null and KitModels.has_structure()
	_build_walls(reader, not _use_kit)
	_build_contact_shadows()


func _build_dressing(reader: WorldReader, arena_half: float) -> void:
	if _use_kit:
		_build_kit(reader)
	else:  # kept deliberately: the box-wall fallback keeps the game runnable before the art kit is imported (P-17)
		_build_props(reader.seed_value(), arena_half)


## v0.8.0 FB1: the final arena (FinalArenaStage): the walls' specs stay for the occlusion, its wall blocks are the
## faded ones.
func _build_final_arena(reader: WorldReader) -> void:
	_build_walls(reader, false)
	final_arena = FinalArenaStage.new()
	add_child(final_arena)
	final_arena.build(reader, palette, reader.final_arena_radius(), reader.seed_value())
	_wall_nodes = final_arena.wall_nodes
	_wall_solid = final_arena.wall_material
	_wall_faded = final_arena.wall_faded


## v0.7.5 NB1: the sim's ice patches, wherever the floor has them (Frozen Shore's surface).
func _build_ice(reader: WorldReader) -> void:
	if reader.ice_patch_count() == 0:
		return
	if reader.surface_kind() == &"starglow":  # v0.7.5 NB2: Starfall's pools, not ice
		glow = StarglowViews.new()
		glow.name = "Starglow"
		add_child(glow)
		glow.build(reader, reader.seed_value())
		return
	ice = IceViews.new()
	ice.name = "Ice"
	add_child(ice)
	ice.build(reader, reader.seed_value())


## v0.7.5 NB1: the biome's edge past the floor (BiomeLook.edge; Frozen Shore's frozen sea), on generated floors.
func _build_edge(reader: WorldReader) -> void:
	if look == null or not BiomeEdge.has_style(look.edge) or _ground_rects.is_empty():
		return
	edge = BiomeEdge.new()
	edge.name = "Edge"
	add_child(edge)
	edge.build(
		look.edge, _ground_rects, reader.floor_bounds(), palette["edge"], reader.seed_value()
	)


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
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.glow_enabled = true
	_mood_environment(env)
	environment = env
	set_lighting(lighting)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## The mood's (or the old look's) settings on `env`; run again by apply_mood() while playing.
func _mood_environment(env: Environment) -> void:
	env.glow_hdr_threshold = 1.0
	env.glow_bloom = 0.0
	for lv in 7:  # Godot's default glow levels
		env.set_glow_level(lv, 1.0 if lv in [2, 4] else 0.0)
	env.adjustment_enabled = false
	if mood == null:
		env.background_color = palette["edge"]
		env.ambient_light_color = palette["ambient"]
		env.ambient_light_energy = 0.55
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.glow_intensity = 0.6
	else:
		env.background_color = mood.void_color
		env.ambient_light_color = mood.ambient_color
		env.ambient_light_energy = mood.ambient_energy
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.tonemap_exposure = mood.exposure
		env.glow_intensity = mood.glow_intensity
		env.glow_hdr_threshold = mood.glow_threshold
		env.glow_bloom = mood.glow_bloom
		if mood.glow_spread > 0.0:  # wider levels: bright sources halo, not just their own pixels
			for lv: Array in [[2, 1.0], [3, 0.9], [4, 0.75], [5, 0.55]]:
				env.set_glow_level(
					int(lv[0]), float(lv[1]) * (1.0 if lv[0] == 2 else mood.glow_spread)
				)
		var grade := mood.grade_texture()
		if grade != null or mood.contrast != 1.0 or mood.saturation != 1.0:
			env.adjustment_enabled = true
			env.adjustment_contrast = mood.contrast
			env.adjustment_saturation = mood.saturation
			env.adjustment_color_correction = grade
		env.ssao_radius = mood.ssao_radius
		env.ssao_intensity = mood.ssao_intensity
		env.ssao_light_affect = mood.ssao_light_affect
		env.ssil_intensity = mood.ssil_intensity
		env.fog_enabled = mood.fog_density > 0.0
		env.fog_density = mood.fog_density
		env.fog_light_color = mood.fog_color
		_build_vignette(mood.vignette)
	if deep:
		_apply_deep(env)


## Re-applies the mood to the running stage (the dev panel's lighting page, docs/tools/DEV_PANEL.md Step 3): the
## environment, the grade and glow, the sun or moon, the vignette and the fire props' lights. The contact shadow
## under blocks is built with the floor: its two numbers take a Restart floor.
func apply_mood() -> void:
	if environment == null:
		return
	_mood_environment(environment)
	set_lighting(lighting)
	if sun != null:
		sun.queue_free()
		sun = null
	_build_light()
	if kit != null and mood != null:
		kit.retune(mood)


## v0.5.5 DS (S5): the Deep haze on top of whatever look the environment has (the mood's, or the old one): the void
## and the ambient pulled toward violet, and violet fog at least DEEP_FOG_DENSITY thick.
func _apply_deep(env: Environment) -> void:
	env.background_color = env.background_color.lerp(DEEP_EDGE, 0.6)
	env.ambient_light_color = env.ambient_light_color.lerp(DEEP_VIOLET, 0.5)
	env.fog_light_color = (
		env.fog_light_color.lerp(DEEP_VIOLET, 0.7) if env.fog_enabled else DEEP_VIOLET
	)
	env.fog_enabled = true
	env.fog_density = maxf(env.fog_density, DEEP_FOG_DENSITY)
	env.fog_sky_affect = 0.0


## Applies a lighting quality ("high" or "low") to the running stage: contact shadow and bounce light follow it.
func set_lighting(quality: String) -> void:
	lighting = quality if quality in LIGHTING_QUALITIES else "high"
	if environment == null:
		return
	var high := mood != null and lighting == "high"
	environment.ssao_enabled = high
	environment.ssil_enabled = high and mood.ssil_enabled
	if kit != null:
		kit.set_shadows(high)


## Darkens the screen's edges (a radial gradient on a full-screen rect, under the HUD and the portal transit).
func _build_vignette(strength: float) -> void:
	if vignette != null:  # apply_mood() again: replace the old one
		vignette.get_parent().queue_free()
		vignette = null
	if strength <= 0.0:
		return
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, strength)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.15, 0.5)
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	vignette = TextureRect.new()
	vignette.texture = tex
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(vignette)


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
	if mood != null:
		light.rotation_degrees = Vector3(mood.sun_pitch_deg, mood.sun_yaw_deg, 0)
		light.light_energy = mood.sun_energy
		light.light_color = mood.sun_color
	if deep:  # v0.5.5 DS (S5): the sun pulled toward violet, a little dimmer
		light.light_color = light.light_color.lerp(DEEP_VIOLET, 0.45)
		light.light_energy *= 0.85
	light.shadow_enabled = true
	light.shadow_blur = SHADOW_BLUR
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 80.0
	sun = light
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


## Ground over r, unless the ground already covers it whole.
func _add_ground(r: Rect2) -> void:
	for g in _ground_rects:
		if g.grow(0.001).encloses(r):
			return
	_ground_rects.append(r)


## The same checker as _build_ground, on the global tile grid, clipped to each room's rect. With a mood (v0.5.9),
## the owner's ground texture instead, mapped in world space so it runs on across tiles, tinted by the biome.
func _build_room_ground() -> void:
	var mats := [_mat(palette["ground"]), _mat(palette["ground_alt"])]
	var textured := _ground_material()
	if textured != null:
		mats = [textured, textured]
	for r in _ground_rects:
		var i0 := int(floor(r.position.x / TILE_M))
		var i1 := int(floor(r.end.x / TILE_M))
		var j0 := int(floor(r.position.y / TILE_M))
		var j1 := int(floor(r.end.y / TILE_M))
		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				var cell := Rect2(Vector2(i, j) * TILE_M, Vector2(TILE_M, TILE_M)).intersection(r)
				if cell.size.x <= 0.001 or cell.size.y <= 0.001:
					continue
				var plane := PlaneMesh.new()
				plane.size = cell.size
				var tile := MeshInstance3D.new()
				tile.mesh = plane
				tile.material_override = mats[posmod(i + j, 2)]
				tile.position = SimPlane.to_3d(cell.get_center())
				tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(tile)


## The kit ground (Ruins: stone tiles; the other biomes: packed dirt), or null without a mood or the texture.
func _ground_material() -> StandardMaterial3D:
	if mood == null:
		return null
	var path := GROUND_TEXTURES.get(prop_style, GROUND_TEXTURES[&""]) as String
	if not ResourceLoader.exists(path):
		return null
	var m := _mat(palette["ground"])
	m.albedo_texture = load(path)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / GROUND_TEXTURE_M
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## True where the stage draws ground (everywhere in the arena; inside a room or its walls on a floor).
func covers_ground(p: Vector2) -> bool:
	if _ground_rects.is_empty():
		return true
	for r in _ground_rects:
		if r.has_point(p):
			return true
	return false


## The walls' specs (for occlusion and the dresser) and, unless the kit dresses them, their boxes.
func _build_walls(reader: WorldReader, draw := true) -> void:
	_wall_solid = _mat(palette["cover"])
	_wall_faded = _mat(palette["cover"])
	_wall_faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wall_faded.albedo_color.a = FADED_ALPHA
	for i in reader.wall_count():
		var kind := reader.wall_class(i)
		if kind == 2:
			continue
		var w := reader.wall(i)
		var height := EDGE_WALL_HEIGHT if kind == 0 else SLAB_HEIGHT
		wall_specs.append([w.center, w.half, SimPlane.yaw_of(w.angle), height])
		_wall_classes.append(kind)
		_wall_pieces.append(reader.wall_piece(i))
		_wall_layout_heights.append(reader.wall_layout_height(i))
		if not draw:
			continue
		var box := BoxMesh.new()
		box.size = Vector3(w.half.x * 2.0, height, w.half.y * 2.0)
		var node := MeshInstance3D.new()
		node.mesh = box
		node.material_override = _wall_solid
		node.position = SimPlane.to_3d(w.center, height * 0.5)
		node.rotation = Vector3(0, SimPlane.yaw_of(w.angle), 0)
		add_child(node)
		_wall_nodes.append(node)


func _build_props(seed_value: int, arena_half: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17  # the cosmetic stream: presentation only
	if prop_style == &"night_rocks" or prop_style == &"red_canyon":
		_build_biome_props(rng, arena_half)
		return
	var rubble_mat := _mat(Color(palette["cover"]).darkened(0.25))
	var grass_mat := _mat(palette["accent"])
	var area_scale := clampf(arena_half * arena_half / 144.0, 1.0, 6.0)
	for i in int(70 * area_scale):
		var p := Vector2(
			rng.randf_range(-arena_half, arena_half), rng.randf_range(-arena_half, arena_half)
		)
		var s := rng.randf_range(0.12, 0.3)
		if not covers_ground(p):
			continue
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(s, s * 0.8, s)
		cube.mesh = box
		cube.material_override = rubble_mat
		cube.position = SimPlane.to_3d(p, s * 0.4)
		cube.rotation = Vector3(0, rng.randf() * TAU, 0)
		add_child(cube)
	for i in int(40 * area_scale):
		var p := Vector2(
			rng.randf_range(-arena_half, arena_half), rng.randf_range(-arena_half, arena_half)
		)
		if not covers_ground(p):
			continue
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


## v0.5.9 Step 1: a soft contact shadow around every wall and slab (only with a mood; the old look has none).
func _build_contact_shadows() -> void:
	if mood == null:
		return
	var boxes: Array = []
	for spec: Array in wall_specs:
		boxes.append([spec[0], spec[1], spec[2]])
	contact_shadows = ContactShadows.build(boxes, mood.contact_radius, mood.contact_strength)
	if contact_shadows != null:
		add_child(contact_shadows)


## v0.5.9 Step 4: the floor dressed with the kit (StageDresser's rules), its pieces under a StageKit node.
func _build_kit(reader: WorldReader) -> void:
	var walls: Array = []
	for i in wall_specs.size():
		walls.append(
			[
				wall_specs[i][0],
				wall_specs[i][1],
				wall_specs[i][2],
				_wall_classes[i],
				_wall_pieces[i] if i < _wall_pieces.size() else &"",
				_wall_layout_heights[i] if i < _wall_layout_heights.size() else -1.0
			]
		)
	var rooms: Array = []
	for i in reader.floor_room_count():
		rooms.append(reader.floor_room(i))
	var doors: Array = []
	for i in reader.floor_door_count():
		doors.append(reader.floor_door_rect(i))
	var keep: Array = [reader.portal_pos()]
	if reader.floor_receiver():  # v0.8.0 N11 (O69): nothing stands on the hero's receiver
		keep.append(reader.floor_start_pos())
	for i in reader.reward_count():
		keep.append(reader.reward_pos(i))
	if reader.shop_stall():  # v0.8.0 SR: no rubble where you walk up to the counter
		keep.append(reader.shop_front())
	if reader.event_curse_altar() >= 0:  # v0.8.0 N17: nothing stands on the curse altar
		keep.append(reader.event_pos(reader.event_curse_altar()))
	var dressing := {
		"walls": walls,
		"rooms": rooms,
		"start_room": reader.floor_start_room(),
		"doors": doors,
		"keep_clear": keep,
		"biome": prop_style,
		"seed": reader.seed_value(),
		"props": _layout_props(reader),
	}
	if look != null:  # v0.7.5 NB1: the biome's own cover and decoration
		dressing["square_cover"] = _names(look.square_cover)
		dressing["decor_swap"] = _names(look.decor_swap)
	# v0.8.0 N12 (O70): the dressing and the ruin's geometry are pure work (StageDresser and ProceduralWall read only
	# their dictionaries and the cosmetic stream; no node, no mesh): on a worker. Then the nodes, a few a job.
	_dressing = dressing
	_proc_input = {
		"walls": walls,
		"rooms": rooms,
		"doors": doors,
		"seed": reader.seed_value(),
		"face_m": mood.wall_texture_m,
		"top_m": mood.wall_top_texture_m,
		"calm": WallCalm.calm_of(mood),  # v0.8.0 N15: the biome's calmer walls
	}
	_queue.add_next_worker("dress", _dress)
	_queue.add_next("kit_nodes", _build_kit_nodes.bind(reader, walls, rooms, doors, keep))


func _dress() -> void:
	_placements = StageDresser.dress(_dressing)
	_proc = {}
	var t0 := Time.get_ticks_usec()  # v0.8.0 N10 (option A; N15, D53: the only wall style)
	_proc_input["cuts"] = StageDresser.niches(_placements)
	_proc = ProceduralWall.build(_proc_input)
	wall_build_ms = (Time.get_ticks_usec() - t0) / 1000.0


func _build_kit_nodes(
	reader: WorldReader, walls: Array, rooms: Array, doors: Array, keep: Array
) -> void:
	var tex := wall_textures(prop_style) if not _proc.is_empty() else {}
	tex.merge(WallCalm.look_of(mood))  # v0.8.0 N15: the shader's calming values
	kit = StageKit.new()
	kit.name = "Kit"
	add_child(kit)
	# v0.8.0 N12: in parts (StageKit.queue_build), then the shadows and the shards after them.
	kit.queue_build(_queue, _placements, wall_specs.size(), palette["cover"], mood, _proc, tex)
	_queue.add_next("kit_shadows", func() -> void: kit.set_shadows(lighting == "high"))
	_build_shards(reader, walls, rooms, doors, keep, _placements)


## v0.8.0 N10 (the probes' numbers): the structural walls' drawn wall meshes (kit pieces and procedural walls; not
## the light props) and their full-detail triangles: {"nodes": int, "tris": int}.
func structural_wall_stats() -> Dictionary:
	var nodes := 0
	var tris := 0
	if kit == null:
		return {"nodes": 0, "tris": 0}
	for i in mini(kit.wall_pieces.size(), _wall_classes.size()):
		if _wall_classes[i] != 0:
			continue
		for node: MeshInstance3D in kit.wall_pieces[i]:
			var piece: StringName = node.get_meta(&"piece", &"")
			if not (piece == &"proc_wall" or KitModels.SPECS.get(piece, {}).get("role") == &"wall"):
				continue
			nodes += 1
			tris += mesh_tris(node.mesh)
	return {"nodes": nodes, "tris": tris}


## A mesh's triangles at full detail (every surface).
static func mesh_tris(mesh: Mesh) -> int:
	var n := 0
	if mesh == null:
		return 0
	for k in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(k)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			n += (idx as PackedInt32Array).size() / 3
		else:
			n += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## v0.8.0 N10: the owner's wall textures for a biome ({"face", "top"}; Ruins' when the biome has none).
static func wall_textures(biome: StringName) -> Dictionary:
	var out := {}
	for pair: Array in [["face", WALL_TEXTURE], ["top", WALL_TOP_TEXTURE]]:
		var path := String(pair[1]) % biome
		if not ResourceLoader.exists(path):
			path = String(pair[1]) % "ruins"
		out[pair[0]] = load(path) if ResourceLoader.exists(path) else null
	return out


## v0.8.0 RT: the designed rooms' drawn-only pieces (WorldReader.layout_prop).
static func _layout_props(reader: WorldReader) -> Array:
	var out: Array = []
	for i in reader.layout_prop_count():
		out.append(reader.layout_prop(i))
	return out


## A look dictionary with StringName keys (and values, when they are text), whatever the .tres wrote.
static func _names(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		var v: Variant = d[k]
		out[StringName(str(k))] = StringName(str(v)) if v is String or v is StringName else v
	return out


## v0.6.1 SD (owner R4): crystal-shard clusters on top of the kit (ShardDressing's rules; ShardCluster draws them).
## Presentation only: the same walls, doorways and keep-clear spots the dresser used, plus its light props, the
## other interactables, the enemy spawn spots and the hero's start.
func _build_shards(
	reader: WorldReader, walls: Array, rooms: Array, doors: Array, keep: Array, placements: Array
) -> void:
	if not reader.has_floor():
		return
	var clear: Array = keep.duplicate()
	var special: Array = []  # v0.6.1 SD4: rooms holding these are never crystal rooms
	for p: Dictionary in placements:
		if p["kind"] == &"light":
			clear.append(SimPlane.to_sim((p["xform"] as Transform3D).origin))
	if reader.has_deep_portal():
		clear.append(reader.deep_portal_pos())
	if reader.has_shop():
		clear.append(reader.shop_pos())
		special.append(reader.shop_pos())
	if reader.has_gamble():
		clear.append(reader.gamble_pos())
		special.append(reader.gamble_pos())
	for k in reader.event_count():
		clear.append(reader.event_pos(k))
		special.append(reader.event_pos(k))
	var blocked: Array = doors.duplicate()
	blocked.append_array(reader.arena_barriers())
	_shard_input = {
		"walls": walls,
		"pieces": placements,
		"rooms": rooms,
		"special": special,
		"start_room": reader.floor_start_room(),
		"boss_room": reader.boss_room(),
		"doors": blocked,
		"keep_clear": clear,
		"spawns": Array(reader.spawn_spots()),
		"start": reader.floor_start_pos(),
		"seed": reader.seed_value(),
	}
	# v0.8.0 N12 (O70): the placement is pure work (ShardDressing reads only the dictionary), on a worker; then each
	# room's crystals are baked and added in a job of their own.
	_queue.add_next_worker("shards_place", _place_shards)
	_queue.add_next("shards", _build_shard_rooms)


func _place_shards() -> void:
	_shard_placed = ShardDressing.place(_shard_input)


func _build_shard_rooms() -> void:
	shards = ShardCluster.new()
	shards.name = "Shards"
	add_child(shards)
	for r: int in shards.begin(
		_shard_placed, ShardCluster.tint_key(prop_style, deep), lighting == "high"
	):
		_queue.add_next("shards", shards.build_room.bind(r))


## Fades the walls at the given indices (dithered alpha) and restores the rest.
func apply_occlusion(indices: PackedInt32Array) -> void:
	if kit != null:
		kit.set_faded(indices)
		return
	for i in _wall_nodes.size():
		_wall_nodes[i].material_override = _wall_faded if i in indices else _wall_solid


## Night Rocks and Red Canyon props (docs/art/ART_DIRECTION.md §1, §3): decoration only, never in the way.
func _build_biome_props(rng: RandomNumberGenerator, arena_half: float) -> void:
	var night := prop_style == &"night_rocks"
	var rock_mat := _mat(Color(palette["cover"]).lightened(0.08 if night else 0.0))
	var dark_mat := _mat(Color(palette["cover"]).darkened(0.3))
	var accent_mat := _mat(palette["accent"])
	var area_scale := clampf(arena_half * arena_half / 144.0, 1.0, 6.0)
	for i in int(45 * area_scale):
		var p := Vector2(
			rng.randf_range(-arena_half, arena_half), rng.randf_range(-arena_half, arena_half)
		)
		if not covers_ground(p):
			continue
		if night:
			# A faceted boulder: a low-poly sphere, squashed and turned.
			var s := rng.randf_range(0.18, 0.42)
			var m := SphereMesh.new()
			m.radius = s
			m.height = s * 1.4
			m.radial_segments = 6
			m.rings = 3
			var rock := MeshInstance3D.new()
			rock.mesh = m
			rock.material_override = rock_mat if i % 3 else dark_mat
			rock.position = SimPlane.to_3d(p, s * 0.45)
			rock.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, 0)
			add_child(rock)
		else:
			# A mesa chunk: two or three flat stacked blocks, each a little smaller.
			var w := rng.randf_range(0.22, 0.5)
			var y := 0.0
			for k in rng.randi_range(2, 3):
				var b := BoxMesh.new()
				var h := rng.randf_range(0.08, 0.16)
				b.size = Vector3(w, h, w * rng.randf_range(0.7, 1.1))
				var block := MeshInstance3D.new()
				block.mesh = b
				block.material_override = rock_mat if k % 2 == 0 else dark_mat
				block.position = SimPlane.to_3d(p, y + h * 0.5)
				block.rotation = Vector3(0, rng.randf() * TAU, 0)
				add_child(block)
				y += h
				w *= 0.75
	for i in int((10 if night else 40) * area_scale):
		var p := Vector2(
			rng.randf_range(-arena_half, arena_half), rng.randf_range(-arena_half, arena_half)
		)
		if not covers_ground(p):
			continue
		if night:
			# A bare dead tree: a leaning trunk and two branches.
			var trunk_h := rng.randf_range(0.8, 1.3)
			var tree := Node3D.new()
			tree.position = SimPlane.to_3d(p)
			tree.rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, 0)
			add_child(tree)
			for spec: Array in [
				[Vector3(0.09, trunk_h, 0.09), Vector3(0, trunk_h * 0.5, 0), 0.0],
				[Vector3(0.05, 0.45, 0.05), Vector3(0.12, trunk_h * 0.8, 0), -0.7],
				[Vector3(0.05, 0.35, 0.05), Vector3(-0.1, trunk_h * 0.65, 0), 0.8],
			]:
				var b := BoxMesh.new()
				b.size = spec[0]
				var part := MeshInstance3D.new()
				part.mesh = b
				part.material_override = accent_mat
				part.position = spec[1]
				part.rotation = Vector3(0, 0, spec[2])
				tree.add_child(part)
		else:
			for blade in 3:
				var g := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = Vector3(0.04, rng.randf_range(0.14, 0.28), 0.04)
				g.mesh = b
				g.material_override = accent_mat
				g.position = SimPlane.to_3d(
					p + Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08)), 0.1
				)
				g.rotation = Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
				add_child(g)
