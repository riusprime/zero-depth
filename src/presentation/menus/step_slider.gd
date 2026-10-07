class_name StepSlider
extends HSlider
## A volume slider that left / right (arrows, d-pad, stick) always step, instead of moving focus away (v0.3.0 O):
## Godot 4.7's slider let the d-pad's ui_left leave it, so a pad couldn't change a volume.


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left", true):
		value -= step
		accept_event()
	elif event.is_action_pressed(&"ui_right", true):
		value += step
		accept_event()
