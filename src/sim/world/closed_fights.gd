class_name ClosedFights
extends RefCounted
## v0.9.0 CF (owner: "lets never make it a 1x1 it is too small and so many enemies appear, the enemies that spawn at
## the same time should be proportional to the room size, where smaller rooms are a challenge but not impossible
## crazy"): what the closed fights share (the arenas and the Overrun room, Arenas; the Lockdowns, Lockdowns; the Chaos
## shrine's challenge, Shrines).
## - The room: a closed fight never takes a room of fewer than its kind's min_cells grid cells (the data; 2: never a
##   1 x 1). ArenaRooms, OverrunRooms and LockdownRooms skip such rooms, and the Chaos kind is not drawn for a shrine
##   standing in one (Shrines.setup). No room fits: that fight is not on the floor.
## - Enemies at once: a fight's members are drawn as before (the same draws in the same order), but only as many come
##   out together as the room's floor area allows: cap() = the room's area / its kind's area_per_enemy_m2 (the data),
##   at least 1, the members weighed by weight() (an elite counts EliteRules.elite_weight). The rest wait in the
##   fight's queue (its state's later_kinds, later_pos: snapshotted and hashed) and come in as earlier ones die
##   (refill), so the fight's total and its clear rule stay. A member always comes out when nothing is out (an elite
##   heavier than a small room's cap still comes, alone). A big room's cap is over every wave's size: it fights as
##   before, tick for tick.
## Pure sim code.

## No budget (area_per_enemy_m2 <= 0): no cap.
const NO_CAP := 1 << 20
## A queued member comes in at its own spot unless it is this close to the hero (m); then at the room's spawn point
## nearest it that isn't (the fights' own spawn distance).
const MIN_HERO_M := 2.5


## Whether run `run`'s current floor was built before CF (floor rules 1-15): it is rebuilt with the rooms it had
## (its kinds' min_cells read as 0). False for today's floors and a floor without a run.
static func legacy_rooms(run: RunState) -> bool:
	return run != null and run.floor_rules <= RunState.FLOOR_RULES_V090_EL


## Room `room`'s floor area (m2): its interior rect, wall face to wall face.
static func area_m2(f: FloorLayout, room: int) -> float:
	if f == null or room < 0 or room >= f.rooms.size():
		return 0.0
	return f.rooms[room].size.x * f.rooms[room].size.y


## The at-once cap (in weight) in a room of `area` m2 at `per` m2 an enemy: area / per rounded down, at least 1.
static func cap_for(area: float, per: float) -> int:
	if per <= 0.0:
		return NO_CAP
	return maxi(1, int(area / per))


static func cap(f: FloorLayout, room: int, per: float) -> int:
	return cap_for(area_m2(f, room), per)


## Whether room `room` is big enough for a closed fight needing `min_cells` grid cells (0: any room).
static func fits(f: FloorLayout, room: int, min_cells: int) -> bool:
	return min_cells <= 0 or (room < f.room_cells.size() and f.room_cell_count(room) >= min_cells)


## An elite's weight (EliteRules.elite_weight; 3 without rules).
static func elite_weight(w: World) -> int:
	return maxi(1, w.elite_rules.elite_weight if w.elite_rules != null else 3)


## Actor i's weight: an elite's (elite_weight), else 1.
static func weight(w: World, i: int) -> int:
	if w.elites != null and w.elites.ids.has(w.actors.ids[i]):
		return elite_weight(w)
	return 1


## A queued member's weight (an elite's kind is stored as -1 - kind).
static func queued_weight(w: World, kind: int) -> int:
	return elite_weight(w) if kind < 0 else 1


## Whether a member of weight `wt` comes out now with `out` already out under `limit`: it fits, or nothing is out.
static func may_add(out: int, wt: int, limit: int) -> bool:
	return out <= 0 or out + wt <= limit


## How many of `kinds` (in order) come out at once under `limit`, none out yet.
static func first_batch(w: World, kinds: PackedInt32Array, limit: int) -> int:
	var out := 0
	var n := 0
	for k in kinds:
		var wt := queued_weight(w, k)
		if not may_add(out, wt, limit):
			break
		out += wt
		n += 1
	return n


## Where a queued member comes in: its own spot, unless it is within MIN_HERO_M of the hero; then the room's spawn
## point nearest it that isn't (its own spot when none is).
static func refill_spot(w: World, room: int, at: Vector2) -> Vector2:
	var p := w.player_pos()
	if Kin.length(at - p) >= MIN_HERO_M:
		return at
	var f := w.floor_layout
	var best := at
	var best_d := -1.0
	if room >= 0 and room < f.spawn_points.size():
		for q in f.spawn_points[room]:
			if Kin.length(q - p) < MIN_HERO_M:
				continue
			var d := Kin.length(q - at)
			if best_d < 0.0 or d < best_d:
				best = q
				best_d = d
	return best
