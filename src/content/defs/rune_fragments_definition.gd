class_name RuneFragmentsDefinition
extends ContentDef
## v0.9.0 MP (PLAN W49-W52, Q28; owner "void unlocked when traveling through a purple portal, lance is unlocked by
## default"): the profile's one meta currency, Rune Fragments. How a run earns them (starting values, not decided by
## the owner: OWNER_QUESTIONS) and the forms out of every offer until the profile has travelled through a Purple
## Portal. Category `rune_fragments`, in data/meta/. What they buy is sideways only (PD-06): the robes' prices are on
## each RobeDefinition (`price`). Compiled into FragmentTable (MetaProgress.compile_table).

## Fragments for a floor cleared (its portal taken), its boss beaten, each secret found (timed door, rune puzzle,
## cracked wall, purple runes), the Purple Portal travelled, the final boss beaten, each collectible (CL's hook).
@export var floor_cleared := 2
@export var boss := 3
@export var secret := 2
@export var purple_portal := 3
@export var final_boss := 10
@export var collectible := 1
## v0.10.5 O5a (owner L2: "more fragments a loop"): every source above earns × (1000 + this × (loop − 1)) / 1000 past
## the first loop (500: loop 2 ×1.5, loop 3 ×2), rounded down. Starting value.
@export var loop_bonus_permille := 500
## Card ids (ItemDefinition / modifier ids) no offer draws until the profile has travelled through a Purple Portal.
@export var portal_unlocks: Array[StringName] = [&"gun_void"]


func category() -> StringName:
	return &"rune_fragments"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	for v: int in [
		floor_cleared, boss, secret, purple_portal, final_boss, collectible, loop_bonus_permille
	]:
		if v < 0:
			issues.append(
				ValidationIssue.new(&"negative", resource_path, "a fragment amount is < 0")
			)
	return issues
