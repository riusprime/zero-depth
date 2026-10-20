class_name AttackBook
extends RefCounted
## v0.6.0 MX1: a build's compiled attack specs (Modifiers.compile), cached on World.attack_book until the build
## changes (an item picked, an ability levelled, a save restored). Derived from the build, so a snapshot keeps it out
## and a restore compiles it again; its digest is hashed (Modifiers.hash_into).

## AttackSpec by id, and the ids in compile order (the combo steps, the bolt, the Skill).
var specs := {}
var order := PackedStringArray()
## The build's modifiers in pick order (the layer order), as compiled.
var modifier_ids := PackedStringArray()
## SHA-256 of every spec in order (hooks and children included).
var digest := ""
## v0.6.0 MX2: every spec by its key (AttackSpec.key: the roots by id, each hook child under "<parent key>/<n>"), so
## what a launch leaves behind (a projectile, a bomb, a patch, a ring) runs its own spec.
var by_key := {}
## v0.8.0 RM (Remnants): every remnant hook (AttackHook.remnant) by its child's key (the key a remnant stores, so an
## activation finds its rule and its cast; derived like by_key), and the consumers (Grand Finale) in key order.
var remnant_hooks := {}
var consumers: Array[AttackHook] = []


func add(s: AttackSpec) -> void:
	specs[s.id] = s
	order.append(String(s.id))


func spec(id: StringName) -> AttackSpec:
	return specs.get(id)


func has(id: StringName) -> bool:
	return specs.has(id)


## The spec filed under `key` (null if this book has none: a build changed since the attack left).
func find(key: String) -> AttackSpec:
	return by_key.get(key)


## v0.6.0 MX2: files every spec and every hook child by key (a child reached twice keeps its first key).
func register() -> void:
	by_key = {}
	remnant_hooks = {}
	consumers = []
	for id in order:
		_file(specs[StringName(id)], id)


func _file(s: AttackSpec, key: String) -> void:
	if s.key == "":
		s.key = key
	if not by_key.has(key):
		by_key[key] = s
	for k in s.hooks.size():
		var h := s.hooks[k]
		var ck := "%s/%d" % [key, k]
		_file(h.child, ck)
		if h.remnant != null and not remnant_hooks.has(h.child.key):  # v0.8.0 RM
			remnant_hooks[h.child.key] = h
			if h.remnant.activate == RemnantRule.Activate.CONSUME:
				consumers.append(h)


## v0.8.0 RM: the remnant hook whose child is filed under `key` (null: none, or the build changed).
func remnant_hook(key: String) -> AttackHook:
	return remnant_hooks.get(key)


func seal() -> void:
	var h := StateHasher.new()
	h.add_string(",".join(modifier_ids))
	for id in order:
		(specs[StringName(id)] as AttackSpec).hash_into(h)
	digest = h.finish_hex()
