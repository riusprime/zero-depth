@tool
extends Node3D
## v0.9.0 HE (owner: "build the hub editor scene so I can drag things in Godot and save back to the data file"): an
## editor-only scene that draws the hub as the game does (HubDressing, HubStations, HubMachine) and gives each piece
## that has a place in data/hub/rune_ring.tres a handle to drag. Never part of the game: it lives outside src/ and the
## export leaves tools/ out.
##
## How to use it:
## 1. Open tools/hub_editor/hub_editor.tscn in the Godot editor. The hub draws itself (the floor, the walls, the gate
##    and the Portal Machine are fixed; they follow the data's radius).
## 2. Click a piece in the 3D view (or pick it in the Scene dock: Station_shop, Pillar_2, Prop_3_hub_crates, Spawn,
##    Alcove) and drag it with the move gizmo. It stays on the floor and turns to face the plaza's middle, as in game.
## 3. Select the HubEditor root node and press "Save to data" in the Inspector: every handle's place is written back to
##    the hub file as plan points (3 decimals). Only the positions change.
## 4. "Reload from data" throws away unsaved moves. The Output panel warns when a piece overlaps another or the
##    machine, or stands past the wall.
## You don't need to save the scene itself (Ctrl+S); the hub file is what the game reads.

const HUB_PATH := "res://data/hub/rune_ring.tres"
## Handle names start with these (the save reads them back by name).
const STATION := "Station_"
const PILLAR := "Pillar_"
const PROP := "Prop_"
const SPAWN := "Spawn"
const ALCOVE := "Alcove"
const LABEL_Y := 3.6

## The hub file the handles come from and save to.
@export_file("*.tres") var hub_path := HUB_PATH
@export_tool_button("Save to data", "Save") var save_button := save_to_data
@export_tool_button("Reload from data", "Reload") var reload_button := reload_from_data
## Warn in the Output panel when a moved piece overlaps another, the machine, or the wall.
@export var warn_overlaps := true

var hub: HubDefinition
## The plan frame, as HubView's: plan (x, y) is local (x, 0, -y), the whole frame turned 45° on the floor.
var plan: Node3D
## Handle -> the plan point it was last seen at (to notice drags).
var _seen := {}


func _ready() -> void:
	if Engine.is_editor_hint():
		reload_from_data()


## Throws away the handles and draws the hub again from the file on disk.
func reload_from_data() -> void:
	var res := ResourceLoader.load(hub_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not res is HubDefinition:
		push_error("Hub editor: %s is not a HubDefinition" % hub_path)
		return
	build(res)
	print("Hub editor: loaded %s" % hub_path)


## Draws `p_hub` and its handles (replacing any from before).
func build(p_hub: HubDefinition) -> void:
	hub = p_hub
	_seen.clear()
	var old := get_node_or_null("Plan")
	if old != null:
		remove_child(old)
		old.free()
	plan = Node3D.new()
	plan.name = "Plan"
	plan.rotation.y = PI * 0.25  # HubLayout.to_sim's 45°, on the 3D floor
	plan.set_meta(&"_edit_lock_", true)  # dragging the frame would move nothing in the data
	add_child(plan)
	_own(plan)
	_build_fixed()
	_build_handles()
	for h in handles():
		_seen[h] = plan_point(h)
	check()


## The floor, walls, gate and machine (not draggable: they follow the hub's sizes, not a point).
func _build_fixed() -> void:
	var fixed := Node3D.new()
	fixed.name = "Fixed"
	plan.add_child(fixed)
	HubDressing.ground(fixed, hub)
	HubDressing.walls(fixed, hub)
	HubDressing.gate(fixed, hub, hub.radius_m + hub.wall_m * 0.5)
	var machine := HubMachine.new()
	fixed.add_child(machine)
	_label(machine, "Portal Machine (fixed)", Color.WHITE)


func _build_handles() -> void:
	var no_trophies: Array[bool] = []
	for s in hub.stations:
		var h := _handle(STATION + String(s.id), s.at)
		HubView.build_station(h, s, no_trophies)
	var scratch := Node3D.new()
	HubDressing.pillars(scratch, hub)
	HubDressing.props(scratch, hub)
	var pillar_i := 0
	var prop_i := 0
	for n in scratch.get_children():
		var h: Node3D
		if n.name.begins_with("Pillar"):
			h = _handle(PILLAR + str(pillar_i), hub.pillars[pillar_i])
			pillar_i += 1
		else:
			var d: Dictionary = hub.props[prop_i]
			h = _handle(PROP + "%d_%s" % [prop_i, d["id"]], d["at"])
			prop_i += 1
		scratch.remove_child(n)
		n.position = Vector3.ZERO
		n.rotation = Vector3.ZERO
		h.add_child(n)
	scratch.free()
	var spawn := _handle(SPAWN, hub.spawn)
	HubProps.floor_pool(spawn, "Mark", HubProps.BLUE, Vector3(0, 0.03, 0), 1.6)
	var alcove := _handle(ALCOVE, hub.alcove_at)
	HubProps.cylinder(
		alcove,
		"Floor",
		hub.alcove_r,
		hub.alcove_r,
		0.1,
		HubProps.stone(HubProps.VIOLET.darkened(0.4)),
		Vector3(0, 0.02, 0),
		24
	)


## A draggable handle named `n` at plan point `at`, turned to the middle like its piece, labelled.
func _handle(n: String, at: Vector2) -> Node3D:
	var h := Node3D.new()
	h.name = n
	h.position = Vector3(at.x, 0.0, -at.y)
	h.rotation.y = HubLayout.facing(at)
	plan.add_child(h)
	_own(h)
	_label(h, n, Color(1.0, 0.85, 0.3))
	return h


## A name floating over `parent`, readable from any side (not part of the data).
func _label(parent: Node3D, text: String, c: Color) -> void:
	var l := Label3D.new()
	l.name = "Label"
	l.text = text
	l.modulate = c
	l.font_size = 48
	l.pixel_size = 0.01
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0, LABEL_Y, 0)
	parent.add_child(l)


## In the editor, a node the Scene dock lists and the viewport can select (its drawn children stay unlisted, so a
## click on a model selects its handle).
func _own(n: Node) -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		var root := get_tree().edited_scene_root
		if root != null and (root == self or root.is_ancestor_of(self)):
			n.owner = root


## Every handle, in the order they were made.
func handles() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if plan == null:
		return out
	for n in plan.get_children():
		if n is Node3D and n.name != "Fixed":
			out.append(n)
	return out


## The plan point handle `h` stands at (3 decimals).
static func plan_point(h: Node3D) -> Vector2:
	return Vector2(snappedf(h.position.x, 0.001), snappedf(-h.position.z, 0.001))


## Writes every handle's plan point into the hub (its positions only) and saves it to `path` (default: the hub file).
## Returns the ResourceSaver error.
func save_to_data(path: String = "") -> Error:
	if hub == null:
		push_error("Hub editor: nothing loaded")
		return ERR_UNCONFIGURED
	apply_to(hub)
	var to := hub_path if path.is_empty() else path
	var err := ResourceSaver.save(hub, to)
	if err == OK:
		print("Hub editor: saved the positions to %s" % to)
	else:
		push_error("Hub editor: could not save %s (error %d)" % [to, err])
	check()
	return err


## Copies every handle's plan point into `h` (stations' and props' `at`, the pillars, the spawn, the alcove).
func apply_to(h: HubDefinition) -> void:
	var pillars := h.pillars.duplicate()
	var props: Array[Dictionary] = []
	for d in h.props:
		props.append(d.duplicate())
	for node in handles():
		var p := plan_point(node)
		var n := String(node.name)
		if n.begins_with(STATION):
			for s in h.stations:
				if STATION + String(s.id) == n:
					s.at = p
		elif n.begins_with(PILLAR):
			pillars[int(n.trim_prefix(PILLAR))] = p
		elif n.begins_with(PROP):
			props[int(n.trim_prefix(PROP).get_slice("_", 0))]["at"] = p
		elif n == SPAWN:
			h.spawn = p
		elif n == ALCOVE:
			h.alcove_at = p
	h.pillars = pillars
	h.props = props


## Editor only: keeps each dragged handle on the floor, turned to the middle, and warns about overlaps once it moves.
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or plan == null:
		return
	var moved := false
	for h in handles():
		if h.position.y != 0.0:
			h.position.y = 0.0
		var p := plan_point(h)
		if _seen.get(h, p) != p:
			_seen[h] = p
			h.rotation = Vector3(0, HubLayout.facing(p), 0)
			moved = true
	if moved:
		check()


## The warnings (also printed when `warn_overlaps`): pieces closer than their footprints, on the machine, or past the
## wall. A rough round footprint each; the game's own walls are boxes.
func check() -> PackedStringArray:
	var out := PackedStringArray()
	if hub == null:
		return out
	var pieces := []  # [name, plan point, radius]
	for h in handles():
		if h.name != SPAWN and h.name != ALCOVE:
			pieces.append([String(h.name), plan_point(h), _radius_of(String(h.name))])
	var wall := hub.radius_m - hub.wall_m
	for i in pieces.size():
		var a: Array = pieces[i]
		var pa: Vector2 = a[1]
		if pa.length() < hub.machine_core_m + a[2]:
			out.append("%s overlaps the Portal Machine" % a[0])
		if pa.length() + a[2] > wall and not String(a[0]).begins_with(PILLAR):  # rim pillars stand in it
			out.append("%s stands past the wall" % a[0])
		for j in range(i + 1, pieces.size()):
			var b: Array = pieces[j]
			if pa.distance_to(b[1]) < a[2] + b[2]:
				out.append("%s overlaps %s" % [a[0], b[0]])
	if warn_overlaps:
		for w in out:
			push_warning("Hub editor: " + w)
	return out


func _radius_of(n: String) -> float:
	var half := Vector2.ONE * hub.pillar_half_m
	if n.begins_with(STATION):
		for s in hub.stations:
			if STATION + String(s.id) == n:
				half = s.half
	elif n.begins_with(PROP):
		half = hub.props[int(n.trim_prefix(PROP).get_slice("_", 0))].get("half", Vector2.ONE * 0.5)
	return (half.x + half.y) * 0.5
