class_name TimedDoor
extends RefCounted
## v0.9.0 TD (owner W §2: "1. The player discovers the closed door. 2. Two interactive switches, runes, or mechanisms
## must be activated. 3. Activating both opens the door … 6. The player must reach the entrance before the timer
## expires. 7. If the player fails, the door closes and the mechanisms reset"; "No permanent penalty for failure. Reset
## safely without trapping the player"; Q20 "Allow local timers": 15 s from the second switch, the room holds an epic
## altar or a chest; Q22 puzzle calm; Q23 the hidden room unseen until it opens): the floor's timed door, in ticks
## (EI-03). World.timed holds it (null on a floor without one; FloorLayout.timed_* from TimedDoorRooms.mark).
## - SHUT: the door's slab (FloorLayout.timed_door_wall) is a barrier (World.add_barrier; added on the floor's first
##   tick, so the floor's generated walls stay as they were and a save's walls start with them). The two switches are
##   shared interactables (Interactables.Kind.TIMED_SWITCH, SWITCH_REACH_M), one press each, in either order; a switch
##   that is on takes no press. The second opens the door.
## - OPEN: the slab is gone, the timer (timer_ticks, 900 at 60 Hz) counts from the second switch. When it runs out the
##   door shuts and both switches reset, unless the hero is in the doorway or inside the secret room: then HELD.
## - HELD: open until the hero is out of the doorway and the secret room (left through the door), then it shuts and the
##   switches reset. The door never shuts on the hero.
## - The secret room's reward: an epic altar (Offers.roll_epic) or a chest (priced as the floor's next chest), drawn
##   from the `loot:timed_door` sub-stream, placed at setup on the room's first item spot (else its spawn spot nearest
##   its centre, else its centre). The room holds no enemy spawn spot.
## - Puzzle calm (Q22): the host room (the switches' room) is a calm room of the registry until the door first opens.
## The views read `opened` (0: never opened, the secret room unseen: Q23), the state, open_tick and timer_ticks (the
## accelerating beeps and flashing runes), shut_tick (the impact).

enum State { SHUT, OPEN, HELD }

## How near a switch (m) the press reaches.
const SWITCH_REACH_M := 1.8
const REWARD_STREAM := "loot:timed_door"

var state := State.SHUT
var timer_ticks := 900
## The tick the door last opened and last shut (-1 not yet), and how many times it has opened.
var open_tick := -1
var shut_tick := -1
var opened := 0
## 1 while the slab stands as a barrier in World.walls.
var wall_up := 0
## The switches' entries in World.interactables, and the host room's calm entry.
var switches := PackedInt32Array()
var calm_k := -1
## The secret room's reward (its id, -1 none) and whether it is an epic altar.
var reward_id := -1
var reward_epic := 0


## Sets up `w`'s timed door (setup, after the floor's rewards, events, shrine and shop are placed): marks the layout
## (TimedDoorRooms.mark: `chance_permille` of floors), registers the switches and the calm room, drops the secret
## room's spawn spots and places its reward. No-op on a floor that gets none.
static func setup(w: World, chance_permille: int, ticks: int, speed: float) -> void:
	var f := w.floor_layout
	if f == null:
		return
	var taken := PackedInt32Array()
	var avoid := PackedVector2Array()
	for i in w.rewards.size():
		avoid.append(w.rewards.pos(i))
		taken.append(f.room_of(w.rewards.pos(i)))
	for k in w.ev.ids.size():
		avoid.append(Vector2(w.ev.pos_x[k], w.ev.pos_y[k]))
		taken.append(w.ev.room[k])
	if w.gamble_id >= 0:
		avoid.append(w.gamble_pos)
		taken.append(f.room_of(w.gamble_pos))
	avoid.append_array(Shrines.avoid_spots(w))  # v0.9.0 HF: the fountain and its room
	taken.append_array(Shrines.taken_rooms(w))
	if TimedDoorRooms.mark(f, chance_permille, ticks, speed, taken, avoid) < 0:
		return
	var t := TimedDoor.new()
	t.timer_ticks = ticks
	for k in f.timed_switches.size():
		t.switches.append(
			w.interactables.add(
				Interactables.Kind.TIMED_SWITCH, f.timed_switches[k], SWITCH_REACH_M, k
			)
		)
	t.calm_k = w.interactables.add_calm_room(f.timed_host)
	var spawns := PackedVector2Array()
	for q in w.spawn_points:
		if f.room_of(q) != f.timed_room:
			spawns.append(q)
	w.spawn_points = spawns
	w.timed = t
	_place_reward(w, t)


static func _place_reward(w: World, t: TimedDoor) -> void:
	var got := Secrets.place_reward(w, w.floor_layout.timed_room, REWARD_STREAM)  # v0.9.0 RA: shared
	t.reward_id = got.x
	t.reward_epic = got.y


## The press on registry entry i (Interactables.handle): switch on; the second opens the door.
static func press(w: World, i: int) -> void:
	var t := w.timed
	var r := w.interactables
	if t == null or t.state != State.SHUT or r.state[i] == 1:
		return
	r.state[i] = 1
	r.enabled[i] = 0
	for s in t.switches:
		if r.state[s] == 0:
			return
	t.state = State.OPEN
	t.open_tick = w.tick
	t.opened += 1
	r.solve_calm(t.calm_k)  # Q22: solved, normal spawning there from now on
	if t.wall_up == 1:
		var slab: Array[Obb] = [w.floor_layout.timed_door_wall]
		w.remove_barriers(slab)
		t.wall_up = 0


## Tick phase 9: the slab stands while shut; the timer runs out; the door shuts when the hero is clear of it.
static func advance(w: World) -> void:
	var t := w.timed
	if t == null:
		return
	match t.state:
		State.SHUT:
			if t.wall_up == 0:
				w.add_barrier(w.floor_layout.timed_door_wall)
				t.wall_up = 1
		State.OPEN:
			if w.tick - t.open_tick >= t.timer_ticks:
				if hero_inside(w):
					t.state = State.HELD
				else:
					_shut(w, t)
		State.HELD:
			if not hero_inside(w):
				_shut(w, t)


static func _shut(w: World, t: TimedDoor) -> void:
	t.state = State.SHUT
	t.shut_tick = w.tick
	w.add_barrier(w.floor_layout.timed_door_wall)
	t.wall_up = 1
	var r := w.interactables
	for s in t.switches:
		r.state[s] = 0
		r.enabled[s] = 1


## The hero is in the doorway (touching the slab's footprint) or inside the secret room.
static func hero_inside(w: World) -> bool:
	var f := w.floor_layout
	var p := w.player_pos()
	if f.room_of(p) == f.timed_room:
		return true
	return Collide.circle_vs_obb(p, w.player.radius_m + 0.05, f.timed_door_wall) != Vector2.ZERO


## Whether reward i is a secret room's epic altar (Offers.roll: epic stat cards, as a Deep floor's). v0.9.0 RA: any
## secret room's (Secrets.is_epic: the timed door's, the rune puzzle's).
static func is_epic(w: World, i: int) -> bool:
	return Secrets.is_epic(w, i)


## Ticks left on the timer while open (0 when shut or held).
func ticks_left(tick: int) -> int:
	if state != State.OPEN:
		return 0
	return maxi(0, timer_ticks - (tick - open_tick))


func hash_into(h: StateHasher) -> void:
	for v in [
		state, timer_ticks, open_tick, shut_tick, opened, wall_up, calm_k, reward_id, reward_epic
	]:
		h.add_int(v)
	h.add_ints(switches)
