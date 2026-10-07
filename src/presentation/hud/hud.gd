class_name Hud
extends Control
## The fight's HUD (PLAN v0.1.0 Step 5): health, dash and utility readiness (bottom left), wave and enemies left
## (top centre). It never takes mouse input, so clicks reach the game.

const BAR := Vector2(320, 22)

var _hp_fill := ColorRect.new()
var _hp_text := Label.new()
var _dash := _pip("HUD_DASH")
var _util := _pip("HUD_UTILITY")
var _wave := Label.new()
var _left := Label.new()
## Floor (PLAN v0.2.0 F): the items you carry, a toast when you pick one up, the sealed-gate note.
var _items := VBoxContainer.new()
var _toast := Label.new()
var _gate := Label.new()
var _toast_left := 0.0
var _last_seq := 0
var _items_shown := -1


func _init() -> void:
	name = "Hud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corner := VBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.position = Vector2(28, -150)
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(corner)
	_hp_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	corner.add_child(_hp_text)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.custom_minimum_size = BAR
	corner.add_child(back)
	_hp_fill.color = ThemePalette.color(&"player_bar")
	_hp_fill.size = BAR
	back.add_child(_hp_fill)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 18)
	pips.add_child(_dash)
	pips.add_child(_util)
	corner.add_child(pips)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-160, 18)
	top.custom_minimum_size = Vector2(320, 0)
	add_child(top)
	for l: Label in [_wave, _left]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		top.add_child(l)
	_wave.add_theme_font_size_override("font_size", 28)
	_items.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_items.position = Vector2(-260, -220)
	_items.custom_minimum_size = Vector2(240, 0)
	add_child(_items)
	for l: Label in [_toast, _gate]:
		l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(900, 0)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_font_size_override("font_size", 24)
		add_child(l)
	_toast.position = Vector2(-450, -190)
	_gate.position = Vector2(-450, -150)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(reader: WorldReader) -> void:
	var hp := reader.player_hp()
	var mx := maxi(1, reader.player_max_hp())
	_hp_fill.size = Vector2(BAR.x * clampf(float(hp) / mx, 0.0, 1.0), BAR.y)
	_hp_text.text = tr("HUD_HP") % [hp, mx]
	_set_pip(_dash, reader.dash_cooldown(), reader.dash_cooldown_total())
	if reader.has_blink():
		(_util.get_child(1) as Label).text = tr("UTIL_BLINK")
		_set_pip(_util, reader.blink_cooldown(), reader.blink_cooldown_total())
	elif reader.has_guard():
		(_util.get_child(1) as Label).text = tr("UTIL_GUARD")
		_set_pip(_util, 0, 1, reader.guarding())
	_util.visible = reader.has_blink() or reader.has_guard()
	if reader.has_floor():
		var secs := int(reader.run_seconds())
		_wave.text = tr("HUD_TIME_TIER") % [secs / 60, secs % 60, reader.tier() + 1]
		_left.text = tr("HUD_KILLS") % reader.kills()
		_sync_items(reader)
	else:
		_wave.text = tr("HUD_WAVE") % [maxi(reader.wave_number(), 1), reader.wave_count()]
		_left.text = tr("HUD_ENEMIES") % reader.enemies_alive()
	_gate.text = tr("GATE_SEALED") if reader.has_floor() and reader.at_gate() else ""


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""


func toast_text() -> String:
	return _toast.text


func _sync_items(reader: WorldReader) -> void:
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.PICKUP:
			var idx := e.amount
			_toast.text = (
				tr("HUD_PICKED")
				% [tr(reader.item_name_key(idx)), tr(String(reader.item_name_key(idx)) + "_DESC")]
			)
			_toast_left = 4.0
	var owned := reader.items_owned()
	if owned.size() == _items_shown:
		return
	_items_shown = owned.size()
	for c in _items.get_children():
		c.queue_free()
	for idx in owned:
		var l := Label.new()
		l.text = String(reader.item_name_key(idx))
		l.add_theme_color_override("font_color", ItemLooks.color(reader.item_kind(idx)))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_items.add_child(l)


## A small square that fills as the cooldown runs out, with a label.
func _pip(key: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	var sq := ColorRect.new()
	sq.custom_minimum_size = Vector2(22, 22)
	sq.color = Color(0, 0, 0, 0.55)
	var fill := ColorRect.new()
	fill.color = ThemePalette.color(&"player_core")
	fill.size = Vector2(22, 22)
	sq.add_child(fill)
	box.add_child(sq)
	var l := Label.new()
	l.text = key
	box.add_child(l)
	return box


func _set_pip(pip: HBoxContainer, left: int, total: int, active: bool = false) -> void:
	var fill: ColorRect = pip.get_child(0).get_child(0)
	var ready := 1.0 - clampf(float(left) / maxf(1.0, total), 0.0, 1.0)
	fill.size = Vector2(22, 22 * ready)
	fill.position = Vector2(0, 22 * (1.0 - ready))
	fill.color = ThemePalette.color(&"player_core").lightened(0.4 if active else 0.0)
