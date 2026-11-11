class_name ShotViews
extends RefCounted
## The plain shots ActorViews draws, a node each under it: the hostile shots as yellow streaks and the hero's
## shrapnel shards as darts (FireballViews draws the fireballs, HeroPulseViews the hero's shots). A shot gone from the
## sim goes back to its look's pool (hidden) instead of being freed; the mesh and material are shared per look.

## Projectile nodes kept for reuse per look, at most this many idle (hordes fire hundreds a second).
const POOL_MAX := 400

## The view the nodes hang under (its bolt look and colour).
var views: ActorViews
var _projectiles := {}
var _last := {}
## Projectile materials by look (see _material), and one mesh per look.
var _mats := {}
var _meshes := {}
## Idle projectile nodes by look key (hidden, kept as children), reused before building new ones.
var _pool := {}
var _pooled := 0
## The last look key per side (0 hostile, 1 player) and the [size, colour, energy] it was built from, so a shot of
## an unchanged look doesn't format its key again (a horde fires hundreds a second).
var _key: Array[String] = ["", ""]
var _key_of: Array = [[], []]


func _init(p_views: ActorViews) -> void:
	views = p_views


func sync(reader: WorldReader) -> void:
	var live := {}
	for i in reader.projectile_count():
		if reader.projectile_look(i) != "":
			continue  # A fireball (FireballViews draws them)
		if reader.projectile_team(i) == 0 and not reader.projectile_is_shard(i):
			continue  # The hero's shots are blue pulses (HeroPulseViews draws them)
		var id := reader.projectile_id(i)
		live[id] = true
		var p := reader.projectile_pos(i)
		var node: Node3D = _projectiles.get(id)
		var fresh := node == null
		if fresh:
			node = _make(reader.projectile_team(i) == 0)
			_projectiles[id] = node
			if node.get_parent() == null:  # a pooled node is already here
				views.add_child(node)
		var last: Vector2 = _last.get(id, p - reader.projectile_vel(i))
		var dir := p - last
		if dir.length() > 0.0001:
			node.rotation = Vector3(0, atan2(dir.y, dir.x), 0)
		node.position = SimPlane.to_3d(p, SimPlane.CORE_HEIGHT)
		_last[id] = p
		if fresh:
			node.reset_physics_interpolation()
	if _projectiles.size() != live.size():  # Every live shot has its node: equal sizes, none ended
		_pool_missing(live)
	if _last.size() != live.size():
		for id in _last.keys():
			if not live.has(id):
				_last.erase(id)


func node(id: int) -> Node3D:
	return _projectiles.get(id)


## Idle projectile nodes waiting for reuse (tests).
func pooled() -> int:
	return _pooled


## A projectile gone from the sim goes back to its look's pool (hidden) instead of being freed.
func _pool_missing(live: Dictionary) -> void:
	for id in _projectiles.keys():
		if live.has(id):
			continue
		var n: Node3D = _projectiles[id]
		_projectiles.erase(id)
		if _pooled >= POOL_MAX:
			n.queue_free()
			continue
		n.visible = false
		var key: String = n.get_meta(&"look")
		if not _pool.has(key):
			_pool[key] = []
		(_pool[key] as Array).append(n)
		_pooled += 1


## Hostile shots are yellow streaks; the player's bolts were short cyan darts (reserved colours, PRESENTATION §3).
## Only the hero's shrapnel shards are still drawn here as darts. A node of the same look comes back from the pool when
## there is one; the mesh is shared per look.
func _make(is_player: bool = false) -> Node3D:
	var size := Vector3(0.55, 0.05, 0.08)
	if is_player:
		size = views.bolt_look.get("size", Vector3(0.38, 0.07, 0.07))
	var role := &"player_core" if is_player else &"proj_hostile"
	var c := ThemePalette.color(role)
	if is_player:
		c = views.bolt_color()
	var energy: float = views.bolt_look.get("energy", 2.5) if is_player else 2.5
	var side := 1 if is_player else 0
	var of := [size, c, energy]
	if of != _key_of[side]:
		_key_of[side] = of
		_key[side] = "%s|%s|%s" % [size, c.to_html(), energy]
	var key := _key[side]
	var idle: Array = _pool.get(key, [])
	if not idle.is_empty():
		var reused: Node3D = idle.pop_back()
		_pooled -= 1
		reused.visible = true
		return reused
	if not _meshes.has(key):
		var box := BoxMesh.new()
		box.size = size
		_meshes[key] = box
	var n := MeshInstance3D.new()
	n.mesh = _meshes[key]
	n.material_override = _material(c, energy)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.set_meta(&"look", key)
	holder.add_child(n)
	return holder


## One shared material per bolt look, kept for the view's life. A fresh material per shot meant that whenever the
## last shot of a look was freed its shader variant went with it, and the next shot compiled it again (a stall).
func _material(c: Color, energy: float) -> StandardMaterial3D:
	var key := "%s|%s" % [c.to_html(), energy]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		_mats[key] = m
	return _mats[key]
