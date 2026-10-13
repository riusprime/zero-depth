extends GutTest
## Audit P-4: the modal panels' shared input decoding (PanelInput): keys, pad buttons and the stick decode the same
## for every panel, and each panel's key-repeat policy stays its own.


func _key(code: Key, echo := false, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	ev.echo = echo
	return ev


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func _kind(ev: InputEvent, digits := 3, echo := PanelInput.Echo.ACT) -> int:
	return PanelInput.decode(ev, digits, echo).kind


func test_keys_buttons_and_digits() -> void:
	assert_eq(_kind(_key(KEY_ENTER)), PanelInput.Kind.CONFIRM)
	assert_eq(_kind(_key(KEY_KP_ENTER)), PanelInput.Kind.CONFIRM)
	assert_eq(_kind(_key(KEY_ESCAPE)), PanelInput.Kind.CANCEL)
	assert_eq(_kind(_pad(JOY_BUTTON_A)), PanelInput.Kind.CONFIRM)
	assert_eq(_kind(_pad(JOY_BUTTON_B)), PanelInput.Kind.CANCEL)
	var d := PanelInput.decode(_key(KEY_3), 3, PanelInput.Echo.ACT)
	assert_eq([d.kind, d.digit], [PanelInput.Kind.DIGIT, 2], "3 is the third")
	d = PanelInput.decode(_key(KEY_4), 3, PanelInput.Echo.ACT)
	assert_eq([d.kind, d.code], [PanelInput.Kind.KEY, KEY_4], "past the panel's digits: just a key")
	d = PanelInput.decode(_pad(JOY_BUTTON_Y), 3, PanelInput.Echo.ACT)
	assert_eq([d.kind, d.code], [PanelInput.Kind.BUTTON, JOY_BUTTON_Y])
	assert_eq(_kind(_key(KEY_ENTER, false, false)), PanelInput.Kind.NONE, "a release is nothing")
	assert_eq(_kind(InputEventMouseMotion.new()), PanelInput.Kind.NONE)


func test_steps() -> void:
	var cases := {
		KEY_LEFT: Vector2i(-1, 0),
		KEY_RIGHT: Vector2i(1, 0),
		KEY_UP: Vector2i(0, -1),
		KEY_DOWN: Vector2i(0, 1)
	}
	for code: Key in cases:
		var d := PanelInput.decode(_key(code), 3, PanelInput.Echo.ACT)
		assert_eq([d.kind, d.step], [PanelInput.Kind.STEP, cases[code]])
	var pad := PanelInput.decode(_pad(JOY_BUTTON_DPAD_UP), 3, PanelInput.Echo.ACT)
	assert_eq(pad.line(), -1, "up steps back along a row")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	assert_eq(PanelInput.decode(stick, 3, PanelInput.Echo.ACT).step, Vector2i(1, 0), "the stick")


func test_each_echo_policy() -> void:
	var enter := _key(KEY_ENTER, true)
	var left := _key(KEY_LEFT, true)
	var one := _key(KEY_1, true)
	assert_eq(_kind(enter, 3, PanelInput.Echo.ACT), PanelInput.Kind.CONFIRM, "pick: repeats act")
	assert_eq(_kind(enter, 3, PanelInput.Echo.IGNORE), PanelInput.Kind.NONE, "event: not its")
	assert_eq(_kind(left, 3, PanelInput.Echo.IGNORE), PanelInput.Kind.NONE)
	assert_eq(_kind(enter, 3, PanelInput.Echo.ARROWS), PanelInput.Kind.SWALLOW, "swap, shop")
	assert_eq(_kind(left, 3, PanelInput.Echo.ARROWS), PanelInput.Kind.STEP, "the arrows repeat")
	assert_eq(_kind(enter, 8, PanelInput.Echo.CONFIRM_ONCE), PanelInput.Kind.SWALLOW, "Build page")
	assert_eq(
		_kind(one, 8, PanelInput.Echo.CONFIRM_ONCE), PanelInput.Kind.DIGIT, "its digits repeat"
	)
