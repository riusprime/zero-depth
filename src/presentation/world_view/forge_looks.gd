class_name ForgeLooks
extends RefCounted
## What the Foundry's forge views share: their colours, the floor shaders (a pool's crust as it cools, the
## Overpressure's burning floor with the slabs cut out of it), a slab's basalt plinth and its shader, and the pack
## colour sets. Looks only (EI-07).

## The plate's cold iron and the shards it bursts into.
const STEEL := Color("#9AA4B0")
const STEEL_DARK := Color("#4A525C")
## The forge's own fire: the hammer's sparks and the floor's heat, hot orange to white.
const HOT := Color("#FF7A2A")
const WHITE_HOT := Color("#FFE2B0")
## A slab's basalt (a grey stone light enough to catch the room's light as the walls do, so it reads as a solid
## plinth, not a pit) and the cool rim that reads "safe": blue-grey, far from the lava's oranges.
const BASALT := Color("#8A817A")
const COOL := Color("#7FC4E8")
## A slab's plinth: how high it stands (m) and its sides.
const PLINTH_H := 0.24
const PLINTH_SIDES := 9
## Sorts under the telegraphs and the bodies (as the Tidecaller's water does).
const UNDER := -2
## The most slabs the burning floor cuts out at once.
const HOLES := 8

const SPARK_COLORS := {
	&"primary": Color(1.0, 0.86, 0.5),
	&"secondary": Color(1.0, 0.5, 0.16),
	&"tertiary": Color(0.55, 0.16, 0.04)
}
const SHARD_COLORS := {
	&"primary": Color(0.85, 0.88, 0.92),
	&"secondary": Color(0.55, 0.6, 0.66),
	&"tertiary": Color(0.22, 0.24, 0.28)
}
const DUST_COLORS := {
	&"primary": Color(0.42, 0.38, 0.36),
	&"secondary": Color(0.26, 0.23, 0.22),
	&"tertiary": Color(0.12, 0.1, 0.1)
}
const STEAM_COLORS := {
	&"primary": Color(0.95, 0.97, 1.0),
	&"secondary": Color(0.78, 0.86, 0.92),
	&"tertiary": Color(0.5, 0.58, 0.66)
}

## A pool's crust on a disc of radius 1: dark patches grow over the lava as `cool` rises (0 bright lava, 1 crust),
## and the lava showing between them dims.
const CRUST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 crust : source_color = vec4(0.14, 0.12, 0.11, 1.0);
uniform vec4 seam : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float cool = 0.0;
uniform float seed = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float n = texture(noise_tex, q * 0.35 + vec2(seed, seed * 0.7)).r;
	float cover = smoothstep(n - 0.04, n + 0.04, cool * 1.15 - 0.1 + 0.25 * r);
	float line = smoothstep(0.06, 0.0, abs(cool * 1.15 - 0.1 + 0.25 * r - n)) * (1.0 - cool * 0.8);
	ALBEDO = mix(crust.rgb, seam.rgb * 1.6, line);
	ALPHA = clamp(cover * 0.92 + line * 0.6, 0.0, 0.95) * smoothstep(1.0, 0.92, r);
}
"""
## A slab: a low faceted basalt plinth (plinth_mesh, radius 1 and PLINTH_H tall; the node's x and z scale are its
## radius), shaded like the kit's stone (matte, lit by the room; the InkPass outlines it), a faint cool rim along its
## top's edge, and dull orange cracks across its top that spread as `crack` rises (its time running out); `safe`
## strengthens the rim and beats it slowly (the Overpressure counts it); `alpha` under 1 sinks it into the floor as it
## crumbles.
const SLAB_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 basalt : source_color = vec4(0.35, 0.33, 0.31, 1.0);
uniform vec4 rim : source_color = vec4(0.5, 0.77, 0.91, 1.0);
uniform vec4 seam : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform float crack = 0.0;
uniform float safe = 0.0;
uniform float alpha = 1.0;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform float height = 0.24;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 lp;

void vertex() {
	lp = VERTEX;
	VERTEX.y -= (1.0 - alpha) * (height + 0.08);
}

void fragment() {
	float r = length(lp.xz);
	float top = step(height - 0.005, lp.y);
	float n = texture(noise_tex, lp.xz * 0.6 + vec2(seed * 0.3, seed)).r;
	float n2 = texture(noise_tex, lp.xz * 1.4 - vec2(seed, seed * 0.4)).r;
	float lines = smoothstep(0.03, 0.0, abs(n2 - 0.5)) * step(1.0 - crack, n * 0.8 + r * 0.4) * top;
	float edge = top * smoothstep(0.74, 0.86, r);
	float beat = mix(1.0, 0.8 + 0.2 * sin(clock * 3.0), safe);
	ALBEDO = mix(basalt.rgb * (0.9 + 0.3 * (n - 0.5)), seam.rgb * 0.35, lines * crack);
	ALBEDO = mix(ALBEDO, rim.rgb * 0.7, edge * (0.25 + 0.35 * safe));
	EMISSION = rim.rgb * edge * (0.08 + 0.5 * safe) * beat + seam.rgb * lines * crack * 0.7;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
"""
## The Overpressure's floor over the room (a plane 1 m across scaled to it): the floor's own tiles show; heat rises
## along their seams (the stage's TILE_M grid) with `level`, a slow pulse running through it, a faint warm cast over
## the tiles, the seams hotter with `burn`; each slab in `holes` ((x, z) from the plane's centre, radius) is cut out
## with a thin cool edge round it.
const HEAT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 heat : source_color = vec4(1.0, 0.36, 0.1, 1.0);
uniform vec4 white : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform vec4 cool : source_color = vec4(0.5, 0.77, 0.91, 1.0);
uniform vec2 room_size = vec2(24.0, 24.0);
uniform vec3 holes[8];
uniform int hole_n = 0;
uniform float level = 0.0;
uniform float burn = 0.0;
uniform float clock = 0.0;
uniform float tile_m = 4.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (UV - 0.5) * room_size;
	float open = 1.0;
	float ring = 0.0;
	for (int k = 0; k < 8; k++) {
		if (k >= hole_n) {
			break;
		}
		float d = length(p - holes[k].xy) - holes[k].z;
		open = min(open, smoothstep(0.0, 0.35, d));
		ring = max(ring, smoothstep(0.12, 0.0, abs(d - 0.1)));
	}
	vec2 g = abs(fract(wp.xz / tile_m + 0.5) - 0.5) * tile_m;
	float sd = min(g.x, g.y);
	float n = texture(noise_tex, wp.xz * 0.11 + vec2(clock * 0.02, -clock * 0.03)).r;
	float n2 = texture(noise_tex, wp.xz * 0.43).r;
	float seam = 1.0 - smoothstep(0.02, 0.06 + 0.06 * n, sd + (n2 - 0.5) * 0.06);
	float run = smoothstep(0.3, 0.7, n2 * 0.7 + n * 0.5);
	float halo = (1.0 - smoothstep(0.06, 0.45, sd)) * run;
	float pulse = 0.7 + 0.3 * sin(clock * 1.6 - n * 3.0);
	vec2 e = min(UV, 1.0 - UV) * room_size;
	float edge = smoothstep(0.0, 1.0, min(e.x, e.y));
	vec3 col = mix(heat.rgb * 0.9, white.rgb, seam * run * 0.3 * burn * pulse);
	float hot = seam * (0.25 + 0.75 * run) * 0.7 + halo * 0.18;
	float a = open * level * (0.035 + 0.03 * burn + hot * (0.55 + 0.45 * burn) * pulse);
	ALBEDO = mix(col, cool.rgb, ring * (1.0 - open * 0.5));
	ALPHA = clamp(max(a, ring * level * 0.45) * edge, 0.0, 0.8);
}
"""

static var _shaders := {}
static var _plinth: ArrayMesh


static func shader(code: String) -> Shader:
	if not _shaders.has(code.hash()):
		var s := Shader.new()
		s.code = code
		_shaders[code.hash()] = s
	return _shaders[code.hash()]


## A hidden floor mesh (`size` across) under `parent`, on its own material of `code`, sorted at `priority`.
static func floor_mesh(parent: Node3D, code: String, size: float, priority: int) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = shader(code)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	m.render_priority = priority
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * size
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


## A hidden slab (plinth_mesh on its own SLAB_SHADER material) under `parent`.
static func slab(parent: Node3D) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = shader(SLAB_SHADER)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	m.set_shader_parameter("height", PLINTH_H)
	var mi := MeshInstance3D.new()
	mi.mesh = plinth_mesh()
	mi.material_override = m
	mi.visible = false
	parent.add_child(mi)
	return mi


## A low faceted plinth of radius 1 standing PLINTH_H on y = 0 (a little below, so it never floats): an uneven
## PLINTH_SIDES-gon, its top bevelled in, flat-shaded.
static func plinth_mesh() -> ArrayMesh:
	if _plinth != null:
		return _plinth
	var low := []
	var mid := []
	var top := []
	for k in PLINTH_SIDES:
		var a := TAU * (k + 0.37 * VfxCore.h(911, k)) / PLINTH_SIDES
		var r := 0.94 + 0.06 * VfxCore.h(912, k)
		var d := Vector3(cos(a), 0.0, sin(a))
		low.append(d * r + Vector3(0, -0.06, 0))
		mid.append(d * r + Vector3(0, PLINTH_H - 0.07, 0))
		top.append(d * (r - 0.12) + Vector3(0, PLINTH_H, 0))
	var tris := []
	for k in PLINTH_SIDES:
		var n := (k + 1) % PLINTH_SIDES
		tris.append([low[k], mid[k], mid[n]])
		tris.append([low[k], mid[n], low[n]])
		tris.append([mid[k], top[k], top[n]])
		tris.append([mid[k], top[n], mid[n]])
		if k > 0 and k < PLINTH_SIDES - 1:
			tris.append([top[0], top[k], top[n]])
	_plinth = AvatarBase.flat_mesh(tris, Vector3(0, PLINTH_H * 0.4, 0))
	return _plinth


static func param(mi: MeshInstance3D, key: StringName, value: Variant) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter(key, value)


static func get_param(mi: MeshInstance3D, key: StringName) -> Variant:
	return (mi.material_override as ShaderMaterial).get_shader_parameter(key)


## The boss room the Foundry fights in (the floor's boss room; else the meltdown's bound; else 24 m round `near`).
static func room_of(reader: WorldReader, near: Vector2) -> Rect2:
	if reader.has_boss_room() and reader.boss_room() >= 0:
		return reader.floor_room(reader.boss_room())
	for m: Dictionary in reader.boss_melts():
		var b: Rect2 = m["bound"]
		if b.has_area():
			return b
	return Rect2(near - Vector2(12, 12), Vector2(24, 24))
