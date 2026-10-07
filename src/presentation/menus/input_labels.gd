class_name InputLabels
extends RefCounted
## What a binding (an InputDefaults spec) is called on screen (v0.3.0 O). Keys use the engine's key name; mouse and
## pad inputs are translation keys.

const MOUSE := {
	MOUSE_BUTTON_LEFT: "UI_MOUSE_LEFT",
	MOUSE_BUTTON_RIGHT: "UI_MOUSE_RIGHT",
	MOUSE_BUTTON_MIDDLE: "UI_MOUSE_MIDDLE",
	MOUSE_BUTTON_WHEEL_UP: "UI_MOUSE_WHEEL_UP",
	MOUSE_BUTTON_WHEEL_DOWN: "UI_MOUSE_WHEEL_DOWN",
	MOUSE_BUTTON_XBUTTON1: "UI_MOUSE_BACK",
	MOUSE_BUTTON_XBUTTON2: "UI_MOUSE_FORWARD",
}
const BUTTONS := {
	JOY_BUTTON_A: "UI_PAD_A",
	JOY_BUTTON_B: "UI_PAD_B",
	JOY_BUTTON_X: "UI_PAD_X",
	JOY_BUTTON_Y: "UI_PAD_Y",
	JOY_BUTTON_BACK: "UI_PAD_BACK",
	JOY_BUTTON_START: "UI_PAD_START",
	JOY_BUTTON_LEFT_STICK: "UI_PAD_L3",
	JOY_BUTTON_RIGHT_STICK: "UI_PAD_R3",
	JOY_BUTTON_LEFT_SHOULDER: "UI_PAD_LB",
	JOY_BUTTON_RIGHT_SHOULDER: "UI_PAD_RB",
	JOY_BUTTON_DPAD_UP: "UI_PAD_DPAD_UP",
	JOY_BUTTON_DPAD_DOWN: "UI_PAD_DPAD_DOWN",
	JOY_BUTTON_DPAD_LEFT: "UI_PAD_DPAD_LEFT",
	JOY_BUTTON_DPAD_RIGHT: "UI_PAD_DPAD_RIGHT",
}
## [negative, positive] per axis.
const AXES := {
	JOY_AXIS_LEFT_X: ["UI_PAD_LS_LEFT", "UI_PAD_LS_RIGHT"],
	JOY_AXIS_LEFT_Y: ["UI_PAD_LS_UP", "UI_PAD_LS_DOWN"],
	JOY_AXIS_RIGHT_X: ["UI_PAD_RS_LEFT", "UI_PAD_RS_RIGHT"],
	JOY_AXIS_RIGHT_Y: ["UI_PAD_RS_UP", "UI_PAD_RS_DOWN"],
	JOY_AXIS_TRIGGER_LEFT: ["UI_PAD_LT", "UI_PAD_LT"],
	JOY_AXIS_TRIGGER_RIGHT: ["UI_PAD_RT", "UI_PAD_RT"],
}
## The action names shown in the Controls list.
const ACTIONS := {
	&"move_up": "UI_ACTION_MOVE_UP",
	&"move_down": "UI_ACTION_MOVE_DOWN",
	&"move_left": "UI_ACTION_MOVE_LEFT",
	&"move_right": "UI_ACTION_MOVE_RIGHT",
	&"primary": "UI_ACTION_PRIMARY",
	&"shoot": "UI_ACTION_SHOOT",
	&"dash": "UI_ACTION_DASH",
	&"skill": "UI_ACTION_SKILL",
	&"vent": "UI_ACTION_VENT",
	&"utility": "UI_ACTION_UTILITY",
	&"interact": "UI_ACTION_INTERACT",
	&"pause": "UI_ACTION_PAUSE",
	&"aim_up": "UI_ACTION_AIM_UP",
	&"aim_down": "UI_ACTION_AIM_DOWN",
	&"aim_left": "UI_ACTION_AIM_LEFT",
	&"aim_right": "UI_ACTION_AIM_RIGHT",
}


## The on-screen name of a spec, translated; "" for an empty spec.
static func text(spec: Array) -> String:
	if spec.is_empty():
		return ""
	var code := int(spec[1])
	match spec[0]:
		&"key":
			return TranslationServer.translate(OS.get_keycode_string(code))
		&"mouse":
			return TranslationServer.translate(MOUSE.get(code, "UI_MOUSE_OTHER"))
		&"button":
			return TranslationServer.translate(BUTTONS.get(code, "UI_PAD_OTHER"))
		_:
			var pair: Array = AXES.get(code, ["UI_PAD_OTHER", "UI_PAD_OTHER"])
			return TranslationServer.translate(pair[1] if float(spec[2]) > 0.0 else pair[0])


static func action_key(action: StringName) -> String:
	return ACTIONS.get(action, String(action))
