class_name InteractPromptHud
extends Control
## v0.9.0 IX (owner W34, W13 §13): the one shared prompt for the shared interactables (the final approach's rune
## pylons, the timed doors' switches, the puzzles to come), as the boss door's (BossDoorHud). It shows the prompt key
## of the entry the interact press would reach now (WorldReader.interact_prompt_key: the sim's own pick, so the prompt
## never names what the press won't do). Short, no explanation (the owner's style): "Awaken", "Activate". Reads only;
## the press goes out as input. (v0.9.0 FA's FinalApproachHud, generalised.)

var _prompt := Label.new()


func _init() -> void:
	name = "InteractPrompt"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.name = "Prompt"
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
	var key := reader.interact_prompt_key()
	_prompt.visible = key != &""
	if _prompt.visible:
		_prompt.text = tr(key)


## The prompt shown now ("" when none).
func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""
