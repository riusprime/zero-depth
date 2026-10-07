class_name TelegraphViews
extends Node3D
## Enemy attack telegraphs (PRESENTATION §4): the attack's area on the ground for its whole windup, drawn from
## WorldReader.telegraph() (the function that resolves the hit). A full-opacity outline, and a fill that grows
## from 0 to 100% so the player reads *when* as well as *where*. Unshaded, so no shadow hides it.
## The bosses' shapes (v0.3.0 C: ring, lanes, arc, discs, sweep, and the harmless ripple of a burrow) are drawn as
## flat triangles rebuilt each tick (ImmediateMesh) from the same dictionary the hit is resolved from.
## v0.3.5 AI: a telegraph with a "style" gets a mark on top of its shape: an Arc Caster's bolt a bright core line down
## each lane, its rune an inner ring with turning spokes, a Bomb Drone's bomb a cross-hair and the bomb itself flying
## from the drone ("from") to the circle's centre as the circle fills.
## v0.4.0 EN: a Sniper's line ("snipe") carries the bolt's bright core; a Shield Bearer's bash ("bash") two chevrons
## pointing down its lane; a Mine Layer's armed mines ("mine") a spiked star in each filling circle.
## v0.4.0 BO: a flood's standing lanes carry a style too: the Warlord's spears a row of spear heads down each lane,
## the Foundry's molten floor a hot core with cross bars (a fixed colour; nothing toggles emission at run time).

## Shapes drawn as rebuilt meshes (BossAi.telegraph).
const MESH_SHAPES: Array[StringName] = [&"ring", &"lanes", &"arc", &"discs", &"sweep", &"ripple"]
const ARC_STEPS := 40

const Y := 0.035
const EDGE := 0.06

var _nodes := {}
var _fill_mat := StandardMaterial3D.new()
var _edge_mat := StandardMaterial3D.new()
var _core_mat := StandardMaterial3D.new()
var _bomb_mat := StandardMaterial3D.new()
var _molten_mat := StandardMaterial3D.new()


func _ready() -> void:
	var c := ThemePalette.color(&"telegraph_hostile")
	for m: StandardMaterial3D in [_fill_mat, _edge_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = c
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mat.albedo_color = Color(c, 0.45)
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_core_mat.albedo_color = ThemePalette.color(&"proj_hostile")
	_molten_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_molten_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_molten_mat.albedo_color = Color("#FF8A2E")
	_bomb_mat.albedo_color = Color("#1B1C20")
	_bomb_mat.emission_enabled = true
	_bomb_mat.emission = c
	_bomb_mat.emission_energy_multiplier = 0.6


func sync(reader: WorldReader) -> void:
	var seen := {}
	for i in reader.actor_count():
		var tg := reader.telegraph(i)
		if tg.is_empty():
			continue
		var id := reader.actor_id(i)
		seen[id] = true
		var n: Node3D = _nodes.get(id)
		var style: StringName = tg.get("style", &"")
		if n == null or n.get_meta(&"shape") != tg["shape"] or n.get_meta(&"style") != style:
			if n != null:
				n.queue_free()
			n = _make(tg["shape"], style)
			_nodes[id] = n
			add_child(n)
		_update(n, tg)
		if style != &"":
			_update_style(n, tg)
	for id in _nodes.keys():
		if not seen.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)


## How many telegraphs are showing (tests and the tour).
func count() -> int:
	return _nodes.size()


func _make(shape: StringName, style: StringName = &"") -> Node3D:
	var root := _make_shape(shape)
	root.set_meta(&"style", style)
	if style == &"":
		return root
	var deco := MeshInstance3D.new()
	deco.name = "Deco"
	deco.mesh = ImmediateMesh.new()
	deco.top_level = true
	deco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(deco)
	if style == &"bomb":
		var bomb := MeshInstance3D.new()
		bomb.name = "Bomb"
		bomb.mesh = ArcCasterAvatar._octahedron(0.12)
		bomb.material_override = _bomb_mat
		bomb.top_level = true
		bomb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bomb)
	return root


func _make_shape(shape: StringName) -> Node3D:
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


# --- styles (v0.3.5 AI) ------------------------------------------------------------------------------------------


func _update_style(n: Node3D, tg: Dictionary) -> void:
	var deco: ImmediateMesh = (n.get_node("Deco") as MeshInstance3D).mesh
	deco.clear_surfaces()
	var p := float(tg["progress"]) / 1000.0
	var pts := []
	match tg["style"]:
		&"bolt", &"snipe":
			var lanes: Array = tg["obbs"] if tg.has("obbs") else [tg["obb"]]
			for o: Obb in lanes:
				var u := o.axis_u
				var side := o.axis_v * 0.035
				var a := o.center - u * o.half.x
				var b := o.center + u * o.half.x
				_quad(pts, a - side, b - side, b + side, a + side)
		&"rune":
			var c: Vector2 = tg["center"]
			var r: float = tg["radius"]
			_sector(pts, c, r * 0.6 - EDGE * 0.5, r * 0.6, 0.0, TAU)
			var turn := p * PI * 0.5
			for k in 6:
				var ang := turn + TAU * k / 6.0
				var d := Vector2(cos(ang), sin(ang))
				var sd := Vector2(-d.y, d.x) * EDGE * 0.4
				_quad(
					pts, c + d * r * 0.6 - sd, c + d * r - sd, c + d * r + sd, c + d * r * 0.6 + sd
				)
		&"bomb":
			var c: Vector2 = tg["center"]
			var r: float = tg["radius"]
			for d: Vector2 in [Vector2.RIGHT, Vector2.UP]:
				var sd := Vector2(-d.y, d.x) * EDGE * 0.4
				_quad(
					pts,
					c - d * r * 0.35 - sd,
					c + d * r * 0.35 - sd,
					c + d * r * 0.35 + sd,
					c - d * r * 0.35 + sd
				)
			# The bomb flies along an arc from the drone's hover to the circle's centre as the circle fills.
			var from: Vector2 = tg.get("from", c)
			var y := BombDroneAvatar.HOVER_Y * (1.0 - p) + 2.4 * p * (1.0 - p) + 0.12
			var bomb := n.get_node("Bomb") as Node3D
			bomb.global_position = SimPlane.to_3d(from.lerp(c, p), y)
			bomb.rotation = Vector3(p * 9.0, p * 5.0, 0)
		&"bash":
			var o: Obb = tg["obb"]
			for k in 2:
				var tip := o.center + o.axis_u * (o.half.x * (0.15 + 0.45 * k))
				var back := tip - o.axis_u * o.half.y * 0.8
				for sgn: float in [-1.0, 1.0]:
					var wing := back + o.axis_v * o.half.y * 0.7 * sgn
					var d := (tip - wing).normalized()
					var sd := Vector2(-d.y, d.x) * EDGE * 0.4
					_quad(pts, wing - sd, tip - sd, tip + sd, wing + sd)
		&"mine":
			var r: float = tg["radius"]
			for c: Vector2 in tg["centers"]:
				for k in 4:
					var ang := TAU * k / 8.0 + p * PI
					var d := Vector2(cos(ang), sin(ang))
					var sd := Vector2(-d.y, d.x) * EDGE * 0.4
					_quad(
						pts,
						c - d * r * 0.3 - sd,
						c + d * r * 0.3 - sd,
						c + d * r * 0.3 + sd,
						c - d * r * 0.3 + sd
					)
		&"spears", &"molten":
			for o: Obb in tg["obbs"]:
				_flood_marks(pts, o, tg["style"] == &"spears")
	var mat := _edge_mat
	if tg["style"] == &"bolt" or tg["style"] == &"snipe":
		mat = _core_mat
	elif tg["style"] == &"molten":
		mat = _molten_mat
	_emit(deco, pts, mat)


## v0.4.0 BO: a standing flood lane's marks: spear heads every SPEAR_STEP along it, or a molten core with bars.
func _flood_marks(pts: Array, o: Obb, spears: bool) -> void:
	var u := o.axis_u
	var v := o.axis_v
	var a := o.center - u * o.half.x
	var n := maxi(1, int(o.half.x * 2.0 / 0.7))
	if spears:
		for k in n:
			var c := a + u * (0.35 + 0.7 * k)
			var w := v * minf(o.half.y, 0.22)
			_quad(pts, c - u * 0.3, c - w, c + u * 0.3, c + w)
		return
	var side := v * o.half.y * 0.3
	_quad(pts, a - side, a + u * o.half.x * 2.0 - side, a + u * o.half.x * 2.0 + side, a + side)
	for k in n:
		var c := a + u * (0.35 + 0.7 * k)
		_quad(
			pts,
			c - u * 0.06 - v * o.half.y,
			c + u * 0.06 - v * o.half.y,
			c + u * 0.06 + v * o.half.y,
			c - u * 0.06 + v * o.half.y
		)


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
