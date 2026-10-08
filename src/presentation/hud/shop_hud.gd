class_name ShopHud
extends Control
## The shop on the HUD (v0.5.0 SH): the interact prompt by the terminal, and the shop panel (ShopPanel) while the
## shop is open. Reads only; the panel's choices go out as input.

var panel := ShopPanel.new()
var _prompt := Label.new()


func _init() -> void:
	name = "Shop"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.name = "ShopPrompt"
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
	add_child(panel)


func sync(reader: WorldReader) -> void:
	var near := (
		reader.has_shop()
		and reader.shop_in_reach()
		and not reader.shop_open()
		and not reader.choosing()
	)
	_prompt.visible = near and reader.reward_in_reach() < 0
	if _prompt.visible:
		_prompt.text = tr("SHOP_PROMPT")
	panel.sync(reader)


## The prompt by the terminal ("" when none).
func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""
