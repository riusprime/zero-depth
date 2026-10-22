class_name RunSaver
extends RefCounted
## v0.4.0 SV (PLAN "Saves (SV)", ROADMAP R3): when the run saves and what a save holds. A save is taken at each
## first entry into a room of the floor (the start hall at the floor's first tick, then every room the player walks
## into for the first time), right after the tick of the entry, and written on a worker thread. On close (pause ->
## Main menu, the window's close request) the last room-entry save is made sure to be on disk: quitting mid-room
## resumes at that room's entry. A death or a win deletes it; a new run overwrites it.
##
## The payload: the run (RunState's fields and the stage seed; its RunTable is compiled again from content), the
## rooms entered on this floor (the minimap's discovery) and the world's canonical snapshot (WorldSnapshot).

## 2: v0.5.0 RT adds the run's route per floor (`run.routes`). 3: v0.6.0 MX2, the build's modifier slots (the
## carry's mod_slots, the world's); a version-2 payload still loads and migrates (RunCarry, WorldSnapshot).
## 4: v0.6.5 WN1, the wand: mod_slots is the slot order the player arranged (the compile reads it left to right). A
## version-3 payload's slots are in pick order, which is its wand order as it stands (nothing to rewrite); its slot
## count comes from the floor reached (Wand.slots), and a wand holding more cards than that keeps them all (the next
## new card needs a Swap).
## v0.7.5 MG adds `run.floor_rules` (RunState.FLOOR_RULES) without a new version: a version-4 payload without it was
## saved on a v0.7.0 floor, which floor_tables() then rebuilds with v0.7.0's rules.
## v0.7.5 AP adds `run.loop` and `run.loop_floors` (the Ascension loop) the same way: a payload without them is a
## loop-1 run (every save made before v0.7.5 AP), and its biome order, routes and floor seeds read as before.
## v0.8.0 FB1 adds `run.final` (End the run took the hero to the final boss; RunState.final_fight) the same way: a
## payload without it is a run before the final arena. In the final arena a save is also taken at each body's start
## (FinalFight.phase_tick: after_tick), so Continue resumes the fight at the current body's beginning.
## v0.9.0 FV (owner Q24, PD-03 changed: a run is 5 floors) adds `run.run_id` (the RunDefinition the run was started
## with) the same way: a payload without it is a v0.8.0 run (or older) and resumes in its 3-floor shape
## (LEGACY_RUN_ID: 3 floors, v0.8.0's scaling, 15-19 rooms a floor, the wand's 4 → 6 → 8), so its floor rebuilds as
## it was saved and it ends on its floor 3.
const PAYLOAD_VERSION := 4
const PAYLOAD_VERSIONS_READ: Array[int] = [2, 3, 4]
## v0.9.0 FV: today's run (Main) and the shape a payload without `run_id` resumes in.
const RUN_ID := &"five_floors"
const LEGACY_RUN_ID := &"three_floors"
## v0.8.0 RT2: the designed layouts of floor rules 4 (RT1: data/room_layouts as RT1 shipped them, unchanged since).
const RT1_LAYOUTS: Array[StringName] = [&"room_2x2_1", &"room_3x2_1", &"room_3x3_1"]

var store: RunSaveStore
## Rooms of the current floor entered so far, one byte per room.
var rooms := PackedByteArray()
## Room-entry saves taken this session (the save unit and e2e tests read it).
var entries := 0
## The last room-entry payload: what Continue resumes from, and what close makes sure is on disk.
var last := {}
var _active := false
## v0.8.0 FB1: the final fight's body whose start was saved last (-1 none).
var _final_saved := -1


func _init(p_store: RunSaveStore = null) -> void:
	store = p_store if p_store != null else RunSaveStore.shared()


## A floor starts (a new floor, or a resumed one): `p_rooms` are the rooms already entered (a resumed save's), else
## the start hall is entered now and saved.
func begin_floor(
	w: World, run: RunState, stage_seed: int, p_rooms: PackedByteArray = PackedByteArray()
) -> void:
	_active = true
	_final_saved = w.final_fight.phase if w.final_fight != null else -1
	rooms = PackedByteArray()
	rooms.resize(w.floor_layout.room_count() if w.floor_layout != null else 0)
	if p_rooms.size() == rooms.size() and not p_rooms.is_empty():
		rooms = p_rooms.duplicate()
		return
	var start := w.floor_layout.start_room if w.floor_layout != null else -1
	if start >= 0:
		rooms[start] = 1
	_save(w, run, stage_seed)


## After each tick: a first entry into a room saves. True when it did.
func after_tick(w: World, run: RunState, stage_seed: int) -> bool:
	if not _active or w.floor_layout == null or w.player_dead():
		return false
	var f := w.final_fight
	if f != null and not f.won and f.phase > _final_saved:
		_final_saved = f.phase  # v0.8.0 FB1: the next body's start (the tick it rose)
		_save(w, run, stage_seed)
		return true
	var room := w.floor_layout.room_of(w.player_pos())
	if room < 0 or room >= rooms.size() or rooms[room] == 1:
		return false
	rooms[room] = 1
	_save(w, run, stage_seed)
	return true


## The run is being left (Main menu, window close): the last room-entry save is on disk when this returns.
func close() -> void:
	if not _active:
		return
	_active = false
	if not store.flush() and not last.is_empty():  # the async write failed: once more, now
		store.write(last)


## The run ended (a death or a win): no save to continue from.
func discard() -> void:
	_active = false
	last = {}
	store.delete()


## v0.7.5 MG: the floor tables a floor of `run` is built with, compiled from `repo`: {map: FloorParams, arena:
## ArenaTable, shop: ShopTable}. v0.8.0 RT: the map carries the designed room layouts (data/room_layouts) unless the
## floor was saved before RT (RunState.designed_rooms), which is rebuilt with its rule-built rooms. v0.8.0 SR: the shop
## carries the biomes' shop rooms (data/shop_rooms) unless the floor was saved before SR (RunState.shop_rooms), which
## is rebuilt with its terminal. A v0.7.0 floor
## resumed from an older save (RunState.v070_floor) gets v0.7.0's rules on top: FloorParams.v070(), arena share 330 per
## mille, a shop on every floor (Main and the save tests).
## v0.8.0 SR: whether run `run`'s current floor puts its shop in its biome's shop room (false: a floor resumed from a
## save made before SR, floor rules 1-4, keeps the terminal it had).
static func shop_rooms(run: RunState) -> bool:
	return run.floor_rules > RunState.FLOOR_RULES_V080_RT1


static func floor_tables(run: RunState, repo: ContentRepository) -> Dictionary:
	var map := RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	var arena := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	var shop := ContentCompiler.compile_shop(repo.get_def(&"shop", &"terminal"))
	if run == null or run.designed_rooms():  # v0.8.0 RT: a floor saved before RT keeps its rule-built rooms
		map.room_layouts = RunContentCompiler.compile_room_layouts(repo)
		if run != null and run.rt1_rooms():  # v0.8.0 RT2: a floor saved under RT1 keeps RT1's three layouts
			map.room_layouts = rt1_layouts(map.room_layouts)
	if shop != null and (run == null or shop_rooms(run)):  # v0.8.0 SR: before SR, the terminal
		shop.rooms = RunContentCompiler.compile_shop_rooms(repo)
	# v0.9.0 PT: a floor saved before v0.9.0 (rules 1-9) keeps its gates against the wall, as it was built.
	map.legacy_gate = run != null and run.floor_rules <= RunState.FLOOR_RULES_V080_BD
	if run != null and run.v070_floor():
		map = FloorParams.v070()
		map.legacy_gate = true
		if arena != null:
			arena.share_permille = ArenaTable.V070_SHARE_PERMILLE
		if shop != null:
			shop.first_floor = 1
			shop.every_floors = 1
	return {&"map": map, &"arena": arena, &"shop": shop}


## v0.8.0 RT2: the designed layouts a floor saved under floor rules 4 (RT1) was built with: RT1_LAYOUTS out of
## `layouts` (RunContentCompiler.compile_room_layouts), the sizes without one dropped, so its rooms of those sizes
## draw nothing and keep their rule-built interiors as they did then.
static func rt1_layouts(layouts: Dictionary) -> Dictionary:
	var out := {}
	for key: Vector2i in layouts:
		var list: Array = []
		for t: RoomLayoutTable in layouts[key]:
			if t.id in RT1_LAYOUTS:
				list.append(t)
		if not list.is_empty():
			out[key] = list
	return out


## v0.7.5 BF1 (N18): the boss room floor `run` builds for boss `boss` (an index into `bosses`; -1 = none): today's
## 4 x 4, or the boss's legacy room on a floor resumed from a save made before BF1 (Main and the labs).
static func boss_arena(run: RunState, bosses: Array[BossTable], boss: int) -> BossArenaSpec:
	if boss < 0:
		return null
	var t := bosses[boss]
	var cells := t.legacy_arena_cells if run != null and run.legacy_boss_room() else t.arena_cells
	return BossArenaSpec.make(cells, t.arena_template, boss)


## v0.9.0 FV: the RunDefinition id a payload's run was started with (LEGACY_RUN_ID for a payload without one: a
## v0.8.0 run resumes in its 3-floor shape). Compile it for run_from.
static func saved_run_id(payload: Dictionary) -> StringName:
	var r: Variant = payload.get("run", {})
	var id := String((r as Dictionary).get("run_id", "")) if r is Dictionary else ""
	return LEGACY_RUN_ID if id.is_empty() else StringName(id)


## Payload -> its run. `run_table` is the run's compiled RunTable (from content, like a new run's; v0.9.0 FV: the
## definition saved_run_id names).
static func run_from(payload: Dictionary, run_table: RunTable) -> RunState:
	var r: Dictionary = payload.get("run", {})
	var run := RunState.start(int(r["run_seed"]), run_table, StringName(r["build_id"]))
	run.floor_index = int(r["floor_index"])
	run.biome_order = r["biome_order"]
	run.carry = (r["carry"] as Dictionary).duplicate(true)
	run.ticks_done = int(r["ticks_done"])
	run.kills_done = int(r["kills_done"])
	run.routes = PackedInt32Array(r["routes"])  # v0.5.0 RT
	run.threat_by_floor = PackedInt32Array(r.get("threat_by_floor", PackedInt32Array()))  # v0.5.0 EV
	# v0.7.5 MG: a payload without floor rules was saved on a v0.7.0 floor (rebuilt with those rules).
	run.floor_rules = int(r.get("floor_rules", RunState.FLOOR_RULES_V070))
	run.loop = maxi(1, int(r.get("loop", 1)))  # v0.7.5 AP: an older payload is loop 1
	run.loop_floors = maxi(0, int(r.get("loop_floors", 0)))
	run.final_fight = bool(r.get("final", false))  # v0.8.0 FB1: an older payload is before the final arena
	return run


## A payload Continue can use: the right version and every part present.
static func is_usable(payload: Dictionary) -> bool:
	return (
		PAYLOAD_VERSIONS_READ.has(int(payload.get("version", -1)))
		and typeof(payload.get("run")) == TYPE_DICTIONARY
		and typeof(payload.get("world")) == TYPE_DICTIONARY
		and typeof(payload.get("rooms")) == TYPE_PACKED_BYTE_ARRAY
	)


static func payload_of(
	w: World, run: RunState, stage_seed: int, p_rooms: PackedByteArray
) -> Dictionary:
	return {
		"version": PAYLOAD_VERSION,
		"run":
		{
			"run_seed": run.run_seed,
			"stage_seed": stage_seed,
			"build_id": String(run.build_id),
			"floor_index": run.floor_index,
			"biome_order": run.biome_order.duplicate(),
			"carry": run.carry.duplicate(true),
			"ticks_done": run.ticks_done,
			"kills_done": run.kills_done,
			"routes": run.routes.duplicate(),  # v0.5.0 RT: each floor's route
			"threat_by_floor": run.threat_by_floor.duplicate(),  # v0.5.0 EV (M-THREAT)
			"floor_rules": run.floor_rules,  # v0.7.5 MG: the floor's generation rules
			"loop": run.loop,  # v0.7.5 AP: the Ascension loop
			"loop_floors": run.loop_floors,
			"final": run.final_fight,  # v0.8.0 FB1: the final arena
			"run_id": String(run.table.id),  # v0.9.0 FV: the run's shape (saved_run_id)
		},
		"rooms": p_rooms.duplicate(),
		"tick": w.tick,
		"world": w.to_snapshot(),
	}


func _save(w: World, run: RunState, stage_seed: int) -> void:
	last = payload_of(w, run, stage_seed, rooms)
	entries += 1
	store.write_async(last)
