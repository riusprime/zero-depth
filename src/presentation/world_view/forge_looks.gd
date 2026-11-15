class_name ForgeLooks
extends RefCounted
## What the Foundry's forge views share: their colours, the floor shaders (a pool's crust as it cools, a slab, the
## Overpressure's burning floor with the safe slabs cut out of it) and the pack colour sets. Looks only (EI-07).

## The plate's cold iron and the shards it bursts into.
const STEEL := Color("#9AA4B0")
const STEEL_DARK := Color("#4A525C")
## The forge's own fire: the hammer's sparks and the floor's heat, hot orange to white.
const HOT := Color("#FF7A2A")
const WHITE_HOT := Color("#FFE2B0")
## A slab's basalt (a lit grey stone, so it reads as a solid plate, not a pit) and the cool rim that reads "safe":
## blue-grey, far from the lava's oranges.
const BASALT := Color("#5A534E")
const COOL := Color("#7FC4E8")
## How far (m) a drone's bomb may land from the Foundry's edge and still blow its plate off: data/bosses/foundry.tres
## forge "drone_blast_m" (the reader does not give it; BossForge._blasts reads it from BossForgeTable).
const DRONE_BLAST_M := 1.5
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
## A slab on a disc of radius 1: dark basalt with a raised, lit face, a cool rim, and dull orange cracks that spread
## as `crack` rises (its time running out); `safe` brightens the rim and pulses it (the Overpressure counts it);
## `alpha` fades it as it crumbles.
const SLAB_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 basalt : source_color = vec4(0.14, 0.13, 0.13, 1.0);
uniform vec4 rim : source_color = vec4(0.5, 0.77, 0.91, 1.0);
uniform vec4 seam : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform float crack = 0.0;
uniform float safe = 0.0;
uniform float alpha = 1.0;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float n = texture(noise_tex, q * 0.5 + vec2(seed * 0.3, seed)).r;
	float n2 = texture(noise_tex, q * 1.3 - vec2(seed, seed * 0.4)).r;
	vec2 lit_dir = normalize(vec2(-0.6, -0.8));
	float face = 0.95 + 0.45 * (n - 0.5) + 0.35 * step(0.78, n2);
	float bevel = smoothstep(0.78, 0.88, r) * (1.0 - smoothstep(0.9, 0.97, r));
	float lit = clamp(dot(normalize(q + vec2(0.0001)), lit_dir), -1.0, 1.0);
	float edge = smoothstep(0.7, 0.86, r) * (1.0 - smoothstep(0.86, 0.9, r));
	float lines = smoothstep(0.025, 0.0, abs(n2 - 0.5)) * step(1.0 - crack, n * 0.8 + r * 0.4);
	float beat = mix(1.0, 0.75 + 0.25 * sin(clock * 5.0), safe);
	vec3 col = basalt.rgb * face * (1.0 + 0.35 * edge * lit);
	col = mix(col, rim.rgb * (0.7 + 0.8 * safe) * beat, bevel * (0.55 + 0.45 * safe));
	col = mix(col, seam.rgb * 0.8, lines * crack);
	ALBEDO = col;
	ALPHA = alpha * smoothstep(1.0, 0.96, r);
}
"""
## The Overpressure's floor over the room (a plane 1 m across scaled to it): a heat shimmer rising with `level`,
## burning with `burn` (never above 0.42 opaque); each slab in `holes` ((x, z) from the plane's centre, radius) is
## cut out, ringed in cool blue.
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
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

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
		ring = max(ring, smoothstep(0.3, 0.0, abs(d - 0.12)));
	}
	float n = texture(noise_tex, p * 0.07 + vec2(clock * 0.05, -clock * 0.08)).r;
	float n2 = texture(noise_tex, p * 0.19 - vec2(clock * 0.11, clock * 0.04)).r;
	float flame = smoothstep(0.55, 0.8, n * 0.6 + n2 * 0.6) * burn;
	vec2 e = min(UV, 1.0 - UV) * room_size;
	float edge = smoothstep(0.0, 1.0, min(e.x, e.y));
	vec3 col = mix(heat.rgb, white.rgb, 0.2 * n + 0.6 * flame);
	float a = open * level * (0.16 + 0.12 * n + 0.14 * burn + 0.2 * flame);
	ALBEDO = mix(col, cool.rgb * 1.4, ring * (1.0 - open * 0.5));
	ALPHA = clamp(max(a, ring * level * 0.7) * edge, 0.0, 0.42);
}
"""

static var _shaders := {}


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
