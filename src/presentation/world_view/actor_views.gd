class_name ActorViews
extends Node3D
## One node per live actor and projectile, keyed by entity id. Transforms are written right after each sim
## tick, and Godot's physics interpolation smooths them between ticks (PRESENTATION_CONTRACTS §2).
## Each enemy behaviour has its own silhouette, readable in greyscale (PRESENTATION §3), from the enemy sheet
## (docs/art/enemies_visual_reference.png): the Charger a red hooded crawler on four clawed legs, the Warden a
## hulking rock golem under a red shell (fists in front, a glowing weak spot on its back; no shield), the Needle a
## legged turret.

const CUBE := 0.7
const BAR_W := 0.55

## Occlusion technique under test: "outline" (rim only) or "xray" (rim + silhouette through walls).
var technique := &"xray"
## How many frames a hit flashes the actor white (PRESENTATION §6, starting value).
var flash_frames := 3
var outline_color := Color("#1A1A22")
## The look of new player bolts (ItemVisuals sets it from the items owned).
var bolt_look := {}
var _actors := {}
var _projectiles := {}
var _proj_last := {}
var _flash := {}
## A steady glow per actor id (e.g. burning), shown when not flashing: [color, energy].
var _tint := {}
## Projectile materials by look (see _projectile_material).
var _proj_mats := {}


func sync(reader: WorldReader) -> void:
	var alive := {}
	for i in reader.actor_count():
		var id := reader.actor_id(i)
		alive[id] = true
		var node: Node3D = _actors.get(id)
		var fresh := node == null
		if fresh:
			node = _make_actor(
				reader.actor_kind(i), reader.actor_team(i) == 0, reader.actor_radius(i)
			)
			_actors[id] = node
			add_child(node)
		node.position = SimPlane.to_3d(reader.actor_pos(i))
		_update_actor(node, reader, i)
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
			node = _make_projectile(reader.projectile_team(i) == 0)
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


func projectile_node(id: int) -> Node3D:
	return _projectiles.get(id)


## Flashes an actor white for a few frames.
func flash(id: int) -> void:
	if _actors.has(id):
		_flash[id] = flash_frames
		_set_flash(_actors[id], true)


func is_flashing(id: int) -> bool:
	return _flash.has(id)


func _process(_delta: float) -> void:
	for id in _flash.keys():
		_flash[id] -= 1
		if _flash[id] <= 0:
			_flash.erase(id)
			if _actors.has(id):
				_set_flash(_actors[id], false, id)


## A steady glow on an actor (energy 0 clears it); a hit flash still wins while it lasts.
func set_tint(id: int, c: Color, energy: float) -> void:
	if energy <= 0.0:
		_tint.erase(id)
	else:
		_tint[id] = [c, energy]
	if _actors.has(id) and not _flash.has(id):
		_set_flash(_actors[id], false, id)


## Only the emission colour and energy change here, never emission_enabled or another feature flag: those pick the
## material's shader, and switching it compiles a new shader variant (and frees it again when no material uses
## it), which stalled the frame on every hit (docs/roadmap/v0.2.0/evidence/DAMAGE_LAG.md). Flashable materials
## are built with emission on at energy 0 (flashable()).
func _set_flash(node: Node3D, on: bool, id: int = -1) -> void:
	var tint: Array = _tint.get(id, [])
	for m: StandardMaterial3D in node.get_meta(&"mats", []):
		m.emission = Color.WHITE if on else (tint[0] if not tint.is_empty() else Color.WHITE)
		m.emission_energy_multiplier = 1.6 if on else (tint[1] if not tint.is_empty() else 0.0)


func _update_actor(node: Node3D, reader: WorldReader, i: int) -> void:
	var facing: Node3D = node.get_meta(&"facing")
	facing.rotation = Vector3(0, SimPlane.yaw_of(reader.actor_facing(i)), 0)
	var spawning := reader.actor_spawning(i)
	# Enemy models play their own rise-in while spawning (v0.2.0 L17); the others stay hidden until they arrive.
	facing.visible = not spawning or node.has_meta(&"enemy_avatar")
	(node.get_meta(&"bar") as Node3D).visible = not spawning
	var frac := clampf(float(reader.actor_hp(i)) / maxf(1.0, reader.actor_max_hp(i)), 0.0, 1.0)
	var bar: Node3D = node.get_meta(&"bar")
	bar.scale = Vector3(maxf(frac, 0.001), 1, 1)
	if node.has_meta(&"dazed"):
		(node.get_meta(&"dazed") as Node3D).visible = reader.actor_recovering(i)
	if node.has_meta(&"avatar"):
		(node.get_meta(&"avatar") as PlayerAvatar).sync(reader)
	# Enemy models (v0.2.0 L17): each kind's own node, animated in frame time from the sim state.
	if node.has_meta(&"enemy_avatar"):
		node.get_meta(&"enemy_avatar").sync(reader, i)


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


## Makes a body material ready for the hit flash and tints: emission on, dark (energy 0), so a flash changes
## only shader parameters and never the shader (see _set_flash).
static func flashable(m: StandardMaterial3D) -> StandardMaterial3D:
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.0
	return m


func _body_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = outline_color
	mat.stencil_outline_thickness = 0.035
	return flashable(mat)


func _ghost_material(c: Color, team_c: Color) -> StandardMaterial3D:
	var gm := StandardMaterial3D.new()
	gm.albedo_color = c
	gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
	gm.stencil_color = Color(team_c, 0.85)
	return gm


## A box body piece (and its X-ray twin): size, centre offset from the actor's feet (in the facing frame).
func _piece(parent: Node3D, size: Vector3, at: Vector3, c: Color, team_c: Color) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	body.mesh = box
	body.material_override = _body_material(c)
	body.position = at
	parent.add_child(body)
	var root := parent.get_parent()
	var mats: Array = root.get_meta(&"mats", [])
	mats.append(body.material_override)
	root.set_meta(&"mats", mats)
	if technique == &"xray":
		var ghost := MeshInstance3D.new()
		var gbox := BoxMesh.new()
		gbox.size = size * 0.96
		ghost.mesh = gbox
		ghost.material_override = _ghost_material(c, team_c)
		ghost.position = at
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ghost)


func _make_actor(kind: int, is_player: bool, radius: float) -> Node3D:
	var root := Node3D.new()
	var body_color := ThemePalette.color(&"player_body" if is_player else &"enemy_body")
	var team_color := ThemePalette.color(&"player_core" if is_player else &"enemy_body")
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
	ring.material_override = _unshaded(team_color)
	ring.position.y = 0.02
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	# The body turns with the actor's facing (+X is the front).
	var facing := Node3D.new()
	root.add_child(facing)
	root.set_meta(&"facing", facing)
	var height := CUBE
	match kind:
		WorldReader.KIND_CHARGER:
			# The clawed hooded crawler (v0.2.0 L17): its own node under the facing, animated in frame time.
			var avatar := ChargerAvatar.new()
			avatar.setup(outline_color, technique)
			facing.add_child(avatar)
			root.set_meta(&"enemy_avatar", avatar)
			root.set_meta(&"mats", avatar.body_materials.duplicate())
			height = ChargerAvatar.HEIGHT
			var dazed := MeshInstance3D.new()
			var dt := TorusMesh.new()
			dt.inner_radius = 0.22
			dt.outer_radius = 0.3
			dazed.mesh = dt
			dazed.material_override = _unshaded(ThemePalette.color(&"proj_hostile").lightened(0.3))
			dazed.position.y = height + 0.35
			dazed.scale = Vector3(1, 0.15, 1)
			dazed.visible = false
			dazed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(dazed)
			root.set_meta(&"dazed", dazed)
		WorldReader.KIND_WARDEN:
			# The rock golem (owner, v0.2.0 L17): its own node, animated in frame time.
			height = 1.25
			var warden := WardenAvatar.new()
			warden.setup(outline_color, technique)
			facing.add_child(warden)
			root.set_meta(&"enemy_avatar", warden)
			root.set_meta(&"mats", warden.body_materials.duplicate())
		WorldReader.KIND_NEEDLE:
			# The walking turret (v0.2.0 L17): its own node under the facing, animated in frame time.
			var needle := NeedleAvatar.new()
			needle.setup(outline_color, technique)
			facing.add_child(needle)
			height = NeedleAvatar.HEIGHT
			root.set_meta(&"enemy_avatar", needle)
			root.set_meta(&"mats", needle.body_materials.duplicate())
		_ when kind == WorldReader.KIND_PLAYER and is_player:
			# The hooded wanderer (owner, 2026-10-07): its own node, animated in frame time.
			height = 1.0
			var avatar := PlayerAvatar.new()
			avatar.setup(outline_color, technique)
			root.add_child(avatar)
			root.set_meta(&"avatar", avatar)
			root.set_meta(&"mats", avatar.body_materials.duplicate())
		_:
			var size := CUBE if is_player else CUBE * 0.85
			height = size
			_piece(
				facing, Vector3(size, size, size), Vector3(0, size * 0.5, 0), body_color, team_color
			)
			if is_player:
				_add_core_panels(facing, size)
	# Floating health bar, as in the reference; it shrinks toward its centre as HP drops.
	var bar_root := Node3D.new()
	bar_root.position = Vector3(0, height + 0.55, 0)
	root.add_child(bar_root)
	var bar := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(BAR_W, 0.07)
	bar.mesh = quad
	var bm := _unshaded(ThemePalette.color(&"player_bar" if is_player else &"enemy_bar"))
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.billboard_keep_scale = true
	bm.no_depth_test = true
	bar.material_override = bm
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pivot := Node3D.new()
	pivot.add_child(bar)
	bar_root.add_child(pivot)
	root.set_meta(&"bar", pivot)
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


## Hostile shots are yellow streaks; the player's bolts are short cyan darts (reserved colours, PRESENTATION §3).
func _make_projectile(is_player: bool = false) -> Node3D:
	var n := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.05, 0.08)
	if is_player:
		box.size = bolt_look.get("size", Vector3(0.38, 0.07, 0.07))
	n.mesh = box
	var role := &"player_core" if is_player else &"proj_hostile"
	var c := ThemePalette.color(role)
	if is_player:
		c = bolt_look.get("color", c)
	var energy: float = bolt_look.get("energy", 2.5) if is_player else 2.5
	n.material_override = _projectile_material(c, energy)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.add_child(n)
	return holder


## One shared material per bolt look, kept for the view's life. A fresh material per shot meant that whenever the
## last shot of a look was freed its shader variant went with it, and the next shot compiled it again (a stall).
func _projectile_material(c: Color, energy: float) -> StandardMaterial3D:
	var key := "%s|%s" % [c.to_html(), energy]
	if not _proj_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		_proj_mats[key] = m
	return _proj_mats[key]
