class_name BossSignatureViews
extends Node3D
## v0.8.0 BS1 (owner O5, "something that actually stands out for each boss"; BOSS_SIGNATURES.md S2, S3): the pieces
## the bosses' signature mechanics leave on the floor, read from the sim (WorldReader; EI-07), never decided here.
## (S1's pillars are StoneSpikeViews: the same 3D stone spikes standing for the pillar's life.)
## - The Warlord's javelins stuck in the floor (WorldReader.boss_javelins): a code-made 3D javelin each (a dark shaft,
##   an iron head with a red-hot edge), its head planted where it stopped, its shaft leaning back the way it flew in,
##   so the line it will come back along reads at a glance. Over the last RECALL_WARN_TICKS before the recall they
##   tremble and their heads glow hotter: the second dodge's warning. An owner model `javelin` listed in
##   assets/models/manifest.json at MODEL_PATH replaces the code mesh (normalised to the same length along +X).
## - The Brood Mother's eggs (WorldReader.actor_egg_permille): a speckled egg on the floor where the egg actor lies,
##   its veins glowing brighter as it nears its hatch, wobbling harder and faster (the hatch wobble), and an HP pip
##   bar over it (its HP over its max: break it before it hatches). A bursting egg swells and splits. The Hatchling
##   inside is hidden meanwhile (ActorViews).
## Pooled: one MultiMesh for every javelin (MAX_JAVELINS, one draw); one node per egg, reused. Ticks are the sim's
## plus the frame's interpolation fraction, so they pause with the game. Reduced motion: no tremble, no wobble.

const MAX_JAVELINS := 64
const JAVELIN_LENGTH := 2.0
## The javelin leans back from its planted head at this pitch (radians) and its head sinks this far into the floor.
const JAVELIN_PITCH := 0.62
const JAVELIN_SINK := 0.22
const RECALL_WARN_TICKS := 40.0
const STICK_TICKS := 4.0
const SHAFT := Color(0.24, 0.16, 0.11)
const IRON := Color(0.42, 0.42, 0.45)
const HOT := Color(1.0, 0.27, 0.12)
const EGG_SHELL := Color(0.83, 0.86, 0.66)
const EGG_SPOT := Color(0.35, 0.45, 0.2)
const EGG_GLOW := Color(0.55, 1.0, 0.25)
const EGG_SIZE := Vector3(0.62, 0.8, 0.62)
const PIP_BACK := Color(0.08, 0.06, 0.05, 0.85)
const PIP_FILL := Color(0.6, 1.0, 0.3, 0.95)
const MODEL_ID := "javelin"
const MODEL_PATH := "res://assets/models/fx/javelin.glb"
const MANIFEST := "res://assets/models/manifest.json"

const JAVELIN_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
uniform vec4 hot : source_color = vec4(1.0, 0.27, 0.12, 1.0);
varying float glow;
void vertex() {
	glow = INSTANCE_CUSTOM.r;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = hot.rgb * COLOR.a * (0.6 + 4.0 * glow);
	ROUGHNESS = mix(0.85, 0.45, COLOR.a);
	METALLIC = 0.4 * COLOR.a;
}
"""

const EGG_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
uniform vec4 shell : source_color = vec4(0.83, 0.86, 0.66, 1.0);
uniform vec4 spot : source_color = vec4(0.35, 0.45, 0.2, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 1.0, 0.25, 1.0);
uniform float glow = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float n = texture(noise_tex, vec2(lp.x * 1.7 + lp.z * 0.9, lp.y * 1.3)).r;
	float veins = 1.0 - smoothstep(0.015, 0.06, abs(n - 0.5));
	float spots = smoothstep(0.62, 0.7, n);
	ALBEDO = mix(shell.rgb, spot.rgb, spots);
	EMISSION = glow_color.rgb * veins * (0.15 + 2.6 * glow);
	ROUGHNESS = 0.55;
	SPECULAR = 0.45;
}
"""

## Where the owner's javelin is looked up (tests point it elsewhere to see the fallback).
static var model_path := MODEL_PATH
static var _mesh: Mesh
static var _from_model := false

var _javelins := MultiMeshInstance3D.new()
var _jav_mat := ShaderMaterial.new()
var _egg_mesh := SphereMesh.new()
var _pip_mesh := QuadMesh.new()
## Egg nodes by actor id: {"node", "body", "mat", "pip", "fill", "seed"}; idle ones wait in _idle.
var _eggs := {}
var _idle: Array[Dictionary] = []
var _tick := 0
## [at, angle, stuck tick, back tick] per javelin; [pos, permille, hp, max_hp, id] per egg (the last sync).
var _jav: Array = []
var _egg_rows: Array = []
var _drawn := 0
var _tips := PackedVector3Array()


func _init() -> void:
	name = "BossSignatures"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = javelin_mesh()
	mm.instance_count = MAX_JAVELINS
	mm.visible_instance_count = 0
	_javelins.name = "Javelins"
	_javelins.multimesh = mm
	var sh := Shader.new()
	sh.code = JAVELIN_SHADER
	_jav_mat.shader = sh
	_jav_mat.set_shader_parameter("hot", HOT)
	_javelins.material_override = _jav_mat
	_javelins.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_javelins.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_javelins.extra_cull_margin = 16384.0
	add_child(_javelins)
	_egg_mesh.radius = 0.5
	_egg_mesh.height = 1.0
	_egg_mesh.radial_segments = 14
	_egg_mesh.rings = 8
	_pip_mesh.size = Vector2(0.7, 0.09)


func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	_jav.clear()
	_egg_rows.clear()
	var boss := reader.boss_index()
	if boss >= 0:
		_jav = reader.boss_javelins(boss)
	for i in reader.actor_count():
		var e := reader.actor_egg_permille(i)
		if e >= 0:
			_egg_rows.append(
				[
					reader.actor_pos(i),
					e,
					reader.actor_hp(i),
					reader.actor_max_hp(i),
					reader.actor_id(i)
				]
			)
	_sync_eggs()
	_draw(float(_tick))


func _process(_delta: float) -> void:
	if not _jav.is_empty() or not _eggs.is_empty():
		_draw(float(_tick) + Engine.get_physics_interpolation_fraction())


## Javelins drawn in the last draw (tests and the tour).
func javelin_count() -> int:
	return _drawn


## Where the drawn javelins' heads are planted (tests: on the sim's stuck points).
func javelin_tips() -> PackedVector3Array:
	return _tips


## Eggs drawn now (tests and the tour).
func egg_count() -> int:
	return _eggs.size()


## Egg `id`'s node (tests), or null.
func egg_node(id: int) -> Node3D:
	return _eggs[id]["node"] if _eggs.has(id) else null


## Egg `id`'s HP pip fill, 0..1 (tests), or -1.
func egg_pip(id: int) -> float:
	return (_eggs[id]["fill"] as Node3D).scale.x if _eggs.has(id) else -1.0


func _sync_eggs() -> void:
	var live := {}
	for row: Array in _egg_rows:
		var id: int = row[4]
		live[id] = true
		if not _eggs.has(id):
			_eggs[id] = _take_egg(id)
	for id in _eggs.keys():
		if not live.has(id):
			var e: Dictionary = _eggs[id]
			(e["node"] as Node3D).visible = false
			_idle.append(e)
			_eggs.erase(id)


func _take_egg(id: int) -> Dictionary:
	var e: Dictionary
	if not _idle.is_empty():
		e = _idle.pop_back()
	else:
		e = _make_egg()
		add_child(e["node"])
	e["seed"] = id
	(e["node"] as Node3D).visible = true
	return e


func _make_egg() -> Dictionary:
	var root := Node3D.new()
	root.name = "Egg"
	var body := MeshInstance3D.new()
	body.mesh = _egg_mesh
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = EGG_SHADER
	mat.shader = sh
	mat.set_shader_parameter("shell", EGG_SHELL)
	mat.set_shader_parameter("spot", EGG_SPOT)
	mat.set_shader_parameter("glow_color", EGG_GLOW)
	mat.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(body)
	var pip := MeshInstance3D.new()
	pip.mesh = _pip_mesh
	pip.material_override = _pip_material(PIP_BACK, 0)
	pip.position = Vector3(0, EGG_SIZE.y + 0.35, 0)
	pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pip)
	var fill := MeshInstance3D.new()
	fill.mesh = _pip_mesh
	fill.material_override = _pip_material(PIP_FILL, 1)
	fill.position = Vector3(0, 0, 0.001)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pip.add_child(fill)
	return {"node": root, "body": body, "mat": mat, "pip": pip, "fill": fill, "seed": 0}


static func _pip_material(c: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = priority
	return m


func _draw(now: float) -> void:
	var still := ViewPrefs.reduced_motion
	_draw_javelins(now, still)
	for row: Array in _egg_rows:
		var id: int = row[4]
		if _eggs.has(id):
			_pose_egg(_eggs[id], row, now, still)


func _draw_javelins(now: float, still: bool) -> void:
	var buf := PackedFloat32Array()
	var n := 0
	_tips.clear()
	for j: Array in _jav:
		if n >= MAX_JAVELINS:
			break
		var at: Vector2 = j[0]
		var since := now - float(j[2])
		var left := float(j[3]) - now
		var warn := clampf(1.0 - left / RECALL_WARN_TICKS, 0.0, 1.0)
		var yaw := SimPlane.yaw_of(int(j[1]))
		var shake := 0.0 if still else warn * 0.09 * sin(now * 2.3 + float(n) * 1.7)
		var b := (
			Basis(Vector3.UP, yaw + shake) * Basis(Vector3(0, 0, 1), -JAVELIN_PITCH * (1.0 - shake))
		)
		var tip := SimPlane.to_3d(at, -JAVELIN_SINK)
		var dir := b * Vector3(1, 0, 0)
		var land := clampf(since / STICK_TICKS, 0.0, 1.0)  # it slides the last bit in as it lands
		var o := tip - dir * JAVELIN_LENGTH - dir * (0.4 * (1.0 - land))
		buf.append_array(
			[
				b.x.x,
				b.y.x,
				b.z.x,
				o.x,
				b.x.y,
				b.y.y,
				b.z.y,
				o.y,
				b.x.z,
				b.y.z,
				b.z.z,
				o.z,
				warn,
				0.0,
				0.0,
				0.0
			]
		)
		_tips.append(SimPlane.to_3d(at))
		n += 1
	var mm := _javelins.multimesh
	if n > 0:
		buf.resize(mm.instance_count * 16)
		mm.buffer = buf
	mm.visible_instance_count = n
	_drawn = n


## An egg at its spot: its veins glowing with its time, the hatch wobble (harder and faster as it nears), its pip
## bar; a bursting egg swells and splits open.
func _pose_egg(e: Dictionary, row: Array, now: float, still: bool) -> void:
	var node: Node3D = e["node"]
	node.position = SimPlane.to_3d(row[0])
	var k := float(row[1]) / 1000.0
	var sd := float(int(e["seed"]) % 97)
	var wob := 0.0
	if not still:
		var amp := 0.05 + 0.3 * k * k
		var freq := 0.18 + 0.55 * k
		wob = amp * sin(now * freq + sd)
	var body: MeshInstance3D = e["body"]
	var swell := 1.0
	if int(row[1]) >= 1000:  # bursting
		swell = 1.25
	body.transform = Transform3D(
		Basis(Vector3(1, 0, 0.4).normalized(), wob) * Basis.from_scale(EGG_SIZE * swell),
		Vector3(0, EGG_SIZE.y * 0.5 * swell - 0.04, 0)
	)
	(e["mat"] as ShaderMaterial).set_shader_parameter("glow", k * k)
	var frac := clampf(float(row[2]) / maxf(1.0, float(row[3])), 0.0, 1.0)
	var fill: MeshInstance3D = e["fill"]
	fill.scale = Vector3(maxf(frac, 0.001), 1, 1)
	fill.position = Vector3(-_pip_mesh.size.x * 0.5 * (1.0 - frac), 0, 0.001)
	(e["pip"] as Node3D).visible = frac < 1.0 or k > 0.4


## True when the owner's model replaced the code javelin.
static func from_model() -> bool:
	javelin_mesh()
	return _from_model


## The javelin: the owner's model when listed and present, else the code-made one. JAVELIN_LENGTH long along +X from
## the butt (x = 0) to the tip; vertex colours carry the look, alpha the hot head.
static func javelin_mesh() -> Mesh:
	if _mesh == null:
		_mesh = _model_mesh()
		_from_model = _mesh != null
		if _mesh == null:
			_mesh = _code_mesh()
	return _mesh


## Drops the cached mesh (tests switch model_path).
static func clear_cache() -> void:
	_mesh = null
	_from_model = false


## A shaft (a thin octagonal rod), a leather grip and a leaf-shaped iron head with a hot edge.
static func _code_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.032
	shaft.bottom_radius = 0.038
	shaft.height = 1.62
	shaft.radial_segments = 8
	shaft.rings = 1
	var turn := Basis(Vector3(0, 0, 1), -PI * 0.5)  # the cylinder's +Y along +X
	_append(st, shaft, Transform3D(turn, Vector3(0.81, 0, 0)), SHAFT, 0.0)
	var grip := CylinderMesh.new()
	grip.top_radius = 0.045
	grip.bottom_radius = 0.045
	grip.height = 0.26
	grip.radial_segments = 8
	grip.rings = 1
	_append(st, grip, Transform3D(turn, Vector3(0.75, 0, 0)), Color(0.12, 0.08, 0.06), 0.0)
	var socket := CylinderMesh.new()
	socket.top_radius = 0.05
	socket.bottom_radius = 0.036
	socket.height = 0.1
	socket.radial_segments = 8
	socket.rings = 1
	_append(st, socket, Transform3D(turn, Vector3(1.66, 0, 0)), IRON, 0.3)
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.085
	head.height = 0.3
	head.radial_segments = 4
	head.rings = 1
	var flat := Basis.from_scale(Vector3(1.0, 1.0, 0.35))
	_append(st, head, Transform3D(turn * flat, Vector3(1.85, 0, 0)), IRON, 1.0)
	st.generate_normals()
	return st.commit()


static func _append(
	st: SurfaceTool, m: PrimitiveMesh, at: Transform3D, c: Color, hot: float
) -> void:
	var arrays := m.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var col := Color(c.r, c.g, c.b, hot)
	if idx.is_empty():
		for v in verts:
			st.set_color(col)
			st.add_vertex(at * v)
		return
	for k in idx:
		st.set_color(col)
		st.add_vertex(at * verts[k])


## The owner's javelin (javelin.glb), normalised to JAVELIN_LENGTH along its longest axis turned to +X from x = 0, or
## null when it isn't listed in the manifest or isn't on disk.
static func _model_mesh() -> Mesh:
	if not _listed() or not ResourceLoader.exists(model_path):
		return null
	var surface := ModelLibrary.first_surface(load(model_path) as PackedScene)
	if surface.is_empty():
		return null
	var arrays: Array = surface["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var ext := (hi - lo).max(Vector3(0.0001, 0.0001, 0.0001))
	var axis := 0 if ext.x >= ext.y and ext.x >= ext.z else (1 if ext.y >= ext.z else 2)
	var k := JAVELIN_LENGTH / ext[axis]
	var mid := (lo + hi) * 0.5
	for i in verts.size():
		var v := verts[i] - mid
		var along := v[axis] + ext[axis] * 0.5
		var a := v[(axis + 1) % 3]
		var b := v[(axis + 2) % 3]
		verts[i] = Vector3(along * k, a * k, b * k)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if arrays[Mesh.ARRAY_COLOR] == null:
		var cols := PackedColorArray()
		cols.resize(verts.size())
		cols.fill(Color(IRON, 0.0))
		arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _listed() -> bool:
	if not FileAccess.file_exists(MANIFEST):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	for m: Dictionary in (data as Dictionary).get("models", []):
		if String(m.get("id", "")) == MODEL_ID:
			return true
	return false
