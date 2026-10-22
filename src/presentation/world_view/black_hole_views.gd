class_name BlackHoleViews
extends Node3D
## v0.8.0 P2 (owner O24, Void: "a small black hole lasting 2 seconds, attracting nearby enemies and dealing damage"):
## each black hole the sim keeps (WorldReader.black_holes) drawn as a small dark swirling hole on the floor:
## - a disc out to the pull's reach whose violet arms spiral inward (an additive shader, fading at its edge), over
## - a dark core the size of the damage radius with a thin violet rim, and a small black sphere hovering at its
##   centre;
## it opens over OPEN_SECONDS and closes over the last CLOSE_TICKS of its life. Pooled (POOL nodes made once and
## reused; a hole past them isn't drawn). Reduced motion: the arms turn at a quarter speed. Presentation only (EI-07):
## the sim's state decides where, how big and how long; the swirl's clock is the shader's.

const POOL := 6
const VIOLET := Color("#8B55FF")
const VIOLET_PALE := Color("#C6A8FF")
## The view's own open and close (presentation only).
const OPEN_TICKS := 10
const CLOSE_TICKS := 15
const CORE_Y := 0.6
const SWIRL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 arm_color : source_color = vec4(0.55, 0.33, 1.0, 1.0);
uniform float strength = 1.0;
uniform float speed = 1.0;
uniform float core = 0.4;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// Arms spiralling inward: the phase winds with log(r) and turns with time.
	float arms = 0.5 + 0.5 * sin(3.0 * a + 7.0 * log(max(r, 0.02)) + TIME * 4.0 * speed);
	float band = smoothstep(0.55, 1.0, arms);
	float edge = 1.0 - smoothstep(0.75, 1.0, r);
	float inner = smoothstep(core * 0.85, core * 1.25, r);
	float rim = exp(-pow((r - core) * 18.0, 2.0));
	float glow = (0.15 + 0.85 * band) * edge * inner * (1.0 - r * 0.6);
	ALBEDO = arm_color.rgb * strength * (glow * 0.9 + rim * 1.6);
}
"""
const CORE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float alpha = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	ALBEDO = vec3(0.01, 0.0, 0.02);
	ALPHA = (1.0 - smoothstep(0.82, 1.0, r)) * alpha;
}
"""

var calm := false
## The holes drawn after the last sync (tests read it).
var drawn := 0
var _swirls: Array[MeshInstance3D] = []
var _cores: Array[MeshInstance3D] = []
var _spheres: Array[MeshInstance3D] = []
var _swirl_shader := Shader.new()
var _core_shader := Shader.new()


func _init() -> void:
	name = "BlackHoles"
	_swirl_shader.code = SWIRL_SHADER
	_core_shader.code = CORE_SHADER
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.albedo_color = Color(0.02, 0.0, 0.04)
	sphere_mat.roughness = 0.2
	sphere_mat.metallic = 0.6
	sphere_mat.rim_enabled = true
	sphere_mat.rim = 1.0
	sphere_mat.rim_tint = 0.0
	for k in POOL:
		var swirl := MeshInstance3D.new()
		swirl.name = "Swirl%d" % k
		var q := PlaneMesh.new()
		q.size = Vector2(2.0, 2.0)
		swirl.mesh = q
		var m := ShaderMaterial.new()
		m.shader = _swirl_shader
		m.set_shader_parameter("arm_color", VIOLET)
		swirl.material_override = m
		swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		swirl.position.y = 0.04
		swirl.visible = false
		add_child(swirl)
		_swirls.append(swirl)
		var core := MeshInstance3D.new()
		core.name = "Core%d" % k
		var cq := PlaneMesh.new()
		cq.size = Vector2(2.0, 2.0)
		core.mesh = cq
		var cm := ShaderMaterial.new()
		cm.shader = _core_shader
		core.material_override = cm
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core.position.y = 0.03
		core.visible = false
		add_child(core)
		_cores.append(core)
		var ball := MeshInstance3D.new()
		ball.name = "Sphere%d" % k
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 16
		sm.rings = 8
		ball.mesh = sm
		ball.material_override = sphere_mat
		ball.visible = false
		add_child(ball)
		_spheres.append(ball)


func sync(reader: WorldReader) -> void:
	calm = ViewPrefs.reduced_motion
	var holes := reader.black_holes()
	drawn = mini(holes.size(), POOL)
	for k in POOL:
		var on := k < drawn
		_swirls[k].visible = on
		_cores[k].visible = on
		_spheres[k].visible = on
		if not on:
			continue
		var h: Dictionary = holes[k]
		var age := int(h["age"])
		var life := int(h["life"])
		var size := (
			clampf(float(age) / OPEN_TICKS, 0.0, 1.0)
			* clampf(float(life - age) / CLOSE_TICKS, 0.0, 1.0)
		)
		size = smoothstep(0.0, 1.0, size)
		var at := SimPlane.to_3d(h["pos"])
		var reach := float(h["pull_radius"]) * 0.75
		var core_r := float(h["radius"]) * 0.55
		_swirls[k].position = Vector3(at.x, 0.04, at.z)
		_swirls[k].scale = Vector3.ONE * maxf(0.001, reach * size)
		var m := _swirls[k].material_override as ShaderMaterial
		m.set_shader_parameter("speed", 0.25 if calm else 1.0)
		m.set_shader_parameter("core", core_r / maxf(0.01, reach))
		m.set_shader_parameter("strength", 0.6 + 0.6 * size)
		_cores[k].position = Vector3(at.x, 0.03, at.z)
		_cores[k].scale = Vector3.ONE * maxf(0.001, core_r * size)
		(_cores[k].material_override as ShaderMaterial).set_shader_parameter("alpha", size)
		_spheres[k].position = Vector3(at.x, CORE_Y * size, at.z)
		_spheres[k].scale = Vector3.ONE * maxf(0.001, 0.45 * size)
