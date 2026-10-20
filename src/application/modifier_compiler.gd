class_name ModifierCompiler
extends RefCounted
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md; CONTENT_SCHEMA "Modifiers"): ModifierDefinition → ModifierTable in sim
## units. ContentCompiler.compile_item compiles an item's modifiers with it.

## v0.6.5 WN3/WN4: the wand pools in the order they shipped (ItemDefinition.requires_weapon): their cards take item
## indices pool by pool, so a later pool never moves an earlier one's indices. A new pool appends its weapon here.
const WAND_POOL_ORDER: Array[StringName] = [&"gun", &"blade", &""]


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
	t.order_kind = int(def.order_kind)  # v0.8.0 AO
	t.alt_target = def.alt_target.duplicate()  # v0.8.0 MR
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
	o.trigger_gun = d.hook_trigger_gun  # v0.6.5 WN1
	o.casts = d.hook_casts  # v0.6.5 WN5b
	o.per_level_after = d.per_level_after  # v0.8.0 BL (B2)
	o.alt = d.alt  # v0.8.0 MR
	for r: Resource in d.hook_ops:
		var c := r as ModifierOpDefinition
		if c != null:
			o.child_ops.append(compile_op(c, c.stage_in(stage)))
	if d.op == ModifierOpDefinition.Op.HOOK:
		o.per_level = d.per_level  # v0.6.5 WN3: per mille of the hook's damage share
	if d.is_numeric() and ModifierOpDefinition.FIELD_STAGE.has(d.field):
		var map: Array = ModifierOpDefinition.FIELD_STAGE[d.field]  # [stage, sim field, unit]
		o.field = map[1]
		o.value = _units(d, map, d.value)
		if d.per_level != 0.0:  # v0.6.5 WN3: the step per level, in the same units
			o.per_level = _units(d, map, d.value + d.per_level) - o.value
			if d.op == ModifierOpDefinition.Op.MUL_PERMILLE:
				o.per_level = d.per_level  # v0.8.0 BL: per mille as is (Flurry's 250 / 3), rounded per level
			elif String(map[2]) == "" and AttackSpec.is_int_field(map[1]):
				o.per_level = d.per_level  # v0.8.0 MR: a whole field's step as is, rounded per level (Flurry's ½)
	return o


## A numeric op's content value `v` in sim units (its field's conversion; MUL_PERMILLE stays per mille; an int
## field rounded once).
static func _units(d: ModifierOpDefinition, map: Array, v: float) -> float:
	var out := v
	if d.op != ModifierOpDefinition.Op.MUL_PERMILLE:
		match String(map[2]):
			"ticks":
				out = SimTick.seconds_to_ticks(v)
			"half_turns":
				out = ContentCompiler.degrees_to_units(v * 0.5)
			"turns":
				out = ContentCompiler.degrees_to_units(v)
			"per_tick":
				out = v / SimTick.TICKS_PER_SECOND
			"turn_rate":
				out = ContentCompiler.degrees_to_units(v) / float(SimTick.TICKS_PER_SECOND)
	if AttackSpec.is_int_field(map[1]):
		out = roundi(out)
	return out


## v0.6.0 MX4: the item definitions in item index order: the items of kinds before MODIFIER in id order (v0.5's
## order, which saves name by index), then the modifier cards (ItemDefinition.Kind.MODIFIER) in id order; v0.6.5 WN1:
## then the wand's trigger cards (Kind.TRIGGER) in id order; v0.6.5 WN3/WN4: then the wand's pool cards (Kind.WAND),
## pool by pool in WAND_POOL_ORDER (the Gun's G cards, then the Blade's B cards), each in id order, so every earlier
## index still names the same card. v0.6.5 WN5b: the legendary trigger cards (Kind.TRIGGER, rarity LEGENDARY) last.
## v0.8.0 BL: then the cards of each later index wave (ItemDefinition.index_wave 1, 2, ...), wave by wave, each in id
## order, whatever their kind or pool: a card added to a pool later never moves an index a save holds.
static func item_defs(repo: ContentRepository) -> Array:
	var waves := {}
	for def: ItemDefinition in repo.all_of(&"items"):
		if def.index_wave > 0:
			if not waves.has(def.index_wave):
				waves[def.index_wave] = []
			waves[def.index_wave].append(def)
	var late := []
	var keys := waves.keys()
	keys.sort()
	for k: int in keys:
		late += waves[k]
	return _wave_zero(repo) + late


## The cards of index wave 0 (every card before v0.8.0) in their order (item_defs).
static func _wave_zero(repo: ContentRepository) -> Array:
	var old := []
	var cards := []
	var triggers := []
	var legend := []  # v0.6.5 WN5b: the legendary triggers, after every pool (no earlier index moves)
	var pools := []
	for _p in WAND_POOL_ORDER:
		pools.append([])
	for def: ItemDefinition in repo.all_of(&"items"):
		if def.index_wave > 0:
			continue  # v0.8.0 BL: a later wave's card (item_defs)
		match def.kind:
			ItemDefinition.Kind.MODIFIER:
				cards.append(def)
			ItemDefinition.Kind.TRIGGER:
				if def.rarity == ItemDefinition.Rarity.LEGENDARY:
					legend.append(def)
				else:
					triggers.append(def)
			ItemDefinition.Kind.WAND:
				pools[WAND_POOL_ORDER.find(def.requires_weapon)].append(def)  # validated: "", blade, gun
			_:
				old.append(def)
	var out := old + cards + triggers
	for p: Array in pools:
		out += p
	return out + legend


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
	t.bleed_move_period_ticks = SimTick.seconds_to_ticks(def.bleed_move_period_seconds)  # v0.6.5 WN5a
	t.name_key_gun = def.name_key_gun
	t.desc_key_gun = def.desc_key_gun


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
