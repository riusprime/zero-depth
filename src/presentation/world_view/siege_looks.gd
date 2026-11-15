class_name SiegeLooks
extends RefCounted
## What the Siege Engine's fight views share: their colours, the floor shaders (the Target Lock's reticle, the ring a
## body wears that shows through walls, the cover's shadow), the boulder's rock, the ammo cart's code-made wagon, and
## the geometry of the shadow a boulder casts away from the Engine. Looks only (EI-07).

## The Engine's palette (SiegeEngineAvatar): its red hull, dark plates, grey metal, its red glow.
const HULL := Color("#D23E35")
const PLATE := Color("#2B2C31")
const METAL := Color("#6A6462")
const METAL_DARK := Color("#4C4847")
const GLOW := Color("#FF3A26")
## The lock's reticle and every "do not stand here" read: a hot red-orange.
const DANGER := Color("#FF4A24")
## The cover's safe read (the shadow behind a boulder, the ring on a covered hero): a cool teal, far from the reds.
const SAFE := Color("#5CE6E0")
## The rock's dust and its cracks' glow as it is about to go.
const DUST := Color(0.72, 0.64, 0.52)
const CRACK := Color("#FF7A3A")
## The boulder's rock from the kit (a cover piece in the unit box: its scale is its size in metres).
const ROCK_MODEL := &"rock_large"
## How high a boulder stands (m): low enough that the hero shows over it from the game's camera.
const ROCK_H := 1.1

## The Target Lock's reticle on a floor quad of radius 1: an outer ring, a countdown arc just inside it (`share` of a
## turn filled), four ticks across the ring turning with `spin`, a small cross in the middle; dull and turning while
## it tracks, white-hot and pulsing fast once `locked` is 1.
const RETICLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.29, 0.14, 1.0);
uniform float locked = 0.0;
uniform float flash = 0.0;
uniform float share = 0.0;
uniform float spin = 0.0;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.x, -q.y);
	float turn = fract(a / 6.2831853 + 1.0);
	float ring = smoothstep(0.07, 0.0, abs(r - 0.93));
	float arc = smoothstep(0.05, 0.0, abs(r - 0.82)) * step(turn, share);
	float ta = mod(a - spin + 0.3927, 1.5708) - 0.3927;
	float ticks = step(abs(ta), 0.05) * step(0.68, r) * step(r, 1.0);
	float cross = (step(abs(q.x), 0.025) + step(abs(q.y), 0.025)) * step(r, 0.18);
	float hatch = step(0.7, fract((q.x - q.y) * 5.0 + clock * 0.5)) * 0.12 * step(r, 0.9);
	float pulse = 0.75 + 0.25 * sin(clock * (5.0 + 9.0 * locked));
	float lit = (ring + ticks) * (0.6 + 0.4 * locked) * pulse + arc * 0.9 + cross * 0.8 + flash * 0.6;
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.95, 0.85), clamp(flash + 0.5 * locked * ring, 0.0, 1.0)) * (1.0 + lit);
	ALPHA = clamp(lit + hatch * (0.5 + 0.5 * locked) + 0.05 * step(r, 0.93), 0.0, 0.95) * step(r, 1.0);
}
"""
## A ring a body wears on a floor quad of radius 1, drawn over walls and boulders (the hero behind a boulder keeps it):
## `pulse` 0 steady, 1 pulsing fast; `fill` how much of the inside glows faintly.
const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.36, 0.9, 0.88, 1.0);
uniform float alpha = 1.0;
uniform float pulse = 0.0;
uniform float fill = 0.15;
uniform float share = 1.0;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float turn = fract(atan(q.x, -q.y) / 6.2831853 + 1.0);
	float edge = smoothstep(0.1, 0.0, abs(r - 0.88)) * step(turn, share);
	float beat = mix(1.0, 0.55 + 0.45 * sin(clock * 9.0), pulse);
	ALBEDO = tint.rgb * (1.0 + edge);
	ALPHA = clamp(alpha * beat * (edge + fill * step(r, 0.88)), 0.0, 0.95) * step(r, 1.0);
}
"""
## The cover's shadow (UV.y 0 at the boulder, 1 at its far end): a cool wash fading out with distance, its two side
## edges brighter.
const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.36, 0.9, 0.88, 1.0);
uniform float alpha = 0.0;

void fragment() {
	float fade = 1.0 - smoothstep(0.35, 1.0, UV.y);
	float side = smoothstep(0.08, 0.0, min(UV.x, 1.0 - UV.x));
	ALBEDO = tint.rgb * (1.0 + side);
	ALPHA = clamp(alpha * fade * (0.32 + 0.5 * side), 0.0, 0.8);
}
"""
## How far a boulder's shadow reaches past it when nothing in the room cuts it short (m).
const SHADOW_REACH_M := 30.0

static var _reticle: Shader
static var _halo: Shader
static var _shadow: Shader


static func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s


## A hidden floor quad (2 m across: its scale is a radius) under `parent` on its own material of `which` (&"reticle"
## or &"halo") in `tint`.
static func floor_quad(parent: Node3D, which: StringName, tint: Color) -> MeshInstance3D:
	if _reticle == null:
		_reticle = _shader(RETICLE_SHADER)
		_halo = _shader(HALO_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _reticle if which == &"reticle" else _halo
	m.set_shader_parameter("tint", tint)
	m.render_priority = 1
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


static func shadow_material() -> ShaderMaterial:
	if _shadow == null:
		_shadow = _shader(SHADOW_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _shadow
	m.set_shader_parameter("tint", SAFE)
	m.render_priority = 2
	return m


static func param(mi: MeshInstance3D, key: StringName, value: Variant) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter(key, value)


## The shadow square boulder (`centre`, half side `half`) casts away from `from` (the Engine's centre), clipped to
## `room`: the polygon of points whose line to `from` crosses the boulder, past it (sim plane, in order round it);
## empty when `from` is inside the boulder. Each point carries [position, along 0..1 across the shadow, how far out
## 0..1].
static func shadow_of(centre: Vector2, half: float, from: Vector2, room: Rect2) -> Array:
	var corners := [
		centre + Vector2(-half, -half),
		centre + Vector2(half, -half),
		centre + Vector2(half, half),
		centre + Vector2(-half, half),
	]
	var to := centre - from
	if absf(to.x) <= half and absf(to.y) <= half:
		return []
	var base := to.angle()
	var lo: Vector2 = corners[0]
	var hi: Vector2 = corners[0]
	var lo_a := INF
	var hi_a := -INF
	for c: Vector2 in corners:
		var a := wrapf((c - from).angle() - base, -PI, PI)
		if a < lo_a:
			lo_a = a
			lo = c
		if a > hi_a:
			hi_a = a
			hi = c
	var reach := SHADOW_REACH_M + room.size.length()
	var poly := PackedVector2Array(
		[
			lo,
			hi,
			hi + (hi - from).normalized() * reach,
			lo + (lo - from).normalized() * reach,
		]
	)
	poly = clip_to(poly, room)
	var out := []
	var span := lo.distance_to(hi)
	var axis := (hi - lo) / maxf(span, 0.001)
	for p: Vector2 in poly:
		var along := clampf((p - lo).dot(axis) / maxf(span, 0.001), 0.0, 1.0)
		var depth := absf((p - lo).dot(axis.orthogonal()))
		out.append([p, along, clampf(depth / maxf(room.size.length() * 0.5, 1.0), 0.0, 1.0)])
	return out


## `poly` (convex) clipped to `rect` (Sutherland-Hodgman).
static func clip_to(poly: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var out := poly
	var edges := [
		[Vector2(1, 0), rect.position.x],
		[Vector2(-1, 0), -rect.end.x],
		[Vector2(0, 1), rect.position.y],
		[Vector2(0, -1), -rect.end.y],
	]
	for e: Array in edges:
		var n: Vector2 = e[0]
		var d: float = e[1]
		var src := out
		out = PackedVector2Array()
		for k in src.size():
			var a := src[k]
			var b := src[(k + 1) % src.size()]
			var da := a.dot(n) - d
			var db := b.dot(n) - d
			if da >= 0.0:
				out.append(a)
			if (da >= 0.0) != (db >= 0.0):
				out.append(a + (b - a) * (da / (da - db)))
		if out.is_empty():
			return out
	return out


## The boulder's rock: the kit's large rock (its own material copy, so one boulder's cracks never show on another), or
## a box in the rock's colour without the kit. Sized by the caller (x, z: the boulder's side; y: ROCK_H).
static func rock(parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var piece := KitModels.get_piece(ROCK_MODEL)
	var mat: StandardMaterial3D = null
	if not piece.is_empty():
		mi.mesh = piece["mesh"]
		var src := piece["material"] as StandardMaterial3D
		mat = (src.duplicate() as StandardMaterial3D) if src != null else null
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mi.mesh = box
		mi.position.y = 0.5
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.46, 0.41, 0.36)
		mat.roughness = 0.95
	mat.emission_enabled = true
	mat.emission = CRACK
	mat.emission_energy_multiplier = 0.0
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _solid(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## The ammo cart (a stand-in in code until the owner's model): a red wagon bed with dark side plates, four grey
## wheels, three glowing red shells lying in it and a tow bar toward +X (its front: the way it rolls). About 2 m long
## and 1.3 m wide, the cart's 1 m radius. Returns [root, its wheels].
static func cart(parent: Node3D) -> Array:
	var root := Node3D.new()
	parent.add_child(root)
	var hull := _solid(HULL)
	var plate := _solid(PLATE)
	var metal := _solid(METAL)
	_box(root, Vector3(1.7, 0.42, 1.1), Vector3(0, 0.62, 0), hull)
	_box(root, Vector3(1.74, 0.3, 0.08), Vector3(0, 0.78, 0.56), plate)
	_box(root, Vector3(1.74, 0.3, 0.08), Vector3(0, 0.78, -0.56), plate)
	_box(root, Vector3(0.08, 0.3, 1.1), Vector3(-0.86, 0.78, 0), plate)
	_box(root, Vector3(0.7, 0.07, 0.07), Vector3(1.18, 0.42, 0), metal)
	var shell := _solid(GLOW, 1.6)
	for k in 3:
		var cap := CapsuleMesh.new()
		cap.radius = 0.15
		cap.height = 1.2
		cap.radial_segments = 8
		cap.rings = 2
		var mi := MeshInstance3D.new()
		mi.mesh = cap
		mi.material_override = shell
		mi.rotation.z = PI * 0.5
		mi.position = Vector3(0, 0.98, (float(k) - 1.0) * 0.32)
		root.add_child(mi)
	var wheels: Array[Node3D] = []
	var wheel_mat := _solid(METAL_DARK)
	for x: float in [-0.55, 0.55]:
		for z: float in [-0.62, 0.62]:
			var w := CylinderMesh.new()
			w.top_radius = 0.34
			w.bottom_radius = 0.34
			w.height = 0.14
			w.radial_segments = 10
			w.rings = 1
			var spin := Node3D.new()
			spin.position = Vector3(x, 0.34, z)
			root.add_child(spin)
			var mi := MeshInstance3D.new()
			mi.mesh = w
			mi.material_override = wheel_mat
			mi.rotation.x = PI * 0.5
			spin.add_child(mi)
			_box(spin, Vector3(0.5, 0.06, 0.16), Vector3.ZERO, metal)
			wheels.append(spin)
	return [root, wheels]


## Transform: `scale` uniform at `pos`.
static func at(pos: Vector3, scale: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), pos)
