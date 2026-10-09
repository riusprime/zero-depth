class_name ShardCluster
extends Node3D
## Crystal-shard clusters built in code (v0.6.1 Step SD, owner R4; the owner's shard style:
## docs/roadmap/v0.6.0/refs/card_style_reference.webp and v0.6.1/refs/plaque_templates_empty.webp): faceted
## crystals with a dark outline, bright facet highlights and a soft inner glow, and a few small floating fragments
## that bob. ShardDressing says where; this node draws a whole floor of them. Presentation only, no collision.
##
## Cheap by construction (a floor's "LOD"): each room's crystals are baked into one mesh (one draw, plus its outline
## pass), so the camera culls whole rooms; each room's fragments are one MultiMesh that bobs on the GPU (no per-frame
## CPU work); the unit crystals are a few dozen triangles; only the hero cluster carries a light, and it casts no
## shadow; small crystals stop casting shadows on the "low" lighting quality.

## The shard tints: [body (albedo), glow (emission and the hero's light)]. Starting values. The default is a cool
## pale cyan / teal, kept off the reserved player_core cyan (#2BC4E2, ART_DIRECTION §2).
const TINTS := {
	&"default": [Color("#B8F4EC"), Color("#5CD6C4")],
	&"ruins": [Color("#B8F4EC"), Color("#5CD6C4")],
	&"night_rocks": [Color("#C8DAFF"), Color("#7C9EFF")],
	&"red_canyon": [Color("#FFE6C8"), Color("#EDB46A")],
	## Deep floors (v0.5.5 DS): the Deep haze's violet.
	&"deep": [Color("#D6C2FF"), Color("#8A5CFF")],
}
## The unit crystal's shape: sides per variant, the shoulder (where the point starts) and the base's taper.
const VARIANT_SIDES: Array[int] = [6, 5, 4]
const SHOULDER := 0.68
const BASE_TAPER := 0.82
## The short point under the base (buried for grown crystals; a fragment's lower point) and the core's height.
const BOTTOM := -0.22
const CORE_Y := 0.45
## Glow (emission) and outline. The glow stays soft: under the mood's glow threshold except at the hero. SD2: each
## crystal carries its own glow factor (ShardDressing: 1 .. 1.35 toward a vein's centre, 1.55 for the hero cluster),
## stored in the vertex colour's green channel (factor / GLOW_SCALE) so a room still bakes into one mesh.
const GLOW_ENERGY := 0.45
const GLOW_SCALE := 2.0
const OUTLINE_WIDTH := 0.022
const INK := Color(0.05, 0.06, 0.09)
## Fragments bob this far (m) at this speed (radians per second); none with reduced motion.
const BOB_AMPLITUDE := 0.08
const BOB_SPEED := 1.6
## The hero cluster's small cold light (sits in the mood: low energy, short range, no shadow).
const HERO_LIGHT_ENERGY := 0.6
const HERO_LIGHT_RANGE := 4.5

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec4 body : source_color = vec4(0.72, 0.96, 0.93, 1.0);
uniform vec4 glow : source_color = vec4(0.36, 0.84, 0.77, 1.0);
uniform float glow_energy = 0.45;
uniform float bob = 0.0;
uniform float bob_speed = 1.6;

varying float v_shade;
varying float v_glow;

void vertex() {
	v_shade = COLOR.r;
	v_glow = COLOR.g * 2.0;
	if (bob > 0.0) {
		vec3 o = MODEL_MATRIX[3].xyz;
		float b = sin(TIME * bob_speed + o.x * 1.7 + o.z * 2.3) * bob;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(0.0, b, 0.0);
	}
}

void fragment() {
	// Facets: the vertex shade lights some faces and darkens the base; the core glows through the faces that
	// look at the camera (a soft inner light), the edges stay darker.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = body.rgb * mix(0.55, 1.15, v_shade);
	ROUGHNESS = 0.22;
	SPECULAR = 0.75;
	RIM = 0.35;
	RIM_TINT = 0.6;
	EMISSION = glow.rgb * glow_energy * v_glow * (0.35 + 0.65 * facing * facing) * mix(0.6, 1.0, v_shade);
}
"""

## The outline: the crystal's hull grown out from its core and drawn back faces only, in ink.
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.05, 0.06, 0.09, 1.0);
uniform float width = 0.022;
uniform float bob = 0.0;
uniform float bob_speed = 1.6;

void vertex() {
	mat3 m = mat3(MODEL_MATRIX);
	mat3 inv = inverse(m);
	vec3 core = CUSTOM0.xyz;
	vec3 dir = normalize(m * (VERTEX - core) + vec3(0.0, 1e-4, 0.0));
	VERTEX += inv * (dir * width);
	if (bob > 0.0) {
		vec3 o = MODEL_MATRIX[3].xyz;
		float b = sin(TIME * bob_speed + o.x * 1.7 + o.z * 2.3) * bob;
		VERTEX += inv * vec3(0.0, b, 0.0);
	}
}

void fragment() {
	ALBEDO = ink.rgb;
}
"""

static var _meshes := {}
static var _shader: Shader
static var _outline_shader: Shader

## What was built, for tests and tools: per room index, its baked mesh node and fragments node.
var room_meshes := {}
var room_fragments := {}
var hero_light: OmniLight3D
var clusters: Array = []


## Builds every cluster `placed` (ShardDressing.place) with the tint `tint_key` (a TINTS key). `shadows`: small
## crystals cast shadows (the "high" lighting quality).
func build(placed: Array, tint_key: StringName, shadows := true) -> void:
	clusters = placed
	var tint: Array = TINTS.get(tint_key, TINTS[&"default"])
	var by_room := {}
	for c: Dictionary in placed:
		var r: int = c["room"]
		if not by_room.has(r):
			by_room[r] = []
		by_room[r].append(c)
	var calm := ViewPrefs.reduced_motion
	for r: int in by_room:
		var crystals: Array = []
		var frags: Array = []
		for c: Dictionary in by_room[r]:
			crystals.append_array(c["crystals"])
			frags.append_array(c["fragments"])
			if c["hero"] and (c["light"] as Vector3).is_finite():
				_add_light(c["light"], tint[1])
		var glow_e := GLOW_ENERGY
		var node := MeshInstance3D.new()
		node.name = "Shards_%d" % r
		node.mesh = bake(crystals)
		node.material_override = material(tint, glow_e, 0.0)
		node.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if shadows or r == _hero_room(by_room[r])
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		add_child(node)
		room_meshes[r] = node
		if frags.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = crystal_mesh(2)
		mm.instance_count = frags.size()
		for k in frags.size():
			mm.set_instance_transform(k, frags[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Fragments_%d" % r
		mmi.multimesh = mm
		mmi.material_override = material(tint, glow_e * 1.3, 0.0 if calm else BOB_AMPLITUDE)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		room_fragments[r] = mmi


## r's room index when one of its clusters is the hero's, else -1.
static func _hero_room(room_clusters: Array) -> int:
	for c: Dictionary in room_clusters:
		if c["hero"]:
			return int(c["room"])
	return -1


## The TINTS key for a biome (StageView.prop_style) and the Deep flag: Deep floors take the Deep violet.
static func tint_key(biome: StringName, deep: bool) -> StringName:
	if deep:
		return &"deep"
	return biome if TINTS.has(biome) else &"default"


func _add_light(at: Vector3, color: Color) -> void:
	var l := OmniLight3D.new()
	l.name = "ShardLight"
	l.position = at
	l.light_color = color.lerp(Color.WHITE, 0.25)
	l.light_energy = HERO_LIGHT_ENERGY
	l.omni_range = HERO_LIGHT_RANGE
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	add_child(l)
	hero_light = l


## The crystal material for a tint ([body, glow]), with its outline as the next pass. `bob`: the fragments'.
static func material(tint: Array, glow_energy: float, bob: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(&"body", tint[0])
	m.set_shader_parameter(&"glow", tint[1])
	m.set_shader_parameter(&"glow_energy", glow_energy)
	m.set_shader_parameter(&"bob", bob)
	m.set_shader_parameter(&"bob_speed", BOB_SPEED)
	var o := ShaderMaterial.new()
	o.shader = _outline_shader
	o.set_shader_parameter(&"ink", INK)
	o.set_shader_parameter(&"width", OUTLINE_WIDTH)
	o.set_shader_parameter(&"bob", bob)
	o.set_shader_parameter(&"bob_speed", BOB_SPEED)
	m.next_pass = o
	return m


## The unit crystal (radius 1, height 1, base at y = 0) of a variant (VARIANT_SIDES), built once and shared.
## Flat-shaded facets; COLOR.r is the facet's shade (a bright highlight face or two, a darker base); CUSTOM0.xyz is
## the crystal's core, so the outline grows from the crystal's own axis (also when baked).
static func crystal_mesh(variant: int) -> ArrayMesh:
	variant = posmod(variant, VARIANT_SIDES.size())
	if _meshes.has(variant):
		return _meshes[variant]
	var a := _crystal_arrays(variant, Transform3D.IDENTITY)
	var mesh := _commit([a])
	_meshes[variant] = mesh
	return mesh


## Bakes many crystals ({"xform", "variant", "glow" (optional, 1)}) into one mesh.
static func bake(crystals: Array) -> ArrayMesh:
	var parts: Array = []
	for c: Dictionary in crystals:
		parts.append(_crystal_arrays(int(c["variant"]), c["xform"], float(c.get("glow", 1.0))))
	return _commit(parts)


## Vertex, normal, colour and core arrays of one crystal under xform. `glow`: its glow factor (COLOR.g).
static func _crystal_arrays(variant: int, xform: Transform3D, glow := 1.0) -> Dictionary:
	var sides := VARIANT_SIDES[posmod(variant, VARIANT_SIDES.size())]
	# A fixed, per-variant irregularity: ring radii and the point's offset (no randomness: the same every run).
	var ring_top: Array[Vector3] = []
	var ring_bot: Array[Vector3] = []
	for k in sides:
		var ang := TAU * float(k) / float(sides) + 0.3 * float(variant)
		var wob := 1.0 + 0.12 * float(((k * 7 + variant * 3) % 5) - 2) / 2.0
		ring_top.append(Vector3(cos(ang) * wob, SHOULDER, sin(ang) * wob))
		ring_bot.append(Vector3(cos(ang) * wob * BASE_TAPER, 0.0, sin(ang) * wob * BASE_TAPER))
	var tip := Vector3(0.12 * float(variant - 1), 1.0, 0.08 * float(1 - variant))
	var foot := Vector3(0.0, BOTTOM, 0.0)
	# Plain arrays while building (packed arrays inside an Array would be copied on write).
	var arrays := [[], [], []]
	var basis_n := xform.basis.inverse().transposed()
	for k in sides:
		var n := (k + 1) % sides
		# Highlight: two facets catch the light, the rest step down.
		var shade := 1.0 if k == 0 or k == 2 else 0.42 + 0.1 * float(k % 3)
		var g := clampf(glow / GLOW_SCALE, 0.0, 1.0)
		_tri(arrays, xform, basis_n, [ring_bot[k], ring_top[n], ring_top[k]], shade, g)
		_tri(arrays, xform, basis_n, [ring_bot[k], ring_bot[n], ring_top[n]], shade, g)
		_tri(arrays, xform, basis_n, [ring_top[k], ring_top[n], tip], minf(shade + 0.2, 1.0), g)
		_tri(arrays, xform, basis_n, [ring_bot[n], ring_bot[k], foot], shade * 0.6, g)
	# The core (the outline grows away from it), in the mesh's own space.
	var core := xform * Vector3(0.0, CORE_Y, 0.0)
	var count: int = arrays[0].size()
	var custom := PackedFloat32Array()
	custom.resize(count * 4)
	for i in count:
		custom[i * 4] = core.x
		custom[i * 4 + 1] = core.y
		custom[i * 4 + 2] = core.z
	return {
		"verts": PackedVector3Array(arrays[0]),
		"normals": PackedVector3Array(arrays[1]),
		"colors": PackedColorArray(arrays[2]),
		"custom": custom,
	}


## One flat triangle `t` ([a, b, c]) into `arrays` ([verts, normals, colors]) under xform, its normal pointing
## away from the crystal's axis, wound for Godot's front faces (clockwise seen from outside). The shade fades
## toward the base; `glow` (the glow factor / GLOW_SCALE) goes in the green channel.
static func _tri(
	arrays: Array, xform: Transform3D, basis_n: Basis, t: Array, shade: float, glow: float
) -> void:
	var a: Vector3 = t[0]
	var b: Vector3 = t[1]
	var c: Vector3 = t[2]
	var n := (b - a).cross(c - a).normalized()
	var mid := (a + b + c) / 3.0
	var out := mid - Vector3(0.0, CORE_Y, 0.0)
	if n.dot(out) < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	var wn := (basis_n * n).normalized()
	for v: Vector3 in [a, c, b]:
		arrays[0].append(xform * v)
		arrays[1].append(wn)
		var s := shade * (0.55 + 0.45 * clampf(v.y / SHOULDER, 0.0, 1.0))
		arrays[2].append(Color(s, glow, s))


static func _commit(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var custom := PackedFloat32Array()
	for p: Dictionary in parts:
		verts.append_array(p["verts"])
		normals.append_array(p["normals"])
		colors.append_array(p["colors"])
		custom.append_array(p["custom"])
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	var fmt := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
	return mesh
