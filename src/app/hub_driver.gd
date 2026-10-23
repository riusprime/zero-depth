class_name HubDriver
extends SimDriver
## v0.9.0 HB: the hub's SimDriver. The hero walks and dashes with the normal controls; nothing else reaches the sim
## (no attack, skill, vent, utility or interact: the hub has no combat, and its interact is the hub's own, HubSession).

const PASSED := InputFrame.DASH


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dash"):
		latch.note_pressed(PASSED)
	elif event.is_action_released(&"dash"):
		latch.note_released(PASSED)
