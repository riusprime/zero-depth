class_name LanceView
extends Node3D
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F5) and AF1b (owner: "it creates a circle in front of the player that circles
## like a charging energy and then shoots a bit … like a lowkey haduoken"): the Lance's look.
## - While it charges (WorldReader.lance_orb: where the ball a release now would launch sits, and its radius), a
##   swirling circle of energy in front of the hero: arcs turning both ways and motes spiralling inward, in the
##   element's colours (BeamLooks: default energy, Fire, Lightning, Frost, Venom, Bleed). It grows with the ball and
##   brightens with the charge, spins faster as it fills, and pulses once full.
## - Each release (a LANCE event: the muzzle, the ball's radius, the aim, the charge) is a burst at the muzzle (a ring
##   thrown outward and a hot flash, fading in BURST_TICKS, bigger for a bigger ball), sparks and a light on the
##   effects layer, and a short camera kick back along the aim (IsoRig.kick, scaled by the charge; none with shake off).
## - The ball in flight is the orb's own look (AttackFormView's bolt layer, scaled by the projectile's radius).
## Presentation only (EI-07): it reads the reader, never writes; a burst's life is sim ticks.

const BURSTS_MAX := 6
const BURST_TICKS := 12.0
const HEIGHT := SimPlane.CORE_HEIGHT
## The circle's radius: this many of the ball's radii plus a margin (m), so the gathering energy reads round the ball.
const CIRCLE_RADII := 1.8
const CIRCLE_PAD_M := 0.1
## A burst's radius in the ball's radii, and the camera kick (m) at full charge.
const BURST_RADII := 3.5
const KICK_M := 0.12

const SWIRL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float charge = 0.0;
uniform float full = 0.0;
uniform float energy = 1.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float a = atan(d.y, d.x);
	float spin = TIME * (3.0 + 5.0 * charge);
	float ring = exp(-pow((r - 0.74) * 9.0, 2.0));
	float arcs = pow(max(0.0, cos(a * 3.0 - spin)), 6.0) * ring;
	float inner = pow(max(0.0, cos(a * 2.0 + spin * 1.6)), 8.0) * exp(-pow((r - 0.46) * 11.0, 2.0));
	float motes = 0.0;
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float ph = fract(TIME * (0.9 + 0.7 * charge) + fi * 0.37);
		float rr = mix(0.98, 0.12, ph);
		float ang = fi * 0.785 + ph * 2.2 + TIME * 0.6;
		vec2 p = rr * vec2(cos(ang), sin(ang));
		motes += exp(-dot(d - p, d - p) * 140.0) * (0.3 + ph);
	}
	float hot = exp(-r * r * mix(70.0, 22.0, charge)) * (0.4 + 0.6 * charge);
	float pulse = mix(1.0, 0.7 + 0.3 * sin(TIME * 16.0), full);
	float mask = smoothstep(1.0, 0.88, r);
	vec3 col = edge.rgb * (arcs * 2.2 + inner * 1.5 + motes * 1.8 + ring * 0.35 * charge) + core.rgb * hot;
	ALBEDO = col * energy * pulse * mask;
}
"""
const BURST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float u = 0.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float fade = 1.0 - u;
	float ring = exp(-pow((r - mix(0.25, 0.95, sqrt(u))) * 10.0, 2.0)) * fade;
	float flash = exp(-r * r * 7.0) * fade * fade;
	ALBEDO = (edge.rgb * ring * 1.6 + core.rgb * flash * 2.2) * smoothstep(1.0, 0.9, r);
}
"""

static var _shaders := {}

## What the last sync showed (tests read them): the circle (shown or not), the charge, the circle's diameter (m), the
## live bursts and their look, the last release's charge (‰) and ball radius (m).
var circle := false
var charge := 0.0
var circle_size := 0.0
var bursts := 0
var look := &"default"
var last_burst_charge := 0
var last_burst_radius := 0.0
## The camera to kick on a release (WorldViewRoot sets it; none in tests).
var rig: IsoRig

var _circle: MeshInstance3D
var _circle_mat: ShaderMaterial
var _burst_nodes: Array[MeshInstance3D] = []
var _burst_mat: Array[ShaderMaterial] = []
## Each live burst: [pos (Vector2), tick (float), look, radius (m)].
var _live: Array = []
var _tick := 0.0
var _last_seq := 0
var _primed := false


func _init() -> void:
	name = "LanceView"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_circle = _quad(quad, SWIRL_SHADER)
	_circle_mat = _circle.material_override as ShaderMaterial
	for k in BURSTS_MAX:
		var n := _quad(quad, BURST_SHADER)
		_burst_nodes.append(n)
		_burst_mat.append(n.material_override as ShaderMaterial)


func _quad(mesh: Mesh, code: String) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = _shader(code)
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## Each tick: the charging circle, and the releases since the last sync.
func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # attaching mid-run draws nothing that already happened
	var els: Array = reader.attack_spec(WorldReader.ATTACK_BOLT).get("elements", [])
	look = BeamLooks.look_of(PackedStringArray(els))
	var orb := reader.lance_orb() if not reader.player_dead() else {}
	charge = reader.lance_charge() if not orb.is_empty() else 0.0
	circle = not orb.is_empty()
	_circle.visible = circle
	if circle:
		circle_size = 2.0 * (float(orb["radius"]) * CIRCLE_RADII + CIRCLE_PAD_M)
		_circle.position = SimPlane.to_3d(orb["pos"], HEIGHT)
		_circle.scale = Vector3.ONE * circle_size
		_circle_mat.set_shader_parameter(&"core", BeamLooks.core(look))
		_circle_mat.set_shader_parameter(&"edge", BeamLooks.edge(look))
		_circle_mat.set_shader_parameter(&"charge", charge)
		_circle_mat.set_shader_parameter(&"full", 1.0 if charge >= 1.0 else 0.0)
		_circle_mat.set_shader_parameter(&"energy", 0.7 + 1.1 * charge)
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.LANCE:
			continue
		var spec := reader.attack_spec_at(String(e.effect_id))
		var l := BeamLooks.look_of(PackedStringArray(spec.get("elements", [])))
		var radius := e.amount / 1000.0
		_live.append([e.pos, float(e.tick), l, radius])
		last_burst_charge = e.proc_pct
		last_burst_radius = radius
		if rig != null:
			var hold_pm := maxi(1001, int(spec.get("hold_permille", 11600)))
			var u := clampf(float(e.proc_pct - 1000) / float(hold_pm - 1000), 0.0, 1.0)
			var back := -Kin.dir(e.amount_applied & 4095)
			rig.kick(Vector3(back.x, 0.0, -back.y), KICK_M * u)
	while _live.size() > BURSTS_MAX:
		_live.pop_front()
	var keep: Array = []
	for f: Array in _live:
		if _tick - float(f[1]) < BURST_TICKS:
			keep.append(f)
	_live = keep
	bursts = _live.size()
	for k in BURSTS_MAX:
		var n := _burst_nodes[k]
		n.visible = k < bursts
		if k >= bursts:
			continue
		var f: Array = _live[k]
		var u := clampf((_tick - float(f[1])) / BURST_TICKS, 0.0, 1.0)
		n.position = SimPlane.to_3d(f[0], HEIGHT)
		n.scale = Vector3.ONE * (2.0 * float(f[3]) * BURST_RADII)
		var m := _burst_mat[k]
		m.set_shader_parameter(&"core", BeamLooks.core(f[2]))
		m.set_shader_parameter(&"edge", BeamLooks.edge(f[2]))
		m.set_shader_parameter(&"u", u)


## VfxLayer's drawer (WorldViewRoot appends it): each young burst's sparks thrown outward and a light; the full
## charge's circle lights the hero's hand.
func draw_fx(layer: VfxCore) -> void:
	var now := layer.now()
	for k in _live.size():
		var f: Array = _live[k]
		var u := clampf((now - float(f[1])) / BURST_TICKS, 0.0, 1.0)
		if u >= 1.0:
			continue
		var at := SimPlane.to_3d(f[0], HEIGHT)
		var col := BeamLooks.edge(f[2])
		var reach := float(f[3]) * BURST_RADII * (0.4 + u)
		for j in 6:
			var a := TAU * (float(j) / 6.0) + float(k) * 0.7
			var p := at + Vector3(cos(a) * reach, 0.15 * u, sin(a) * reach)
			var c := Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 1.0 - u)
			layer.sprite(&"spark", p, 0.28 * (1.0 - u), c, j % 4, 0.0)
		layer.light_merged(at + Vector3(0, 0.4, 0), col, 2.2 * (1.0 - u), 3.0, 1.5)
	if circle and charge > 0.0:
		layer.light_merged(
			_circle.position + Vector3(0, 0.3, 0),
			BeamLooks.edge(look),
			0.4 + 0.9 * charge,
			2.5,
			1.2
		)
