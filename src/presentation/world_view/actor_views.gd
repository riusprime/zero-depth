class_name ActorViews
extends Node3D
## One node per live actor and projectile, keyed by entity id. Transforms are written right after each sim
## tick, and Godot's physics interpolation smooths them between ticks (PRESENTATION_CONTRACTS §2).

const CUBE := 0.7

## Occlusion technique under test: "outline" (rim only) or "xray" (rim + silhouette through walls).
var technique := &"xray"
var outline_color := Color("#1A1A22")
var _actors := {}
var _projectiles := {}
var _proj_last := {}


func sync(reader: WorldReader) -> void:
	var alive := {}
	for i in reader.actor_count():
		var id := reader.actor_id(i)
		alive[id] = true
		var node: Node3D = _actors.get(id)
		var fresh := node == null
		if fresh:
			node = _make_actor(reader.actor_team(i) == 0, reader.actor_radius(i))
			_actors[id] = node
			add_child(node)
		node.position = SimPlane.to_3d(reader.actor_pos(i))
		if fresh:
			node.reset_physics_interpolation()
	_drop_missing(_actors, alive)
	var live := {}
	for i in reader.projectile_count():
		var id := reader.projectile_id(i)
		live[id] = true
		var p := reader.projectile_pos(i)
		var node: Node3D = _projectiles.get(id)
		var fresh := node == null
		if fresh:
			node = _make_projectile()
			_projectiles[id] = node
			add_child(node)
		var last: Vector2 = _proj_last.get(id, p - reader.projectile_vel(i))
		var dir := p - last
		if dir.length() > 0.0001:
			node.rotation = Vector3(0, atan2(dir.y, dir.x), 0)
		node.position = SimPlane.to_3d(p, SimPlane.CORE_HEIGHT)
		_proj_last[id] = p
		if fresh:
			node.reset_physics_interpolation()
	_drop_missing(_projectiles, live)
	for id in _proj_last.keys():
		if not live.has(id):
			_proj_last.erase(id)


func actor_node(id: int) -> Node3D:
	return _actors.get(id)


func _drop_missing(nodes: Dictionary, alive: Dictionary) -> void:
	for id in nodes.keys():
		if not alive.has(id):
			nodes[id].queue_free()
			nodes.erase(id)


func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _make_actor(is_player: bool, radius: float) -> Node3D:
	var root := Node3D.new()
	var body_color := ThemePalette.color(&"player_body" if is_player else &"enemy_body")
	var size := CUBE if is_player else CUBE * 0.85
	# Contact ring: a dark disc under the actor.
	var contact := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius + 0.1
	disc.bottom_radius = radius + 0.1
	disc.height = 0.01
	contact.mesh = disc
	var shadow := _unshaded(Color(outline_color, 0.55))
	shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	contact.material_override = shadow
	contact.position.y = 0.006
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(contact)
	# Team ring decal: identity never depends on body hue alone.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius + 0.16
	torus.outer_radius = radius + 0.24
	ring.mesh = torus
	ring.scale = Vector3(1, 0.08, 1)
	ring.material_override = _unshaded(
		ThemePalette.color(&"player_core" if is_player else &"enemy_body")
	)
	ring.position.y = 0.02
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	# Body with a rim outline in the biome's outline token.
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, size, size)
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 1.0
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = outline_color
	mat.stencil_outline_thickness = 0.035
	body.material_override = mat
	body.position.y = size * 0.5
	root.add_child(body)
	if technique == &"xray":
		# A slightly smaller twin that only shows (in team colour) where a wall hides the body.
		var ghost := MeshInstance3D.new()
		var gbox := BoxMesh.new()
		gbox.size = Vector3(size, size, size) * 0.96
		ghost.mesh = gbox
		var gm := StandardMaterial3D.new()
		gm.albedo_color = body_color
		gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		gm.stencil_color = Color(
			ThemePalette.color(&"player_core" if is_player else &"enemy_body"), 0.85
		)
		ghost.material_override = gm
		ghost.position.y = size * 0.5
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ghost)
	if is_player:
		_add_core_panels(root, size)
	# Floating health bar, as in the reference.
	var bar := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.07)
	bar.mesh = quad
	var bm := _unshaded(ThemePalette.color(&"player_bar" if is_player else &"enemy_bar"))
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.no_depth_test = true
	bar.material_override = bm
	bar.position.y = size + 0.55
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bar)
	return root


func _add_core_panels(root: Node3D, size: float) -> void:
	var core := StandardMaterial3D.new()
	core.albedo_color = ThemePalette.color(&"player_core")
	core.emission_enabled = true
	core.emission = ThemePalette.color(&"player_core")
	core.emission_energy_multiplier = 2.2
	var panel := BoxMesh.new()
	panel.size = Vector3(size * 0.5, size * 0.38, 0.02)
	for k in 4:
		var n := MeshInstance3D.new()
		n.mesh = panel
		n.material_override = core
		var yaw := k * PI * 0.5
		n.rotation = Vector3(0, yaw, 0)
		n.position = (
			Vector3(sin(yaw), 0, cos(yaw)) * (size * 0.5 + 0.045) + Vector3(0, size * 0.3, 0)
		)
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(n)


func _make_projectile() -> Node3D:
	var n := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.05, 0.08)
	n.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = ThemePalette.color(&"proj_hostile")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = ThemePalette.color(&"proj_hostile")
	m.emission_energy_multiplier = 2.5
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.add_child(n)
	return holder
