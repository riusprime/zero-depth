class_name ComboDefinition
extends ContentDef
## A named combo (v0.3.0 PLAN L8, G): owning both items unlocks it, with its own effect, card and look. `effect`
## picks what it does; only that effect's fields are read and validated. Values are starting values the owner tunes
## after playing. Pairs are unordered; the validator checks both items exist and that no pair repeats.
## v0.4.0 AB: an ability combo names two abilities (ability_a, ability_b) instead of two items: owning both at
## min_level or higher evolves the pair (owner F13). A combo names either two items or two abilities, never both.

## Appended, never renumbered (the compiler maps each to ComboTable.Effect).
enum Effect {
	PLASMA_ARC,
	SHATTER_DASH,
	RESONANCE,
	SHRAPNEL_STORM,
	BLOOD_HARVEST,
	SPIKED_PHASE,
	SLIPSTREAM,
	FROZEN_BASTION,
	STORM_BOMBS,
	NAPALM_DRONE,
	GLACIER_RING,
	BLINK_CHARGE,
	BLADE_DANCE,
	WINGMAN,
	SUPERCONDUCTOR,
	EMBER_WARD,
}

## The effects that pair two abilities (v0.4.0 AB).
const ABILITY_EFFECTS: Array[int] = [
	Effect.STORM_BOMBS,
	Effect.NAPALM_DRONE,
	Effect.GLACIER_RING,
	Effect.BLINK_CHARGE,
	Effect.BLADE_DANCE,
	Effect.WINGMAN,
	Effect.SUPERCONDUCTOR,
	Effect.EMBER_WARD,
]

@export var item_a: StringName
@export var item_b: StringName
## v0.4.0 AB: an ability combo's two abilities (ids under data/abilities) and the level both must reach.
@export var ability_a: StringName
@export var ability_b: StringName
@export var min_level := 3
@export var name_key: StringName
@export var desc_key: StringName
@export var effect := Effect.PLASMA_ARC
## Plasma Arc, Shatter Dash, Blood Harvest: damage of the payoff hit. v0.4.0 AB: Storm Bombs' bolt, Napalm Drone's
## fire (per hit), Ember Ward's burst.
@export var damage := 0
## Plasma Arc: the jump's reach; Blood Harvest: the nova's radius; Frozen Bastion: how far the attacker may be.
## v0.4.0 AB: Storm Bombs' chain reach from the blast, Napalm Drone's fire patch, Blade Dance's extra ring radius,
## Ember Ward's burst.
@export var radius_m := 0.0
## Plasma Arc: burn stacks the jump adds; Frozen Bastion: frost stacks on the attacker. v0.4.0 AB: shock (Storm
## Bombs), burn (Napalm Drone, Ember Ward) or frost (Glacier Ring) stacks per hit.
@export var stacks := 0
## Shrapnel Storm: shards per bounce and the fan's full width. v0.4.0 AB: Storm Bombs' bolts per blast, Blink
## Charge's bombs per blink.
@export var count := 0
@export var spread_degrees := 0.0
## Resonance: the echo's shockwave as a share of the Overcharge shockwave; Shrapnel Storm: each shard's share of
## the bolt's damage. v0.4.0 AB: Blade Dance's blade damage bonus, Wingman's bolt as a share of a drone bolt,
## Superconductor's bonus on a chilled or frozen enemy.
@export var share_permille := 0
## Blood Harvest: HP healed (inside Vampiric Core's cap).
@export var heal := 0
## Slipstream: at most one dash refund in each window. v0.4.0 AB: how long Napalm Drone's fire lasts, Blade
## Dance lasts after a landed swing, the least time between Wingman volleys and between Ember Ward bursts.
@export var window_seconds := 0.0


func category() -> StringName:
	return &"combos"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if is_ability_combo():
		_validate_abilities(issues)
	elif String(item_a).is_empty() or String(item_b).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "item_a and item_b are required")
		)
	elif item_a == item_b:
		issues.append(ValidationIssue.new(&"combo_pair", resource_path, "a combo needs two items"))
	match effect:
		Effect.PLASMA_ARC:
			check_positive(issues, "damage", damage)
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "stacks", stacks)
		Effect.SHATTER_DASH:
			check_positive(issues, "damage", damage)
		Effect.RESONANCE:
			check_positive(issues, "share_permille", share_permille)
		Effect.SHRAPNEL_STORM:
			check_positive(issues, "count", count)
			check_positive(issues, "spread_degrees", spread_degrees)
			check_positive(issues, "share_permille", share_permille)
		Effect.BLOOD_HARVEST:
			check_positive(issues, "damage", damage)
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "heal", heal)
		Effect.SLIPSTREAM:
			check_positive(issues, "window_seconds", window_seconds)
			check_duration(issues, "window_seconds", window_seconds)
		Effect.FROZEN_BASTION:
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "stacks", stacks)
	if effect in ABILITY_EFFECTS:
		_validate_ability_effect(issues)
	elif is_ability_combo():
		issues.append(
			ValidationIssue.new(
				&"mismatch", resource_path, "an ability combo has an ability effect"
			)
		)
	return issues


## v0.4.0 AB: the combo pairs two abilities (it names one).
func is_ability_combo() -> bool:
	return not String(ability_a).is_empty() or not String(ability_b).is_empty()


func _validate_abilities(issues: Array[ValidationIssue]) -> void:
	if not String(item_a).is_empty() or not String(item_b).is_empty():
		issues.append(
			ValidationIssue.new(
				&"combo_pair", resource_path, "two items or two abilities, not both"
			)
		)
	if String(ability_a).is_empty() or String(ability_b).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "ability_a and ability_b are required")
		)
	elif ability_a == ability_b:
		issues.append(
			ValidationIssue.new(&"combo_pair", resource_path, "a combo needs two abilities")
		)
	if min_level < 1 or min_level > AbilityDefinition.MAX_LEVEL:
		issues.append(ValidationIssue.new(&"range", resource_path, "min_level is 1..5"))


func _validate_ability_effect(issues: Array[ValidationIssue]) -> void:
	if not is_ability_combo():
		issues.append(
			ValidationIssue.new(&"mismatch", resource_path, "this effect pairs two abilities")
		)
	match effect:
		Effect.STORM_BOMBS:
			check_positive(issues, "damage", damage)
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "count", count)
			check_positive(issues, "stacks", stacks)
		Effect.NAPALM_DRONE:
			check_positive(issues, "damage", damage)
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "stacks", stacks)
			check_positive(issues, "window_seconds", window_seconds)
		Effect.GLACIER_RING:
			check_positive(issues, "stacks", stacks)
		Effect.BLINK_CHARGE:
			check_positive(issues, "count", count)
		Effect.BLADE_DANCE:
			check_positive(issues, "share_permille", share_permille)
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "window_seconds", window_seconds)
		Effect.WINGMAN:
			check_positive(issues, "share_permille", share_permille)
			check_positive(issues, "window_seconds", window_seconds)
		Effect.SUPERCONDUCTOR:
			check_positive(issues, "share_permille", share_permille)
		Effect.EMBER_WARD:
			check_positive(issues, "damage", damage)
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "stacks", stacks)
			check_positive(issues, "window_seconds", window_seconds)
	check_duration(issues, "window_seconds", window_seconds)


## Cross-definition checks (ContentValidator runs them over the whole set): both items of every combo exist, and
## no unordered pair of items has two combos.
static func cross_check(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var items := {}
	var abilities := {}
	for d in defs:
		if d is ItemDefinition:
			items[d.id] = true
		elif d is AbilityDefinition:
			abilities[d.id] = true
	var pairs := {}
	for d in defs:
		if not d is ComboDefinition:
			continue
		var c := d as ComboDefinition
		for item: StringName in [c.item_a, c.item_b]:
			if not String(item).is_empty() and not items.has(item):
				issues.append(
					ValidationIssue.new(&"unknown_item", c.resource_path, "no item %s" % item)
				)
		for ab: StringName in [c.ability_a, c.ability_b]:  # v0.4.0 AB
			if not String(ab).is_empty() and not abilities.has(ab):
				issues.append(
					ValidationIssue.new(&"unknown_ability", c.resource_path, "no ability %s" % ab)
				)
		var key := (
			"ab:" + pair_key(c.ability_a, c.ability_b)
			if c.is_ability_combo()
			else pair_key(c.item_a, c.item_b)
		)
		if pairs.has(key):
			issues.append(
				ValidationIssue.new(
					&"duplicate_pair", c.resource_path, "pair %s also in %s" % [key, pairs[key]]
				)
			)
		else:
			pairs[key] = c.resource_path
	return issues


## The same key for (a, b) and (b, a).
static func pair_key(a: StringName, b: StringName) -> String:
	return "%s+%s" % ([a, b] if String(a) < String(b) else [b, a])
