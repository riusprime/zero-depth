class_name InterphaseViews
extends Node3D
## v0.9.5 BH6 (owner, 2026-10-25: "he dissapears and then he makes different kind of patterns, with rays, balls, and
## thing that come out of the ground ... I liked the darkness ability of the newer boss so we could also reuse that";
## BOSSES_HARD.md HC4, HC5): the Fallen's interphase, read from the sim (WorldReader.final_interphase; EI-07: nothing
## here decides an outcome).
## - The vanish: the tick the sim takes the body, a burst of violet runes rises where it stood (an expanding ring, rune
##   glyphs lifting and fading); the body itself is not drawn (BossAi.hidden, WorldReader.boss_hidden).
## - Rays: each beam is the Prism's beam look (BossSignatureShaders.BEAM: a hot core and a wider glow, a burning strip
##   on the floor), thinner and violet, from the arena's centre to its edge; through its telegraph a thin aim line.
## - Ground eruptions (rays and Lights Out): a rune ring on the floor with a violet fill growing through the 0.8 s
##   telegraph, then a cluster of stone spikes thrown up (the Gatekeeper's spikes' shape) that sink again. In Lights
##   Out they glow only where the light reaches (the hero's circle, a lit lantern's pool).
## - Rain: a glowing mark at the four edge points (the pair about to fire pulses through its telegraph); the balls are
##   the Prism's orbs (FireballViews); lines of ground spikes walk across the arena: a floor strip with its gap shown
##   through the telegraph, then a row of stone spikes along it.
## - Lights Out: the Lantern Shade's dark (ShadeViews reads WorldReader.boss_light, which the sim fills for it).
## - The return: a ring of the slam's size fills through its 1 s, a violet streak falls toward its middle, and the slam
##   is a flash and a ring thrown out; the body is drawn again.
## Shaders are unshaded, fog_disabled and edge-masked. Effects density Low drops the rune glyphs and halves the spikes;
## reduced motion holds the pulses and the flicker still.

const VIOLET := Color(0.62, 0.3, 1.0)
const CORE := Color(0.95, 0.86, 1.0)
const HOT := Color(1.0, 0.35, 0.55)
const BEAM_Y := 0.9
const MAX_ARMS := 5
const MAX_DISCS := 8
const MAX_STRIPS := 8
const MAX_SPIKES := 320
const MAX_RUNES := 28
## Seconds an eruption's spikes stand (rise, hold, sink) and a vanish or return burst lasts.
const SPIKE_S := 0.7
const BURST_S := 0.9
## Spacing of a spike line's spikes (m).
const LINE_STEP_M := 0.8

## The flat glow every floor mark uses: 0 a rune ring with a growing fill, 1 a rectangle with a bright border and
## chevrons running along it, 2 a soft disc flash.
const FLOOR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(0.62, 0.3, 1.0, 1.0);
uniform int mode = 0;
uniform float fill = 0.0;
uniform float power = 1.0;
uniform float clock = 0.0;
uniform vec2 size = vec2(1.0, 1.0);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float glow = 0.0;
	if (mode == 0) {
		float r = length(q);
		float edge = smoothstep(0.08, 0.0, abs(r - 0.92));
		float inner = smoothstep(fill, fill - 0.05, r) * 0.38 * step(0.001, fill);
		float ang = atan(q.y, q.x) / 6.2831853;
		float rune = step(0.5, fract(ang * 14.0 + clock * 0.15)) * smoothstep(0.84, 0.78, r) * smoothstep(0.5, 0.56, r) * 0.3;
		glow = (edge + inner + rune) * smoothstep(1.0, 0.94, r);
	} else if (mode == 1) {
		vec2 p = q * size * 0.5;
		vec2 d = size * 0.5 - abs(p);
		float b = min(d.x, d.y);
		float edge = smoothstep(0.1, 0.0, abs(b - 0.09));
		float chev = step(0.5, fract((UV.x * size.x - clock * 1.6) / 1.4)) * 0.14;
		glow = (edge * 0.95 + 0.1 + chev) * smoothstep(0.0, 0.08, b);
	} else {
		float r = length(q);
		glow = pow(clamp(1.0 - r, 0.0, 1.0), 1.6);
	}
	ALBEDO = tint.rgb * glow * 1.7;
	ALPHA = clamp(glow * power, 0.0, 1.0);
}
"""

var _data := {}
var _light := {}
var _tick := 0
var _clock := 0.0
var _hero_at := Vector2.ZERO
var _stage := 0
var _body_at := Vector2.ZERO
var _arms: Array[Dictionary] = []
var _discs: Array[MeshInstance3D] = []
var _strips: Array[MeshInstance3D] = []
var _points: Array[MeshInstance3D] = []
var _ret: MeshInstance3D
var _ret_flash: MeshInstance3D
var _streak: MeshInstance3D
var _burst_ring: MeshInstance3D
var _spikes := MultiMeshInstance3D.new()
var _runes := MultiMeshInstance3D.new()
var _beam_shader := Shader.new()
var _floor_shader := Shader.new()
## Eruptions seen striking: [sim position, seconds since]; their spikes stand SPIKE_S.
var _ghosts: Array = []
var _struck := {}
## Bursts: [kind (0 vanish, 1 return), 3D centre, seconds since].
var _bursts: Array = []
var _spike_n := 0
var _drawn_beams := 0
var _lines_drawn := 0
var _discs_drawn := 0


func _init() -> void:
	name = "InterphaseViews"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_beam_shader.code = BossSignatureShaders.BEAM
	_floor_shader.code = FLOOR_SHADER
	for k in MAX_ARMS:
		(
			_arms
			. append(
				{
					"core": _cylinder(CORE, 1.0),
					"glow": _cylinder(VIOLET, 0.8),
					"aim": _cylinder(VIOLET, 0.6),
					"floor": _quad(VIOLET, 1),
				}
			)
		)
	for k in MAX_DISCS:
		_discs.append(_quad(VIOLET, 0))
	for k in MAX_STRIPS:
		_strips.append(_quad(VIOLET, 1))
	for k in 4:
		_points.append(_quad(VIOLET, 0))
	_ret = _quad(HOT, 0)
	_ret_flash = _quad(CORE, 2)
	_burst_ring = _quad(VIOLET, 0)
	_streak = _cylinder(CORE, 1.4)
	_make_spikes()
	_make_runes()


func _mat(mi: MeshInstance3D) -> ShaderMaterial:
	return mi.material_override as ShaderMaterial


func _quad(c: Color, mode: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _floor_shader
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("mode", mode)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.extra_cull_margin = 64.0
	add_child(mi)
	return mi


func _cylinder(c: Color, strength: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 4
	mi.mesh = cyl
	var m := ShaderMaterial.new()
	m.shader = _beam_shader
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("core", CORE)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.extra_cull_margin = 64.0
	add_child(mi)
	return mi


func _make_spikes() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.3
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = MAX_SPIKES
	mm.visible_instance_count = 0
	_spikes.multimesh = mm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.2, 0.15, 0.3)
	sm.emission_enabled = true
	sm.emission = VIOLET
	sm.emission_energy_multiplier = 1.4
	sm.roughness = 0.7
	sm.disable_fog = true
	_spikes.material_override = sm
	_spikes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spikes.extra_cull_margin = 64.0
	add_child(_spikes)


func _make_runes() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = MAX_RUNES
	mm.visible_instance_count = 0
	_runes.multimesh = mm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.vertex_color_use_as_albedo = true
	sm.disable_fog = true
	_runes.material_override = sm
	_runes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_runes.extra_cull_margin = 64.0
	add_child(_runes)


# --- sync and draw ----------------------------------------------------------------------------------------------


func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	_hero_at = reader.player_pos()
	var i := reader.boss_index()
	var prev := _stage
	_data = reader.final_interphase()
	_light = reader.boss_light() if not _data.is_empty() else {}
	_stage = int(_data.get("stage", 0))
	if i >= 0 and _stage == 0:
		_body_at = reader.actor_pos(i)
	if prev < 2 and _stage >= 2:  # it vanishes: a burst of runes where it stood
		_bursts.append([0, SimPlane.to_3d(_body_at, 0.05), 0.0])
		_ghosts.clear()
		_struck.clear()
	elif prev >= 2 and _stage == 0:  # it slams back down
		_bursts.append([1, SimPlane.to_3d(reader.final_home(), 0.05), 0.0])
	_note_strikes()
	_draw(0.0)


func _process(delta: float) -> void:
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	for g in _ghosts:
		g[1] += delta
	for b in _bursts:
		b[2] += delta
	_ghosts = _ghosts.filter(func(g: Array) -> bool: return g[1] < SPIKE_S)
	_bursts = _bursts.filter(func(b: Array) -> bool: return b[2] < BURST_S)
	_draw(delta)


## An eruption that strikes this sync starts its spikes (a ghost lives SPIKE_S in frame time).
func _note_strikes() -> void:
	for e: Dictionary in _data.get("erupts", []):
		var key := Vector2i(roundi(float(e["pos"].x) * 10.0), roundi(float(e["pos"].y) * 10.0))
		if bool(e["striking"]) and not _struck.has(key):
			_struck[key] = true
			_ghosts.append([e["pos"], 0.0])


func _lit_factor(p: Vector2) -> float:
	if _light.is_empty() or not bool(_light.get("dark", false)):
		return 1.0
	if p.distance_to(_hero_at) <= float(_light["light_m"]) + 1.0:
		return 1.0
	for lamp: Dictionary in _light["lamps"]:
		if bool(lamp["lit"]) and p.distance_to(lamp["pos"]) <= float(_light["lamp_m"]) + 1.0:
			return 1.0
	return 0.0


func _hide_all() -> void:
	for arm in _arms:
		for k in ["core", "glow", "aim", "floor"]:
			(arm[k] as Node3D).visible = false
	for n in _discs + _strips + _points:
		n.visible = false
	for n: Node3D in [_ret, _ret_flash, _streak, _burst_ring]:
		n.visible = false
	_spikes.multimesh.visible_instance_count = 0
	_runes.multimesh.visible_instance_count = 0


func _draw(_delta: float) -> void:
	_hide_all()
	_spike_n = 0
	_drawn_beams = 0
	_lines_drawn = 0
	_discs_drawn = 0
	var calm := ViewPrefs.reduced_motion
	var pulse := 1.0 if calm else 0.8 + 0.2 * sin(_clock * 7.0)
	if not _data.is_empty():
		_draw_beams(pulse)
		_draw_erupts(pulse)
		_draw_lines(pulse)
		_draw_points(pulse)
		_draw_return(pulse)
	_draw_ghosts()
	_draw_bursts()
	_spikes.multimesh.visible_instance_count = _spike_n


func _set_floor(
	mi: MeshInstance3D, c: Vector2, size: Vector2, yaw: float, fill: float, power: float
) -> void:
	mi.visible = true
	mi.transform = Transform3D(
		Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size.x, 1.0, size.y)),
		SimPlane.to_3d(c, 0.04)
	)
	var m := _mat(mi)
	m.set_shader_parameter("fill", fill)
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("clock", _clock)
	m.set_shader_parameter("size", size)


func _draw_beams(pulse: float) -> void:
	var beams: Array = _data["beams"]
	for k in mini(beams.size(), MAX_ARMS):
		var b: Dictionary = beams[k]
		var arm: Dictionary = _arms[k]
		var from2: Vector2 = b["from"]
		var to2 := from2 + Kin.dir(int(b["angle"])) * float(b["len"])
		var a := SimPlane.to_3d(from2, BEAM_Y)
		var e := SimPlane.to_3d(to2, BEAM_Y * 0.7)
		var hw := float(b["half"])
		var p := float(b["progress"]) / 1000.0
		_drawn_beams += 1
		if not bool(b["live"]):
			var aim: MeshInstance3D = arm["aim"]
			aim.visible = true
			PrismViews._place(aim, a, e, 0.05 + 0.06 * p)
			_mat(aim).set_shader_parameter("strength", 0.4 + 1.4 * p)
			var yaw := atan2(-(e - a).z, (e - a).x)
			_set_floor(
				arm["floor"],
				(from2 + to2) * 0.5,
				Vector2(float(b["len"]), hw * 2.0 + 0.2),
				yaw,
				0.0,
				0.25 + 0.5 * p
			)
			continue
		var core: MeshInstance3D = arm["core"]
		var glow: MeshInstance3D = arm["glow"]
		core.visible = true
		glow.visible = true
		PrismViews._place(core, a, e, hw * 0.45)
		PrismViews._place(
			glow,
			a,
			e,
			hw * (1.1 if ViewPrefs.reduced_motion else 1.1 + 0.08 * sin(_clock * 9.0 + k))
		)
		_mat(core).set_shader_parameter("strength", pulse)
		var yaw2 := atan2(-(e - a).z, (e - a).x)
		_set_floor(
			arm["floor"],
			(from2 + to2) * 0.5,
			Vector2(float(b["len"]), hw * 2.0 + 0.3),
			yaw2,
			0.0,
			0.9
		)


func _draw_erupts(pulse: float) -> void:
	var list: Array = _data["erupts"]
	for k in mini(list.size(), MAX_DISCS):
		var e: Dictionary = list[k]
		var lit := _lit_factor(e["pos"])
		var r := float(e["radius"])
		var p := float(e["progress"]) / 1000.0
		_discs_drawn += 1
		var power := (0.55 + 0.45 * p) * (pulse if p < 1.0 else 1.0) * lit
		if bool(e["striking"]):
			power = 0.0
		_set_floor(_discs[k], e["pos"], Vector2(r * 2.0, r * 2.0), 0.0, p, power)


func _draw_lines(pulse: float) -> void:
	var lines: Array = _data["lines"]
	var s := 0
	for line: Dictionary in lines:
		var p := float(line["progress"]) / 1000.0
		var moving := bool(line["moving"])
		for box: Obb in line["obbs"]:
			if s < MAX_STRIPS:
				var yaw := float(box.angle) * TAU / 4096.0
				_set_floor(
					_strips[s],
					box.center,
					Vector2(box.half.x * 2.0, box.half.y * 2.0 + 0.3),
					yaw,
					0.0,
					(0.35 + 0.5 * p) * (pulse if not moving else 1.0)
				)
				s += 1
			if moving:
				_spike_row(box)
		_lines_drawn += 1


func _spike_row(box: Obb) -> void:
	var n := int(box.half.x * 2.0 / LINE_STEP_M)
	var low := ViewPrefs.effects_density == "low"
	for j in n:
		if low and j % 2 == 1:
			continue
		if _spike_n >= MAX_SPIKES - 24:
			return
		var u := -box.half.x + (j + 0.5) * LINE_STEP_M
		var at := box.center + box.axis_u * u
		var h := 0.9 + 0.5 * float((j * 7) % 5) / 4.0
		_add_spike(at, h, 0.8, 0.0)


func _add_spike(at: Vector2, h: float, w: float, lean: float) -> void:
	if _spike_n >= MAX_SPIKES:
		return
	var basis := Basis.from_scale(Vector3(w, h, w))
	if lean != 0.0:
		basis = Basis(Vector3.FORWARD, lean) * basis
	_spikes.multimesh.set_instance_transform(
		_spike_n, Transform3D(basis, SimPlane.to_3d(at, h * 0.5))
	)
	_spike_n += 1


func _draw_ghosts() -> void:
	var per := 4 if ViewPrefs.effects_density == "low" else 7
	for g in _ghosts:
		var t := float(g[1]) / SPIKE_S
		var rise := clampf(t * 8.0, 0.0, 1.0) if t < 0.7 else clampf((1.0 - t) / 0.3, 0.0, 1.0)
		var c: Vector2 = g[0]
		_add_spike(c, 2.0 * rise + 0.01, 1.2, 0.0)
		for j in per - 1:
			var ang := j * TAU / float(per - 1)
			_add_spike(
				c + Vector2(cos(ang), sin(ang)) * 0.9, (1.0 + 0.3 * (j % 3)) * rise + 0.01, 0.8, 0.0
			)


func _draw_points(pulse: float) -> void:
	var pts: Array = _data["points"]
	for k in mini(pts.size(), 4):
		var p: Dictionary = pts[k]
		var warn := int(p["warn"])
		if warn < 0:
			continue
		_set_floor(
			_points[k],
			p["pos"],
			Vector2(2.2, 2.2),
			0.0,
			float(warn) / 1000.0,
			(0.4 + 0.6 * float(warn) / 1000.0) * pulse
		)


func _draw_return(pulse: float) -> void:
	var ret: Dictionary = _data["ret"]
	if ret.is_empty():
		return
	var p := float(ret["progress"]) / 1000.0
	var r := float(ret["radius"])
	var c: Vector2 = ret["center"]
	_set_floor(_ret, c, Vector2(r * 2.0, r * 2.0), 0.0, p, (0.5 + 0.5 * p) * pulse)
	_streak.visible = true
	var top := SimPlane.to_3d(c, 14.0 - 13.0 * p * p)
	var bottom := SimPlane.to_3d(c, 14.0 - 13.0 * p * p - 3.0)
	PrismViews._place(_streak, top, bottom, 0.12 + 0.25 * p)
	_mat(_streak).set_shader_parameter("strength", 0.6 + 1.6 * p)


func _draw_bursts() -> void:
	var runes := 0
	var low := ViewPrefs.effects_density == "low"
	for b in _bursts:
		var t := float(b[2]) / BURST_S
		var at: Vector3 = b[1]
		var kind := int(b[0])
		if kind == 1:
			_ret_flash.visible = true
			_ret_flash.transform = Transform3D(Basis.from_scale(Vector3.ONE * (2.5 + 5.0 * t)), at)
			_mat(_ret_flash).set_shader_parameter("power", 1.0 - t)
		else:
			_burst_ring.visible = true
			_burst_ring.transform = Transform3D(Basis.from_scale(Vector3.ONE * (1.5 + 5.5 * t)), at)
			_mat(_burst_ring).set_shader_parameter("power", 1.0 - t)
			_mat(_burst_ring).set_shader_parameter("fill", t)
			if low:
				continue
			for j in 12:
				if runes >= MAX_RUNES:
					break
				var ang := j * TAU / 12.0 + float(j % 3) * 0.3
				var out := (0.6 + 0.9 * float(j % 4) / 3.0) * t * 3.0
				var pos := (
					at
					+ Vector3(cos(ang) * out, 0.4 + t * (1.5 + float(j % 5) * 0.5), sin(ang) * out)
				)
				_runes.multimesh.set_instance_transform(runes, Transform3D(Basis(), pos))
				_runes.multimesh.set_instance_color(runes, Color(VIOLET, (1.0 - t) * 0.9))
				runes += 1
	_runes.multimesh.visible_instance_count = runes


# --- reads for the tests ----------------------------------------------------------------------------------------


func beams_drawn() -> int:
	return _drawn_beams


func discs_drawn() -> int:
	return _discs_drawn


func lines_drawn() -> int:
	return _lines_drawn


func spikes_drawn() -> int:
	return _spike_n


func bursts_alive() -> int:
	return _bursts.size()


func return_drawn() -> bool:
	return _ret.visible


func points_drawn() -> int:
	var n := 0
	for p in _points:
		n += 1 if p.visible else 0
	return n
