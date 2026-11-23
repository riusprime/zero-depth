class_name MaelstromViews
extends Node3D
## The Tidecaller's Maelstrom, drawn from WorldReader.boss_dance()["maelstrom"] (EI-07: it reads; the carry, the eye's
## hit and the throw are the sim's, BossMaelstrom).
## - The whirlpool: a wide floor disc centred on `centre` (the Tidecaller), four spiral arms of seafoam laid along
##   the way the floor carries the hero (round `spin` and slowly in, the sim's own ratio of `around` to `inward`),
##   turning that way and brighter and tighter toward the eye; each arm carries dashes whose bright heads point the
##   way the water goes, so a still frame reads too. The edge fades into the floor.
## - The eye: a dark core of the eye's exact radius (`eye`, from the boss's centre) with a bright rim and the pack's
##   ripple (tc_eye) in deep blue; the rim dims while the eye's `grace` holds it off.
## - The throw (`maelstrom_throw`): the pack's splash (tc_splash) where the hero stood and a streak of spray running out
##   from the Tidecaller past it, fading in half a second.
## Reduced motion: the arms hold still (their dashes still point the way) and rings mark the pull inward. The floor
## layers draw under every telegraph and never hide the hero. Nothing here decides an outcome.

const SEA := Color(0.42, 0.86, 1.0)
const DEEP := Color(0.02, 0.07, 0.2)
const FOAM := Color(0.88, 0.98, 1.0)
const EYE_ID := &"tc_eye"
const SPLASH_ID := &"tc_splash"
const EFFECT_THROW := &"maelstrom_throw"
## The whirlpool's radius (m): past any boss room's corner from a boss in it.
const RADIUS_M := 18.0
## The eye's quad reaches past its radius by this share (the rim's glow).
const EYE_PAD := 1.25
const EYE_PER_M := 0.52
const SPLASH_PER_M := 0.45
## The throw's streak: its length (m), width (m) and life (s).
const STREAK_M := 7.0
const STREAK_W := 1.1
const STREAK_S := 0.5
const UNDER := -2
const SPIRAL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 sea : source_color = vec4(0.42, 0.86, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.07, 0.2, 1.0);
uniform vec4 foam : source_color = vec4(0.88, 0.98, 1.0, 1.0);
uniform float spin = 1.0;     // the sim's turn: +1 counter-clockwise on the sim plane
uniform float pitch = 0.55;   // inward over around: how tightly the arms wind
uniform float eye = 0.15;     // the eye's radius over the disc's
uniform float clock = 0.0;
uniform float still = 0.0;
uniform float alpha = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = max(length(q), 0.001);
	// The plane's UV angle runs the other way from the sim's (its z is the sim's -y)
	float a = atan(q.y, q.x);
	float lr = log(r);
	float n = texture(noise_tex, UV * 2.5 + vec2(clock * 0.02, -clock * 0.015)).r;
	// Arms along the flow lines (log spirals of the sim's pitch), turned the way the floor carries the hero
	float arm = 4.0 * a - (4.0 / pitch) * spin * lr + spin * clock * 0.9 + n * 0.8;
	float band = 0.5 + 0.5 * cos(arm);
	float on_arm = smoothstep(0.6, 0.95, band);
	// Dashes along each arm, bright at their heads (the way the water goes: in), drifting with it
	float dash = fract(-lr * 3.2 + clock * 0.6);
	float head = pow(dash, 3.0) * smoothstep(1.0, 0.93, dash);
	float rings = still * smoothstep(0.06, 0.0, abs(fract(lr * 1.6) - 0.5)) * 0.5;
	float inner = 1.0 - smoothstep(0.0, 1.0, r);
	float edge = smoothstep(1.0, 0.82, r) * smoothstep(eye * 0.95, eye * 1.2, r);
	float lit = on_arm * (0.35 + 0.65 * head) * (0.55 + 0.45 * inner) + rings;
	vec3 col = mix(sea.rgb, foam.rgb, head * on_arm);
	ALBEDO = mix(deep.rgb, col, clamp(lit * 1.4, 0.0, 1.0)) * (1.0 + 0.5 * lit);
	ALPHA = clamp(alpha * edge * (0.08 + 0.1 * inner + 0.5 * lit), 0.0, 0.55);
}
"""
const EYE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 sea : source_color = vec4(0.42, 0.86, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.07, 0.2, 1.0);
uniform vec4 foam : source_color = vec4(0.88, 0.98, 1.0, 1.0);
uniform float core = 0.8;     // the eye's edge over the quad's radius
uniform float danger = 1.0;   // 1 armed, lower while its grace holds
uniform float spin = 1.0;
uniform float clock = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float n = texture(noise_tex, vec2(a / 6.2831853 * 3.0 + spin * clock * 0.3, r * 1.5 - clock * 0.4)).r;
	float inside = smoothstep(core + 0.02, core - 0.02, r);
	float rim = smoothstep(0.07, 0.0, abs(r - core));
	float turn = fract((a + spin * clock * 1.4) * 12.0 / 6.2831853);
	float ticks = step(0.75, turn) * smoothstep(0.1, 0.0, abs(r - core - 0.08));
	float swirl = smoothstep(0.45, 0.85, n) * inside * (1.0 - r / core);
	vec3 col = mix(deep.rgb, sea.rgb, swirl * 0.6);
	float lit = (rim + ticks * 0.8) * danger;
	ALBEDO = mix(col, mix(sea.rgb, foam.rgb, 0.6), clamp(lit, 0.0, 1.0)) * (1.0 + 1.6 * lit);
	ALPHA = clamp(inside * 0.78 + lit * 0.9, 0.0, 0.92) * step(r, 1.0);
}
"""
const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 foam : source_color = vec4(0.88, 0.98, 1.0, 1.0);
uniform float alpha = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	float u = UV.x;  // from the Tidecaller outward
	float v = abs(UV.y * 2.0 - 1.0);
	float n = texture(noise_tex, vec2(u * 3.0, UV.y * 1.5)).r;
	float body = smoothstep(1.0, 0.2, v + (n - 0.5) * 0.5) * smoothstep(0.0, 0.25, u) * smoothstep(1.0, 0.6, u);
	ALBEDO = foam.rgb * 1.6;
	ALPHA = clamp(alpha * body * (0.6 + 0.5 * n), 0.0, 1.0);
}
"""

## The pack's effects (WorldViewRoot hands them over; a view built alone draws its own layers only).
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
var quiet := false
var _mael := {}
var _last_seq := 0
var _primed := false
var _clock := 0.0
var _streak_t := STREAK_S
var _spiral: MeshInstance3D
var _spiral_mat: ShaderMaterial
var _eye: MeshInstance3D
var _eye_mat: ShaderMaterial
var _streak: MeshInstance3D
var _streak_mat: ShaderMaterial


func _init() -> void:
	name = "MaelstromViews"
	var noise := ProjectileMeshes.noise()
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * 2.0
	_spiral_mat = _material(SPIRAL_SHADER, noise)
	_spiral = _mesh(disc, _spiral_mat)
	_eye_mat = _material(EYE_SHADER, noise)
	_eye_mat.render_priority = UNDER + 1
	_eye = _mesh(disc, _eye_mat)
	var strip := PlaneMesh.new()
	strip.size = Vector2.ONE
	_streak_mat = _material(STREAK_SHADER, noise)
	_streak_mat.render_priority = 0
	_streak = _mesh(strip, _streak_mat)
	for m: ShaderMaterial in [_spiral_mat, _eye_mat]:
		m.set_shader_parameter("sea", SEA)
		m.set_shader_parameter("deep", DEEP)
		m.set_shader_parameter("foam", FOAM)
	_streak_mat.set_shader_parameter("foam", FOAM)


func _material(code: String, noise: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("noise_tex", noise)
	m.render_priority = UNDER
	return m


func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_mael = reader.boss_dance().get("maelstrom", {})
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == EFFECT_THROW:
			_throw(e.pos)


## The throw: a splash where the hero stood, the streak running out from the Tidecaller past it.
func _throw(at: Vector2) -> void:
	var from: Vector2 = _mael.get("centre", at)
	var dir := (at - from).normalized() if at.distance_to(from) > 0.01 else Vector2.RIGHT
	_streak_t = 0.0
	_streak.position = SimPlane.to_3d(at + dir * STREAK_M * 0.35, 0.12)
	_streak.rotation = Vector3(0.0, atan2(dir.y, dir.x), 0.0)
	_streak.scale = Vector3(STREAK_M, 1.0, STREAK_W)
	if pack_fx != null and pack_fx.has_id(SPLASH_ID) and pack_fx.has_room(&"impact"):
		pack_fx.spawn(SPLASH_ID, SimPlane.to_3d(at, 0.1), 2.0 * SPLASH_PER_M)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	if _mael.is_empty() and _streak_t >= STREAK_S:
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	var still := ViewPrefs.reduced_motion
	_clock += delta * (0.0 if still else 1.0)
	_streak_t = minf(STREAK_S, _streak_t + delta)
	_streak.visible = _streak_t < STREAK_S
	_streak_mat.set_shader_parameter("alpha", 1.0 - _streak_t / STREAK_S)
	hold.begin()
	_draw(still)
	hold.end()


func _draw(still: bool) -> void:
	var on := not _mael.is_empty()
	_spiral.visible = on
	_eye.visible = on
	if not on:
		return
	var c := SimPlane.to_3d(_mael["centre"])
	var spin := float(int(_mael["spin"]))
	var eye := float(_mael["eye"])
	_spiral.position = c + Vector3(0, 0.035, 0)
	_spiral.scale = Vector3.ONE * RADIUS_M
	_spiral_mat.set_shader_parameter("spin", spin)
	_spiral_mat.set_shader_parameter("pitch", pitch_of(_mael))
	_spiral_mat.set_shader_parameter("eye", eye / RADIUS_M)
	_spiral_mat.set_shader_parameter("clock", _clock)
	_spiral_mat.set_shader_parameter("still", 1.0 if still else 0.0)
	_eye.position = c + Vector3(0, 0.05, 0)
	_eye.scale = Vector3.ONE * eye * EYE_PAD
	_eye_mat.set_shader_parameter("core", 1.0 / EYE_PAD)
	_eye_mat.set_shader_parameter("danger", 0.35 if int(_mael["grace"]) > 0 else 1.0)
	_eye_mat.set_shader_parameter("spin", spin)
	_eye_mat.set_shader_parameter("clock", _clock)
	hold.put(
		&"eye", EYE_ID, &"area", Transform3D(Basis.from_scale(Vector3.ONE * eye * EYE_PER_M), c)
	)


## How tightly the arms wind: the sim's inward speed over its speed round (a flow line's pitch), never flat.
static func pitch_of(m: Dictionary) -> float:
	return clampf(float(m["inward"]) / maxf(float(m["around"]), 0.001), 0.15, 2.0)


## Tests and the shot scripts: what is drawn now.
func spiral_shown() -> bool:
	return _spiral.visible


func spiral_centre() -> Vector2:
	return SimPlane.to_sim(_spiral.position)


func spiral_param(param: StringName) -> float:
	return float(_spiral_mat.get_shader_parameter(param))


func eye_shown() -> bool:
	return _eye.visible


## The eye's dark core radius as drawn (m).
func eye_radius() -> float:
	return _eye.scale.x / EYE_PAD


func eye_danger() -> float:
	return float(_eye_mat.get_shader_parameter("danger"))


func streak_live() -> bool:
	return _streak_t < STREAK_S


func clock() -> float:
	return _clock
