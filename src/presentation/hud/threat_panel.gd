class_name ThreatPanel
extends PanelContainer
## Threat T and the curses held (v0.5.0 EV, PLAN R4; PD-05): "THREAT 2" over one line per curse (its mark, name and
## sentence). The HUD shows it at the top left while you hold a curse; the pause menu shows it too. A curse just
## taken or lifted flashes a caption under the title for a moment. Reads only.
## v0.6.0 UP: on the HUD an Ember stone slab (HudStyle) with the curses' colour along its top; inside a menu (the
## pause screen) the menu's Cold glass look (MenuStyle).

const FLASH_S := 3.0
const MARGIN := Vector2(14, 9)
## The widest a curse line runs before it wraps (v0.6.0 UP: a long Spanish line ran under the top plate).
const LINE_W := 560.0

## Whether it wears the menus' Cold glass (set when it is added to a MenuPanel).
var in_menu := false
## The reader last shown (read only), to word the panel again on a language switch.
var _reader: WorldReader
var _title := HudStyle.label(18, true)
var _note := HudStyle.label(14)
var _rows := VBoxContainer.new()
var _shown := PackedInt32Array([-1])
## The language the rows were worded in.
var _locale := ""
var _curse_tick := -1
var _cleanse_tick := -1
var _note_left := 0.0


func _init() -> void:
	name = "Threat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 5)
	add_child(col)
	_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_apply_look()
	for l: Label in [_title, _note]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	col.add_child(_note)
	_note.visible = false
	_rows.add_theme_constant_override("separation", 3)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_rows)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED and get_parent() is MenuPanel and not in_menu:
		in_menu = true
		_apply_look()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _reader != null:
		sync(_reader)  # the pause menu syncs it once: a language switch from its Options words it again


## The panel's box and title colour for where it is: Cold glass in a menu, the HUD's slab otherwise.
func _apply_look() -> void:
	if in_menu:
		add_theme_stylebox_override("panel", MenuStyle.glass_panel(MARGIN))
		_title.add_theme_color_override("font_color", MenuStyle.TEXT)
	else:
		add_theme_stylebox_override("panel", HudStyle.side_panel_box(MARGIN, CurseLook.COLOR))
		_title.add_theme_color_override("font_color", CurseLook.COLOR.lerp(Color.WHITE, 0.35))
	queue_redraw()


func _draw() -> void:
	if not in_menu:
		HudStyle.draw_side_panel(self, CurseLook.COLOR)


## Anchors the panel to the top-left corner, `top` px down.
func place_top_left(top: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 28
	offset_top = top


func sync(reader: WorldReader) -> void:
	_reader = reader
	_title.text = tr("UI_THREAT") % reader.threat()
	if reader.curse_tick() != _curse_tick:
		_curse_tick = reader.curse_tick()
		if _curse_tick >= 0 and _shown != PackedInt32Array([-1]):
			_flash(
				"%s · %s" % [tr("UI_CURSE_GAINED"), tr(reader.curse_name_key(reader.curse_last()))]
			)
	if reader.cleanse_tick() != _cleanse_tick:
		_cleanse_tick = reader.cleanse_tick()
		if _cleanse_tick >= 0 and _shown != PackedInt32Array([-1]):
			_flash(
				(
					"%s · %s"
					% [tr("UI_CURSE_LIFTED"), tr(reader.curse_name_key(reader.cleanse_last()))]
				)
			)
	var now := reader.curses_owned()
	if now == _shown and TranslationServer.get_locale() == _locale:  # v0.6.0 UP: worded again on a switch
		return
	_shown = now.duplicate()
	_locale = TranslationServer.get_locale()
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	if now.is_empty():
		_rows.add_child(_line(tr("UI_THREAT_NONE"), Color(1, 1, 1, 0.55)))
	for c in now:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		var mark := CardMark.new(11.0)
		mark.color = CurseLook.COLOR
		row.add_child(mark)
		row.add_child(
			_line(CurseLook.line(self, reader, c), CurseLook.COLOR.lerp(Color.WHITE, 0.45))
		)
		_rows.add_child(row)


func _process(delta: float) -> void:
	if _note_left > 0.0:
		_note_left = maxf(0.0, _note_left - delta)
		_note.visible = _note_left > 0.0


## Lines shown (one per curse, or the "no curses" line), for tests.
func row_count() -> int:
	var n := 0
	for c in _rows.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


## Line k's text (a curse's line, or the "no curses" line), for tests.
func row_text(k: int) -> String:
	var r := _rows.get_child(k)
	return (r as Label).text if r is Label else (r.get_child(1) as Label).text


## The panel's width once laid out (tests: it stays clear of the top plate).
func panel_width() -> float:
	return get_combined_minimum_size().x


func title_text() -> String:
	return _title.text


func note_text() -> String:
	return _note.text if _note.visible else ""


func _flash(text: String) -> void:
	_note.text = text
	_note.visible = true
	_note_left = FLASH_S


func _line(text: String, c: Color) -> Label:
	var l := HudStyle.label(15)
	l.text = text
	l.add_theme_color_override("font_color", c)
	if l.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > LINE_W:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(LINE_W, 0)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
