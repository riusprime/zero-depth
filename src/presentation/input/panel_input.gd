class_name PanelInput
extends RefCounted
## One modal panel input event, decoded (audit P-4): the pick, event, shop and swap panels and the Build page read
## their keys, pad buttons and stick the same way, so they decode them here and only match the result.
## - Keys: 1..`digits` jump (DIGIT), Enter confirms, Esc cancels, the arrows step; any other key is KEY (its code).
## - Pad: A confirms, B cancels, the d-pad steps; any other button is BUTTON (its index).
## - Left stick: ui_left / ui_right / ui_up / ui_down step.
## Each panel keeps its own key-repeat (echo) policy (Echo), so nothing shifts from what it did before.

## What a held key's OS repeats (echoes) do on a panel:
## - ACT: they act like presses (the pick panel: its sent latch stops a second answer);
## - IGNORE: they are not the panel's (the event panel);
## - ARROWS: only the arrows repeat; any other echo is swallowed (the swap panel and the shop, P-12);
## - CONFIRM_ONCE: Enter and Esc don't repeat (swallowed); the rest acts (the Build page).
enum Echo { ACT, IGNORE, ARROWS, CONFIRM_ONCE }
## NONE: not the panel's (leave it unhandled); SWALLOW: the panel's, and nothing happens.
enum Kind { NONE, SWALLOW, DIGIT, CONFIRM, CANCEL, STEP, KEY, BUTTON }

const ARROW_KEYS: Array[Key] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]

var kind := Kind.NONE
## STEP: left (-1, 0), right (1, 0), up (0, -1), down (0, 1).
var step := Vector2i.ZERO
## DIGIT: 0 for key 1.
var digit := -1
## KEY: the physical keycode; BUTTON: the pad button.
var code := 0


## The step along a single row (left and up back, right and down on).
func line() -> int:
	return step.x + step.y


static func decode(event: InputEvent, digits: int, echo: Echo) -> PanelInput:
	var out := PanelInput.new()
	if event is InputEventKey and event.pressed:
		var key: Key = event.physical_keycode
		if event.echo:
			match echo:
				Echo.IGNORE:
					return out
				Echo.ARROWS:
					if key not in ARROW_KEYS:
						out.kind = Kind.SWALLOW
						return out
				Echo.CONFIRM_ONCE:
					if key in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
						out.kind = Kind.SWALLOW
						return out
		if key >= KEY_1 and key < KEY_1 + digits:
			out.kind = Kind.DIGIT
			out.digit = key - KEY_1
		else:
			match key:
				KEY_ENTER, KEY_KP_ENTER:
					out.kind = Kind.CONFIRM
				KEY_ESCAPE:
					out.kind = Kind.CANCEL
				KEY_LEFT:
					out.step = Vector2i(-1, 0)
				KEY_RIGHT:
					out.step = Vector2i(1, 0)
				KEY_UP:
					out.step = Vector2i(0, -1)
				KEY_DOWN:
					out.step = Vector2i(0, 1)
				_:
					out.kind = Kind.KEY
					out.code = key
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				out.kind = Kind.CONFIRM
			JOY_BUTTON_B:
				out.kind = Kind.CANCEL
			JOY_BUTTON_DPAD_LEFT:
				out.step = Vector2i(-1, 0)
			JOY_BUTTON_DPAD_RIGHT:
				out.step = Vector2i(1, 0)
			JOY_BUTTON_DPAD_UP:
				out.step = Vector2i(0, -1)
			JOY_BUTTON_DPAD_DOWN:
				out.step = Vector2i(0, 1)
			_:
				out.kind = Kind.BUTTON
				out.code = event.button_index
	elif event is InputEventJoypadMotion:
		if event.is_action_pressed(&"ui_left"):
			out.step = Vector2i(-1, 0)
		elif event.is_action_pressed(&"ui_right"):
			out.step = Vector2i(1, 0)
		elif event.is_action_pressed(&"ui_up"):
			out.step = Vector2i(0, -1)
		elif event.is_action_pressed(&"ui_down"):
			out.step = Vector2i(0, 1)
	if out.step != Vector2i.ZERO:
		out.kind = Kind.STEP
	return out
