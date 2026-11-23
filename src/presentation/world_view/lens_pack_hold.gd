class_name LensPackHold
extends FormPackHold
## The Hive Lens views' FormPackHold: a key the pack refused (its family full that frame, as it can be while the floor's
## effects warm up) tries again the next frame under a fresh inner key, rather than drawing nothing (or its fallback)
## for the whole of its life. The keys the callers use stay the same. Cosmetic only (EI-07).

## Caller's key -> how many times it was refused (the inner key is [key, that count]).
var _tries := {}


func put(
	key: Variant, effect_id: StringName, family: StringName, xf: Transform3D, colors := {}
) -> Node3D:
	var t := int(_tries.get(key, 0))
	var inner := [key, t]
	var n := super.put(inner, effect_id, family, xf, colors)
	if n == null and refused(inner):
		_tries[key] = t + 1
	return n


func has(key: Variant) -> bool:
	return super.has([key, int(_tries.get(key, 0))])


func node(key: Variant) -> Node3D:
	return super.node([key, int(_tries.get(key, 0))])


func end() -> void:
	super.end()
	if count() == 0:
		_tries.clear()


func clear() -> void:
	super.clear()
	_tries.clear()
