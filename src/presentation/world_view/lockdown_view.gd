class_name LockdownView
extends Node3D
## v0.9.0 LK (owner Q21: "a visible seal with a sound"; FV, MI2: the owner's bar gate is `lockdown_seal`; W24, W71: a
## hazard per biome, each with a ground warning before it hurts): the floor's Lockdowns, reading only
## (WorldReader.lockdown, lockdown_doors).
## - The bars: in every doorway of every Lockdown room, iron bars (the owner's `lockdown_seal` through ShopModels, 0.4 x
##   2.6 x 3.0 m, stretched across the doorway's width; a code stand-in of iron rods when it isn't listed) wait above
##   the doorway, unseen. On the seal they slide down into it (DROP_S, a slam: take_thud asks the camera for a thud);
##   on the open they grind up out of sight (RISE_S). The sounds are AudioEvents' (`lockdown_close`, `lockdown_open`).
## - Hazard Lockdowns: each strike marked on the ground shows a warning disc that fills and brightens until it lands;
##   then the biome's hazard (Ruins sparking cables `hazard_cable`, Night Rocks a falling rock `hazard_rock`, Red
##   Canyon a heat vent `hazard_vent`, Frozen Shore cracking ice `hazard_ice`, Starfall a falling star `hazard_star`;
##   through ShopModels by those ids, code stand-ins until the owner's files arrive) bursts or falls there for IMPACT_S.

const MODEL_SEAL := &"lockdown_seal"
## The biomes' hazard props (docs/art/requests/v0.9.0_ART_LIST.md), and the ones that fall from the sky.
const HAZARDS := {
	&"ruins": &"hazard_cable",
	&"night_rocks": &"hazard_rock",
	&"red_canyon": &"hazard_vent",
	&"frozen_shore": &"hazard_ice",
	&"starfall": &"hazard_star",
}
const FALLING := [&"hazard_rock", &"hazard_star"]
const SEAL_H := 2.6
## How high the bars wait above the doorway (m), and how long they take to drop and to rise (s).
const LIFT_M := 3.0
const DROP_S := 0.3
const RISE_S := 1.3
const ROD_GAP := 0.32
const WARN := Color("#FF5A1F")
const IMPACT_S := 0.6
const THUD := 0.35

var uses_model := false
var hazard_id := &""
var hazard_uses_model := false
## The bars came down since the last take_thud (the camera's thud).
var _thud := false
## Each Lockdown room's bars (one root a doorway) and how far down they are (0 up, unseen .. 1 in the doorway).
var _bars := {}
var _down := {}
var _goal := {}
var _sealed := -1
var _marks: Array[MeshInstance3D] = []
var _mark_mat := StandardMaterial3D.new()
var _iron := StandardMaterial3D.new()
var _impact: Node3D
var _impact_left := 0.0
var _landed := -1


func setup(reader: WorldReader, biome: StringName) -> void:
	name = "Lockdowns"
	_iron.albedo_color = Color("#2E2B29")
	_iron.metallic = 0.6
	_iron.roughness = 0.55
	var d := reader.lockdown()
	var kinds: PackedInt32Array = d["kinds"]
	var rooms: PackedInt32Array = d["rooms"]
	var any_hazard := false
	for k in rooms.size():
		var room := rooms[k]
		var roots: Array[Node3D] = []
		for door: Dictionary in reader.lockdown_doors(room):
			roots.append(_build_bars(room, door))
		_bars[room] = roots
		_down[room] = 0.0
		_goal[room] = 0.0
		if k < kinds.size() and kinds[k] == WorldReader.LOCKDOWN_HAZARD:
			any_hazard = true
	if any_hazard:
		_build_hazard(biome)
	_sealed = int(d["sealed"])
	if _sealed >= 0:  # a floor resumed sealed: the bars already stand
		_down[_sealed] = 1.0
		_goal[_sealed] = 1.0
	_apply()
	sync(reader)


func sync(reader: WorldReader) -> void:
	var d := reader.lockdown()
	var sealed := int(d["sealed"])
	if sealed != _sealed:
		if _sealed >= 0:
			_goal[_sealed] = 0.0
		if sealed >= 0 and _goal.has(sealed):
			_goal[sealed] = 1.0
		_sealed = sealed
	_sync_marks(reader, d)
	var landed := int(d["landed_tick"])
	if landed >= 0 and landed != _landed and _impact != null:
		_impact.position = SimPlane.to_3d(d["landed_pos"])
		_impact.visible = true
		_impact_left = IMPACT_S
	_landed = landed


func _process(delta: float) -> void:
	for room: int in _down:
		var now: float = _down[room]
		var goal: float = _goal[room]
		if now < goal:
			_down[room] = minf(goal, now + delta / DROP_S)
			if _down[room] >= 1.0:
				_thud = true
		elif now > goal:
			_down[room] = maxf(goal, now - delta / RISE_S)
	_apply()
	if _impact != null and _impact_left > 0.0:
		_impact_left -= delta
		var t := clampf(1.0 - _impact_left / IMPACT_S, 0.0, 1.0)
		var drop := (1.0 - minf(1.0, t * 3.0)) * 6.0 if FALLING.has(hazard_id) else 0.0
		var base := 0.0 if hazard_uses_model else _base_y(hazard_id)  # a model stands on the floor
		(_impact.get_child(0) as Node3D).position.y = base + drop
		_impact.visible = _impact_left > 0.0


## Whether the bars slammed down since the last call (the camera's thud), once.
func take_thud() -> bool:
	var t := _thud
	_thud = false
	return t


## The hazard prop's height off the floor (its stand-in's middle).
static func _base_y(id: StringName) -> float:
	match id:
		&"hazard_vent":
			return 1.1
		&"hazard_cable":
			return 0.8
		&"hazard_ice":
			return 0.45
		_:
			return 0.5


func _apply() -> void:
	for room: int in _bars:
		var down: float = _down[room]
		for root: Node3D in _bars[room]:
			var bars := root.get_child(0) as Node3D
			bars.position.y = LIFT_M * (1.0 - down)
			bars.visible = down > 0.001


## Tests: how far down room `room`'s bars are (0 up and unseen .. 1 in the doorways), their doorways, and the
## warnings shown now.
func bars_down(room: int) -> float:
	return float(_down.get(room, 0.0))


func bars_visible(room: int) -> bool:
	for root: Node3D in _bars.get(room, []):
		if (root.get_child(0) as Node3D).visible:
			return true
	return false


func door_count(room: int) -> int:
	return (_bars.get(room, []) as Array).size()


func warnings_shown() -> int:
	var n := 0
	for m in _marks:
		if m.visible:
			n += 1
	return n


## Settles the bars at once (tests; a frame's _process does it over DROP_S / RISE_S in play).
func settle() -> void:
	for room: int in _down:
		_down[room] = _goal[room]
	_apply()


func _build_bars(room: int, door: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Seal%d_%d" % [room, get_child_count()]
	root.position = SimPlane.to_3d(door["center"])
	root.rotation.y = SimPlane.yaw_of(int(door["angle"]))
	add_child(root)
	var bars := Node3D.new()
	bars.name = "Bars"
	root.add_child(bars)
	var width: float = door["width"]
	var model := ShopModels.get_model(MODEL_SEAL)
	if not model.is_empty():
		uses_model = true
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = model["mesh"]
		mi.set_surface_override_material(0, model["material"])
		mi.scale = Vector3(1.0, 1.0, width / 3.0)
		bars.add_child(mi)
		return root
	var rods := maxi(2, int(width / ROD_GAP))
	for k in rods:
		var z := -width * 0.5 + (float(k) + 0.5) * width / float(rods)
		var c := CylinderMesh.new()
		c.top_radius = 0.045
		c.bottom_radius = 0.045
		c.height = SEAL_H
		c.radial_segments = 6
		var rod := MeshInstance3D.new()
		rod.mesh = c
		rod.material_override = _iron
		rod.position = Vector3(0.0, SEAL_H * 0.5, z)
		bars.add_child(rod)
	for y in [0.35, SEAL_H - 0.3]:
		var b := BoxMesh.new()
		b.size = Vector3(0.14, 0.12, width)
		var bar := MeshInstance3D.new()
		bar.mesh = b
		bar.material_override = _iron
		bar.position = Vector3(0.0, y, 0.0)
		bars.add_child(bar)
	return root


## The warnings' pool and the biome's hazard prop (its model, else a stand-in).
func _build_hazard(biome: StringName) -> void:
	hazard_id = HAZARDS.get(biome, &"hazard_cable")
	_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_mat.albedo_color = Color(WARN, 0.5)
	_mark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 3:
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 0.03
		c.radial_segments = 24
		var m := MeshInstance3D.new()
		m.name = "Warning%d" % k
		m.mesh = c
		m.material_override = _mark_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_marks.append(m)
	_impact = Node3D.new()
	_impact.name = "Hazard"
	_impact.visible = false
	add_child(_impact)
	var model := ShopModels.get_model(hazard_id)
	var mi := MeshInstance3D.new()
	mi.name = "Model" if not model.is_empty() else "StandIn"
	if not model.is_empty():
		hazard_uses_model = true
		mi.mesh = model["mesh"]
		mi.set_surface_override_material(0, model["material"])
	else:
		mi.mesh = _stand_in(hazard_id)
		mi.material_override = _stand_in_mat(hazard_id)
	_impact.add_child(mi)


func _sync_marks(reader: WorldReader, d: Dictionary) -> void:
	var at: PackedVector2Array = d.get("strike_pos", PackedVector2Array())
	var due: PackedInt32Array = d.get("strike_tick", PackedInt32Array())
	var warn := maxi(1, int(d.get("warn_ticks", 1)))
	var r := float(d.get("radius", 1.0))
	for k in _marks.size():
		var m := _marks[k]
		m.visible = k < at.size()
		if not m.visible:
			continue
		var t := clampf(1.0 - float(due[k] - reader.tick()) / float(warn), 0.0, 1.0)
		var s := r * (0.35 + 0.65 * t)
		m.scale = Vector3(s, 1.0, s)
		m.position = SimPlane.to_3d(at[k], 0.03)
	_mark_mat.albedo_color = Color(WARN, 0.35 + 0.4 * absf(fmod(reader.tick() / 8.0, 2.0) - 1.0))


static func _stand_in(id: StringName) -> Mesh:
	match id:
		&"hazard_rock", &"hazard_star":
			var s := SphereMesh.new()
			s.radius = 0.55 if id == &"hazard_rock" else 0.35
			s.height = s.radius * 2.0
			s.radial_segments = 8
			s.rings = 4
			return s
		&"hazard_vent":
			var c := CylinderMesh.new()
			c.top_radius = 0.2
			c.bottom_radius = 0.7
			c.height = 2.2
			return c
		&"hazard_ice":
			var p := PrismMesh.new()
			p.size = Vector3(1.4, 0.9, 1.4)
			return p
		_:
			var b := BoxMesh.new()
			b.size = Vector3(0.18, 1.6, 0.18)
			return b


static func _stand_in_mat(id: StringName) -> StandardMaterial3D:
	var colors := {
		&"hazard_cable": Color("#7FD8FF"),
		&"hazard_rock": Color("#5C5A66"),
		&"hazard_vent": Color("#FF7A2A"),
		&"hazard_ice": Color("#CDEFFF"),
		&"hazard_star": Color("#FFF2A8"),
	}
	var m := StandardMaterial3D.new()
	var c: Color = colors.get(id, WARN)
	m.albedo_color = c
	m.emission_enabled = id != &"hazard_rock"
	m.emission = c
	m.emission_energy_multiplier = 2.0
	return m
