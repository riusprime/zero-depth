class_name SeekersView
extends Node3D
## v0.9.0 AF2 (owner Q7; ATTACK_FORMS.md F8): the Seekers' look. Each dart in flight (WorldReader.projectile_is_dart)
## is a thin needle of light stretched along its flight, camera-facing, in the element's colours (BeamLooks: default
## energy, Fire, Lightning, Frost, Venom, Bleed), trailing TRAIL fading motes where it was the last syncs, so the curve
## each dart draws toward its enemy reads at a glance.
## v0.9.0 VX (VFX_AUDIT.md): V2 the first element's centre and the second's edge; V27 the volley's muzzle spark fanned
## three ways (AttackFormView); V29 with the effects layer on the trail motes become the element's own sprites (an
## ember, a crackle, a shard, a drop: HeroFx.mote), same count; V47 Low keeps LOW_MOTES a dart; V48 in-place buffers.
## Presentation only (EI-07): it reads the reader, never writes.

const DARTS_MAX := 24
## v0.9.5 FC7: Ring's lightning rings where a dart hit (the Glaive's ring look): at most ARCS_MAX at once; the ring
## shader's phase that puts its band at ARC_FRONT of the quad's half-width (0.25 + 0.72 u), so a ring of radius r is
## drawn at r / ARC_FRONT.
const ARCS_MAX := 8
const ARC_U := 0.7
const ARC_FRONT := 0.754
const TRAIL := 5
const HEIGHT := SimPlane.CORE_HEIGHT
## A dart's needle: its length (m, along its flight) and width (m); a trail mote's size (m).
const NEEDLE := Vector2(0.5, 0.11)
const MOTE := 0.16
## v0.9.0 VX V47: Effects density Low keeps this many trail motes a dart.
const LOW_MOTES := 2
## v0.10.0 VX2 (VFX_PACK R2): each dart is the pack's javelin (mprojectile_javelin, the element's scene and colours)
## following it, its own trail replacing the needle and the motes (false: the needles, for before/after shots).
const PACK_DARTS := true
## The javelin scene drawn at this scale (its head and trail are about 2.7 m long, the needle 0.5 m).
const JAVELIN_SCALE := 0.4

const NEEDLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float head = smoothstep(-1.0, 0.8, d.x);
	float r = d.y * d.y * 5.0 + max(d.x - 0.75, 0.0) * 8.0;
	float glow = exp(-r * 1.6) * head;
	float hot = exp(-r * 7.0) * smoothstep(0.2, 0.9, d.x);
	ALBEDO = (edge.rgb * glow + core.rgb * hot * 2.2) * 1.7;
}
"""
const MOTE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float fade = 1.0;
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	ALBEDO = edge.rgb * exp(-dot(d, d) * 4.0) * fade * 1.3 * (1.0 - smoothstep(0.8, 1.0, length(d)));
}
"""

static var _shaders := {}

## What the last sync showed (tests read them): the darts drawn, the trail motes drawn, the look.
var darts := 0
var motes := 0
var look := &"default"
## v0.9.5 FC7: the lightning rings drawn now.
var arcs := 0
## v0.9.0 VX V29: the effects layer is on (WorldViewRoot sets it): an element's trail motes become its own sprites
## (draw_fx), the round motes hide. Same count, so the cost stays the same.
var vfx_on := false
## v0.10.0 VX2: the pack the darts draw with (WorldViewRoot hands it in) and the javelins it holds, by dart id.
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v if PACK_DARTS else null
var hold := FormPackHold.new()

var _dart_ids: PackedInt32Array = PackedInt32Array()
var _needles: Array[MeshInstance3D] = []
var _needle_mat: Array[ShaderMaterial] = []
var _motes: Array[MeshInstance3D] = []
var _mote_mat: Array[ShaderMaterial] = []
var _pos: Array[Vector2] = []
var _vel: Array[Vector2] = []
var _mote_pos: Array[Vector2] = []
var _mote_fade: PackedFloat32Array = PackedFloat32Array()
var _mote_id: PackedInt32Array = PackedInt32Array()
## Past positions by projectile id (the trails, nearest first), updated in place (V48).
var _trail := {}
var _seen := {}
var _form := FormLook.new()
var _arcs: Array[MeshInstance3D] = []


## v0.9.5 FC7: the pool of lightning rings (one shared material, the Glaive's ring look).
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


## v0.9.5 FC7: Ring's lightning ring where each dart hit.
func _place_arcs(reader: WorldReader) -> void:
	arcs = 0
	for row in reader.seeker_rings():
		if arcs >= ARCS_MAX:
			break
		var g := float(row["r"]) / ARC_FRONT
		var arc := _arcs[arcs]
		arc.visible = true
		arc.transform = Transform3D(
			Basis.from_scale(Vector3(g, 1.0, g)), SimPlane.to_3d(row["pos"], 0.1)
		)
		arcs += 1
	for k in range(arcs, ARCS_MAX):
		_arcs[k].visible = false


func _init() -> void:
	name = "SeekersView"
	_make_arcs()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for k in DARTS_MAX:
		var n := _node(quad, NEEDLE_SHADER)
		_needles.append(n)
		_needle_mat.append(n.material_override as ShaderMaterial)
	for k in DARTS_MAX * TRAIL:
		var n := _node(quad, MOTE_SHADER)
		_motes.append(n)
		_mote_mat.append(n.material_override as ShaderMaterial)


func _node(mesh: Mesh, code: String) -> MeshInstance3D:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	var m := ShaderMaterial.new()
	m.shader = _shaders[code]
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


## Each tick: the darts in flight and their trails (V47: Effects density Low keeps LOW_MOTES a dart).
func sync(reader: WorldReader) -> void:
	var changed := _form.refresh(reader)
	look = _form.look
	var keep_n := LOW_MOTES if ViewPrefs.effects_density == "low" else TRAIL
	_pos.clear()
	_vel.clear()
	_mote_pos.clear()
	_mote_fade.clear()
	_mote_id.clear()
	_dart_ids.clear()
	_seen.clear()
	for i in reader.projectile_count():
		if reader.projectile_team(i) != 0 or not reader.projectile_is_dart(i):
			continue
		var id := reader.projectile_id(i)
		var p := reader.projectile_pos(i)
		_seen[id] = true
		var past: Array = _trail.get(id, [])
		if past.is_empty():
			_trail[id] = past
		if _pos.size() < DARTS_MAX:
			_pos.append(p)
			_vel.append(reader.projectile_vel(i))
			_dart_ids.append(id)
			for g in mini(past.size(), keep_n):
				_mote_pos.append(past[g])
				_mote_fade.append(1.0 - float(g + 1) / float(TRAIL + 1))
				_mote_id.append(id * 8 + g)
		past.push_front(p)
		if past.size() > TRAIL:
			past.pop_back()
	for id: int in _trail.keys():
		if not _seen.has(id):
			_trail.erase(id)
	_place_arcs(reader)
	darts = _pos.size()
	motes = _mote_pos.size()
	var round := not vfx_on or _form.kind == &""
	for k in DARTS_MAX:
		_needles[k].visible = k < darts
		if changed:
			_needle_mat[k].set_shader_parameter(&"core", _form.core)
			_needle_mat[k].set_shader_parameter(&"edge", _form.edge)
	for k in _motes.size():
		_motes[k].visible = k < motes and round
		if changed:
			_mote_mat[k].set_shader_parameter(&"edge", _form.edge)
		if k < motes and round:
			_mote_mat[k].set_shader_parameter(&"fade", _mote_fade[k])
	_place()


func _process(_delta: float) -> void:
	if darts > 0:
		_place()


## The needles and motes face the camera (each frame: the camera moves between ticks).
func _place() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var view := Vector3(0, 1, 1).normalized() if cam == null else cam.global_transform.basis.z
	hold.begin()
	for k in darts:
		var v := _vel[k]
		var dir2 := v.normalized() if v.length_squared() > 1e-8 else Vector2.RIGHT
		var x := SimPlane.to_3d(dir2, 0.0).normalized()
		if _pack_dart(k, x):
			_needles[k].visible = false  # v0.10.0 VX2: the pack's javelin is the dart
			continue
		_needles[k].visible = true
		var y := x.cross(view).normalized()
		if y.length_squared() < 0.5:
			y = Vector3.UP.cross(x).normalized()
		var n := x.cross(y).normalized()
		var at := SimPlane.to_3d(_pos[k], HEIGHT) - x * (NEEDLE.x * 0.35)
		_needles[k].transform = Transform3D(Basis(x * NEEDLE.x, y * NEEDLE.y, n), at)
	hold.end()
	var right := Vector3.RIGHT if cam == null else cam.global_transform.basis.x
	var up := view.cross(right).normalized()
	for k in motes:
		if hold.has(_mote_id[k] >> 3):  # a javelin's own trail replaces its motes
			_motes[k].visible = false
			continue
		var b := Basis(right * MOTE, up * MOTE, view)
		_motes[k].transform = Transform3D(b, SimPlane.to_3d(_mote_pos[k], HEIGHT))


## v0.10.0 VX2 (R2): dart `k` (flying along `x` on the ground) as the pack's javelin of its element, held on it. False:
## the needle draws.
func _pack_dart(k: int, x: Vector3) -> bool:
	if not hold.active():
		return false
	var id := _dart_ids[k]
	var cols := {} if hold.has(id) else PackLooks.colors(_form.elements)
	var xf := Transform3D(PackLooks.facing(x, JAVELIN_SCALE), SimPlane.to_3d(_pos[k], HEIGHT))
	return hold.put(id, PackLooks.id_of("jav", _form.element), &"projectile", xf, cols) != null


## The effects layer's drawer (WorldViewRoot appends it): V29's element motes, one sprite where each round mote was.
func draw_fx(layer: VfxCore) -> void:
	if not vfx_on or _form.kind == &"":
		return
	for k in motes:
		if hold.has(_mote_id[k] >> 3):
			continue
		var q := SimPlane.to_3d(_mote_pos[k], HEIGHT)
		HeroFx.mote(layer, _form.kind, _form.element, q, _mote_fade[k], _mote_id[k])
