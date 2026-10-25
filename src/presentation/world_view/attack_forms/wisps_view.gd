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
## Presentation only (EI-07): the sim decides where and when; the bob is the frame's clock.

const WISPS_MAX := 6
const HEIGHT := SimPlane.CORE_HEIGHT + 0.15
const SIZE := 0.75
const BOB_M := 0.06
const FIRE_TICKS := 6.0

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float charge = 0.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float halo = exp(-r * r * 5.0) * (0.55 + 0.45 * charge);
	float hot = exp(-r * r * 30.0);
	float flick = 0.85 + 0.15 * sin(TIME * 13.0 + d.x * 3.0);
	ALBEDO = mix(edge.rgb * 1.4, core.rgb * 1.6, clamp(hot * 1.5, 0.0, 1.0));
	ALPHA = clamp(halo * flick * 1.3 + hot, 0.0, 1.0);
}
"""

static var _shader: Shader = null

## What the last sync showed (tests read them): the wisps drawn, their places (sim plane), the look.
var wisps := 0
var places: Array[Vector2] = []
var look := &"default"

var _orbs: Array[MeshInstance3D] = []
var _mat: Array[ShaderMaterial] = []
var _charge: Array[float] = []
var _time := 0.0
var _form := FormLook.new()
## v0.9.0 VX: each wisp's last firing tick (-1: none yet), its angle round the hero, and the sim tick.
var _fired: PackedFloat32Array = PackedFloat32Array()
var _angle: PackedFloat32Array = PackedFloat32Array()
var _tick := 0.0


func _init() -> void:
	name = "WispsView"
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GLOW_SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for k in WISPS_MAX:
		var m := ShaderMaterial.new()
		m.shader = _shader
		var n := MeshInstance3D.new()
		n.mesh = quad
		n.material_override = m
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false
		add_child(n)
		_orbs.append(n)
		_mat.append(m)
		_charge.append(0.0)
		_fired.append(-100.0)
		_angle.append(0.0)


## Each tick: the wisps round the hero.
func sync(reader: WorldReader) -> void:
	_tick = float(reader.tick())
	var changed := _form.refresh(reader)
	look = _form.look
	if changed:
		for m in _mat:
			m.set_shader_parameter(&"core", _form.core)
			m.set_shader_parameter(&"edge", _form.edge)
	var ws: Array[Dictionary] = []  # dead: none (an untyped [] in a ternary fails the typed assignment)
	if not reader.player_dead():
		ws = reader.wisps()
	wisps = mini(ws.size(), WISPS_MAX)
	places.clear()
	for k in WISPS_MAX:
		_orbs[k].visible = k < wisps
		if k >= wisps:
			continue
		var wd: Dictionary = ws[k]
		var period := maxf(1.0, float(wd["period"]))
		var wait := float(wd["wait"])
		# Due: 0 → 1 over the last third of the wait; the firing tick flares (1.6).
		_charge[k] = 1.6 if wait <= 0.0 else clampf(1.0 - wait / (period / 3.0), 0.0, 1.0)
		if wait <= 0.0:
			_fired[k] = _tick
		_angle[k] = TAU * float(int(wd.get("angle", 0))) / 4096.0
		places.append(wd["pos"])
	_place()


func _process(delta: float) -> void:
	_time += delta
	if wisps > 0:
		_place()


func _place() -> void:
	for k in wisps:
		var bob := BOB_M * sin(_time * 4.0 + k * 2.1)
		var s := SIZE * (1.0 + 0.35 * _charge[k])
		var at := SimPlane.to_3d(places[k], HEIGHT + bob)
		_orbs[k].transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), at)
		_mat[k].set_shader_parameter(&"charge", _charge[k])


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
