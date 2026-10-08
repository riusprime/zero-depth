class_name EventHud
extends Control
## Event rooms and curses on the HUD (v0.5.0 EV): the interact prompt by a ready pedestal, the status line while an
## Ambush Cache fight or a Wandering Drone defence runs, the event panel (EventPanel), and threat T with the curses
## held (ThreatPanel, top left, while T > 0). Reads only; only the panel's cards take the mouse.

var panel := EventPanel.new()
var threat := ThreatPanel.new()
var _prompt := Label.new()
var _status := HudStyle.label(20, true)


func _init() -> void:
	name = "Events"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.name = "EventPrompt"
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size = Vector2(900, 0)
	_prompt.position = Vector2(-450, -112)
	HudStyle.style_label(_prompt, 22, true)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.name = "EventStatus"
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(700, 0)
	_status.position = Vector2(-350, 112)
	_status.add_theme_constant_override("outline_size", 6)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	for l: Label in [_prompt, _status]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.visible = false
		add_child(l)
	threat.place_top_left(20)
	threat.visible = false
	add_child(threat)
	add_child(panel)


func sync(reader: WorldReader) -> void:
	var k := reader.event_in_reach() if not reader.event_open() else -1
	_prompt.visible = k >= 0
	if k >= 0:
		_prompt.text = tr("UI_EVENT_OPEN") % tr(reader.event_name_key(k))
		_prompt.add_theme_color_override(
			"font_color", EventPedestalViews.GLOW.lerp(Color.WHITE, 0.6)
		)
	_sync_status(reader)
	threat.visible = reader.threat() > 0 or not reader.curses_owned().is_empty()
	threat.sync(reader)
	panel.sync(reader)


func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""


func status_text() -> String:
	return _status.text if _status.visible else ""


func _sync_status(reader: WorldReader) -> void:
	_status.visible = false
	if reader.event_ambush() >= 0:
		_status.visible = true
		_status.text = tr("UI_EVENT_AMBUSH") % reader.event_ambush_left()
		_status.add_theme_color_override("font_color", EventPedestalViews.FIGHT)
	elif reader.event_defend() >= 0:
		var k := reader.event_defend()
		var away := (
			reader.player_pos().distance_to(reader.event_pos(k)) > reader.event_defend_radius_m()
		)
		_status.visible = true
		_status.text = (
			tr("UI_EVENT_DEFEND_AWAY")
			if away
			else tr("UI_EVENT_DEFEND") % int(reader.event_defend_progress() * 100.0)
		)
		_status.add_theme_color_override(
			"font_color", HudStyle.WARN if away else EventPedestalViews.GUARD
		)
