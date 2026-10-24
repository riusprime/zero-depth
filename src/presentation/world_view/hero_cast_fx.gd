class_name HeroCastFx
extends Node3D
## v0.8.0 GF1 (owner O19: "The main character needs to have like a casting animation, just spark of light and swirl
## that comes out of him every time a bullet comes out … very light"): on every Gun shot (WorldReader.shot_fired) a
## spark of light flashes at the casting hand (MUZZLE_M out along the aim and HAND_M to the hero's right, a little over
## the shots' height, beside the shot leaving)
## and a small swirl of light winds out round the aim and fades. PlayerAvatar adds the body's accent.
## - Pooled: POOL flourishes are built once and reused round-robin (nothing is made or freed per shot); their
##   materials are built once and only their parameters change.
## - Cheap at high fire rates: a shot within MERGE_TICKS of the live flourish's start re-lights its spark where the new
##   shot leaves and keeps its swirl turning (one flourish, not one per shot).
## - Reduced motion keeps only the spark (no swirl; PlayerAvatar drops the accent).
## Presentation only (EI-07): it reads WorldReader; its timing is frame time and decides nothing.

const POOL := 4
const MERGE_TICKS := 6
const MUZZLE_M := 0.32
const HAND_M := 0.22
const HEIGHT := SimPlane.CORE_HEIGHT + 0.12
const SPARK_SECONDS := 0.12
const SWIRL_SECONDS := 0.24
## The spark's size (metres across at its peak) and the swirl's turns per second about the aim.
const SPARK_SIZE := 0.6
const SWIRL_TURNS := 2.6

## The spark: a camera-facing quad, a hot round centre with four thin rays, additive; `fade` 1 → 0 over its life.
const SPARK := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 core : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(0.2, 0.8, 0.9, 1.0);
uniform float fade = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float glow = exp(-d * d * 9.0);
	float rays = exp(-abs(q.x) * 40.0) * (1.0 - smoothstep(0.2, 1.0, abs(q.y)))
		+ exp(-abs(q.y) * 40.0) * (1.0 - smoothstep(0.2, 1.0, abs(q.x)));
	float a = clamp(glow + rays * 0.7, 0.0, 1.0) * fade;
	ALBEDO = mix(tint.rgb, core.rgb, clamp(glow * 1.4, 0.0, 1.0)) * 2.0;
	ALPHA = a;
}
"""

## The swirl: a thin strip winding out round the aim (the mesh's x), additive, brighter toward its head (UV.x);
## `fade` 1 → 0 over its life.
const SWIRL := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.2, 0.8, 0.9, 1.0);
uniform float fade = 0.0;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = tint.rgb * 1.8;
	ALPHA = clamp(smoothstep(0.0, 1.0, UV.x) * across * fade, 0.0, 1.0);
}
"""

static var _spark_shader: Shader
static var _swirl_shader: Shader
static var _swirl_mesh: ArrayMesh

## Flourishes started and shots merged into a live one (tests).
var started := 0
var merged := 0
## Each slot: {root, spark, swirl, spark_mat, swirl_mat, age, live, tick, turn}.
var _slots: Array[Dictionary] = []
var _next := 0
var _live := -1


func _ready() -> void:
	_build()


## Builds the pool (once; also on the first sync when not in the tree yet).
func _build() -> void:
	if not _slots.is_empty():
		return
	if _spark_shader == null:
		_spark_shader = Shader.new()
		_spark_shader.code = SPARK
		_swirl_shader = Shader.new()
		_swirl_shader.code = SWIRL
		_swirl_mesh = swirl_mesh()
	var cols := HeroPulseViews.colors(ElementLooks.player_energy())  # MP2: violet under The Fallen
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for k in POOL:
		var root := Node3D.new()
		root.name = "Cast%d" % k
		root.visible = false
		root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(root)
		var sm := ShaderMaterial.new()
		sm.shader = _spark_shader
		sm.set_shader_parameter("core", cols[0])
		sm.set_shader_parameter("tint", cols[2])
		var spark := MeshInstance3D.new()
		spark.mesh = quad
		spark.material_override = sm
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.extra_cull_margin = 1.0
		root.add_child(spark)
		var wm := ShaderMaterial.new()
		wm.shader = _swirl_shader
		wm.set_shader_parameter("tint", cols[2])
		var swirl := MeshInstance3D.new()
		swirl.mesh = _swirl_mesh
		swirl.material_override = wm
		swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		swirl.extra_cull_margin = 1.0
		root.add_child(swirl)
		(
			_slots
			. append(
				{
					"root": root,
					"spark": spark,
					"swirl": swirl,
					"spark_mat": sm,
					"swirl_mat": wm,
					"age": 0.0,
					"spark_age": 0.0,
					"live": false,
					"tick": -1000000,
					"turn": 0.0,
				}
			)
		)


func sync(reader: WorldReader) -> void:
	_build()
	if not reader.shot_fired() or reader.player_dead():
		return
	var tick := reader.tick()
	var dir := Kin.dir(reader.aim_angle())
	var right := Vector2(dir.y, -dir.x)
	var at := SimPlane.to_3d(reader.player_pos() + dir * MUZZLE_M + right * HAND_M, HEIGHT)
	var yaw := SimPlane.yaw_of(reader.aim_angle())
	if _live >= 0 and _slots[_live]["live"] and tick - int(_slots[_live]["tick"]) < MERGE_TICKS:
		var s := _slots[_live]
		s["spark_age"] = 0.0  # the spark re-lights where this shot leaves; the swirl keeps turning
		(s["root"] as Node3D).position = at
		(s["root"] as Node3D).rotation = Vector3(0, yaw, 0)
		merged += 1
		_apply(s)
		return
	var slot := _slots[_next]
	_next = (_next + 1) % POOL
	_live = _slots.find(slot)
	slot["age"] = 0.0
	slot["spark_age"] = 0.0
	slot["live"] = true
	slot["tick"] = tick
	slot["turn"] = float(started % 4) * 0.5 * PI
	var root: Node3D = slot["root"]
	root.position = at
	root.rotation = Vector3(0, yaw, 0)
	root.visible = true
	started += 1
	_apply(slot)


func _process(delta: float) -> void:
	for s in _slots:
		if not s["live"]:
			continue
		s["age"] = float(s["age"]) + delta
		s["spark_age"] = float(s["spark_age"]) + delta
		s["turn"] = float(s["turn"]) + delta * TAU * SWIRL_TURNS
		_apply(s)


## How many flourishes are showing now, and the pool's size (tests).
func live_count() -> int:
	var n := 0
	for s in _slots:
		n += 1 if s["live"] else 0
	return n


func pool_size() -> int:
	return _slots.size()


## Whether slot `k`'s swirl shows (tests: reduced motion keeps only the spark).
func swirl_visible(k: int) -> bool:
	return (_slots[k]["swirl"] as Node3D).visible and (_slots[k]["root"] as Node3D).visible


func spark_visible(k: int) -> bool:
	return (_slots[k]["spark"] as Node3D).visible and (_slots[k]["root"] as Node3D).visible


func _apply(s: Dictionary) -> void:
	var sp := clampf(float(s["spark_age"]) / SPARK_SECONDS, 0.0, 1.0)
	var sw := clampf(float(s["age"]) / SWIRL_SECONDS, 0.0, 1.0)
	var spark: MeshInstance3D = s["spark"]
	spark.visible = sp < 1.0
	spark.scale = Vector3.ONE * SPARK_SIZE * lerpf(0.55, 1.0, sqrt(sp))
	(s["spark_mat"] as ShaderMaterial).set_shader_parameter("fade", 1.0 - sp * sp)
	var swirl: MeshInstance3D = s["swirl"]
	swirl.visible = sw < 1.0 and not ViewPrefs.reduced_motion
	swirl.rotation = Vector3(float(s["turn"]), 0, 0)
	swirl.scale = Vector3.ONE * lerpf(0.6, 1.15, sw)
	(s["swirl_mat"] as ShaderMaterial).set_shader_parameter("fade", 1.0 - sw * sw)
	if sp >= 1.0 and (sw >= 1.0 or ViewPrefs.reduced_motion):
		s["live"] = false
		(s["root"] as Node3D).visible = false


## The swirl's strip: 1.25 turns round the x axis, winding out from 0.04 m to 0.17 m across while it runs 0.05 m back
## to 0.3 m forward (UV.x 0 at its tail, 1 at its head), 0.08 m wide.
static func swirl_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var segs := 18
	var pts := []
	for k in segs + 1:
		var u := float(k) / segs
		var a := u * TAU * 1.25
		var r := lerpf(0.04, 0.17, u)
		pts.append([Vector3(lerpf(-0.05, 0.3, u), cos(a) * r, sin(a) * r), u, a])
	for k in segs:
		var p0: Array = pts[k]
		var p1: Array = pts[k + 1]
		var w0 := Vector3(0.0, cos(p0[2]), sin(p0[2])) * 0.04
		var w1 := Vector3(0.0, cos(p1[2]), sin(p1[2])) * 0.04
		var quad := [
			[p0[0] - w0, Vector2(p0[1], 0)],
			[p1[0] - w1, Vector2(p1[1], 0)],
			[p1[0] + w1, Vector2(p1[1], 1)],
			[p0[0] - w0, Vector2(p0[1], 0)],
			[p1[0] + w1, Vector2(p1[1], 1)],
			[p0[0] + w0, Vector2(p0[1], 1)],
		]
		for q: Array in quad:
			verts.append(q[0])
			uvs.append(q[1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
