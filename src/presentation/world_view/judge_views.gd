class_name JudgeViews
extends Node3D
## v0.9.0 NB3 (BOSSES_4_5.md N3; the VX quality bar: layered, never a flat single-colour shape): the Clockwork Judge's
## echo and its Verdict's pendulum, drawn from WorldReader.boss_echo (EI-07: it reads; every strike is the sim's,
## BossJudge).
## - The recording: while the Judge records the last 3 s before its echo, gold glints hang over the points it keeps,
##   brighter as the echo nears (each a glowing mote over a faint ground tick).
## - The path (the windup's 0.8 s and on): every point it will strike shows at once as a clock-gear marker (a turning
##   toothed rim, twelve ticks, a sweeping hand, a hot core that fills as its strike nears; ECHO_MARKER_SHADER), joined
##   in the order walked by a glowing gold ribbon (a hot thread over a soft halo), so the whole path reads before the
##   first ghost lands.
## - The ghost trail: as each point strikes, a golden afterimage of the hero rises there (a translucent body and head
##   with a bright rim and an inner glow, fading up), a ring of light rolls out, gear filings spray, and a gold light
##   flashes on the newest strike.
## - The Verdict: a brass pendulum (a long rod, a gavel weight with a hot seam) hangs over the tracked square and sways;
##   as the square locks it is hauled back to its apex, and on the strike it swings down onto the square with a
##   shockwave and sparks.
## Effects density Low halves the filings and glints; reduced motion slows the turning and the sway. Nothing here
## decides an outcome.

const MAX_POINTS := BossSchemas.ECHO_MAX_POINTS
const GOLD := Color(1.0, 0.78, 0.3)
const HOT := Color(1.0, 0.95, 0.72)
const BRONZE := Color(0.32, 0.2, 0.06)
const GHOST_S := 0.75
const RING_S := 0.55
const FILINGS_PER := 10
const FILING_S := 0.6
const PIVOT_H := 5.5
const ECHO_MARKER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 gold : source_color = vec4(1.0, 0.78, 0.3, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.95, 0.72, 1.0);
uniform float heat = 0.0;
uniform float alpha = 0.0;
uniform float clock = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float turns = a / 6.2831853;
	float n = texture(noise_tex, UV * 2.5 + vec2(clock * 0.04, -clock * 0.03)).r;
	float rim = smoothstep(0.07, 0.0, abs(r - 0.88));
	float teeth = step(0.5, fract(turns * 16.0 + clock * 0.25)) * smoothstep(0.09, 0.0, abs(r - 0.76));
	float ticks = step(0.82, fract(turns * 12.0)) * smoothstep(0.1, 0.0, abs(r - 0.6));
	float ang = 1.5707963 - heat * 6.2831853;
	vec2 d = vec2(cos(ang), sin(ang));
	float along = dot(q, d);
	float off = abs(q.x * d.y - q.y * d.x);
	float hand = step(0.0, along) * step(along, 0.62) * smoothstep(0.05, 0.0, off);
	float core = smoothstep(0.62, 0.0, r) * heat * heat;
	float fill = smoothstep(0.9, 0.2, r) * (0.12 + 0.18 * n);
	float lit = max(rim, max(teeth * 0.75, max(ticks * 0.55, max(hand, core))));
	vec3 col = mix(gold.rgb, hot.rgb, clamp(heat * 1.2 + lit * 0.3, 0.0, 1.0));
	ALBEDO = col * (0.5 + 1.6 * lit + 0.6 * n * fill);
	ALPHA = clamp(alpha * (lit + fill), 0.0, 1.0) * smoothstep(1.0, 0.93, r);
}
"""

var _echo := {}
var _markers: Array[MeshInstance3D] = []
var _marker_mats: Array[ShaderMaterial] = []
var _ribbon := MultiMeshInstance3D.new()
var _halo := MultiMeshInstance3D.new()
var _glints := MultiMeshInstance3D.new()
var _ghosts: Array[Node3D] = []
var _ghost_mats: Array[StandardMaterial3D] = []
var _inner_mats: Array[StandardMaterial3D] = []
var _ghost_t := PackedFloat32Array()
var _rings: Array[MeshInstance3D] = []
var _ring_mats: Array[StandardMaterial3D] = []
var _filings := MultiMeshInstance3D.new()
## Per filing: [origin, velocity, age]; per ghost slot its point.
var _filing_state: Array = []
var _light := OmniLight3D.new()
var _light_t := 1.0
var _struck := {}
var _was_phase := WorldReader.ECHO_NONE
var _clock := 0.0
var _show := 0.0
## The Verdict's pendulum.
var _pendulum := Node3D.new()
var _pendulum_mat := StandardMaterial3D.new()
var _seam_mat := StandardMaterial3D.new()
var _verdict := {}
var _verdict_at := Vector3.ZERO
var _swing := 0.0
var _drop_t := 1.0
var _shock := MeshInstance3D.new()
var _shock_mat := StandardMaterial3D.new()


func _init() -> void:
	name = "JudgeViews"
	var sh := Shader.new()
	sh.code = ECHO_MARKER_SHADER
	for k in MAX_POINTS:
		var m := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * 2.0
		m.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("gold", GOLD)
		mat.set_shader_parameter("hot", HOT)
		mat.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_markers.append(m)
		_marker_mats.append(mat)
	_ribbon.multimesh = _segments(0.06, _glow_mat(HOT, 1.6, 0.9))
	_halo.multimesh = _segments(0.32, _glow_mat(GOLD, 1.0, 0.28))
	for mmi: MultiMeshInstance3D in [_ribbon, _halo]:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	var glint := SphereMesh.new()
	glint.radius = 0.09
	glint.height = 0.18
	glint.radial_segments = 8
	glint.rings = 4
	glint.material = _glow_mat(GOLD, 2.2, 0.8)
	_glints.multimesh = _multi(glint, MAX_POINTS)
	_glints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glints)
	_build_ghosts()
	var filing := BoxMesh.new()
	filing.size = Vector3(0.06, 0.02, 0.14)
	filing.material = _glow_mat(HOT, 1.6, 1.0)
	_filings.multimesh = _multi(filing, MAX_POINTS * FILINGS_PER)
	_filings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_filings)
	_light.light_color = GOLD
	_light.light_energy = 0.0
	_light.omni_range = 4.0
	_light.shadow_enabled = false
	add_child(_light)
	_build_pendulum()


## A strip mesh of up to MAX_POINTS segments `width` wide (a unit box stretched along each segment).
func _segments(width: float, mat: Material) -> MultiMesh:
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.02, 1.0)
	box.material = mat
	return _multi(box, MAX_POINTS)


func _multi(mesh: Mesh, n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	return mm


func _glow_mat(c: Color, energy: float, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(c * energy, a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Each ghost: a translucent gold body and head with a bright rim (the hero's shape, the Judge's colour), an inner
## glow column, and a ring of light that rolls out on the floor.
func _build_ghosts() -> void:
	for k in MAX_POINTS:
		var g := Node3D.new()
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(GOLD, 0.0)
		mat.rim_enabled = true
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		var torso := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.28
		cap.height = 1.1
		torso.mesh = cap
		torso.position = Vector3(0, 0.75, 0)
		torso.material_override = mat
		var head := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.2
		ball.height = 0.4
		head.mesh = ball
		head.position = Vector3(0, 1.5, 0)
		head.material_override = mat
		var inner := MeshInstance3D.new()
		var col := CylinderMesh.new()
		col.top_radius = 0.05
		col.bottom_radius = 0.16
		col.height = 2.2
		inner.mesh = col
		inner.position = Vector3(0, 1.1, 0)
		var im := _glow_mat(HOT, 1.2, 0.0)
		inner.material_override = im
		_inner_mats.append(im)
		for part: MeshInstance3D in [torso, head, inner]:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(part)
		g.visible = false
		add_child(g)
		_ghosts.append(g)
		_ghost_mats.append(mat)
		_ghost_t.append(1.0)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.86
		torus.outer_radius = 1.0
		torus.rings = 40
		ring.mesh = torus
		var rm := _glow_mat(GOLD, 1.2, 0.0)
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		_rings.append(ring)
		_ring_mats.append(rm)


## The Verdict's pendulum: a long brass rod from a pivot high over the square, a gavel weight with a hot seam, and its
## impact shockwave.
func _build_pendulum() -> void:
	_pendulum_mat.albedo_color = Color("#B8862E")
	_pendulum_mat.metallic = 0.85
	_pendulum_mat.roughness = 0.3
	_pendulum_mat.emission_enabled = true
	_pendulum_mat.emission = GOLD
	_pendulum_mat.emission_energy_multiplier = 0.4
	_pendulum_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rod := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = PIVOT_H - 0.6
	rod.mesh = cyl
	rod.position = Vector3(0, -(PIVOT_H - 0.6) * 0.5, 0)
	rod.material_override = _pendulum_mat
	var head := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.55, 0.55)
	head.mesh = box
	head.position = Vector3(0, -(PIVOT_H - 0.35), 0)
	head.material_override = _pendulum_mat
	var seam := MeshInstance3D.new()
	var band := BoxMesh.new()
	band.size = Vector3(1.24, 0.08, 0.59)
	seam.mesh = band
	seam.position = head.position
	_seam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_seam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_seam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_seam_mat.albedo_color = Color(HOT * 2.0, 0.0)
	seam.material_override = _seam_mat
	for part: MeshInstance3D in [rod, head, seam]:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pendulum.add_child(part)
	_pendulum.visible = false
	add_child(_pendulum)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 48
	_shock.mesh = torus
	_shock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shock_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shock_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shock_mat.albedo_color = Color(GOLD * 2.0, 0.0)
	_shock.material_override = _shock_mat
	_shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shock.visible = false
	add_child(_shock)


func sync(reader: WorldReader) -> void:
	var boss := reader.boss_index()
	_echo = reader.boss_echo(boss) if boss >= 0 else {}
	var phase := int(_echo.get("phase", WorldReader.ECHO_NONE))
	if phase == WorldReader.ECHO_SHOW and _was_phase != WorldReader.ECHO_SHOW:
		_struck.clear()
	_was_phase = phase
	if phase == WorldReader.ECHO_REPLAY:
		var now := int(_echo["t"])
		for p: Dictionary in _echo["path"]:
			var k := int(p["k"])
			if now >= int(p["at"]) and not _struck.has(k):
				_struck[k] = true
				_spawn_ghost(k, SimPlane.to_3d(p["pos"]))
	var v: Dictionary = _echo.get("verdict", {})
	if not v.is_empty():
		_verdict = v
		_verdict_at = SimPlane.to_3d(v["center"])
	elif not _verdict.is_empty():
		_verdict = {}
		_drop_t = 0.0  # the windup ended: the pendulum swings down onto the square


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var calm := 0.35 if ViewPrefs.reduced_motion else 1.0
	_clock += delta * calm
	var phase := int(_echo.get("phase", WorldReader.ECHO_NONE))
	_show = move_toward(_show, 1.0 if phase != WorldReader.ECHO_NONE else 0.0, delta * 6.0)
	_draw_glints(phase)
	_draw_path(phase)
	_draw_ghosts(delta)
	_draw_filings(delta)
	_light_t = minf(1.0, _light_t + delta / 0.35)
	_light.light_energy = 1.6 * (1.0 - _light_t)
	_draw_pendulum(delta, calm)


## The recording's glints: one over each point kept, brighter as the echo nears; gone while it runs.
func _draw_glints(phase: int) -> void:
	var mm := _glints.multimesh
	var trail: Array = _echo.get("trail", [])
	var rec := float(_echo.get("recording", 0)) / 1000.0
	if phase != WorldReader.ECHO_NONE or rec <= 0.05:
		mm.visible_instance_count = 0
		return
	var step := 2 if ViewPrefs.effects_density == "low" else 1
	var n := 0
	for k in range(0, trail.size(), step):
		var at := SimPlane.to_3d(trail[k], 0.35 + 0.1 * sin(_clock * 3.0 + k))
		var s := maxf(0.01, rec * (0.5 + 0.5 * float(k + 1) / float(trail.size())))
		mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * s), at))
		n += 1
	mm.visible_instance_count = n


## The path: every point not yet struck as a clock-gear marker, its core filling as its strike nears, and the ribbon
## joining them in order.
func _draw_path(phase: int) -> void:
	var path: Array = _echo.get("path", []) if phase != WorldReader.ECHO_NONE else []
	var now := int(_echo.get("t", 0))
	var gap := maxi(1, int(_echo.get("gap", 15)))
	var radius := float(_echo.get("radius", 0.9))
	var shown := 0
	for m in _markers.size():
		var mark := _markers[m]
		if m >= path.size() or bool(path[m]["struck"]):
			mark.visible = false
			continue
		var p: Dictionary = path[m]
		var left := int(p["at"]) - now
		var heat := clampf(1.0 - float(left) / float(gap * 3), 0.0, 1.0)
		mark.visible = true
		mark.position = SimPlane.to_3d(p["pos"], 0.04 + 0.002 * m)
		mark.scale = Vector3.ONE * radius
		var mat := _marker_mats[m]
		mat.set_shader_parameter("heat", heat)
		mat.set_shader_parameter("alpha", _show * (0.55 + 0.45 * heat))
		mat.set_shader_parameter("clock", _clock + m * 0.37)
		shown += 1
	var segs := 0
	for m in range(1, path.size()):
		if bool(path[m]["struck"]):
			continue
		var a := SimPlane.to_3d(path[m - 1]["pos"], 0.06)
		var b := SimPlane.to_3d(path[m]["pos"], 0.06)
		var d := b - a
		var l := d.length()
		if l < 0.01:
			continue
		var basis := Basis.looking_at(d / l, Vector3.UP).scaled(Vector3(1, 1, l))
		var xf := Transform3D(basis, (a + b) * 0.5)
		_ribbon.multimesh.set_instance_transform(segs, xf)
		_halo.multimesh.set_instance_transform(segs, xf)
		segs += 1
	_ribbon.multimesh.visible_instance_count = segs
	_halo.multimesh.visible_instance_count = segs
	(_ribbon.multimesh.mesh.material as StandardMaterial3D).albedo_color.a = 0.9 * _show
	(_halo.multimesh.mesh.material as StandardMaterial3D).albedo_color.a = 0.28 * _show


## A ghost strike lands at `at`: its afterimage rises, a ring rolls out, gear filings spray, the light flashes.
func _spawn_ghost(k: int, at: Vector3) -> void:
	var slot := k % MAX_POINTS
	_ghosts[slot].position = at
	_ghost_t[slot] = 0.0
	_rings[slot].position = at + Vector3(0, 0.08, 0)
	var n := FILINGS_PER / 2 if ViewPrefs.effects_density == "low" else FILINGS_PER
	for j in n:
		var a := TAU * (float(j) + 0.37 * k) / float(n)
		var v := Vector3(cos(a) * 3.2, 2.6 + 1.2 * fposmod(j * 0.618, 1.0), sin(a) * 3.2)
		_filing_state.append([at + Vector3(0, 0.4, 0), v, 0.0, a])
	while _filing_state.size() > _filings.multimesh.instance_count:
		_filing_state.pop_front()
	_light.position = at + Vector3(0, 1.2, 0)
	_light_t = 0.0


func _draw_ghosts(delta: float) -> void:
	for s in _ghosts.size():
		_ghost_t[s] = minf(1.0, _ghost_t[s] + delta / GHOST_S)
		var t := _ghost_t[s]
		var on := t < 1.0
		_ghosts[s].visible = on
		_rings[s].visible = on and t < RING_S / GHOST_S
		if not on:
			continue
		var fade := 1.0 - t
		var g := _ghosts[s]
		g.scale = Vector3.ONE * (1.0 + 0.25 * t)
		g.position.y = 0.6 * t * t
		_ghost_mats[s].albedo_color = Color(GOLD * 0.6, 0.25 * fade)
		_inner_mats[s].albedo_color.a = 0.3 * fade * fade
		var rt := clampf(t * GHOST_S / RING_S, 0.0, 1.0)
		var r := lerpf(0.4, 2.2, ease(rt, 0.5))
		_rings[s].scale = Vector3(r, 0.5, r)
		_ring_mats[s].albedo_color.a = 0.8 * (1.0 - rt)


func _draw_filings(delta: float) -> void:
	var mm := _filings.multimesh
	var keep: Array = []
	for f: Array in _filing_state:
		f[2] += delta
		if f[2] < FILING_S:
			keep.append(f)
	_filing_state = keep
	for j in _filing_state.size():
		var f: Array = _filing_state[j]
		var t: float = f[2]
		var pos: Vector3 = f[0] + (f[1] as Vector3) * t + Vector3(0, -6.0 * t * t, 0)
		var spin := Basis(Vector3.UP, float(f[3]) + t * 14.0)
		var s := maxf(0.01, 1.0 - t / FILING_S)
		mm.set_instance_transform(j, Transform3D(spin.scaled(Vector3.ONE * s), pos))
	mm.visible_instance_count = _filing_state.size()


## The pendulum over the Verdict's square: it sways while the square tracks, is hauled back to its apex through the
## lock, then swings down onto the square on the strike (a shockwave rolls out) and fades.
func _draw_pendulum(delta: float, calm: float) -> void:
	var tracking := not _verdict.is_empty()
	var locked := tracking and bool(_verdict.get("locked", false))
	var apex := deg_to_rad(80.0)
	var target := sin(_clock * 4.0) * 0.25 * calm
	if locked:
		target = apex
	if tracking:
		_swing = lerpf(_swing, target, 1.0 - exp(-8.0 * delta))
	else:
		_drop_t = minf(1.0, _drop_t + delta / 0.6)
		_swing = apex * (1.0 - clampf(_drop_t / 0.2, 0.0, 1.0))
	var shown := tracking or _drop_t < 1.0
	_pendulum.visible = shown
	if not shown:
		_shock.visible = false
		return
	_pendulum.position = _verdict_at + Vector3(0, PIVOT_H, 0)
	_pendulum.rotation = Vector3(0, 0, _swing)
	var fade := 1.0 if tracking else 1.0 - clampf((_drop_t - 0.25) / 0.75, 0.0, 1.0)
	_pendulum_mat.albedo_color.a = fade
	_pendulum_mat.emission_energy_multiplier = 0.4 + (1.6 if locked else 0.0)
	_seam_mat.albedo_color.a = (0.9 if locked else 0.3) * fade
	var hit := not tracking and _drop_t >= 0.2
	_shock.visible = hit and _drop_t < 0.8
	if _shock.visible:
		var st := (_drop_t - 0.2) / 0.6
		var r := lerpf(0.8, 3.4, ease(st, 0.5))
		_shock.position = _verdict_at + Vector3(0, 0.1, 0)
		_shock.scale = Vector3(r, 0.5, r)
		_shock_mat.albedo_color.a = 0.9 * (1.0 - st)


## Tests: the markers showing, the ghosts rising, the ribbon's segments, the filings flying, the pendulum's swing.
func markers_shown() -> int:
	return _markers.filter(func(m: MeshInstance3D) -> bool: return m.visible).size()


func ghosts_shown() -> int:
	return _ghosts.filter(func(g: Node3D) -> bool: return g.visible).size()


func ribbon_segments() -> int:
	return _ribbon.multimesh.visible_instance_count


func filings_shown() -> int:
	return _filings.multimesh.visible_instance_count


func glints_shown() -> int:
	return _glints.multimesh.visible_instance_count


func pendulum_shown() -> bool:
	return _pendulum.visible


func pendulum_swing() -> float:
	return _swing
