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
## The bosses' cap per floor, per mille; entry f − 1.
@export var boss_cap_permille := PackedInt32Array([2000, 3000, 4000])
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
