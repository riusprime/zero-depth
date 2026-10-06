class_name InputRemap
extends RefCounted
## Key and button bindings stored in the profile's "bindings" section, applied to InputMap at boot
## (ARCHITECTURE §7). A binding is a list of InputDefaults specs ([kind, code, value?]). The rebinding UI is v0.1.0.


static func apply(profile: ProfileStore) -> void:
	var bindings := profile.section("bindings")
	for action: String in bindings:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for spec: Array in bindings[action]:
			InputMap.action_add_event(action, InputDefaults.make_event(_spec(spec)))


static func set_binding(profile: ProfileStore, action: StringName, specs: Array) -> void:
	var stored := []
	for spec: Array in specs:
		stored.append([String(spec[0])] + spec.slice(1))
	profile.section("bindings")[String(action)] = stored


static func clear(profile: ProfileStore) -> void:
	profile.data["bindings"] = {}


## JSON stores numbers as floats: codes go back to ints; an axis value stays a float.
static func _spec(stored: Array) -> Array:
	var out: Array = [StringName(stored[0])]
	if stored.size() > 1:
		out.append(int(stored[1]))
	if stored.size() > 2:
		out.append(float(stored[2]))
	return out
