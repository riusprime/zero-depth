class_name BossDoorHud
extends Control
## v0.8.0 BD (owner O83: "opening the door now is a press button"): the interact prompt by the shut boss door, as the
## shop's by its terminal (ShopHud). Reads only (WorldReader.boss_door_in_reach); the press goes out as input.

var _prompt := Label.new()


func _init() -> void:
	name = "BossDoor"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.name = "BossDoorPrompt"
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
	_prompt.visible = (
		reader.boss_door_in_reach() and not reader.choosing() and reader.reward_in_reach() < 0
	)
	if _prompt.visible:
		_prompt.text = tr("BOSS_DOOR_PROMPT")


## The prompt by the door ("" when none).
func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""
