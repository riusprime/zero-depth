class_name TelegraphViews
extends Node3D
## Enemy attack telegraphs (PRESENTATION §4): the attack's area on the ground for its whole windup, drawn from
## WorldReader.telegraph() (the function that resolves the hit). A full-opacity outline, and a fill that grows
## from 0 to 100% so the player reads *when* as well as *where*. Unshaded, so no shadow hides it.

const Y := 0.035
const EDGE := 0.06

var _nodes := {}
var _fill_mat := StandardMaterial3D.new()
var _edge_mat := StandardMaterial3D.new()


func _ready() -> void:
	var c := ThemePalette.color(&"telegraph_hostile")
	for m: StandardMaterial3D in [_fill_mat, _edge_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = c
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mat.albedo_color = Color(c, 0.45)


func sync(reader: WorldReader) -> void:
	var seen := {}
	for i in reader.actor_count():
		var tg := reader.telegraph(i)
		if tg.is_empty():
			continue
		var id := reader.actor_id(i)
		seen[id] = true
		var n: Node3D = _nodes.get(id)
		if n == null or n.get_meta(&"shape") != tg["shape"]:
			if n != null:
				n.queue_free()
			n = _make(tg["shape"])
			_nodes[id] = n
			add_child(n)
		_update(n, tg)
	for id in _nodes.keys():
		if not seen.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)


## How many telegraphs are showing (tests and the tour).
func count() -> int:
	return _nodes.size()


func _make(shape: StringName) -> Node3D:
	var root := Node3D.new()
	root.set_meta(&"shape", shape)
	if shape == &"disc":
		var edge := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.rings = 48
		edge.mesh = torus
		edge.material_override = _edge_mat
		edge.name = "Edge"
		root.add_child(edge)
		var fill := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.height = 0.005
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.0
		cyl.radial_segments = 48
		fill.mesh = cyl
		fill.material_override = _fill_mat
		fill.name = "Fill"
		root.add_child(fill)
	else:
		for k in 4:
			var e := MeshInstance3D.new()
			e.mesh = BoxMesh.new()
			e.material_override = _edge_mat
			e.name = "Edge%d" % k
			root.add_child(e)
		var fill := MeshInstance3D.new()
		var q := BoxMesh.new()
		q.size = Vector3(1, 0.005, 1)
		fill.mesh = q
		fill.material_override = _fill_mat
		fill.name = "Fill"
		root.add_child(fill)
	for c in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


func _update(n: Node3D, tg: Dictionary) -> void:
	var p := float(tg["progress"]) / 1000.0
	if tg["shape"] == &"disc":
		var r: float = tg["radius"]
		n.position = SimPlane.to_3d(tg["center"], Y)
		var edge: MeshInstance3D = n.get_node("Edge")
		var torus: TorusMesh = edge.mesh
		torus.inner_radius = r - EDGE
		torus.outer_radius = r
		edge.scale = Vector3(1, 0.05, 1)
		var fill: Node3D = n.get_node("Fill")
		var fr := maxf(r * p, 0.01)
		fill.scale = Vector3(fr, 1, fr)
		return
	var box: Obb = tg["obb"]
	n.position = SimPlane.to_3d(box.center, Y)
	n.rotation = Vector3(0, SimPlane.yaw_of(box.angle), 0)
	var hx := box.half.x
	var hy := box.half.y
	var sides := [
		[Vector3(0, 0, -hy), Vector3(hx * 2.0, 0.01, EDGE)],
		[Vector3(0, 0, hy), Vector3(hx * 2.0, 0.01, EDGE)],
		[Vector3(-hx, 0, 0), Vector3(EDGE, 0.01, hy * 2.0)],
		[Vector3(hx, 0, 0), Vector3(EDGE, 0.01, hy * 2.0)],
	]
	for k in 4:
		var e: MeshInstance3D = n.get_node("Edge%d" % k)
		e.position = sides[k][0]
		(e.mesh as BoxMesh).size = sides[k][1]
	# The fill runs from the attacker's end (-x) toward the far end as the windup completes.
	var fill: Node3D = n.get_node("Fill")
	var len := maxf(hx * 2.0 * p, 0.01)
	fill.scale = Vector3(len, 1, hy * 2.0)
	fill.position = Vector3(-hx + len * 0.5, 0, 0)
