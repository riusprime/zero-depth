class_name BossFlow
extends RefCounted
## A floor's ending (v0.3.0 PLAN L4, "Boss room and portal"), advanced in tick phase 9 after spawning:
## WAITING: normal spawns run. Walking ENTRY_DEPTH_M into the boss room past the door's inner face seals the door
##   behind you (its collider, the whole passage, joins the walls), stops normal spawns and spawns the boss
##   (World.spawn_boss) where the layout says. Every normal enemy on the floor dissolves first (BossChallenge, L20),
##   and the boss room's interior becomes the arena its closing band creeps in from.
## FIGHT: when World.boss_alive() turns false, the portal opens (PORTAL_OPENED).
## OPEN: walking into the gate's opening takes the portal (FLOOR_EXIT): ENTERING holds the world still and ignores
##   input for enter_ticks while the hero is drawn in (v0.3.5 PT, F19), then the floor ends (EXITED, still).
## Arrival (v0.3.5 PT, F20): a floor after the first opens with arrive_ticks of the same hold while the hero
##   materialises; the run flow sets both lengths (set_transit), shorter with reduced motion. One clock (EI-03).
## Blink (blink_may_land): the boss room is entered only through its door, and never left or entered while sealed.
## Run time keeps counting while spawns are stopped (count_time), so the floor's clock covers the boss fight.

## Appended, never inserted: the state is hashed.
enum State { WAITING, FIGHT, OPEN, EXITED, ENTERING }

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


static func create(p_boss_index: int) -> BossFlow:
	var b := BossFlow.new()
	b.boss_index = p_boss_index
	return b


func spawns_open() -> bool:
	return state == State.WAITING


func door_sealed() -> bool:
	return state != State.WAITING


func portal_active() -> bool:
	return state == State.OPEN or state == State.ENTERING or state == State.EXITED


func exited() -> bool:
	return state == State.EXITED


## Setup (the run flow, before the first tick): the transit lengths, short with reduced motion (`calm`), and whether
## this floor opens with the arrival.
func set_transit(calm: bool, arrive: bool) -> void:
	enter_ticks = ENTER_TICKS_CALM if calm else ENTER_TICKS
	arrive_ticks = (ARRIVE_TICKS_CALM if calm else ARRIVE_TICKS) if arrive else 0
	arrive_left = arrive_ticks


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
			var inner := f.door_depths[f.boss_door_index] * 0.5 + ENTRY_DEPTH_M
			if f.room_of(p) == f.boss_room and f.boss_door_depth(p) >= inner:
				state = State.FIGHT
				sealed_tick = w.tick
				w.add_wall_now(f.boss_door_wall)
				w.emit_event(SimEvent.Kind.BOSS_ROOM_SEALED, 0, 0, 0, f.boss_door_center)
				BossChallenge.dissolve_floor(w)  # BX (L20): the floor's enemies dissolve.
				w.bosses.arena = f.rooms[f.boss_room]  # BX (L17): the band closes in from these walls.
				w.spawn_boss(boss_index, f.boss_spawn)
		State.FIGHT:
			if not w.boss_alive():
				state = State.OPEN
				opened_tick = w.tick
				w.emit_event(SimEvent.Kind.PORTAL_OPENED, 0, 0, 0, f.portal_pos)
		State.OPEN:
			if in_portal(f, p):
				state = State.ENTERING
				enter_tick = w.tick
				w.emit_event(SimEvent.Kind.FLOOR_EXIT, 0, 0, 0, p)


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
	var n := f.portal_facing()
	var d := p - f.portal_pos
	var depth := d.dot(n) - FloorLayout.GATE_HALF_DEPTH
	var across := absf(d.dot(Vector2(-n.y, n.x)))
	return depth >= 0.0 and depth <= EXIT_DEPTH_M and across <= FloorLayout.GATE_WIDTH * 0.5


func hash_into(h: StateHasher) -> void:
	for v in [state, boss_index, sealed_tick, opened_tick, exit_tick]:
		h.add_int(v)
	for v in [enter_tick, enter_ticks, arrive_ticks, arrive_left]:  # v0.3.5 PT
		h.add_int(v)
