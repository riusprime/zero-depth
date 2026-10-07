class_name PortalGate
extends Node3D
## The gateway to the next floor (v0.2.0 PLAN L8, step D): two stacked-stone pillars and a lintel around a
## 2.4 × 3.2 m rectangle of swirling blue light, like a cartoon portal in a door shape (owner, L12: "the portal
## should be blue, not green": a deep electric blue with cyan-white highlights, bluer than the player's cyan).
## Presentation only: it reads nothing from the sim and decides nothing (EI-07). Sealed (the default) slows and dims
## the swirl under a dark veil; v0.3.0 B: the view unseals it when the sim's portal opens (the boss is dead), with a
## brief flare, and the open swirl runs bright and fast.
##
## Local frame: the opening spans local Z, the gate faces local +X; setup() turns +X to the sim facing angle.

const OPENING_W := 2.4
const OPENING_H := 3.2
const PILLAR_W := 0.33
const DEPTH := 0.72
const STONE := Color("#6F6A66")
const STONE_TOP := Color("#8A847E")
const PORTAL_BLUE := Color("#2E62FF")
## The swirl's colours, dark to light, and the floor glow.
const SWIRL_DEEP := Color(0.03, 0.08, 0.52)
const SWIRL_MID := Color(0.13, 0.36, 1.0)
const SWIRL_LIGHT := Color(0.74, 0.9, 1.0)
const GLOW := Color(0.16, 0.36, 1.0)
const LIGHT_ENERGY_OPEN := 2.2
const LIGHT_ENERGY_SEALED := 0.7
## The flare when the portal opens: extra light energy, fading over FLARE_SECONDS.
const FLARE_ENERGY := 5.0
const FLARE_SECONDS := 1.2

## Stacked blocks of one pillar, bottom to top: [height, width, depth, z offset, y-rotation°, z-roll°].
## Hand-picked (not random) so every gate looks the same and the opening stays clear.
const PILLAR_BLOCKS := [
	[0.36, 0.50, 0.90, 0.06, 2.0, 0.0],
	[1.02, 0.35, 0.74, 0.01, -2.5, 1.2],
	[0.94, 0.37, 0.70, 0.03, 3.0, -1.0],
	[0.88, 0.34, 0.76, 0.00, -1.5, 0.8],
]

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_prepass_alpha, shadows_disabled, fog_disabled;

uniform vec2 opening_size = vec2(2.4, 3.2);
uniform vec4 color_deep : source_color = vec4(0.03, 0.08, 0.52, 1.0);
uniform vec4 color_mid : source_color = vec4(0.13, 0.36, 1.0, 1.0);
uniform vec4 color_light : source_color = vec4(0.74, 0.9, 1.0, 1.0);
uniform vec4 veil_color : source_color = vec4(0.02, 0.03, 0.08, 1.0);
uniform float swirl_speed = 1.0;
uniform float energy = 1.6;
uniform float sealed = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	vec2 half_size = opening_size * 0.5;
	vec2 p = (UV - 0.5) * opening_size;
	// Distance to the frame (m): the portal keeps the door's rectangle.
	float d_edge = min(half_size.x - abs(p.x), half_size.y - abs(p.y));
	// Radius normalised so the swirl fills the rectangle rather than a circle.
	vec2 q = p / half_size.x;
	float r = length(q);
	float speed = swirl_speed * mix(1.25, 0.15, sealed);
	float t = TIME * speed;
	// Two noise layers twisted into a vortex that turns faster near the centre.
	vec2 s1 = rot(q, t * 1.3 + 1.4 / (r + 0.45));
	vec2 s2 = rot(q, -t * 0.7 + 0.9 / (r + 0.6));
	float n1 = fbm(s1 * 2.2 + vec2(0.0, t * 0.15));
	float n2 = fbm(s2 * 3.6 - vec2(t * 0.1, 0.0));
	// Spiral arms: bands that wind round the centre.
	float ang = atan(q.y, q.x);
	float arms = 0.5 + 0.5 * sin(ang * 3.0 + log(r + 0.05) * 5.0 - t * 4.0 + n1 * 3.0);
	float v = clamp(arms * 0.6 + n1 * 0.5 + n2 * 0.25 - 0.2, 0.0, 1.0);
	vec3 col = mix(color_deep.rgb, color_mid.rgb, smoothstep(0.15, 0.6, v));
	col = mix(col, color_light.rgb, smoothstep(0.62, 0.95, v));
	// A lighter core and a bright rim close to the stone.
	float core = 1.0 - smoothstep(0.0, 0.55, r);
	col = mix(col, color_light.rgb, core * 0.75);
	float rim = 1.0 - smoothstep(0.0, 0.3, d_edge + (n2 - 0.5) * 0.12);
	col = mix(col, color_light.rgb * 1.4, rim * 0.9);
	float bright = energy * mix(1.15, 0.38, sealed);
	col *= bright;
	// Sealed: a faint dark veil that drifts over the swirl.
	float veil = sealed * (0.45 + 0.2 * fbm(p * 1.4 + vec2(t * 0.2, -t * 0.1)));
	col = mix(col, veil_color.rgb, veil * (1.0 - rim * 0.6));
	ALBEDO = col;
	ALPHA = mix(0.55, 1.0, smoothstep(0.0, 0.07, d_edge));
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(0.16, 0.36, 1.0, 1.0);
uniform float strength = 0.55;

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float a = pow(1.0 - smoothstep(0.0, 1.0, r), 1.6);
	ALBEDO = glow_color.rgb * a * strength;
}
"""

var portal: MeshInstance3D
var portal_material: ShaderMaterial
var glow_material: ShaderMaterial
var light: OmniLight3D
var stone_blocks: Array[MeshInstance3D] = []
var _sealed := true
var _flare := 0.0
var _stone := StandardMaterial3D.new()
var _stone_top := StandardMaterial3D.new()


func _init() -> void:
	_stone.albedo_color = STONE
	_stone.roughness = 1.0
	_stone_top.albedo_color = STONE_TOP
	_stone_top.roughness = 1.0
	_build_stone()
	_build_portal()
	_build_glow()
	set_sealed(true)


## Places the gate at `sim_pos` facing the sim direction `facing_angle` (1/4096 turn).
func setup(sim_pos: Vector2, facing_angle: int) -> void:
	position = SimPlane.to_3d(sim_pos)
	rotation = Vector3(0, SimPlane.yaw_of(facing_angle), 0)


func set_sealed(sealed: bool) -> void:
	if _sealed and not sealed and is_inside_tree():
		_flare = FLARE_SECONDS
	_sealed = sealed
	portal_material.set_shader_parameter("sealed", 1.0 if sealed else 0.0)
	light.light_energy = LIGHT_ENERGY_SEALED if sealed else LIGHT_ENERGY_OPEN
	glow_material.set_shader_parameter("strength", 0.32 if sealed else 0.55)


func is_sealed() -> bool:
	return _sealed


func _process(delta: float) -> void:
	if _flare <= 0.0:
		return
	_flare = maxf(0.0, _flare - delta)
	var k := _flare / FLARE_SECONDS
	light.light_energy = LIGHT_ENERGY_OPEN + FLARE_ENERGY * k * k
	glow_material.set_shader_parameter("strength", 0.55 + 0.6 * k)


## Optional: tint the stone from a biome palette's `cover` token (a little darker, so the gate stands apart).
func set_stone_color(c: Color) -> void:
	_stone.albedo_color = c
	_stone_top.albedo_color = c.lightened(0.12)


func _block(size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var node := MeshInstance3D.new()
	node.mesh = box
	node.material_override = mat
	node.position = pos
	node.rotation_degrees = rot_deg
	add_child(node)
	stone_blocks.append(node)


func _build_stone() -> void:
	var inner := OPENING_W * 0.5
	for side in [-1.0, 1.0]:
		var y := 0.0
		for i in PILLAR_BLOCKS.size():
			var b: Array = PILLAR_BLOCKS[i]
			var h: float = b[0]
			var w: float = b[1]
			# Blocks grow outward from the opening's edge, so the opening stays 2.4 m clear.
			var z: float = side * (inner + w * 0.5 + b[3])
			var mat := _stone_top if i == PILLAR_BLOCKS.size() - 1 else _stone
			_block(
				Vector3(b[2], h, w),
				Vector3(0, y + h * 0.5, z),
				Vector3(0, b[4] * side, b[5] * side),
				mat
			)
			y += h
	# Lintel: two long stones and a raised keystone, over the full width.
	var outer := inner + PILLAR_W + 0.12
	var top := OPENING_H
	_block(
		Vector3(0.78, 0.44, outer - 0.28),
		Vector3(0, top + 0.22, -(outer + 0.28) * 0.5),
		Vector3(0, 1.5, -1.2),
		_stone
	)
	_block(
		Vector3(0.80, 0.42, outer - 0.28),
		Vector3(0, top + 0.21, (outer + 0.28) * 0.5),
		Vector3(0, -2.0, 1.0),
		_stone
	)
	_block(Vector3(0.86, 0.66, 0.58), Vector3(0, top + 0.31, 0), Vector3(0, 0, 0), _stone_top)
	# A thin cap slab and two fallen stones at the foot.
	_block(
		Vector3(0.9, 0.16, outer * 2.0 + 0.1),
		Vector3(0.02, top + 0.52, 0.04),
		Vector3(0, 0.8, 0.6),
		_stone_top
	)
	_block(
		Vector3(0.34, 0.22, 0.3), Vector3(0.55, 0.11, -(inner + 0.62)), Vector3(0, 28, 0), _stone
	)
	_block(
		Vector3(0.24, 0.16, 0.26), Vector3(-0.45, 0.08, inner + 0.66), Vector3(0, -17, 0), _stone
	)


func _build_portal() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(OPENING_W, OPENING_H)
	portal_material = ShaderMaterial.new()
	portal_material.shader = Shader.new()
	portal_material.shader.code = SHADER
	portal_material.set_shader_parameter("opening_size", Vector2(OPENING_W, OPENING_H))
	portal_material.set_shader_parameter("color_deep", SWIRL_DEEP)
	portal_material.set_shader_parameter("color_mid", SWIRL_MID)
	portal_material.set_shader_parameter("color_light", SWIRL_LIGHT)
	portal = MeshInstance3D.new()
	portal.mesh = quad
	portal.material_override = portal_material
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The quad faces +Z; a quarter turn makes it face the gate's +X, spanning local Z.
	portal.rotation = Vector3(0, PI * 0.5, 0)
	portal.position = Vector3(0, OPENING_H * 0.5, 0)
	add_child(portal)
	light = OmniLight3D.new()
	light.light_color = PORTAL_BLUE
	light.omni_range = 5.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0.9, 1.3, 0)
	add_child(light)


func _build_glow() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.4, 3.6)
	glow_material = ShaderMaterial.new()
	glow_material.shader = Shader.new()
	glow_material.shader.code = GLOW_SHADER
	glow_material.set_shader_parameter("glow_color", GLOW)
	var disc := MeshInstance3D.new()
	disc.mesh = plane
	disc.material_override = glow_material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Mostly in front of the gate (+X), a little behind it.
	disc.position = Vector3(0.7, 0.02, 0)
	add_child(disc)
