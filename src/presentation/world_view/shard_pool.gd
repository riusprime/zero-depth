class_name ShardPool
extends MultiMeshInstance3D
## The flying cubes of one look (a dead enemy's debris, a spark colour): every piece is an instance of one
## multimesh, so a mass kill is one draw per look and no node per cube. A piece flies on gravity, spins, and goes
## when its life in seconds is spent or it falls below the floor. Life is real time, so the pop lasts as long at 144 fps
## as at 60. Presentation only: nothing here reads or feeds the sim.

## The most pieces alive per look: a 120-enemy mass kill is 840 debris pieces. When it is full the piece
## closest to its end gives way to the new one.
const CAPACITY := 1024
const LIFE := 0.5
const GRAVITY := 9.8
const SPIN := Vector3(4, 3, 2)

var _pos: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _rot: Array[Vector3] = []
var _size: Array[float] = []
var _left: Array[float] = []


func _init(p_material: Material) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = p_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# The pieces are in world space, spread over the room: never cull the pool by its first instance's box.
	custom_aabb = AABB(Vector3(-512, -8, -512), Vector3(1024, 64, 1024))
	visible = false


## How many pieces are flying.
func count() -> int:
	return _pos.size()


## Throws one cube of edge `size` from `at` with velocity `vel`; it is drawn from the next `step`.
func throw(at: Vector3, vel: Vector3, size: float) -> void:
	var i := _pos.size()
	if i >= CAPACITY:
		i = _left.find(_left.min())
	else:
		_pos.append(at)
		_vel.append(vel)
		_rot.append(Vector3.ZERO)
		_size.append(size)
		_left.append(LIFE)
	_pos[i] = at
	_vel[i] = vel
	_rot[i] = Vector3.ZERO
	_size[i] = size
	_left[i] = LIFE


## Moves every piece on by `delta` seconds; a pool with nothing flying does nothing.
func step(delta: float) -> void:
	if _pos.is_empty():
		return
	for k in range(_pos.size() - 1, -1, -1):
		_vel[k].y -= GRAVITY * delta
		_pos[k] += _vel[k] * delta
		_rot[k] += SPIN * delta
		_left[k] -= delta
		if _left[k] <= 0.0 or _pos[k].y < 0.0:
			_remove(k)
	_draw()


func _remove(k: int) -> void:
	var last := _pos.size() - 1
	_pos[k] = _pos[last]
	_vel[k] = _vel[last]
	_rot[k] = _rot[last]
	_size[k] = _size[last]
	_left[k] = _left[last]
	_pos.resize(last)
	_vel.resize(last)
	_rot.resize(last)
	_size.resize(last)
	_left.resize(last)


## Writes the live pieces and shows only that many.
func _draw() -> void:
	var n := _pos.size()
	for k in n:
		var b := Basis.from_euler(_rot[k]).scaled(Vector3.ONE * _size[k])
		multimesh.set_instance_transform(k, Transform3D(b, _pos[k]))
	if multimesh.visible_instance_count != n:
		multimesh.visible_instance_count = n
	if visible != (n > 0):
		visible = n > 0


## One piece's position (tests).
func piece_position(k: int) -> Vector3:
	return _pos[k]
