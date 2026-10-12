class_name RunContentCompiler
extends RefCounted
## The v0.5.5 run-shape compilers (sealed arenas, the legendary tier, the hidden catch-up), split from
## ContentCompiler to keep it under the lint's file-length limit. Same rules: definitions in, sim tables out.


## v0.5.5 AR: the sealed arenas (null without a definition: no regular arenas).
static func compile_arena(def: ArenaDefinition) -> ArenaTable:
	if def == null:
		return null
	var t := ArenaTable.new()
	t.share_permille = int(round(def.share * 1000.0))
	t.waves_min = def.waves_min
	t.waves_max = def.waves_max
	t.wave_sizes = def.wave_sizes.duplicate()
	t.first_wave_ticks = int(round(def.first_wave_seconds * SimTick.TICKS_PER_SECOND))
	t.wave_gap_ticks = int(round(def.wave_gap_seconds * SimTick.TICKS_PER_SECOND))
	t.min_spawn_distance_m = def.min_spawn_distance
	return t


## v0.5.5 AR (X1b): the boss-only legendary tier, its ids resolved against the compiled stat cards and items.
static func compile_legendary(
	def: LegendaryDefinition, stats: Array[StatTable], items: Array[ItemTable]
) -> LegendaryTable:
	if def == null:
		return null
	var t := LegendaryTable.new()
	for id in def.stat_cards:
		for s in stats.size():
			if stats[s] != null and stats[s].id == id:
				t.stats.append(s)
	for id in def.mods:
		for k in items.size():
			if items[k].id == id:
				t.mods.append(k)
	t.weights = PackedInt32Array([def.stat_weight, def.mod_weight])
	t.offer_size = def.offer_size
	t.stat_permille = int(round(def.stat_multiplier * 1000.0))
	return t


## The sim's designer numbers (docs/tools/DEV_PANEL.md Step 6): seconds to ticks; null (no file) keeps the shipped
## SimTuning.
static func compile_sim_tuning(def: SimTuningDefinition) -> SimTuning:
	var t := SimTuning.new()
	if def == null:
		return t
	t.spawn_in_ticks = _ticks(def.spawn_in_seconds)
	t.boss_intro_ticks = _ticks(def.boss_intro_seconds)
	t.boss_after_stagger_cd = _ticks(def.boss_after_stagger_seconds)
	t.gate_ticks = _ticks(def.gate_seconds)
	t.gate_adds_min = def.gate_adds_min
	t.gate_adds_max = def.gate_adds_max
	t.gate_add_ring_m = def.gate_add_ring_m
	t.ai_commit_ticks = _ticks(def.ai_commit_seconds)
	t.ai_snipe_commit_ticks = _ticks(def.ai_snipe_commit_seconds)
	t.ai_strafe_permille = def.ai_strafe_permille
	t.ai_flank_permille = def.ai_flank_permille
	t.ai_flank_min_m = def.ai_flank_min_m
	t.ai_flank_range_m = def.ai_flank_range_m
	t.ai_spread_radius_m = def.ai_spread_radius_m
	t.ai_spread_weight = def.ai_spread_weight
	t.ai_relocate_speed_permille = def.ai_relocate_speed_permille
	t.ai_relocate_max_ticks = _ticks(def.ai_relocate_max_seconds)
	t.ai_mend_scan_ticks = maxi(1, _ticks(def.ai_mend_scan_seconds))
	t.heal_orbs_max = def.heal_orbs_max
	t.pickup_radius_m = def.pickup_radius_m
	t.fire_cap = def.fire_cap
	t.fire_hit_ticks = maxi(1, _ticks(def.fire_hit_seconds))
	t.fire_trail_spacing_m = def.fire_trail_spacing_m
	t.field_min_m = def.field_min_m
	return t


static func _ticks(seconds: float) -> int:
	return int(round(seconds * SimTick.TICKS_PER_SECOND))
