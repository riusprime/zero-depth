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
	t.first_wave_ticks = SimTick.seconds_to_ticks(def.first_wave_seconds)
	t.wave_gap_ticks = SimTick.seconds_to_ticks(def.wave_gap_seconds)
	t.min_spawn_distance_m = def.min_spawn_distance
	return t


## v0.9.0 LK (owner Q21): the Lockdowns' numbers (null without a definition: no Lockdowns).
static func compile_lockdown(def: LockdownDefinition) -> LockdownTable:
	if def == null:
		return null
	var t := LockdownTable.new()
	t.rooms_min = def.rooms_min
	t.rooms_max = def.rooms_max
	t.kind_weights = def.kind_weights.duplicate()
	t.kind_floor_min = def.kind_floor_min.duplicate()
	t.waves = def.waves
	t.wave_sizes = def.wave_sizes.duplicate()
	t.first_wave_ticks = SimTick.seconds_to_ticks(def.first_wave_seconds)
	t.wave_gap_ticks = SimTick.seconds_to_ticks(def.wave_gap_seconds)
	t.stuck_ticks = maxi(1, SimTick.seconds_to_ticks(def.stuck_seconds))
	t.cap_ticks = maxi(1, SimTick.seconds_to_ticks(def.cap_seconds))
	t.hazard_every_ticks = maxi(1, SimTick.seconds_to_ticks(def.hazard_every_seconds))
	t.hazard_warn_ticks = SimTick.seconds_to_ticks(def.hazard_warn_seconds)
	t.hazard_radius_m = def.hazard_radius
	t.hazard_damage = def.hazard_damage
	return t


## v0.9.0 RB (AFFINITIES.md): the run's rune affinity, its offer bias resolved against the compiled `items` (one per
## mille per item index). Null for None (or no definition): the run builds no affinity state.
static func compile_affinity(def: AffinityDefinition, items: Array[ItemTable]) -> AffinityTable:
	if def == null or def.is_none():
		return null
	var t := AffinityTable.new()
	t.id = def.id
	t.burn_duration_permille = def.burn_duration_permille
	t.dash_shock_radius_m = def.dash_shock_radius_m
	t.dash_shock_stacks = def.dash_shock_stacks
	t.poison_jump_m = def.poison_jump_m
	t.secret_sense_m = def.secret_sense_m
	t.map_secrets = def.map_secrets
	t.ward_charges = def.ward_charges
	t.shard_permille = def.shard_permille
	t.card_permille.resize(items.size())
	for i in items.size():
		var p := 1000
		if def.favoured_cards.has(items[i].id):
			p = def.favoured_permille
		elif def.disfavoured_cards.has(items[i].id):
			p = def.disfavoured_permille
		t.card_permille[i] = p
	return t


## v0.9.0 SH, HF (owner Q29b, W36): the shrines' and the fountain's numbers (null without a definition: every shrine
## stays a Fortune shrine and no floor has a fountain).
static func compile_shrines(def: ShrineDefinition) -> ShrineTable:
	if def == null:
		return null
	var t := ShrineTable.new()
	t.kind_weights = def.kind_weights.duplicate()
	t.kind_floor_min = def.kind_floor_min.duplicate()
	t.blood_cost_permille = def.blood_cost_permille
	t.blood_min_permille = def.blood_min_permille
	t.blood_altars = def.blood_altars
	t.chaos_sizes = def.chaos_sizes.duplicate()
	t.chaos_elite_permille = def.chaos_elite_permille
	t.chaos_altars = def.chaos_altars
	t.fountain_permille = def.fountain_permille
	t.fountain_floor_min = def.fountain_floor_min
	t.fountain_heal_permille = def.fountain_heal_permille
	t.reach_m = def.reach
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
	t.upgrade = def.upgrade_choice  # v0.8.0 FL (the v0.6.5 WN5b wand_level is retired)
	for c in def.card_categories:
		var k := ItemDefinition.LOOT_CATEGORIES.find(c)
		if k > 0:
			t.card_categories.append(k)
	t.card_permille = int(round(def.legendary_chance * 1000.0))  # v0.8.0 RR
	t.card_loop_permille = int(round(def.legendary_chance_per_loop * 1000.0))
	t.extra_picks_per_loop = def.extra_picks_per_loop
	t.extra_picks_max = def.extra_picks_max
	return t


## v0.8.0 FL (owner O91): the floor-paced loot table (LootPacingDefinition); null without a definition (no pacing).
static func compile_loot_pacing(def: LootPacingDefinition) -> LootPacingTable:
	if def == null:
		return null
	var t := LootPacingTable.new()
	var rows: Array[PackedInt32Array] = []
	for row in def.weight_rows():
		rows.append(row.duplicate())
	t.weights = rows
	t.ceilings = def.level_ceilings.duplicate()
	t.guaranteed_altars = def.guaranteed_altars.duplicate()
	t.jackpot_permille = def.jackpot_permille
	return t


## The sim's designer numbers (docs/tools/DEV_PANEL.md Step 6): seconds to ticks; null (no file) keeps the shipped
## SimTuning.
static func compile_sim_tuning(def: SimTuningDefinition) -> SimTuning:
	var t := SimTuning.new()
	if def == null:
		return t
	t.spawn_in_ticks = SimTick.seconds_to_ticks(def.spawn_in_seconds)
	t.boss_intro_ticks = SimTick.seconds_to_ticks(def.boss_intro_seconds)
	t.boss_after_stagger_cd = SimTick.seconds_to_ticks(def.boss_after_stagger_seconds)
	t.gate_ticks = SimTick.seconds_to_ticks(def.gate_seconds)
	t.gate_adds_min = def.gate_adds_min
	t.gate_adds_max = def.gate_adds_max
	t.gate_add_ring_m = def.gate_add_ring_m
	t.ai_commit_ticks = SimTick.seconds_to_ticks(def.ai_commit_seconds)
	t.ai_snipe_commit_ticks = SimTick.seconds_to_ticks(def.ai_snipe_commit_seconds)
	t.ai_strafe_permille = def.ai_strafe_permille
	t.ai_flank_permille = def.ai_flank_permille
	t.ai_flank_min_m = def.ai_flank_min_m
	t.ai_flank_range_m = def.ai_flank_range_m
	t.ai_spread_radius_m = def.ai_spread_radius_m
	t.ai_spread_weight = def.ai_spread_weight
	t.ai_relocate_speed_permille = def.ai_relocate_speed_permille
	t.ai_relocate_max_ticks = SimTick.seconds_to_ticks(def.ai_relocate_max_seconds)
	t.ai_mend_scan_ticks = maxi(1, SimTick.seconds_to_ticks(def.ai_mend_scan_seconds))
	t.heal_orbs_max = def.heal_orbs_max
	t.pickup_radius_m = def.pickup_radius_m
	t.fire_cap = def.fire_cap
	t.fire_hit_ticks = maxi(1, SimTick.seconds_to_ticks(def.fire_hit_seconds))
	t.fire_trail_spacing_m = def.fire_trail_spacing_m
	t.field_min_m = def.field_min_m
	t.player_shots_max = def.player_shots_max  # v0.8.0 PF
	t.arrival_first_ticks = SimTick.seconds_to_ticks(def.arrival_first_seconds)  # v0.8.0 N11
	t.arrival_ticks = SimTick.seconds_to_ticks(def.arrival_seconds)
	t.arrival_calm_ticks = SimTick.seconds_to_ticks(def.arrival_calm_seconds)
	t.attack_speed_knee_permille = def.attack_speed_knee_permille  # v0.8.0 SG
	t.attack_speed_knee2_permille = def.attack_speed_knee2_permille
	t.attack_speed_slope_permille = def.attack_speed_slope_permille
	t.attack_speed_slope2_permille = def.attack_speed_slope2_permille
	return t


## v0.8.0 RT (owner O12): the designed room layouts (data/room_layouts), RoomLayouts.key(cells) -> Array of
## RoomLayoutTable in id order: centimetres, anchors per mille, yaws in 1/4096 turns.
static func compile_room_layouts(repo: ContentRepository) -> Dictionary:
	var out := {}
	if repo == null:
		return out
	for def: RoomLayoutDefinition in repo.all_of(&"room_layout"):
		var t := compile_room_layout(def)
		var k := RoomLayouts.key(t.cells)
		if not out.has(k):
			out[k] = []
		(out[k] as Array).append(t)
	return out


static func compile_room_layout(def: RoomLayoutDefinition) -> RoomLayoutTable:
	var t := RoomLayoutTable.new()
	t.id = def.id
	t.cells = def.cells
	t.weight = def.weight
	for g in def.groups:
		var cg := RoomLayoutGroupTable.new()
		cg.anchor = Vector2i(roundi(g.anchor.x * 1000.0), roundi(g.anchor.y * 1000.0))
		for p in g.pieces:
			var cp := RoomLayoutPieceTable.new()
			cp.piece = p.piece
			cp.at = Vector2i(roundi(p.at.x * 100.0), roundi(p.at.y * 100.0))
			cp.size = Vector2i(roundi(p.size.x * 100.0), roundi(p.size.y * 100.0))
			cp.angle = posmod(roundi(p.yaw * 4096.0 / 360.0), 4096)
			cp.height = roundi(p.height * 100.0)
			cp.solid = p.solid
			cg.pieces.append(cp)
		t.groups.append(cg)
	t.keep_clear = def.keep_clear.duplicate()
	return t


## v0.8.0 SR (owner O13): the biomes' shop rooms (data/shop_rooms), biome id -> ShopRoomTable: the stall and the
## dressing groups in centimetres and per mille, as compile_room_layout.
static func compile_shop_rooms(repo: ContentRepository) -> Dictionary:
	var out := {}
	if repo == null:
		return out
	for def: ShopRoomDefinition in repo.all_of(&"shop_room"):
		var t := ShopRoomTable.new()
		t.id = def.id
		t.biome = def.biome
		t.stall = _layout_group(def.stall)
		for q in def.stall_spots:
			t.stall_spots.append(Vector2i(roundi(q.x * 1000.0), roundi(q.y * 1000.0)))
		t.approach = Vector2i(roundi(def.approach.x * 100.0), roundi(def.approach.y * 100.0))
		t.layout = RoomLayoutTable.new()
		t.layout.id = def.id
		for g in def.groups:
			t.layout.groups.append(_layout_group(g))
		out[def.biome] = t
	return out


static func _layout_group(g: RoomLayoutGroup) -> RoomLayoutGroupTable:
	var cg := RoomLayoutGroupTable.new()
	if g == null:
		return cg
	cg.anchor = Vector2i(roundi(g.anchor.x * 1000.0), roundi(g.anchor.y * 1000.0))
	for p in g.pieces:
		var cp := RoomLayoutPieceTable.new()
		cp.piece = p.piece
		cp.at = Vector2i(roundi(p.at.x * 100.0), roundi(p.at.y * 100.0))
		cp.size = Vector2i(roundi(p.size.x * 100.0), roundi(p.size.y * 100.0))
		cp.angle = posmod(roundi(p.yaw * 4096.0 / 360.0), 4096)
		cp.height = roundi(p.height * 100.0)
		cp.solid = p.solid
		cg.pieces.append(cp)
	return cg


## v0.7.5 MG (owner N9): the generator's room counts, footprints and span from data/map over FloorParams' defaults
## (null: the defaults, which equal the shipped file).
static func compile_map(def: MapDefinition) -> FloorParams:
	var p := FloorParams.defaults()
	if def == null:
		return p
	p.rooms_min = def.rooms_min
	p.rooms_max = def.rooms_max
	var feet: Array[Vector2i] = []
	for k in def.footprint_weights.size():
		feet.append(Vector2i(def.footprint_x[k], def.footprint_y[k]))
	p.footprints = feet
	p.footprint_weights = def.footprint_weights.duplicate()
	p.max_span = def.max_span
	p.place_attempts = def.place_attempts
	p.timed_door_permille = def.timed_door_permille  # v0.9.0 TD
	p.timed_door_ticks = def.timed_door_ticks
	return p


## v0.9.0 FV (owner Q24): the run's id, its floors' room ranges and its wand slots onto `t`
## (ContentCompiler.compile_run).
static func add_run_shape(t: RunTable, def: RunDefinition) -> RunTable:
	t.id = def.id
	t.rooms_min_by_floor = def.rooms_min_by_floor.duplicate()
	t.rooms_max_by_floor = def.rooms_max_by_floor.duplicate()
	t.wand_slots_per_floor = def.wand_slots_per_floor.duplicate()
	return t


## v0.9.0 FV (owner Q24, "Scale with floor size"): the altar and chest counts by the floor's rooms onto `t`
## (ContentCompiler.compile_rewards).
static func add_reward_bands(t: RewardTable, def: RewardsDefinition) -> RewardTable:
	t.count_rooms = def.count_rooms.duplicate()
	t.band_counts.clear()
	for k in def.count_rooms.size():
		(
			t
			. band_counts
			. append(
				PackedInt32Array(
					[
						def.altars_min_by_rooms[k],
						def.altars_max_by_rooms[k],
						def.chests_min_by_rooms[k],
						def.chests_max_by_rooms[k],
					]
				)
			)
		)
	return t


## v0.9.0 FV: every floor's boss pool (indices into ContentCompiler.compile_bosses), entry f − 1, for floors 1 to
## `floors` (at least as many as the pools name): an empty entry for a floor without a pool (FloorShape.boss draws
## it from the bosses not yet met).
static func compile_boss_pools(repo: ContentRepository, floors: int) -> Array[PackedInt32Array]:
	var n := floors
	for pool: BossPoolDefinition in repo.all_of(&"boss_pools"):
		n = maxi(n, pool.floor_index)
	var out: Array[PackedInt32Array] = []
	for f in range(1, n + 1):
		out.append(ContentCompiler.compile_boss_pool(repo, f))
	return out
