extends GutTest
## Rebinding (v0.3.0 O): one keyboard/mouse and one pad binding per action, a taken input swaps, the profile keeps it.


func after_each() -> void:
	InputDefaults.apply()


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func test_the_defaults_read_back_per_device() -> void:
	InputDefaults.apply()
	assert_eq(InputRebind.binding(&"dash", InputRebind.KBM), [&"key", KEY_SPACE])
	assert_eq(InputRebind.binding(&"dash", InputRebind.PAD), [&"button", JOY_BUTTON_RIGHT_SHOULDER])
	assert_eq(
		InputRebind.binding(&"shoot", InputRebind.PAD), [&"axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]
	)
	assert_false(InputRebind.has_slot(&"aim_up", InputRebind.KBM), "the mouse aims")
	assert_true(InputRebind.has_slot(&"aim_up", InputRebind.PAD))


func test_a_free_key_binds_and_the_pad_binding_stays() -> void:
	var p := ProfileStore.new("")
	InputDefaults.apply()
	var swapped := InputRebind.rebind(p, &"dash", InputRebind.spec_of(_key(KEY_J)))
	assert_eq(swapped, &"")
	assert_eq(InputRebind.binding(&"dash", InputRebind.KBM), [&"key", KEY_J])
	assert_eq(InputRebind.binding(&"dash", InputRebind.PAD), [&"button", JOY_BUTTON_RIGHT_SHOULDER])
	assert_true(InputMap.event_is_action(_key(KEY_J), &"dash"), "InputMap has it at once")
	assert_false(InputMap.event_is_action(_key(KEY_SPACE), &"dash"))


func test_a_taken_key_swaps_the_two_actions() -> void:
	var p := ProfileStore.new("")
	InputDefaults.apply()
	var swapped := InputRebind.rebind(p, &"dash", InputRebind.spec_of(_key(KEY_E)))
	assert_eq(swapped, &"interact", "E belonged to interact")
	assert_eq(InputRebind.binding(&"dash", InputRebind.KBM), [&"key", KEY_E])
	assert_eq(
		InputRebind.binding(&"interact", InputRebind.KBM),
		[&"key", KEY_SPACE],
		"interact gets Space"
	)
	assert_true(p.section("bindings").has("interact"), "both are stored")


func test_pad_inputs_bind_only_on_the_pad_side() -> void:
	var p := ProfileStore.new("")
	InputDefaults.apply()
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_Y
	b.pressed = true
	InputRebind.rebind(p, &"utility", InputRebind.spec_of(b))
	assert_eq(InputRebind.binding(&"utility", InputRebind.PAD), [&"button", JOY_BUTTON_Y])
	assert_eq(
		InputRebind.binding(&"utility", InputRebind.KBM), [&"key", KEY_SHIFT], "the key stays"
	)
	var small := InputEventJoypadMotion.new()
	small.axis = JOY_AXIS_LEFT_X
	small.axis_value = 0.3
	assert_eq(InputRebind.spec_of(small), [], "a small stick move is no binding")
	small.axis_value = -0.9
	assert_eq(InputRebind.spec_of(small), [&"axis", JOY_AXIS_LEFT_X, -1.0])


func test_bindings_survive_a_profile_round_trip_and_reset() -> void:
	var path := "user://test_rebind_profile.json"
	var p := ProfileStore.new(path)
	InputDefaults.apply()
	InputRebind.rebind(p, &"dash", [&"key", KEY_J])
	assert_true(p.save_file())
	InputDefaults.apply()
	var q := ProfileStore.open(path)
	InputRemap.apply(q)
	assert_eq(InputRebind.binding(&"dash", InputRebind.KBM), [&"key", KEY_J], "loaded back")
	InputRebind.reset(q)
	assert_eq(InputRebind.binding(&"dash", InputRebind.KBM), [&"key", KEY_SPACE], "reset restores")
	assert_true(q.section("bindings").is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_labels_name_every_default_binding() -> void:
	InputDefaults.apply()
	for action in InputRebind.ACTIONS:
		for device in [InputRebind.KBM, InputRebind.PAD]:
			if InputRebind.has_slot(action, device):
				var spec := InputRebind.binding(action, device)
				assert_false(spec.is_empty(), "%s has a %s binding" % [action, device])
				assert_false(
					InputLabels.text(spec).is_empty(), "%s/%s has a label" % [action, device]
				)
