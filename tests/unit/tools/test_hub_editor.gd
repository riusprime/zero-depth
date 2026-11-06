extends GutTest
## v0.9.0 HE: the hub editor (tools/hub_editor). A handle for every placed piece, named for it; saving with no moves
## leaves the hub file byte for byte the same; a moved handle saves at the plan point it was dragged to (the game's
## own plan -> sim -> 3D mapping), changing only its lines; a file missing a line it expects is left untouched. It
## saves to a temp copy of the hub file, never the real one.

const HubEditorScript := preload("res://tools/hub_editor/hub_editor.gd")
const TMP := "user://test_hub_editor_rune_ring.tres"

var _hub: HubDefinition
var _original: String


func before_each() -> void:
	_original = FileAccess.get_file_as_string(HubEditorScript.HUB_PATH)
	_write(_original)
	_hub = ResourceLoader.load(HubEditorScript.HUB_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)


func after_each() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _editor() -> Node3D:
	var e: Node3D = HubEditorScript.new()
	e.warn_overlaps = false
	add_child_autofree(e)
	e.build(_hub)
	return e


func _write(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _saved() -> HubDefinition:
	return ResourceLoader.load(TMP, "", ResourceLoader.CACHE_MODE_IGNORE)


func _positions(h: HubDefinition) -> Dictionary:
	var out := {"spawn": h.spawn, "alcove": h.alcove_at, "pillars": Array(h.pillars)}
	for s in h.stations:
		out[s.id] = s.at
	var props := []
	for d in h.props:
		props.append([d["id"], d["at"], d["half"]])
	out["props"] = props
	return out


func test_every_piece_has_a_named_handle_on_the_floor() -> void:
	var e := _editor()
	var names: Array = e.handles().map(func(n: Node3D) -> String: return String(n.name))
	for s in _hub.stations:
		assert_has(names, "Station_%s" % s.id)
	assert_has(names, "Pillar_0")
	assert_has(names, "Pillar_%d" % (_hub.pillars.size() - 1))
	assert_has(names, "Prop_3_%s" % _hub.props[3]["id"])
	assert_has(names, "Spawn")
	assert_has(names, "Alcove")
	assert_eq(names.size(), _hub.stations.size() + _hub.pillars.size() + _hub.props.size() + 2)
	for h: Node3D in e.handles():
		assert_eq(h.position.y, 0.0, "%s on the floor" % h.name)
	assert_not_null(e.plan.get_node_or_null("Fixed/PortalMachine"), "the machine is drawn")
	var arch: Node3D = e.plan.get_node("Station_archive")
	assert_gt(arch.get_child_count(), 1, "the station's own view hangs under its handle")


func test_saving_with_no_moves_writes_the_same_positions() -> void:
	var before := _positions(_hub)
	var e := _editor()
	assert_eq(e.save_to_data(TMP), OK)
	assert_eq(FileAccess.get_file_as_string(TMP), _original, "the file is byte for byte the same")
	var after := _saved()
	assert_eq_deep(_positions(after), before)
	assert_eq(after.radius_m, _hub.radius_m, "other fields untouched")
	assert_eq(after.stations.size(), _hub.stations.size())
	assert_eq(after.states.size(), _hub.states.size())


func test_a_moved_handle_saves_at_its_plan_point() -> void:
	var e := _editor()
	var target := Vector2(-6.25, 9.5)
	var h: Node3D = e.plan.get_node("Station_runic")
	# Dragged in the viewport: placed where the game draws plan point `target` (HubLayout -> SimPlane).
	h.global_position = SimPlane.to_3d(HubLayout.to_sim(target))
	var p: Node3D = e.plan.get_node("Prop_3_%s" % _hub.props[3]["id"])
	p.position = Vector3(1.23456, 0.0, -2.0)
	assert_eq(e.save_to_data(TMP), OK)
	var after := _saved()
	var credits: HubStationDefinition = null
	for s in after.stations:
		if s.id == &"runic":
			credits = s
	assert_almost_eq(credits.at, target, Vector2.ONE * 0.0011)
	assert_eq(after.props[3]["at"], Vector2(1.235, 2.0), "rounded to 3 decimals")
	assert_eq(after.spawn, _hub.spawn, "the others stay")
	var old_lines := _original.split("\n")
	var new_lines := FileAccess.get_file_as_string(TMP).split("\n")
	assert_eq(new_lines.size(), old_lines.size())
	var changed := []
	for i in old_lines.size():
		if old_lines[i] != new_lines[i]:
			changed.append(new_lines[i])
	assert_eq(changed.size(), 2, "only the credits' `at` line and the props line change")
	assert_has(changed, "at = Vector2(-6.25, 9.5)")
	assert_true(String(changed[1]).contains('"at": Vector2(1.235, 2)'), str(changed))


func test_a_missing_line_saves_nothing() -> void:
	var broken := _original.replace("\nalcove_at = ", "\nalcove_somewhere = ")
	_write(broken)
	var e := _editor()
	e.plan.get_node("Spawn").position = Vector3(1.0, 0.0, 10.0)
	assert_ne(e.save_to_data(TMP), OK)
	assert_push_error("no `alcove_at = ` line")
	assert_push_error("nothing saved")
	assert_eq(FileAccess.get_file_as_string(TMP), broken, "the file is left as it was")


func test_overlaps_are_reported() -> void:
	var e := _editor()
	var h: Node3D = e.plan.get_node("Station_archive")
	h.position = Vector3(0.5, 0.0, -0.5)
	var warnings: PackedStringArray = e.check()
	assert_true(
		Array(warnings).any(func(w: String) -> bool: return w.contains("Portal Machine")),
		"a station on the machine warns"
	)
