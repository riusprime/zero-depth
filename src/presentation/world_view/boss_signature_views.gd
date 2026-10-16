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
## v0.8.0 BS2 (S4-S6):
## - The Hive Lens's Gaze (WorldReader.boss_gaze): through its windup the eye brightens (a flare and a light at the
##   eye) and a thin aim line runs the way the beam will open; then a real 3D beam, a hot core and a wider glow (two
##   cylinders, a scrolling noise shader) from the eye down to where it strikes, a burning strip on the floor under
##   it, and where a wall stopped it a flare, a light and scorch marks left on the floor (fading over SCORCH_TICKS).
##   Built here, not in the telegraph or VFX drawers (the Focus Beam's are AV2's).
## - The Siege Engine's ricochets: a spark burst where a hostile shot bounced off a wall (its bounce tick).
## - The Foundry's molten floor (WorldReader.boss_lava): each piece a churning lava quad that wells up and crusts over
##   its last LAVA_CRUST_TICKS; its meltdown (WorldReader.boss_melts): the room's floor beyond the melt's radius
##   molten, the cool bridge to the exit left out, the ring that melts next glowing and pulsing while it is warned.
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

## v0.8.0 BS2: the Gaze's colours, the eye's height (the Hive Lens hovers) and where the beam meets the floor's
## height at its far end; the aim line's radius; scorch marks, sparks and the lava's timing.
const GAZE := Color(1.0, 0.22, 0.52)
const GAZE_CORE := Color(1.0, 0.86, 0.95)
const EYE_Y := HiveLensAvatar.HOVER_Y
const BEAM_END_Y := 0.7
## The eye's front, this far out from the body's centre along the beam (m): the flare sits on it.
const EYE_OUT := 1.15
const AIM_RADIUS := 0.07
const SCORCH_MAX := 96
const SCORCH_TICKS := 150.0
const SCORCH_EVERY := 3
const SPARK_MAX := 48
const SPARK_TICKS := 12.0
const LAVA_FADE_TICKS := 8.0
const LAVA_CRUST_TICKS := 60.0
## v0.8.0 TX2: the lava and meltdown shaders' owner textures (BossStrikeMeshes.GROUND_TEX slots).
const LAVA_SLOTS := ["lava_tex", "crust_tex"]

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
## v0.8.0 BS2: the Gaze (its last sync's state, the eye's sim position added), its meshes and lights; scorch marks
## [at, tick, seed]; ricochet sparks [at, tick] and each hostile shot's last bounce tick seen (by id); lava and melt
## rows (the last sync) and their pooled nodes.
var _gaze := {}
var _gaze_ends: Array = []
var _beam := MeshInstance3D.new()
var _beam_glow := MeshInstance3D.new()
var _beam_floor := MeshInstance3D.new()
var _aim := MeshInstance3D.new()
var _eye_flare := MeshInstance3D.new()
var _impact := MeshInstance3D.new()
var _eye_light := OmniLight3D.new()
var _impact_light := OmniLight3D.new()
var _scorch := MultiMeshInstance3D.new()
var _scorch_rows: Array = []
var _scorch_tick := -1
var _sparks := MultiMeshInstance3D.new()
var _spark_rows: Array = []
var _bounced := {}
var _lava_rows: Array = []
var _lava_nodes: Array[MeshInstance3D] = []
var _lava_shader := Shader.new()
var _melt_rows: Array = []
var _melt_nodes: Array[MeshInstance3D] = []
var _melt_shader := Shader.new()


func _init() -> void:
	name = "BossSignatures"
	# v0.8.0 N1 (O55, the lighting audit): everything here is laid out in _draw on frame time (ticks plus the
	# fraction), its lights, scorch and spark pools included: no physics interpolation on top (as VfxCore).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	_init_bs2()


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
	_sync_bs2(reader, boss)
	_draw(float(_tick))


func _process(_delta: float) -> void:
	if not _jav.is_empty() or not _eggs.is_empty() or _bs2_busy():
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
	_draw_bs2(now, still)


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


# --- v0.8.0 BS2: the Gaze, the ricochet sparks, the lava and the meltdown -----------------------------------------


func _init_bs2() -> void:
	var beam_sh := Shader.new()
	beam_sh.code = BossSignatureShaders.BEAM
	for part: Array in [[_beam, 1.0], [_beam_glow, 0.35], [_aim, 0.6]]:
		var mi: MeshInstance3D = part[0]
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.0
		cyl.height = 1.0
		cyl.radial_segments = 12
		cyl.rings = 6
		mi.mesh = cyl
		var m := ShaderMaterial.new()
		m.shader = beam_sh
		m.set_shader_parameter("color", GAZE)
		m.set_shader_parameter("core", GAZE_CORE)
		m.set_shader_parameter("strength", part[1])
		m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
		if mi == _aim:  # v0.8.0 TX1: the owner's dashed aim line, the owner's beam strip
			FxTextures.texture_beam(m, "fx_aim_lines", FxTextures.AIM_DASHED, 6.0, false, 0.6)
		else:
			FxTextures.texture_beam(m, "fx_beam", 3, 5.0, false, 0.5)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		mi.extra_cull_margin = 64.0
		add_child(mi)
	_beam.name = "GazeBeam"
	_beam_glow.name = "GazeGlow"
	_aim.name = "GazeAim"
	var strip := QuadMesh.new()
	strip.size = Vector2.ONE
	strip.orientation = PlaneMesh.FACE_Y
	_beam_floor.name = "GazeFloor"
	_beam_floor.mesh = strip
	var fm := ShaderMaterial.new()
	var fs := Shader.new()
	fs.code = BossSignatureShaders.FLOOR
	fm.shader = fs
	fm.set_shader_parameter("color", GAZE)
	_beam_floor.material_override = fm
	_beam_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam_floor.visible = false
	add_child(_beam_floor)
	var flare := SphereMesh.new()
	flare.radius = 0.5
	flare.height = 1.0
	flare.radial_segments = 10
	flare.rings = 5
	for mi: MeshInstance3D in [_eye_flare, _impact]:
		mi.mesh = flare
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = GAZE_CORE
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
	var impact := FxTextures.flare_material(GAZE, GAZE_CORE, 2)  # v0.8.0 TX1: the owner's impact flare
	if impact != null:
		_impact.mesh = FxTextures.flare_mesh()
		_impact.material_override = impact
	_eye_flare.name = "GazeEye"
	_impact.name = "GazeImpact"
	for l: OmniLight3D in [_eye_light, _impact_light]:
		l.light_color = GAZE
		l.omni_range = 4.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
	_eye_light.name = "GazeEyeLight"
	_impact_light.name = "GazeImpactLight"
	_impact_light.omni_range = 5.0
	_scorch.name = "Scorch"
	_scorch.multimesh = _flat_multimesh(SCORCH_MAX, 0.9)
	var sm := ShaderMaterial.new()
	var ss := Shader.new()
	ss.code = BossSignatureShaders.SCORCH
	sm.shader = ss
	sm.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	_scorch.material_override = sm
	_scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scorch.extra_cull_margin = 16384.0
	add_child(_scorch)
	_sparks.name = "RicochetSparks"
	_sparks.multimesh = _flat_multimesh(SPARK_MAX, 1.0, false)
	var pm := ShaderMaterial.new()
	var ps := Shader.new()
	ps.code = BossSignatureShaders.SPARK
	pm.shader = ps
	_sparks.material_override = pm
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.extra_cull_margin = 16384.0
	add_child(_sparks)
	_lava_shader.code = BossSignatureShaders.LAVA
	_melt_shader.code = BossSignatureShaders.MELT


## A MultiMesh of quads (flat on the floor, or facing the camera) with a custom float per instance.
static func _flat_multimesh(n: int, size: float, flat: bool = true) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	if flat:
		q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	mm.instance_count = n
	mm.visible_instance_count = 0
	return mm


func _sync_bs2(reader: WorldReader, boss: int) -> void:
	_gaze = {}
	if boss >= 0:
		var g := reader.boss_gaze(boss)
		if not g.is_empty():
			g["eye"] = reader.actor_pos(boss)
			_gaze = g
			if (
				not g["winding"]
				and g["hit"]
				and _tick % SCORCH_EVERY == 0
				and _tick != _scorch_tick
			):
				_scorch_tick = _tick
				_scorch_rows.append([g["to"], float(_tick), float(_scorch_rows.size() % 7)])
	while (
		_scorch_rows.size() > SCORCH_MAX
		or (not _scorch_rows.is_empty() and float(_tick) - float(_scorch_rows[0][1]) > SCORCH_TICKS)
	):
		_scorch_rows.pop_front()
	_lava_rows = reader.boss_lava()
	_melt_rows = reader.boss_melts()
	var seen := {}
	for k in reader.projectile_count():
		if reader.projectile_team(k) != WorldReader.TEAM_ENEMY:
			continue
		var bt := reader.projectile_bounce_tick(k)
		var id := reader.projectile_id(k)
		seen[id] = bt
		if bt >= 0 and int(_bounced.get(id, -1)) != bt:
			_spark_rows.append([reader.projectile_pos(k), float(_tick)])
	_bounced = seen
	while (
		_spark_rows.size() > SPARK_MAX
		or (not _spark_rows.is_empty() and float(_tick) - float(_spark_rows[0][1]) > SPARK_TICKS)
	):
		_spark_rows.pop_front()
	_sync_lava_nodes()
	_sync_melt_nodes()


func _bs2_busy() -> bool:
	return (
		not _gaze.is_empty()
		or not _lava_rows.is_empty()
		or not _melt_rows.is_empty()
		or not _spark_rows.is_empty()
		or not _scorch_rows.is_empty()
	)


## True while the Gaze is drawn (its aim line in the windup, its beam after; tests and the tour).
func gaze_drawn() -> bool:
	return _beam.visible or _aim.visible


## The drawn beam's (or aim line's) ends in 3D, [from, to] (tests: on the sim's beam), or [].
func gaze_ends() -> Array:
	return _gaze_ends


## Molten floor pieces and meltdowns drawn now (tests and the tour).
func lava_count() -> int:
	var n := 0
	for mi: MeshInstance3D in _lava_nodes:
		n += 1 if mi.visible else 0
	return n


func melt_count() -> int:
	var n := 0
	for mi: MeshInstance3D in _melt_nodes:
		n += 1 if mi.visible else 0
	return n


## Ricochet sparks showing now (tests and the tour).
func spark_count() -> int:
	return _sparks.multimesh.visible_instance_count


func _draw_bs2(now: float, still: bool) -> void:
	_draw_gaze(now, still)
	_draw_scorch(now)
	_draw_sparks(now)
	_draw_lava(now)
	_draw_melt()


## The Gaze: in the windup the eye brightens and a thin aim line runs the way the beam will open; then the beam, a
## core and a glow cylinder from the eye down to where it strikes, a burning strip on the floor under it, a flare and
## a light at the impact point when a wall stopped it.
func _draw_gaze(now: float, still: bool) -> void:
	_gaze_ends = []
	var on := not _gaze.is_empty()
	for n: Node3D in [
		_beam, _beam_glow, _beam_floor, _aim, _eye_flare, _eye_light, _impact, _impact_light
	]:
		n.visible = false
	if not on:
		return
	var g := _gaze
	var p := float(g["progress"]) / 1000.0
	var d := Kin.dir(int(g["angle"]))
	var eye := SimPlane.to_3d((g["eye"] as Vector2) + d * EYE_OUT, EYE_Y)
	var to := SimPlane.to_3d(g["to"], BEAM_END_Y)
	var flicker := 1.0 if still else 0.85 + 0.15 * sin(now * 0.9)
	_eye_flare.visible = true
	_eye_light.visible = true
	_eye_flare.position = eye
	var bright := p if g["winding"] else 1.0
	_eye_flare.scale = Vector3.ONE * (0.3 + 0.5 * bright)
	_eye_light.position = eye
	_eye_light.light_energy = 0.4 + 3.0 * bright * flicker
	if g["winding"]:
		_aim.visible = true
		_place_cylinder(_aim, eye, to, AIM_RADIUS * (0.6 + 0.4 * p))
		(_aim.material_override as ShaderMaterial).set_shader_parameter("strength", 0.6 + 1.4 * p)
		_gaze_ends = [eye, to]
		return
	var hw := float(g["half_width"])
	_beam.visible = true
	_beam_glow.visible = true
	_place_cylinder(_beam, eye, to, hw * 0.45)
	_place_cylinder(_beam_glow, eye, to, hw * (1.05 + (0.0 if still else 0.08 * sin(now * 1.7))))
	_gaze_ends = [eye, to]
	var from2: Vector2 = g["from"]
	var to2: Vector2 = g["to"]
	_beam_floor.visible = true
	var mid := (from2 + to2) * 0.5
	var len := Kin.length(to2 - from2)
	_beam_floor.transform = Transform3D(
		(
			Basis(Vector3.UP, SimPlane.yaw_of(int(g["angle"])))
			* Basis.from_scale(Vector3(len, 1, hw * 2.0))
		),
		SimPlane.to_3d(mid, 0.03)
	)
	if g["hit"]:
		_impact.visible = true
		_impact_light.visible = true
		_impact.position = to
		_impact.scale = Vector3.ONE * (0.7 + (0.0 if still else 0.2 * sin(now * 2.3)))
		if _impact.material_override is ShaderMaterial:
			(_impact.material_override as ShaderMaterial).set_shader_parameter(
				"motion", 0.0 if still else 1.0
			)
		_impact_light.position = to + Vector3(0, 0.4, 0)
		_impact_light.light_energy = 3.5 * flicker


## Puts a unit cylinder (its axis +Y, height 1, radius 1) from a to b with radius r.
static func _place_cylinder(mi: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	var y := b - a
	var len := maxf(y.length(), 0.001)
	var yn := y / len
	var side := Vector3.UP if absf(yn.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := yn.cross(side).normalized()
	var z := x.cross(yn).normalized()
	mi.transform = Transform3D(Basis(x * r, yn * len, z * r), (a + b) * 0.5)


## Scorch marks the beam burnt where it struck: dark and glowing, fading over SCORCH_TICKS.
func _draw_scorch(now: float) -> void:
	var mm := _scorch.multimesh
	var buf := PackedFloat32Array()
	var n := 0
	for row: Array in _scorch_rows:
		var age := clampf((now - float(row[1])) / SCORCH_TICKS, 0.0, 1.0)
		var at := SimPlane.to_3d(row[0], 0.025 + 0.001 * float(n % 5))
		var s := 0.8 + 0.25 * float(row[2]) / 7.0
		var b := Basis(Vector3.UP, float(row[2])) * Basis.from_scale(Vector3(s, 1, s))
		buf.append_array(
			[b.x.x, b.y.x, b.z.x, at.x, b.x.y, b.y.y, b.z.y, at.y, b.x.z, b.y.z, b.z.z, at.z]
		)
		buf.append_array([age, float(row[2]), 0.0, 0.0])
		n += 1
	if n > 0:
		buf.resize(mm.instance_count * 16)
		mm.buffer = buf
	mm.visible_instance_count = n


## A ricochet's spark burst where a hostile shot bounced off a wall: a hot star facing the camera that flashes and
## shrinks over SPARK_TICKS.
func _draw_sparks(now: float) -> void:
	var mm := _sparks.multimesh
	var buf := PackedFloat32Array()
	var n := 0
	for row: Array in _spark_rows:
		var age := clampf((now - float(row[1])) / SPARK_TICKS, 0.0, 1.0)
		var at := SimPlane.to_3d(row[0], SimPlane.CORE_HEIGHT)
		buf.append_array([1, 0, 0, at.x, 0, 1, 0, at.y, 0, 0, 1, at.z, age, 0, 0, 0])
		n += 1
	if n > 0:
		buf.resize(mm.instance_count * 16)
		mm.buffer = buf
	mm.visible_instance_count = n


func _sync_lava_nodes() -> void:
	while _lava_nodes.size() < _lava_rows.size():
		var mi := MeshInstance3D.new()
		mi.name = "Lava"
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.orientation = PlaneMesh.FACE_Y
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = _lava_shader
		m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
		BossStrikeMeshes.set_ground_textures(m, LAVA_SLOTS)  # v0.8.0 TX2: the owner's lava and crust
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_lava_nodes.append(mi)
	for k in _lava_nodes.size():
		var mi := _lava_nodes[k]
		mi.visible = k < _lava_rows.size()
		if mi.visible:
			var r: Rect2 = _lava_rows[k][0]
			mi.transform = Transform3D(
				Basis.from_scale(Vector3(r.size.x, 1, r.size.y)),
				SimPlane.to_3d(r.get_center(), 0.035)
			)


## Molten floor: it wells up over LAVA_FADE_TICKS, churns, and crusts over its last LAVA_CRUST_TICKS.
func _draw_lava(now: float) -> void:
	for k in mini(_lava_rows.size(), _lava_nodes.size()):
		var row: Array = _lava_rows[k]
		var m := _lava_nodes[k].material_override as ShaderMaterial
		var since := now - float(row[1])
		var left := float(row[2]) - now
		m.set_shader_parameter("fade", clampf(since / LAVA_FADE_TICKS, 0.0, 1.0))
		m.set_shader_parameter("cool", clampf(1.0 - left / LAVA_CRUST_TICKS, 0.0, 1.0))


func _sync_melt_nodes() -> void:
	while _melt_nodes.size() < _melt_rows.size():
		var mi := MeshInstance3D.new()
		mi.name = "Meltdown"
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.orientation = PlaneMesh.FACE_Y
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = _melt_shader
		m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
		BossStrikeMeshes.set_ground_textures(m, LAVA_SLOTS)  # v0.8.0 TX2: the owner's lava and crust
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 64.0
		add_child(mi)
		_melt_nodes.append(mi)
	for k in _melt_nodes.size():
		_melt_nodes[k].visible = k < _melt_rows.size()


## The meltdown: the room's floor beyond its radius molten (the lava look), the cool bridge to the exit left out, and
## the ring that melts next glowing and pulsing while it is warned (the whole outer ring through the windup).
func _draw_melt() -> void:
	for k in mini(_melt_rows.size(), _melt_nodes.size()):
		var row: Dictionary = _melt_rows[k]
		var mi := _melt_nodes[k]
		var r: Rect2 = row["bound"]
		mi.transform = Transform3D(
			Basis.from_scale(Vector3(r.size.x, 1, r.size.y)), SimPlane.to_3d(r.get_center(), 0.03)
		)
		var m := mi.material_override as ShaderMaterial
		var c := SimPlane.to_3d(row["centre"])
		var e := SimPlane.to_3d(row["exit"])
		var radius := float(row["radius"])
		m.set_shader_parameter("centre", Vector2(c.x, c.z))
		m.set_shader_parameter("radius", radius if radius < 100000.0 else 100000.0)
		m.set_shader_parameter("next", float(row["next"]))
		m.set_shader_parameter(
			"warn", float(row["warn"]) / 1000.0 if int(row["warn"]) >= 0 else -1.0
		)
		m.set_shader_parameter("bridge", 1.0 if row["bridge"] else 0.0)
		m.set_shader_parameter("bridge_to", Vector2(e.x, e.z))
		m.set_shader_parameter("bridge_half", float(row["half"]))
