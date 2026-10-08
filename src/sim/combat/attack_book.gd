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


func add(s: AttackSpec) -> void:
	specs[s.id] = s
	order.append(String(s.id))


func spec(id: StringName) -> AttackSpec:
	return specs.get(id)


func has(id: StringName) -> bool:
	return specs.has(id)


func seal() -> void:
	var h := StateHasher.new()
	h.add_string(",".join(modifier_ids))
	for id in order:
		(specs[StringName(id)] as AttackSpec).hash_into(h)
	digest = h.finish_hex()
