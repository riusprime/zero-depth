class_name TelegraphViews
extends Node3D
## Enemy attack telegraphs (PRESENTATION §4): the attack's area on the ground for its whole windup, drawn from
## WorldReader.telegraph() (the function that resolves the hit). A full-opacity outline, and a fill that grows
## from 0 to 100% so the player reads *when* as well as *where*. Unshaded, so no shadow hides it.
## The bosses' shapes (v0.3.0 C: ring, lanes, arc, discs, sweep, and the harmless ripple of a burrow) are drawn as
## flat triangles rebuilt each tick (ImmediateMesh) from the same dictionary the hit is resolved from.

## Shapes drawn as rebuilt meshes (BossAi.telegraph).
const MESH_SHAPES: Array[StringName] = [&"ring", &"lanes", &"arc", &"discs", &"sweep", &"ripple"]
const ARC_STEPS := 40

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
	if MESH_SHAPES.has(shape):
		for part in ["Fill", "Edge"]:
			var mi := MeshInstance3D.new()
			mi.name = part
			mi.mesh = ImmediateMesh.new()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		return root
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
	if MESH_SHAPES.has(tg["shape"]):
		_update_mesh(n, tg, p)
		return
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


# --- boss shapes (v0.3.0 C) -------------------------------------------------------------------------------------


func _update_mesh(n: Node3D, tg: Dictionary, p: float) -> void:
	var fill: ImmediateMesh = (n.get_node("Fill") as MeshInstance3D).mesh
	var edge: ImmediateMesh = (n.get_node("Edge") as MeshInstance3D).mesh
	fill.clear_surfaces()
	edge.clear_surfaces()
	var ft := []
	var et := []
	match tg["shape"]:
		&"ring":
			var c: Vector2 = tg["center"]
			var r0: float = tg["inner"]
			var r1: float = tg["outer"]
			_sector(ft, c, r0, r0 + (r1 - r0) * p, 0.0, TAU)
			_sector(et, c, r0, r0 + EDGE, 0.0, TAU)
			_sector(et, c, r1 - EDGE, r1, 0.0, TAU)
		&"lanes":
			for o: Obb in tg["obbs"]:
				_lane(ft, et, o, p)
		&"arc":
			var a := _rad(tg["angle"])
			var h := _rad(tg["half_arc"])
			_fan(ft, et, tg["center"], tg["own_r"], tg["own_r"] + tg["reach"], a - h, a + h, p)
		&"sweep":
			var a0 := _rad(tg["start"])
			var a1 := a0 + _rad(tg["span"])
			var c: Vector2 = tg["center"]
			var r0: float = tg["own_r"]
			var r1: float = r0 + float(tg["reach"])
			_fan(ft, et, c, r0, r1, minf(a0, a1), maxf(a0, a1), p)
			var b := _rad(tg["beam"])
			var d := Vector2(cos(b), sin(b))
			var side := Vector2(-d.y, d.x) * 0.12
			_quad(et, c + d * r0 - side, c + d * r1 - side, c + d * r1 + side, c + d * r0 + side)
		&"discs":
			for c: Vector2 in tg["centers"]:
				var r: float = tg["radius"]
				_sector(ft, c, 0.0, maxf(r * p, 0.01), 0.0, TAU)
				_sector(et, c, r - EDGE, r, 0.0, TAU)
		&"ripple":
			var c: Vector2 = tg["center"]
			var r: float = tg["radius"]
			for k in 3:
				var rr := r * (0.45 + 0.3 * k)
				_sector(et, c, rr - EDGE * 0.6, rr, 0.0, TAU)
	_emit(fill, ft, _fill_mat)
	_emit(edge, et, _edge_mat)


func _rad(units: int) -> float:
	return TAU * float(units) / 4096.0


## Triangles of an annular sector (sim plane) from radius r0 to r1, angles a0..a1 (radians).
func _sector(out: Array, c: Vector2, r0: float, r1: float, a0: float, a1: float) -> void:
	var steps := maxi(4, int(ceil(ARC_STEPS * absf(a1 - a0) / TAU)) + 4)
	for k in steps:
		var t0 := a0 + (a1 - a0) * k / steps
		var t1 := a0 + (a1 - a0) * (k + 1) / steps
		var d0 := Vector2(cos(t0), sin(t0))
		var d1 := Vector2(cos(t1), sin(t1))
		_quad(out, c + d0 * r0, c + d0 * r1, c + d1 * r1, c + d1 * r0)


## A sector fan: the fill grows outward from r0 with the windup, the outline is its two sides and both arcs.
func _fan(
	ft: Array, et: Array, c: Vector2, r0: float, r1: float, a0: float, a1: float, p: float
) -> void:
	_sector(ft, c, r0, r0 + maxf((r1 - r0) * p, 0.01), a0, a1)
	_sector(et, c, r1 - EDGE, r1, a0, a1)
	_sector(et, c, r0, r0 + EDGE, a0, a1)
	for a in [a0, a1]:
		var d := Vector2(cos(a), sin(a))
		var side := Vector2(-d.y, d.x) * EDGE * 0.5
		_quad(et, c + d * r0 - side, c + d * r1 - side, c + d * r1 + side, c + d * r0 + side)


## A lane: its outline, and a fill that runs from the attacker's end as the windup completes.
func _lane(ft: Array, et: Array, o: Obb, p: float) -> void:
	var u := o.axis_u
	var v := o.axis_v
	var hx := o.half.x
	var hy := o.half.y
	var back := o.center - u * hx
	var len := maxf(hx * 2.0 * p, 0.01)
	_quad(ft, back - v * hy, back + u * len - v * hy, back + u * len + v * hy, back + v * hy)
	var corners := [
		o.center - u * hx - v * hy,
		o.center + u * hx - v * hy,
		o.center + u * hx + v * hy,
		o.center - u * hx + v * hy
	]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var d := (b - a).normalized()
		var side := Vector2(-d.y, d.x) * EDGE * 0.5
		_quad(et, a - side, b - side, b + side, a + side)


func _quad(out: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	out.append_array([a, b, c, a, c, d])


func _emit(im: ImmediateMesh, pts: Array, mat: Material) -> void:
	if pts.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for q: Vector2 in pts:
		im.surface_set_normal(Vector3.UP)
		im.surface_add_vertex(SimPlane.to_3d(q, Y))
	im.surface_end()
