class_name BossFlow
extends RefCounted
## A floor's ending (v0.3.0 PLAN L4, "Boss room and portal"), advanced in tick phase 9 after spawning:
## WAITING: normal spawns run. Walking ENTRY_DEPTH_M into the boss room past the door's inner face seals the door
##   behind you (its collider, the whole passage, joins the walls), stops normal spawns and spawns the boss
##   (World.spawn_boss) where the layout says.
## FIGHT: when World.boss_alive() turns false, the portal opens (PORTAL_OPENED).
## OPEN: walking into the gate's opening ends the floor (FLOOR_EXIT); the world then stands still (EXITED).
## Blink (blink_may_land): the boss room is entered only through its door, and never left or entered while sealed.
## Run time keeps counting while spawns are stopped (count_time), so the floor's clock covers the boss fight.

enum State { WAITING, FIGHT, OPEN, EXITED }

## How far past the door's inner face (m) the player must be for the door to seal: clear of the door collider.
const ENTRY_DEPTH_M := 0.8
## The portal takes you when you stand this deep (m) in front of the gate's face, within its opening's width.
const EXIT_DEPTH_M := 1.2

var state := State.WAITING
## Which compiled boss World.spawn_boss gets (BossArenaSpec.boss_index).
var boss_index := 0
## Ticks of the state changes (-1 = not yet): sealed, portal opened, floor left.
var sealed_tick := -1
var opened_tick := -1
var exit_tick := -1


static func create(p_boss_index: int) -> BossFlow:
	var b := BossFlow.new()
	b.boss_index = p_boss_index
	return b


func spawns_open() -> bool:
	return state == State.WAITING


func door_sealed() -> bool:
	return state != State.WAITING


func portal_active() -> bool:
	return state == State.OPEN or state == State.EXITED


func exited() -> bool:
	return state == State.EXITED


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
				w.spawn_boss(boss_index, f.boss_spawn)
		State.FIGHT:
			BossStub.advance(w)  # STUB: C removes this line (the real boss emits BOSS_DEFEATED itself).
			if not w.boss_alive():
				state = State.OPEN
				opened_tick = w.tick
				w.emit_event(SimEvent.Kind.PORTAL_OPENED, 0, 0, 0, f.portal_pos)
		State.OPEN:
			if in_portal(f, p):
				state = State.EXITED
				exit_tick = w.tick
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
