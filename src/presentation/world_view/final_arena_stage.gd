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
## An owner model `<id>.glb` in assets/models/arena/, listed in assets/models/manifest.json, replaces a code piece.
## v0.9.0 MI2 (the owner's models delivered 2026-10-22, prepared by scripts/assets/mi2_prep.py at their size here,
## PIECES): each ring segment is the owner's wall segment (tiled along the causeway's long walls), in the walls' faded
## and solid materials (its own texture), so the occlusion still fades it; the far pillars are his (their floating
## crystal turns and bobs as the code shard did; the near ones stay low code stumps so they never hide the fight);
## the braziers are his (his flames; the light stays code); the gate is his; on the approach his stair flights replace
## the code treads; his ground_arena texture paves the floor. The code pieces stay the fallback (L15).
## Presentation only: the sim's walls are the ring whatever is drawn. The cosmetic stream (seeded from the floor)
## places the broken bits; nothing here reads or writes the sim.
## v0.9.0 FA (owner C §3: "a separate, quieter environment … stairs and a clear path leading toward a large altar";
## Q18 "Stair causeway"): on the final approach the ring is open on the hero's side and a stair causeway runs down
## from the gap (WorldReader.approach_causeway_*): CAUSEWAY_STEPS treads of worn stone, each edged by a faint violet
## line (the sim is flat: the steps read by their edges and their alternating shades), over a spine of rock into the
## void; no pillar or brazier stands in the gap. FinalApproachView draws the altar, the pylons and the walls of light.

const MODEL_DIR := "res://assets/models/arena/"
const MANIFEST := "res://assets/models/manifest.json"
const GROUND_TEXTURE := "res://assets/textures/kit/ground_arena.png"
## The art request's ids (§7), each with its size (m, x y z in the piece's frame) as mi2_prep.py prepared it (an owner
## model is fitted to it): the wall segment one sim segment long (z; its arena face -X), the gate 7.6 m across (z; its
## face -X, to the centre), the stair flight 3 m deep (climbing +X) and 6 m across.
const PIECES := {
	&"arena_wall_segment": Vector3(1.324, 1.571, 3.0),
	&"arena_gate": Vector3(3.104, 5.42, 7.6),
	&"arena_pillar": Vector3(2.058, 5.0, 2.224),
	&"arena_brazier": Vector3(0.934, 1.4, 0.937),
	&"approach_stairs": Vector3(3.0, 0.5, 6.0),
}
## v0.9.0 MI2: the owner's stair flights sit this far down (m), so the flat sim's hero walks over their middle.
const FLIGHT_SINK := 0.25
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
## v0.9.0 FA: the causeway's treads, and how wide (radians) the gap is kept clear of pillars and braziers.
const CAUSEWAY_STEPS := 14
const GAP_CLEAR := 0.42

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
## v0.9.0 FA: the causeway's treads (empty off the approach), and the gap's angle (radians, the 3D floor's x-z
## plane; NAN off the approach).
var treads: Array[MeshInstance3D] = []
## v0.9.0 MI2: the owner's stair flights on the causeway (empty without his model), and the owner models drawn (ids).
var flights: Array[Node3D] = []
var models_used: Array[StringName] = []
var _gap_a := NAN
var _flames: Array[MeshInstance3D] = []
var _shards: Array[Node3D] = []
## Each shard's resting height (its node's frame), for the bob.
var _shard_y := PackedFloat32Array()
var _t := 0.0


## Builds the arena from `reader` (its walls before slab_first are the ring), the palette and the radius.
func build(reader: WorldReader, palette: Dictionary, radius: float, seed_value: int) -> void:
	name = "FinalArena"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 4409  # the cosmetic stream: presentation only
	_build_ground(palette, radius)
	_build_walls(reader)
	if reader.final_approach():  # v0.9.0 FA
		var top := SimPlane.to_3d(reader.approach_causeway_top())
		_gap_a = atan2(top.z, top.x)
		_build_causeway(reader, rng)
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
			_shards[k].position.y = _shard_y[k] + 0.15 * sin(_t * 1.4 + k)


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
		# v0.9.0 MI2: the owner's paving in its own colours (a light tint of the palette's stone).
		var m := _mat(Color.WHITE.lerp(palette["ground"], 0.25))
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


## The ring: one stone block per sim wall segment (the sim's own boxes), a red vein along each top; v0.9.0 MI2: or the
## owner's wall segment on each (tiled along the longer walls), in the same faded / solid materials (his texture).
func _build_walls(reader: WorldReader) -> void:
	var seg := _piece_surface(&"arena_wall_segment")
	wall_material = _mat(STONE)
	if not seg.is_empty():
		wall_material = (seg["material"] as StandardMaterial3D).duplicate()
		models_used.append(&"arena_wall_segment")
	wall_faded = wall_material.duplicate()
	wall_faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_faded.albedo_color.a = 0.3
	var vein := _mat(STONE_DARK, VEIN, 2.4)
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
		var along_x := w.half.x > w.half.y  # v0.9.0 FA: the causeway's long walls run along their x
		if not seg.is_empty():
			# A ring segment's arena face (the model's -X) toward the centre: the node turned so its +X points out.
			var out := Vector3(at.x, 0.0, at.z).normalized()
			if not along_x and node.basis.x.dot(out) < 0.0:
				node.rotation.y += PI
			node.mesh = _wall_mesh(seg, 2.0 * maxf(w.half.x, w.half.y), along_x)
			continue
		var strip := _box(
			node,
			(
				Vector3(w.half.x * 2.0, 0.06, w.half.y * 0.6)
				if along_x
				else Vector3(w.half.x * 0.6, 0.06, w.half.y * 2.0)
			),
			Vector3(0, WALL_H * 0.5, 0),
			0.0,
			vein
		)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## v0.9.0 MI2: the owner's wall segment (`seg`, ModelLibrary.first_surface) as one mesh `length` m long along the
## node's z (its x when `along_x`): as many copies as fit his segment's own length, stretched a little to fill it, its
## base at the node's foot (the node stands at half the wall's height).
static func _wall_mesh(seg: Dictionary, length: float, along_x: bool) -> ArrayMesh:
	var arrays: Array = seg["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		for k in verts.size():
			idx.append(k)
	var piece: float = (PIECES[&"arena_wall_segment"] as Vector3).z
	var n := maxi(1, roundi(length / piece))
	var s := length / (n * piece)
	var turn := Basis(Vector3.UP, PI * 0.5 if along_x else 0.0)
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_i := PackedInt32Array()
	for k in n:
		var off := (k + 0.5) * piece * s - length * 0.5
		var base := out_v.size()
		for j in verts.size():
			var v := verts[j]
			out_v.append(turn * Vector3(v.x, v.y - WALL_H * 0.5, v.z * s + off))
			out_n.append(turn * norms[j])
		out_uv.append_array(uvs)
		for i in idx:
			out_i.append(base + i)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_v
	out[Mesh.ARRAY_NORMAL] = out_n
	out[Mesh.ARRAY_TEX_UV] = out_uv
	out[Mesh.ARRAY_INDEX] = out_i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


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
	if model != null:
		models_used.append(&"arena_pillar")
	var gate_a := atan2(gate_dir.z, gate_dir.x)
	for k in PILLARS:
		var a := TAU * (k + 0.5) / PILLARS
		var far := absf(wrapf(a - gate_a, -PI, PI)) <= SEAT_ARC
		if _in_gap(a):
			continue
		var at := Vector3(cos(a), 0, sin(a)) * (radius + 1.6)
		var root := Node3D.new()
		root.name = "Pillar%d" % k
		root.position = at
		add_child(root)
		pillar_count += 1
		if model != null and far:
			var inst := _scaled(model, PIECES[&"arena_pillar"])
			root.add_child(inst)
			var crystal_part := inst.find_child("shard", true, false) as Node3D
			if crystal_part != null:  # v0.9.0 MI2: his floating crystal turns and bobs
				_shards.append(crystal_part)
				_shard_y.append(crystal_part.position.y)
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
			_shard_y.append(shard.position.y)


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
	if model != null:
		models_used.append(&"arena_brazier")
	for k in BRAZIERS:
		var a := TAU * k / BRAZIERS
		if _in_gap(a):
			continue
		var root := Node3D.new()
		root.name = "Brazier%d" % k
		root.position = Vector3(cos(a), 0, sin(a)) * (radius + 0.6) + Vector3(0, WALL_H, 0)
		add_child(root)
		brazier_count += 1
		var light := OmniLight3D.new()
		light.light_color = STAR_FIRE
		light.light_energy = 2.2
		light.omni_range = 7.0
		light.shadow_enabled = false
		light.position = Vector3(0, 1.4, 0)
		root.add_child(light)
		if model != null:  # v0.9.0 MI2: his brazier holds his own violet flames
			root.add_child(_scaled(model, PIECES[&"arena_brazier"]))
			continue
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


## v0.9.0 FA: angle `a` (radians on the 3D floor) falls in the approach's gap.
func _in_gap(a: float) -> bool:
	return not is_nan(_gap_a) and absf(wrapf(a - _gap_a, -PI, PI)) <= GAP_CLEAR


## v0.9.0 FA: the stair causeway from the ring's gap down to the foot: worn treads with lit edges over a rock spine.
func _build_causeway(reader: WorldReader, rng: RandomNumberGenerator) -> void:
	var top := SimPlane.to_3d(reader.approach_causeway_top())
	var foot := SimPlane.to_3d(reader.approach_causeway_foot())
	var axis := (foot - top).normalized()
	var length := top.distance_to(foot) + 3.6
	var width := reader.approach_causeway_half_width() * 2.0
	var yaw := atan2(-axis.z, axis.x)
	var root := Node3D.new()
	root.name = "Causeway"
	add_child(root)
	var light_stone := _mat(STONE.lightened(0.08))
	var dark_stone := _mat(STONE.darkened(0.1))
	var edge := _mat(STONE_DARK, STAR_FIRE, 1.4)
	var stairs := _owner_piece(&"approach_stairs")
	if stairs != null:
		# v0.9.0 MI2: the owner's stair flights down the causeway, each climbing toward the ring, low (the sim is
		# flat: they sit FLIGHT_SINK down, the hero walks over their middle), as wide as the causeway.
		models_used.append(&"approach_stairs")
		var size: Vector3 = PIECES[&"approach_stairs"]
		var count := maxi(1, roundi(length / size.x))
		var deep := length / count
		for k in count:
			var f := Node3D.new()
			f.name = "Flight%d" % k
			f.position = top + axis * (deep * (k + 0.5) - 1.2) + Vector3(0, -FLIGHT_SINK, 0)
			f.rotation.y = yaw + PI
			root.add_child(f)
			var inst := _scaled(stairs, size)
			inst.scale = Vector3(deep / size.x, 1.0, (width + 0.3) / size.z)
			f.add_child(inst)
			flights.append(f)
	var tread := length / CAUSEWAY_STEPS
	for k in CAUSEWAY_STEPS:
		if stairs != null:
			break
		var at := top + axis * (tread * (k + 0.5) - 1.2)
		var h := 0.3 + 0.05 * rng.randf()
		var t := _box(
			root,
			Vector3(tread - 0.04, h, width + 0.3),
			at + Vector3(0, -h * 0.5, 0),
			yaw,
			light_stone if k % 2 == 0 else dark_stone
		)
		t.name = "Tread%d" % k
		treads.append(t)
		var line := _box(
			root,
			Vector3(0.06, 0.02, width),
			at - axis * (tread * 0.5 - 0.05) + Vector3(0, 0.005, 0),
			yaw,
			edge
		)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spine := _box(
		root,
		Vector3(length, 5.0, width * 0.7),
		top + axis * (length * 0.5 - 1.2) + Vector3(0, -2.9, 0),
		yaw,
		StarVoid.rock_material(Color("#1A1426"))
	)
	spine.name = "Spine"
	spine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
		models_used.append(&"arena_gate")
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


## v0.9.0 MI2: an owner piece's first surface (ModelLibrary.first_surface) or {} while none is listed and delivered.
static func _piece_surface(id: StringName) -> Dictionary:
	var scene := _owner_piece(id)
	return ModelLibrary.first_surface(scene) if scene != null else {}


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
		if id != &"approach_stairs":  # v0.9.0's (its art list), not §7's
			out.append(id)
	return out
