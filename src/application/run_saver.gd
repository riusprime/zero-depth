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
const PAYLOAD_VERSION := 3
const PAYLOAD_VERSIONS_READ: Array[int] = [2, 3]

var store: RunSaveStore
## Rooms of the current floor entered so far, one byte per room.
var rooms := PackedByteArray()
## Room-entry saves taken this session (the e2e test and the dev panel read it).
var entries := 0
## The last room-entry payload: what Continue resumes from, and what close makes sure is on disk.
var last := {}
## Microseconds the last entry save held the frame (the snapshot; the encode and write are off the frame).
var last_cost_usec := 0
var _active := false


func _init(p_store: RunSaveStore = null) -> void:
	store = p_store if p_store != null else RunSaveStore.shared()


## A floor starts (a new floor, or a resumed one): `p_rooms` are the rooms already entered (a resumed save's), else
## the start hall is entered now and saved.
func begin_floor(
	w: World, run: RunState, stage_seed: int, p_rooms: PackedByteArray = PackedByteArray()
) -> void:
	_active = true
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


## Payload -> its run. `run_table` is the run's compiled RunTable (from content, like a new run's).
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
		},
		"rooms": p_rooms.duplicate(),
		"tick": w.tick,
		"world": w.to_snapshot(),
	}


func _save(w: World, run: RunState, stage_seed: int) -> void:
	var t0 := Time.get_ticks_usec()
	last = payload_of(w, run, stage_seed, rooms)
	last_cost_usec = Time.get_ticks_usec() - t0
	entries += 1
	store.write_async(last)
