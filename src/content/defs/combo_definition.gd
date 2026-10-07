class_name ComboDefinition
extends ContentDef
## A named combo (v0.3.0 PLAN L8, G): owning both items unlocks it, with its own effect, card and look. `effect`
## picks what it does; only that effect's fields are read and validated. Values are starting values the owner tunes
## after playing. Pairs are unordered; the validator checks both items exist and that no pair repeats.

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
}

@export var item_a: StringName
@export var item_b: StringName
@export var name_key: StringName
@export var desc_key: StringName
@export var effect := Effect.PLASMA_ARC
## Plasma Arc, Shatter Dash, Blood Harvest: damage of the payoff hit.
@export var damage := 0
## Plasma Arc: the jump's reach; Blood Harvest: the nova's radius; Frozen Bastion: how far the attacker may be.
@export var radius_m := 0.0
## Plasma Arc: burn stacks the jump adds; Frozen Bastion: frost stacks on the attacker.
@export var stacks := 0
## Shrapnel Storm: shards per bounce and the fan's full width.
@export var count := 0
@export var spread_degrees := 0.0
## Resonance: the echo's shockwave as a share of the Overcharge shockwave; Shrapnel Storm: each shard's share of
## the bolt's damage.
@export var share_permille := 0
## Blood Harvest: HP healed (inside Vampiric Core's cap).
@export var heal := 0
## Slipstream: at most one dash refund in each window.
@export var window_seconds := 0.0


func category() -> StringName:
	return &"combos"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if String(item_a).is_empty() or String(item_b).is_empty():
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
	return issues


## Cross-definition checks (ContentValidator runs them over the whole set): both items of every combo exist, and
## no unordered pair of items has two combos.
static func cross_check(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var items := {}
	for d in defs:
		if d is ItemDefinition:
			items[d.id] = true
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
		var key := pair_key(c.item_a, c.item_b)
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
