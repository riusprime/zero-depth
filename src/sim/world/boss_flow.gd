class_name BossFlow
extends RefCounted
## A floor's ending (v0.3.0 PLAN L4, "Boss room and portal"), advanced in tick phase 9 after spawning:
## WAITING: normal spawns run. Walking ENTRY_DEPTH_M into the boss room past the door's inner face seals the door
##   behind you (its collider, the whole passage, joins the walls), stops normal spawns and spawns the boss
##   (World.spawn_boss) where the layout says. Every normal enemy on the floor dissolves first (BossChallenge, L20),
##   and the boss room's interior becomes the arena its closing band creeps in from.
## FIGHT: when World.boss_alive() turns false, the portal opens (PORTAL_OPENED) and the door reopens (v0.5.0 PB,
##   owner D10: its collider leaves the walls; PORTAL_OPENED marks both).
## OPEN: the floor goes on (D10): the boss's drops stay, the gate(s) stay open until walked into, and the player may
##   leave the boss room to explore and fight. Normal spawns resume while the player is outside the boss room, at
##   the curve's level for the floor time (the clock never stopped); none arrive inside it (a safe spot by the
##   portal; SpawnDirector never anchors there). Re-entering never seals the door again, so the D9 heal is once.
##   Walking into the gate's opening takes the portal (FLOOR_EXIT): ENTERING holds the world still and ignores
##   input for enter_ticks while the hero is drawn in (v0.3.5 PT, F19), then the floor ends (EXITED, still).
## Arrival (v0.3.5 PT, F20): a floor after the first opens with arrive_ticks of the same hold while the hero
##   materialises; the run flow sets both lengths (set_transit), shorter with reduced motion. One clock (EI-03).
##   v0.8.0 N11 (owner O69: "the spawning enemies would be paused … there would be no main character yet"): every
##   run floor opens with it, floor 1 of a run the longest (the hero lands on the floor's receiver): the lengths are
##   data (SimTuning's arrival_*; arrival_length). While it holds nothing runs: no input acts, nothing spawns, the
##   hero can't be hit or targeted, the enemies already placed don't act, and the run's clock waits.
## Routes (v0.5.0 RT): on a run's floor before the last the room has two gates (`routes`): the gate and the Deep gate
##   (FloorLayout.deep_portal_pos). Both open together; walking into one sets route_taken once (Routes.Route) and
##   the other closes. `deep` marks a Deep floor (RunState.prepare), and epic_altar_id its epic altar.
## Ascension (v0.7.5 AP, Ascension): on a run's last floor of a loop (`ascension`) the gate is the Ascension portal.
##   v0.8.0 P2 (owner O28): no choice panel; two devices open with the boss's death: walking into the Ascension
##   portal's opening sends the hero in toward the final boss, stepping onto the Loop device (FloorLayout.loop_pos)
##   sends the hero into the next loop (enter_ascension: ENTERING, ascend_choice).
## Blink (blink_may_land): the boss room is entered only through its door, and never left or entered while sealed
## (the fight); once the boss is dead the door is open both ways (v0.5.0 PB).
## Run time keeps counting while spawns are stopped (count_time), so the floor's clock covers the boss fight.
## The door's press (v0.8.0 BD, owner O83: "opening the door now is a press button … and when opened the sound
## play"): on today's floors (`door` starts at Door.SET, RunState.prepare) the door is shut and solid from the floor's
## first tick (its collider joins the walls, Door.SHUT) until the player presses interact within DOOR_REACH_M of its
## outer face (interact(): Door.OPENING, BOSS_DOOR_OPENING); DOOR_OPEN_TICKS later the slab is down, its collider
## leaves the walls and the passage is open (Door.OPEN, BOSS_DOOR_OPENED). Walking in seals it as before. A floor
## saved before BD (floor rules 1-7) and a world built without a run keep Door.PASSAGE: the doorway open until sealed.

## Appended, never inserted: the state is hashed.
enum State { WAITING, FIGHT, OPEN, EXITED, ENTERING }
## v0.8.0 BD (O83): the boss door before the fight (appended, never inserted: hashed). PASSAGE: the doorway is open
## (a floor before BD). SET: shut, its collider joins the walls on the floor's first tick. SHUT: shut and solid.
## OPENING: pressed, the slab going down (still solid). OPEN: the passage is open (and stays so once sealed).
enum Door { PASSAGE, SET, SHUT, OPENING, OPEN }

## How far past the door's inner face (m) the player must be for the door to seal: clear of the door collider.
const ENTRY_DEPTH_M := 0.8
## The portal takes you when you stand this deep (m) in front of the gate's face, within its opening's width.
const EXIT_DEPTH_M := 1.2
## Portal transit lengths in ticks (v0.3.5 PT; starting values): the way in (~1.0 s) and the arrival (~0.8 s), and
## their reduced-motion fades.
const ENTER_TICKS := 60
const ARRIVE_TICKS := 48
const ENTER_TICKS_CALM := 24
const ARRIVE_TICKS_CALM := 18
## v0.8.0 N11 (O69; starting value): floor 1 of a run's arrival (~1.6 s), the big landing on the receiver.
const ARRIVE_FIRST_TICKS := 96
## v0.8.0 BD (O83; starting values): the door's opening, press to open (~2.7 s, the owner's opening sound's
## length), and how near its outer face (m, in front of it and along it past its sides) the press reaches.
const DOOR_OPEN_TICKS := 162
const DOOR_REACH_M := 2.2

var state := State.WAITING
## Which compiled boss World.spawn_boss gets (BossArenaSpec.boss_index).
var boss_index := 0
## Ticks of the state changes (-1 = not yet): sealed, portal opened, floor left.
var sealed_tick := -1
var opened_tick := -1
var exit_tick := -1
## Portal transit (v0.3.5 PT): the tick the portal was entered (-1 = not yet) and the way in's length; the arrival's
## length (0 = none) and the ticks of it left.
var enter_tick := -1
var enter_ticks := ENTER_TICKS
var arrive_ticks := 0
var arrive_left := 0
## v0.5.0 RT: two gates on this floor, the route taken (-1 = none yet), this floor is Deep, its epic altar's id.
var routes := false
var route_taken := -1
var deep := false
var epic_altar_id := -1
## v0.7.5 AP: the gate is the Ascension portal, and the device taken (Ascension.Choice). v0.8.0 P2: ascend_open and
## ascend_declined belonged to the retired choice panel; they stay false (kept: saved and hashed on these floors, so
## older saves load and the digests keep their shape).
var ascension := false
var ascend_open := false
var ascend_declined := false
var ascend_choice := 0
## v0.8.0 FB1 (owner O16; FINAL_BOSS.md F1): the Ascension portal (v0.8.0 P2; End the run before it) leads to the final
## boss (RunState.prepare, from the run's content: setup, not hashed): WorldReader.outcome is then 3 (the app builds the
## final arena), not 1.
var final_next := false
## v0.8.0 BD (O83): the door (Door) and the tick it was pressed (-1 = not yet).
var door := Door.PASSAGE
var door_press_tick := -1


static func create(p_boss_index: int) -> BossFlow:
	var b := BossFlow.new()
	b.boss_index = p_boss_index
	return b


## Normal spawning runs: before the boss room is entered, and after the boss died while the player is outside the
## boss room (v0.5.0 PB, D10). During the fight, and inside the boss room after it, the clock runs (count_time).
func spawns_open(w: World) -> bool:
	if state == State.WAITING:
		return true
	if state != State.OPEN:
		return false
	var f := w.floor_layout
	return f == null or f.room_of(w.player_pos()) != f.boss_room


## The door is shut: only during the fight (v0.5.0 PB: the boss's death reopens it).
func door_sealed() -> bool:
	return state == State.FIGHT


## v0.8.0 BD (O83): the door's slide before the fight, 0 (shut) .. 1 (open), from the press; -1 on a floor without
## the press (Door.PASSAGE) or once the fight began (the door is then sealed or open: door_sealed()).
func door_progress(tick: int) -> float:
	if door == Door.PASSAGE or state != State.WAITING:
		return -1.0
	if door == Door.OPEN:
		return 1.0
	if door != Door.OPENING:
		return 0.0
	return clampf(float(tick - door_press_tick) / float(DOOR_OPEN_TICKS), 0.0, 1.0)


## v0.8.0 BD (O83): the interact press would open the door now: it is shut, and `p` stands in front of its outer face
## (on the host room's side, within DOOR_REACH_M of it and of its sides).
func door_in_reach(f: FloorLayout, p: Vector2) -> bool:
	if door != Door.SHUT or state != State.WAITING or f == null or f.boss_door_index < 0:
		return false
	var half := f.door_depths[f.boss_door_index] * 0.5
	var depth := f.boss_door_depth(p)
	var n := Kin.dir(f.boss_door_angle)
	var across := absf((p - f.boss_door_center).dot(Vector2(-n.y, n.x)))
	return (
		depth <= -half + 0.05
		and depth >= -half - DOOR_REACH_M
		and across <= f.boss_door_width * 0.5 + DOOR_REACH_M * 0.5
	)


## v0.8.0 BD (O83), tick phase 2b after the shrine: a buffered interact press in reach of the shut door starts its
## opening (BOSS_DOOR_OPENING at the door). The world goes on (nothing waits for a panel).
func interact(w: World) -> void:
	var f := w.floor_layout
	if (
		w.player_dead()
		or w.buffered(InputFrame.INTERACT) == 0
		or not door_in_reach(f, w.player_pos())
	):
		return
	w.consume_buffered(InputFrame.INTERACT)
	door = Door.OPENING
	door_press_tick = w.tick
	w.emit_event(SimEvent.Kind.BOSS_DOOR_OPENING, 0, 0, 0, f.boss_door_center)


## v0.8.0 BD: the door's collider stands (SHUT or OPENING).
func _door_solid() -> bool:
	return door == Door.SHUT or door == Door.OPENING


## v0.8.0 BD (O83), phase 9 before the fight: the door's collider goes up on the floor's first tick, and comes down
## DOOR_OPEN_TICKS after the press (BOSS_DOOR_OPENED: the slab is down). Its flow field is kept for the sealing.
func _advance_door(w: World, f: FloorLayout) -> void:
	if door == Door.SET:
		door = Door.SHUT
		w.add_wall_now(f.boss_door_wall)
	elif door == Door.OPENING and w.tick - door_press_tick >= DOOR_OPEN_TICKS:
		door = Door.OPEN
		w.remove_wall_now(f.boss_door_wall, true)
		w.emit_event(SimEvent.Kind.BOSS_DOOR_OPENED, 0, 0, 0, f.boss_door_center)


## The boss room has been entered (the door sealed once): the fight began, or is over.
func boss_reached() -> bool:
	return state != State.WAITING


func portal_active() -> bool:
	return state == State.OPEN or state == State.ENTERING or state == State.EXITED


func exited() -> bool:
	return state == State.EXITED


## v0.5.0 RT: gate `route` (Routes.Route) is open: the portal is active and no route was taken, or this one was.
func gate_open(route: int) -> bool:
	if not portal_active() or (route == Routes.Route.DEEP and not routes):
		return false
	return route_taken < 0 or route_taken == route


## Setup (the run flow, before the first tick): the transit lengths, short with reduced motion (`calm`), and whether
## this floor opens with the arrival. v0.8.0 N11: `ticks` >= 0 is the arrival's length (arrival_length; the run flow's
## data), else the shipped one.
func set_transit(calm: bool, arrive: bool, ticks: int = -1) -> void:
	enter_ticks = ENTER_TICKS_CALM if calm else ENTER_TICKS
	var length := ticks if ticks >= 0 else (ARRIVE_TICKS_CALM if calm else ARRIVE_TICKS)
	arrive_ticks = length if arrive else 0
	arrive_left = arrive_ticks


## v0.8.0 N11 (O69): the arrival's length in ticks from the tuning: floor 1 of a run (`first`), a later floor, or
## either with reduced motion (`calm`: a quick fade-in).
static func arrival_length(t: SimTuning, calm: bool, first: bool) -> int:
	if calm:
		return t.arrival_calm_ticks
	return t.arrival_first_ticks if first else t.arrival_ticks


## The world stands still and takes no input: the floor is over, or the hero is going in or arriving.
func holds_world() -> bool:
	return arrive_left > 0 or state == State.ENTERING or state == State.EXITED


## Advances a held tick (World.step, instead of the rest of the tick): the arrival counts down; the way in ends the
## floor once it has run enter_ticks.
func advance_transit(w: World) -> void:
	if arrive_left > 0:
		arrive_left -= 1
	elif state == State.ENTERING and w.tick - enter_tick >= enter_ticks:
		state = State.EXITED
		exit_tick = w.tick


## 0..1 through the way in (-1 when not entering): read after a tick.
func enter_progress(tick: int) -> float:
	if state != State.ENTERING:
		return -1.0
	return clampf(float(tick - enter_tick) / float(maxi(1, enter_ticks)), 0.0, 1.0)


## v0.4.0 TU (D9): the sealing heals World.boss_room_heal_permille of max HP (never past it), with a HEAL event.
static func _entry_heal(w: World) -> void:
	var a := w.actors
	if w.boss_room_heal_permille <= 0 or w.player_dead():
		return
	var want := a.max_hp[0] * w.boss_room_heal_permille / 1000
	var applied := maxi(0, mini(want, a.max_hp[0] - a.hp[0]))
	a.hp[0] += applied
	var e := w.emit_event(SimEvent.Kind.HEAL, a.ids[0], a.ids[0], a.ids[0], w.player_pos())
	e.amount = want
	e.amount_applied = applied
	e.effect_id = &"boss_room_heal"


## 0..1 through the arrival (-1 when not arriving).
func arrive_progress() -> float:
	if arrive_left <= 0:
		return -1.0
	return 1.0 - float(arrive_left) / float(maxi(1, arrive_ticks))


## Counts run time while normal spawning is stopped (SpawnDirector counts it otherwise).
func count_time(w: World) -> void:
	if not w.player_dead() and state != State.EXITED:
		w.run_ticks += 1


func advance(w: World) -> void:
	var f := w.floor_layout
	if f == null or f.boss_room < 0 or w.player_dead():
		return
	var p := w.player_pos()
	match state:
		State.WAITING:
			_advance_door(w, f)  # v0.8.0 BD (O83)
			var inner := f.door_depths[f.boss_door_index] * 0.5 + ENTRY_DEPTH_M
			if f.room_of(p) == f.boss_room and f.boss_door_depth(p) >= inner:
				state = State.FIGHT
				sealed_tick = w.tick
				if not _door_solid():  # v0.8.0 BD: a hero put inside past the shut door (tests, the dev panel)
					w.add_wall_now(f.boss_door_wall)
				if door != Door.PASSAGE:
					door = Door.OPEN
				w.emit_event(SimEvent.Kind.BOSS_ROOM_SEALED, 0, 0, 0, f.boss_door_center)
				_entry_heal(w)  # v0.4.0 TU (owner D9): floor 1's boss room restores your HP
				BossChallenge.dissolve_floor(w)  # BX (L20): the floor's enemies dissolve.
				w.bosses.arena = f.rooms[f.boss_room]  # BX (L17): the band closes in from these walls.
				w.spawn_boss(boss_index, f.boss_spawn)
		State.FIGHT:
			if not w.boss_alive():
				state = State.OPEN
				opened_tick = w.tick
				var e := w.emit_event(SimEvent.Kind.PORTAL_OPENED, 0, 0, 0, f.portal_pos)
				e.amount = 1 if routes else 0  # v0.5.0 RT: 1 when the Deep gate opened too
				w.remove_wall_now(f.boss_door_wall)  # v0.5.0 PB (D10): the door opens both ways
		State.OPEN:
			if ascension:  # v0.8.0 P2 (O28): the Ascension portal or the Loop device, no menu
				if in_portal(f, p):
					enter_ascension(w, Ascension.Choice.ASCENSION)
				elif Ascension.on_loop_device(f, p):
					enter_ascension(w, Ascension.Choice.LOOP)
				return
			var route := -1
			if in_portal(f, p):
				route = Routes.Route.NORMAL
			elif routes and in_gate(f.deep_portal_pos, f.deep_portal_angle, p):
				route = Routes.Route.DEEP  # v0.5.0 RT
			if route >= 0:
				state = State.ENTERING
				enter_tick = w.tick
				route_taken = route
				w.emit_event(SimEvent.Kind.FLOOR_EXIT, 0, 0, 0, p).amount = route


## v0.7.5 AP: a device of the Ascension floor was taken (Ascension.Choice.ASCENSION or LOOP; v0.8.0 P2): the hero goes
## in, as through the gate (FLOOR_EXIT, amount Routes.Route.NORMAL; the next floor's route is normal).
func enter_ascension(w: World, choice: int) -> void:
	ascend_open = false
	ascend_choice = choice
	state = State.ENTERING
	enter_tick = w.tick
	route_taken = Routes.Route.NORMAL
	w.emit_event(SimEvent.Kind.FLOOR_EXIT, 0, 0, 0, w.player_pos()).amount = Routes.Route.NORMAL


## Whether a blink from `from` may land at `at` (PlayerKit.blink_target asks): crossing the boss room's boundary
## (its cells, grid line to grid line) is refused while the door is sealed, and otherwise allowed only through the
## open doorway, a straight path that touches no wall. Moves within either side are not this rule's business.
func blink_may_land(w: World, from: Vector2, at: Vector2) -> bool:
	var f := w.floor_layout
	if f == null or f.boss_room < 0:
		return true
	var area := f.boss_cells_rect
	if area.has_point(from) == area.has_point(at):
		return true
	if door_sealed():
		return false
	for wall in w.walls:
		if Collide.sweep_vs_obb(from, at, 0.0, wall) != Collide.NO_HIT:
			return false
	return true


## p stands in the gate's opening: within EXIT_DEPTH_M of its face and within its width.
static func in_portal(f: FloorLayout, p: Vector2) -> bool:
	return in_gate(f.portal_pos, f.portal_angle, p)


## p stands in the opening of a gate at `pos` facing `angle`.
static func in_gate(pos: Vector2, angle: int, p: Vector2) -> bool:
	var n := Kin.dir(angle)
	var d := p - pos
	var depth := d.dot(n) - FloorLayout.GATE_HALF_DEPTH
	var across := absf(d.dot(Vector2(-n.y, n.x)))
	return depth >= 0.0 and depth <= EXIT_DEPTH_M and across <= FloorLayout.GATE_WIDTH * 0.5


func hash_into(h: StateHasher) -> void:
	for v in [state, boss_index, sealed_tick, opened_tick, exit_tick]:
		h.add_int(v)
	for v in [enter_tick, enter_ticks, arrive_ticks, arrive_left]:  # v0.3.5 PT
		h.add_int(v)
	for v in [1 if routes else 0, route_taken, 1 if deep else 0, epic_altar_id]:  # v0.5.0 RT
		h.add_int(v)
	if ascension:  # v0.7.5 AP: only the Ascension portal's floors, so every other floor hashes as before
		for v in [1, 1 if ascend_open else 0, 1 if ascend_declined else 0, ascend_choice]:
			h.add_int(v)
	if door != Door.PASSAGE:  # v0.8.0 BD: only the press's floors, so a floor before BD hashes as before
		for v in [2, door, door_press_tick]:
			h.add_int(v)
