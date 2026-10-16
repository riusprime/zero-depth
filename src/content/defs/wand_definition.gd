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
## v0.8.0 BL (docs/roadmap/v0.8.0/BLADE_AUDIT.md B3): on a Blade run a slash's hit casts a trigger's child spell this
## many times (1..3), each blade_cast_gap_seconds after the one before.
@export var blade_hit_casts := 2
@export var blade_cast_gap_seconds := 0.1
## v0.8.0 BL (B6): the hook cards (modifier ids) whose children never split or explode again.
@export var once_per_line: Array[StringName] = [&"split_shot", &"shared_explosive"]
## v0.8.0 PF2 (owner O9: the Blade Storm build's lag): the hook cards (modifier ids) whose children cast no trigger's
## spell (a Blade Storm blade's hits don't cast On Hit's slash; the trigger still ends their spell).
@export var cast_free_lines: Array[StringName] = [&"blade_storm"]
## v0.8.0 BL (B6): past this many blasts of blast_merge_ids in one tick, a blast within its radius of an earlier one
## merges into it (0 = never).
@export var blast_merge_after := 8
@export var blast_merge_ids: Array[StringName] = [&"shared_explosive"]
## v0.8.0 P2 (owner O24, Void): a black hole a Void shot leaves (its chance and its pulses' damage share are the card's,
## data/modifiers/gravity_well.tres): how long it lasts, how many stand at once (a new one past it replaces the
## oldest), how far it pulls (m) and how fast (m/s), the core whose enemies its pulses hurt (m) and the gap between
## pulses (s). Starting values.
@export var hole_seconds := 2.0
@export var hole_max := 3
@export var hole_pull_radius_m := 3.5
@export var hole_pull_mps := 3.0
@export var hole_radius_m := 1.4
@export var hole_period_seconds := 0.2


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
	if blade_hit_casts < 1 or blade_hit_casts > 3:  # v0.8.0 BL
		issues.append(ValidationIssue.new(&"range", resource_path, "blade_hit_casts is 1..3"))
	if blade_cast_gap_seconds < 0.0 or blade_cast_gap_seconds > 1.0:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "blade_cast_gap_seconds is 0..1")
		)
	if blast_merge_after < 0 or blast_merge_after > 256:
		issues.append(ValidationIssue.new(&"range", resource_path, "blast_merge_after is 0..256"))
	if hole_seconds < 0.1 or hole_seconds > 10.0:  # v0.8.0 P2
		issues.append(ValidationIssue.new(&"range", resource_path, "hole_seconds is 0.1..10"))
	if hole_max < 1 or hole_max > 16:
		issues.append(ValidationIssue.new(&"range", resource_path, "hole_max is 1..16"))
	if hole_period_seconds < 1.0 / 60.0 or hole_period_seconds > hole_seconds:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "hole_period_seconds is 1/60..hole_seconds"
			)
		)
	for pair: Array in [
		["hole_pull_radius_m", hole_pull_radius_m],
		["hole_pull_mps", hole_pull_mps],
		["hole_radius_m", hole_radius_m],
	]:
		if float(pair[1]) < 0.0 or float(pair[1]) > 20.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s is 0..20" % pair[0]))
	return issues
