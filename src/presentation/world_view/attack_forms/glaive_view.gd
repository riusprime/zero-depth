class_name GlaiveView
extends Node3D
## v0.9.0 AF2 (owner Q7; ATTACK_FORMS.md F7): the Glaive's look. Each disc in flight (WorldReader.projectile_is_disc)
## is a flat spinning blade-disc lying on the core plane: a bright rim, three curved blades turning round a hot hub,
## in the element's colours (BeamLooks: default energy, Fire, Lightning, Frost, Venom, Bleed), with two fading
## afterimages where it was the last syncs (its whirl). On its way back (WorldReader.disc_coming_back) it spins the
## other way and burns brighter, so the return reads at a glance.
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

const DISC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
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

## What the last sync showed (tests read them): the discs drawn, those coming back, the look.
var discs := 0
var returning := 0
var look := &"default"

var _nodes: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _ghosts: Array[MeshInstance3D] = []
var _ghost_mats: Array[ShaderMaterial] = []
## Each disc drawn: [pos (Vector2), coming back (bool), its past positions (Array of Vector2, nearest first)].
var _shown: Array = []
## Past positions by projectile id (the afterimages).
var _trail := {}
var _spin := 0.0


func _init() -> void:
	name = "GlaiveView"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
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


## Each tick: the discs in flight, their afterimages, the spin.
func sync(reader: WorldReader) -> void:
	_spin = float(reader.tick()) * SPIN
	var spec := reader.attack_spec(WorldReader.ATTACK_BOLT)
	look = BeamLooks.look_of(PackedStringArray(spec.get("elements", [])))
	_shown.clear()
	var trail := {}
	returning = 0
	for i in reader.projectile_count():
		if reader.projectile_team(i) != 0 or not reader.projectile_is_disc(i):
			continue
		var id := reader.projectile_id(i)
		var p := reader.projectile_pos(i)
		var past: Array = _trail.get(id, [])
		trail[id] = ([p] + past).slice(0, GHOSTS + 1)
		if _shown.size() >= DISCS_MAX:
			continue
		var back := reader.disc_coming_back(i)
		returning += 1 if back else 0
		_shown.append([p, back, past.slice(0, GHOSTS)])
	_trail = trail
	discs = _shown.size()
	var core := BeamLooks.core(look)
	var edge := BeamLooks.edge(look)
	for k in DISCS_MAX:
		var on := k < discs
		_nodes[k].visible = on
		for g in GHOSTS:
			_ghosts[k * GHOSTS + g].visible = on and g < (_shown[k][2] as Array).size()
		if not on:
			continue
		var back: bool = _shown[k][1]
		_mats[k].set_shader_parameter(&"core", core)
		_mats[k].set_shader_parameter(&"edge", edge)
		_mats[k].set_shader_parameter(&"hot", 1.0 if back else 0.0)
		for g in GHOSTS:
			var m := _ghost_mats[k * GHOSTS + g]
			m.set_shader_parameter(&"core", core)
			m.set_shader_parameter(&"edge", edge)
			m.set_shader_parameter(&"fade", GHOST_FADE[g])
	_place()


func _process(delta: float) -> void:
	if discs > 0:
		_spin += delta * 60.0 * SPIN
		_place()


func _place() -> void:
	for k in discs:
		var back: bool = _shown[k][1]
		var s := -_spin if back else _spin
		_nodes[k].transform = _at(_shown[k][0], 1.0)
		_mats[k].set_shader_parameter(&"spin", s)
		var past: Array = _shown[k][2]
		for g in mini(GHOSTS, past.size()):
			_ghosts[k * GHOSTS + g].transform = _at(past[g], 0.92 - 0.06 * g)
			_ghost_mats[k * GHOSTS + g].set_shader_parameter(&"spin", s - 0.4 * (g + 1))


static func _at(p: Vector2, scale: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * SIZE * scale), SimPlane.to_3d(p, HEIGHT))
