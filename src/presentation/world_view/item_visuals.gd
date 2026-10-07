class_name ItemVisuals
extends Node3D
## How items change the look (PLAN v0.2.0 "Items": "as we gather more items there should be modification on how
## the character attack and its own visuals"). Reads the sim through WorldReader only:
## - the laser blade's colour, width and trail (Ember Edge orange, Twin Arc a longer trail, Overcharge a wider,
##   brighter blade on the charged swing; Long Edge needs nothing here: the blade already matches the hit reach);
## - bolts (Splinter Shot small and green-tinged, Rapid Coil long, Ricochet Core white and brighter);
## - Twin Arc's echo flash, Overcharge's shockwave ring, Kinetic Dash's cyan afterimages (drawn over the white
##   trail every dash leaves, DashTrail);
## - burning enemies glow orange, frozen ones icy white (v0.3.0 G; StatusVisuals draws the other status effects);
## - v0.3.0 G: Glacial Edge, Serrated Edge and Conductor tint the blade; Cinder Shot and Barbed Bolts the bolts.

const FX_FRAMES := 14

var kit: KitView
var actors: ActorViews
## Kept for the view's life so item effects (echo, ring, afterimages) compile their shader once, not on the first
## effect after a quiet spell (the v0.2.0 H rule).
var _fx_template := _make_fx_template()
var _sig := ""
var _last_echo := -1
var _last_shock := -1
var _fx: Array = []
var _was_dashing := false
var _burning := {}


func _init(p_kit: KitView, p_actors: ActorViews) -> void:
	kit = p_kit
	actors = p_actors


func sync(reader: WorldReader) -> void:
	_sync_looks(reader)
	if reader.echo_tick() != _last_echo:
		_last_echo = reader.echo_tick()
		if _last_echo >= 0:
			_flash_arc(
				reader,
				reader.echo_angle(),
				reader.echo_step(),
				ItemLooks.color(WorldReader.ITEM_TWIN_ARC)
			)
	if reader.overcharge_tick() != _last_shock:
		_last_shock = reader.overcharge_tick()
		if _last_shock >= 0:
			_ring(
				reader.player_pos(),
				reader.shockwave_radius_m(),
				ItemLooks.color(WorldReader.ITEM_OVERCHARGE)
			)
	var dashing := reader.is_dashing()
	if dashing and reader.has_item_kind(WorldReader.ITEM_KINETIC_DASH):
		_afterimage(reader.player_pos(), ItemLooks.color(WorldReader.ITEM_KINETIC_DASH))
	_was_dashing = dashing
	_sync_burns(reader)


## The bolt look ActorViews applies to new player bolts.
static func bolt_look(reader: WorldReader) -> Dictionary:
	var look := {
		"size": Vector3(0.38, 0.07, 0.07),
		"color": ThemePalette.color(&"player_core"),
		"energy": 2.5
	}
	if reader.has_item_kind(WorldReader.ITEM_RAPID_COIL):
		look["size"] = Vector3(0.62, 0.06, 0.06)
	if reader.has_item_kind(WorldReader.ITEM_SPLINTER_SHOT):
		look["size"] = look["size"] * Vector3(0.75, 1, 1)
		look["color"] = look["color"].lerp(ItemLooks.color(WorldReader.ITEM_SPLINTER_SHOT), 0.5)
	if reader.has_item_kind(WorldReader.ITEM_RICOCHET_CORE):
		look["color"] = look["color"].lerp(Color.WHITE, 0.6)
		look["energy"] = 4.5
	for k: int in [WorldReader.ITEM_CINDER_SHOT, WorldReader.ITEM_BARBED_BOLTS]:
		if reader.has_item_kind(k):
			look["color"] = look["color"].lerp(ItemLooks.color(k), 0.55)
	return look


func _sync_looks(reader: WorldReader) -> void:
	var owned := reader.items_owned()
	var sig := "%s|%s" % [owned, reader.swing_overcharged()]
	if sig == _sig:
		return
	_sig = sig
	var c := ThemePalette.color(&"player_core")
	var width := 1.0
	var trail := 6
	# v0.3.0 G: each elemental blade item pulls the blade toward its colour; Ember Edge wins outright.
	for k: int in [
		WorldReader.ITEM_CONDUCTOR, WorldReader.ITEM_SERRATED_EDGE, WorldReader.ITEM_GLACIAL_EDGE
	]:
		if reader.has_item_kind(k):
			c = c.lerp(ItemLooks.color(k), 0.7)
	if reader.has_item_kind(WorldReader.ITEM_EMBER_EDGE):
		c = ItemLooks.color(WorldReader.ITEM_EMBER_EDGE)
	if reader.has_item_kind(WorldReader.ITEM_TWIN_ARC):
		trail = 11
	if reader.has_item_kind(WorldReader.ITEM_OVERCHARGE):
		width = 1.15
		if reader.swing_overcharged():
			width = 1.7
			c = c.lerp(ItemLooks.color(WorldReader.ITEM_OVERCHARGE), 0.6)
	kit.set_look(c, 1.0, width, trail)
	actors.bolt_look = bolt_look(reader)


func _sync_burns(reader: WorldReader) -> void:
	var now := {}
	var frozen := {}
	for i in range(1, reader.actor_count()):
		if reader.actor_frozen(i):
			frozen[reader.actor_id(i)] = true
			now[reader.actor_id(i)] = 1
		elif reader.burn_stacks(i) > 0:
			now[reader.actor_id(i)] = reader.burn_stacks(i)
	for id in now:
		if frozen.has(id):
			actors.set_tint(id, ItemLooks.status_color(&"frozen"), 1.1)
		else:
			actors.set_tint(id, ItemLooks.color(WorldReader.ITEM_EMBER_EDGE), 0.4 + 0.15 * now[id])
	for id in _burning:
		if not now.has(id):
			actors.set_tint(id, Color.BLACK, 0.0)
	_burning = now


func _unshaded(c: Color, a: float) -> StandardMaterial3D:
	var m := _fx_template.duplicate() as StandardMaterial3D
	m.albedo_color = Color(c, a)
	return m


static func _make_fx_template() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add_fx(n: MeshInstance3D, mat: StandardMaterial3D, grow: float) -> void:
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(n)
	_fx.append([n, mat, FX_FRAMES, mat.albedo_color.a, grow])


## Twin Arc's echo: the echoed step's own arc (the shape it hit with).
func _flash_arc(reader: WorldReader, angle: int, step: int, c: Color) -> void:
	var shape := reader.swing_shape(step)
	var n := MeshInstance3D.new()
	n.mesh = KitView.fan_mesh(shape[0], shape[2] + 0.2, shape[1])
	n.position = SimPlane.to_3d(reader.player_pos(), 0.45)
	n.rotation = Vector3(0, SimPlane.yaw_of(angle), 0)
	_add_fx(n, _unshaded(c, 0.45), 0.0)


func _ring(at: Vector2, radius: float, c: Color) -> void:
	var n := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	n.mesh = torus
	n.position = SimPlane.to_3d(at, 0.15)
	n.scale = Vector3(0.4, 0.08, 0.4)
	_add_fx(n, _unshaded(c, 0.9), 0.6)


func _afterimage(at: Vector2, c: Color) -> void:
	var n := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.9, 0.5)
	n.mesh = box
	n.position = SimPlane.to_3d(at, 0.45)
	# Over the white dash trail every dash leaves (DashTrail draws at priority -1), so the cyan stays readable.
	var m := _unshaded(c, 0.5)
	m.render_priority = 1
	_add_fx(n, m, 0.0)


func fx_count() -> int:
	return _fx.size()


func _process(_delta: float) -> void:
	for k in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[k]
		fx[2] -= 1
		var t := float(fx[2]) / FX_FRAMES
		(fx[1] as StandardMaterial3D).albedo_color.a = fx[3] * t
		if fx[4] > 0.0:
			var s: float = 1.0 - (1.0 - fx[4]) * t
			(fx[0] as Node3D).scale = Vector3(s, 0.08, s)
		if fx[2] <= 0:
			(fx[0] as Node).queue_free()
			_fx.remove_at(k)
