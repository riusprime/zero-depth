class_name AttackFormPool
extends MultiMeshInstance3D
## v0.6.0 MX3: one MultiMesh pool of an attack form's layer (or a particle kind): a fixed number of instances,
## refilled every drawn frame (begin → add → finish) and shown up to the count added. One draw call per pool however
## many attacks are on screen; a pool never grows, so a crowd of attacks costs no allocation (PRESENTATION §7).

var capacity := 0
var used := 0
## What was added this frame, kept on the CPU side too (the headless renderer keeps no instance buffer to read back).
var _xfs: Array[Transform3D] = []
var _colors := PackedColorArray()


func _init(p_name: StringName, p_mesh: Mesh, material: Material, p_capacity: int) -> void:
	name = String(p_name)
	capacity = p_capacity
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = p_mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	_xfs.resize(capacity)
	_colors.resize(capacity)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# The instances are in world space and spread over the room: never cull the pool by its first instance's box.
	custom_aabb = AABB(Vector3(-512, -8, -512), Vector3(1024, 32, 1024))


func begin() -> void:
	used = 0


## Adds one instance; false (and nothing drawn) once the pool is full.
func add(xf: Transform3D, c: Color) -> bool:
	if used >= capacity:
		return false
	multimesh.set_instance_transform(used, xf)
	multimesh.set_instance_color(used, c)
	_xfs[used] = xf
	_colors[used] = c
	used += 1
	return true


func finish() -> void:
	multimesh.visible_instance_count = used
	visible = used > 0


func room() -> int:
	return capacity - used


## The instance's transform and colour as last added (tests).
func instance_transform(i: int) -> Transform3D:
	return _xfs[i]


func instance_color(i: int) -> Color:
	return _colors[i]
