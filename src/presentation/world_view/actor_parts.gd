class_name ActorParts
extends RefCounted
## The pieces every actor node wears besides its body: the contact disc and the team ring under it, the dazed ring
## over a Charger and the floating health bar. Their meshes (one per size) and their unshaded materials (one per
## colour) are made once per view and shared by every actor, so a spawn builds no mesh and no material: a horde's
## top-up brings dozens of enemies in one frame, and building three meshes and three materials for each was most of
## that frame. A shared piece draws exactly as its own copy did (same sizes, colours and flags); nothing writes these
## meshes or materials per actor.

## The health bar's quad (m).
const BAR_SIZE := Vector2(ActorViews.BAR_W, 0.07)
## The contact disc's alpha (over the outline colour).
const DISC_ALPHA := 0.55

var _meshes := {}
var _mats := {}


## The contact disc (a dark disc under the actor) and the team ring decal under `root` (identity never depends on
## body hue alone).
func add_rings(root: Node3D, radius: float, team_color: Color, outline: Color) -> void:
	var contact := MeshInstance3D.new()
	contact.mesh = _disc(radius + 0.1)
	contact.material_override = _material(Color(outline, DISC_ALPHA), true, false)
	contact.position.y = 0.006
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(contact)
	var ring := MeshInstance3D.new()
	ring.mesh = _torus(radius + 0.16, radius + 0.24)
	ring.scale = Vector3(1, 0.08, 1)
	ring.material_override = _material(team_color, false, false)
	ring.position.y = 0.02
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)


## The dazed ring over a stunned Charger at `y` (hidden until it recovers).
func add_dazed(root: Node3D, y: float) -> MeshInstance3D:
	var dazed := MeshInstance3D.new()
	dazed.mesh = dazed_mesh()
	dazed.material_override = dazed_material()
	dazed.position.y = y
	dazed.scale = Vector3(1, 0.15, 1)
	dazed.visible = false
	dazed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dazed)
	return dazed


## The floating health bar at `y` over `root`, as in the reference; returns its pivot (BarChunks scales it toward
## its centre as HP drops).
func add_bar(root: Node3D, y: float, color: Color) -> Node3D:
	var bar_root := Node3D.new()
	bar_root.position = Vector3(0, y, 0)
	root.add_child(bar_root)
	var bar := MeshInstance3D.new()
	bar.mesh = _quad()
	bar.material_override = _material(color, false, true)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pivot := Node3D.new()
	pivot.add_child(bar)
	bar_root.add_child(pivot)
	return pivot


## The meshes and materials made so far (tests: a spawn of a size and colour seen before makes none).
func made() -> int:
	return _meshes.size() + _mats.size()


## The same meshes and materials for EnemyBatch, which draws these pieces as instances of a batched enemy: the disc
## and the ring of an actor of contact radius `radius`, the dazed ring, the bar's quad, and their materials.
func disc_mesh(radius: float) -> Mesh:
	return _disc(radius + 0.1)


func ring_mesh(radius: float) -> Mesh:
	return _torus(radius + 0.16, radius + 0.24)


func dazed_mesh() -> Mesh:
	return _torus(0.22, 0.3)


func bar_mesh() -> Mesh:
	return _quad()


func disc_material(outline: Color) -> Material:
	return _material(Color(outline, DISC_ALPHA), true, false)


func ring_material(team_color: Color) -> Material:
	return _material(team_color, false, false)


func dazed_material() -> Material:
	return _material(ThemePalette.color(&"proj_hostile").lightened(0.3), false, false)


func bar_material(color: Color) -> Material:
	return _material(color, false, true)


func _disc(r: float) -> CylinderMesh:
	var key := [&"disc", r]
	if not _meshes.has(key):
		var disc := CylinderMesh.new()
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.01
		_meshes[key] = disc
	return _meshes[key]


func _torus(inner: float, outer: float) -> TorusMesh:
	var key := [&"torus", inner, outer]
	if not _meshes.has(key):
		var torus := TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = outer
		_meshes[key] = torus
	return _meshes[key]


func _quad() -> QuadMesh:
	if not _meshes.has(&"bar"):
		var quad := QuadMesh.new()
		quad.size = BAR_SIZE
		_meshes[&"bar"] = quad
	return _meshes[&"bar"]


## An unshaded material of colour `c`: `alpha` blends it (the disc), `billboard` turns it to the camera, kept at its
## scale and drawn over everything (the bar).
func _material(c: Color, alpha: bool, billboard: bool) -> StandardMaterial3D:
	var key := [c, alpha, billboard]  # The exact colour (a value key)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if alpha:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if billboard:
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
			m.no_depth_test = true
		_mats[key] = m
	return _mats[key]
