class_name WandDefinition
extends ContentDef
## v0.6.5 WN1 (docs/design/WAND.md, owner W3 and W6; CONTENT_SCHEMA "The wand"): the wand's numbers, one `.tres` in
## data/wand/ (its own file, so the dev panel's tuning data merges beside it). Every number is a starting value the
## owner tunes by play (never a measurement: no bot sims, P1).
## - The slots per floor: the wand starts with 4 and gains 2 after each boss (owner: "Grows during the run").
## - The child spell a trigger casts (WAND.md rule 3: "a small copy of your basic attack"): the weapon's plain attack
##   (the Gun's bolt, the Blade's first slash) with its size (a bolt's radius, a slash's reach) × size_permille, its
##   range (a bolt's flight) × range_permille, and its hits dealing damage_permille of the hit that set it off.

## The most slots a wand ever has (the HUD's pips and the swap answers' codes are sized for it).
const MAX_SLOTS := 8

## The wand's slot count on floor f (entry f − 1; the last entry repeats past the end).
@export var slots_per_floor := PackedInt32Array([4, 6, 8])
## The child spell's size, range and damage share, per mille of the basic attack's.
@export var child_size_permille := 600
@export var child_range_permille := 600
@export var child_damage_permille := 500


func category() -> StringName:
	return &"wand"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if slots_per_floor.is_empty() or slots_per_floor.size() > 64:
		issues.append(
			ValidationIssue.new(
				&"table_size", resource_path, "slots_per_floor needs 1 to 64 entries"
			)
		)
	for k in slots_per_floor.size():
		var n := slots_per_floor[k]
		if n < 1 or n > MAX_SLOTS:
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "slots_per_floor[%d] is outside 1..%d" % [k, MAX_SLOTS]
				)
			)
		elif k > 0 and n < slots_per_floor[k - 1]:
			issues.append(
				ValidationIssue.new(
					&"table_order",
					resource_path,
					"slots_per_floor[%d] is lower than the one before" % k
				)
			)
	for pair: Array in [
		["child_size_permille", child_size_permille],
		["child_range_permille", child_range_permille],
		["child_damage_permille", child_damage_permille],
	]:
		if int(pair[1]) < 1 or int(pair[1]) > 10000:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s is outside 1..10000" % pair[0])
			)
	return issues
