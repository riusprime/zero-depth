class_name ThreatPanel
extends PanelContainer
## Threat T and the curses held (v0.5.0 EV, PLAN R4; PD-05): "THREAT 2" over one line per curse (its mark, name and
## sentence). The HUD shows it at the top left while you hold a curse; the pause menu shows it too. A curse just
## taken or lifted flashes a caption under the title for a moment. Reads only.

const FLASH_S := 3.0

var _title := HudStyle.label(18, true)
var _note := HudStyle.label(14)
var _rows := VBoxContainer.new()
var _shown := PackedInt32Array([-1])
var _curse_tick := -1
var _cleanse_tick := -1
var _note_left := 0.0


func _init() -> void:
	name = "Threat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.03, 0.05, 0.8)
	box.set_corner_radius_all(0)
	box.border_color = Color(CurseLook.COLOR, 0.7)
	box.border_width_top = 2
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 10
	add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 5)
	add_child(col)
	_title.add_theme_color_override("font_color", CurseLook.COLOR.lerp(Color.WHITE, 0.35))
	_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	for l: Label in [_title, _note]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	col.add_child(_note)
	_note.visible = false
	_rows.add_theme_constant_override("separation", 3)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_rows)


## Anchors the panel to the top-left corner, `top` px down.
func place_top_left(top: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 28
	offset_top = top


func sync(reader: WorldReader) -> void:
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
	if now == _shown:
		return
	_shown = now.duplicate()
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
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
