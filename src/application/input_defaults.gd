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
	# v0.6.0 (owner, 2026-10-09): the Blade swings on the right trigger too ("it should be right trigger by
	# default"); a Blade run never shoots and a Gun run never swings, so both share it.
	&"primary": [[&"mouse", MOUSE_BUTTON_LEFT], [&"axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	&"shoot": [[&"mouse", MOUSE_BUTTON_RIGHT], [&"axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	&"utility": [[&"key", KEY_SHIFT], [&"button", JOY_BUTTON_LEFT_SHOULDER]],
	&"dash": [[&"key", KEY_SPACE], [&"button", JOY_BUTTON_RIGHT_SHOULDER]],
	&"interact": [[&"key", KEY_E], [&"button", JOY_BUTTON_X]],
	&"pause": [[&"key", KEY_ESCAPE], [&"button", JOY_BUTTON_START]],
	# v0.3.0 MM: hold to show the full map (owner L30).
	&"map": [[&"key", KEY_TAB], [&"button", JOY_BUTTON_BACK]],
	# v0.3.5 K (owner F1, F18): Vent and the build's Skill, each on its own button.
	&"vent": [[&"key", KEY_F], [&"button", JOY_BUTTON_B]],
	&"skill": [[&"key", KEY_Q], [&"button", JOY_BUTTON_Y]],
}
## Action -> InputFrame bit, for the latch.
const BUTTON_BITS := {
	&"primary": InputFrame.PRIMARY,
	&"shoot": InputFrame.SHOOT,
	&"utility": InputFrame.UTILITY,
	&"dash": InputFrame.DASH,
	&"interact": InputFrame.INTERACT,
	&"vent": InputFrame.VENT,
	&"skill": InputFrame.SKILL,
}
const DEADZONE := 0.2
## Pad buttons added to Godot's built-in UI actions (v0.2.0 PLAN L3). Godot 4.7's default `ui_accept` holds only
## Enter, Kp Enter and Space, so pad A (Xbox) / Cross (PS), both JOY_BUTTON_A, pressed nothing in the menus. The
## built-in `ui_up/down/left/right` already hold the d-pad and the left stick, so focus moved but never fired.
const UI_PAD := {
	&"ui_accept": [JOY_BUTTON_A],
}


## Registers every action with its default events (replacing any existing events), and adds the pad buttons to
## the built-in UI actions.
static func apply() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, DEADZONE)
		for spec: Array in ACTIONS[action]:
			InputMap.action_add_event(action, make_event(spec))
	for action: StringName in UI_PAD:
		for button: int in UI_PAD[action]:
			var ev := make_event([&"button", button])
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)


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
