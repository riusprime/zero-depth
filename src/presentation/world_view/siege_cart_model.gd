class_name SiegeCartModel
extends RefCounted
## The Siege Engine's ammo cart: the owner's (BossPieceModels `siege_cart`: a red iron wagon with three shells in its
## bed, its four wheels parts of their own that turn) when it loads, else made in code in the game's own low-poly look
## (a small faceted wagon of wood and iron: a plank crate banded in iron with the Engine's red on its lid, a chassis,
## four spoked wooden wheels with iron tyres, a tow bar). Either is matte like the kit's props and the enemies' bodies
## (roughness 1, metallic 0, the default specular), lit by the room and outlined by the InkPass; nothing on it glows.
## About 2 m long and 1.2-1.3 m wide (the cart's 1 m radius), its front (the way it rolls) toward +X. Looks only
## (EI-07).

## Its palette: weathered wood (light enough to catch the room's light as the walls do), the wood's darker planks and
## spokes, iron, and the Engine's red, dulled, on the lid.
const WOOD := Color("#B48A60")
const WOOD_DARK := Color("#8C6844")
const IRON := Color("#97938F")
const LID := Color("#B84A3B")
## The code wheels' radius and how far they stand out from the cart's middle line (m).
const WHEEL_R := 0.34
const WHEEL_Z := 0.62
const MODEL_WHEELS := ["wheel_0", "wheel_1", "wheel_2", "wheel_3"]

static var _prisms := {}


## A matte, flat-shaded material in `c` (as EnemyLooks.body and the kit props shade).
static func matte(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.5
	return m


## A flat-shaded prism of `sides` round the Z axis, `r` across its corners, `w` deep along Z (a wheel, a tyre, a hub).
static func prism(sides: int, r: float, w: float) -> ArrayMesh:
	var key := "%d:%.3f:%.3f" % [sides, r, w]
	if _prisms.has(key):
		return _prisms[key]
	var front := []
	var back := []
	for k in sides:
		var a := TAU * (k + 0.5) / sides
		front.append(Vector3(cos(a) * r, sin(a) * r, w * 0.5))
		back.append(Vector3(cos(a) * r, sin(a) * r, -w * 0.5))
	var tris := []
	for k in sides:
		var n := (k + 1) % sides
		tris.append([front[k], back[k], back[n]])
		tris.append([front[k], back[n], front[n]])
		if k > 0 and k < sides - 1:
			tris.append([front[0], front[k], front[n]])
			tris.append([back[0], back[k], back[n]])
	var mesh := AvatarBase.flat_mesh(tris, Vector3.ZERO)
	_prisms[key] = mesh
	return mesh


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _put(parent, b, at, mat)


static func _put(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## The wagon under `parent`. Returns [root, its wheels (each turns about its local Z as the cart rolls), their radius
## (m), how far they stand out from its middle line (m)].
static func build(parent: Node3D) -> Array:
	var root := Node3D.new()
	root.name = "AmmoCart"
	parent.add_child(root)
	var piece := BossPieceModels.get_piece(&"siege_cart", ["body"] + MODEL_WHEELS)
	if not piece.is_empty():
		return _model(root, piece)
	var wood := matte(WOOD)
	var dark := matte(WOOD_DARK)
	var iron := matte(IRON)
	# The chassis: two beams along the cart, the tow bar out front with an iron ring at its end.
	for z: float in [-0.36, 0.36]:
		_box(root, Vector3(1.86, 0.12, 0.12), Vector3(0.0, 0.4, z), dark)
	_box(root, Vector3(0.74, 0.09, 0.09), Vector3(1.22, 0.4, 0.0), dark)
	_put(root, prism(6, 0.09, 0.04), Vector3(1.6, 0.4, 0.0), iron).rotation.y = PI * 0.5
	# The crate: planked sides (a slightly darker plank band between two lighter ones), iron bands round it, the lid
	# in the Engine's dulled red with a wooden rim.
	_box(root, Vector3(1.56, 0.56, 1.02), Vector3(0.0, 0.76, 0.0), wood)
	_box(root, Vector3(1.58, 0.14, 1.04), Vector3(0.0, 0.76, 0.0), dark)
	for x: float in [-0.56, 0.56]:
		_box(root, Vector3(0.09, 0.6, 1.06), Vector3(x, 0.76, 0.0), iron)
	_box(root, Vector3(1.62, 0.07, 1.08), Vector3(0.0, 1.06, 0.0), dark)
	_box(root, Vector3(1.44, 0.07, 0.9), Vector3(0.0, 1.1, 0.0), matte(LID))
	# Two shells lashed on the lid, iron noses toward the front.
	for z: float in [-0.2, 0.2]:
		var shell := _put(root, prism(6, 0.12, 0.62), Vector3(-0.08, 1.24, z), iron)
		shell.rotation.y = PI * 0.5
		var nose := _put(root, prism(6, 0.075, 0.12), Vector3(0.29, 1.24, z), dark)
		nose.rotation.y = PI * 0.5
	# The axles and the wheels: a wooden disc with two crossed spokes on each face and an iron tyre, an iron hub.
	var wheels: Array[Node3D] = []
	for x: float in [-0.55, 0.55]:
		_put(root, prism(6, 0.05, 1.38), Vector3(x, WHEEL_R, 0.0), iron)
		for z: float in [-WHEEL_Z, WHEEL_Z]:
			var spin := Node3D.new()
			spin.position = Vector3(x, WHEEL_R, z)
			root.add_child(spin)
			_put(spin, prism(10, WHEEL_R, 0.1), Vector3.ZERO, iron)
			_put(spin, prism(10, WHEEL_R - 0.06, 0.13), Vector3.ZERO, wood)
			for a: float in [0.0, PI * 0.5]:
				var spoke := _box(spin, Vector3(0.56, 0.06, 0.16), Vector3.ZERO, dark)
				spoke.rotation.z = a
			_put(spin, prism(6, 0.08, 0.2), Vector3.ZERO, iron)
			wheels.append(spin)
	return [root, wheels, WHEEL_R, WHEEL_Z]


## The owner's cart under `root`: his body, and each wheel on a node at its hub (the part's own place) that turns.
static func _model(root: Node3D, piece: Dictionary) -> Array:
	BossPieceModels.put(piece, "body", root)
	var wheels: Array[Node3D] = []
	var r := 0.0
	var side := 0.0
	for id: String in MODEL_WHEELS:
		var spin := Node3D.new()
		spin.position = piece["parts"][id]["at"]
		root.add_child(spin)
		var mi := BossPieceModels.put(piece, id, spin)
		mi.position = Vector3.ZERO
		var box := (mi.mesh as Mesh).get_aabb()
		r = maxf(r, box.size.y * 0.5)
		side += absf(spin.position.z) / MODEL_WHEELS.size()
		wheels.append(spin)
	return [root, wheels, r, side]
