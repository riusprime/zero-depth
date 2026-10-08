class_name RewardViews
extends Node3D
## Altars and chests (v0.3.0 E). Low-poly, faceted stone like the gate:
## - an altar: a hexagonal stone plinth with a blue-white rune crystal floating and turning above it, three small
##   shards orbiting it, and a cold light;
## - a chest: a stone chest with iron bands and a red-glowing lock; its price floats above it while you are near,
##   red when you can't afford it. A refused open shakes it.
## The reward you can open now glows brighter. A node disappears when the sim removes its reward. Glowing
## materials have emission on from creation; only energies change at runtime (flash-safe).

const ALTAR_GLOW := Color("#CFE8FF")
const ALTAR_LIGHT := Color("#9CC8FF")
## v0.5.0 RT: a Deep floor's epic altar glows the Deep gate's violet.
const EPIC_GLOW := Color("#B47CFF")
const EPIC_LIGHT := Color("#8B3DFF")
const LOCK_RED := Color("#FF3B30")
const STONE := Color("#77706A")
const STONE_TOP := Color("#8B847D")
const IRON := Color("#3A3D44")
## The price shows within this distance (m).
const PRICE_NEAR_M := 4.5
const PRICE_OK := Color("#F4F1EA")
const PRICE_POOR := Color("#FF4A3D")
const SHAKE_S := 0.35

var _nodes := {}
var _t := 0.0
var _reach_id := -1
var _denied_tick := -1
## id -> seconds of shake left.
var _shake := {}
var _rune_mat := StandardMaterial3D.new()
var _epic_mat := StandardMaterial3D.new()
var _lock_mat := StandardMaterial3D.new()


func _init() -> void:
	name = "Rewards"
	_rune_mat.albedo_color = ALTAR_GLOW
	_rune_mat.emission_enabled = true
	_rune_mat.emission = ALTAR_GLOW
	_rune_mat.emission_energy_multiplier = 2.2
	_epic_mat.albedo_color = EPIC_GLOW
	_epic_mat.emission_enabled = true
	_epic_mat.emission = EPIC_GLOW
	_epic_mat.emission_energy_multiplier = 2.6
	_lock_mat.albedo_color = LOCK_RED
	_lock_mat.emission_enabled = true
	_lock_mat.emission = LOCK_RED
	_lock_mat.emission_energy_multiplier = 2.6


func sync(reader: WorldReader) -> void:
	var live := {}
	var p := reader.player_pos()
	var reach := reader.reward_in_reach()
	_reach_id = reader.reward_id(reach) if reach >= 0 else -1
	for i in reader.reward_count():
		var id := reader.reward_id(i)
		live[id] = true
		var n: Node3D = _nodes.get(id)
		if n == null:
			var altar := reader.reward_kind(i) == WorldReader.REWARD_ALTAR
			n = make_altar(reader.reward_is_epic(i)) if altar else make_chest()
			n.position = SimPlane.to_3d(reader.reward_pos(i))
			add_child(n)
			n.reset_physics_interpolation()
			_nodes[id] = n
		var label: Label3D = n.get_meta(&"price") if n.has_meta(&"price") else null
		if label != null:
			label.text = str(reader.reward_price(i))
			label.modulate = PRICE_OK if reader.reward_affordable(i) else PRICE_POOR
			label.visible = reader.reward_pos(i).distance_to(p) <= PRICE_NEAR_M
	if reader.reward_denied_tick() != _denied_tick:
		_denied_tick = reader.reward_denied_tick()
		if _denied_tick >= 0:
			_shake[reader.reward_denied_id()] = SHAKE_S
	for id in _nodes.keys():
		if not live.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)
			_shake.erase(id)


func count() -> int:
	return _nodes.size()


## The node of reward `id` (tests and shot scripts), or null.
func node_of(id: int) -> Node3D:
	return _nodes.get(id)


func price_label(id: int) -> Label3D:
	var n: Node3D = _nodes.get(id)
	return n.get_meta(&"price") if n != null and n.has_meta(&"price") else null


func _process(delta: float) -> void:
	_t += delta
	for id: int in _nodes:
		var n: Node3D = _nodes[id]
		var hot := id == _reach_id
		var light: OmniLight3D = n.get_meta(&"light")
		light.light_energy = move_toward(
			light.light_energy, n.get_meta(&"energy") * (1.8 if hot else 1.0), delta * 4.0
		)
		var spin: Node3D = n.get_meta(&"spin") if n.has_meta(&"spin") else null
		if spin != null:
			spin.position.y = 1.25 + sin(_t * 2.0 + n.position.x) * 0.07
			spin.rotation.y = _t * (1.6 if hot else 0.9)
		var body: Node3D = n.get_meta(&"body")
		var left: float = _shake.get(id, 0.0)
		if left > 0.0:
			left = maxf(0.0, left - delta)
			_shake[id] = left
			body.position.x = sin(left * 70.0) * 0.06 * (left / SHAKE_S)
		else:
			body.position.x = 0.0


## A hexagonal stone plinth with a floating rune crystal (blue-white) and three orbiting shards.
func make_altar(epic: bool = false) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var stone := _stone_mat(STONE)
	var top := _stone_mat(STONE_TOP)
	body.add_child(_mesh(prism(6, 0.62, 0.56, 0.16, 0.0, 0.0, 3), stone))
	body.add_child(_mesh(prism(6, 0.36, 0.3, 0.52, 0.16, 0.26, 5), stone))
	body.add_child(_mesh(prism(6, 0.48, 0.44, 0.13, 0.68, 0.0, 7), top))
	var spin := Node3D.new()
	spin.position.y = 1.25
	root.add_child(spin)
	var glow := _epic_mat if epic else _rune_mat  # v0.5.0 RT: the epic altar's violet
	var rune := _mesh(bipyramid(4, 0.17, 0.3, 0.3), glow)
	rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spin.add_child(rune)
	for k in 3:
		var a := TAU * k / 3.0
		var shard := _mesh(bipyramid(3, 0.05, 0.1, 0.1), glow)
		shard.position = Vector3(cos(a) * 0.42, -0.1 + 0.08 * k, sin(a) * 0.42)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spin.add_child(shard)
	var light := OmniLight3D.new()
	light.light_color = EPIC_LIGHT if epic else ALTAR_LIGHT
	light.light_energy = 0.9
	light.omni_range = 3.0
	light.position.y = 1.2
	root.add_child(light)
	root.set_meta(&"body", body)
	root.set_meta(&"spin", spin)
	root.set_meta(&"light", light)
	root.set_meta(&"energy", 0.9)
	root.set_meta(&"epic", epic)
	return root


## A stone chest with a sloped lid, iron bands and a red-glowing lock; its price floats above it.
func make_chest() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var stone := _stone_mat(STONE)
	var top := _stone_mat(STONE_TOP)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.metallic = 0.6
	iron.roughness = 0.55
	# Sim +y is 3D -z; the chest faces 3D +z (toward the camera's side), its long side along x.
	body.add_child(_box(Vector3(1.0, 0.5, 0.62), Vector3(0, 0.25, 0), Vector3.ZERO, stone))
	body.add_child(_box(Vector3(1.06, 0.1, 0.68), Vector3(0, 0.05, 0), Vector3.ZERO, top))
	body.add_child(_box(Vector3(1.04, 0.14, 0.4), Vector3(0, 0.6, 0.13), Vector3(28, 0, 0), top))
	body.add_child(_box(Vector3(1.04, 0.14, 0.4), Vector3(0, 0.6, -0.13), Vector3(-28, 0, 0), top))
	for x in [-0.33, 0.33]:
		body.add_child(_box(Vector3(0.09, 0.56, 0.66), Vector3(x, 0.3, 0), Vector3.ZERO, iron))
		body.add_child(_box(Vector3(0.09, 0.1, 0.44), Vector3(x, 0.66, 0), Vector3.ZERO, iron))
	body.add_child(_box(Vector3(0.24, 0.22, 0.08), Vector3(0, 0.42, 0.33), Vector3.ZERO, iron))
	var lock := _mesh(bipyramid(4, 0.07, 0.07, 0.07), _lock_mat)
	lock.position = Vector3(0, 0.42, 0.39)
	lock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(lock)
	var light := OmniLight3D.new()
	light.light_color = LOCK_RED
	light.light_energy = 0.7
	light.omni_range = 2.0
	light.position = Vector3(0, 0.5, 0.6)
	root.add_child(light)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 72
	label.outline_size = 16
	label.pixel_size = 0.008
	label.position.y = 1.45
	label.visible = false
	root.add_child(label)
	var gem := _mesh(bipyramid(4, 0.08, 0.12, 0.12), ShardViews.shared_material())
	gem.position = Vector3(-0.5, 0.0, 0)
	label.add_child(gem)
	root.set_meta(&"body", body)
	root.set_meta(&"light", light)
	root.set_meta(&"energy", 0.7)
	root.set_meta(&"price", label)
	return root


func _stone_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.vertex_color_use_as_albedo = true
	return m


func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	return n


func _box(size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var n := _mesh(b, mat)
	n.position = pos
	n.rotation_degrees = rot_deg
	return n


## A flat-shaded prism: `sides` around, radius r0 at y0 and r1 at y0 + h, the top ring turned by `twist`
## radians; each facet tinted a little (from `salt`) so the planes read apart.
static func prism(
	sides: int, r0: float, r1: float, h: float, y0: float, twist: float, salt: int
) -> ArrayMesh:
	var tris := []
	var top := Vector3(0, y0 + h, 0)
	var bottom := Vector3(0, y0, 0)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var b0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var t0 := Vector3(cos(a0 + twist) * r1, y0 + h, sin(a0 + twist) * r1)
		var t1 := Vector3(cos(a1 + twist) * r1, y0 + h, sin(a1 + twist) * r1)
		tris.append([b0, b1, t1])
		tris.append([b0, t1, t0])
		tris.append([top, t0, t1])
		tris.append([bottom, b1, b0])
	return _flat(tris, Vector3(0, y0 + h * 0.5, 0), salt)


## A flat-shaded double pyramid (a crystal): `sides` around, radius r, tips up and down.
static func bipyramid(sides: int, r: float, up: float, down: float) -> ArrayMesh:
	var tris := []
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		tris.append([Vector3(0, up, 0), p0, p1])
		tris.append([Vector3(0, -down, 0), p1, p0])
	return _flat(tris, Vector3.ZERO, 0)


static func _flat(tris: Array, centre: Vector3, salt: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for k in tris.size():
		var a: Vector3 = tris[k][0]
		var b: Vector3 = tris[k][1]
		var c: Vector3 = tris[k][2]
		var n := (b - a).cross(c - a)
		if n.dot((a + b + c) / 3.0 - centre) < 0.0:
			var t := b
			b = c
			c = t
			n = -n
		n = n.normalized()
		verts.append_array([a, c, b])
		normals.append_array([n, n, n])
		var v := 1.0 if salt == 0 else 0.9 + 0.2 * float((salt * 131 + k * 17) % 11) / 10.0
		v *= lerpf(1.0, 0.75, clampf(-n.y, 0.0, 1.0))
		colors.append_array([Color(v, v, v), Color(v, v, v), Color(v, v, v)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
