class_name Interactables
extends RefCounted
## v0.9.0 IX (owner W34: "Build reusable Godot components so the same interaction logic can support different visual
## models and room layouts"; W13 §13 "Interactable Controller: Common player interaction logic for switches, altars,
## machines, and other objects"): the shared interactable registry, plain data (World.interactables).
## - Each entry: an id (ascending, never reused), a kind (Kind), a position, a reach (m), an enabled flag, a state (the
##   kind's own: a switch's 0 off / 1 on) and a ref (the owner's own index: a pylon's k, a timed door's switch code).
## - The interact press (World.step's fixed order, after Rewards, Events, Shop, Gamble and the boss door: those systems
##   keep their own reach and run first, unchanged) goes to the nearest enabled entry within its reach, the lowest id
##   on a tie, and is dispatched to its kind's handler (handle). in_reach() is the only reach rule, so the HUD's one
##   shared prompt (WorldReader.interact_prompt_key) shows exactly what the press would do.
## - Puzzle calm (owner Q22: "when approaching puzzles the enemy spawn should ease a bit so the player has a chill
##   moment to solve the puzzle, not stop completly"; "A quarter of the rate"): a puzzle registers its room
##   (add_calm_room); while the hero stands in a calm room that is not solved, SpawnDirector's clock runs at a quarter
##   of its rate (calm_now). Enemies already out keep fighting. solve_calm ends it for good; leaving the room ends it
##   while you are away.
## Users: the final approach's rune pylons (FinalApproach, v0.9.0 FA).
## Pure: no stream is drawn.

enum Kind { PYLON }

## Each kind's prompt (a string key in locale/strings.csv), for the shared prompt view.
const PROMPT_KEYS: Array[StringName] = [&"APPROACH_PYLON_PROMPT"]
## Puzzle calm: the spawn clock runs one tick in CALM_DIVISOR (a quarter of the rate).
const CALM_DIVISOR := 4

var ids := PackedInt32Array()
var kind := PackedInt32Array()
var pos := PackedVector2Array()
var reach := PackedFloat64Array()
var enabled := PackedByteArray()
var state := PackedInt32Array()
var ref := PackedInt32Array()
## The tick each entry was last pressed (-1 never), for the views' edges.
var press_tick := PackedInt32Array()
var next_id := 1
## Puzzle calm: the rooms (FloorLayout room indices) and whether each is solved (1: calm over for good).
var calm_rooms := PackedInt32Array()
var calm_solved := PackedByteArray()


func size() -> int:
	return ids.size()


func is_empty() -> bool:
	return ids.is_empty() and calm_rooms.is_empty()


## Adds an entry (setup, or play). Returns its index.
func add(p_kind: int, p_pos: Vector2, p_reach: float, p_ref: int) -> int:
	ids.append(next_id)
	next_id += 1
	kind.append(p_kind)
	pos.append(p_pos)
	reach.append(p_reach)
	enabled.append(1)
	state.append(0)
	ref.append(p_ref)
	press_tick.append(-1)
	return ids.size() - 1


## The entry of `p_kind` with ref `p_ref`, or -1.
func find(p_kind: int, p_ref: int) -> int:
	for i in ids.size():
		if kind[i] == p_kind and ref[i] == p_ref:
			return i
	return -1


## The enabled entry nearest `p` within its reach (the lowest id on a tie: entries are in id order), or -1.
func in_reach(p: Vector2) -> int:
	var best := -1
	var best_d := 0.0
	for i in ids.size():
		if enabled[i] == 0:
			continue
		var d := Kin.length(pos[i] - p)
		if d <= reach[i] and (best < 0 or d < best_d):
			best = i
			best_d = d
	return best


## Tick phase 2 (World.step, the registry's slot): a buffered interact press by an enabled entry goes to its kind's
## handler. True when the press was taken.
static func interact(w: World) -> bool:
	if w.player_dead() or w.buffered(InputFrame.INTERACT) == 0:
		return false
	var r := w.interactables
	var i := r.in_reach(w.player_pos())
	if i < 0:
		return false
	w.consume_buffered(InputFrame.INTERACT)
	r.press_tick[i] = w.tick
	handle(w, i)
	return true


## Dispatches entry i's press to its kind's owner.
static func handle(w: World, i: int) -> void:
	var r := w.interactables
	match r.kind[i]:
		Kind.PYLON:
			if w.approach != null:
				w.approach.press(w, r.ref[i])


## Registers `room` as a puzzle's calm room (setup). Returns its index.
func add_calm_room(room: int) -> int:
	calm_rooms.append(room)
	calm_solved.append(0)
	return calm_rooms.size() - 1


## The puzzle in calm room k is solved: normal spawning from now on there.
func solve_calm(k: int) -> void:
	if k >= 0 and k < calm_solved.size():
		calm_solved[k] = 1


## Whether the hero stands in an unsolved puzzle's room (World.floor_layout's room_of).
static func calm_now(w: World) -> bool:
	var r := w.interactables
	if r.calm_rooms.is_empty() or w.floor_layout == null:
		return false
	var room := w.floor_layout.room_of(w.player_pos())
	if room < 0:
		return false
	for k in r.calm_rooms.size():
		if r.calm_rooms[k] == room and r.calm_solved[k] == 0:
			return true
	return false


## SpawnDirector's clock step under puzzle calm: 1 on one tick in CALM_DIVISOR, else 0 (1 without calm).
static func spawn_clock_step(w: World) -> int:
	if not calm_now(w):
		return 1
	return 1 if w.run_ticks % CALM_DIVISOR == 0 else 0


func hash_into(h: StateHasher) -> void:
	h.add_int(next_id)
	h.add_ints(ids)
	h.add_ints(kind)
	for i in ids.size():
		h.add_f32(pos[i].x)
		h.add_f32(pos[i].y)
		h.add_f32(reach[i])
		h.add_int(enabled[i])
	h.add_ints(state)
	h.add_ints(ref)
	h.add_ints(press_tick)
	h.add_ints(calm_rooms)
	for v in calm_solved:
		h.add_int(v)
