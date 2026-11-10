class_name FormPackHold
extends RefCounted
## A view's pack effects that follow something each frame (a bolt, a needle, a wisp, a zone) and end with
## it. The caller names each thing by a key; every frame it calls begin(), then put() for the things that exist, then
## end(): what was not put is released back to PackFx's pool. Cosmetic only (EI-07).
## - put() spawns the effect held (life 0) the first time a key is seen, and moves it every frame after. When PackFx's
##   family has no free slot at that moment, the key is refused for its whole life and put() returns null each frame,
##   so the caller draws its old look (never a live bolt's effect taken over for a new one).
## - A pack scene's "main" animation ends after about a second and PackFx would release it then, which would end a
##   bolt still flying; held effects therefore have it loop (Animation.loop_mode, once per scene resource).

var pack: PackFx = null
var _nodes := {}
var _seen := {}
var _refused := {}


func active() -> bool:
	return pack != null


## How many keys hold an effect now (tests).
func count() -> int:
	return _nodes.size()


## Whether `key` holds a pack effect (a view that draws the old look otherwise asks).
func has(key: Variant) -> bool:
	return _nodes.has(key)


func node(key: Variant) -> Node3D:
	return _nodes.get(key)


## Whether `key` was refused (the family was full when it began): its old look draws.
func refused(key: Variant) -> bool:
	return _refused.has(key)


func begin() -> void:
	_seen.clear()


## Keeps `key`'s effect `effect_id` (of `family`) at `xf` (a basis that already carries the scale); returns it, or null
## when this key draws the old look. `colors` is read once, when it spawns.
func put(
	key: Variant, effect_id: StringName, family: StringName, xf: Transform3D, colors := {}
) -> Node3D:
	if pack == null:
		return null
	_seen[key] = true
	var n: Node3D = _nodes.get(key)
	if n != null and (not is_instance_valid(n) or not n.visible):
		_nodes.erase(key)  # PackFx gave it up (its family overflowed): this key now draws the old look
		_refused[key] = true
		return null
	if n == null:
		if _refused.has(key) or not pack.has_id(effect_id) or not pack.has_room(family):
			_refused[key] = true
			return null
		n = pack.spawn(effect_id, xf.origin, 1.0, colors, 0.0)
		if n == null:
			_refused[key] = true
			return null
		loop(n)
		_nodes[key] = n
	var was := n.global_position if n.is_inside_tree() else n.position
	if n.is_inside_tree():
		n.global_transform = xf
	else:
		n.transform = xf
	PackFx.settle(n, was, xf.origin)
	return n


## Releases what was not put since begin().
func end() -> void:
	for key in _nodes.keys():
		if not _seen.has(key):
			if pack != null:
				pack.release(_nodes[key])
			_nodes.erase(key)
	for key in _refused.keys():
		if not _seen.has(key):
			_refused.erase(key)


## Releases everything (the view clears).
func clear() -> void:
	if pack != null:
		for key in _nodes:
			pack.release(_nodes[key])
	_nodes.clear()
	_refused.clear()
	_seen.clear()


## A held scene must not end with its first pass of the "main" animation (PackFx releases a scene when it ends).
static func loop(n: Node3D) -> void:
	var anim := n.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation(PackFx.ANIM):
		var a := anim.get_animation(PackFx.ANIM)
		if a.loop_mode != Animation.LOOP_LINEAR:
			a.loop_mode = Animation.LOOP_LINEAR
