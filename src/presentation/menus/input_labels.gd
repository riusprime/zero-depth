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
## The HUD's short names (v0.6.0 UP): a 52 px ability slot has no room for "Left click" / "Clic izquierdo", so the
## slot's corner names a mouse or pad binding by these (the Options list keeps the full names above).
const SHORT := {
	"UI_MOUSE_LEFT": "HUD_KEY_MOUSE_LEFT",
	"UI_MOUSE_RIGHT": "HUD_KEY_MOUSE_RIGHT",
	"UI_MOUSE_MIDDLE": "HUD_KEY_MOUSE_MIDDLE",
	"UI_MOUSE_WHEEL_UP": "HUD_KEY_MOUSE_WHEEL_UP",
	"UI_MOUSE_WHEEL_DOWN": "HUD_KEY_MOUSE_WHEEL_DOWN",
	"UI_MOUSE_BACK": "HUD_KEY_MOUSE_BACK",
	"UI_MOUSE_FORWARD": "HUD_KEY_MOUSE_FORWARD",
	"UI_MOUSE_OTHER": "HUD_KEY_MOUSE_OTHER",
	"UI_PAD_A": "HUD_KEY_PAD_A",
	"UI_PAD_B": "HUD_KEY_PAD_B",
	"UI_PAD_X": "HUD_KEY_PAD_X",
	"UI_PAD_Y": "HUD_KEY_PAD_Y",
	"UI_PAD_BACK": "HUD_KEY_PAD_BACK",
	"UI_PAD_START": "HUD_KEY_PAD_START",
	"UI_PAD_L3": "HUD_KEY_PAD_L3",
	"UI_PAD_R3": "HUD_KEY_PAD_R3",
	"UI_PAD_LB": "HUD_KEY_PAD_LB",
	"UI_PAD_RB": "HUD_KEY_PAD_RB",
	"UI_PAD_LT": "HUD_KEY_PAD_LT",
	"UI_PAD_RT": "HUD_KEY_PAD_RT",
	"UI_PAD_DPAD_UP": "HUD_KEY_PAD_DPAD_UP",
	"UI_PAD_DPAD_DOWN": "HUD_KEY_PAD_DPAD_DOWN",
	"UI_PAD_DPAD_LEFT": "HUD_KEY_PAD_DPAD_LEFT",
	"UI_PAD_DPAD_RIGHT": "HUD_KEY_PAD_DPAD_RIGHT",
	"UI_PAD_LS_UP": "HUD_KEY_PAD_LS_UP",
	"UI_PAD_LS_DOWN": "HUD_KEY_PAD_LS_DOWN",
	"UI_PAD_LS_LEFT": "HUD_KEY_PAD_LS_LEFT",
	"UI_PAD_LS_RIGHT": "HUD_KEY_PAD_LS_RIGHT",
	"UI_PAD_RS_UP": "HUD_KEY_PAD_RS_UP",
	"UI_PAD_RS_DOWN": "HUD_KEY_PAD_RS_DOWN",
	"UI_PAD_RS_LEFT": "HUD_KEY_PAD_RS_LEFT",
	"UI_PAD_RS_RIGHT": "HUD_KEY_PAD_RS_RIGHT",
	"UI_PAD_OTHER": "HUD_KEY_PAD_OTHER",
}
## The HUD's short names for the keys whose engine names are too long for a slot even at its smallest type
## ("Kp Multiply"); symbols and the usual abbreviations, the same in every language.
const SHORT_KEYS := {
	KEY_KP_MULTIPLY: "Kp *",
	KEY_KP_DIVIDE: "Kp /",
	KEY_KP_SUBTRACT: "Kp -",
	KEY_KP_ADD: "Kp +",
	KEY_KP_PERIOD: "Kp .",
	KEY_KP_ENTER: "Kp Ent",
	KEY_PRINT: "PrtSc",
	KEY_SCROLLLOCK: "ScrLk",
	KEY_NUMLOCK: "NumLk",
	KEY_CAPSLOCK: "Caps",
	KEY_BACKSPACE: "Bksp",
	KEY_PAGEUP: "PgUp",
	KEY_PAGEDOWN: "PgDn",
	KEY_INSERT: "Ins",
	KEY_DELETE: "Del",
	KEY_BRACKETLEFT: "[",
	KEY_BRACKETRIGHT: "]",
	KEY_APOSTROPHE: "'",
	KEY_QUOTELEFT: "`",
	KEY_SEMICOLON: ";",
	KEY_BACKSLASH: "\\",
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
	if spec[0] == &"key":
		return TranslationServer.translate(OS.get_keycode_string(int(spec[1])))
	return TranslationServer.translate(name_key(spec))


## The HUD's short name of a spec ("LMB" / "Clic izq.", "RT"), translated; a key keeps the engine's key name.
static func short_text(spec: Array) -> String:
	if spec.is_empty():
		return ""
	if spec[0] == &"key":
		var code := int(spec[1])
		if SHORT_KEYS.has(code):
			return SHORT_KEYS[code]
		return TranslationServer.translate(OS.get_keycode_string(code))
	var k := name_key(spec)
	return TranslationServer.translate(SHORT.get(k, k))


## The translation key naming a mouse, button or axis spec ("" for a key spec, which the engine names).
static func name_key(spec: Array) -> String:
	var code := int(spec[1])
	match spec[0]:
		&"key":
			return ""
		&"mouse":
			return MOUSE.get(code, "UI_MOUSE_OTHER")
		&"button":
			return BUTTONS.get(code, "UI_PAD_OTHER")
		_:
			var pair: Array = AXES.get(code, ["UI_PAD_OTHER", "UI_PAD_OTHER"])
			return pair[1] if float(spec[2]) > 0.0 else pair[0]


static func action_key(action: StringName) -> String:
	return ACTIONS.get(action, String(action))
