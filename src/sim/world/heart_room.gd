class_name HeartRoom
extends RefCounted
## v0.11.0 O14b (owner Q-O14b "Both": "the hidden room under the Hollow Crown's throne leads to a secret 'remembered'
## Hollow Crown fight"; OWNER_QUESTIONS §J N1, N2; RUNIC_CLUES.md): the city's heart, World.heart (null unless the
## final approach was built with it: FinalArena.add_heart_room, from RunState.heart_room). In ticks (EI-03).
## - Found: the room hides behind the ring's cracked wall (FloorLayout.crack_*), a Breakables crack the build's Skill
##   breaks in crack_hits uses, as on the floors (setup gives the world its Breakables with that crack only).
## - The pedestal (Interactables Kind.HEART_PEDESTAL, reach PEDESTAL_REACH_M): one press takes the relic it holds (the
##   City's Heart, Relics.CITY_HEART; the lead's placeholder, N1). Empty once taken, or when the hero already holds it
##   (a later loop's final approach: the carry kept it).
## - The sealed door (Kind.HEART_DOOR, reach DOOR_REACH_M; N2): `door` is SEALED and its entry takes no press, so no
##   prompt shows; the views speak its rune line ("THE CROWN IS NOT YET REMEMBERED") when the hero comes within
##   DOOR_REACH_M. How the remembered Crown plugs in later: door_opens() is the one hook (today always false). When it
##   answers true, sync_registry enables the entry (the shared prompt shows HEART_DOOR_PROMPT) and the press runs
##   press_door: `door` becomes OPEN on `door_tick`, and the fight's own step reads that (for example a BossFlow-style
##   flag the app turns into the remembered fight's world, as the Ascension portal does for the final arena).
## Pure: no stream is drawn.

enum Door { SEALED, OPEN }

## How near (m) the pedestal's and the door's presses reach (the pedestal: past its half side).
const PEDESTAL_REACH_M := 1.6
const DOOR_REACH_M := 2.5

## The relic on the pedestal (Relics index), and whether it was taken here.
var relic := Relics.CITY_HEART
var taken := 0
## The sealed door: its state and the tick it opened (-1 never).
var door := Door.SEALED
var door_tick := -1


## Sets up `w`'s heart room (FinalArenaScenario.build, after the approach): its cracked wall (crack_hits Skill uses),
## the pedestal and the door in the interactable registry. Nothing without the room.
static func setup(w: World, crack_hits: int) -> void:
	var f := w.floor_layout
	if f == null or f.heart_room < 0:
		return
	var b := Breakables.new()
	b.crack_max = maxi(1, crack_hits)
	b.crack_hp = b.crack_max
	w.breakables = b
	var h := HeartRoom.new()
	w.heart = h
	w.interactables.add(
		Interactables.Kind.HEART_PEDESTAL,
		f.heart_pedestal,
		PEDESTAL_REACH_M + FinalArena.HEART_PEDESTAL_HALF_M,
		0
	)
	w.interactables.add(Interactables.Kind.HEART_DOOR, f.heart_door, DOOR_REACH_M, 0)
	h.sync_registry(w)


## The relic still lies on the pedestal.
func relic_here(w: World) -> bool:
	return taken == 0 and not Relics.held(w, relic) and Relics.table(w, relic) != null


## The registry's entries follow the room: the pedestal takes a press while it holds the relic; the door only once
## door_opens() lets it (never today) and while it is sealed.
func sync_registry(w: World) -> void:
	var r := w.interactables
	var p := r.find(Interactables.Kind.HEART_PEDESTAL, 0)
	if p >= 0:
		r.enabled[p] = 1 if relic_here(w) else 0
		r.state[p] = taken
	var d := r.find(Interactables.Kind.HEART_DOOR, 0)
	if d >= 0:
		r.enabled[d] = 1 if door == Door.SEALED and door_opens(w) else 0
		r.state[d] = door


## The press on the pedestal (Interactables.handle): the hero takes the relic.
static func press_pedestal(w: World) -> void:
	var h := w.heart
	if h == null or not h.relic_here(w):
		return
	if Relics.take(w, h.relic):
		h.taken = 1
	h.sync_registry(w)


## N2's hook: whether the sealed door opens to a press now. The remembered Crown's fight waits for the owner's brief
## so it stays sealed: always false.
static func door_opens(_w: World) -> bool:
	return false


## The press on the door (Interactables.handle; unreachable while door_opens() is false).
static func press_door(w: World) -> void:
	var h := w.heart
	if h == null or h.door != Door.SEALED or not door_opens(w):
		return
	h.door = Door.OPEN
	h.door_tick = w.tick
	h.sync_registry(w)


## FinalApproach.advance, as the walls of light rise: a hero still in the heart room is set back on the plateau, by
## the doorway (the walls of light close it: FloorLayout.light_walls holds its segment).
static func on_fight(w: World, edge_in: float) -> void:
	var f := w.floor_layout
	if w.heart == null or f == null or f.heart_room < 0:
		return
	if Kin.length(w.player_pos() - f.altar_pos) > FinalArena.radius_of(f) - edge_in:
		if (
			f.rooms[f.heart_room].has_point(w.player_pos())
			or w.player_pos().x > FinalArena.radius_of(f)
		):
			var at := (
				f.altar_pos + Kin.dir(FinalArena.HEART_ANGLE) * (FinalArena.radius_of(f) - edge_in)
			)
			w.actors.set_pos(0, at)
			w.vel = Vector2.ZERO


func hash_into(h: StateHasher) -> void:
	for v in [relic, taken, door, door_tick]:
		h.add_int(v)
