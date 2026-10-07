class_name OptionCycler
extends Button
## A choice that works the same on every device (v0.3.0 O): it shows "‹ value ›"; left / right (arrows, d-pad, stick)
## step through the values, and pressing it (click, Enter, pad A) steps forward. No popup to get lost in on a pad.

signal changed(value: String)

var values: Array = []
var index := 0
## Translation key per value (same order as values).
var label_keys: Array = []


func _init(p_values: Array, p_label_keys: Array, current: String) -> void:
	values = p_values
	label_keys = p_label_keys
	index = maxi(0, values.find(current))
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	custom_minimum_size = Vector2(0, 44)
	pressed.connect(func() -> void: step(1))
	_show()


func value() -> String:
	return String(values[index])


func step(by: int) -> void:
	index = posmod(index + by, values.size())
	_show()
	changed.emit(value())


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		step(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		step(1)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_show()


func _show() -> void:
	text = "‹  %s  ›" % tr(label_keys[index])
