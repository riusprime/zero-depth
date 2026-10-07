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
			ItemTable.Kind.EMBER_EDGE:
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
	return m


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
			m.slow_permille = t.slow_permille
			m.slow_ticks = t.slow_ticks
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


func has(kind: int) -> bool:
	return (kinds_mask & (1 << kind)) != 0
