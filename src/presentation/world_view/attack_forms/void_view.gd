class_name VoidView
extends Node3D
## v0.9.0 VP (owner C §6.4: "The visual should communicate a moving gravitational anomaly, not a stationary vortex";
## PLAN C56): the Void form. Each Void shot in flight (WorldReader.void_shots) is a travelling lensing sphere:
## - a dark core (an unlit black sphere at the shot's height);
## - a camera-facing lens around it that bends the picture behind (the screen texture pulled toward the core, strongest
##   at the rim), with a bright violet bent-light ring at its edge; with the owner's `void_lens` PNG
##   (assets/textures/vfx/, white on transparent) installed the ring is that picture, tinted;
## - swirling dust: a camera-facing disc of violet arms winding in and turning, and a short trail of fading dust puffs
##   behind it along its flight (so it reads as moving), plus a faint flat ring on the ground at its aura's reach.
## The enemies it pulls lean into it (ActorViews._lean, from WorldReader.void_leans). Pooled (VOIDS_MAX shots drawn,
## the rest skipped). Presentation only (EI-07): the sim decides where, how big and which way; the swirl's clock is the
## shader's.

const VOIDS_MAX := 16
const TRAIL := 3
## The trail's puffs this far apart behind the shot (m).
const TRAIL_GAP_M := 0.38
const HEIGHT := SimPlane.CORE_HEIGHT
const CORE_SIZE := 0.42
const LENS_SIZE := 1.5
const VIOLET := Color("#8B55FF")
const RIM := Color("#D9C2FF")

const LENS_SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D lens_tex : source_color, filter_linear;
uniform float has_tex = 0.0;
uniform vec4 rim : source_color = vec4(0.85, 0.76, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(0.55, 0.33, 1.0, 1.0);
uniform float core = 0.3;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	if (r > 1.0) {
		discard;
	}
	vec2 n = d / max(r, 0.001);
	float bend = core * core / max(r * r, core * core) * 0.035 * (1.0 - smoothstep(0.6, 1.0, r));
	vec3 bg = textureLod(screen_tex, SCREEN_UV + vec2(n.x, -n.y) * bend, 0.0).rgb;
	float ring = exp(-pow((r - core * 1.35) * 12.0, 2.0));
	float halo = exp(-pow((r - core * 1.35) * 4.0, 2.0)) * 0.35;
	if (has_tex > 0.5) {
		vec4 t = texture(lens_tex, UV);
		ring = t.a * dot(t.rgb, vec3(0.333));
	}
	float dark = 1.0 - smoothstep(core * 0.95, core * 1.12, r);
	vec3 col = mix(bg * (0.75 + 0.25 * r), vec3(0.0), dark) + rim.rgb * ring * 1.9 + glow.rgb * halo;
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.82, 1.0, r);
}
"""
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 arm_color : source_color = vec4(0.55, 0.33, 1.0, 1.0);
uniform float strength = 1.0;
uniform float turn = 0.0;
uniform float billboard = 1.0;
void vertex() {
	if (billboard > 0.5) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
			INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float arms = 0.5 + 0.5 * sin(3.0 * a + 6.0 * log(max(r, 0.03)) + TIME * 5.0 + turn);
	float grains = 0.5 + 0.5 * sin(a * 23.0 - TIME * 7.0 + r * 31.0 + turn * 3.0);
	float band = smoothstep(0.45, 1.0, arms) * (0.6 + 0.4 * grains);
	float fade = (1.0 - smoothstep(0.55, 1.0, r)) * smoothstep(0.12, 0.3, r);
	ALBEDO = arm_color.rgb * strength * band * fade * 1.4;
}
"""

static var _shaders := {}

## What the last sync drew (tests read them): the shots and the dust puffs behind them.
var voids := 0
var puffs := 0

var _cores: Array[MeshInstance3D] = []
var _lenses: Array[MeshInstance3D] = []
var _dust: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _trail: Array[MeshInstance3D] = []
var _trail_mat: Array[ShaderMaterial] = []


func _init() -> void:
	name = "VoidView"
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.0, 0.0, 0.01)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var flat := PlaneMesh.new()
	flat.size = Vector2(2.0, 2.0)
	var tex := FxTextures.get_tex("void_lens")
	var lens_mat := ShaderMaterial.new()
	lens_mat.shader = _shader(LENS_SHADER)
	lens_mat.set_shader_parameter(&"has_tex", 1.0 if tex != null else 0.0)
	if tex != null:
		lens_mat.set_shader_parameter(&"lens_tex", tex)
	lens_mat.set_shader_parameter(&"rim", RIM)
	lens_mat.set_shader_parameter(&"glow", VIOLET)
	lens_mat.render_priority = 1
	var ring_mat := _dust_mat(0.45, false)
	for k in VOIDS_MAX:
		_cores.append(_node(ball, black))
		_lenses.append(_node(quad, lens_mat))
		_dust.append(_node(quad, _dust_mat(1.0, true)))
		_rings.append(_node(flat, ring_mat))
		for t in TRAIL:
			var m := _dust_mat(1.0, true)
			_trail.append(_node(quad, m))
			_trail_mat.append(m)


func _node(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


func _dust_mat(strength: float, billboard: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(DUST_SHADER)
	m.set_shader_parameter(&"arm_color", VIOLET)
	m.set_shader_parameter(&"strength", strength)
	m.set_shader_parameter(&"billboard", 1.0 if billboard else 0.0)
	return m


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## Each tick: every Void shot in flight, drawn where the sim has it.
func sync(reader: WorldReader) -> void:
	var shots := reader.void_shots()
	voids = 0
	puffs = 0
	for v: Dictionary in shots:
		if voids >= VOIDS_MAX:
			break
		var p: Vector2 = v["pos"]
		var dir: Vector2 = v["dir"]
		var aura: float = v["aura"]
		var at := SimPlane.to_3d(p, HEIGHT)
		var core := _cores[voids]
		core.visible = true
		core.transform = Transform3D(Basis.from_scale(Vector3.ONE * CORE_SIZE), at)
		var lens := _lenses[voids]
		lens.visible = true
		lens.transform = Transform3D(Basis.from_scale(Vector3.ONE * LENS_SIZE), at)
		var dust := _dust[voids]
		dust.visible = true
		dust.transform = Transform3D(Basis.from_scale(Vector3.ONE * LENS_SIZE * 1.35), at)
		var spin := float(int(v["id"]) % 97)
		(dust.material_override as ShaderMaterial).set_shader_parameter(&"turn", spin)
		var ring := _rings[voids]
		ring.visible = true
		ring.transform = Transform3D(
			Basis.from_scale(Vector3(aura, 1.0, aura)), SimPlane.to_3d(p, 0.06)
		)
		for t in TRAIL:
			var puff := _trail[voids * TRAIL + t]
			var back := p - dir * TRAIL_GAP_M * (t + 1)
			var s := LENS_SIZE * (0.9 - 0.2 * t)
			puff.visible = true
			puff.transform = Transform3D(
				Basis.from_scale(Vector3.ONE * s), SimPlane.to_3d(back, HEIGHT - 0.05 * t)
			)
			var m := _trail_mat[voids * TRAIL + t]
			m.set_shader_parameter(&"strength", 0.55 / (t + 1))
			m.set_shader_parameter(&"turn", spin + t * 1.7)
			puffs += 1
		voids += 1
	for k in range(voids, VOIDS_MAX):
		_cores[k].visible = false
		_lenses[k].visible = false
		_dust[k].visible = false
		_rings[k].visible = false
		for t in TRAIL:
			_trail[k * TRAIL + t].visible = false
