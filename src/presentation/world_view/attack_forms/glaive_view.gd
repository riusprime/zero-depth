class_name GlaiveView
extends Node3D
## v0.9.0 AF2 (owner Q7; ATTACK_FORMS.md F7): the Glaive's look. Each disc in flight (WorldReader.projectile_is_disc)
## is a flat spinning blade-disc lying on the core plane: a bright rim, three curved blades turning round a hot hub,
## in the element's colours (BeamLooks: default energy, Fire, Lightning, Frost, Venom, Bleed), with two fading
## afterimages where it was the last syncs (its whirl). On its way back (WorldReader.disc_coming_back) it spins the
## other way and burns brighter, so the return reads at a glance.
## v0.9.0 VX (VFX_AUDIT.md): V2 the first element's centre and the second's edge; V25 the rim sheds its element's
## accent;
## V26 a small catch flash at the hero's hand; V47 Effects density Low drops the afterimages; V48 fixed buffers.
## Presentation only (EI-07): it reads the reader, never writes; the spin is cosmetic (sim ticks, and frame time
## between them), never an outcome.

const DISCS_MAX := 12
const GHOSTS := 2
const HEIGHT := SimPlane.CORE_HEIGHT
## The disc's drawn diameter (m) and its spin (radians a tick).
const SIZE := 1.0
const SPIN := 0.55
## The afterimages' strength, nearest first.
const GHOST_FADE: Array[float] = [0.45, 0.2]
## v0.9.0 VX V26: a disc coming back that leaves within CATCH_M of the hero was caught: a flash at the hand for
## CATCH_TICKS (CATCHES_MAX at once).
const CATCH_M := 1.6
const CATCH_TICKS := 4.0
const CATCHES_MAX := 4

const DISC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float spin = 0.0;
uniform float fade = 1.0;
uniform float hot = 0.0;
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float a = atan(d.y, d.x) + spin;
	float rim = smoothstep(0.09, 0.0, abs(r - 0.78));
	float blade = pow(max(0.0, sin(a * 3.0 + r * 5.0)), 5.0);
	blade *= smoothstep(0.98, 0.78, r) * smoothstep(0.18, 0.4, r);
	float hub = smoothstep(0.28, 0.08, r);
	float glow = exp(-r * r * 2.5) * 0.35 * smoothstep(1.0, 0.8, r);
	vec3 c = edge.rgb * (rim + blade + glow) + core.rgb * (hub * 1.6 + blade * 0.5 + rim * 0.3);
	ALBEDO = c * (1.4 + hot * 0.8) * fade;
}
"""

static var _shader: Shader

## What the last sync showed (tests read them): the discs drawn, those coming back, the look; v0.9.0 VX: the
## afterimages drawn (none at Low, V47), the catch flashes playing and caught since the view began (V26).
var discs := 0
var returning := 0
var look := &"default"
var ghosts := 0
var catches := 0
var caught := 0

var _nodes: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _ghosts: Array[MeshInstance3D] = []
var _ghost_mats: Array[ShaderMaterial] = []
## v0.9.0 VX V48: each disc drawn in fixed buffers (no Dictionary or slice a disc a sync): its place, coming back, its
## afterimages' count and places (GHOSTS a disc), its id.
var _pos: Array[Vector2] = []
var _back: Array[bool] = []
var _ghost_n: PackedInt32Array = PackedInt32Array()
var _ghost_pos: Array[Vector2] = []
var _ids: PackedInt32Array = PackedInt32Array()
## Past positions by projectile id (the afterimages, nearest first), updated in place; whether each was coming back.
var _trail := {}
var _was_back := {}
var _seen := {}
## V26: the catches playing ([pos (Vector2), tick (float)]).
var _catches: Array = []
var _spin := 0.0
var _tick := 0.0
var _hero := Vector2.ZERO
var _form := FormLook.new()


func _init() -> void:
	name = "GlaiveView"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_ghost_pos.resize(DISCS_MAX * GHOSTS)
	for k in DISCS_MAX:
		var n := _node(plane)
		_nodes.append(n)
		_mats.append(n.material_override as ShaderMaterial)
		for g in GHOSTS:
			var h := _node(plane)
			_ghosts.append(h)
			_ghost_mats.append(h.material_override as ShaderMaterial)


func _node(mesh: Mesh) -> MeshInstance3D:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = DISC_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


## Each tick: the discs in flight, their afterimages, the spin; a disc that came back to the hand flashes (V26).
func sync(reader: WorldReader) -> void:
	_tick = float(reader.tick())
	_spin = _tick * SPIN
	_hero = reader.player_pos()
	var changed := _form.refresh(reader)
	look = _form.look
	var low := ViewPrefs.effects_density == "low"  # V47: Low drops the afterimages
	_pos.clear()
	_back.clear()
	_ghost_n.clear()
	_ids.clear()
	_seen.clear()
	returning = 0
	ghosts = 0
	for i in reader.projectile_count():
		if reader.projectile_team(i) != 0 or not reader.projectile_is_disc(i):
			continue
		var id := reader.projectile_id(i)
		var p := reader.projectile_pos(i)
		_seen[id] = true
		var past: Array = _trail.get(id, [])
		if past.is_empty():
			_trail[id] = past
		var back := reader.disc_coming_back(i)
		_was_back[id] = back
		if _pos.size() < DISCS_MAX:
			var k := _pos.size()
			_pos.append(p)
			_back.append(back)
			_ids.append(id)
			returning += 1 if back else 0
			var gn := 0 if low else mini(GHOSTS, past.size())
			_ghost_n.append(gn)
			for g in gn:
				_ghost_pos[k * GHOSTS + g] = past[g]
			ghosts += gn
		past.push_front(p)
		if past.size() > GHOSTS:
			past.pop_back()
	_drop_gone()
	discs = _pos.size()
	for k in DISCS_MAX:
		var on := k < discs
		_nodes[k].visible = on
		for g in GHOSTS:
			_ghosts[k * GHOSTS + g].visible = on and g < _ghost_n[k]
		if changed:
			_colour(k)
		if on:
			_mats[k].set_shader_parameter(&"hot", 1.0 if _back[k] else 0.0)
	_place()


func _colour(k: int) -> void:
	_mats[k].set_shader_parameter(&"core", _form.core)
	_mats[k].set_shader_parameter(&"edge", _form.edge)
	for g in GHOSTS:
		var m := _ghost_mats[k * GHOSTS + g]
		m.set_shader_parameter(&"core", _form.core)
		m.set_shader_parameter(&"edge", _form.edge)
		m.set_shader_parameter(&"fade", GHOST_FADE[g])


## The discs that left since the last sync: one coming back that left within CATCH_M of the hero was caught (V26).
func _drop_gone() -> void:
	for id: int in _trail.keys():
		if _seen.has(id):
			continue
		var past: Array = _trail[id]
		if bool(_was_back.get(id, false)) and not past.is_empty():
			if (past[0] as Vector2).distance_to(_hero) < CATCH_M:
				caught += 1
				_catches.append([_hero, _tick])
		_trail.erase(id)
		_was_back.erase(id)
	while _catches.size() > CATCHES_MAX:
		_catches.pop_front()
	while not _catches.is_empty() and _tick - float(_catches[0][1]) >= CATCH_TICKS:
		_catches.pop_front()
	catches = _catches.size()


func _process(delta: float) -> void:
	if discs > 0:
		_spin += delta * 60.0 * SPIN
		_place()


func _place() -> void:
	for k in discs:
		var s := -_spin if _back[k] else _spin
		_nodes[k].transform = _at(_pos[k], 1.0)
		_mats[k].set_shader_parameter(&"spin", s)
		for g in _ghost_n[k]:
			_ghosts[k * GHOSTS + g].transform = _at(_ghost_pos[k * GHOSTS + g], 0.92 - 0.06 * g)
			_ghost_mats[k * GHOSTS + g].set_shader_parameter(&"spin", s - 0.4 * (g + 1))


static func _at(p: Vector2, scale: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * SIZE * scale), SimPlane.to_3d(p, HEIGHT))


## The effects layer's drawer (WorldViewRoot appends it): V25 the rim sheds its element's accent (1-2 pieces a disc a
## frame: embers, an arc between two blades, frost shards and glints, drips), V26 the catch flash at the hero's hand.
func draw_fx(layer: VfxCore) -> void:
	var now := layer.now()
	if _form.kind != &"":
		for k in discs:
			var a := _spin * (-1.0 if _back[k] else 1.0) + float(_ids[k])
			var rim := Vector3(cos(a), 0.0, sin(a)) * SIZE * 0.42
			var at := SimPlane.to_3d(_pos[k], HEIGHT) + rim
			var tangent := Vector3(-sin(a), 0.0, cos(a))
			HeroFx.accent(layer, _form.kind, _form.element, at, tangent, _ids[k] * 11 + 3, 0.8)
	for k in _catches.size():
		var u := clampf((now - float(_catches[k][1])) / CATCH_TICKS, 0.0, 1.0)
		var hand := SimPlane.to_3d(_catches[k][0], HEIGHT)
		HeroFx.flash(layer, hand, _form.core, _form.edge, u, 0.9, 5501 + k * 7, 4, true)
