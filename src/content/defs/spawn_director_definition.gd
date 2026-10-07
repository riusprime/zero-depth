class_name SpawnDirectorDefinition
extends ContentDef
## Continuous spawning (PLAN v0.2.0 L6, PD-05 flipped; hordes v0.4.0 SC, owner F7/F10): every tier_seconds a new
## danger tier raises the alive cap, shortens the spawn interval, unlocks more of the mix and scales the HP and
## damage of the enemies that arrive. Enemies arrive in packs at the edges of the player's room and its
## neighbours. One definition serves every floor: per-floor values are arrays indexed by floor − 1 (a floor past
## the end uses the last entry), per-tier values are per-mille tables indexed by tier (a tier past the end uses the
## last entry: the tier cap). Starting values the owner tunes.

## Tier n starts at n × tier_seconds of run time (each floor's clock starts at 0).
@export var tier_seconds := 30.0
## Alive cap: min(cap_by_floor[floor − 1] + cap_per_tier × tier, cap_max).
@export var cap_by_floor := PackedInt32Array([14, 30, 50])
@export var cap_per_tier := 6
@export var cap_max := 120
## Interval between packs: max(interval_min, interval_start × interval_tier_permille[tier] / 1000).
@export var interval_start_seconds := 2.5
@export var interval_min_seconds := 0.4
@export var interval_tier_permille := PackedInt32Array([1000, 900, 810])
## Enemy max HP and damage × these per mille at the tier the enemy arrives in (on top of RunDefinition's per-floor
## tables). Integer tables, not runtime powers (EI-02): 1.10^tier and 1.05^tier rounded.
@export var hp_tier_permille := PackedInt32Array([1000, 1100, 1210])
@export var damage_tier_permille := PackedInt32Array([1000, 1050, 1102])
## A pack's size is drawn from pack_min_by_floor .. pack_max_by_floor (inclusive) for the floor, unless its mix entry
## fixes one (SpawnMixEntry.pack); it never takes the alive count past the cap.
@export var pack_min_by_floor := PackedInt32Array([2, 3, 3])
@export var pack_max_by_floor := PackedInt32Array([3, 4, 5])
## Enemies never appear closer than this to the player.
@export var min_distance_m := 8.0
## A pack's anchor is a spawn point within this distance of its room's walls (the room's edge), when there is one.
@export var edge_band_m := 3.0
@export var mix: Array[SpawnMixEntry] = []


func category() -> StringName:
	return &"spawning"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_positive(issues, "tier_seconds", tier_seconds)
	check_duration(issues, "tier_seconds", tier_seconds)
	_check_per_floor(issues, "cap_by_floor", cap_by_floor)
	if cap_per_tier < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "cap_per_tier is negative"))
	for c in cap_by_floor:
		if c > cap_max:
			issues.append(
				ValidationIssue.new(&"cap_range", resource_path, "cap_max is below a floor's cap")
			)
			break
	check_positive(issues, "interval_start_seconds", interval_start_seconds)
	check_positive(issues, "interval_min_seconds", interval_min_seconds)
	check_duration(issues, "interval_min_seconds", interval_min_seconds)
	if interval_min_seconds > interval_start_seconds:
		issues.append(
			ValidationIssue.new(
				&"interval_range",
				resource_path,
				"interval_min_seconds is above interval_start_seconds"
			)
		)
	check_permille_table(issues, "interval_tier_permille", interval_tier_permille, false)
	check_permille_table(issues, "hp_tier_permille", hp_tier_permille, true)
	check_permille_table(issues, "damage_tier_permille", damage_tier_permille, true)
	_check_per_floor(issues, "pack_min_by_floor", pack_min_by_floor)
	_check_per_floor(issues, "pack_max_by_floor", pack_max_by_floor)
	if pack_min_by_floor.size() != pack_max_by_floor.size():
		issues.append(
			ValidationIssue.new(
				&"pack_range",
				resource_path,
				"pack_min_by_floor and pack_max_by_floor differ in size"
			)
		)
	else:
		for k in pack_min_by_floor.size():
			if pack_max_by_floor[k] < pack_min_by_floor[k]:
				issues.append(
					ValidationIssue.new(
						&"pack_range", resource_path, "pack_max_by_floor[%d] is below its min" % k
					)
				)
	check_positive(issues, "min_distance_m", min_distance_m)
	if edge_band_m < 0.0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "edge_band_m is negative"))
	if mix.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "the mix is empty"))
	var opens := false
	for k in mix.size():
		var e := mix[k]
		if (
			e == null
			or String(e.enemy_id).is_empty()
			or e.weight <= 0
			or e.unlock_tier < 0
			or e.pack < 0
		):
			issues.append(ValidationIssue.new(&"mix_entry", resource_path, "mix[%d] is bad" % k))
			continue
		if e.unlock_tier == 0:
			opens = true
	if not mix.is_empty() and not opens:
		issues.append(
			ValidationIssue.new(&"mix_tier0", resource_path, "no enemy is unlocked at tier 0")
		)
	return issues


## Enemy ids that must exist in the repository.
func enemy_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e in mix:
		if e != null and not out.has(e.enemy_id):
			out.append(e.enemy_id)
	return out


## A per-floor array: at least one entry, every entry positive.
func _check_per_floor(issues: Array[ValidationIssue], field: String, a: PackedInt32Array) -> void:
	if a.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "%s is empty" % field))
	for v in a:
		if v <= 0:
			issues.append(
				ValidationIssue.new(&"not_positive", resource_path, "%s has an entry <= 0" % field)
			)
			break
