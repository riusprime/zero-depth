class_name PackHold
extends RefCounted
## v0.10.0 VX3: pack effects that live as long as something else does (a ground patch, a ring, a status on an enemy,
## a guard orb). The effects layer draws every frame from the sim's state, so a held effect is "touched" each frame it
## should be there: the first touch takes an effect from PackFx (held, life 0), later touches follow it, and an effect
## nobody touched in a frame is released when the frame ends (PackHold.end). Cosmetic only (EI-07).
## - touch(): the effect for `key`, or null when PackFx has no room in the family (the caller draws its old look).
## - Loops: the pack's effects are one-shot in PackFx (they end with their animation); a held one must keep going, so
##   its "main" animation loops and its particles stop being one-shot (the pack's own controller does the same).

var fx: PackFx = null
var held := 0  # held effects now (tests)
var _items := {}  # key -> {node, id, frame, data}
var _frame := 0


## Starts a frame (VfxLayer.begin).
func begin() -> void:
	_frame += 1


## The held effect for `key` (an int the caller makes from what it follows), at `pos`, `scale`, spawning it on the
## first touch (`id` in `family`, with `colors`; `setup` is called with the new node). Null: no PackFx, an unknown id
## or no room (the caller keeps its old look).
func touch(
	key: int,
	id: StringName,
	family: StringName,
	pos: Vector3,
	scale: float,
	colors: Dictionary = {},
	setup: Callable = Callable()
) -> Node3D:
	if fx == null or not is_instance_valid(fx):
		return null
	var it: Dictionary = _items.get(key, {})
	if not it.is_empty():
		var node: Node3D = it["node"]
		if is_instance_valid(node) and it["id"] == id and _is_live(node):
			it["frame"] = _frame
			_move(node, pos, scale, it)
			return node
		_items.erase(key)  # (PackFx reused it for something else, or the id changed)
		held = _items.size()
	if not fx.has_id(id) or not fx.has_room(family):
		return null
	var n := play(fx, id, pos, scale, colors, 0.0)
	if n == null:
		return null
	loop(n)
	if setup.is_valid():
		setup.call(n)
	_items[key] = {"node": n, "id": id, "frame": _frame, "scale": scale, "data": {}}
	held = _items.size()
	return n


## True when `key` has a held effect (as of its last touch).
func has(key: int) -> bool:
	return _items.has(key)


## A small dictionary the caller keeps with `key`'s effect (a timer, a count); empty without one.
func data(key: int) -> Dictionary:
	return (_items[key]["data"] as Dictionary) if _items.has(key) else {}


## Ends a frame (VfxLayer.finish): every effect not touched since begin() goes back to PackFx.
func end() -> void:
	if _items.is_empty():
		return
	for key: int in _items.keys():
		var it: Dictionary = _items[key]
		if int(it["frame"]) != _frame:
			_drop(key)
	held = _items.size()


## Releases everything (a floor ends, tests).
func clear() -> void:
	for key: int in _items.keys():
		_drop(key)
	held = 0


func _drop(key: int) -> void:
	var it: Dictionary = _items[key]
	_items.erase(key)
	var node: Node3D = it["node"]
	if fx != null and is_instance_valid(fx) and is_instance_valid(node) and _is_live(node):
		fx.release(node)


## Whether PackFx still has `node` as a live effect (it may have reused it for a newer one when its family was full).
func _is_live(node: Node3D) -> bool:
	return fx.is_live(node)


func _move(node: Node3D, pos: Vector3, scale: float, it: Dictionary) -> void:
	var was := node.global_position if node.is_inside_tree() else node.position
	if node.is_inside_tree():
		node.global_position = pos
	else:
		node.position = pos
	PackFx.settle(node, was, pos)
	if not is_equal_approx(float(it["scale"]), scale):
		it["scale"] = scale
		node.scale = Vector3.ONE * scale


## PackFx.spawn, then the instance's materials are its own. The pack's scenes share their materials between every
## instance of a scene (a recolour on one recolours all, and their animations drive one shared alpha), so an effect
## that is coloured per use (bleed red, venom green) needs its own. The colours were set on the shared ones a moment
## ago, so the copies start right.
static func play(
	fx: PackFx, id: StringName, pos: Vector3, scale: float, colors: Dictionary = {}, life := -1.0
) -> Node3D:
	var n := fx.spawn(id, pos, scale, colors, life)
	if n != null:
		localize(n)
	return n


## Gives `node` its own copy of every material override (once).
static func localize(node: Node3D) -> void:
	if node.has_meta(&"pack_local"):
		return
	node.set_meta(&"pack_local", true)
	for ch in node.find_children("*", "GeometryInstance3D", true, false):
		var gi := ch as GeometryInstance3D
		if gi.material_override != null:
			gi.material_override = gi.material_override.duplicate()


## The effect keeps running: its animation loops and its particles are not one-shot.
static func loop(node: Node3D) -> void:
	var anim := node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation(PackFx.ANIM):
		anim.get_animation(PackFx.ANIM).loop_mode = Animation.LOOP_LINEAR
	for c in node.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).one_shot = false
			(c as GPUParticles3D).restart()
