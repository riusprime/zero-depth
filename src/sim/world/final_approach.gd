class_name FinalApproach
extends RefCounted
## v0.9.0 FA (owner C §3: "reaching the final boss should initiate a short transition to a dedicated approach floor …
## The player must activate a small number of mechanisms, approximately two, around the altar. Once activated, the
## purple runes illuminate and begin spinning. A buildup animation begins … The final boss encounter is initiated";
## "The boss sequence must only trigger once the required activations are complete"; Q18: "Press once", "On the altar
## plateau", "Stair causeway"): the final approach's flow, in ticks (EI-03), on the approach's floor
## (FinalArena.approach_layout). World.approach holds it (null in every other world).
## - WALK: the hero walks up the causeway (no enemies, no tiers, no shards); each of the two rune pylons
##   (FloorLayout.pylons) switches on with one interact press within PYLON_REACH_M (order free; a lit one ignores the
##   press). The first lights its share of the altar's runes; the second starts the buildup.
## - BUILDUP: buildup_ticks (about 3 s) of the purple altar's sequence (the views read buildup_progress).
## - FIGHT: the buildup ended: the walls of light (FloorLayout.light_walls) close the plateau's ring (a hero still out
##   on the causeway is set back inside first, at the plateau's edge by the causeway's top), and the Colossus rises
##   from the altar (FinalBoss.begin): today's fight, unchanged.
## v0.9.0 IX: the pylons are entries of the shared interactable registry (Interactables, Kind.PYLON, ref k, reach
## PYLON_REACH_M; register()): the registry's slot in World.step's order (after the boss door's) picks the press and
## calls press(); the HUD's shared prompt shows APPROACH_PYLON_PROMPT by an unlit one. A lit pylon's entry is disabled.
## Pure: no stream is drawn.

enum State { WALK, BUILDUP, FIGHT }

## How near a pylon (m) the press reaches.
const PYLON_REACH_M := 2.0
## The buildup's length (ticks, ~3 s; owner Q18 "a modified version of the starting altar sequence").
const BUILDUP_TICKS := 180
## How far in from the ring (m) a hero still on the causeway is set when the walls rise.
const EDGE_IN := 1.5

var state := State.WALK
## Each pylon's switch: 0 off, 1 on; and the tick it was pressed (-1 not yet).
var lit := PackedByteArray([0, 0])
var lit_tick := PackedInt32Array([-1, -1])
## The tick the buildup began (-1 not yet), its length, and the tick the walls rose and the fight began.
var buildup_tick := -1
var buildup_ticks := BUILDUP_TICKS
var fight_tick := -1
## The fight's bodies (indices into World.boss_tables), its shatter length and its name (FinalArenaScenario's).
var tables := PackedInt32Array()
var shatter_ticks := 0
var name_key := &""


static func create(
	p_tables: PackedInt32Array, p_shatter_ticks: int, p_name_key: StringName
) -> FinalApproach:
	var a := FinalApproach.new()
	a.tables = p_tables
	a.shatter_ticks = p_shatter_ticks
	a.name_key = p_name_key
	return a


## How many pylons are on.
func lit_count() -> int:
	var n := 0
	for v in lit:
		n += v
	return n


## Registers the pylons into `w`'s interactable registry (setup, after create; FinalArenaScenario).
func register(w: World) -> void:
	var f := w.floor_layout
	for k in f.pylons.size():
		w.interactables.add(Interactables.Kind.PYLON, f.pylons[k], PYLON_REACH_M, k)
	sync_registry(w)


## The registry's pylon entries follow `lit` (a lit one is on and takes no press; none takes one past WALK). A restore
## of a save from before IX (no registry) runs it once.
func sync_registry(w: World) -> void:
	var r := w.interactables
	for k in lit.size():
		var i := r.find(Interactables.Kind.PYLON, k)
		if i >= 0:
			r.state[i] = lit[k]
			r.enabled[i] = 1 if lit[k] == 0 and state == State.WALK else 0


## The pylon (0 or 1) the interact press would switch on now from `w`'s hero, or -1 (the registry's pick).
func in_reach(w: World) -> int:
	if state != State.WALK or w.floor_layout == null:
		return -1
	var i := w.interactables.in_reach(w.player_pos())
	if i < 0 or w.interactables.kind[i] != Interactables.Kind.PYLON:
		return -1
	return w.interactables.ref[i]


## The press on pylon k (Interactables.handle): it switches on; the second starts the buildup.
func press(w: World, k: int) -> void:
	if state != State.WALK or lit[k] == 1:
		return
	lit[k] = 1
	lit_tick[k] = w.tick
	if lit_count() >= lit.size():
		state = State.BUILDUP
		buildup_tick = w.tick
	sync_registry(w)


## Tick phase 9 (before FinalBoss.advance): the buildup's end raises the walls and begins the fight.
func advance(w: World) -> void:
	if state != State.BUILDUP or w.tick - buildup_tick < buildup_ticks:
		return
	state = State.FIGHT
	fight_tick = w.tick
	var f := w.floor_layout
	var r := FinalArena.radius_of(f)
	if Kin.length(w.player_pos() - f.altar_pos) > r - EDGE_IN:  # still out on the causeway: back on the plateau
		var axis := Kin.dir(FinalArena.START_ANGLE)
		w.actors.set_pos(0, f.altar_pos + axis * (r - EDGE_IN))
		w.vel = Vector2.ZERO
	w.add_walls_now(f.light_walls)
	FinalBoss.begin(w, tables, shatter_ticks, f.boss_spawn)
	w.final_fight.name_key = name_key


## 0..1 through the buildup, -1 outside it.
func buildup_progress(tick: int) -> float:
	if state != State.BUILDUP:
		return -1.0
	return clampf(float(tick - buildup_tick) / float(maxi(1, buildup_ticks)), 0.0, 1.0)


func hash_into(h: StateHasher) -> void:
	h.add_int(state)
	for v in lit:
		h.add_int(v)
	for t in lit_tick:
		h.add_int(t)
	h.add_int(buildup_tick)
	h.add_int(buildup_ticks)
	h.add_int(fight_tick)
