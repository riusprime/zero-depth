class_name HubHud
extends Control
## v0.9.0 HB: the hub's HUD, the shared interact prompt's look (InteractPromptHud): the station the hero stands at,
## its name above, the short prompt below ("[E / X] Start a run"), and nothing else (no health, no map: the hub has no
## fight). The key hint for the pause sits small in a corner. Reads only; the press is the hub's (HubSession).

var _name := Label.new()
var _prompt := InteractPrompt.new()
var _hint := Label.new()


func _init() -> void:
	name = "HubHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l: Label in [_name]:
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
	add_child(_prompt)
	_hint.name = "Hint"
	_hint.text = "HUB_HINT"
	_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hint.position = Vector2(28, 22)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudStyle.style_label(_hint, 18, false)
	_hint.modulate = Color(1, 1, 1, 0.7)
	add_child(_hint)


## The station shown: its name and prompt keys (&"" hides both).
func show_station(name_key: StringName, prompt_key: StringName, reader: WorldReader = null) -> void:
	_name.visible = name_key != &""
	if _name.visible:
		_name.text = tr(name_key)
	if prompt_key != &"":
		# The collectible toast names a find, not a press: no button.
		_prompt.show_prompt(
			reader, tr(prompt_key), false, Color.WHITE, prompt_key != CollectibleBook.HEADER_KEY
		)
	else:
		_prompt.hide_prompt()


## The prompt shown now ("" when none).
func prompt_text() -> String:
	return _prompt.text()


func station_name() -> String:
	return _name.text if _name.visible else ""
