class_name WispsView
extends Node3D
## v0.9.0 AF3 (owner Q7; ATTACK_FORMS.md F10 "Orbs circle you and fire on their own at the nearest enemy"): the Wisps'
## look. Each wisp (WorldReader.wisps: where the sim has it, its wait to the next shot) is a small glowing orb at body
## height circling the hero, bobbing a little, in the element's colours (BeamLooks: default energy, Fire, Lightning,
## Frost, Venom, Bleed). It brightens and swells as its shot comes due and flares the tick it fires, so the player
## can read which wisp is about to shoot; its orb then flies as the Gun's (a smaller one; the pulses draw it).
## v0.9.0 VX (VFX_AUDIT.md V31, with the element accents): the first element's centre and the second's edge (V2); each
## wisp carries its element's accent (HeroFx.accent, trailing along its orbit) and flashes as it fires (a hot core, a
## glow, a ring and sparks, FIRE_TICKS, no light), its shot then a plain Orb with its own accent (V6).
## v0.10.5 W3-S19 (owner playtest 2026-11-05: "wisps orbiting VFX is very bad too it also leaves like a trail of
## replicas of the attack when you move"): each wisp is a small bright orb (ORB_M across, the element's colours, the
## Gun's moon blue with none) with a short soft trail along its orbit (TRAIL_N fading ghosts, TRAIL_STEP ticks of its
## spin apart, about 0.13 s), placed from where the hero is each frame, so nothing lingers. The VX2 pack orb and its
## firing flare are gone: the pack's billboard shader ignores the node's scale (each drew about 2 m across), and the
## flare (a timed pack effect, about 1 s) stayed where the wisp fired, a disc left behind per shot while the hero
## walked. The firing flash is the effects layer's again (FIRE_TICKS, on the wisp).
## Presentation only (EI-07): the sim decides where and when; the bob is the frame's clock.

## v0.9.5 FC9: Halo with Twin draws seven; Ring's lightning rings (the Void's and the Glaive's look, the same
## ARC_FRONT).
const WISPS_MAX := 8
const ARCS_MAX := 12
const ARC_U := 0.7
const ARC_FRONT := 0.754
const HEIGHT := SimPlane.CORE_HEIGHT + 0.15
## W3-S19: the orb's quad (its soft halo fades well inside it; the bright orb reads about half of it).
const ORB_M := 0.46
const BOB_M := 0.06
const FIRE_TICKS := 6.0
## W3-S19: the trail: ghosts behind each wisp along its orbit, TRAIL_STEP ticks of its spin apart, each smaller and
## fainter (the last TRAIL_N * TRAIL_STEP ticks of the orbit, drawn round where the hero is now).
const TRAIL_N := 4
const TRAIL_STEP := 2.0
const TRAIL_FADE := 0.55
## A turn above this (radians a tick) is a jump (a new wisp, a resize), not an orbit: no trail that tick.
const SPIN_MAX := 0.5

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
instance uniform float charge = 0.0;
instance uniform float fade = 1.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float halo = exp(-r * r * 7.0) * (0.6 + 0.4 * clamp(charge, 0.0, 1.0));
	float hot = exp(-r * r * 26.0);
	float flick = 0.88 + 0.12 * sin(TIME * 13.0 + d.x * 3.0);
	ALBEDO = mix(edge.rgb * 1.5, mix(core.rgb, vec3(1.0), 0.45) * 1.8, clamp(hot * 1.6, 0.0, 1.0));
	ALPHA = clamp(halo * flick * 1.2 + hot * 1.1, 0.0, 1.0) * fade;
}
"""

static var _shader: Shader = null

## What the last sync showed (tests read them): the wisps drawn, their places (sim plane), the look.
var wisps := 0
var arcs := 0
var places: Array[Vector2] = []
var look := &"default"
## W3-S19: the trail ghosts shown by the last placing (tests).
var trail_shown := 0

var _arcs: Array[MeshInstance3D] = []
var _orbs: Array[MeshInstance3D] = []
## W3-S19: TRAIL_N ghosts per wisp, wisp k's at k * TRAIL_N + j. One material for every orb and ghost: the colours
## are its uniforms, the charge and the fade each instance's.
var _trail: Array[MeshInstance3D] = []
var _mat: ShaderMaterial
var _charge: Array[float] = []
var _time := 0.0
var _form := FormLook.new()
## v0.9.0 VX: each wisp's last firing tick (-1: none yet), its angle round the hero, and the sim tick.
var _fired: PackedFloat32Array = PackedFloat32Array()
var _angle: PackedFloat32Array = PackedFloat32Array()
## W3-S19: the hero's place this tick; each wisp's angle and distance round it (the sim plane), and its turn since
## the tick before (radians).
var _hero := Vector2.ZERO
var _around: PackedFloat32Array = PackedFloat32Array()
var _radius: PackedFloat32Array = PackedFloat32Array()
var _spin: PackedFloat32Array = PackedFloat32Array()
var _tick := 0.0


func _init() -> void:
	name = "WispsView"
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GLOW_SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	for k in WISPS_MAX:
		_orbs.append(_glow(quad))
		_charge.append(0.0)
		_fired.append(-100.0)
		_angle.append(0.0)
		_around.append(0.0)
		_radius.append(0.0)
		_spin.append(0.0)
		for j in TRAIL_N:
			var g := _glow(quad)
			g.set_instance_shader_parameter(
				&"fade", TRAIL_FADE * (1.0 - float(j) / float(TRAIL_N + 1))
			)
			_trail.append(g)
	_make_arcs()


func _glow(quad: QuadMesh) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = quad
	n.material_override = _mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


## v0.9.5 FC9: the pool of lightning rings (one shared material, the Glaive's ring look).
func _make_arcs() -> void:
	var flat := PlaneMesh.new()
	flat.size = Vector2(2.0, 2.0)
	var shader := Shader.new()
	shader.code = BombView.RING_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"has_tex", 0.0)
	m.set_shader_parameter(&"u", ARC_U)
	m.set_shader_parameter(&"core", AttackFormLooks.ground_safe(BeamLooks.core(&"lightning")))
	m.set_shader_parameter(&"edge", AttackFormLooks.ground_safe(BeamLooks.edge(&"lightning")))
	for k in ARCS_MAX:
		var n := MeshInstance3D.new()
		n.mesh = flat
		n.material_override = m
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false
		add_child(n)
		_arcs.append(n)


## v0.9.5 FC9: the Ring card's lightning rings where a wisp's shot struck (grown as the Void's are).
func _place_arcs(reader: WorldReader) -> void:
	arcs = 0
	if not reader.player_dead():
		for row in reader.wisp_rings():
			if arcs >= ARCS_MAX:
				break
			var g := (
				clampf(float(row["age"]) / float(row["span"]), 0.0, 1.0)
				* float(row["r"])
				/ ARC_FRONT
			)
			var arc := _arcs[arcs]
			arc.visible = g > 0.01
			arc.transform = Transform3D(
				Basis.from_scale(Vector3(g, 1.0, g)), SimPlane.to_3d(row["pos"], 0.1)
			)
			arcs += 1
	for k in range(arcs, ARCS_MAX):
		_arcs[k].visible = false


## Each tick: the wisps round the hero.
func sync(reader: WorldReader) -> void:
	_tick = float(reader.tick())
	var changed := _form.refresh(reader)
	look = _form.look
	if changed:
		_mat.set_shader_parameter(&"core", _form.core)
		_mat.set_shader_parameter(&"edge", _form.edge)
	var ws: Array[Dictionary] = []  # dead: none (an untyped [] in a ternary fails the typed assignment)
	if not reader.player_dead():
		ws = reader.wisps()
	var was := wisps
	wisps = mini(ws.size(), WISPS_MAX)
	_hero = reader.player_pos()
	places.clear()
	for k in wisps:
		var wd: Dictionary = ws[k]
		var period := maxf(1.0, float(wd["period"]))
		var wait := float(wd["wait"])
		# Due: 0 → 1 over the last third of the wait; the firing tick flares (1.6).
		_charge[k] = 1.6 if wait <= 0.0 else clampf(1.0 - wait / (period / 3.0), 0.0, 1.0)
		if wait <= 0.0:
			_fired[k] = _tick
		_angle[k] = TAU * float(int(wd.get("angle", 0))) / 4096.0
		var off: Vector2 = wd["pos"] - _hero
		var around := off.angle()
		var orbiting := k < was and absf(_radius[k] - off.length()) < 0.25
		_spin[k] = wrapf(around - _around[k], -PI, PI) if orbiting else 0.0
		_around[k] = around
		_radius[k] = off.length()
		places.append(wd["pos"])
	_place()
	_place_arcs(reader)


func _process(delta: float) -> void:
	_time += delta
	if wisps > 0:
		_place()


## The orbs and their trails, round the hero's place of the last sync (the trail is never left in the world).
func _place() -> void:
	trail_shown = 0
	for k in WISPS_MAX:
		var on := k < wisps
		_orbs[k].visible = on
		var bob := BOB_M * sin(_time * 4.0 + k * 2.1) if on else 0.0
		if on:
			var s := ORB_M * (1.0 + 0.3 * _charge[k])
			var at := SimPlane.to_3d(places[k], HEIGHT + bob)
			_orbs[k].transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), at)
			_orbs[k].set_instance_shader_parameter(&"charge", _charge[k])
		var trail := on and absf(_spin[k]) > 0.001 and absf(_spin[k]) < SPIN_MAX
		for j in TRAIL_N:
			var g := _trail[k * TRAIL_N + j]
			g.visible = trail
			if not trail:
				continue
			var a := _around[k] - _spin[k] * TRAIL_STEP * float(j + 1)
			var p := _hero + Vector2.from_angle(a) * _radius[k]
			var s := ORB_M * (0.78 - 0.13 * float(j))
			g.transform = Transform3D(
				Basis.IDENTITY.scaled(Vector3.ONE * s), SimPlane.to_3d(p, HEIGHT + bob)
			)
			trail_shown += 1


## The effects layer's drawer (WorldViewRoot appends it): each wisp's element accent trailing along its orbit, and its
## firing flash.
func draw_fx(layer: VfxCore) -> void:
	var now := layer.now()
	for k in wisps:
		var at := SimPlane.to_3d(places[k], HEIGHT)
		if _form.kind != &"":
			var a := _angle[k]
			var tangent := SimPlane.to_3d(Vector2(-sin(a), cos(a)), 0.0)
			HeroFx.accent(layer, _form.kind, _form.element, at, tangent, 6007 + k * 13, 0.7)
		var u := (now - _fired[k]) / FIRE_TICKS
		if u >= 0.0 and u < 1.0:
			HeroFx.flash(layer, at, _form.core, _form.edge, u, 0.7, 6101 + k * 7, 3, false)
