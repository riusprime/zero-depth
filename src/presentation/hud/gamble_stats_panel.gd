class_name GambleStatsPanel
extends PanelContainer
## The stats won at the gamble shrine this run (v0.3.0 L19): one row per stat with its icon, the total it adds and
## its wins / cap. On the HUD it shows while you stand at the shrine; the pause menu shows it too.
## v0.6.0 UP: on the HUD it is an Ember stone slab (HudStyle) with the shrine's colour along its top; inside a menu
## (the pause screen) it takes the menu's Cold glass look (MenuStyle), so the pause screen reads as one style.

const ICON := 28.0
const MARGIN := Vector2(14, 9)

## Whether it wears the menus' Cold glass (set when it is added to a MenuPanel).
var in_menu := false
## The reader last shown (read only), to word the panel again on a language switch.
var _reader: WorldReader
var _rows := VBoxContainer.new()
var _title := Label.new()
var _none := Label.new()
## The state last shown (stacks per stat), so rows are rebuilt only on a change.
var _shown := PackedInt32Array()
## The language the rows were worded in.
var _locale := ""


func _init() -> void:
	name = "GambleStats"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	_title.add_theme_font_size_override("font_size", 16)
	_none.add_theme_font_size_override("font_size", 15)
	_apply_look()
	for l: Label in [_title, _none]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	col.add_child(_none)
	_rows.add_theme_constant_override("separation", 4)
	col.add_child(_rows)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED and get_parent() is MenuPanel and not in_menu:
		in_menu = true
		_apply_look()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _reader != null:
		sync(_reader)  # the pause menu syncs it once: a language switch from its Options words it again


## The panel's box and title colours for where it is: Cold glass in a menu, the HUD's slab otherwise.
func _apply_look() -> void:
	if in_menu:
		add_theme_stylebox_override("panel", MenuStyle.glass_panel(MARGIN))
		_title.add_theme_color_override("font_color", MenuStyle.GLASS)
		_none.add_theme_color_override("font_color", MenuStyle.DIM)
	else:
		add_theme_stylebox_override("panel", HudStyle.side_panel_box(MARGIN, GambleIcons.CORE))
		_title.add_theme_color_override("font_color", GambleIcons.CORE.lerp(Color.WHITE, 0.4))
		_none.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	queue_redraw()


func _draw() -> void:
	if not in_menu:
		HudStyle.draw_side_panel(self, GambleIcons.CORE)


## Anchors the panel to the top-right corner, `top` px down.
func place_top_right(top: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -28
	offset_right = -28
	offset_top = top


func sync(reader: WorldReader) -> void:
	_reader = reader
	_title.text = tr("UI_GAMBLE_STATS")
	_none.text = tr("UI_GAMBLE_STATS_NONE")
	var now := PackedInt32Array()
	for s in reader.gamble_stat_count():
		now.append(reader.gamble_stacks(s))
	if now == _shown and TranslationServer.get_locale() == _locale:  # v0.6.0 UP: worded again on a switch
		return
	_shown = now
	_locale = TranslationServer.get_locale()
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for s in reader.gamble_stat_count():
		if reader.gamble_stacks(s) <= 0:
			continue
		var id := reader.gamble_stat_id(s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(GambleIconView.new(id, ICON))
		var text := Label.new()
		text.text = GambleIcons.line(self, id, reader.gamble_bonus(s))
		text.add_theme_font_size_override("font_size", 17)
		text.add_theme_color_override("font_color", GambleIcons.color(id).lerp(Color.WHITE, 0.45))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var count := Label.new()
		count.text = "%d / %d" % [reader.gamble_stacks(s), reader.gamble_cap(s)]
		count.add_theme_font_size_override("font_size", 14)
		count.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		row.add_child(count)
		for l: Label in [text, count]:
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(row)
	_none.visible = _rows.get_child_count() == 0


## Rows shown (one per stat won), for tests.
func row_count() -> int:
	var n := 0
	for c in _rows.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


## Row k's line ("+12 % melee damage"), for tests.
func row_text(k: int) -> String:
	return (_rows.get_child(k).get_child(1) as Label).text
