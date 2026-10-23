class_name TideViews
extends Node3D
## v0.9.0 NB1 (BOSSES_4_5.md N1; the VX quality bar: layered, never a flat single-colour shape): the Tidecaller's Pull,
## drawn from WorldReader.boss_tide (EI-07: it reads; the drift itself is the sim's, BossTide).
## - The bell's toll (its windup): sound rings rising off the bell and spreading over the floor, brighter each toll.
## - The current: a wide disc of moving water round the boss (TIDE_SHADER): a deep teal body, spiral streaks of
##   seafoam flowing in toward it while the room pulls and out while it pushes, caustic light, foam flecks breaking
##   at the streaks' crests, the edge fading; its speed and brightness follow the tide's.
## - Bubbles and spray: droplets riding the current (in or out) over the disc, MultiMesh, thinned on Low density.
## - The push's swell: a ring wave rolling out from the boss at the push's start.
## - A sea-green light on the boss while the tide runs.
## Reduced motion slows the flow and stills the bubbles' bob. Nothing here decides an outcome.

const RADIUS := 14.0
const BUBBLES := 72
const SEA := Color(0.45, 1.0, 0.76)
const DEEP := Color(0.03, 0.16, 0.16)
const TOLL_RINGS := 3
const TIDE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 sea : source_color = vec4(0.45, 1.0, 0.76, 1.0);
uniform vec4 deep : source_color = vec4(0.03, 0.16, 0.16, 1.0);
uniform float flow = 1.0;   // + in (the pull), - out (the push)
uniform float strength = 0.0;
uniform float clock = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float t = clock;
	float n = texture(noise_tex, UV * 3.0 + vec2(t * 0.03, -t * 0.02)).r;
	// Spiral streaks: lines of constant (angle - twist × radius), sliding along the radius with the flow.
	float s = sin(a * 7.0 + r * 9.0 + flow * t * 3.2 + n * 2.5);
	float streak = smoothstep(0.55, 0.95, s);
	float fine = smoothstep(0.7, 1.0, sin(a * 15.0 - r * 18.0 + flow * t * 4.5 + n * 4.0));
	// Caustics: two noise taps crossing.
	float c1 = texture(noise_tex, UV * 6.0 + vec2(t * 0.05, t * 0.04)).r;
	float c2 = texture(noise_tex, UV * 6.0 - vec2(t * 0.04, t * 0.06)).r;
	float caustic = smoothstep(0.08, 0.0, abs(c1 - c2)) * 0.7;
	float foam = smoothstep(0.78, 0.92, n) * streak;
	float edge = smoothstep(1.0, 0.55, r) * smoothstep(0.06, 0.16, r);
	float lit = max(streak * 0.8, max(fine * 0.45, max(caustic, foam * 1.2)));
	ALBEDO = mix(deep.rgb, sea.rgb * (1.2 + foam), lit);
	ALPHA = clamp(edge * strength * (0.22 + 0.6 * lit), 0.0, 0.9);
}
"""

var _disc := MeshInstance3D.new()
var _disc_mat := ShaderMaterial.new()
var _bubbles := MultiMeshInstance3D.new()
var _bubble_mat := StandardMaterial3D.new()
var _rings: Array[MeshInstance3D] = []
var _ring_mat := StandardMaterial3D.new()
var _swell := MeshInstance3D.new()
var _swell_mat := StandardMaterial3D.new()
var _light := OmniLight3D.new()
var _tide := {}
var _centre := Vector3.ZERO
var _strength := 0.0
var _flow := 1.0
var _clock := 0.0
var _toll := 0.0
var _swell_t := 1.0
var _last_phase := WorldReader.TIDE_NONE


func _init() -> void:
	name = "TideViews"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * RADIUS * 2.0
	_disc.mesh = plane
	var sh := Shader.new()
	sh.code = TIDE_SHADER
	_disc_mat.shader = sh
	_disc_mat.set_shader_parameter("sea", SEA)
	_disc_mat.set_shader_parameter("deep", DEEP)
	_disc_mat.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	_disc.material_override = _disc_mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.visible = false
	add_child(_disc)
	var drop := SphereMesh.new()
	drop.radius = 0.07
	drop.height = 0.14
	drop.radial_segments = 8
	drop.rings = 4
	_bubble_mat.albedo_color = Color(SEA, 0.65)
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.emission_enabled = true
	_bubble_mat.emission = SEA
	_bubble_mat.emission_energy_multiplier = 1.4
	_bubble_mat.rim_enabled = true
	_bubble_mat.rim = 1.0
	drop.material = _bubble_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = drop
	mm.instance_count = BUBBLES
	mm.visible_instance_count = 0
	_bubbles.multimesh = mm
	_bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bubbles)
	for m: StandardMaterial3D in [_ring_mat, _swell_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(SEA, 0.0)
	for k in TOLL_RINGS:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.92
		torus.outer_radius = 1.0
		torus.rings = 48
		ring.mesh = torus
		ring.material_override = _ring_mat.duplicate()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		_rings.append(ring)
	var wave := TorusMesh.new()
	wave.inner_radius = 0.85
	wave.outer_radius = 1.0
	wave.rings = 64
	_swell.mesh = wave
	_swell.material_override = _swell_mat
	_swell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swell.visible = false
	add_child(_swell)
	_light.light_color = SEA
	_light.light_energy = 0.0
	_light.omni_range = 7.0
	_light.shadow_enabled = false
	add_child(_light)


func sync(reader: WorldReader) -> void:
	var boss := reader.boss_index()
	_tide = reader.boss_tide(boss) if boss >= 0 else {}
	if _tide.is_empty():
		_last_phase = WorldReader.TIDE_NONE
		return
	_centre = SimPlane.to_3d(_tide["centre"])
	var phase := int(_tide["phase"])
	if phase == WorldReader.TIDE_PUSH and _last_phase != WorldReader.TIDE_PUSH:
		_swell_t = 0.0
	_last_phase = phase


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var phase := int(_tide.get("phase", WorldReader.TIDE_NONE))
	var tolling := bool(_tide.get("windup", false))
	var running := phase != WorldReader.TIDE_NONE
	var speed := float(_tide.get("speed", 0.0))
	var target := clampf(speed / WorldReader.TIDE_MAX_MPS, 0.0, 1.0) if running else 0.0
	_strength = move_toward(_strength, target, delta * 2.5)
	_flow = move_toward(_flow, -1.0 if phase == WorldReader.TIDE_PUSH else 1.0, delta * 4.0)
	_clock += delta * (0.4 if ViewPrefs.reduced_motion else 1.0) * (0.5 + _strength)
	_toll = move_toward(_toll, 1.0 if tolling else 0.0, delta * 3.0)
	_swell_t = minf(1.0, _swell_t + delta / 1.2)
	var shown := _strength > 0.01
	_disc.visible = shown
	_disc.position = _centre + Vector3(0, 0.03, 0)
	_disc_mat.set_shader_parameter("flow", _flow)
	_disc_mat.set_shader_parameter("strength", _strength)
	_disc_mat.set_shader_parameter("clock", _clock)
	_light.position = _centre + Vector3(0, 1.4, 0)
	_light.light_energy = 2.4 * maxf(_strength, _toll * 0.8)
	_draw_bubbles(shown)
	_draw_toll(float(_tide.get("progress", 0)) / 1000.0 if tolling else 0.0)
	_swell.visible = _swell_t < 1.0
	if _swell.visible:
		var r := lerpf(1.5, RADIUS * 0.8, ease(_swell_t, 0.6))
		_swell.position = _centre + Vector3(0, 0.12 + 0.25 * sin(_swell_t * PI), 0)
		_swell.scale = Vector3(r, 0.5, r)
		_swell_mat.albedo_color = Color(SEA, 0.55 * (1.0 - _swell_t))


## Droplets riding the current: each on its own spoke and radius, sliding in (pull) or out (push), bobbing.
func _draw_bubbles(shown: bool) -> void:
	var mm := _bubbles.multimesh
	var n := BUBBLES / 2 if ViewPrefs.effects_density == "low" else BUBBLES
	mm.visible_instance_count = n if shown else 0
	if not shown:
		return
	for k in n:
		var spoke := TAU * fposmod(k * 0.618034, 1.0)
		var f := fposmod(k * 0.3819 - _clock * 0.22 * _flow, 1.0)
		var r := lerpf(1.8, RADIUS * 0.85, f)
		var twist := spoke + r * 0.35 * _flow
		var bob := 0.0 if ViewPrefs.reduced_motion else sin(_clock * 6.0 + k) * 0.08
		var at := (
			_centre
			+ Vector3(cos(twist) * r, 0.15 + bob + 0.2 * fposmod(k * 0.77, 1.0), sin(twist) * r)
		)
		var s := (0.6 + 0.8 * fposmod(k * 0.53, 1.0)) * _strength * (1.0 - 0.6 * f)
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * maxf(s, 0.01)), at))


## The bell's toll: TOLL_RINGS rings rising off the bell and spreading, one after another through the windup.
func _draw_toll(progress: float) -> void:
	for k in _rings.size():
		var ring := _rings[k]
		var local := fposmod(progress * 2.2 - k / float(TOLL_RINGS), 1.0)
		ring.visible = _toll > 0.01
		var r := lerpf(0.6, 6.0, local)
		ring.position = _centre + Vector3(0, lerpf(3.4, 0.2, local), 0)
		ring.scale = Vector3(r, 1.0, r)
		(ring.material_override as StandardMaterial3D).albedo_color = Color(
			SEA, 0.5 * _toll * (1.0 - local)
		)


## Tests: how strongly the current shows (0..1), which way it flows (+1 in, -1 out) and how many bubbles are drawn.
func strength() -> float:
	return _strength


func flow() -> float:
	return _flow


func bubbles_drawn() -> int:
	return _bubbles.multimesh.visible_instance_count
