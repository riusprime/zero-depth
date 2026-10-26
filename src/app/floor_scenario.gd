class_name FloorScenario
extends RefCounted
## The first floor (PLAN v0.2.0 F): a generated layout (FloorGenerator), the player at its start, the stone gate's
## footprint as a wall, continuous spawning over every room's spawn points (limited to the player's room and its
## neighbours by SpawnDirector).
## v0.3.0 B: a boss room off the farthest room (BossRoomBuilder, sized by `arena`), the gate inside it, and the boss
## flow (BossFlow); on a run, the floor number and the carry from the floor before (RunState.prepare).
## v0.3.0 E: the floor's free altars and shard chests on the layout's item spots (Rewards.place: one per room while
## rooms last, never in the start hall or the boss room, which has no item spots), placed after the carry so no
## card offers an item you hold. v0.2.0's item pedestals are gone: items come from an altar's or chest's pick.
## v0.3.0 L19: with a gamble table, the gamble shrine (Gamble.place, after the rewards), its plinth's footprint a
## wall. v0.8.0 N14 (owner O72): on some floors only, in a combat room away from the start hall (Gamble.site; the
## spawn points under it dropped); a floor saved before N14 (legacy_shrine) keeps it in the start hall.
## v0.5.0 RT: on a run's floor before the last, the Deep gate beside the gate (Routes.place_deep_gate; its footprint
## a wall); on a Deep floor, the extra chest and the epic altar (Routes.place_deep_rewards, after the shrine). v0.9.0
## DP (owner Q26b): its spot only; it stands once the floor's purple runes are awakened (PurpleRunes, FloorPlan).
## v0.8.0 P2 (owner O28): on a loop's last floor, the Loop device beside the Ascension portal
## (Ascension.place_loop_device; nothing solid, so the walls are unchanged).
## v0.5.5 AR: with an arena table, the sealed arenas (ArenaRooms.mark, after the Overrun room), whose item spots the
## rewards fill first.
## v0.7.5 MG: `map` (RunContentCompiler.compile_map, data/map) sets the generator's room counts and footprints (null:
## FloorParams' defaults, the same numbers); the shop stands only on the floors its table names (ShopTable.on_floor,
## owner N12: every two floors). v0.9.0 FV (owner Q24): on a run, the room range is the run's for the floor
## (FloorShape.size_floor: about 10, 13, 15, 17 and 19 rooms), written over `map`.
## v0.9.0 CF (owner: "lets never make it a 1x1"): the Overrun room and the arenas take rooms of at least their tables'
## min_cells grid cells (`overrun`: null, any room; RunSaver.floor_tables reads 0 for a floor saved before CF).
## v0.9.0 CF2 (owner: "Lockdowns get rooms first"): with `lockdown_first` (floor rules 17), the Lockdowns' rooms are
## marked right after the arenas (LockdownRooms.mark, nothing else taken yet), so the shrine, the fountain, the events,
## the curse room and the secrets take the rooms left (each keeps out of FloorLayout.lockdown_rooms); null (a floor
## saved under rules 1-16), FloorPlan.add_secrets marks them last, as before.


static func build(
	seed_value: int,
	player: PlayerTable,
	enemies: Array[EnemyTable],
	spawning: SpawnTable,
	items: Array[ItemTable],
	rewards: RewardTable = null,
	floor_index: int = 1,
	arena: BossArenaSpec = null,
	run: RunState = null,
	combos: Array[ComboTable] = [],
	gamble: GambleTable = null,
	arenas: ArenaTable = null,
	map: FloorParams = null,
	overrun: OverrunTable = null,
	lockdown_first: LockdownTable = null
) -> World:
	var params := map
	var sized := FloorShape.sized(run)  # v0.9.0 FV (Q24): the run's floor size (none in the 3-floor shape)
	if sized:
		params = FloorShape.size_floor(
			run, map if map != null else FloorParams.defaults(), floor_index
		)
	var layout := FloorGenerator.generate(seed_value, params)
	var spec := arena if arena != null else BossArenaSpec.new()
	BossRoomBuilder.attach(layout, spec)
	# v0.4.0 AB: the floor's optional Overrun room (no wall or draw changes); v0.9.0 CF: never a small room
	OverrunRooms.mark(layout, overrun.min_cells if overrun != null else 0)
	if arenas != null:  # v0.5.5 AR: the sealed arenas, before the rewards that fill them first
		ArenaRooms.mark(layout, arenas.share_permille, arenas.min_cells)
	if lockdown_first != null:  # v0.9.0 CF2: the Lockdowns next, before the shrine, events and secrets
		LockdownRooms.mark(layout, lockdown_first, floor_index, PackedInt32Array())
	var routes := Routes.offers_choice(run) and Routes.place_deep_gate(layout)  # v0.5.0 RT
	# v0.9.0 DP (owner Q26b): the Deep gate's spot is placed as before, but it stands and opens only once the floor's
	# purple runes are awakened (PurpleRunes.earn); a floor saved before DP keeps it on every floor before the last.
	var deep_now := routes and (run == null or PurpleRunes.legacy_deep_gate(run))
	if run != null and run.is_last_floor():  # v0.8.0 P2 (O28): the Loop device beside the Ascension portal
		Ascension.place_loop_device(layout)
	var w := World.new(seed_value, player, layout.start_pos)
	var walls: Array[Obb] = layout.walls.duplicate()
	walls.append(gate_collider(layout))
	if deep_now:
		walls.append(Routes.deep_gate_collider(layout))
	var legacy_shrine := legacy_shrine_of(run)  # v0.8.0 N14: an older save's floor
	var shrine := PackedVector2Array()
	if gamble != null:  # v0.3.0 L19: the shrine is solid, like the gate (its footprint is not drawn as a wall).
		shrine = Gamble.site(layout, gamble, legacy_shrine, map)
		if not shrine.is_empty():
			walls.append(Gamble.collider(shrine[0]))
	w.set_walls(walls)
	w.prepare_wall(layout.boss_door_wall)
	w.floor_layout = layout
	w.arena_table = arenas  # v0.5.5 AR
	w.set_enemy_tables(enemies)
	for pts in layout.spawn_points:
		w.spawn_points.append_array(pts)
	w.spawner = spawning
	w.set_item_tables(items)
	w.set_combo_tables(combos)  # v0.3.0 G: named combos, set before the run's carry restores the owned ones.
	w.boss_flow = BossFlow.create(spec.boss_index)
	w.boss_flow.routes = deep_now
	if rewards != null:
		w.reward_table = rewards
		if not sized:  # v0.9.0 FV: counts by room band on sized floors only (the 3-floor shape keeps v0.8.0's)
			rewards.count_rooms = PackedInt32Array()
	w.floor_index = floor_index
	if run != null:
		run.prepare(w)
	Rewards.place(w, layout)  # after the carry, so no card offers an item you hold
	if gamble != null:  # v0.3.0 L19: the gamble shrine; v0.8.0 N14: on the floors site() gives one
		w.gamble_table = gamble
		if not shrine.is_empty():
			Gamble.place(w, shrine[0])
			if not legacy_shrine:  # no enemy spawns inside its footprint
				w.spawn_points = Gamble.free_spawns(w.spawn_points, shrine[0], gamble)
	if Routes.is_deep(w):  # v0.5.0 RT (set by run.prepare)
		Routes.place_deep_rewards(w, layout, run.table.deep_extra_chests)
	return w


## v0.5.0 SH: the floor's shop (after build): ShopPlacement picks its side room and spot, the terminal's footprint
## becomes a wall (the flow fields are rebuilt with it), and Shop.place puts it on the floor. No-op without a table,
## and (v0.7.5 MG, owner N12) on a floor the table skips (ShopTable.on_floor: floors 1, 3, 5 ... as shipped). On a
## floor without a shop, the room ShopPlacement would take stays an ordinary room (never an arena: ArenaRooms and
## Routes keep it out either way, so the floor's other choices don't move).
## v0.8.0 SR (owner O13): with a shop room for the floor's biome (ShopTable.room_for; none on a floor saved before SR),
## the room ShopPlacement picked is furnished as the biome's tent stall (ShopRoom.furnish, `map` its generator rules:
## null, FloorParams' defaults): its old interior goes, the dressing joins the layout's walls, the stall's footprints
## are walls the dresser never draws, and the shop's spot is the counter. When no stall fits, the terminal stands as
## before.
static func add_shop(
	w: World, shop: ShopTable, biome: StringName = &"", map: FloorParams = null
) -> void:
	var layout := w.floor_layout
	if shop == null or layout == null or not shop.on_floor(w.run_floor_index()):  # AP: across loops
		return
	if ShopPlacement.pick(layout) < 0:
		return
	var extra: Array[Obb] = w.walls.slice(layout.walls.size())  # the gate, the Deep gate, the shrine
	var room := layout.shop_room
	var p := map if map != null else FloorParams.defaults()
	var walls: Array[Obb] = []
	if ShopRoom.furnish(layout, p, room, shop.room_for(biome)):
		walls = layout.walls.duplicate()
		walls.append_array(extra)
		walls.append_array(layout.shop_solids)
		var spawns := PackedVector2Array()
		for q in w.spawn_points:
			if layout.room_of(q) != room or layout.spawn_points[room].has(q):
				spawns.append(q)
		w.spawn_points = spawns
	else:
		walls = w.walls.duplicate()
		walls.append(ShopPlacement.collider(layout.shop_pos, layout.shop_angle))
	w.set_walls(walls)
	w.prepare_wall(layout.boss_door_wall)
	w.shop_table = shop
	Shop.place(w, layout)


## v0.8.0 N14 (O72): whether run `run`'s current floor keeps its shrine in the start hall (a floor resumed from a save
## made before N14, floor rules 1-5); false for today's floors and for a floor built without a run.
static func legacy_shrine_of(run: RunState) -> bool:
	return run != null and run.floor_rules <= RunState.FLOOR_RULES_V080_SR


## v0.8.0 N17 (O75): whether run `run`'s current floor keeps its event rooms as they were before the curse room (a
## floor resumed from a save made before N17, floor rules 1-6); false for today's floors and a floor without a run.
static func legacy_curse_room_of(run: RunState) -> bool:
	return run != null and run.floor_rules <= RunState.FLOOR_RULES_V080_N14


## v0.9.0 EL (owner Q25): whether run `run`'s current floor was saved before EL (floor rules 1-14): its event draw
## keeps the retired Ambush Cache's weight (EventCompiler.setup's `legacy`); false for today's floors and no run.
static func retired_events_of(run: RunState) -> bool:
	return run != null and run.floor_rules <= RunState.FLOOR_RULES_V090_SH


## v0.9.5 AQ: whether run `run`'s current floor draws rare event rooms (floor rules 18+); false for a floor saved under
## rules 1-17 (1-2 event rooms, repeats allowed). True for no run.
static func rare_events_of(run: RunState) -> bool:
	return run == null or run.floor_rules > RunState.FLOOR_RULES_V090_CF2


## v0.8.0 N19 (O80): the curse-room rules run `run`'s current floor was built under (Events.CURSE_RULES_*): before
## N17 for floor rules 1-6, N17's for 7 (a combat room keeping its interior), today's for a new floor or no run.
static func curse_room_rules_of(run: RunState) -> int:
	if legacy_curse_room_of(run):
		return Events.CURSE_RULES_BEFORE_N17
	if run != null and run.floor_rules == RunState.FLOOR_RULES_V080_N17:
		return Events.CURSE_RULES_N17
	return Events.CURSE_RULES_N19


## Item spot indices in fill order: each room's first spot (in room order), then the second spots.
static func spot_order(layout: FloorLayout) -> PackedInt32Array:
	return Rewards.spot_order(layout)


## The gate's stone footprint: as deep as the gate, as wide as its pillars, so you can't walk through it.
static func gate_collider(layout: FloorLayout) -> Obb:
	var half := Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5 + 0.35)
	return Obb.make(layout.portal_pos, half, layout.portal_angle)
