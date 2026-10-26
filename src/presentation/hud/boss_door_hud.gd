class_name BossDoorHud
extends Control
## v0.8.0 BD (owner O83: "opening the door now is a press button"): the interact prompt by the shut boss door, as the
## shop's by its terminal (ShopHud). Reads only (WorldReader.boss_door_in_reach); the press goes out as input.

var _prompt := InteractPrompt.new()


func _init() -> void:
	name = "BossDoor"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)


func sync(reader: WorldReader) -> void:
	var near := (
		reader.boss_door_in_reach() and not reader.choosing() and reader.reward_in_reach() < 0
	)
	if near:
		_prompt.show_prompt(reader, tr("BOSS_DOOR_PROMPT"))
	else:
		_prompt.hide_prompt()


## The prompt by the door ("" when none).
func prompt_text() -> String:
	return _prompt.text()
