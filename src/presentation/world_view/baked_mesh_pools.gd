class_name BakedMeshPools
extends Node3D
## v0.8.0 PF2 (owner O9: "find a way … so the game doesn't have lag"; docs/roadmap/v0.8.0/evidence/PERF.md PF2):
## BladeFormView's crescents and ghost slashes as MultiMesh instances. Each shape (a key: a crescent's width and
## radius, a ghost's width, reach, way and age) is baked once into a mesh by the view, with its colours, and drawn in a
## pool of its own: a crowd of them costs one transform each and one draw call per shape, where the ImmediateMesh
## rebuilt 84 vertices for each one. A sync lays the pools out (begin → add → finish). Presentation only (EI-07).

## The most instances of one shape drawn a sync (the rest wait for room).
const CAPACITY := 256
## The most shapes kept; past it every pool is dropped and rebuilt (a build change; the shapes are few).
const SHAPES_MAX := 96

var _pools := {}  # key -> MultiMeshInstance3D
var _used := {}  # key -> instances added this sync


func begin() -> void:
	for k: Variant in _used:
		_used[k] = 0


## One instance of shape `key` at `xf`; `bake` (key) -> Mesh builds the shape's mesh the first time. False when the
## shape's pool is full.
func add(key: Variant, xf: Transform3D, bake: Callable) -> bool:
	if not _pools.has(key):
		if _pools.size() >= SHAPES_MAX:
			_drop_all()
		_pools[key] = _pool(bake.call(key))
		_used[key] = 0
	var n: int = _used[key]
	if n >= CAPACITY:
		return false
	(_pools[key] as MultiMeshInstance3D).multimesh.set_instance_transform(n, xf)
	_used[key] = n + 1
	return true


func finish() -> void:
	for k: Variant in _pools:
		var mmi: MultiMeshInstance3D = _pools[k]
		mmi.multimesh.visible_instance_count = _used[k]
		mmi.visible = _used[k] > 0


## The instances the last sync added, every shape together.
func used_total() -> int:
	var n := 0
	for k: Variant in _used:
		n += int(_used[k])
	return n


## The shapes with a pool (tests).
func shape_count() -> int:
	return _pools.size()


func _pool(mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# World-space instances spread over the room: never cull the pool by its first instance's box.
	mmi.custom_aabb = AABB(Vector3(-512, -8, -512), Vector3(1024, 32, 1024))
	add_child(mmi)
	return mmi


func _drop_all() -> void:
	for k: Variant in _pools:
		(_pools[k] as MultiMeshInstance3D).queue_free()
	_pools.clear()
	_used.clear()
