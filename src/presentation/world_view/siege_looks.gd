class_name SiegeLooks
extends RefCounted
## What the Siege Engine's fight views share: their colours, the floor shaders (the Target Lock's reticle, the ring a
## body wears that shows through walls, the cover's shadow, the cart's ruts and its plain floor rings), the boulder's
## rock, and the geometry of the shadow a boulder casts away from the Engine. The ammo cart's wagon is SiegeCartModel.
## Looks only (EI-07).

## The Engine's palette (SiegeEngineAvatar): its red hull, dark plates, grey metal, its red glow.
const HULL := Color("#D23E35")
const PLATE := Color("#2B2C31")
const METAL := Color("#6A6462")
const METAL_DARK := Color("#4C4847")
const GLOW := Color("#FF3A26")
## The lock's reticle and every "do not stand here" read: a hot red-orange.
const DANGER := Color("#FF4A24")
## The cover's safe read (the rim of the shadow behind a boulder, the ring on a covered hero): a pale cool slate, far
## from the reds and from the hero's own cyan; the shadow itself is a dark cool shade over the floor.
const SAFE := Color("#A9C3D2")
const SHADE := Color("#0B1220")
## The cart's floor rings: its blast circle (dull red, a dull gold once the Engine stands in it) and the Engine's
## countdown ring (a dull red).
const BLAST := Color("#C0543C")
const BLAST_GOLD := Color("#D2A85A")
const COUNTDOWN := Color("#94392C")
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
## The cover's shadow (UV.y 0 at the boulder, 1 at its far end): a dark cool shade over the floor, as a real cast
## shadow reads, fading out with distance, its two side edges a thin faint pale rim so its shape reads on any floor.
const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.66, 0.76, 0.82, 1.0);
uniform vec4 shade : source_color = vec4(0.04, 0.07, 0.12, 1.0);
uniform float alpha = 0.0;

void fragment() {
	float fade = 1.0 - smoothstep(0.45, 1.0, UV.y);
	float side = smoothstep(0.022, 0.008, min(UV.x, 1.0 - UV.x));
	ALBEDO = mix(shade.rgb, tint.rgb * 0.75, side);
	ALPHA = clamp(alpha * fade * mix(0.62, 0.4, side), 0.0, 0.7);
}
"""
## The cart's track (a unit plane along +X laid as a strip as wide as SiegeCartViews' track): two wheel ruts pressed
## into the floor, each a dark groove with a pale lip on its outer side where the floor's edge catches the light;
## `fresh` 1 behind the cart (deeper, churned).
const RUT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 groove : source_color = vec4(0.06, 0.05, 0.05, 1.0);
uniform vec4 lip : source_color = vec4(0.66, 0.6, 0.52, 1.0);
uniform float alpha = 0.5;
uniform float fresh = 0.0;
uniform float length_m = 10.0;
uniform float clock = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	float y = abs(UV.y * 2.0 - 1.0);
	float n = texture(noise_tex, vec2(UV.x * length_m * 0.4, UV.y * 0.7)).r;
	float rut = 1.0 - smoothstep(0.075, 0.11, abs(y - 0.74) + (n - 0.5) * 0.04);
	float lip_l = (1.0 - smoothstep(0.012, 0.04, abs(y - 0.88))) * (0.55 + 0.45 * n);
	float grit = step(0.8, n) * step(abs(y - 0.74), 0.2) * fresh * 0.35;
	float fade = smoothstep(0.0, 0.03, UV.x) * (1.0 - smoothstep(0.97, 1.0, UV.x));
	ALBEDO = mix(groove.rgb, lip.rgb, max(lip_l, grit) * (1.0 - rut));
	ALPHA = clamp(alpha * fade * max(rut * (0.8 + 0.2 * fresh), max(lip_l * 0.75, grit)), 0.0, 0.9);
}
"""
## A plain floor ring of radius 1 (the cart's blast circle, the Engine's countdown): a thin dull band at the rim (its
## first `share` of a turn full, the rest faint), a faint wash inside, a disc growing from the middle to `fill`;
## `locked` 1 strengthens it and beats it slowly, `flash` lifts it toward a pale heat. No stripes, no glow halo.
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.75, 0.33, 0.24, 1.0);
uniform float alpha = 1.0;
uniform float share = 1.0;
uniform float locked = 0.0;
uniform float flash = 0.0;
uniform float fill = 0.0;
uniform float edge = 0.05;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float turn = fract(atan(q.x, -q.y) / 6.2831853 + 1.0);
	float band = 1.0 - smoothstep(edge * 0.5, edge, abs(r - (1.0 - edge)));
	float arc = mix(0.3, 1.0, step(turn, share));
	float beat = 1.0 - 0.15 * locked * (0.5 + 0.5 * sin(clock * 4.0));
	float grow = step(r, fill) * 0.16;
	float wash = 0.05 * step(r, 1.0 - edge);
	ALBEDO = mix(tint.rgb, vec3(0.95, 0.86, 0.72), flash * 0.6);
	ALPHA = clamp(alpha * (band * arc * (0.7 + 0.3 * locked) * beat + grow + wash + flash * 0.3), 0.0, 0.85);
	ALPHA *= step(r, 1.0);
}
"""
## How far a boulder's shadow reaches past it when nothing in the room cuts it short (m).
const SHADOW_REACH_M := 30.0

static var _reticle: Shader
static var _halo: Shader
static var _shadow: Shader
static var _rut: Shader
static var _plain_ring: Shader


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
	m.set_shader_parameter("shade", SHADE)
	m.render_priority = 2
	return m


## A hidden strip of the cart's ruts under `parent` (laid with WardenLooks.lay_strip), on its own material.
static func ruts(parent: Node3D) -> MeshInstance3D:
	if _rut == null:
		_rut = _shader(RUT_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _rut
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	m.render_priority = -1
	var mi := MeshInstance3D.new()
	mi.mesh = WardenLooks.plane()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


## A hidden plain floor ring (2 m across: its scale is a radius) under `parent` in `tint`, on its own material.
static func plain_ring(parent: Node3D, tint: Color) -> MeshInstance3D:
	if _plain_ring == null:
		_plain_ring = _shader(RING_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _plain_ring
	m.set_shader_parameter("tint", tint)
	m.render_priority = -1
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


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


## Transform: `scale` uniform at `pos`.
static func at(pos: Vector3, scale: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), pos)
