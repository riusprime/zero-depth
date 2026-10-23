class_name BombView
extends Node3D
## v0.9.0 BM (owner C §6.3; PLAN C51): the Bomb form. Each bomb in flight (WorldReader.projectile_is_bomb) is a chunky
## faceted iron bomb, tumbling as it flies, with a fuse spark flickering on top in its element's colour; each blast
## (a BLAST event: where, how big, the bomb's spec) is a stylised ring that sweeps out to the blast's radius and fades,
## in the element's colours (BeamLooks: default energy, Fire, Lightning, Frost, Venom, Bleed), with the owner's
## `blast_ring` PNG (assets/textures/vfx/, white on transparent, tinted) when installed, else a code-made band. With the
## effects layer each blast also draws VfxLayer's burst of its element (the fire explosion for Fire and the default).
## v0.9.0 VX (VFX_AUDIT.md): V2 the first element's centre and the second's edge; V10 the blast ring lies on the floor,
## so its colours go through AttackFormLooks.ground_safe (V49: never a telegraph's hostile hue); V11 (owner "Keep fire
## blast") a no-element bomb keeps the fire explosion; each fuse sheds its element's sparks.
## Presentation only (EI-07): it reads the reader, never writes; a blast's life is sim ticks.

const BOMBS_MAX := 16
const BLASTS_MAX := 8
const BLAST_TICKS := 20.0
const BOMB_SIZE := 0.62
const SPARK_SIZE := 0.42
const HEIGHT := SimPlane.CORE_HEIGHT
const IRON := Color("#55606E")
const BAND := Color("#C9A86A")

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D ring_tex : source_color, filter_linear;
uniform float has_tex = 0.0;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float u = 0.0;
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float front = 0.25 + 0.72 * u;
	float band = exp(-pow((r - front) * 8.0, 2.0));
	float fill = (1.0 - smoothstep(0.0, front, r)) * 0.45 * (1.0 - u);
	float a = band + fill;
	if (has_tex > 0.5) {
		vec2 uv = (UV - 0.5) / max(front, 0.05) + 0.5;
		a = texture(ring_tex, clamp(uv, 0.0, 1.0)).a * step(r, front + 0.05) + fill;
	}
	ALBEDO = mix(edge.rgb, core.rgb, band) * a * (1.0 - u * u) * 2.2;
}
"""
const SPARK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.5, 0.1, 1.0);
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float a = atan(d.y, d.x);
	float flick = 0.7 + 0.3 * sin(TIME * 40.0 + a * 3.0);
	float star = pow(abs(cos(a * 2.0 + TIME * 9.0)), 8.0) * (1.0 - r);
	ALBEDO = (edge.rgb * (exp(-r * r * 6.0) + star) + core.rgb * exp(-r * r * 30.0) * 1.5) * flick * 1.6;
}
"""

static var _shaders := {}

## What the last sync showed (tests read them): bombs in flight, blasts drawn, and the last blast's look.
var bombs := 0
var blasts := 0
var last_look := &""
## The effects layer for the element bursts (WorldViewRoot hands it in; null: the rings alone).
var vfx: VfxLayer = null

var _bomb_nodes: Array[MeshInstance3D] = []
var _sparks: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _ring_mat: Array[ShaderMaterial] = []
## Live blasts: [pos (Vector2), radius (m), start tick, look].
var _live: Array = []
var _last_seq := 0
var _tick := 0
var _primed := false
var _form := FormLook.new()


func _init() -> void:
	name = "BombView"
	var body := bomb_mesh()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for k in BOMBS_MAX:
		var b := MeshInstance3D.new()
		b.mesh = body
		b.visible = false
		add_child(b)
		_bomb_nodes.append(b)
		var s := MeshInstance3D.new()
		s.mesh = quad
		var sm := ShaderMaterial.new()
		sm.shader = _shader(SPARK_SHADER)
		s.material_override = sm
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		add_child(s)
		_sparks.append(s)
	var flat := PlaneMesh.new()
	flat.size = Vector2(2.0, 2.0)
	var tex := FxTextures.get_tex("blast_ring")
	for k in BLASTS_MAX:
		var m := ShaderMaterial.new()
		m.shader = _shader(RING_SHADER)
		m.set_shader_parameter(&"has_tex", 1.0 if tex != null else 0.0)
		if tex != null:
			m.set_shader_parameter(&"ring_tex", tex)
		var r := MeshInstance3D.new()
		r.mesh = flat
		r.material_override = m
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		_rings.append(r)
		_ring_mat.append(m)


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## The bomb's body: a low-poly faceted ball (flat shaded iron) with a brass band and a fuse stub.
static func bomb_mesh() -> Mesh:
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 7
	ball.rings = 4
	var mesh := _mesh_of(ball.get_mesh_arrays())
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.metallic = 0.25
	iron.roughness = 0.45
	iron.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mesh.surface_set_material(0, iron)
	var fuse := CylinderMesh.new()
	fuse.top_radius = 0.12
	fuse.bottom_radius = 0.16
	fuse.height = 0.22
	fuse.radial_segments = 6
	var cap := StandardMaterial3D.new()
	cap.albedo_color = BAND
	cap.metallic = 0.8
	cap.roughness = 0.35
	var fa := fuse.get_mesh_arrays()
	var verts: PackedVector3Array = fa[Mesh.ARRAY_VERTEX]
	for k in verts.size():
		verts[k] += Vector3(0, 0.52, 0)
	fa[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fa)
	mesh.surface_set_material(1, cap)
	return mesh


static func _mesh_of(arr: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.deindex()
	st.generate_normals(true)  # flat facets
	return st.commit()


## Each tick: the bombs in flight and the blasts since the last sync.
func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # attaching mid-run draws nothing that already happened
	bombs = 0
	if _form.refresh(reader):  # v0.9.0 VX V48: the Gun shot's look once per build (V2 colours)
		for spark in _sparks:
			var sm := spark.material_override as ShaderMaterial
			sm.set_shader_parameter(&"core", _form.core)
			sm.set_shader_parameter(&"edge", _form.edge)
	for i in reader.projectile_count():
		if bombs >= BOMBS_MAX:
			break
		if reader.projectile_team(i) != 0 or not reader.projectile_is_bomb(i):
			continue
		var p := reader.projectile_pos(i)
		var at := SimPlane.to_3d(p, HEIGHT)
		var spin := float(reader.projectile_id(i) * 37 % 360) + (p.x + p.y) * 140.0
		var node := _bomb_nodes[bombs]
		node.visible = true
		var s := BOMB_SIZE * reader.projectile_radius(i) / 0.3
		node.transform = Transform3D(
			(
				Basis(Vector3.UP, deg_to_rad(spin))
				* Basis(Vector3.RIGHT, 0.35).scaled(Vector3.ONE * s)
			),
			at
		)
		var spark := _sparks[bombs]
		spark.visible = true
		spark.position = at + Vector3.UP * (0.62 * s)
		spark.scale = Vector3.ONE * SPARK_SIZE
		bombs += 1
	for k in range(bombs, BOMBS_MAX):
		_bomb_nodes[k].visible = false
		_sparks[k].visible = false
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.BLAST:
			continue
		var spec := reader.attack_spec_at(String(e.effect_id))
		var els := PackedStringArray(spec.get("elements", []))
		var l := BeamLooks.look_of(els)
		# v0.9.0 VX V2, V10, V49: the first element's centre and the second's edge, kept out of the telegraphs' hostile
		# hues: the ring lies flat on the floor, a player ground mark (Fire leans to amber, Bleed to a cool crimson).
		var cols := BeamLooks.colors(els)
		var g0 := AttackFormLooks.ground_safe(cols[0])
		var g1 := AttackFormLooks.ground_safe(cols[1])
		_live.append([e.pos, e.amount / 1000.0, float(e.tick), l, g0, g1])
		last_look = l
	while _live.size() > BLASTS_MAX:
		_live.pop_front()
	_draw_rings()


func _draw_rings() -> void:
	var keep: Array = []
	for b: Array in _live:
		if _tick - float(b[2]) < BLAST_TICKS:
			keep.append(b)
	_live = keep
	blasts = _live.size()
	for k in BLASTS_MAX:
		var ring := _rings[k]
		ring.visible = k < blasts
		if k >= blasts:
			continue
		var b: Array = _live[k]
		var u := clampf((_tick - float(b[2])) / BLAST_TICKS, 0.0, 1.0)
		var r: float = b[1]
		ring.transform = Transform3D(
			Basis.from_scale(Vector3(r, 1.0, r)), SimPlane.to_3d(b[0], 0.08)
		)
		var m := _ring_mat[k]
		m.set_shader_parameter(&"u", u)
		m.set_shader_parameter(&"core", b[4])
		m.set_shader_parameter(&"edge", b[5])


## VfxLayer's drawer (WorldViewRoot appends it): each young blast's burst in its element.
func draw_fx(layer: VfxCore) -> void:
	var fx := layer as VfxLayer
	if fx == null:
		return
	# v0.9.0 VX: each fuse sheds its element's sparks (a no-element bomb's fuse: embers, as its fire blast, V11).
	var fuse := _form.kind if _form.kind != &"" else &"fire"
	var element := _form.element if _form.element != &"" else &"ember"
	for k in bombs:
		HeroFx.accent(layer, fuse, element, _sparks[k].position, Vector3.DOWN, 9301 + k * 11, 0.6)
	for k in _live.size():
		var b: Array = _live[k]
		var u := clampf((layer.now() - float(b[2])) / BLAST_TICKS, 0.0, 1.0)
		var kind: StringName = BeamLooks.VFX_KIND[b[3]]
		fx.burst(
			kind if kind != &"" else &"fire", SimPlane.to_3d(b[0], 0.0), b[1], u, 9001 + k * 17
		)
