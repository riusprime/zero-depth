class_name BlinkFlash
extends Node3D
## One end of a blink (PLAN v0.2.0 L12, owner: "a blue light at the beginning and end points of the teleport"): a
## short column of blue light (fading upward from the foot, lighter where it faces the camera), a pool of light on
## the ground, a burst of small blue sparks and a blue OmniLight3D, all fading over DURATION_S. Presentation only
## (EI-07): UtilityView starts it when the sim reports a blink; it decides nothing.

const DURATION_S := 0.36
const COLUMN_H := 2.4
const COLUMN_R := 0.42
const SPARKS := 18
const BLUE := Color("#2F6BFF")
const BLUE_CORE := Color("#A8D4FF")
const LIGHT_ENERGY := 5.0

const COLUMN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 col : source_color = vec4(0.18, 0.42, 1.0, 1.0);
uniform vec4 core : source_color = vec4(0.66, 0.83, 1.0, 1.0);
uniform float height = 2.4;
uniform float fade = 1.0;
varying float hy;

void vertex() {
	hy = VERTEX.y / height + 0.5;
}

void fragment() {
	float up = clamp(hy, 0.0, 1.0);
	float body = pow(1.0 - up, 1.4);
	float facing = abs(dot(NORMAL, VIEW));
	// Blue at the edges, a lighter core where the column faces the camera; over 1.0 so the glow picks it up.
	vec3 c = mix(col.rgb, core.rgb, pow(facing, 4.0) * 0.7);
	ALBEDO = c * 1.6;
	ALPHA = clamp(body * fade * (0.35 + 0.75 * facing), 0.0, 1.0);
}
"""

const POOL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 col : source_color = vec4(0.18, 0.42, 1.0, 1.0);
uniform float fade = 1.0;

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float a = pow(1.0 - smoothstep(0.0, 1.0, r), 1.8);
	ALBEDO = col.rgb * 1.3;
	ALPHA = clamp(a * fade * 0.7, 0.0, 1.0);
}
"""

var column := MeshInstance3D.new()
var pool := MeshInstance3D.new()
var light := OmniLight3D.new()
var sparks: Array[MeshInstance3D] = []
var _column_mat := ShaderMaterial.new()
var _pool_mat := ShaderMaterial.new()
var _spark_mat := StandardMaterial3D.new()
var _dirs: Array[Vector3] = []
var _t := DURATION_S


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var cyl := CylinderMesh.new()
	cyl.top_radius = COLUMN_R * 0.7
	cyl.bottom_radius = COLUMN_R
	cyl.height = COLUMN_H
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 16
	column.mesh = cyl
	_column_mat.shader = Shader.new()
	_column_mat.shader.code = COLUMN_SHADER
	_column_mat.set_shader_parameter("col", BLUE)
	_column_mat.set_shader_parameter("core", BLUE_CORE)
	_column_mat.set_shader_parameter("height", COLUMN_H)
	column.material_override = _column_mat
	column.position.y = COLUMN_H * 0.5
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.6, 2.6)
	pool.mesh = plane
	_pool_mat.shader = Shader.new()
	_pool_mat.shader.code = POOL_SHADER
	_pool_mat.set_shader_parameter("col", BLUE)
	pool.material_override = _pool_mat
	pool.position.y = 0.03
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.albedo_color = Color(0.55, 0.78, 1.6)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.11, 0.11, 0.11)
	# A fixed fan of directions (golden angle round, rising), so every blink bursts the same way.
	for k in SPARKS:
		var a := k * 2.39996
		var rise := 0.35 + 0.5 * float(k % 4) / 3.0
		_dirs.append(Vector3(cos(a), rise, sin(a)).normalized() * (2.6 + 0.5 * (k % 3)))
		var s := MeshInstance3D.new()
		s.mesh = spark_mesh
		s.material_override = _spark_mat
		sparks.append(s)
	for n: GeometryInstance3D in [column, pool] + sparks:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
	light.light_color = BLUE
	light.omni_range = 4.5
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.position.y = 1.0
	add_child(light)
	visible = false


## Starts the flash at the 3D ground point `at`.
func play(at: Vector3) -> void:
	position = at
	_t = 0.0
	visible = true
	_apply()


func is_playing() -> bool:
	return _t < DURATION_S


## 0 at the start, 1 when done.
func progress() -> float:
	return clampf(_t / DURATION_S, 0.0, 1.0)


func _process(delta: float) -> void:
	if not is_playing():
		return
	# Clamped so a long frame (a hitch, a slow renderer) can't skip the whole flash.
	_t += minf(delta, 1.0 / 30.0)
	_apply()
	if not is_playing():
		visible = false


func _apply() -> void:
	var p := progress()
	var fade := 1.0 - p
	var pop := minf(1.0, p / 0.15)
	_column_mat.set_shader_parameter("fade", fade * 1.3)
	column.scale = Vector3(0.4 + 0.6 * pop - 0.3 * p, 1.0, 0.4 + 0.6 * pop - 0.3 * p)
	_pool_mat.set_shader_parameter("fade", fade)
	light.light_energy = LIGHT_ENERGY * fade * fade
	_spark_mat.albedo_color.a = fade
	var t := p * DURATION_S
	for k in SPARKS:
		var d := _dirs[k]
		sparks[k].position = Vector3(d.x * t, 0.3 + d.y * t - 4.0 * t * t, d.z * t)
