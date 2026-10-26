class_name ShopHud
extends Control
## The shop on the HUD (v0.5.0 SH): the interact prompt by the terminal, and the shop panel (ShopPanel) while the
## shop is open. Reads only; the panel's choices go out as input.

var panel := ShopPanel.new()
var _prompt := InteractPrompt.new()


func _init() -> void:
	name = "Shop"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	add_child(panel)


func sync(reader: WorldReader) -> void:
	var near := (
		reader.has_shop()
		and reader.shop_in_reach()
		and not reader.shop_open()
		and not reader.choosing()
	)
	if near and reader.reward_in_reach() < 0:
		_prompt.show_prompt(reader, tr("SHOP_PROMPT"))
	else:
		_prompt.hide_prompt()
	panel.sync(reader)


## The prompt by the terminal ("" when none).
func prompt_text() -> String:
	return _prompt.text()
