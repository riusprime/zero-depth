class_name ArchivePage
extends HBoxContainer
## v0.9.0 CL (owner: "collectibles are fine"; COLLECTIBLES.md, P4 "Yes, with the shelf name only, no hint"; PLAN W39,
## W43): the Codex's Collectibles page, the Rune Archive's shelves (Stone, Sealed, Crown, Hub), each a row of niches
## (ArchiveTile) with how many are found. Beside them the focused one: found, its name, its shelf and its lore line;
## not found, "?" and the shelf's name, no hint. Reads the definitions and the profile's finds; changes nothing.

var defs: Array[CollectibleDefinition] = []
var found: Array[bool] = []
var tiles: Array[ArchiveTile] = []
## Where "up" goes from the first shelf (the page's tab).
var top_neighbor: Control
var name_label := Label.new()
var shelf_label := Label.new()
var lore_label := Label.new()
var _list := VBoxContainer.new()
var _shown: ArchiveTile


func _init(p_defs: Array[CollectibleDefinition], p_found: Array[bool]) -> void:
	name = "ArchivePage"
	defs = p_defs
	found = p_found
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 40)
	_list.name = "Shelves"
	_list.add_theme_constant_override("separation", 10)
	_list.custom_minimum_size = Vector2(7 * ArchiveTile.SIZE.x + 6 * 10, 0)
	add_child(_list)
	var panel := PanelContainer.new()
	panel.name = "Detail"
	panel.add_theme_stylebox_override("panel", MenuStyle.stone_panel(Vector2(22, 22)))
	panel.custom_minimum_size = Vector2(520, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	panel.add_child(info)
	name_label.name = "EntryName"
	name_label.add_theme_font_override("font", HudStyle.font(true))
	name_label.add_theme_font_size_override("font_size", 30)
	shelf_label.name = "Shelf"
	shelf_label.add_theme_font_size_override("font_size", MenuStyle.NOTE_SIZE)
	shelf_label.add_theme_color_override("font_color", MenuStyle.DIM)
	lore_label.name = "Lore"
	lore_label.add_theme_font_size_override("font_size", 22)
	for l: Label in [name_label, shelf_label, lore_label]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(470, 0)
		info.add_child(l)


## How many are found ("Found 3 / 16").
func progress_text() -> String:
	return tr("UI_CODEX_FOUND") % [found.count(true), defs.size()]


## Builds the shelves (call again after the finds changed: `p_found`, or the same).
func refresh(p_found: Array[bool] = found) -> void:
	found = p_found
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	tiles.clear()
	var above: Array[ArchiveTile] = []
	for shelf: StringName in CollectibleDefinition.SHELVES:
		var here: Array[ArchiveTile] = []
		var have := 0
		for k in defs.size():
			if defs[k].shelf != shelf:
				continue
			var t := ArchiveTile.new()
			t.show_entry(defs[k], k < found.size() and found[k])
			have += 1 if t.found else 0
			here.append(t)
		if here.is_empty():
			continue
		var head := Label.new()
		head.name = "Head_%s" % shelf
		head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		head.text = "%s   %d / %d" % [tr(CollectibleBook.SHELF_KEYS[shelf]), have, here.size()]
		head.add_theme_font_override("font", HudStyle.font(true))
		head.add_theme_font_size_override("font_size", 18)
		head.add_theme_color_override("font_color", MenuStyle.EMBER.lerp(Color.WHITE, 0.3))
		_list.add_child(head)
		var row := HBoxContainer.new()
		row.name = "Row_%s" % shelf
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		for k in here.size():
			var t := here[k]
			row.add_child(t)
			t.focus_entered.connect(show_tile.bind(t))
			if above.is_empty() and top_neighbor != null:
				t.focus_neighbor_top = t.get_path_to(top_neighbor)
			elif not above.is_empty():
				t.focus_neighbor_top = t.get_path_to(above[mini(k, above.size() - 1)])
			if k == 0:
				t.focus_neighbor_left = t.get_path_to(t)
			if k == here.size() - 1:
				t.focus_neighbor_right = t.get_path_to(t)
			tiles.append(t)
		for k in above.size():
			above[k].focus_neighbor_bottom = above[k].get_path_to(here[mini(k, here.size() - 1)])
		above = here
	if not tiles.is_empty():
		show_tile(tiles[0])


func focus_first() -> void:
	if not tiles.is_empty():
		tiles[0].grab_focus()


## The tile of collectible `id` (null when there is none).
func tile(id: StringName) -> ArchiveTile:
	for t in tiles:
		if t.def.id == id:
			return t
	return null


## The detail beside the shelves shows `t`'s collectible: found, its name, shelf and lore; else "?" and the shelf.
func show_tile(t: ArchiveTile) -> void:
	_shown = t
	var shelf := tr(CollectibleBook.SHELF_KEYS.get(t.def.shelf, &"COLLECTIBLE_SHELF_STONE"))
	shelf_label.text = shelf
	if t.found:
		name_label.text = tr(t.def.name_key)
		lore_label.text = tr(t.def.lore_key)
	else:
		name_label.text = "?"
		lore_label.text = ""  # P4: the shelf's name only, no hint


## The collectible the detail shows (null before any).
func shown() -> ArchiveTile:
	return _shown
