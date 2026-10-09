class_name ModifierCompiler
extends RefCounted
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md; CONTENT_SCHEMA "Modifiers"): ModifierDefinition → ModifierTable in sim
## units. ContentCompiler.compile_item compiles an item's modifiers with it.

## Content field (ModifierOpDefinition.FIELD_STAGE) -> the AttackSpec field it changes, and how its value converts
## to sim units: "" as is, "ticks" seconds to ticks, "half_turns" a full width in degrees to a half width in 1/4096
## turns, "turns" degrees to 1/4096 turns, "per_tick" metres per second to metres per tick.
const MODIFIER_FIELDS := {
	&"count": [&"count", ""],
	&"spread_degrees": [&"spread", "turns"],
	&"repeat_delay_seconds": [&"repeat_delay_ticks", "ticks"],
	&"repeat_damage_permille": [&"repeat_damage_permille", ""],
	&"bounces": [&"bounces", ""],
	&"pierce": [&"pierce", ""],
	&"damage": [&"damage", ""],
	&"damage_permille": [&"damage_permille", ""],
	&"nth_every": [&"nth_every", ""],
	&"nth_damage_permille": [&"nth_damage_permille", ""],
	&"hitstop_seconds": [&"hitstop_ticks", "ticks"],
	&"arc_degrees": [&"half_arc", "half_turns"],
	&"reach_m": [&"reach_m", ""],
	&"reach_bonus_permille": [&"reach_bonus_permille", ""],
	&"radius_m": [&"radius_m", ""],
	&"speed_mps": [&"speed", "per_tick"],
	&"life_seconds": [&"life_ticks", "ticks"],
	&"period_seconds": [&"period_ticks", "ticks"],
	&"rate_bonus_permille": [&"rate_bonus_permille", ""],
}


## One modifier in sim units. Each op takes its effective stage; values convert with the item compiler's functions
## (seconds_to_ticks, degrees_to_units), so a migrated item keeps its exact numbers. MUL_PERMILLE values stay per
## mille.
static func compile_modifier(def: ModifierDefinition) -> ModifierTable:
	var t := ModifierTable.new()
	t.id = def.id
	t.family = def.family
	t.rarity = def.rarity
	t.target = def.target.duplicate()
	t.stage = int(def.stage)
	t.overlay = def.overlay
	for d: ModifierOpDefinition in def.ops:
		var o := ModifierOp.new()
		o.op = int(d.op)
		o.stage = d.stage_in(def.stage)
		o.form = int(d.form)
		o.status = d.status
		o.stacks = d.stacks
		o.every = d.every
		o.element = d.element
		o.trigger = int(d.hook_trigger)
		o.hook_tags = d.hook_tags.duplicate()
		o.radius_m = d.hook_radius_m
		o.reach_m = d.hook_reach_m
		o.damage = d.hook_damage
		o.damage_permille = d.hook_damage_permille
		o.hook_every = d.hook_every
		o.effect_id = d.hook_effect
		if d.is_numeric():
			var map: Array = MODIFIER_FIELDS[d.field]
			o.field = map[0]
			o.value = d.value
			if d.op != ModifierOpDefinition.Op.MUL_PERMILLE:
				match String(map[1]):
					"ticks":
						o.value = SimTick.seconds_to_ticks(d.value)
					"half_turns":
						o.value = ContentCompiler.degrees_to_units(d.value * 0.5)
					"turns":
						o.value = ContentCompiler.degrees_to_units(d.value)
					"per_tick":
						o.value = d.value / SimTick.TICKS_PER_SECOND
			if o.field in AttackSpec.INT_FIELDS:
				o.value = roundi(o.value)
		t.ops.append(o)
	return t


## Every modifier in a repository, compiled, in id order (the combinatorial smoke test and the views' tests use it).
static func compile_modifiers(repo: ContentRepository) -> Array[ModifierTable]:
	var out: Array[ModifierTable] = []
	for def: ModifierDefinition in repo.all_of(&"modifiers"):
		out.append(compile_modifier(def))
	return out


## v0.6.0 MX2: the ability's modifier numbers (AbilityDefinition: every_attacks, the kill streak) and its modifiers
## (AbilityDefinition.modifiers, compiled; an unknown id is a validation error and is left out here).
static func compile_ability_extras(
	t: AbilityTable, def: AbilityDefinition, repo: ContentRepository
) -> void:
	t.every_attacks = def.every_attacks
	t.streak_kills = def.streak_kills
	t.streak_ticks = SimTick.seconds_to_ticks(def.streak_seconds)
	t.modifiers = []
	if repo == null:
		return
	for id in def.modifiers:
		var md: ModifierDefinition = repo.get_def(&"modifiers", id)
		if md != null:
			t.modifiers.append(compile_modifier(md))
