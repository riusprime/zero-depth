class_name CatchUpDefinition
extends ContentDef
## The hidden growth-matching difficulty (v0.5.5 Step DS, owner D4 and D7, "Yes, but hidden"; SIM_CONTRACTS §11;
## CONTENT_SCHEMA §7). At each floor entry the sim reads the player's power P from the build alone (CatchUp.power)
## and compares it with the power a normal build has by then, E(floor): the catch-up m = clamp(sqrt(P / E), 1, cap),
## cap = cap(floor) + threat_cap_bonus × threat T. Enemy HP × m, enemy damage × sqrt(m), fixed for the floor. A boss
## takes its own m when it spawns, against the expected power at the floor's end and the boss cap. Every number is a
## starting value the owner tunes by play (never a measurement: no bot sims, P1).

## E(floor) at floor entry, per mille of a fresh build's power (1000 = the build you start with); entry f − 1, the
## last repeats.
@export var expected_power_permille := PackedInt32Array([1000, 2000, 4000])
## The enemies' cap per floor, per mille (1500 = ×1.5); entry f − 1, the last repeats.
@export var cap_permille := PackedInt32Array([1500, 2000, 2500])
## E at the boss (the floor's end), per mille; entry f − 1.
@export var boss_expected_power_permille := PackedInt32Array([2000, 4000, 7000])
## The bosses' cap per floor, per mille; entry f − 1 (v0.9.5 BH1, Q2: 2.5 / 3.0 / 3.5 / 4.0 / 4.5 for floors 1-5).
@export var boss_cap_permille := PackedInt32Array([2500, 3000, 3500, 4000, 4500])
## v0.9.5 BH1 (owner Q2): each boss draws its HP spread in +- this per mille (80 = +-8 %), applied after the cap.
@export var boss_spread_permille := 80
## v0.10.5 O2b (owner D38 (a): "fights should last 1-2 minutes"): a floor boss's HP multiplier when your power equals
## the boss's expected power, per floor (entry f − 1, the last repeats). Its HP multiplier is this × your power ÷ the
## expected power (power capped below), so a fight lasts about as long at any power. Empty = off (HP × the catch-up m).
## data/scaling/catch_up.tres: 3090 / 3770 / 4450 for floors 1-3 (floors 4-5 repeat floor 3's), from the O2b probe
## (90 s ÷ the before fight at the expected power, then × 90 s ÷ the first paced mean): starting value (owner D38,
## 2026-11-01).
@export var boss_pace_permille := PackedInt32Array()
## v0.10.5 O2b: past this power (per mille of the expected power) the boss's HP stops growing, so a far stronger build
## is quicker: deleting a phase stays possible, very rarely. 3000: starting value (owner D38, 2026-11-01).
@export var boss_pace_cap_permille := 3000
## v0.10.5 O2b: the paced HP multiplier's floor, per mille (a weak build never meets less than the boss's own HP).
## 1000: starting value (owner D38, 2026-11-01).
@export var boss_pace_min_permille := 1000
## Added to both caps per point of threat T (Curses.threat: curses held and Deep floors taken), per mille.
@export var threat_cap_bonus_permille := 250
## The build's power terms besides the weapon and the stat cards (per mille each): every level of an ability that
## is not the starting weapon, every item (mod) held, every combo owned.
@export var ability_level_permille := 120
@export var item_permille := 80
@export var combo_permille := 150


func category() -> StringName:
	return &"scaling"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	_check_table(issues, "expected_power_permille", expected_power_permille, 1)
	_check_table(issues, "cap_permille", cap_permille, 1000)
	_check_table(issues, "boss_expected_power_permille", boss_expected_power_permille, 1)
	_check_table(issues, "boss_cap_permille", boss_cap_permille, 1000)
	for k in boss_pace_permille.size():  # v0.10.5 O2b: optional (empty = off), any order
		if boss_pace_permille[k] < 1 or boss_pace_permille[k] > 100000 or k >= 64:
			issues.append(
				ValidationIssue.new(
					&"table_range", resource_path, "boss_pace_permille[%d] is outside 1..100000" % k
				)
			)
	if boss_pace_cap_permille < 1000 or boss_pace_cap_permille > 100000:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "boss_pace_cap_permille is outside 1000..100000"
			)
		)
	if boss_pace_min_permille < 1 or boss_pace_min_permille > 100000:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "boss_pace_min_permille is outside 1..100000"
			)
		)
	if boss_spread_permille < 0 or boss_spread_permille > 500:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "boss_spread_permille is outside 0..500")
		)
	for pair: Array in [
		["threat_cap_bonus_permille", threat_cap_bonus_permille],
		["ability_level_permille", ability_level_permille],
		["item_permille", item_permille],
		["combo_permille", combo_permille],
	]:
		if int(pair[1]) < 0 or int(pair[1]) > 10000:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s is outside 0..10000" % pair[0])
			)
	return issues


## An ERROR unless `table` has 1..64 entries, each in lo..100000 and never lower than the one before.
func _check_table(
	issues: Array[ValidationIssue], field: String, table: PackedInt32Array, lo: int
) -> void:
	if table.is_empty() or table.size() > 64:
		issues.append(
			ValidationIssue.new(&"table_size", resource_path, "%s needs 1 to 64 entries" % field)
		)
		return
	for k in table.size():
		if table[k] < lo or table[k] > 100000:
			issues.append(
				ValidationIssue.new(
					&"table_range", resource_path, "%s[%d] is outside %d..100000" % [field, k, lo]
				)
			)
		elif k > 0 and table[k] < table[k - 1]:
			issues.append(
				ValidationIssue.new(&"table_order", resource_path, "%s[%d] falls" % [field, k])
			)
