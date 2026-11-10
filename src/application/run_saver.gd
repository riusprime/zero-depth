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

## The payload has one version. A payload of any other version, one without every part, or a file that can't be read
## is refused (EI-09): Continue doesn't offer it, the file is set aside on disk under run.bad.<time>.save
## (RunSaveStore.reject: kept, never deleted or written over), and the main menu says so once (`take_refused`).
const PAYLOAD_VERSION := 5
## The run's keys every payload holds (payload_of writes each one).
const RUN_KEYS: Array[String] = [
	"run_seed",
	"stage_seed",
	"build_id",
	"floor_index",
	"biome_order",
	"carry",
	"ticks_done",
	"kills_done",
	"routes",
	"threat_by_floor",
	"floor_rules",
	"loop",
	"loop_floors",
	"final",
	"purple_floors",
	"run_id",
	"boss_draw",
	"affinity",
	"fragments",
	"locked",
	"collected",
	"collected_run",
	"marked",
	"loop_rules",
	"loop_rule_loop",
	"heart_room"
]
## Today's run (Main).
const RUN_ID := &"five_floors"
## The main menu's notices for a refused save: written by an older version, or unreadable.
const REFUSED_OLDER := "UI_SAVE_REFUSED_OLDER"
const REFUSED_UNREADABLE := "UI_SAVE_REFUSED_UNREADABLE"
## The designed layouts of floor rules 4 (RT1: data/room_layouts as RT1 shipped them, unchanged since).
const RT1_LAYOUTS: Array[StringName] = [&"room_2x2_1", &"room_3x2_1", &"room_3x3_1"]

var store: RunSaveStore
## Rooms of the current floor entered so far, one byte per room.
var rooms := PackedByteArray()
## Room-entry saves taken this session (the save unit and e2e tests read it).
var entries := 0
## The last room-entry payload: what Continue resumes from, and what close makes sure is on disk.
var last := {}
## The notice for the save refused last (REFUSED_*), "" when none; take_refused hands it out once.
var refused := ""
var _active := false
## The final fight's body whose start was saved last (-1 none).
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
		_final_saved = f.phase  # The next body's start (the tick it rose)
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


## The saved run Continue resumes, or {}: none, or one this build refuses (set aside on disk, and `refused` names the
## notice: a save from another save_version or an earlier payload version reads as older, anything else as
## unreadable).
func usable() -> Dictionary:
	var save := store.read()
	if store.last_error != "":
		var older := store.last_error.begins_with("save_version")
		refused = REFUSED_OLDER if older else REFUSED_UNREADABLE
		return {}
	if save.is_empty() or is_usable(save):
		return save
	var version := int(save["version"]) if save.get("version") is int else -1
	refuse(
		"payload version %d, this game reads %d" % [version, PAYLOAD_VERSION],
		version >= 0 and version < PAYLOAD_VERSION
	)
	return {}


## Sets the save aside on disk (kept, never deleted: `why` it can't be resumed), and the menu says so once.
func refuse(why: String, older := false) -> void:
	store.reject(why)
	refused = REFUSED_OLDER if older else REFUSED_UNREADABLE


## The notice for the save refused last ("" when none), handed out once.
func take_refused() -> String:
	var out := refused
	refused = ""
	return out


## The floor tables a floor of `run` is built with, compiled from `repo`: {map: FloorParams, arena:
## ArenaTable, shop: ShopTable}. the map carries the designed room layouts (data/room_layouts) unless the
## floor was saved before RT (RunState.designed_rooms), which is rebuilt with its rule-built rooms. the shop
## carries the biomes' shop rooms (data/shop_rooms) unless the floor was saved before SR (RunState.shop_rooms), which
## is rebuilt with its terminal. A v0.7.0 floor
## resumed from an older save (RunState.v070_floor) gets v0.7.0's rules on top: FloorParams.v070(), arena share 330 per
## mille, a shop on every floor (Main and the save tests).
## Whether run `run`'s current floor puts its shop in its biome's shop room (false: a floor resumed from a
## save made before SR, floor rules 1-4, keeps the terminal it had).
static func shop_rooms(run: RunState) -> bool:
	return run.floor_rules > RunState.FLOOR_RULES_V080_RT1


static func floor_tables(run: RunState, repo: ContentRepository) -> Dictionary:
	var map := RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	var arena := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	var shop := ContentCompiler.compile_shop(repo.get_def(&"shop", &"terminal"))
	var overrun := ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))
	if ClosedFights.legacy_rooms(run):  # A floor saved before CF keeps its rooms
		if arena != null:
			arena.min_cells = 0
		if overrun != null:
			overrun.min_cells = 0
	if run == null or run.designed_rooms():  # A floor saved before RT keeps its rule-built rooms
		map.room_layouts = RunContentCompiler.compile_room_layouts(repo)
		if run != null and run.rt1_rooms():  # A floor saved under RT1 keeps RT1's three layouts
			map.room_layouts = rt1_layouts(map.room_layouts)
	if shop != null and (run == null or shop_rooms(run)):  # Before SR, the terminal
		shop.rooms = RunContentCompiler.compile_shop_rooms(repo)
	# A floor saved before v0.9.0 (rules 1-9) keeps its gates against the wall, as it was built.
	map.legacy_gate = run != null and run.floor_rules <= RunState.FLOOR_RULES_V080_BD
	if run != null and run.v070_floor():
		map = FloorParams.v070()
		map.legacy_gate = true
		if arena != null:
			arena.share_permille = ArenaTable.V070_SHARE_PERMILLE
		if shop != null:
			shop.first_floor = 1
			shop.every_floors = 1
	var first: LockdownTable = null  # A floor built under rules 17 marks its Lockdowns first
	if run != null and run.floor_rules > RunState.FLOOR_RULES_V090_CF:
		first = lockdown_table(run, repo)
	# PLAN P1: the large rooms' purposes (none on a v0.7.0 floor)
	var purposes: Array[RoomPurposeTable] = []
	if run == null or not run.v070_floor():
		purposes = RunContentCompiler.compile_room_purposes(repo)
	return {
		&"map": map,
		&"arena": arena,
		&"shop": shop,
		&"overrun": overrun,
		&"lockdown_first": first,
		&"purposes": purposes
	}


## v0.9.0 LK, EL, CF: the Lockdowns' table a floor of `run` is built with: no Elite Lockdown on a floor saved before
## EL (rules 1-14), any room size on one saved before CF (1-15). Null without the data.
static func lockdown_table(run: RunState, repo: ContentRepository) -> LockdownTable:
	var t := RunContentCompiler.compile_lockdown(repo.get_def(&"lockdown", &"lockdown"))
	if t != null and run != null and run.floor_rules <= RunState.FLOOR_RULES_V090_SH:
		t.kind_weights[LockdownTable.Kind.ELITE] = 0  # A floor saved before EL had none
	if t != null and run != null and run.floor_rules <= RunState.FLOOR_RULES_V095_AQ:
		t.burst_gap_ticks = 0  # A floor saved before DR keeps its three formations and its arenas
		t.takes_arenas = false
	if t != null and run != null and run.floor_rules <= RunState.FLOOR_RULES_V095_BK:
		t.set_piece_floor = 0  # A floor saved before it keeps its Lockdown order and kinds
	if t != null and ClosedFights.legacy_rooms(run):  # A floor saved before CF keeps its rooms
		t.min_cells = 0
	return t


## The designed layouts a floor saved under floor rules 4 was built with: RT1_LAYOUTS out of
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


## The boss room floor `run` builds for boss `boss` (an index into `bosses`; -1 = none): today's
## 4 x 4, or the boss's legacy room on a floor resumed from a save made before BF1 (Main and the labs).
static func boss_arena(run: RunState, bosses: Array[BossTable], boss: int) -> BossArenaSpec:
	if boss < 0:
		return null
	var t := bosses[boss]
	var cells := t.legacy_arena_cells if run != null and run.legacy_boss_room() else t.arena_cells
	return BossArenaSpec.make(cells, t.arena_template, boss)


## The RunDefinition id a payload's run was started with. Compile it for run_from.
static func saved_run_id(payload: Dictionary) -> StringName:
	return StringName(String((payload["run"] as Dictionary)["run_id"]))


## Payload -> its run. `run_table` is the run's compiled RunTable (from content, like a new run's; the
## definition saved_run_id names). The payload is one is_usable accepts.
static func run_from(payload: Dictionary, run_table: RunTable) -> RunState:
	var r: Dictionary = payload["run"]
	var run := RunState.start(int(r["run_seed"]), run_table, StringName(r["build_id"]))
	run.floor_index = int(r["floor_index"])
	run.biome_order = r["biome_order"]
	run.carry = (r["carry"] as Dictionary).duplicate(true)
	run.ticks_done = int(r["ticks_done"])
	run.kills_done = int(r["kills_done"])
	run.routes = PackedInt32Array(r["routes"])
	run.threat_by_floor = PackedInt32Array(r["threat_by_floor"])
	run.floor_rules = int(r["floor_rules"])
	run.loop = int(r["loop"])
	run.loop_floors = int(r["loop_floors"])
	run.final_fight = bool(r["final"])
	run.purple_floors = PackedInt32Array(r["purple_floors"])
	run.affinity = StringName(String(r["affinity"]))
	run.fragments_done = int(r["fragments"])
	run.locked_cards = _names(r["locked"])
	run.collected = _names(r["collected"])
	run.collected_run = _names(r["collected_run"])
	run.marked_done = int(r["marked"])
	run.loop_rules = _names(r["loop_rules"])
	run.loop_rule_loop = int(r["loop_rule_loop"])
	run.boss_draw = int(r["boss_draw"])
	run.heart_room = bool(r["heart_room"])
	return run


## A payload Continue can use: this build's version and every part present.
static func is_usable(payload: Dictionary) -> bool:
	if not (payload.get("version") is int and int(payload["version"]) == PAYLOAD_VERSION):
		return false
	if (
		typeof(payload.get("world")) != TYPE_DICTIONARY
		or typeof(payload.get("rooms")) != TYPE_PACKED_BYTE_ARRAY
		or typeof(payload.get("run")) != TYPE_DICTIONARY
	):
		return false
	var r: Dictionary = payload["run"]
	return RUN_KEYS.all(func(k: String) -> bool: return r.has(k))


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
			"routes": run.routes.duplicate(),  # Each floor's route
			"threat_by_floor": run.threat_by_floor.duplicate(),
			"floor_rules": run.floor_rules,  # The floor's generation rules
			"loop": run.loop,  # The Ascension loop
			"loop_floors": run.loop_floors,
			"final": run.final_fight,  # The final arena
			"purple_floors": run.purple_floors.duplicate(),  # The floors that held purple runes
			"run_id": String(run.table.id),  # The run's shape (saved_run_id)
			"boss_draw": run.boss_draw,  # The run's boss draw rules (RunState.BOSS_DRAW)
			"affinity": String(run.affinity) if Wardrobe.has_affinity(run.affinity) else "",  # "": None
			"fragments": run.fragments_done,  # The run's Rune Fragments so far
			"locked": _ids(run.locked_cards),  # The cards still locked for the run
			"collected": _ids(run.collected),  # The collectibles no floor arms again
			"collected_run": _ids(run.collected_run),  # Those taken in this run
			"marked": run.marked_done,  # The marked secrets the finished floors found
			"loop_rules": _ids(run.loop_rules),
			"loop_rule_loop": run.loop_rule_loop,
			"heart_room": run.heart_room,  # The final approach holds the heart room
		},
		"rooms": p_rooms.duplicate(),
		"tick": w.tick,
		"world": w.to_snapshot(),
	}


static func _names(ids: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in ids:
		out.append(StringName(String(id)))
	return out


static func _ids(ids: Array[StringName]) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		out.append(String(id))
	return out


func _save(w: World, run: RunState, stage_seed: int) -> void:
	last = payload_of(w, run, stage_seed, rooms)
	entries += 1
	store.write_async(last)
