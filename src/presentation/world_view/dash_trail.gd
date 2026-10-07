class_name DashTrail
extends Node3D
## Every dash leaves a white motion trail (PLAN v0.2.0 L12, owner: "white trail movement for dash"): a soft
## vertical ribbon of white along the path, brightest at body height, plus a few white afterimages of the
## wanderer's silhouette (a cloak cone and a hood), all fading within LIFE_S. Kinetic Dash's cyan afterimages
## (ItemVisuals) draw on top of it. Reads WorldReader only (EI-07).

const LIFE_S := 0.3
const GHOST_LIFE_S := 0.22
## A ghost every this many dashing ticks.
const GHOST_EVERY := 3
## Over 1.0 so the glow catches it and it stays white on light ground.
const WHITE := Color(1.5, 1.5, 1.5)
## Ribbon rows: [height (m), alpha]: faint at the feet and over the head, solid at the body.
const ROWS := [[0.06, 0.0], [0.45, 0.9], [0.9, 0.65], [1.25, 0.0]]

var ribbon := MeshInstance3D.new()
var _mesh := ImmediateMesh.new()
var _ribbon_mat := StandardMaterial3D.new()
## Kept for the view's life so the afterimages' shader is compiled once, not on the first dash after a quiet spell
## (the v0.2.0 H rule: never let a material's shader variant die and recompile mid-fight).
var _ghost_template := _make_ghost_template()
var _ghost_mesh: Mesh
## [Vector3 ground point, age (s)], oldest first.
var _points: Array = []
## [MeshInstance3D, StandardMaterial3D, age (s)].
var _ghosts: Array = []
var _was_dashing := false
var _last_pos := Vector2.ZERO
var _dash_ticks := 0


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ribbon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ribbon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ribbon_mat.vertex_color_use_as_albedo = true
	_ribbon_mat.albedo_color = WHITE
	_ribbon_mat.render_priority = -1
	ribbon.mesh = _mesh
	ribbon.material_override = _ribbon_mat
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(ribbon)
	_ghost_mesh = _silhouette()


func sync(reader: WorldReader) -> void:
	var dashing := reader.is_dashing()
	var p := reader.player_pos()
	if dashing:
		if not _was_dashing:
			_dash_ticks = 0
			_points.append([SimPlane.to_3d(_last_pos), 0.0])
		_points.append([SimPlane.to_3d(p), 0.0])
		if _dash_ticks % GHOST_EVERY == 0:
			_ghost(SimPlane.to_3d(p), SimPlane.yaw_of(reader.aim_angle()))
		_dash_ticks += 1
	_was_dashing = dashing
	_last_pos = p


func point_count() -> int:
	return _points.size()


func ghost_count() -> int:
	return _ghosts.size()


func _process(delta: float) -> void:
	if _points.is_empty() and _ghosts.is_empty():
		return
	# Clamped so a long frame (a hitch, a slow renderer) can't skip the whole trail.
	var dt := minf(delta, 1.0 / 30.0)
	for pt: Array in _points:
		pt[1] += dt
	while not _points.is_empty() and _points[0][1] >= LIFE_S:
		_points.pop_front()
	for k in range(_ghosts.size() - 1, -1, -1):
		var g: Array = _ghosts[k]
		g[2] += dt
		var t: float = g[2] / GHOST_LIFE_S
		(g[1] as StandardMaterial3D).albedo_color.a = 0.6 * (1.0 - t)
		if t >= 1.0:
			(g[0] as Node).queue_free()
			_ghosts.remove_at(k)
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	for r in ROWS.size() - 1:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for pt: Array in _points:
			var life := 1.0 - clampf(pt[1] / LIFE_S, 0.0, 1.0)
			var at: Vector3 = pt[0]
			for row in [ROWS[r], ROWS[r + 1]]:
				_mesh.surface_set_color(Color(1, 1, 1, row[1] * life * life))
				_mesh.surface_add_vertex(at + Vector3(0, row[0], 0))
		_mesh.surface_end()


func _ghost(at: Vector3, yaw: float) -> void:
	var m := _ghost_template.duplicate() as StandardMaterial3D
	m.albedo_color = Color(WHITE, 0.6)
	var n := MeshInstance3D.new()
	n.mesh = _ghost_mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	n.position = at
	n.rotation.y = yaw
	add_child(n)
	_ghosts.append([n, m, 0.0])


## The wanderer's outline in two pieces: a cloak cone and a hood.
static func _silhouette() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloak := CylinderMesh.new()
	cloak.top_radius = 0.1
	cloak.bottom_radius = 0.4
	cloak.height = 0.85
	cloak.radial_segments = 8
	cloak.rings = 1
	st.append_from(cloak, 0, Transform3D(Basis(), Vector3(0, 0.5, 0)))
	var hood := SphereMesh.new()
	hood.radius = 0.2
	hood.height = 0.36
	hood.radial_segments = 8
	hood.rings = 4
	st.append_from(hood, 0, Transform3D(Basis(), Vector3(0, 1.06, 0)))
	return st.commit()


static func _make_ghost_template() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = -1
	return m
