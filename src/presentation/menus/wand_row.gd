class_name WandRow
extends Control
## The wand as a row of slots (v0.6.5 WN2; docs/design/WAND.md rule 4), shared by the pause menu's Build page and the
## Swap panel. Each held card is a Cold-glass tile (MenuStyle) with its card family's frame colour along the top
## (CardFrames), its icon (ItemIcons), its name and its level; an empty slot is a dim tile. A trigger card cuts the
## row: a cold-glass divider stands after it, and under the row a bracket per part of the wand says what it is ("the
## shot you fire", then "cast on hit →" under the cards the trigger casts). It draws a wand read (WorldReader.wand(),
## or a preview from WorldReader.wand_moved) and the page's marks (focus, the card held, a card leaving, a new card);
## it decides nothing (EI-07).
## Mouse: a press on a tile and a release on another is a drag (`tile_dropped`); a press and release on the same tile
## is a click (`tile_clicked`); hovering a tile reports it (`tile_hovered`). The pages turn those into moves.

signal tile_clicked(k: int)
signal tile_dropped(from: int, to: int)
signal tile_hovered(k: int)

## A tile's size, the gap between tiles, the extra room a cut takes (its divider), and the bracket band under the row
## (px at the 1920 x 1080 base; 8 slots and 3 cuts: about 1,300 px).
const TILE := Vector2(140, 150)
const GAP := 10.0
const CUT := 34.0
const LIFT := 14.0
const BRACKET_H := 52.0
const NAME_SIZE := 15
const SMALL_SIZE := 13
const BRACKET_SIZE := 14
## A press that moves this far (px) before its release is a drag.
const DRAG_PX := 8.0
## The bracket label of a part cast by each trigger (WorldReader.WAND_ON_*), and of the shot you fire.
const CUT_KEYS := {
	WorldReader.WAND_ON_HIT: "UI_WAND_CUT_ON_HIT",
	WorldReader.WAND_ON_KILL: "UI_WAND_CUT_ON_KILL",
	WorldReader.WAND_ON_END: "UI_WAND_CUT_ON_END",
	WorldReader.WAND_ON_FINISHER: "UI_WAND_CUT_ON_FINISHER",
	WorldReader.WAND_ON_CRIT: "UI_WAND_CUT_ON_CRIT",
}
## The compile's nesting depth (a third trigger casts nothing; WAND.md rule 3).
const MAX_DEPTH := 2

## The marks the page sets (slot indices, -1 for none): the focused tile, the card held (lifted), a card that leaves
## (the Swap's replace), and the new card (the Swap's incoming card placed in the row).
var focus := -1
var held := -1
var leaving := -1
var fresh := -1

var _wand := {}
var _slots := 0
var _tiles: Array[PanelContainer] = []
var _icons: Array[ItemIconView] = []
var _keys: Array[Label] = []
var _names: Array[Label] = []
var _levels: Array[Label] = []
var _brackets: Array[Label] = []
## Each tile's x (left edge) and the dividers' x, from the last layout.
var _xs: Array[float] = []
var _cut_xs: Array[float] = []
## [from_x, to_x, depth] per bracket, for _draw.
var _spans: Array = []
var _press := -1
var _press_at := Vector2.ZERO
var _dragging := false


func _init() -> void:
	name = "WandRow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in WorldReader.MOD_SLOTS + 1:  # one more than the wand holds: the Swap's new card placed in a full row
		_make_tile(k)
	for k in WorldReader.MOD_SLOTS + 2:
		var b := make_label(BRACKET_SIZE, false, MenuStyle.DIM)
		b.name = "Bracket%d" % k
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.max_lines_visible = 2
		add_child(b)
		_brackets.append(b)
	for k in _tiles.size():  # every tile wears the glass look from the start
		_style(k)


func _make_tile(k: int) -> void:
	var t := PanelContainer.new()
	t.name = "WandSlot%d" % (k + 1)
	t.custom_minimum_size = TILE
	t.size = TILE
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.clip_contents = true
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(box)
	var key := make_label(SMALL_SIZE, false, MenuStyle.DIM)
	key.text = str(k + 1)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(key)
	var icon := ItemIconView.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var nm := make_label(NAME_SIZE, true, MenuStyle.TEXT)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	nm.custom_minimum_size = Vector2(TILE.x - 16, 0)
	box.add_child(nm)
	var lv := make_label(SMALL_SIZE, false, MenuStyle.DIM)
	box.add_child(lv)
	t.gui_input.connect(_on_tile_input.bind(k))
	t.mouse_entered.connect(func() -> void: tile_hovered.emit(k))
	add_child(t)
	_tiles.append(t)
	_icons.append(icon)
	_keys.append(key)
	_names.append(nm)
	_levels.append(lv)


static func make_label(px: int, bold: bool, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", HudStyle.font(bold))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Shows `wand` (a wand read: its cards in slot order with their triggers) over `slots` slots (at least the cards).
func show_wand(wand: Dictionary, slots: int) -> void:
	_wand = wand
	_slots = clampi(maxi(slots, card_count()), 0, _tiles.size())
	_refresh()


func card_count() -> int:
	return (_wand.get("cards", []) as Array).size()


func slot_count() -> int:
	return _slots


func wand() -> Dictionary:
	return _wand


## The tile of slot k (tests and the pages' mouse checks).
func tile(k: int) -> PanelContainer:
	return _tiles[k]


func card_name(k: int) -> String:
	return _names[k].text


func level_text(k: int) -> String:
	return _levels[k].text


## The bracket labels shown, left to right (tests).
func bracket_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _brackets:
		if b.visible:
			out.append(b.text)
	return out


## The dividers' x (tests: one after each trigger card).
func cut_positions() -> Array[float]:
	return _cut_xs.duplicate()


## The row's width now (tests: it fits the screen at 8 slots).
func row_width() -> float:
	return custom_minimum_size.x


## Restyles the marks only (focus, held, leaving, new) after the page changes them.
func refresh_marks() -> void:
	for k in _slots:
		_style(k)
		_tiles[k].position.y = 0.0 if k == held else LIFT  # the held card is lifted


func _refresh() -> void:
	var cards: Array = _wand.get("cards", [])
	var x := 0.0
	_xs.clear()
	_cut_xs.clear()
	_spans.clear()
	var seg_from := 0.0
	var depth := 0
	var seg_keys: Array[String] = ["UI_WAND_CUT_FIRE"]
	for k in _tiles.size():
		var t := _tiles[k]
		t.visible = k < _slots
		if k >= _slots:
			continue
		_xs.append(x)
		t.position = Vector2(x, LIFT)
		if k < cards.size():
			var c: Dictionary = cards[k]
			var id: StringName = c["id"]
			_names[k].text = tr(c["name_key"])
			var ability := int(c["type"]) == WorldReader.CARD_ABILITY
			_levels[k].text = tr("UI_WAND_LEVEL") % int(c["level"]) if ability else ""
			if k == fresh:
				_levels[k].text = tr("UI_WAND_NEW")
			var col := AbilityIcons.color(id) if ability else ItemLooks.color_of_id(id)
			_icons[k].set_item(id, col)
			_icons[k].visible = true
			var tint := CardFrames.tint(CardFrames.frame_of(CardFrames.family(id, int(c["type"]))))
			t.set_meta(&"tint", tint)
			t.set_meta(&"empty", false)
		else:
			_names[k].text = tr("UI_WAND_EMPTY")
			_levels[k].text = ""
			_icons[k].visible = false
			t.set_meta(&"tint", Color(MenuStyle.DIM, 0.3))
			t.set_meta(&"empty", true)
		x += TILE.x
		var trig := int(cards[k]["trigger"]) if k < cards.size() else -1
		if trig >= 0 and k < _slots - 1:
			_spans.append([seg_from, x, depth])
			depth += 1
			var key: String = CUT_KEYS.get(trig, "UI_WAND_CUT_ON_HIT")
			seg_keys.append(key if depth <= MAX_DEPTH else "UI_WAND_CUT_UNUSED")
			_cut_xs.append(x + CUT * 0.5)
			x += CUT
			seg_from = x
		elif k < _slots - 1:
			x += GAP
	_spans.append([seg_from, x, depth])
	for b in _brackets.size():
		var l := _brackets[b]
		l.visible = b < _spans.size() and _slots > 0
		if not l.visible:
			continue
		var span: Array = _spans[b]
		var w := maxf(float(span[1]) - float(span[0]), TILE.x)
		l.text = tr(seg_keys[b])
		l.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER if b == 0 else HORIZONTAL_ALIGNMENT_LEFT
		)
		l.position = Vector2(float(span[0]), LIFT + TILE.y + 14.0)
		l.size = Vector2(w, BRACKET_H - 14.0)
		l.add_theme_color_override(
			"font_color", MenuStyle.DIM if b == 0 else Color(MenuStyle.GLASS, 0.9)
		)
	custom_minimum_size = Vector2(maxf(x, 0.0), LIFT + TILE.y + BRACKET_H)
	size = custom_minimum_size
	refresh_marks()
	queue_redraw()


func _style(k: int) -> void:
	var t := _tiles[k]
	var tint: Color = t.get_meta(&"tint", MenuStyle.GLASS)
	var empty: bool = t.get_meta(&"empty", false)
	var box := MenuStyle.glass_panel(Vector2(8, 6))
	box.border_color = Color(tint, 0.9)
	box.border_width_top = 3
	if empty:
		box.bg_color = Color(MenuStyle.PANEL, 0.3)
		box.border_width_top = 1
	if k == focus or k == held:  # the focused or held tile: the glass wash and a cold rim
		box.bg_color = Color(MenuStyle.GLASS, 0.22 if k == held else 0.16)
		box.border_color = MenuStyle.GLASS
		box.set_border_width_all(2 if k == held else 1)
		box.border_width_top = 3
	if k == fresh:  # the incoming card: a warm rim, so it reads as the new one
		box.border_color = CardFrames.tint(&"gold")
		box.set_border_width_all(2)
		box.border_width_top = 3
	t.add_theme_stylebox_override("panel", box)
	t.modulate = Color(1, 1, 1, 0.42) if k == leaving else Color.WHITE


func _draw() -> void:
	var top := LIFT
	var bottom := LIFT + TILE.y
	for cx in _cut_xs:  # a trigger cuts the row: a cold-glass divider with a small arrow head
		draw_line(
			Vector2(cx, top - 6.0), Vector2(cx, bottom + 6.0), Color(MenuStyle.GLASS, 0.85), 2.0
		)
		var mid := (top + bottom) * 0.5
		var head := PackedVector2Array(
			[Vector2(cx + 9, mid), Vector2(cx - 3, mid - 8), Vector2(cx - 3, mid + 8)]
		)
		draw_colored_polygon(head, Color(MenuStyle.GLASS, 0.85))
	for span: Array in _spans:  # the brackets under each part of the wand
		var a := float(span[0]) + 4.0
		var b := float(span[1]) - 4.0
		if b <= a:
			continue
		var y := bottom + 8.0
		var c := MenuStyle.DIM if int(span[2]) == 0 else Color(MenuStyle.GLASS, 0.7)
		draw_line(Vector2(a, y - 5.0), Vector2(a, y), c, 1.0)
		draw_line(Vector2(a, y), Vector2(b, y), c, 1.0)
		draw_line(Vector2(b, y - 5.0), Vector2(b, y), c, 1.0)


## The slot under `global` (a point on screen), or -1.
func slot_at(global: Vector2) -> int:
	for k in _slots:
		if _tiles[k].get_global_rect().has_point(global):
			return k
	return -1


func _on_tile_input(event: InputEvent, k: int) -> void:
	var t := _tiles[k]
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = t.get_global_rect().position + event.position
		if event.pressed:
			_press = k
			_press_at = at
			_dragging = false
		elif _press >= 0:
			var from := _press
			_press = -1
			var to := slot_at(at)
			if _dragging and to >= 0 and to != from:
				tile_dropped.emit(from, to)
			elif to == from or not _dragging:
				tile_clicked.emit(from)
			_dragging = false
		t.accept_event()
	elif event is InputEventMouseMotion and _press >= 0:
		var at: Vector2 = t.get_global_rect().position + event.position
		if at.distance_to(_press_at) > DRAG_PX:
			_dragging = true
		var over := slot_at(at)
		if over >= 0:
			tile_hovered.emit(over)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _wand.is_empty():
		_refresh()
