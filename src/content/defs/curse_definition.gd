class_name CurseDefinition
extends ContentDef
## A curse (v0.5.0 EV, PLAN R4; CONTENT_SCHEMA §9): a lasting drawback that comes with a strong reward (some event
## choices) or, since v0.6.0 CU (PLAN v0.5.5 S6, S7), a trade-off curse: a drawback with its own upside, offered as
## the cursed card of a cursed chest. It lasts the run unless cleansed, and each one raises threat T (PD-05) by
## `threat`. `amount` is in percent, a count for the count effects (COUNTS) or seconds for hit_stun.
## - `effect` / `amount`: the drawback; `effect_2` / `amount_2`: an optional second drawback (&"" = none);
## - `up_effect` / `up_amount` / `up_desc_key`: the upside (&"" = a plain curse, the v0.5.0 kind).

## The effects the sim knows (Curses.Effect mirrors the order; appended, never renumbered):
## enemy_speed (+amount % normal enemies' move speed), regen (-amount % regen), heat_decay (Overclock heat decays
## +amount % faster), extra_enemy (+amount enemies in every spawn arrival, under the alive cap), prices (+amount %
## shard prices: chests, the gamble shrine, shops), elite_chance (+amount % chance that a spawned enemy is elite);
## v0.6.0 CU: no_dash (the dash button does nothing), dodge (amount % chance an enemy hit is dodged), attack_slow
## (attack speed -amount %), fourth_hit (the 4th Blade combo hit / every 4th Gun shot +amount % damage), max_hp_cut
## (max HP -amount %), crit_chance (+amount % crit chance), ability_hp_cost (each Skill or Blink use costs amount %
## of max HP, never lethal), ability_damage (+amount % damage on skill and ability hits), heat_linger (Overclock
## heat decays amount % slower), overclock_damage (+amount % Overclock damage), no_minimap (the minimap is off),
## shard_gain (+amount % shards), hit_stun (a hit taken stuns you for amount seconds), move_speed (+amount % move
## speed), elite_hunt (elites in range move amount % faster toward you), elite_rare_drop (a killed elite drops a
## free rare card).
const EFFECTS: Array[StringName] = [
	&"enemy_speed",
	&"regen",
	&"heat_decay",
	&"extra_enemy",
	&"prices",
	&"elite_chance",
	&"no_dash",
	&"dodge",
	&"attack_slow",
	&"fourth_hit",
	&"max_hp_cut",
	&"crit_chance",
	&"ability_hp_cost",
	&"ability_damage",
	&"heat_linger",
	&"overclock_damage",
	&"no_minimap",
	&"shard_gain",
	&"hit_stun",
	&"move_speed",
	&"elite_hunt",
	&"elite_rare_drop",
]
## Effects whose amount is a count (or an on/off flag of 1), not a percent.
const COUNTS: Array[StringName] = [&"extra_enemy", &"no_dash", &"no_minimap", &"elite_rare_drop"]
## Effects whose amount is in seconds.
const SECONDS: Array[StringName] = [&"hit_stun"]
## Effects that cut a value by a percent (at most 90 %).
const CUTS: Array[StringName] = [&"regen", &"attack_slow", &"max_hp_cut", &"heat_linger"]

@export var name_key: StringName
## A sentence with one %s for the amount (or none for an on/off effect).
@export var desc_key: StringName
@export var effect: StringName = &"enemy_speed"
@export var amount := 15.0
## v0.6.0 CU: a second drawback (&"" = none).
@export var effect_2: StringName = &""
@export var amount_2 := 0.0
## v0.6.0 CU: the upside of a trade-off curse (&"" = a plain curse), and its sentence (one %s for up_amount, or none).
@export var up_effect: StringName = &""
@export var up_amount := 0.0
@export var up_desc_key: StringName
@export var threat := 1
## Draw weight when a curse is rolled.
@export var weight := 10


func category() -> StringName:
	return &"curses"


## A trade-off curse (v0.6.0 CU): it has an upside.
func is_trade_off() -> bool:
	return up_effect != &""


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	_check_effect(issues, effect, amount)
	if effect_2 != &"":
		_check_effect(issues, effect_2, amount_2)
	if up_effect != &"":
		_check_effect(issues, up_effect, up_amount)
		if String(up_desc_key).is_empty():
			issues.append(
				ValidationIssue.new(&"missing", resource_path, "a trade-off needs up_desc_key")
			)
	if threat < 1:
		issues.append(ValidationIssue.new(&"range", resource_path, "a curse raises threat by >= 1"))
	if weight < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "weight is negative"))
	return issues


func _check_effect(issues: Array[ValidationIssue], e: StringName, a: float) -> void:
	if not EFFECTS.has(e):
		issues.append(ValidationIssue.new(&"unknown", resource_path, "unknown effect %s" % e))
	check_positive(issues, "amount", a)
	if e == &"regen" and a > 100.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "regen cut is at most 100 %"))
	elif CUTS.has(e) and e != &"regen" and a > 90.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "%s is at most 90 %%" % e))
