class_name FinalApproachHud
extends Control
## v0.9.0 FA (owner Q18: "Press once"): the interact prompt by an unlit rune pylon on the final approach, as the boss
## door's (BossDoorHud). Short, no explanation (the owner's style): "[E / X] Awaken". Reads only
## (WorldReader.approach_pylon_in_reach); the press goes out as input.

var _prompt := Label.new()


func _init() -> void:
	name = "FinalApproach"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.name = "PylonPrompt"
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size = Vector2(900, 0)
	_prompt.position = Vector2(-450, -112)
	_prompt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudStyle.style_label(_prompt, 22, true)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.visible = false
	add_child(_prompt)


func sync(reader: WorldReader) -> void:
	_prompt.visible = reader.approach_pylon_in_reach() >= 0 and not reader.choosing()
	if _prompt.visible:
		_prompt.text = tr("APPROACH_PYLON_PROMPT")


## The prompt by a pylon ("" when none).
func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""
