class_name TwinViews
extends Node3D
## v0.9.0 NB2 (BOSSES_4_5.md N2; the VX quality bar: layered, never a flat single-colour shape): the Twin Wardens'
## chain and their two signature reads, drawn from WorldReader.boss_twin (EI-07: it reads; the burn, the length rule
## and the strikes are the sim's, BossTwin).
## - The chain: heavy iron links (lit, metallic, each turned a quarter from the last) hung between the two shackles
##   with a sag that tightens as it stretches; inside each link a hot core glowing amber at the amber Warden's end and
##   violet at the violet's, a soft halo round it; embers shedding off and rising; a light at its middle. Hot (it
##   burns) it glows and sheds; cooled (a body rising, a gate, the Chain Sweep holding it) it dims and goes slack-dark.
##   A burn flashes white-hot where it touched the hero, with a puff of sparks. The angry Warden's half burns hotter.
## - Crossfire's read (its windup and firing): each body's gap lane on the ground, a glowing strip in its colour from
##   the body through the safe spot with chevrons flowing toward it, and the safe spot itself, a bright gold ring with a
##   pulsing core: the two lanes cross only there.
## - The Chain Sweep's lash: on its strike a white-hot whip of links runs along the locked line from the boss to the
##   line's end and fades, with a flash of light (the lane's marker is TelegraphViews', its scorch BossStrikeViews').
## Embers halve on Low density; reduced motion stills the sway and the embers' drift. Nothing here decides an outcome.

const MAX_LINKS := 40
const LINK_M := 0.3
const EMBERS := 48
const LASH_LINKS := 32
## The shackles' height (the chain's ends, metres) and the most it sags.
const END_H := 1.25
const SAG_M := 0.55
const AMBER := Color("#FFB347")
const VIOLET := Color("#B98CFF")
const SAFE := Color("#FFE9A0")
const IRON := Color("#2E2A28")
const LASH_SECONDS := 0.45
const BURN_SECONDS := 0.35
const LANE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

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
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

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

static var _glow_tex: GradientTexture2D

var _links := MultiMeshInstance3D.new()
var _cores := MultiMeshInstance3D.new()
var _halos := MultiMeshInstance3D.new()
var _embers := MultiMeshInstance3D.new()
var _lash := MultiMeshInstance3D.new()
var _link_mat := StandardMaterial3D.new()
var _core_mat := StandardMaterial3D.new()
var _halo_mat := StandardMaterial3D.new()
var _ember_mat := StandardMaterial3D.new()
var _lash_mat := StandardMaterial3D.new()
var _light := OmniLight3D.new()
var _flash := OmniLight3D.new()
var _lanes: Array[MeshInstance3D] = []
var _spot := MeshInstance3D.new()
var _burn := MeshInstance3D.new()
var _burn_mat := StandardMaterial3D.new()
## The read state (sync) and what animates in frame time (advance).
var _chain: Array = []
var _hot := false
var _lifted := false
var _amber_angry := false
var _violet_angry := false
var _gaps: Array = []
var _safe := Vector2.ZERO
var _crossfire := 0.0
var _sweep := {}
var _heat := 0.0
var _anger_a := 0.0
var _anger_v := 0.0
var _show := 0.0
var _clock := 0.0
var _lash_t := 1.0
var _lash_from := Vector3.ZERO
var _lash_to := Vector3.ZERO
var _burn_t := 1.0
var _burn_at := Vector3.ZERO
var _struck := false
var _last_burned := -1


func _init() -> void:
	name = "TwinViews"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # drawn in frame time (advance)
	var link := TorusMesh.new()
	link.inner_radius = 0.07
	link.outer_radius = 0.14
	link.rings = 12
	link.ring_segments = 8
	_link_mat.albedo_color = IRON
	_link_mat.metallic = 0.85
	_link_mat.roughness = 0.45
	_link_mat.emission_enabled = true
	_link_mat.emission = Color(1.0, 0.45, 0.15)
	_link_mat.emission_energy_multiplier = 0.25
	link.material = _link_mat
	_setup_mm(_links, link, MAX_LINKS, false)
	var core := SphereMesh.new()
	core.radius = 0.07
	core.height = 0.14
	core.radial_segments = 8
	core.rings = 4
	_additive(_core_mat, false)
	_core_mat.vertex_color_use_as_albedo = true
	core.material = _core_mat
	_setup_mm(_cores, core, MAX_LINKS, true)
	var halo := QuadMesh.new()
	halo.size = Vector2(0.7, 0.7)
	_additive(_halo_mat, true)
	_halo_mat.albedo_texture = _glow_texture()
	_halo_mat.vertex_color_use_as_albedo = true
	halo.material = _halo_mat
	_setup_mm(_halos, halo, MAX_LINKS, true)
	var ember := QuadMesh.new()
	ember.size = Vector2(0.09, 0.09)
	_additive(_ember_mat, true)
	_ember_mat.albedo_texture = _glow_texture()
	_ember_mat.vertex_color_use_as_albedo = true
	ember.material = _ember_mat
	_setup_mm(_embers, ember, EMBERS, true)
	var whip := CapsuleMesh.new()
	whip.radius = 0.09
	whip.height = 0.42
	whip.radial_segments = 8
	whip.rings = 2
	_additive(_lash_mat, false)
	_lash_mat.vertex_color_use_as_albedo = true
	whip.material = _lash_mat
	_setup_mm(_lash, whip, LASH_LINKS, true)
	for n: MultiMeshInstance3D in [_links, _cores, _halos, _embers, _lash]:
		add_child(n)
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
	var puff := QuadMesh.new()
	puff.size = Vector2(1.6, 1.6)
	_additive(_burn_mat, true)
	_burn_mat.albedo_texture = _glow_texture()
	puff.material = _burn_mat
	_burn.mesh = puff
	_burn.visible = false
	add_child(_burn)
	for l: OmniLight3D in [_light, _flash]:
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
	_light.omni_range = 5.0
	_flash.omni_range = 7.0
	_flash.light_color = Color(1.0, 0.85, 0.6)


static func _setup_mm(node: MultiMeshInstance3D, mesh: Mesh, n: int, colours: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colours
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _additive(m: StandardMaterial3D, billboard: bool) -> void:
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true


static func _glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.3, Color(1, 1, 1, 0.5))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex


func sync(reader: WorldReader) -> void:
	var boss := reader.boss_index()
	var tw := reader.boss_twin(boss) if boss >= 0 else {}
	_chain = tw.get("chain", [])
	_hot = bool(tw.get("hot", false))
	_lifted = bool(tw.get("lifted", false))
	_amber_angry = bool(tw.get("angry", false))
	var partner := int(tw.get("partner", -1))
	var other := reader.boss_twin(partner) if partner >= 0 else {}
	_violet_angry = bool(other.get("angry", false))
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
		_lash_t = 0.0
		_lash_from = SimPlane.to_3d(sweep["from"], END_H)
		_lash_to = SimPlane.to_3d(sweep["to"], 0.35)
	_struck = struck
	_sweep = sweep
	var burned := int(tw.get("burned", -1))
	if burned >= 0 and burned <= 1 and _last_burned != burned and _chain.size() == 2:
		_burn_t = 0.0
		_burn_at = SimPlane.to_3d(reader.player_pos(), END_H - SAG_M * 0.6)
	_last_burned = burned


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var reduced := ViewPrefs.reduced_motion
	_clock += delta * (0.4 if reduced else 1.0)
	var shown := _chain.size() == 2
	_show = move_toward(_show, 1.0 if shown else 0.0, delta * 4.0)
	_heat = move_toward(_heat, 1.0 if _hot else 0.25, delta * 3.0)
	_anger_a = move_toward(_anger_a, 1.0 if _amber_angry else 0.0, delta * 4.0)
	_anger_v = move_toward(_anger_v, 1.0 if _violet_angry else 0.0, delta * 4.0)
	_lash_t = minf(1.0, _lash_t + delta / LASH_SECONDS)
	_burn_t = minf(1.0, _burn_t + delta / BURN_SECONDS)
	_draw_chain(shown, reduced)
	_draw_gaps(delta)
	_draw_lash()
	_burn.visible = _burn_t < 1.0
	if _burn.visible:
		_burn.position = _burn_at
		_burn.scale = Vector3.ONE * (0.6 + 0.8 * _burn_t)
		_burn_mat.albedo_color = Color(1.0, 0.9, 0.7, 0.9 * (1.0 - _burn_t))


## Where the chain hangs at f (0 the amber Warden's shackle, 1 the violet's), in world space.
func chain_point(f: float) -> Vector3:
	if _chain.size() != 2:
		return Vector3.ZERO
	var a := SimPlane.to_3d(_chain[0], END_H)
	var b := SimPlane.to_3d(_chain[1], END_H)
	var length := a.distance_to(b)
	var taut := clampf((length - 3.0) / 6.0, 0.0, 1.0)
	var sag := SAG_M * (1.0 - 0.7 * taut) * (0.4 if _lifted else 1.0)
	var sway := 0.0 if ViewPrefs.reduced_motion else sin(_clock * 1.7 + f * 3.0) * 0.04
	return a.lerp(b, f) + Vector3(0, -sag * 4.0 * f * (1.0 - f) + sway * f * (1.0 - f) * 4.0, 0)


## The hot core's colour at f: amber to violet, white-hot where its Warden is angry, dimmer when cooled.
func core_color(f: float) -> Color:
	var c := AMBER.lerp(VIOLET, smoothstep(0.25, 0.75, f))
	var anger := lerpf(_anger_a, _anger_v, f)
	c = c.lerp(Color(1.0, 0.95, 0.85), 0.35 * anger)
	var pulse := 0.85 + 0.15 * sin(_clock * 5.0 + f * 9.0)
	return Color(c.r, c.g, c.b, clampf(_heat * pulse * (0.75 + 0.25 * anger), 0.0, 1.0) * _show)


func _draw_chain(shown: bool, reduced: bool) -> void:
	var n := 0
	if shown:
		var a := SimPlane.to_3d(_chain[0], END_H)
		var b := SimPlane.to_3d(_chain[1], END_H)
		n = clampi(int(a.distance_to(b) / LINK_M) + 1, 2, MAX_LINKS)
	for mm: MultiMesh in [_links.multimesh, _cores.multimesh, _halos.multimesh]:
		mm.visible_instance_count = n
	for k in n:
		var f := (k + 0.5) / float(n)
		var at := chain_point(f)
		var ahead := chain_point(minf(1.0, f + 0.02)) - chain_point(maxf(0.0, f - 0.02))
		var fwd := ahead.normalized() if ahead.length() > 0.0001 else Vector3.RIGHT
		var side := fwd.cross(Vector3.UP).normalized() if absf(fwd.y) < 0.99 else Vector3.FORWARD
		var up := side.cross(fwd).normalized()
		var basis := Basis(fwd, up, side)
		if k % 2 == 1:
			basis = basis * Basis(Vector3.RIGHT, PI * 0.5)
		# TorusMesh lies in its XZ plane: stand it along the chain (its hole across the line).
		var link := basis * Basis(Vector3.FORWARD, PI * 0.5)
		_links.multimesh.set_instance_transform(k, Transform3D(link, at))
		var c := core_color(f)
		_cores.multimesh.set_instance_transform(
			k, Transform3D(Basis().scaled(Vector3.ONE * (0.8 + 0.5 * c.a)), at)
		)
		_cores.multimesh.set_instance_color(k, Color(c.r, c.g, c.b, c.a))
		_halos.multimesh.set_instance_transform(
			k, Transform3D(Basis().scaled(Vector3.ONE * (0.6 + 0.6 * c.a)), at)
		)
		_halos.multimesh.set_instance_color(k, Color(c.r, c.g, c.b, 0.35 * c.a))
	_link_mat.emission_energy_multiplier = 0.15 + 0.9 * _heat * _show
	_draw_embers(shown, reduced)
	_light.visible = shown
	if shown:
		var mid := core_color(0.5)
		_light.position = chain_point(0.5) + Vector3(0, 0.3, 0)
		_light.light_color = Color(mid.r, mid.g, mid.b)
		_light.light_energy = 1.6 * _heat * _show


## Embers shedding off the hot chain and rising, each from its own place along it.
func _draw_embers(shown: bool, reduced: bool) -> void:
	var mm := _embers.multimesh
	var n := EMBERS / 2 if ViewPrefs.effects_density == "low" else EMBERS
	var on := shown and _heat > 0.4
	mm.visible_instance_count = n if on else 0
	if not on:
		return
	for k in n:
		var f := fposmod(k * 0.618034, 1.0)
		var life := fposmod(k * 0.371 + _clock * (0.0 if reduced else 0.7), 1.0)
		var drift := Vector3(sin(k * 1.7) * 0.3, 0.9, cos(k * 2.3) * 0.3) * life
		var at := chain_point(f) + drift
		var c := core_color(f)
		mm.set_instance_transform(
			k, Transform3D(Basis().scaled(Vector3.ONE * (1.0 - life * 0.7)), at)
		)
		mm.set_instance_color(k, Color(c.r, c.g, c.b, c.a * (1.0 - life)))


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


## The Chain Sweep's lash: a white-hot whip running along the locked line, then fading.
func _draw_lash() -> void:
	var mm := _lash.multimesh
	var on := _lash_t < 1.0
	mm.visible_instance_count = LASH_LINKS if on else 0
	_flash.light_energy = 5.0 * (1.0 - _lash_t) if on else 0.0
	if not on:
		return
	var front := minf(1.0, _lash_t * 4.0)
	var fade := 1.0 - smoothstep(0.25, 1.0, _lash_t)
	var along := _lash_to - _lash_from
	var basis := Basis()
	if along.length() > 0.0001:
		var fwd := along.normalized()
		var side := fwd.cross(Vector3.UP).normalized()
		basis = Basis(side, fwd, side.cross(fwd))
	_flash.position = _lash_from.lerp(_lash_to, 0.5) + Vector3(0, 0.5, 0)
	for k in LASH_LINKS:
		var f := (k + 0.5) / LASH_LINKS
		var lift := sin(f * PI) * 0.35 * (1.0 - _lash_t)
		var at := _lash_from.lerp(_lash_to, f) + Vector3(0, lift, 0)
		var lit := 1.0 if f <= front else 0.0
		var c := AMBER.lerp(VIOLET, f).lerp(Color.WHITE, 0.55 * fade)
		mm.set_instance_transform(k, Transform3D(basis, at))
		mm.set_instance_color(k, Color(c.r, c.g, c.b, lit * fade))


## Tests and the shots: links drawn, embers drawn, the lanes and spot showing, the lash running.
func links_drawn() -> int:
	return _links.multimesh.visible_instance_count


func embers_drawn() -> int:
	return _embers.multimesh.visible_instance_count


func lanes_shown() -> int:
	var n := 0
	for lane in _lanes:
		n += 1 if lane.visible else 0
	return n


func spot_shown() -> bool:
	return _spot.visible


func lashing() -> bool:
	return _lash_t < 1.0


func heat() -> float:
	return _heat


func burn_flashing() -> bool:
	return _burn_t < 1.0
