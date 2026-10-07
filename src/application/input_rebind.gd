class_name InputRebind
extends RefCounted
## Rebinding for the Options screen (v0.3.0 O): each action has one keyboard/mouse binding and one pad binding
## (InputDefaults specs). A new binding that another action already uses on the same device swaps the two, so no
## input is ever left doing two things or nothing. Bindings live in the profile (InputRemap) and apply to InputMap
## at once.

const KBM := &"kbm"
const PAD := &"pad"
## The actions the screen lists, in order. Aiming has no keyboard binding (the mouse aims).
const ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"primary",
	&"shoot",
	&"dash",
	&"utility",
	&"interact",
	&"pause",
	&"aim_up",
	&"aim_down",
	&"aim_left",
	&"aim_right",
]
const PAD_ONLY: Array[StringName] = [&"aim_up", &"aim_down", &"aim_left", &"aim_right"]
## A stick or trigger must move this far to count as a new binding.
const AXIS_PRESS := 0.6


## Whether `action` has a binding slot on `device`.
static func has_slot(action: StringName, device: StringName) -> bool:
	return device == PAD or not PAD_ONLY.has(action)


## The device a spec belongs to.
static func device_of(spec: Array) -> StringName:
	return KBM if spec[0] == &"key" or spec[0] == &"mouse" else PAD


## The spec of an input event that could become a binding ([] if it can't: a release, an echo, a small stick move).
static func spec_of(ev: InputEvent) -> Array:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).physical_keycode
		return [&"key", k if k != KEY_NONE else (ev as InputEventKey).keycode]
	if ev is InputEventMouseButton and ev.pressed:
		return [&"mouse", (ev as InputEventMouseButton).button_index]
	if ev is InputEventJoypadButton and ev.pressed:
		return [&"button", (ev as InputEventJoypadButton).button_index]
	if (
		ev is InputEventJoypadMotion
		and absf((ev as InputEventJoypadMotion).axis_value) >= AXIS_PRESS
	):
		var m := ev as InputEventJoypadMotion
		return [&"axis", m.axis, 1.0 if m.axis_value > 0.0 else -1.0]
	return []


## The current binding of `action` on `device`, from InputMap ([] when none).
static func binding(action: StringName, device: StringName) -> Array:
	if not InputMap.has_action(action):
		return []
	for ev in InputMap.action_get_events(action):
		var spec := _spec_of_bound(ev)
		if not spec.is_empty() and device_of(spec) == device:
			return spec
	return []


## Binds `spec` to `action` on the spec's device. If another listed action holds `spec` on that device, it takes
## `action`'s old binding (a swap). Returns the action swapped with, or &"". Stores both in the profile and applies.
static func rebind(profile: ProfileStore, action: StringName, spec: Array) -> StringName:
	var device := device_of(spec)
	var old := binding(action, device)
	var swapped := &""
	for other in ACTIONS:
		if other != action and has_slot(other, device) and same(binding(other, device), spec):
			swapped = other
			_store(profile, other, device, old)
			break
	_store(profile, action, device, spec)
	InputRemap.apply(profile)
	return swapped


## Back to InputDefaults.
static func reset(profile: ProfileStore) -> void:
	InputRemap.clear(profile)
	InputDefaults.apply()


static func same(a: Array, b: Array) -> bool:
	if (
		a.is_empty()
		or b.is_empty()
		or a.size() != b.size()
		or a[0] != b[0]
		or int(a[1]) != int(b[1])
	):
		return false
	return a.size() < 3 or signf(float(a[2])) == signf(float(b[2]))


## `action`'s full binding list with `device`'s slot set to `spec` (or emptied by []), saved to the profile.
static func _store(
	profile: ProfileStore, action: StringName, device: StringName, spec: Array
) -> void:
	var specs: Array = []
	for d in [KBM, PAD]:
		var s := spec if d == device else binding(action, d)
		if not s.is_empty():
			specs.append(s)
	InputRemap.set_binding(profile, action, specs)
	# Apply this action now, so the next binding() read (the swap's second half) sees it.
	InputMap.action_erase_events(action)
	for s: Array in specs:
		InputMap.action_add_event(action, InputDefaults.make_event(s))


static func _spec_of_bound(ev: InputEvent) -> Array:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return [&"key", k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode]
	if ev is InputEventMouseButton:
		return [&"mouse", (ev as InputEventMouseButton).button_index]
	if ev is InputEventJoypadButton:
		return [&"button", (ev as InputEventJoypadButton).button_index]
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		return [&"axis", m.axis, 1.0 if m.axis_value > 0.0 else -1.0]
	return []
