class_name ShadeViews
extends Node3D
## v0.9.0 NB4 (BOSSES_4_5.md N4; PLAN NB "Keep the empty hood"; the VX quality bar: layered, never a flat
## single-colour shape): the Lantern Shade's dark, drawn from WorldReader.boss_light (EI-07: it reads; what is lit,
## what can be hit and which lantern burns are the sim's, BossShade).
## - The dark: a full-screen pass (ShadeDark.SHADER) finds each pixel's place on the floor from the depth buffer and
##   lays a violet-black over it, except inside the sim's light (your 3.5 m circle, each lit lantern's pool). Layered:
##   two drifting fog octaves break the dark and fray the light's edges, a vignette deepens the screen's corners, a
##   faint haze hangs inside the light, the lanterns' edges glow warm and yours cool. It ramps in over Lights Out's
##   4 s and stays while the Shade lives. It is drawn first of the see-through things: every marker, telegraph, bar and
##   strike effect draws over it (the dark never hides a marker), while the floor, the bodies and the wisps' solid
##   cores are darkened (the wisps glow only inside light).
## - The lanterns: four iron lantern posts on the room's edge, each with a caged glass, a flickering flame, a warm
##   light, a warm pool of light on the floor (lamp_m wide, over the dark) and a burn ring that empties as its 6 s run
##   down (flickering in its last second). An out lantern is cold glass with an ember and a dashed violet ring on the
##   floor (where to relight it); it puffs smoke as it goes out and flares as you relight it.
## - Your light: a cool shimmering ring at its edge and a pale light over you.
## - The wisps: every Shade wisp within 4 m of you shows a pale outline (never thinned by Effects density, and over
##   the dark), and a soft glow that brightens as it nears you (Wisp Bloom brightening).
## Effects density Low halves the smoke and sparks and drops the fog's second octave; reduced motion slows the fog and
## the flicker. Nothing here decides an outcome.

const MAX_LAMPS := 8
const WISP_LOOK := &"shade_wisp"
## Wisps within this of the hero always show their outline (BOSSES_4_5.md N4 fair rule).
const OUTLINE_M := 4.0
const MAX_WISPS := 96
const POST_H := 1.55
const WARM := Color(1.0, 0.64, 0.28)
const FLAME_CORE := Color(1.0, 0.92, 0.66)
const COOL := Color(0.62, 0.58, 0.95)
const OUT_RING := Color(0.55, 0.42, 0.85)
const WISP := Color(0.78, 0.66, 1.0)
const IRON := Color("#1C1822")
const LAMP_ENERGY := 2.4
const HERO_ENERGY := 2.2

## The dark pass's shared part: each pixel's place on the floor (from the depth buffer), the drifting fog, how lit it
## is (the sim's light circles, their edges frayed by the fog) and the lanterns' warm and your cool rims. Two layers
## use it on one full-screen quad: DARK_MUL multiplies the scene down (a true night: an alpha blend only dims an HDR
## floor) to a violet-black, and DARK_MIST adds a faint drifting violet mist in the dark and warm and cool glows at
## the light's edges.
const DARK_COMMON := """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float strength = 0.0;
uniform float clock = 0.0;
uniform float fog_detail = 1.0;
uniform int light_count = 0;
uniform vec4 lights[8];
uniform vec4 night : source_color = vec4(0.16, 0.12, 0.24, 1.0);
uniform vec4 murk : source_color = vec4(0.32, 0.2, 0.5, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.62, 0.25, 1.0);
uniform vec4 cool : source_color = vec4(0.55, 0.5, 0.9, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	vec3 wp = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	vec2 g = wp.xz;
	float n1 = texture(noise_tex, g * 0.06 + vec2(clock * 0.011, clock * 0.006)).r;
	float n2 = texture(noise_tex, g * 0.21 - vec2(clock * 0.019, -clock * 0.013)).r;
	float fog = mix(n1, n1 * 0.55 + n2 * 0.45, fog_detail);
	float lit = 0.0;
	float warm_rim = 0.0;
	float cool_rim = 0.0;
	for (int k = 0; k < light_count; k++) {
		vec4 L = lights[k];
		float r = max(L.z, 0.01);
		float edge = distance(g, L.xy) + (fog - 0.5) * 0.7;
		float inside = 1.0 - smoothstep(r * 0.62, r, edge);
		lit = max(lit, inside);
		float rim = smoothstep(r * 0.55, r * 0.9, edge) * (1.0 - smoothstep(r * 0.9, r * 1.25, edge));
		if (L.w > 0.5) {
			warm_rim = max(warm_rim, rim * L.w);
		} else {
			cool_rim = max(cool_rim, rim);
		}
	}
	vec2 sc = SCREEN_UV - 0.5;
	float vig = smoothstep(0.2, 0.75, length(sc * vec2(1.3, 1.0)));
	float shade = strength * (1.0 - lit);
%s
}
"""
## The night: the scene multiplied down to a few per cent, violet, deepest at the screen's corners, the fog's darker
## swirls lower still; untouched inside the light.
const DARK_MUL := """
	float depth_of_night = 0.035 + 0.05 * fog - 0.02 * vig;
	vec3 down = night.rgb * clamp(depth_of_night, 0.008, 1.0) * 4.0;
	ALBEDO = mix(vec3(1.0), down, shade);
"""
## Over the night: a drifting violet mist in the dark, a faint haze in the light, the lanterns' warm rims and your
## cool one.
const DARK_MIST := """
	vec3 mist = murk.rgb * shade * (0.012 + 0.05 * fog * fog) * (1.0 - 0.6 * vig);
	mist += murk.rgb * strength * lit * 0.025 * fog;
	mist += warm.rgb * strength * warm_rim * 0.16;
	mist += cool.rgb * strength * cool_rim * 0.07;
	ALBEDO = mist;
	ALPHA = 1.0;
"""

## The floor glows over the dark: 0 a lantern's warm pool, 1 the burn ring (filled to `frac`), 2 an out lantern's
## dashed ring, 3 your light's shimmering edge.
const GROUND_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 0.64, 0.28, 1.0);
uniform int mode = 0;
uniform float power = 1.0;
uniform float frac = 1.0;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float turns = atan(q.y, q.x) / 6.2831853 + 0.5;
	float n = texture(noise_tex, UV * 1.6 + vec2(clock * 0.05, -clock * 0.035)).r;
	float glow = 0.0;
	if (mode == 0) {
		float pool = pow(clamp(1.0 - r, 0.0, 1.0), 1.7) * (0.7 + 0.6 * n);
		float edge = smoothstep(0.06, 0.0, abs(r - 0.93 - (n - 0.5) * 0.04)) * 0.3;
		glow = pool * 0.55 + edge;
	} else if (mode == 1) {
		float band = smoothstep(0.07, 0.0, abs(r - 0.86));
		float filled = step(turns, frac);
		glow = band * (filled * (0.9 + 0.3 * n) + (1.0 - filled) * 0.12);
	} else if (mode == 2) {
		float band = smoothstep(0.06, 0.0, abs(r - 0.86));
		float dash = step(0.45, fract(turns * 14.0 + clock * 0.08));
		float ember = smoothstep(0.3, 0.0, r) * (0.25 + 0.2 * n);
		glow = band * dash * 0.8 + ember;
	} else {
		float band = smoothstep(0.035, 0.0, abs(r - 0.97 - (n - 0.5) * 0.03));
		glow = band * (0.45 + 0.4 * n);
	}
	ALBEDO = tint.rgb * glow * 1.6;
	ALPHA = clamp(glow * power, 0.0, 1.0) * smoothstep(1.0, 0.97, r);
}
"""

## A camera-facing quad: 0 a lantern flame (a flickering teardrop), 1 a wisp's outline and glow (COLOR.a the outline,
## COLOR.r the glow).
const SPRITE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 core : source_color = vec4(1.0, 0.92, 0.66, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform int mode = 0;
uniform float power = 1.0;
uniform float clock = 0.0;
varying vec4 tint;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	tint = COLOR;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	q.y = -q.y;
	if (mode == 0) {
		float n = texture(noise_tex, vec2(UV.x * 0.7, UV.y * 0.5 + clock * 0.9)).r;
		float h = clamp((q.y + 1.0) * 0.5, 0.0, 1.0);
		float w = mix(0.55, 0.06, h);
		float x = q.x + (n - 0.5) * 0.3 * h;
		float body = smoothstep(w, w * 0.25, abs(x)) * smoothstep(1.0, 0.3, h + (n - 0.5) * 0.3);
		body *= smoothstep(0.0, 0.12, h);
		vec3 c = mix(edge.rgb, core.rgb, body * body);
		ALBEDO = c * (0.8 + 2.2 * body) * power;
		ALPHA = clamp(body * power, 0.0, 1.0);
	} else {
		float r = length(q);
		float ring = smoothstep(0.09, 0.0, abs(r - 0.78)) * tint.a;
		float halo = smoothstep(1.0, 0.0, r) * smoothstep(1.0, 0.0, r) * tint.r;
		ALBEDO = core.rgb * (ring * 1.4 + halo * 1.2);
		ALPHA = clamp(ring + halo * 0.6, 0.0, 1.0);
	}
}
"""

var dark_quad := MeshInstance3D.new()
## The room's sun and ambient light (WorldViewRoot hands its StageView in), dimmed with the dark so the bodies, the
## walls and their see-through cutaways go dark too and the lanterns' and your lights carry the room.
var stage: StageView
var _dark_mat := ShaderMaterial.new()
var _mist_mat := ShaderMaterial.new()
var _ground_sh := Shader.new()
var _sprite_sh := Shader.new()
var _light := {}
var _strength := 0.0
var _clock := 0.0
## Per lantern: {"root", "glass_mat", "flame_mat", "light", "pool_mat", "ring_mat", "out_mat", "smoke", "sparks",
## "lit", "frac", "flare"}.
var _lamps: Array[Dictionary] = []
var _hero_ring := MeshInstance3D.new()
var _hero_mat := ShaderMaterial.new()
var _hero_light := OmniLight3D.new()
var _hero_at := Vector3.ZERO
var _wisps := MultiMeshInstance3D.new()
var _wisp_pos: Array[Vector3] = []
var _player := Vector2.ZERO
var _used := 0
## The stage's sun and ambient levels before the dark, restored when it lifts.
var _sun_base := -1.0
var _ambient_base := -1.0


func _init() -> void:
	name = "ShadeViews"
	_ground_sh.code = GROUND_SHADER
	_sprite_sh.code = SPRITE_SHADER
	var mul_sh := Shader.new()
	mul_sh.code = DARK_COMMON % ["blend_mul", DARK_MUL]
	_dark_mat.shader = mul_sh
	_dark_mat.render_priority = -20  # first of the see-through things: every marker draws over the dark
	var mist_sh := Shader.new()
	mist_sh.code = DARK_COMMON % ["blend_add", DARK_MIST]
	_mist_mat.shader = mist_sh
	_mist_mat.render_priority = -19
	_dark_mat.next_pass = _mist_mat
	_set_dark("noise_tex", ProjectileMeshes.noise())
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.flip_faces = true
	dark_quad.name = "ShadeDark"
	dark_quad.mesh = quad
	dark_quad.material_override = _dark_mat
	dark_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dark_quad.extra_cull_margin = 16384.0
	dark_quad.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	dark_quad.visible = false
	add_child(dark_quad)
	_hero_mat = _ground_mat(COOL, 3)
	_hero_ring.mesh = _plane(1.0)
	_hero_ring.material_override = _hero_mat
	_hero_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hero_ring.visible = false
	add_child(_hero_ring)
	_hero_light.light_color = Color(0.85, 0.82, 1.0)
	_hero_light.light_energy = 0.0
	_hero_light.omni_range = 6.0
	_hero_light.shadow_enabled = false
	add_child(_hero_light)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = MAX_WISPS
	mm.visible_instance_count = 0
	var wm := _sprite_mat(1)
	wm.set_shader_parameter("core", WISP)
	(mm.mesh as QuadMesh).material = wm
	_wisps.multimesh = mm
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wisps.extra_cull_margin = 4.0
	add_child(_wisps)


## Sets a uniform on both layers of the dark pass.
func _set_dark(param: StringName, value: Variant) -> void:
	_dark_mat.set_shader_parameter(param, value)
	_mist_mat.set_shader_parameter(param, value)


func _plane(size: float) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2.ONE * size
	return p


func _ground_mat(c: Color, mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _ground_sh
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	return m


func _sprite_mat(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _sprite_sh
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	return m


func _iron(rough: float = 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = IRON
	m.metallic = 0.65
	m.roughness = rough
	return m


## One lantern post: a weighted base, an iron post, a hook arm, the caged glass with its flame inside, its warm light,
## its pool, its burn ring and its out ring on the floor, its smoke and its sparks.
func _make_lamp() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var iron := _iron()
	var parts := [
		[_cyl(0.26, 0.3, 0.12, 8), Vector3(0, 0.06, 0)],
		[_cyl(0.05, 0.065, POST_H, 6), Vector3(0, POST_H * 0.5, 0)],
		[_box(Vector3(0.42, 0.05, 0.05)), Vector3(0.18, POST_H - 0.04, 0)],
		[_cyl(0.0, 0.2, 0.16, 6), Vector3(0.36, POST_H - 0.18, 0)],
		[_cyl(0.17, 0.17, 0.04, 6), Vector3(0.36, POST_H - 0.62, 0)],
	]
	for k in 4:
		var a := TAU * (float(k) + 0.5) / 4.0
		parts.append(
			[
				_box(Vector3(0.025, 0.36, 0.025)),
				Vector3(0.36 + cos(a) * 0.15, POST_H - 0.43, sin(a) * 0.15)
			]
		)
	for p: Array in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.position = p[1]
		mi.material_override = iron
		root.add_child(mi)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.32, 0.22, 0.12, 0.75)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.15
	glass_mat.emission_enabled = true
	glass_mat.emission = WARM
	var glass := MeshInstance3D.new()
	glass.mesh = _cyl(0.13, 0.13, 0.32, 6)
	glass.position = Vector3(0.36, POST_H - 0.43, 0)
	glass.material_override = glass_mat
	root.add_child(glass)
	var flame_mat := _sprite_mat(0)
	flame_mat.set_shader_parameter("core", FLAME_CORE)
	flame_mat.set_shader_parameter("edge", WARM)
	var flame := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.2, 0.34)
	flame.mesh = fq
	flame.material_override = flame_mat
	flame.position = Vector3(0.36, POST_H - 0.42, 0)
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = WARM
	light.omni_range = 4.2
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0.36, POST_H - 0.4, 0)
	root.add_child(light)
	var pool_mat := _ground_mat(WARM, 0)
	var pool := MeshInstance3D.new()
	pool.mesh = _plane(2.0)
	pool.material_override = pool_mat
	pool.position = Vector3(0, 0.03, 0)
	root.add_child(pool)
	var ring_mat := _ground_mat(WARM, 1)
	var ring := MeshInstance3D.new()
	ring.mesh = _plane(1.5)
	ring.material_override = ring_mat
	ring.position = Vector3(0, 0.04, 0)
	root.add_child(ring)
	var out_mat := _ground_mat(OUT_RING, 2)
	var out := MeshInstance3D.new()
	out.mesh = _plane(1.7)
	out.material_override = out_mat
	out.position = Vector3(0, 0.045, 0)
	root.add_child(out)
	for mi: MeshInstance3D in [pool, ring, out, flame, glass]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var smoke := _puff(Color(0.24, 0.2, 0.3, 0.55), 18, 1.4, 0.7)
	smoke.position = Vector3(0.36, POST_H - 0.25, 0)
	root.add_child(smoke)
	var sparks := _puff(Color(1.0, 0.7, 0.35, 1.0), 22, 0.6, 2.4)
	sparks.position = Vector3(0.36, POST_H - 0.42, 0)
	root.add_child(sparks)
	return {
		"root": root,
		"glass_mat": glass_mat,
		"flame": flame,
		"flame_mat": flame_mat,
		"light": light,
		"pool": pool,
		"pool_mat": pool_mat,
		"ring": ring,
		"ring_mat": ring_mat,
		"out": out,
		"out_mat": out_mat,
		"smoke": smoke,
		"sparks": sparks,
		"lit": true,
		"frac": 1.0,
		"flare": 0.0,
	}


func _cyl(top: float, bottom: float, h: float, sides: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


## A one-shot burst (the smoke as a lantern goes out, the sparks as it relights).
func _puff(c: Color, n: int, life: float, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, 0.3 if c.r < 0.5 else -2.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2.ONE * (0.28 if c.r < 0.5 else 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if c.r < 0.5 else BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	q.material = m
	p.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return p


func sync(reader: WorldReader) -> void:
	_light = reader.boss_light()
	_player = reader.player_pos()
	_wisp_pos.clear()
	if _light.is_empty():
		return
	for i in reader.projectile_count():
		if StringName(reader.projectile_look(i)) != WISP_LOOK:
			continue
		var p := reader.projectile_pos(i)
		if p.distance_to(_player) <= OUTLINE_M and _wisp_pos.size() < MAX_WISPS:
			_wisp_pos.append(SimPlane.to_3d(p, FireballViews.HEIGHT))
	var lamps: Array = _light["lamps"]
	while _lamps.size() < mini(lamps.size(), MAX_LAMPS):
		_lamps.append(_make_lamp())
	var mid := Vector3.ZERO
	for s: Dictionary in lamps:
		mid += SimPlane.to_3d(s["pos"]) / float(maxi(1, lamps.size()))
	var low := ViewPrefs.effects_density == "low"
	for k in _lamps.size():
		var lamp: Dictionary = _lamps[k]
		var on := k < lamps.size()
		(lamp["root"] as Node3D).visible = on
		if not on:
			continue
		var s: Dictionary = lamps[k]
		var at := SimPlane.to_3d(s["pos"])
		var root: Node3D = lamp["root"]
		# The post stands just behind the lantern's spot, its lantern hung out over it toward the room's middle.
		var inward := mid - at
		inward.y = 0.0
		inward = inward.normalized() if inward.length() > 0.1 else Vector3.RIGHT
		root.rotation.y = atan2(-inward.z, inward.x)
		root.position = at - inward * 0.36
		(lamp["pool"] as MeshInstance3D).position = Vector3(0.36, 0.03, 0)
		(lamp["ring"] as MeshInstance3D).position = Vector3(0.36, 0.04, 0)
		(lamp["out"] as MeshInstance3D).position = Vector3(0.36, 0.045, 0)
		var lit := bool(s["lit"])
		if lit != bool(lamp["lit"]) and bool(_light["dark"]):
			var burst: CPUParticles3D = lamp["sparks"] if lit else lamp["smoke"]
			burst.amount = maxi(4, int(burst.amount / 2) if low else burst.amount)
			burst.restart()
			lamp["flare"] = 1.0 if lit else 0.0
		lamp["lit"] = lit
		lamp["frac"] = float(s["frac"])
	var r: float = _light["lamp_m"]
	for lamp: Dictionary in _lamps:
		(lamp["pool"] as MeshInstance3D).scale = Vector3.ONE * r
	_hero_at = SimPlane.to_3d(_player, 0.06)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var calm := 0.35 if ViewPrefs.reduced_motion else 1.0
	_clock += delta * calm
	var target := 0.0
	if not _light.is_empty():
		if bool(_light["dark"]):
			target = 1.0
		elif int(_light["falling"]) >= 0:
			target = smoothstep(0.15, 1.0, float(_light["falling"]) / 1000.0)
	_strength = move_toward(_strength, target, delta * 1.5)
	dark_quad.visible = _strength > 0.002
	_dim_stage()
	_set_dark("strength", _strength)
	_set_dark("clock", _clock)
	_set_dark("fog_detail", 0.0 if ViewPrefs.effects_density == "low" else 1.0)
	var lights := PackedVector4Array()
	if not _light.is_empty():
		lights.append(Vector4(_hero_at.x, _hero_at.z, float(_light["light_m"]), 0.0))
	lights = _draw_lamps(delta, lights)
	while lights.size() < MAX_LAMPS:
		lights.append(Vector4.ZERO)
	_set_dark("lights", lights)
	_set_dark("light_count", mini(lights_used(), MAX_LAMPS))
	var hero_on := _strength > 0.01
	_hero_ring.visible = hero_on
	_hero_light.light_energy = HERO_ENERGY * _strength
	if hero_on:
		var hr := float(_light.get("light_m", 3.5))
		_hero_ring.position = _hero_at
		_hero_ring.scale = Vector3(hr * 2.0, 1.0, hr * 2.0)
		_hero_mat.set_shader_parameter("power", 0.7 * _strength)
		_hero_mat.set_shader_parameter("clock", _clock)
		_hero_light.position = _hero_at + Vector3(0, 2.6, 0)
	_draw_wisps()


## The stage's sun down to 12 % and its ambient to 20 % at full dark (their levels kept while the room is lit).
func _dim_stage() -> void:
	if stage == null or stage.sun == null or stage.environment == null:
		return
	if _strength <= 0.002:
		_sun_base = stage.sun.light_energy
		_ambient_base = stage.environment.ambient_light_energy
		return
	if _sun_base < 0.0:
		return
	stage.sun.light_energy = _sun_base * (1.0 - 0.88 * _strength)
	stage.environment.ambient_light_energy = _ambient_base * (1.0 - 0.8 * _strength)


## How many light circles the dark pass reads this frame (yours and every lit lantern).
func lights_used() -> int:
	return _used


## Each lantern: its flame, glass and light by how much burn it has left (a flicker in its last second, a flare as it
## relights), its pool over the dark, its burn ring, its out ring; the lit ones join the dark pass's lights.
func _draw_lamps(delta: float, lights: PackedVector4Array) -> PackedVector4Array:
	var r := float(_light.get("lamp_m", 3.0))
	var dark := bool(_light.get("dark", false))
	for k in _lamps.size():
		var lamp: Dictionary = _lamps[k]
		if not (lamp["root"] as Node3D).visible:
			continue
		var lit := bool(lamp["lit"])
		var frac := float(lamp["frac"])
		lamp["flare"] = maxf(0.0, float(lamp["flare"]) - delta * 1.8)
		var flare := float(lamp["flare"])
		var last := frac < 0.17 and dark
		var flick := 0.85 + 0.15 * sin(_clock * 13.0 + k * 1.7) * sin(_clock * 7.3 + k)
		if last:
			flick *= 0.55 + 0.45 * absf(sin(_clock * 21.0 + k))
		var burn := (flick + flare * 1.2) if lit else 0.0
		(lamp["flame"] as MeshInstance3D).visible = lit
		(lamp["flame_mat"] as ShaderMaterial).set_shader_parameter("power", burn)
		(lamp["flame_mat"] as ShaderMaterial).set_shader_parameter("clock", _clock + k)
		var gm: StandardMaterial3D = lamp["glass_mat"]
		gm.emission_energy_multiplier = 2.4 * burn if lit else 0.15
		gm.emission = WARM if lit else Color(0.9, 0.3, 0.1)
		(lamp["light"] as OmniLight3D).light_energy = LAMP_ENERGY * burn
		var pool_on := lit and dark
		(lamp["pool"] as MeshInstance3D).visible = pool_on
		(lamp["pool_mat"] as ShaderMaterial).set_shader_parameter("power", 0.75 * burn)
		(lamp["pool_mat"] as ShaderMaterial).set_shader_parameter("clock", _clock + k * 3.0)
		(lamp["ring"] as MeshInstance3D).visible = pool_on
		(lamp["ring_mat"] as ShaderMaterial).set_shader_parameter("frac", frac)
		(lamp["ring_mat"] as ShaderMaterial).set_shader_parameter(
			"power", 0.9 if not last else flick
		)
		(lamp["out"] as MeshInstance3D).visible = dark and not lit
		(lamp["out_mat"] as ShaderMaterial).set_shader_parameter(
			"power", 0.55 + 0.25 * sin(_clock * 3.0)
		)
		(lamp["out_mat"] as ShaderMaterial).set_shader_parameter("clock", _clock)
		if lit and dark:
			var root: Node3D = lamp["root"]
			var at := root.position + root.basis * Vector3(0.36, 0, 0)
			lights.append(Vector4(at.x, at.z, r, clampf(burn, 0.6, 1.0)))
	_used = lights.size()
	return lights


## The wisps near you: an outline ring (over the dark, never thinned) and a glow brightening as they near you.
func _draw_wisps() -> void:
	var mm := _wisps.multimesh
	var n := 0
	var me := SimPlane.to_3d(_player, FireballViews.HEIGHT)
	for p in _wisp_pos:
		var d := p.distance_to(me)
		var near := clampf(1.0 - (d - 1.0) / (OUTLINE_M - 1.0), 0.0, 1.0)
		var outline := 0.55 + 0.45 * near
		var glow := near * near * (0.6 + 0.4 * sin(_clock * 9.0 + p.x))
		mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * 0.75), p))
		mm.set_instance_color(n, Color(glow, 0.0, 0.0, outline))
		n += 1
	mm.visible_instance_count = n


## For tests: the dark's strength (0..1), the wisps outlined, the lanterns shown and lit.
func dark_strength() -> float:
	return _strength


func outlined_wisps() -> int:
	return _wisps.multimesh.visible_instance_count


func lamps_shown() -> int:
	var n := 0
	for lamp: Dictionary in _lamps:
		n += 1 if (lamp["root"] as Node3D).visible else 0
	return n


func lamps_lit() -> int:
	var n := 0
	for lamp: Dictionary in _lamps:
		n += 1 if (lamp["root"] as Node3D).visible and bool(lamp["lit"]) else 0
	return n


func dark_priority() -> int:
	return _dark_mat.render_priority
