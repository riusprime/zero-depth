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
	_wave.text = tr("HUD_WAVE") % [maxi(reader.wave_number(), 1), reader.wave_count()]
	_left.text = tr("HUD_ENEMIES") % reader.enemies_alive()


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
