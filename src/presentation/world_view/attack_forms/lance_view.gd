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
##   effects layer. v0.9.0 VX V17 (owner "Drop it"): no camera kick; the hero's own step back carries the recoil.
## - The ball in flight is the orb's own look (AttackFormView's bolt layer, scaled by the projectile's radius; VX V18:
##   with its element accent, and the long trail near full charge).
## - v0.9.0 VX V19: where a wall stops the ball, a layered flash (a hot core, a glow, a ring, sparks, a light) and its
##   element's extra (HeroFx.impact), WALL_TICKS long.
## - v0.9.0 VX V47: Effects density Low halves the circle's motes; reduced motion stills its spin.
## Presentation only (EI-07): it reads the reader, never writes; a burst's life is sim ticks.

const BURSTS_MAX := 6
const BURST_TICKS := 12.0
const HEIGHT := SimPlane.CORE_HEIGHT
## The circle's radius: this many of the ball's radii plus a margin (m), so the gathering energy reads round the ball.
const CIRCLE_RADII := 1.8
const CIRCLE_PAD_M := 0.1
## A burst's radius in the ball's radii.
const BURST_RADII := 3.5
## v0.9.0 VX V19: a wall stop's flash and extra (ticks), and how many play at once.
const WALL_TICKS := 18.0
const WALLS_MAX := 4

const SWIRL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float charge = 0.0;
uniform float full = 0.0;
uniform float energy = 1.0;
uniform int motes_n = 8;
uniform float motion = 1.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float a = atan(d.y, d.x);
	float tm = TIME * motion;
	float spin = tm * (3.0 + 5.0 * charge);
	float ring = exp(-pow((r - 0.74) * 9.0, 2.0));
	float arcs = pow(max(0.0, cos(a * 3.0 - spin)), 6.0) * ring;
	float inner = pow(max(0.0, cos(a * 2.0 + spin * 1.6)), 8.0) * exp(-pow((r - 0.46) * 11.0, 2.0));
	float motes = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= motes_n) {
			break;
		}
		float fi = float(i);
		float ph = fract(tm * (0.9 + 0.7 * charge) + fi * 0.37);
		float rr = mix(0.98, 0.12, ph);
		float ang = fi * 0.785 + ph * 2.2 + tm * 0.6;
		vec2 p = rr * vec2(cos(ang), sin(ang));
		motes += exp(-dot(d - p, d - p) * 140.0) * (0.3 + ph);
	}
	float hot = exp(-r * r * mix(70.0, 22.0, charge)) * (0.4 + 0.6 * charge);
	float pulse = mix(1.0, 0.7 + 0.3 * sin(tm * 16.0), full);
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
## v0.9.0 VX V19: the wall stops playing now, and since the view began (the tests).
var walls := 0
var walls_seen := 0

var _circle: MeshInstance3D
var _circle_mat: ShaderMaterial
var _burst_nodes: Array[MeshInstance3D] = []
var _burst_mat: Array[ShaderMaterial] = []
## Each live burst: [pos (Vector2), tick (float), look, radius (m)].
var _live: Array = []
var _tick := 0.0
var _last_seq := 0
var _primed := false
var _form := FormLook.new()
## v0.9.0 VX V19: the balls in flight (id -> [pos, vel, radius], the last sync's, swapped with the one being built) and
## the wall stops playing ([pos (Vector3), tick (float)]).
var _balls := {}
var _balls_was := {}
var _walls: Array = []


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
	_form.refresh(reader)  # v0.9.0 VX V48: once per build
	look = _form.look
	var motes := 4 if ViewPrefs.effects_density == "low" else 8  # V47
	_circle_mat.set_shader_parameter(&"motes_n", motes)
	_circle_mat.set_shader_parameter(&"motion", 0.0 if ViewPrefs.reduced_motion else 1.0)
	var orb := reader.lance_orb() if not reader.player_dead() else {}
	charge = reader.lance_charge() if not orb.is_empty() else 0.0
	circle = not orb.is_empty()
	_circle.visible = circle
	if circle:
		circle_size = 2.0 * (float(orb["radius"]) * CIRCLE_RADII + CIRCLE_PAD_M)
		_circle.position = SimPlane.to_3d(orb["pos"], HEIGHT)
		_circle.scale = Vector3.ONE * circle_size
		_circle_mat.set_shader_parameter(&"core", _form.core)
		_circle_mat.set_shader_parameter(&"edge", _form.edge)
		_circle_mat.set_shader_parameter(&"charge", charge)
		_circle_mat.set_shader_parameter(&"full", 1.0 if charge >= 1.0 else 0.0)
		_circle_mat.set_shader_parameter(&"energy", 0.7 + 1.1 * charge)
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.LANCE:
			continue
		var radius := e.amount / 1000.0
		_live.append([e.pos, float(e.tick), _form.core, radius, _form.edge])
		last_burst_charge = e.proc_pct
		last_burst_radius = radius
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
		m.set_shader_parameter(&"core", f[2])
		m.set_shader_parameter(&"edge", f[4])
		m.set_shader_parameter(&"u", u)
	_sync_walls(reader)


## V19: the balls in flight this sync; a ball that left where a wall stands just ahead of it (its last place plus its
## step, within its radius of a wall) stopped on that wall: a flash and its element's extra play there.
func _sync_walls(reader: WorldReader) -> void:
	var was := _balls_was
	_balls_was = _balls
	_balls = was
	_balls.clear()
	if reader.lance_active():
		for i in reader.projectile_count():
			if reader.projectile_team(i) != 0 or not _is_ball(reader, i):
				continue
			_balls[reader.projectile_id(i)] = [
				reader.projectile_pos(i), reader.projectile_vel(i), reader.projectile_radius(i)
			]
	for id: int in _balls_was:
		if _balls.has(id):
			continue
		var b: Array = _balls_was[id]
		var p: Vector2 = b[0]
		var v: Vector2 = b[1]
		var hit := _wall_ahead(reader, p + v, float(b[2]))
		if hit:
			walls_seen += 1
			var d := v.normalized() if v.length_squared() > 1e-8 else Vector2.RIGHT
			_walls.append([SimPlane.to_3d(p + v * 0.5, HEIGHT), _tick, SimPlane.to_3d(d, 0.0)])
	while _walls.size() > WALLS_MAX:
		_walls.pop_front()
	var k := 0
	while k < _walls.size():
		if _tick - float(_walls[k][1]) >= WALL_TICKS:
			_walls.remove_at(k)
		else:
			k += 1
	walls = _walls.size()


## Player projectile `i` is a plain Gun ball (not another form's shot or a wisp's orb).
static func _is_ball(reader: WorldReader, i: int) -> bool:
	return not (
		reader.projectile_is_wave(i)
		or reader.projectile_is_shard(i)
		or reader.projectile_is_bomb(i)
		or reader.projectile_is_void(i)
		or reader.projectile_is_pellet(i)
		or reader.projectile_is_disc(i)
		or reader.projectile_is_dart(i)
		or reader.projectile_is_wisp(i)
	)


static func _wall_ahead(reader: WorldReader, p: Vector2, r: float) -> bool:
	var rr := (r + 0.05) * (r + 0.05)
	for w in reader.wall_count():
		var box := reader.wall(w)  # the box's nearest point to `p` (the view's own test: no sim collision code)
		var d := p - box.center
		var lx := clampf(d.dot(box.axis_u), -box.half.x, box.half.x)
		var ly := clampf(d.dot(box.axis_v), -box.half.y, box.half.y)
		if (box.center + box.axis_u * lx + box.axis_v * ly).distance_squared_to(p) <= rr:
			return true
	return false


static func _glow(c: Color, f: float) -> Color:
	return Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, clampf(0.5 * f, 0.0, 1.0))


## VfxLayer's drawer (WorldViewRoot appends it): each young burst's sparks thrown outward, its glow and a light; each
## wall stop's flash and element extra (V19); the full charge's circle lights the hero's hand.
func draw_fx(layer: VfxCore) -> void:
	var now := layer.now()
	for k in _live.size():
		var f: Array = _live[k]
		var u := clampf((now - float(f[1])) / BURST_TICKS, 0.0, 1.0)
		if u >= 1.0:
			continue
		var at := SimPlane.to_3d(f[0], HEIGHT)
		var col: Color = f[4]
		var reach := float(f[3]) * BURST_RADII * (0.4 + u)
		for j in 6:
			var a := TAU * (float(j) / 6.0) + float(k) * 0.7
			var p := at + Vector3(cos(a) * reach, 0.15 * u, sin(a) * reach)
			var c := Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 1.0 - u)
			layer.sprite(&"spark", p, 0.28 * (1.0 - u), c, j % 4, 0.0)
		var gs := float(f[3]) * BURST_RADII * 1.6 * (0.6 + u)
		layer.sprite(&"glow", at, gs, _glow(col, 1.0 - u), 0, 0.0)
		layer.light_merged(at + Vector3(0, 0.4, 0), col, 2.2 * (1.0 - u), 3.0, 1.5)
	for k in _walls.size():
		var u := clampf((now - float(_walls[k][1])) / WALL_TICKS, 0.0, 1.0)
		var p: Vector3 = _walls[k][0]
		var sd := 4211 + k * 17 + int(float(_walls[k][1]))
		HeroFx.flash(layer, p, _form.core, _form.edge, minf(1.0, u * 1.6), 1.2, sd, 6)
		HeroFx.impact(layer, _form.kind, p, _walls[k][2], u, sd)
	if circle and charge > 0.0:
		layer.light_merged(
			_circle.position + Vector3(0, 0.3, 0), _form.edge, 0.4 + 0.9 * charge, 2.5, 1.2
		)
