class_name LanceView
extends Node3D
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F5): the Lance's look. While it charges (WorldReader.lance_charge), a glow at
## the hero's muzzle grows with the charge and a thin aim line runs along each Lance line (WorldReader.lance_lines:
## the sim's own trace, so it ends on the wall the release would stop on), brighter and wider as the charge fills,
## pulsing once full. Each release (a LANCE event: the line's start, length and angle, the charge) is a bright flash
## along the whole line that fades in FLASH_TICKS, wider for a bigger charge, in the element's colours (BeamLooks:
## default energy, Fire, Lightning, Frost, Venom, Bleed), with the element's accent and sparks along it on the effects
## layer. Presentation only (EI-07): it reads the reader, never writes; a flash's life is sim ticks.

const LINES_MAX := 3
const FLASHES_MAX := 6
const FLASH_TICKS := 14.0
const HEIGHT := SimPlane.CORE_HEIGHT
const MUZZLE_MIN := 0.25
const MUZZLE_MAX := 0.95
## The aim line's width (m) empty and full, and a release flash's at × 1 and × 5.
const AIM_W := Vector2(0.05, 0.16)
const FLASH_W := Vector2(0.3, 0.75)

const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float length_m = 1.0;
uniform float energy = 1.0;
uniform float dashes = 1.0;
uniform float fade = 0.0;
void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float hot = exp(-across * across * 10.0);
	float soft = exp(-across * across * 2.5);
	float ends = smoothstep(0.0, 0.03, UV.x) * smoothstep(1.0, 0.94, UV.x);
	float dash = mix(1.0, step(0.45, fract(UV.x * length_m * 1.6 - TIME * 2.4)), dashes);
	float along = mix(1.0, 1.0 - UV.x * 0.6, fade);
	ALBEDO = (edge.rgb * soft + core.rgb * hot * 1.4) * energy * ends * dash * along;
}
"""
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float energy = 1.0;
uniform float full = 0.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float a = atan(d.y, d.x);
	float rays = pow(abs(cos(a * 3.0 + TIME * 2.0)), 8.0) * (1.0 - r) * full;
	float pulse = mix(1.0, 0.75 + 0.25 * sin(TIME * 14.0), full);
	float glow = exp(-r * r * 4.0);
	float hot = exp(-r * r * 26.0);
	ALBEDO = (edge.rgb * (glow + rays) + core.rgb * hot * 1.8) * energy * pulse;
}
"""

static var _shaders := {}

## What the last sync showed (tests read them): the aim lines, the charge, the live flashes and their look.
var aims := 0
var charge := 0.0
var flashes := 0
var look := &"default"
var last_flash_charge := 0

var _aim_nodes: Array[MeshInstance3D] = []
var _aim_mat: Array[ShaderMaterial] = []
var _flash_nodes: Array[MeshInstance3D] = []
var _flash_mat: Array[ShaderMaterial] = []
var _muzzle: MeshInstance3D
var _muzzle_mat: ShaderMaterial
var _lines: Array[Dictionary] = []
## Each live flash: [from (Vector2), to (Vector2), tick (float), look, width (m)].
var _live: Array = []
var _tick := 0.0
var _last_seq := 0
var _primed := false


func _init() -> void:
	name = "LanceView"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for k in LINES_MAX:
		var n := _quad(quad, LINE_SHADER)
		_aim_nodes.append(n)
		_aim_mat.append(n.material_override as ShaderMaterial)
	for k in FLASHES_MAX:
		var n := _quad(quad, LINE_SHADER)
		_flash_nodes.append(n)
		_flash_mat.append(n.material_override as ShaderMaterial)
	_muzzle = _quad(quad, GLOW_SHADER)
	_muzzle_mat = _muzzle.material_override as ShaderMaterial


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


## Each tick: the charge and its aim lines, and the releases since the last sync.
func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # attaching mid-run draws nothing that already happened
	var els: Array = reader.attack_spec(WorldReader.ATTACK_BOLT).get("elements", [])
	look = BeamLooks.look_of(PackedStringArray(els))
	charge = reader.lance_charge() if not reader.player_dead() else 0.0
	_lines = reader.lance_lines() if charge > 0.0 else ([] as Array[Dictionary])
	aims = mini(_lines.size(), LINES_MAX)
	_muzzle.visible = aims > 0
	if aims > 0:
		var full := 1.0 if charge >= 1.0 else 0.0
		_muzzle.position = SimPlane.to_3d(_lines[(aims - 1) / 2]["from"], HEIGHT)
		_muzzle.scale = Vector3.ONE * lerpf(MUZZLE_MIN, MUZZLE_MAX, charge)
		_muzzle_mat.set_shader_parameter(&"core", BeamLooks.core(look))
		_muzzle_mat.set_shader_parameter(&"edge", BeamLooks.edge(look))
		_muzzle_mat.set_shader_parameter(&"energy", 0.8 + 1.2 * charge)
		_muzzle_mat.set_shader_parameter(&"full", full)
	for k in LINES_MAX:
		_aim_nodes[k].visible = k < aims
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.LANCE:
			continue
		var spec := reader.attack_spec_at(String(e.effect_id))
		var l := BeamLooks.look_of(PackedStringArray(spec.get("elements", [])))
		var to := e.pos + Kin.dir(e.amount_applied & 4095) * (e.amount / 1000.0)
		var hold_pm := maxi(1001, int(spec.get("hold_permille", 5000)))
		var u := clampf(float(e.proc_pct - 1000) / float(hold_pm - 1000), 0.0, 1.0)
		_live.append([e.pos, to, float(e.tick), l, lerpf(FLASH_W.x, FLASH_W.y, u)])
		last_flash_charge = e.proc_pct
	while _live.size() > FLASHES_MAX:
		_live.pop_front()
	var keep: Array = []
	for f: Array in _live:
		if _tick - float(f[2]) < FLASH_TICKS:
			keep.append(f)
	_live = keep
	flashes = _live.size()
	for k in FLASHES_MAX:
		_flash_nodes[k].visible = k < flashes
	_place()


func _process(_delta: float) -> void:
	if aims > 0 or flashes > 0:
		_place()


## The camera-facing ribbons along the aim lines and the flashes (each frame: the camera moves between ticks).
func _place() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var view := Vector3(0, 1, 1).normalized() if cam == null else cam.global_transform.basis.z
	for k in aims:
		var l: Dictionary = _lines[k]
		var full := charge >= 1.0
		var m := _aim_mat[k]
		_ribbon(_aim_nodes[k], l["from"], l["to"], lerpf(AIM_W.x, AIM_W.y, charge), view, m)
		m.set_shader_parameter(&"core", BeamLooks.core(look))
		m.set_shader_parameter(&"edge", BeamLooks.edge(look))
		m.set_shader_parameter(&"energy", (0.25 + 0.75 * charge) * (1.3 if full else 1.0))
		m.set_shader_parameter(&"dashes", 0.0 if full else 1.0)
		m.set_shader_parameter(&"fade", 1.0)
	for k in flashes:
		var f: Array = _live[k]
		var u := clampf((_tick - float(f[2])) / FLASH_TICKS, 0.0, 1.0)
		var m := _flash_mat[k]
		_ribbon(_flash_nodes[k], f[0], f[1], float(f[4]) * (1.0 - 0.6 * u), view, m)
		m.set_shader_parameter(&"core", BeamLooks.core(f[3]))
		m.set_shader_parameter(&"edge", BeamLooks.edge(f[3]))
		m.set_shader_parameter(&"energy", 2.6 * (1.0 - u) * (1.0 - u))
		m.set_shader_parameter(&"dashes", 0.0)
		m.set_shader_parameter(&"fade", 0.0)


static func _ribbon(
	n: MeshInstance3D, from: Vector2, to: Vector2, width: float, view: Vector3, m: ShaderMaterial
) -> void:
	var a := SimPlane.to_3d(from, HEIGHT)
	var e := SimPlane.to_3d(to, HEIGHT)
	var along := e - a
	var len := along.length()
	if len < 0.01:
		n.visible = false
		return
	var x := along / len
	var y := x.cross(view).normalized()
	if y.length_squared() < 0.5:
		y = Vector3.UP.cross(x).normalized()
	var z := x.cross(y).normalized()
	n.transform = Transform3D(Basis(x * len, y * width, z), (a + e) * 0.5)
	m.set_shader_parameter(&"length_m", len)


## VfxLayer's drawer (WorldViewRoot appends it): each young flash's element accent along its line, sparks at its end
## and a light; the full charge's glow lights the hero's hand.
func draw_fx(layer: VfxCore) -> void:
	var fx := layer as VfxLayer
	var now := layer.now()
	for k in _live.size():
		var f: Array = _live[k]
		var u := clampf((now - float(f[2])) / FLASH_TICKS, 0.0, 1.0)
		if u >= 1.0:
			continue
		var a := SimPlane.to_3d(f[0], HEIGHT)
		var e := SimPlane.to_3d(f[1], HEIGHT)
		var kind: StringName = BeamLooks.VFX_KIND[f[3]]
		if kind != &"" and fx != null:
			fx.line(kind, a, e, 1.0 - u, now, 8101 + k * 37)
		var col := BeamLooks.edge(f[3])
		for j in 4:
			var t := fposmod(u + j * 0.25, 1.0)
			var at := a.lerp(e, t)
			var c := Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 1.0 - u)
			layer.sprite(&"spark", at + Vector3(0, 0.2 * u, 0), 0.3 * (1.0 - u), c, j % 4, 0.0)
		layer.light_merged(e + Vector3(0, 0.4, 0), col, 2.0 * (1.0 - u), 3.0, 1.5)
	if aims > 0 and charge >= 1.0:
		layer.light_merged(
			_muzzle.position + Vector3(0, 0.3, 0), BeamLooks.edge(look), 1.2, 2.5, 1.2
		)
