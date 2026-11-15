class_name TwinViews
extends Node3D
## The Twin Wardens' Crossfire and Sword Lane reads, drawn from WorldReader.boss_twin (EI-07: it reads; the lanes and
## the strikes are the sim's, BossTwin). Nothing joins the two bodies: they fight apart.
## - Crossfire's read (its windup and firing): each body's gap lane on the ground, a glowing strip in its colour from
##   the body through the safe spot with chevrons flowing toward it, and the safe spot itself, a bright gold ring with a
##   pulsing core: the two lanes cross only there.
## - The Sword Lane's cut: on its strike a white-hot amber slash runs along the locked line from the boss to the line's
##   end and fades, with a flash of light (the lane's marker is TelegraphViews', its scorch BossStrikeViews').
## Reduced motion stills the chevrons. Nothing here decides an outcome.

const AMBER := Color("#FFB347")
const VIOLET := Color("#B98CFF")
const SAFE := Color("#FFE9A0")
const CUT_SECONDS := 0.45
## The slash's width (m).
const CUT_W := 1.4
const LANE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float alpha = 0.0;
uniform float clock = 0.0;

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float body = 1.0 - smoothstep(0.55, 1.0, across);
	float core = 1.0 - smoothstep(0.0, 0.18, across);
	float chev = smoothstep(0.72, 0.95, fract(UV.x * 7.0 - clock * 1.8 - across * 0.6));
	float fade = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.85, 1.0, UV.x));
	ALBEDO = tint.rgb * (0.8 + 1.4 * core + chev);
	ALPHA = clamp(alpha * fade * (body * 0.25 + core * 0.45 + chev * body * 0.45), 0.0, 1.0);
}
"""
const SPOT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float alpha = 0.0;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float ring = smoothstep(0.08, 0.0, abs(r - 0.82));
	float pulse = 0.5 + 0.5 * sin(clock * 6.0);
	float fill = (1.0 - smoothstep(0.2, 0.8, r)) * (0.25 + 0.35 * pulse);
	float rays = smoothstep(0.8, 1.0, sin(a * 8.0 + clock * 2.0)) * (1.0 - smoothstep(0.3, 0.8, r)) * 0.4;
	ALBEDO = tint.rgb * (1.0 + ring);
	ALPHA = clamp(alpha * (ring * 0.9 + fill + rays) * (1.0 - smoothstep(0.92, 1.0, r)), 0.0, 1.0);
}
"""

## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _flash := OmniLight3D.new()
var _lanes: Array[MeshInstance3D] = []
var _spot := MeshInstance3D.new()
var _cut: MeshInstance3D
## The read state (sync) and what animates in frame time (advance).
var _gaps: Array = []
var _safe := Vector2.ZERO
var _crossfire := 0.0
var _clock := 0.0
var _cut_t := 1.0
var _cut_from := Vector2.ZERO
var _cut_to := Vector2.ZERO
var _struck := false


func _init() -> void:
	name = "TwinViews"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # drawn in frame time (advance)
	for k in 2:
		var lane := MeshInstance3D.new()
		lane.mesh = PlaneMesh.new()
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = LANE_SHADER
		mat.shader = sh
		mat.set_shader_parameter("tint", AMBER if k == 0 else VIOLET)
		lane.material_override = mat
		lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lane.visible = false
		add_child(lane)
		_lanes.append(lane)
	var disc := PlaneMesh.new()
	disc.size = Vector2(2.4, 2.4)
	_spot.mesh = disc
	var spot_mat := ShaderMaterial.new()
	var spot_sh := Shader.new()
	spot_sh.code = SPOT_SHADER
	spot_mat.shader = spot_sh
	spot_mat.set_shader_parameter("tint", SAFE)
	_spot.material_override = spot_mat
	_spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spot.visible = false
	add_child(_spot)
	_cut = WardenLooks.floor_mesh(self, false, Color(1.0, 0.85, 0.55))
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	_flash.omni_range = 7.0
	_flash.light_color = Color(1.0, 0.85, 0.6)
	add_child(_flash)


func sync(reader: WorldReader) -> void:
	var boss := reader.boss_index()
	var tw := reader.boss_twin(boss) if boss >= 0 else {}
	var partner := int(tw.get("partner", -1))
	var other := reader.boss_twin(partner) if partner >= 0 else {}
	_gaps = []
	_crossfire = 0.0
	for s: Dictionary in [tw, other]:
		if s.has("gap"):
			_gaps.append(s["gap"])
			_safe = s["safe"]
			_crossfire = maxf(_crossfire, 0.4 + 0.6 * float(s.get("progress", 0)) / 1000.0)
	var sweep: Dictionary = tw.get("sweep", {})
	var struck := bool(sweep.get("struck", false))
	if struck and not _struck:
		_cut_t = 0.0
		_cut_from = sweep["from"]
		_cut_to = sweep["to"]
	_struck = struck


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	# No lane and the slash done: the last frame drew all of it hidden, so another would change nothing
	if _gaps.is_empty() and _cut_t >= 1.0:
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	_clock += delta * (0.4 if ViewPrefs.reduced_motion else 1.0)
	_cut_t = minf(1.0, _cut_t + delta / CUT_SECONDS)
	_draw_gaps(delta)
	_draw_cut()


## Crossfire's gap lanes (each body's colour, through the safe spot) and the safe spot.
func _draw_gaps(delta: float) -> void:
	for k in _lanes.size():
		var lane := _lanes[k]
		lane.visible = k < _gaps.size()
		if not lane.visible:
			continue
		var g: Array = _gaps[k]
		var from := SimPlane.to_3d(g[0], 0.06)
		var to := SimPlane.to_3d(g[1], 0.06)
		var length := from.distance_to(to)
		(lane.mesh as PlaneMesh).size = Vector2(maxf(length, 0.1), 1.6)
		var along := (to - from).normalized() if length > 0.0001 else Vector3.RIGHT
		lane.transform = Transform3D(
			Basis(along, Vector3.UP, along.cross(Vector3.UP)), (from + to) * 0.5
		)
		var mat := lane.material_override as ShaderMaterial
		mat.set_shader_parameter("alpha", _crossfire)
		mat.set_shader_parameter("clock", _clock)
	_spot.visible = not _gaps.is_empty()
	if _spot.visible:
		_spot.position = SimPlane.to_3d(_safe, 0.08)
		var spot_mat := _spot.material_override as ShaderMaterial
		spot_mat.set_shader_parameter("alpha", _crossfire)
		spot_mat.set_shader_parameter("clock", _clock + delta)


## The Sword Lane's cut: a white-hot slash running out along the locked line, then fading.
func _draw_cut() -> void:
	var on := _cut_t < 1.0
	_cut.visible = on
	_flash.light_energy = 5.0 * (1.0 - _cut_t) if on else 0.0
	if not on:
		return
	var front := minf(1.0, _cut_t * 4.0)
	var fade := 1.0 - smoothstep(0.25, 1.0, _cut_t)
	var to := _cut_from.lerp(_cut_to, front)
	WardenLooks.lay_strip(_cut, _cut_from, to, CUT_W, 0.09)
	WardenLooks.param(_cut, &"alpha", fade)
	WardenLooks.param(_cut, &"glow", 2.0)
	WardenLooks.param(_cut, &"clock", _clock)
	_flash.position = SimPlane.to_3d(_cut_from.lerp(_cut_to, 0.5), 0.8)


## Tests and the shots: the lanes and spot showing, the slash running.
func lanes_shown() -> int:
	var n := 0
	for lane in _lanes:
		n += 1 if lane.visible else 0
	return n


func spot_shown() -> bool:
	return _spot.visible


func lashing() -> bool:
	return _cut_t < 1.0
