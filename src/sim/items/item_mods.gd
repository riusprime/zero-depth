class_name ItemMods
extends RefCounted
## The owned items folded into one set of modifiers (derived from World.items_owned and the item tables, so it
## is not hashed; World rebuilds it whenever an item is added). Bonuses add up; per-kind payoffs take the
## strongest owned value, so owning several items combines their effects.

var reach_bonus_permille := 0
var echo_delay_ticks := 0
var echo_damage_permille := 0
var burn_damage := 0
var burn_period_ticks := 1
var burn_duration_ticks := 0
var burn_max_stacks := 0
var split_count := 1
var split_spread := 0
var split_damage_permille := 1000
var fire_rate_bonus_permille := 0
var bounces := 0
var dash_hit_damage := 0
var overcharge_every := 0
var overcharge_mult_permille := 1000
var shockwave_radius_m := 0.0
var shockwave_damage_permille := 0
## v0.2.0 J (the second eight; see ItemTable for each field).
var heal_per_kill := 0
var heal_cap := 0
var heal_window_ticks := 0
var chain_every := 0
var chain_range_m := 0.0
var chain_damage := 0
var momentum_window_ticks := 0
var momentum_bonus_permille := 0
var slow_permille := 1000
var slow_ticks := 0
var thorn_bolts := 0
var thorn_damage := 0
var execute_threshold_permille := 0
var execute_bonus_permille := 0
var move_speed_bonus_permille := 0
var dash_cooldown_cut_permille := 0
var phase_damage := 0
var phase_radius_m := 0.0
var phase_guard_window_ticks := 0
## Bit (1 << ItemTable.Kind) per owned kind.
var kinds_mask := 0
## Engines (v0.3.0 G). Feeders: stacks added per qualifying hit by source (melee swing, landed bolt every N,
## Static Chain jump, Overcharge shockwave, a dash through), 0 = that source doesn't feed it. Engine numbers take
## the strongest owned value.
var burn_bolt := 0
var burn_bolt_every := 0
var wildfire_stacks := 0
var wildfire_radius_m := 0.0
var shock_melee := 0
var shock_bolt := 0
var shock_bolt_every := 0
var shock_chain := 0
var shock_wave := 0
var shock_threshold := 0
var shock_ticks := 0
var shock_damage := 0
var shock_jumps := 0
var shock_range_m := 0.0
var bleed_melee := 0
var bleed_bolt := 0
var bleed_bolt_every := 0
var bleed_damage := 0
var bleed_period_ticks := 1
var bleed_ticks := 0
var bleed_max_stacks := 0
var bleed_burst_per_stack := 0
var frost_melee := 0
var frost_bolt := 0
var frost_bolt_every := 0
var frost_dash := 0
var frost_threshold := 0
var frost_ticks := 0
var freeze_ticks := 0
var chill_bonus_permille := 0
var frozen_bonus_permille := 0
var charge_max := 0
var charge_bonus_permille := 0
## Overclock heat (v0.3.0 L18): Heat Sink's vent bonuses add up; Thermal Edge's Hot threshold takes the lowest owned
## (0 = none); Meltdown's blast share takes the strongest.
var vent_damage_bonus_permille := 0
var vent_radius_bonus_permille := 0
var heat_hot_threshold := 0
var meltdown_damage_permille := 0


static func build(tables: Array[ItemTable], owned: PackedInt32Array) -> ItemMods:
	var m := ItemMods.new()
	for idx in owned:
		var t := tables[idx]
		m.kinds_mask |= 1 << t.kind
		m.reach_bonus_permille += t.reach_bonus_permille
		m.fire_rate_bonus_permille += t.fire_rate_bonus_permille
		m.bounces += t.bounces
		m.dash_hit_damage += t.dash_hit_damage
		match t.kind:
			ItemTable.Kind.TWIN_ARC:
				m.echo_delay_ticks = t.echo_delay_ticks
				m.echo_damage_permille = maxi(m.echo_damage_permille, t.echo_damage_permille)
			ItemTable.Kind.EMBER_EDGE, ItemTable.Kind.CINDER_SHOT, ItemTable.Kind.WILDFIRE:
				m.burn_damage = maxi(m.burn_damage, t.burn_damage)
				m.burn_period_ticks = maxi(1, t.burn_period_ticks)
				m.burn_duration_ticks = maxi(m.burn_duration_ticks, t.burn_duration_ticks)
				m.burn_max_stacks = maxi(m.burn_max_stacks, t.burn_max_stacks)
			ItemTable.Kind.SPLINTER_SHOT:
				m.split_count = maxi(m.split_count, t.split_count)
				m.split_spread = maxi(m.split_spread, t.split_spread)
				m.split_damage_permille = t.split_damage_permille
			ItemTable.Kind.OVERCHARGE:
				m.overcharge_every = t.overcharge_every
				m.overcharge_mult_permille = t.overcharge_mult_permille
				m.shockwave_radius_m = t.shockwave_radius_m
				m.shockwave_damage_permille = t.shockwave_damage_permille
			_:
				_build_v2(m, t)
		_build_engines(m, t)
		_build_heat(m, t)
	return m


## Overclock heat items (v0.3.0 L18).
static func _build_heat(m: ItemMods, t: ItemTable) -> void:
	m.vent_damage_bonus_permille += t.vent_damage_bonus_permille
	m.vent_radius_bonus_permille += t.vent_radius_bonus_permille
	if t.heat_hot_threshold > 0:
		m.heat_hot_threshold = (
			t.heat_hot_threshold
			if m.heat_hot_threshold <= 0
			else mini(m.heat_hot_threshold, t.heat_hot_threshold)
		)
	m.meltdown_damage_permille = maxi(m.meltdown_damage_permille, t.meltdown_damage_permille)


## The second eight items (v0.2.0 J): each kind's numbers; Swift Feet's bonuses add up like the others.
static func _build_v2(m: ItemMods, t: ItemTable) -> void:
	m.move_speed_bonus_permille += t.move_speed_bonus_permille
	m.dash_cooldown_cut_permille += t.dash_cooldown_cut_permille
	match t.kind:
		ItemTable.Kind.VAMPIRIC_CORE:
			m.heal_per_kill = t.heal_per_kill
			m.heal_cap = t.heal_cap
			m.heal_window_ticks = t.heal_window_ticks
		ItemTable.Kind.STATIC_CHAIN:
			m.chain_every = t.chain_every
			m.chain_range_m = t.chain_range_m
			m.chain_damage = t.chain_damage
		ItemTable.Kind.MOMENTUM:
			m.momentum_window_ticks = t.momentum_window_ticks
			m.momentum_bonus_permille = t.momentum_bonus_permille
		ItemTable.Kind.FROST_CORE:
			m.slow_permille = mini(m.slow_permille, t.slow_permille)
			m.slow_ticks = maxi(m.slow_ticks, t.slow_ticks)
		ItemTable.Kind.THORN_MANTLE:
			m.thorn_bolts = t.thorn_bolts
			m.thorn_damage = t.thorn_damage
		ItemTable.Kind.EXECUTIONER:
			m.execute_threshold_permille = t.execute_threshold_permille
			m.execute_bonus_permille = t.execute_bonus_permille
		ItemTable.Kind.PHASE_STRIKE:
			m.phase_damage = t.phase_damage
			m.phase_radius_m = t.phase_radius_m
			m.phase_guard_window_ticks = t.phase_guard_window_ticks


## Engines (v0.3.0 G): which sources feed which status, and each engine's strongest numbers.
static func _build_engines(m: ItemMods, t: ItemTable) -> void:
	_build_fire(m, t)
	match t.kind:
		ItemTable.Kind.STATIC_CHAIN:
			m.shock_bolt = t.stacks_per_hit
			m.shock_bolt_every = t.stack_every
			m.shock_chain = t.stacks_per_hit
		ItemTable.Kind.OVERCHARGE:
			m.shock_wave = t.stacks_per_hit
		ItemTable.Kind.CONDUCTOR:
			m.shock_melee = t.stacks_per_hit
		ItemTable.Kind.SERRATED_EDGE:
			m.bleed_melee = t.stacks_per_hit
		ItemTable.Kind.BARBED_BOLTS:
			m.bleed_bolt = t.stacks_per_hit
			m.bleed_bolt_every = t.stack_every
		ItemTable.Kind.FROST_CORE:
			m.frost_bolt = t.stacks_per_hit
			m.frost_bolt_every = t.stack_every
		ItemTable.Kind.GLACIAL_EDGE:
			m.frost_melee = t.stacks_per_hit
		ItemTable.Kind.COLD_SNAP:
			m.frost_dash = t.stacks_per_hit
			m.chill_bonus_permille = t.chill_bonus_permille
			m.frozen_bonus_permille = t.frozen_bonus_permille
		ItemTable.Kind.BULWARK:
			m.charge_max = t.charge_max
			m.charge_bonus_permille = t.charge_bonus_permille
	if t.kind in [ItemTable.Kind.GLACIAL_EDGE, ItemTable.Kind.COLD_SNAP]:
		m.slow_permille = mini(m.slow_permille, t.slow_permille)
		m.slow_ticks = maxi(m.slow_ticks, t.slow_ticks)
	m.shock_threshold = maxi(m.shock_threshold, t.shock_threshold)
	m.shock_ticks = maxi(m.shock_ticks, t.shock_ticks)
	m.shock_damage = maxi(m.shock_damage, t.shock_damage)
	m.shock_jumps = maxi(m.shock_jumps, t.shock_jumps)
	m.shock_range_m = maxf(m.shock_range_m, t.shock_range_m)
	m.bleed_damage = maxi(m.bleed_damage, t.bleed_damage)
	m.bleed_period_ticks = maxi(m.bleed_period_ticks, t.bleed_period_ticks)
	m.bleed_ticks = maxi(m.bleed_ticks, t.bleed_ticks)
	m.bleed_max_stacks = maxi(m.bleed_max_stacks, t.bleed_max_stacks)
	m.bleed_burst_per_stack = maxi(m.bleed_burst_per_stack, t.bleed_burst_per_stack)
	m.frost_threshold = maxi(m.frost_threshold, t.frost_threshold)
	m.frost_ticks = maxi(m.frost_ticks, t.frost_ticks)
	m.freeze_ticks = maxi(m.freeze_ticks, t.freeze_ticks)


## Cinder Shot (bolts burn every Nth landed bolt) and Wildfire (kills spread burn).
static func _build_fire(m: ItemMods, t: ItemTable) -> void:
	if t.kind == ItemTable.Kind.CINDER_SHOT:
		m.burn_bolt = t.stacks_per_hit
		m.burn_bolt_every = t.stack_every
	elif t.kind == ItemTable.Kind.WILDFIRE:
		m.wildfire_stacks = t.stacks_per_hit
		m.wildfire_radius_m = t.spread_radius_m


## v0.4.0 AB: folds item `t`'s engine numbers only (burn, shock, frost and the chill's slow; never a feeder, kind or
## other effect) into `m`, each taking the stronger value: the engine an owned Arc Field, Frost Nova or Flame Trail
## borrows (AbilityTable.engine) when no owned item brings it.
static func fold_engine(m: ItemMods, t: ItemTable) -> void:
	if t.burn_max_stacks > 0:
		m.burn_damage = maxi(m.burn_damage, t.burn_damage)
		m.burn_period_ticks = maxi(m.burn_period_ticks, maxi(1, t.burn_period_ticks))
		m.burn_duration_ticks = maxi(m.burn_duration_ticks, t.burn_duration_ticks)
		m.burn_max_stacks = maxi(m.burn_max_stacks, t.burn_max_stacks)
	if t.slow_ticks > 0:
		m.slow_permille = mini(m.slow_permille, t.slow_permille)
		m.slow_ticks = maxi(m.slow_ticks, t.slow_ticks)
	m.shock_threshold = maxi(m.shock_threshold, t.shock_threshold)
	m.shock_ticks = maxi(m.shock_ticks, t.shock_ticks)
	m.shock_damage = maxi(m.shock_damage, t.shock_damage)
	m.shock_jumps = maxi(m.shock_jumps, t.shock_jumps)
	m.shock_range_m = maxf(m.shock_range_m, t.shock_range_m)
	m.frost_threshold = maxi(m.frost_threshold, t.frost_threshold)
	m.frost_ticks = maxi(m.frost_ticks, t.frost_ticks)
	m.freeze_ticks = maxi(m.freeze_ticks, t.freeze_ticks)


func has(kind: int) -> bool:
	return (kinds_mask & (1 << kind)) != 0
