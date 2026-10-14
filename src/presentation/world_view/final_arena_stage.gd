class_name FinalArenaStage
extends Node3D
## v0.8.0 FB1 (owner, F1/F2: "rounded big room like a gladiator arena, but cosmic like"; FINAL_BOSS.md F2): the final
## arena's look, built in code from the sim's round room (WorldReader: the floor's walls, its gate) and the arena's
## palette, so the owner's pieces can replace it piece by piece (docs/art/requests/v0.8.0_ART_LIST.md §7, by id):
## - `ground_arena`: a disc of worn circular paving in dark violet stone, faint rings and radial joints, red crystal
##   veins glowing in the cracks and a faint star sparkle (a shader); the owner's tileable texture replaces it
##   (assets/textures/kit/ground_arena.png, listed in the models manifest's textures).
## - `arena_wall_segment`: each sim wall segment as a block of dark stone with a glowing red vein along its top (the
##   occlusion fades them as the floors' walls); behind the far half, tiered seating rising in steps, empty and broken
##   in places (the near half keeps a low ring so it never hides the fight from the iso camera).
## - `arena_pillar`: tall broken columns round the ring (stumps on the near side), each topped by a floating red
##   crystal shard that turns slowly.
## - `arena_brazier`: stone braziers on the wall's top holding a violet star-fire (a flickering flame and a light).
## - `arena_gate`: the sealed great gate where the sim puts it (WorldReader.portal_pos), two great columns and an arch,
##   barred by a glowing red crystal portcullis.
## - the void: the arena is a floating disc of rock over the star-lit void (StarVoid's stars and nebulae, as Starfall),
##   spikes of rock hanging from its rim.
## An owner model `<id>.glb` in assets/models/arena/, listed in assets/models/manifest.json, replaces a code piece
## (scaled to the piece's size); none is delivered yet. Presentation only: the sim's walls are the ring whatever is
## drawn. The cosmetic stream (seeded from the floor) places the broken bits; nothing here reads or writes the sim.

const MODEL_DIR := "res://assets/models/arena/"
const MANIFEST := "res://assets/models/manifest.json"
const GROUND_TEXTURE := "res://assets/textures/kit/ground_arena.png"
## The art request's ids (§7), each with its code piece's size (m) for an owner model to be scaled to.
const PIECES := {
	&"arena_wall_segment": Vector3(8.0, 4.0, 3.0),
	&"arena_gate": Vector3(6.0, 6.0, 2.0),
	&"arena_pillar": Vector3(1.2, 5.0, 1.2),
	&"arena_brazier": Vector3(1.0, 1.4, 1.0),
}
const WALL_H := 1.5
const SEAT_TIERS := 4
const SEAT_DEPTH := 1.8
const SEAT_RISE := 1.0
## The seating's half arc round the gate's side (radians); the rest of the ring keeps the low wall only.
const SEAT_ARC := 1.9
const PILLARS := 12
const PILLAR_H := 5.0
const BRAZIERS := 8
const STONE := Color("#3B3150")
const STONE_DARK := Color("#251E33")
const VEIN := Color("#FF2E4A")
const STAR_FIRE := Color("#B46BFF")
const SEAL := Color("#FF3050")

const GROUND_SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 stone : source_color = vec4(0.30, 0.25, 0.42, 1.0);
uniform vec4 stone_dark : source_color = vec4(0.16, 0.12, 0.24, 1.0);
uniform vec4 vein : source_color = vec4(1.0, 0.18, 0.29, 1.0);
uniform float radius = 15.0;
uniform float motion = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float r = length(p);
	float a = atan(p.y, p.x);
	float ring = fract(r / 2.2);
	float joints_r = smoothstep(0.0, 0.04, ring) * smoothstep(1.0, 0.96, ring);
	float cells = floor(r / 2.2) * 6.0 + 8.0;
	float seg = fract(a / 6.2831853 * cells);
	float joints_a = smoothstep(0.0, 0.03, seg) * smoothstep(1.0, 0.97, seg);
	float n = texture(noise_tex, p * 0.07).r;
	float n2 = texture(noise_tex, p * 0.31 + vec2(3.1, 1.7)).r;
	float stone_mix = smoothstep(0.25, 0.75, n) * 0.6 + 0.4 * n2;
	vec3 col = mix(stone_dark.rgb, stone.rgb, stone_mix);
	col *= mix(0.55, 1.0, joints_r * joints_a);
	float veins = 1.0 - smoothstep(0.008, 0.03, abs(n - 0.5));
	veins *= smoothstep(radius * 0.15, radius * 0.5, r);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.3 * motion + r * 0.4);
	float rim = smoothstep(radius * 0.9, radius, r);
	float star = step(0.985, texture(noise_tex, p * 1.9).r) * (0.6 + 0.4 * sin(TIME * 3.0 * motion + p.x));
	ALBEDO = col;
	EMISSION = vein.rgb * (veins * 2.2 * pulse + rim * 0.15) + vec3(0.8, 0.75, 1.0) * star * 0.6;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
"""

## Built pieces, for tests and the tour.
var wall_nodes: Array[MeshInstance3D] = []
var wall_material: StandardMaterial3D
var wall_faded: StandardMaterial3D
var pillar_count := 0
var brazier_count := 0
var seat_count := 0
var gate: Node3D
var ground: MeshInstance3D
var _flames: Array[MeshInstance3D] = []
var _shards: Array[Node3D] = []
var _t := 0.0


## Builds the arena from `reader` (its walls before slab_first are the ring), the palette and the radius.
func build(reader: WorldReader, palette: Dictionary, radius: float, seed_value: int) -> void:
	name = "FinalArena"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 4409  # the cosmetic stream: presentation only
	_build_ground(palette, radius)
	_build_walls(reader)
	var gate_at := reader.portal_pos()
	var gate_dir := SimPlane.to_3d(gate_at).normalized()
	_build_seating(radius, gate_dir, rng)
	_build_pillars(radius, gate_dir, rng)
	_build_braziers(radius)
	_build_gate(gate_at, radius)
	_build_void(radius, palette, rng)


func _process(delta: float) -> void:
	_t += delta
	var still := ViewPrefs.reduced_motion
	for k in _flames.size():
		var f := _flames[k]
		var flick := 1.0 if still else 0.85 + 0.15 * sin(_t * 9.0 + k * 1.7) * sin(_t * 5.3 + k)
		f.scale = Vector3(1.0, flick, 1.0)
	if not still:
		for k in _shards.size():
			_shards[k].rotation.y = _t * 0.5 + k
			_shards[k].position.y = PILLAR_H + 0.9 + 0.15 * sin(_t * 1.4 + k)


func _mat(c: Color, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, yaw: float, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.rotation = Vector3(0, yaw, 0)
	parent.add_child(mi)
	return mi


## The floor: the paving disc (or the owner's texture), and the rock under it.
func _build_ground(palette: Dictionary, radius: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius + 1.4
	disc.bottom_radius = radius + 1.4
	disc.height = 0.2
	disc.radial_segments = 96
	ground = MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = disc
	ground.position = Vector3(0, -0.1, 0)
	if ResourceLoader.exists(GROUND_TEXTURE):
		var m := _mat(palette["ground"])
		m.albedo_texture = load(GROUND_TEXTURE)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / 4.0
		ground.material_override = m
	else:
		var sm := ShaderMaterial.new()
		sm.shader = Shader.new()
		sm.shader.code = GROUND_SHADER
		sm.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
		sm.set_shader_parameter("stone", palette["ground"])
		sm.set_shader_parameter("stone_dark", (palette["ground"] as Color).darkened(0.45))
		sm.set_shader_parameter("vein", VEIN)
		sm.set_shader_parameter("radius", radius)
		sm.set_shader_parameter("motion", 0.0 if ViewPrefs.reduced_motion else 1.0)
		ground.material_override = sm
	add_child(ground)
	var rock := CylinderMesh.new()
	rock.top_radius = radius + 10.0
	rock.bottom_radius = radius * 0.35
	rock.height = 7.0
	rock.radial_segments = 24
	var under := MeshInstance3D.new()
	under.name = "Underside"
	under.mesh = rock
	under.material_override = StarVoid.rock_material(palette["edge"])
	under.position = Vector3(0, -3.71, 0)
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(under)


## The ring: one stone block per sim wall segment (the sim's own boxes), a red vein along each top.
func _build_walls(reader: WorldReader) -> void:
	wall_material = _mat(STONE)
	wall_faded = _mat(STONE)
	wall_faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_faded.albedo_color.a = 0.3
	var vein := _mat(STONE_DARK, VEIN, 2.4)
	var model := _owner_piece(&"arena_wall_segment")
	for i in reader.wall_count():
		if reader.wall_class(i) != 0:
			continue
		var w := reader.wall(i)
		var yaw := SimPlane.yaw_of(w.angle)
		var at := SimPlane.to_3d(w.center, WALL_H * 0.5)
		var node := _box(
			self, Vector3(w.half.x * 2.0, WALL_H, w.half.y * 2.0), at, yaw, wall_material
		)
		node.name = "Wall%d" % i
		wall_nodes.append(node)
		var strip := _box(
			node,
			Vector3(w.half.x * 0.6, 0.06, w.half.y * 2.0),
			Vector3(0, WALL_H * 0.5, 0),
			0.0,
			vein
		)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if model != null:  # the owner's segment over the code block, every fourth sim segment (8 make the ring)
			node.visible = i % 4 == 0
			if i % 4 == 0:
				node.add_child(_scaled(model, PIECES[&"arena_wall_segment"]))


## The seating behind the far half: SEAT_TIERS steps rising away from the ring, broken in places.
func _build_seating(radius: float, gate_dir: Vector3, rng: RandomNumberGenerator) -> void:
	var seats := Node3D.new()
	seats.name = "Seating"
	add_child(seats)
	var stone := _mat(STONE.darkened(0.15))
	var gate_a := atan2(gate_dir.z, gate_dir.x)
	for tier in SEAT_TIERS:
		var r := radius + 1.4 + SEAT_DEPTH * (tier + 0.5)
		var h := WALL_H + SEAT_RISE * (tier + 1)
		var n := int(TAU * r / 2.4)
		for k in n:
			var a := TAU * k / n
			if absf(wrapf(a - gate_a, -PI, PI)) > SEAT_ARC:
				continue
			if rng.randf() < 0.08:
				continue  # broken away
			var len := TAU * r / n * 1.02
			var at := Vector3(cos(a), 0, sin(a)) * r + Vector3(0, h * 0.5, 0)
			var block := _box(seats, Vector3(SEAT_DEPTH, h, len), at, -a, stone)
			block.name = "Seat%d_%d" % [tier, k]
			seat_count += 1


## Columns round the ring, tall on the far side and broken stumps on the near, each tall one with a floating shard.
func _build_pillars(radius: float, gate_dir: Vector3, rng: RandomNumberGenerator) -> void:
	var stone := _mat(STONE.lightened(0.05))
	var crystal := _mat(Color("#8A1830"), SEAL, 2.0)
	var model := _owner_piece(&"arena_pillar")
	var gate_a := atan2(gate_dir.z, gate_dir.x)
	for k in PILLARS:
		var a := TAU * (k + 0.5) / PILLARS
		var far := absf(wrapf(a - gate_a, -PI, PI)) <= SEAT_ARC
		var at := Vector3(cos(a), 0, sin(a)) * (radius + 1.6)
		var root := Node3D.new()
		root.name = "Pillar%d" % k
		root.position = at
		add_child(root)
		pillar_count += 1
		if model != null and far:
			root.add_child(_scaled(model, PIECES[&"arena_pillar"]))
			continue
		var h := PILLAR_H * (1.0 if far else rng.randf_range(0.18, 0.3))
		_box(root, Vector3(1.1, h, 1.1), Vector3(0, h * 0.5, 0), a, stone)
		_box(root, Vector3(1.4, 0.3, 1.4), Vector3(0, 0.15, 0), a, stone)
		if far:
			_box(root, Vector3(1.4, 0.25, 1.4), Vector3(0, h, 0), a, stone)
			var shard := Node3D.new()
			shard.position = Vector3(0, PILLAR_H + 0.9, 0)
			root.add_child(shard)
			var mesh := MeshInstance3D.new()
			mesh.mesh = BossParts.crystal(1.2, 0.35, 90 + k)
			mesh.material_override = crystal
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shard.add_child(mesh)
			_shards.append(shard)


## Braziers on the wall's top with violet star-fire: a stone bowl, a flickering flame and a light.
func _build_braziers(radius: float) -> void:
	var stone := _mat(STONE_DARK)
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.albedo_color = STAR_FIRE
	fire.emission_enabled = true
	fire.emission = STAR_FIRE
	fire.emission_energy_multiplier = 3.0
	var model := _owner_piece(&"arena_brazier")
	for k in BRAZIERS:
		var a := TAU * k / BRAZIERS
		var root := Node3D.new()
		root.name = "Brazier%d" % k
		root.position = Vector3(cos(a), 0, sin(a)) * (radius + 0.6) + Vector3(0, WALL_H, 0)
		add_child(root)
		brazier_count += 1
		if model != null:
			root.add_child(_scaled(model, PIECES[&"arena_brazier"]))
		else:
			var bowl := CylinderMesh.new()
			bowl.top_radius = 0.5
			bowl.bottom_radius = 0.25
			bowl.height = 0.5
			bowl.radial_segments = 8
			var b := MeshInstance3D.new()
			b.mesh = bowl
			b.material_override = stone
			b.position = Vector3(0, 0.25, 0)
			root.add_child(b)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.32
		cone.height = 0.9
		cone.radial_segments = 6
		var flame := MeshInstance3D.new()
		flame.name = "StarFire"
		flame.mesh = cone
		flame.material_override = fire
		flame.position = Vector3(0, 0.95, 0)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flame)
		_flames.append(flame)
		var light := OmniLight3D.new()
		light.light_color = STAR_FIRE
		light.light_energy = 2.2
		light.omni_range = 7.0
		light.shadow_enabled = false
		light.position = Vector3(0, 1.4, 0)
		root.add_child(light)


## The sealed great gate in the ring: two columns, an arch and a glowing crystal portcullis, facing the centre.
func _build_gate(at: Vector2, radius: float) -> void:
	gate = Node3D.new()
	gate.name = "Gate"
	var out := SimPlane.to_3d(at).normalized()
	gate.position = out * (radius + 1.0)
	gate.rotation = Vector3(0, atan2(-out.z, out.x), 0)
	add_child(gate)
	var model := _owner_piece(&"arena_gate")
	if model != null:
		gate.add_child(_scaled(model, PIECES[&"arena_gate"]))
		return
	var stone := _mat(STONE.lightened(0.04))
	var seal := _mat(Color("#5A0E1E"), SEAL, 2.6)
	for side in [-1.0, 1.0]:
		_box(gate, Vector3(1.6, 6.0, 1.6), Vector3(0, 3.0, side * 3.0), 0.0, stone)
	_box(gate, Vector3(1.6, 1.2, 7.6), Vector3(0, 6.4, 0), 0.0, stone)
	for k in 7:
		var bar := _box(
			gate, Vector3(0.18, 5.6, 0.18), Vector3(-0.2, 2.8, -2.1 + k * 0.7), 0.0, seal
		)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 3:
		_box(gate, Vector3(0.18, 0.18, 4.4), Vector3(-0.2, 1.2 + k * 1.7, 0), 0.0, seal)


## The star-lit void round the floating arena: Starfall's stars and nebulae below and around it.
func _build_void(radius: float, palette: Dictionary, rng: RandomNumberGenerator) -> void:
	var reach := radius + SEAT_DEPTH * SEAT_TIERS + 4.0
	var keep: Array = [Rect2(-reach, -reach, reach * 2.0, reach * 2.0)]
	var bounds := Rect2(-reach - 30.0, -reach - 30.0, (reach + 30.0) * 2.0, (reach + 30.0) * 2.0)
	var sky := StarVoid.star_xforms(keep, bounds, rng)
	_multi("Stars", StarVoid.star_mesh(), sky[0], StarVoid.star_material(), sky[1])
	var nebula := Node3D.new()
	nebula.name = "Nebula"
	add_child(nebula)
	for cloud: Dictionary in StarVoid.nebula_clouds(bounds, rng):
		var mi := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2.ONE * float(cloud["size"])
		mi.mesh = q
		mi.position = cloud["at"]
		mi.material_override = StarVoid.nebula_material(cloud["color"], cloud["seed"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nebula.add_child(mi)
	var isles := StarVoid.island_xforms(keep, bounds, rng)
	_multi(
		"Islands", StarVoid.island_mesh(), isles[0], StarVoid.drift_material(palette["edge"], false)
	)


func _multi(n: String, mesh: Mesh, xforms: Array, mat: Material, colors: Array = []) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		if mm.use_colors:
			mm.set_instance_color(k, colors[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## The owner's model for an art id (its scene), or null while none is listed and delivered.
static func _owner_piece(id: StringName) -> PackedScene:
	var path := MODEL_DIR + String(id) + ".glb"
	if not ResourceLoader.exists(path) or not FileAccess.file_exists(MANIFEST):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	for m: Dictionary in (data as Dictionary).get("models", []):
		if String(m.get("id", "")) == String(id):
			return load(path) as PackedScene
	return null


## An owner piece's instance, scaled to fit `size` (its largest proportion), its base on the floor.
static func _scaled(scene: PackedScene, size: Vector3) -> Node3D:
	var holder := Node3D.new()
	var inst: Node3D = scene.instantiate()
	holder.add_child(inst)
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var b := BossModels.relative_transform(inst, mi) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := 1.0
	if not first:
		s = minf(size.x / maxf(box.size.x, 0.001), size.y / maxf(box.size.y, 0.001))
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(0, -box.position.y * s, 0)
	return holder


## Every art id this stage draws (the request list; a test pins it to ART_LIST §7).
static func art_ids() -> Array[StringName]:
	var out: Array[StringName] = [&"ground_arena"]
	for id: StringName in PIECES:
		out.append(id)
	return out
