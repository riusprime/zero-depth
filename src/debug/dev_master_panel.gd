class_name DevMasterPanel
extends PanelContainer
## The master dev panel (F10, every build: docs/tools/DEV_PANEL.md; owner 2026-10-12: "a master dev panel, not only
## for lighting, but … all the variables that affect the balancing of the game"). Left: the groups (lighting, player,
## enemies, bosses, difficulty, economy, build pieces, tools) and their content files, with a search box. Right: the
## chosen file's fields (DevFields), each with its shipped value and a reset. Top: Restart floor, Reset all, Copy
## changes, Close. Every edit goes into the tuning store (DevTuning), is saved at once and announced through
## `changed`; Main applies it live (lighting, balance) and Restart floor rebuilds the floor from it.
## Field names are the content's own (a developer tool); the panel's own words go through tr() (EI-10).

signal changed(key: String)
signal restart_requested
signal close_requested

const ROW_H := 26.0

var tuning: DevTuning
## The old debug panel's buttons (pause, step, spawn, god mode …), shown on the Tools page when in a run.
var tools: Control
var _tree := Tree.new()
var _search := LineEdit.new()
var _fields := VBoxContainer.new()
var _title := Label.new()
var _hint := Label.new()
var _status := Label.new()
var _source := ""
var _filter := ""
var _editors := {}


func _init(p_tuning: DevTuning, p_tools: Control = null) -> void:
	name = "DevMasterPanel"
	tuning = p_tuning
	tools = p_tools
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 24
	offset_top = 24
	offset_right = -24
	offset_bottom = -24
	var col := VBoxContainer.new()
	add_child(col)
	col.add_child(_top_bar())
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 320
	col.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	split.add_child(left)
	_search.placeholder_text = "UI_DEVM_SEARCH"
	_search.text_changed.connect(func(_t: String) -> void: _fill_tree())
	left.add_child(_search)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tree.item_selected.connect(_on_pick)
	left.add_child(_tree)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	right.add_child(_title)
	_hint.modulate = Color(1, 1, 1, 0.65)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fields)
	_fill_tree()
	_refresh_status()


func _top_bar() -> Control:
	var bar := HBoxContainer.new()
	var t := Label.new()
	t.text = "UI_DEVM_TITLE"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(t)
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bar.add_child(_status)
	for spec: Array in [
		["UI_DEVM_RESTART", func() -> void: restart_requested.emit()],
		["UI_DEVM_RESET_ALL", reset_all],
		["UI_DEVM_COPY", copy_changes],
		["UI_DEVM_CLOSE", func() -> void: close_requested.emit()],
	]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		bar.add_child(b)
	return bar


# --- The list -----------------------------------------------------------------------------------------------------
func _fill_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var q := _search.text.strip_edges().to_lower()
	for g: Array in DevFields.GROUPS:
		var group := _tree.create_item(root)
		group.set_text(0, tr(g[1]))
		group.set_selectable(0, false)
		var shown := 0
		for path in DevFields.sources(g):
			var label := DevFields.label_of(path)
			if q != "" and not label.contains(q):
				continue
			var it := _tree.create_item(group)
			it.set_text(0, label + (" *" if _touched(path, g[3]) else ""))
			it.set_metadata(0, [path, g[3]])
			shown += 1
		if shown == 0:
			group.free()
	if tools != null:
		var t := _tree.create_item(root)
		t.set_text(0, tr("UI_DEVM_G_TOOLS"))
		t.set_metadata(0, ["tools", ""])


func _touched(path: String, filter: String) -> bool:
	for k: String in tuning.overrides:
		var parts := DevTuning.split_key(k)
		if parts[0] == path and (filter == "" or parts[1].begins_with(filter)):
			return true
	return false


func _on_pick() -> void:
	var it := _tree.get_selected()
	if it == null or it.get_metadata(0) == null:
		return
	var meta: Array = it.get_metadata(0)
	show_source(meta[0], meta[1])


## The Tools page is built by Main for this panel; freed with it whether or not it was ever shown (v0.7.5: it was
## left as an orphan when the panel closed without visiting Tools).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(tools) and tools.get_parent() == null:
		tools.free()


## Shows the fields of the content file `path` (only those under `filter`, "" = all), or the Tools page.
func show_source(path: String, filter: String = "") -> void:
	_source = path
	_filter = filter
	_editors.clear()
	if tools != null and tools.get_parent() == _fields:
		_fields.remove_child(tools)  # the Tools page is kept for the next visit, not freed with the rows
	for c in _fields.get_children():
		c.queue_free()
	if path == "tools":
		_title.text = tr("UI_DEVM_G_TOOLS")
		_hint.text = ""
		if tools != null:
			if tools.get_parent() != null:
				tools.get_parent().remove_child(tools)
			_fields.add_child(tools)
		return
	_title.text = path.trim_prefix("res://")
	_hint.text = hint_key(path)
	var res: Resource = load(path)
	for row: Dictionary in DevFields.rows(res, filter):
		_fields.add_child(_row(path, row["path"], row["value"]))


func _row(path: String, field: String, value: Variant) -> Control:
	var key := DevTuning.key_of(path, field)
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, ROW_H)
	var name_l := Label.new()
	name_l.text = field
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tuning.is_overridden(key):
		name_l.modulate = Color(1.0, 0.75, 0.3)
	h.add_child(name_l)
	var ed := _editor(key, value)
	ed.custom_minimum_size = Vector2(160, 0)
	h.add_child(ed)
	var shipped := Label.new()
	shipped.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	shipped.custom_minimum_size = Vector2(110, 0)
	shipped.text = "(%s)" % DevTuning._show(tuning.shipped_value(key))
	shipped.modulate = Color(1, 1, 1, 0.5)
	h.add_child(shipped)
	var back := Button.new()
	back.text = "UI_DEVM_RESET"
	back.pressed.connect(func() -> void: reset_key(key))
	h.add_child(back)
	_editors[key] = ed
	return h


func _editor(key: String, value: Variant) -> Control:
	match typeof(value):
		TYPE_BOOL:
			var c := CheckBox.new()
			c.button_pressed = value
			c.toggled.connect(func(on: bool) -> void: set_value(key, on))
			return c
		TYPE_COLOR:
			var p := ColorPickerButton.new()
			p.color = value
			p.color_changed.connect(func(col: Color) -> void: set_value(key, col))
			return p
	var s := SpinBox.new()
	s.allow_greater = true
	s.allow_lesser = true
	s.min_value = -1.0e9
	s.max_value = 1.0e9
	s.step = 1.0 if typeof(value) == TYPE_INT else 0.001
	s.value = float(value)
	s.select_all_on_focus = true
	s.update_on_text_changed = true  # live while typing, not only on Enter
	s.value_changed.connect(func(v: float) -> void: set_value(key, v))
	return s


## When a file's numbers take effect (LiveTuning): lighting at once; most balance when the panel closes; HP and
## shards of enemies and bosses on the next spawns; what the floor lays out, and the run's per-floor numbers, on
## Restart floor.
static func hint_key(path: String) -> String:
	var dir := path.trim_prefix("res://data/").get_slice("/", 0)
	match dir:
		"biomes":
			return "UI_DEVM_HINT_LIVE"
		"enemies", "bosses", "boss_pools":
			return "UI_DEVM_HINT_SPAWN"
		"run", "events", "event_rules", "curses":
			return "UI_DEVM_HINT_RESTART"
	return "UI_DEVM_HINT_CLOSE"


# --- Edits --------------------------------------------------------------------------------------------------------
## Sets one field (typed like its shipped value), saves the store and announces it.
func set_value(key: String, value: Variant) -> void:
	var parts := DevTuning.split_key(key)
	tuning.set_value(parts[0], parts[1], value)
	_commit(key)


func reset_key(key: String) -> void:
	tuning.clear(key)
	_commit(key)
	if _source != "":
		show_source(_source, _filter)


func reset_all() -> void:
	var keys := tuning.overrides.keys()
	tuning.reset_all()
	tuning.apply()
	tuning.save()
	for k: String in keys:
		changed.emit(k)
	_fill_tree()
	if _source != "":
		show_source(_source, _filter)
	_refresh_status()


## Puts the list of changes on the clipboard (to paste to the lead, who writes them into the content files).
func copy_changes() -> String:
	var text := tuning.copy_text()
	DisplayServer.clipboard_set(text)
	_status.text = tr("UI_DEVM_COPIED") % tuning.overrides.size()
	return text


func _commit(key: String) -> void:
	tuning.apply()
	tuning.save()
	changed.emit(key)
	_refresh_status()


func _refresh_status() -> void:
	var n := tuning.overrides.size()
	_status.text = (tr("UI_DEVM_CHANGES") % n) if n > 0 else ""


## How many field rows the page shows (tests).
func row_count() -> int:
	return _editors.size()


func editor_of(key: String) -> Control:
	return _editors.get(key)
