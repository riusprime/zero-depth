class_name RobeDefinition
extends ContentDef
## v0.9.0 RB (owner, PLAN "Owner decisions" RB; docs/roadmap/v0.9.0/AFFINITIES.md R1-R6): one robe colour for the
## hero's cloak and hood, picked at the hub's Wardrobe. Cosmetic only: no run reads it. Category `robe`, in
## data/wardrobe/. The hero's blue core stays the same on every robe; no robe uses the enemy red (#E25A4C) or the
## hostile yellow (#FBD07A) (tests/content/test_wardrobe_content.gd).
## `free` robes are worn from the start; the others are bought with Rune Fragments at the Progression Station (MP,
## `price`), which puts their id in the profile's `unlocks.robes` list (Wardrobe.robe_unlocked).

@export var order := 0
@export var name_key: StringName
## The cloak's and hood's outside, and the cloak's underside.
@export var cloak := Color("#EBDCCB")
@export var underside := Color("#C9B8A6")
@export var free := false
## v0.9.0 MP: what a robe that isn't free costs in Rune Fragments at the Progression Station (a starting value).
@export var price := 0


func category() -> StringName:
	return &"robe"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "a robe needs a name_key"))
	if not free and price <= 0:
		issues.append(ValidationIssue.new(&"price", resource_path, "a robe to buy needs a price"))
	return issues
