class_name ScatterView
extends Node3D
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F6): the Scatter's look. Each pellet in flight
## (WorldReader.projectile_is_pellet) is a short hot slug stretched along its flight, camera-facing, in the element's
## colours (BeamLooks: default energy, Fire, Lightning, Frost, Venom, Bleed); each volley (a pellet that wasn't there
## last sync) opens a muzzle cone at the hero, a fan as wide as the shot's spread that flares and fades in CONE_TICKS,
## so the short reach reads at a glance.
## v0.9.0 VX (VFX_AUDIT.md): V2 the colours of the first element's centre and the second's edge; V22 the element's
## accent on the cone (HeroFx.spray: an ember spray, a crackle across the fan, frost shards, droplets; 5 sprites a
## volley, none at Low); V48 the look read once per build and the buffers reused.
## Presentation only (EI-07): it reads the reader, never writes; a cone's life is sim ticks.

const PELLETS_MAX := 24
const CONES_MAX := 4
const CONE_TICKS := 9.0
const CONE_LEN := 1.7
const HEIGHT := SimPlane.CORE_HEIGHT
## A pellet's slug: its length (m, along its flight) and width (m).
const SLUG := Vector2(0.55, 0.16)

const SLUG_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float head = smoothstep(-1.0, 0.7, d.x);
	float r = d.y * d.y * 4.0 + max(d.x - 0.7, 0.0) * 6.0;
	float glow = exp(-r * 1.4) * head;
	float hot = exp(-r * 6.0) * smoothstep(0.0, 0.8, d.x);
	ALBEDO = (edge.rgb * glow + core.rgb * hot * 2.0) * 1.6;
}
"""
const CONE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float u = 0.0;
varying float along;
varying float side;
void vertex() {
	along = UV.x;
	side = UV.y;
}
void fragment() {
	float fan = smoothstep(1.0, 0.6, abs(side * 2.0 - 1.0));
	float reach = smoothstep(1.0, 0.25 + 0.5 * u, along) * smoothstep(0.0, 0.08, along);
	float hot = exp(-along * 5.0);
	float a = (1.0 - u) * (1.0 - u);
	ALBEDO = (edge.rgb * fan * reach + core.rgb * hot * fan * 1.2) * a * 1.8;
}
"""

static var _shaders := {}

## What the last sync showed (tests read them): the pellets drawn, the live cones, the look.
var pellets := 0
var cones := 0
var look := &"default"

var _slugs: Array[MeshInstance3D] = []
var _slug_mat: Array[ShaderMaterial] = []
var _cone_nodes: Array[MeshInstance3D] = []
var _cone_mat: Array[ShaderMaterial] = []
var _seen := {}
var _seen_now := {}
var _form := FormLook.new()
## Each live cone: [origin (Vector2), angle (1/4096 turns), half spread (1/4096 turns), tick (float)].
var _live: Array = []
var _tick := 0.0
var _pellet_pos: Array[Vector2] = []
var _pellet_vel: Array[Vector2] = []


func _init() -> void:
	name = "ScatterView"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for k in PELLETS_MAX:
		var n := _node(quad, SLUG_SHADER)
		_slugs.append(n)
		_slug_mat.append(n.material_override as ShaderMaterial)
	var fan := fan_mesh()
	for k in CONES_MAX:
		var n := _node(fan, CONE_SHADER)
		_cone_nodes.append(n)
		_cone_mat.append(n.material_override as ShaderMaterial)


func _node(mesh: Mesh, code: String) -> MeshInstance3D:
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


## A flat unit fan on the ground plane: from the origin along +x out to 1, its edges at ±1 across (scaled per cone to
## its spread). UV.x = along, UV.y = across (0..1).
static func fan_mesh() -> ArrayMesh:
	var steps := 8
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for k in steps:
		var a := float(k) / steps
		var b := float(k + 1) / steps
		verts.append_array(
			[Vector3.ZERO, Vector3(1.0, 0.0, a * 2.0 - 1.0), Vector3(1.0, 0.0, b * 2.0 - 1.0)]
		)
		uvs.append_array([Vector2(0.0, 0.5), Vector2(1.0, a), Vector2(1.0, b)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Each tick: the pellets in flight and the volleys since the last sync.
func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	var changed := _form.refresh(reader)
	look = _form.look
	_pellet_pos.clear()
	_pellet_vel.clear()
	var now := _seen_now
	now.clear()
	var fresh := false
	for i in reader.projectile_count():
		if reader.projectile_team(i) != 0 or not reader.projectile_is_pellet(i):
			continue
		var id := reader.projectile_id(i)
		now[id] = true
		if not _seen.has(id):
			fresh = true
		if _pellet_pos.size() < PELLETS_MAX:
			_pellet_pos.append(reader.projectile_pos(i))
			_pellet_vel.append(reader.projectile_vel(i))
	_seen_now = _seen
	_seen = now
	if fresh and not reader.player_dead():
		var half := maxi(16, _form.spread / 2)
		_live.append([reader.player_pos(), reader.aim_angle(), half, _tick])
	while _live.size() > CONES_MAX:
		_live.pop_front()
	while not _live.is_empty() and _tick - float(_live[0][3]) >= CONE_TICKS:
		_live.pop_front()
	pellets = _pellet_pos.size()
	cones = _live.size()
	for k in PELLETS_MAX:
		_slugs[k].visible = k < pellets
		if changed:
			_slug_mat[k].set_shader_parameter(&"core", _form.core)
			_slug_mat[k].set_shader_parameter(&"edge", _form.edge)
	for k in CONES_MAX:
		_cone_nodes[k].visible = k < cones
		if k < cones:
			_place_cone(k)
	_place_slugs()


func _process(_delta: float) -> void:
	if pellets > 0:
		_place_slugs()


func _place_cone(k: int) -> void:
	var c: Array = _live[k]
	var u := clampf((_tick - float(c[3])) / CONE_TICKS, 0.0, 1.0)
	var dir := Kin.dir(int(c[1]) & 4095)
	var across := Kin.dir(int(c[2]) & 4095)
	var reach := CONE_LEN * (0.7 + 0.3 * u)
	var width := reach * across.y / maxf(0.05, across.x)
	var o := SimPlane.to_3d(c[0] + dir * 0.35, HEIGHT - 0.1)
	var x := SimPlane.to_3d(dir, 0.0)
	var z := SimPlane.to_3d(Vector2(-dir.y, dir.x), 0.0)
	_cone_nodes[k].transform = Transform3D(Basis(x * reach, Vector3.UP, z * width), o)
	var m := _cone_mat[k]
	m.set_shader_parameter(&"u", u)
	m.set_shader_parameter(&"core", _form.core)
	m.set_shader_parameter(&"edge", _form.edge)


## The slugs face the camera, stretched along their flight (each frame: the camera moves between ticks).
func _place_slugs() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var view := Vector3(0, 1, 1).normalized() if cam == null else cam.global_transform.basis.z
	for k in pellets:
		var v := _pellet_vel[k]
		var dir2 := v.normalized() if v.length_squared() > 1e-8 else Vector2.RIGHT
		var x := SimPlane.to_3d(dir2, 0.0).normalized()
		var y := x.cross(view).normalized()
		if y.length_squared() < 0.5:
			y = Vector3.UP.cross(x).normalized()
		var n := x.cross(y).normalized()
		var at := SimPlane.to_3d(_pellet_pos[k], HEIGHT) - x * (SLUG.x * 0.35)
		_slugs[k].transform = Transform3D(Basis(x * SLUG.x, y * SLUG.y, n), at)


## The effects layer's drawer (WorldViewRoot appends it): V22's element spray over each live cone.
func draw_fx(layer: VfxCore) -> void:
	if _form.kind == &"":
		return
	for k in _live.size():
		var c: Array = _live[k]
		var u := clampf((layer.now() - float(c[3])) / CONE_TICKS, 0.0, 1.0)
		var dir := Kin.dir(int(c[1]) & 4095)
		var across := Kin.dir(int(c[2]) & 4095)
		var half := atan2(across.y, across.x)
		var o := SimPlane.to_3d(c[0] + dir * 0.35, HEIGHT)
		var sd := int(float(c[3])) * 31 + 7
		HeroFx.spray(
			layer, _form.kind, _form.element, o, SimPlane.to_3d(dir, 0.0), half, CONE_LEN, u, sd
		)
