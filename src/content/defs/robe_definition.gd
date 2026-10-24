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
## MP2 (owner, PLAN "Owner decisions" MP2: "ascending cost starting from 75 and 25 more each one"): the ladder's first
## price; MetaProgress.price_of adds `price_step` for each ladder robe already bought.
@export var price := 0
## MP2: the ladder's step (the four robes: 25); 0 for a robe outside the ladder (the epic robes' flat 250).
@export var price_step := 0
## MP2: an epic robe (PLAN MP2: "then 250 the epic robe"): it changes the hero's shape, not only the colour (`style`,
## built by EpicRobeView). Cosmetic only (PD-06).
@export var epic := false
## MP2: listed as "???" (ROBE_HIDDEN) with a silhouette at the station and the Wardrobe until it is bought.
@export var hidden := false
## MP2: the epic robe's build in the avatar (EpicRobeView: &"fallen", &"divine"); empty for a colour robe.
@export var style := &""


func category() -> StringName:
	return &"robe"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "a robe needs a name_key"))
	if not free and price <= 0:
		issues.append(ValidationIssue.new(&"price", resource_path, "a robe to buy needs a price"))
	if price_step < 0:
		issues.append(
			ValidationIssue.new(&"price", resource_path, "a robe's price_step is never negative")
		)
	if epic and String(style).is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "an epic robe needs a style"))
	return issues
