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
	# v0.6.0 MX4 (AttackSpec names each; "turn_rate" degrees per second to 1/4096 turns per tick; "range" is the
	# virtual field Modifiers scales per form).
	&"mirror": [&"mirror", ""],
	&"directions": [&"directions", ""],
	&"back_damage_permille": [&"back_permille", ""],
	&"aim_offset_degrees": [&"aim_offset", "turns"],
	&"chains": [&"chains", ""],
	&"homing_dps": [&"homing", "turn_rate"],
	&"returns": [&"returns", ""],
	&"orbit_seconds": [&"orbit_ticks", "ticks"],
	&"intangible": [&"intangible", ""],
	&"pull_m": [&"pull_m", ""],
	&"barrier_seconds": [&"barrier_ticks", "ticks"],
	&"charge_seconds": [&"charge_ticks", "ticks"],
	&"charge_permille": [&"charge_permille", ""],
	&"resonance_permille": [&"resonance_permille", ""],
	&"heat_rate_permille": [&"heat_rate_permille", ""],
	&"range": [&"range", ""],
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
		t.ops.append(compile_op(d, d.stage_in(def.stage)))
	return t


## One op in sim units, at `stage` (v0.6.0 MX4: a hook's child ops, its delay and its condition too).
static func compile_op(d: ModifierOpDefinition, stage: int) -> ModifierOp:
	var o := ModifierOp.new()
	o.op = int(d.op)
	o.stage = stage
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
	o.delay_ticks = SimTick.seconds_to_ticks(d.hook_delay_seconds)  # v0.6.0 MX4
	o.when = int(d.hook_when)
	for c: ModifierOpDefinition in d.hook_ops:
		if c != null:
			o.child_ops.append(compile_op(c, c.stage_in(stage)))
	if d.is_numeric() and MODIFIER_FIELDS.has(d.field):
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
				"turn_rate":
					o.value = (
						ContentCompiler.degrees_to_units(d.value) / float(SimTick.TICKS_PER_SECOND)
					)
		if o.field in AttackSpec.INT_FIELDS:
			o.value = roundi(o.value)
	return o


## v0.6.0 MX4: the item definitions in item index order: the items of kinds before MODIFIER in id order (v0.5's
## order, which saves name by index), then the modifier cards (ItemDefinition.Kind.MODIFIER) in id order.
static func item_defs(repo: ContentRepository) -> Array:
	var old := []
	var cards := []
	for def: ItemDefinition in repo.all_of(&"items"):
		(cards if def.kind == ItemDefinition.Kind.MODIFIER else old).append(def)
	return old + cards


## v0.6.0 MX4: an item's numbers past the v0.5 ones: Venom Core's poison engine; a modifier card tagged heat needs a
## run with heat (Heat Sink Rounds, Meltdown Edge), as the v0.5 heat items do.
static func compile_item_extras(def: ItemDefinition, t: ItemTable) -> void:
	if def.kind == ItemDefinition.Kind.MODIFIER and def.tags.has("heat"):
		t.requires_heat = true
	t.poison_damage = def.poison_damage
	t.poison_period_ticks = maxi(1, SimTick.seconds_to_ticks(def.poison_period_seconds))
	t.poison_ticks = SimTick.seconds_to_ticks(def.poison_seconds)
	t.poison_max_stacks = def.poison_max_stacks
	t.poison_spread_m = def.poison_spread_m


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
