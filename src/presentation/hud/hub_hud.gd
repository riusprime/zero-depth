class_name HubHud
extends Control
## v0.9.0 HB: the hub's HUD, the shared interact prompt's look (InteractPromptHud): the station the hero stands at,
## its name above, the short prompt below ("[E / X] Start a run"), and nothing else (no health, no map: the hub has no
## fight). The key hint for the pause sits small in a corner. Reads only; the press is the hub's (HubSession).

var _name := Label.new()
var _prompt := Label.new()
var _hint := Label.new()


func _init() -> void:
	name = "HubHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l: Label in [_name, _prompt]:
		l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(900, 0)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.visible = false
		add_child(l)
	_name.name = "StationName"
	_name.position = Vector2(-450, -158)
	HudStyle.style_label(_name, 28, true)
	_prompt.name = "Prompt"
	_prompt.position = Vector2(-450, -112)
	HudStyle.style_label(_prompt, 22, true)
	_hint.name = "Hint"
	_hint.text = "HUB_HINT"
	_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hint.position = Vector2(28, 22)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudStyle.style_label(_hint, 18, false)
	_hint.modulate = Color(1, 1, 1, 0.7)
	add_child(_hint)


## The station shown: its name and prompt keys (&"" hides both).
func show_station(name_key: StringName, prompt_key: StringName) -> void:
	_name.visible = name_key != &""
	_prompt.visible = prompt_key != &""
	if _name.visible:
		_name.text = tr(name_key)
	if _prompt.visible:
		_prompt.text = tr(prompt_key)


## The prompt shown now ("" when none).
func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""


func station_name() -> String:
	return _name.text if _name.visible else ""
