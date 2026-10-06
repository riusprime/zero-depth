class_name MenuPanel
extends Control
## A centred column of buttons; labels are translation keys (Controls auto-translate their text).

var box := VBoxContainer.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(360, 0)
	center.add_child(box)


func add_title(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 44)
	box.add_child(l)
	return l


func add_button(key: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(on_press)
	box.add_child(b)
	return b


func focus_first() -> void:
	for c in box.get_children():
		if c is Button:
			(c as Button).grab_focus()
			return
