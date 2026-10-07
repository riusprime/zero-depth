class_name InputDefaults
extends RefCounted
## The default bindings, in one table that the remap store and the tests share (PLAN v0.0.1 Step 1).
## Keys bind by physical keycode, so WASD stays WASD on AZERTY. Pad bindings are starting values.

const ACTIONS := {
	&"move_up": [[&"key", KEY_W], [&"axis", JOY_AXIS_LEFT_Y, -1.0]],
	&"move_down": [[&"key", KEY_S], [&"axis", JOY_AXIS_LEFT_Y, 1.0]],
	&"move_left": [[&"key", KEY_A], [&"axis", JOY_AXIS_LEFT_X, -1.0]],
	&"move_right": [[&"key", KEY_D], [&"axis", JOY_AXIS_LEFT_X, 1.0]],
	&"aim_up": [[&"axis", JOY_AXIS_RIGHT_Y, -1.0]],
	&"aim_down": [[&"axis", JOY_AXIS_RIGHT_Y, 1.0]],
	&"aim_left": [[&"axis", JOY_AXIS_RIGHT_X, -1.0]],
	&"aim_right": [[&"axis", JOY_AXIS_RIGHT_X, 1.0]],
	# Owner, 2026-10-07: the triggers attack, the bumpers dash and use the utility; melee and shooting
	# have separate buttons. The keyboard side (Shift for the utility) is the lead's pick, remappable.
	&"primary": [[&"mouse", MOUSE_BUTTON_LEFT], [&"axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
	&"shoot": [[&"mouse", MOUSE_BUTTON_RIGHT], [&"axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	&"utility": [[&"key", KEY_SHIFT], [&"button", JOY_BUTTON_LEFT_SHOULDER]],
	&"dash": [[&"key", KEY_SPACE], [&"button", JOY_BUTTON_RIGHT_SHOULDER]],
	&"interact": [[&"key", KEY_E], [&"button", JOY_BUTTON_X]],
	&"pause": [[&"key", KEY_ESCAPE], [&"button", JOY_BUTTON_START]],
}
## Action -> InputFrame bit, for the latch.
const BUTTON_BITS := {
	&"primary": InputFrame.PRIMARY,
	&"shoot": InputFrame.SHOOT,
	&"utility": InputFrame.UTILITY,
	&"dash": InputFrame.DASH,
	&"interact": InputFrame.INTERACT,
}
const DEADZONE := 0.2


## Registers every action with its default events (replacing any existing events).
static func apply() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, DEADZONE)
		for spec: Array in ACTIONS[action]:
			InputMap.action_add_event(action, make_event(spec))


static func make_event(spec: Array) -> InputEvent:
	match spec[0]:
		&"key":
			var k := InputEventKey.new()
			k.physical_keycode = spec[1]
			return k
		&"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = spec[1]
			return m
		&"button":
			var b := InputEventJoypadButton.new()
			b.button_index = spec[1]
			return b
		_:
			var a := InputEventJoypadMotion.new()
			a.axis = spec[1]
			a.axis_value = spec[2]
			return a
