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
