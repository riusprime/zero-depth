class_name FloorScenario
extends RefCounted
## The first floor (PLAN v0.2.0 F): a generated layout (FloorGenerator), the player at its start, the stone gate's
## footprint as a wall, continuous spawning over every room's spawn points (limited to the player's room and its
## neighbours by SpawnDirector).
## A boss room off the farthest room (BossRoomBuilder, sized by `arena`), the gate inside it, and the boss
## flow (BossFlow); on a run, the floor number and the carry from the floor before (RunState.prepare).
## The floor's free altars and shard chests on the layout's item spots (Rewards.place: one per room while
## rooms last, never in the start hall or the boss room, which has no item spots), placed after the carry so no
## card offers an item you hold. v0.2.0's item pedestals are gone: items come from an altar's or chest's pick.
## With a gamble table, the gamble shrine (Gamble.place, after the rewards), its plinth's footprint a
## wall. on some floors only, in a combat room away from the start hall (Gamble.site; the
## spawn points under it dropped).
## On a run's floor before the last, the Deep gate's spot beside the gate (Routes.place_deep_gate); it stands once the
## floor's purple runes are awakened (PurpleRunes, FloorPlan). On a Deep floor, the extra chest and the epic altar
## (Routes.place_deep_rewards, after the shrine).
## On a loop's last floor, the Loop device beside the Ascension portal
## (Ascension.place_loop_device; nothing solid, so the walls are unchanged).
## With an arena table, the sealed arenas (ArenaRooms.mark, after the Overrun room), whose item spots the
## rewards fill first.
## `map` (RunContentCompiler.compile_map, data/map) sets the generator's room counts and footprints (null:
## FloorParams' defaults, the same numbers); the shop stands only on the floors its table names (ShopTable.on_floor,
## owner N12: every two floors). on a run, the room range is the run's for the floor
## (FloorShape.size_floor: about 10, 13, 15, 17 and 19 rooms), written over `map`.
## The Overrun room and the arenas take rooms of at least their tables'
## min_cells grid cells (`overrun`: null, any room).
## With `lockdown_first`, the Lockdowns' rooms are
## marked right after the arenas (LockdownRooms.mark, nothing else taken yet), so the shrine, the fountain, the events,
## the curse room and the secrets take the rooms left (each keeps out of FloorLayout.lockdown_rooms); null (a world
## built without a run), none.
## With `defer_nav` (FloorPlan), the world's flow fields wait for World.build_nav, which the caller runs
## once the floor is laid out (the shop, the purposes, the curse room and the fountain each set the walls again).


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
	lockdown_first: LockdownTable = null,
	defer_nav: bool = false
) -> World:
	var params := map
	var sized := FloorShape.sized(run)  # The run's floor size (none in the 3-floor shape)
	if sized:
		params = FloorShape.size_floor(
			run, map if map != null else FloorParams.defaults(), floor_index
		)
	var layout := FloorGenerator.generate(seed_value, params)
	var spec := arena if arena != null else BossArenaSpec.new()
	BossRoomBuilder.attach(layout, spec)
	# The floor's optional Overrun room (no wall or draw changes); never a small room
	OverrunRooms.mark(layout, overrun.min_cells if overrun != null else 0)
	if arenas != null:  # The sealed arenas, before the rewards that fill them first
		ArenaRooms.mark(layout, arenas.share_permille, arenas.min_cells)
	if lockdown_first != null:  # The Lockdowns next, before the shrine, events and secrets
		LockdownRooms.mark(layout, lockdown_first, floor_index, PackedInt32Array())
	# The Deep gate's spot; it stands and opens only once the floor's purple runes are awakened (PurpleRunes.earn)
	if Routes.offers_choice(run):
		Routes.place_deep_gate(layout)
	if run != null and run.is_last_floor():  # The Loop device beside the Ascension portal
		Ascension.place_loop_device(layout)
	var w := World.new(seed_value, player, layout.start_pos)
	if defer_nav:  # Built once the floor is laid out (World.build_nav)
		w.defer_nav()
	w.solids.on = Solids.rules_on(run)  # The props that look solid are solid
	if layout.has_loop_device:  # the Loop device is one of them (Ascension.touching_loop_device enters it)
		var loop := Ascension.loop_footprint(layout)
		w.solids.add(Solids.Kind.LOOP_DEVICE, 0, loop.center, loop.half, loop.angle)
	var walls: Array[Obb] = layout.walls.duplicate()
	walls.append(gate_collider(layout))
	var shrine := PackedVector2Array()
	if gamble != null:  # The shrine is solid, like the gate (its footprint is not drawn as a wall).
		shrine = Gamble.site(layout, gamble, map)
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
	w.set_combo_tables(combos)  # Named combos, set before the run's carry restores the owned ones.
	w.boss_flow = BossFlow.create(spec.boss_index)
	if rewards != null:
		w.reward_table = rewards
		if not sized:  # Counts by room band on sized floors only (the 3-floor shape keeps v0.8.0's)
			rewards.count_rooms = PackedInt32Array()
	w.floor_index = floor_index
	if run != null:
		run.prepare(w)
	Rewards.place(w, layout)  # after the carry, so no card offers an item you hold
	if gamble != null:  # The gamble shrine; on the floors site() gives one
		w.gamble_table = gamble
		if not shrine.is_empty():
			Gamble.place(w, shrine[0])
			w.spawn_points = Gamble.free_spawns(w.spawn_points, shrine[0], gamble)  # none inside it
	if Routes.is_deep(w):  # v0.5.0 RT (set by run.prepare)
		Routes.place_deep_rewards(w, layout, run.table.deep_extra_chests)
	return w


## The floor's shop (after build): ShopPlacement picks its side room and spot, the terminal's footprint
## becomes a wall (the flow fields are rebuilt with it), and Shop.place puts it on the floor. No-op without a table,
## and on a floor the table skips (ShopTable.on_floor: floors 1, 3, 5... as shipped). On a
## floor without a shop, the room ShopPlacement would take stays an ordinary room (never an arena: ArenaRooms and
## Routes keep it out either way, so the floor's other choices don't move).
## With a shop room for the floor's biome (ShopTable.room_for),
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


## PLAN P1: the large rooms' purposes (after add_shop; RoomPurposes.lay, `map` the generator rules:
## null, FloorParams' defaults): a share of the large combat rooms that hold no other kind (and not the shrine's
## room) are refurnished as a camp, a collapsed hall or a quarry in `biome`'s pieces; the walls are rebuilt with them
## (the gate, the Deep gate, the shrine and the stall kept) and the spawn points inside them keep only the room's own.
## No-op without purposes or a biome. The events placed after keep out of these rooms (Events.place).
static func add_purposes(
	w: World, purposes: Array, biome: StringName, map: FloorParams = null
) -> void:
	var layout := w.floor_layout
	if layout == null or purposes.is_empty() or biome == &"":
		return
	var p := map if map != null else FloorParams.defaults()
	var taken := PackedInt32Array()
	if Gamble.present(w):
		taken.append(layout.room_of(w.gamble_pos))
	var before := layout.walls.size()
	var rooms := RoomPurposes.lay(layout, p, purposes, biome, taken)
	if rooms.is_empty():
		return
	var walls: Array[Obb] = layout.walls.duplicate()
	walls.append_array(w.walls.slice(before))  # the gate, the Deep gate, the shrine, the stall
	w.set_walls(walls)
	w.prepare_wall(layout.boss_door_wall)
	var spawns := PackedVector2Array()
	for q in w.spawn_points:
		var room := layout.room_of(q)
		if not rooms.has(room) or layout.spawn_points[room].has(q):
			spawns.append(q)
	w.spawn_points = spawns


## Item spot indices in fill order: each room's first spot (in room order), then the second spots.
static func spot_order(layout: FloorLayout) -> PackedInt32Array:
	return Rewards.spot_order(layout)


## The gate's stone footprint: as deep as the gate, as wide as its pillars, so you can't walk through it.
static func gate_collider(layout: FloorLayout) -> Obb:
	var half := Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5 + 0.35)
	return Obb.make(layout.portal_pos, half, layout.portal_angle)
