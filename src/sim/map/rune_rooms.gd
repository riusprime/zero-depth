class_name RuneRooms
extends RefCounted
## v0.9.0 RA (owner W §4 A: "Several rune pillars can be rotated. The player aligns symbols according to a visual clue
## to unlock a reward"; Q22 "3 pillars, 4 faces"; Q23 the hidden room unseen until it opens; W3 "understood in under
## 5 s, solved in under 30 s"): the floor's rune puzzle, chosen after the floor, its rooms' kinds and the timed door are
## set (RuneAlignment.setup), from the rooms already generated, so the floor's walls and draws stay as they were:
## - on chance_permille of the floors (a draw from the `map:rune_alignment` sub-stream of the floor seed), one dead-end
##   room (one doorway, to one room) becomes the puzzle's hidden room, by TimedDoorRooms' rules (never the start hall,
##   the boss room, its host, the portal room, the Overrun room, the shop's room, the curse room, an arena or a room in
##   `taken`); never the timed door's secret room or its host, and its host is never either (a floor holds both only
##   when both fit); its one doorway is sealed by a slab carrying the carving (the clue);
## - the room before it (the host) holds the three pillars, on three of its spawn spots PILLAR_GAP_M apart,
##   DOOR_GAP_M from its doorways' approaches and AVOID_M from `avoid` (rewards, pedestals, the shrine, the timed
##   door's switches) and its item spots, at most PILLAR_SPAN_M apart and CARVING_M from the sealed doorway; the
##   spots are drawn from the same sub-stream;
## - the faces: each pillar's target (the carving's symbol, 0..3) and its start, drawn from the sub-stream so that no
##   pillar starts solved and each is solved in at most FACES - 1 = 3 quarter turns (start = target + 1..3, mod 4);
## - a dead end is never on the way anywhere (the property test: every other room stays reachable without it).
## Pure sim code: integers and the doorway graph.

const STREAM := "map:rune_alignment"
const PILLARS := 3
const FACES := 4
const PILLAR_GAP_M := 2.5
const DOOR_GAP_M := 2.5
const AVOID_M := 3.0
## W3 (solved in under 30 s, the clue in sight): the pillars stand at most PILLAR_SPAN_M from each other and
## CARVING_M from the sealed doorway that carries the carving.
const PILLAR_SPAN_M := 10.0
const CARVING_M := 12.0


## Marks `f`'s rune puzzle (FloorLayout.rune_*). Returns the hidden room, or -1.
static func mark(
	f: FloorLayout, chance_permille: int, taken: PackedInt32Array, avoid: PackedVector2Array
) -> int:
	clear(f)
	var rng := RngStream.derive(f.seed_value, STREAM)
	if not rng.chance_permille(chance_permille):
		return -1
	var cands := PackedInt32Array()
	var busy := PackedInt32Array([f.timed_room, f.timed_host])
	for room in TimedDoorRooms.candidates(f, taken):
		var host := host_of(f, room)
		if not room in busy and not host in busy:
			cands.append(room)
	_shuffle(cands, rng)
	var all_avoid := avoid.duplicate()
	all_avoid.append_array(f.timed_switches)
	for room in cands:
		var door := TimedDoorRooms.only_door(f, room)
		var host := host_of(f, room)
		var spots := pillar_spots(f, host, door, all_avoid, rng)
		if spots.size() != PILLARS:
			continue
		f.rune_room = room
		f.rune_host = host
		f.rune_door = door
		f.rune_pillars = spots
		f.rune_door_wall = TimedDoorRooms.door_wall(f, door)
		for k in PILLARS:
			var target := rng.range_int(0, FACES - 1)
			f.rune_target.append(target)
			f.rune_start.append((target + rng.range_int(1, FACES - 1)) % FACES)
		return room
	return -1


## No rune puzzle (the fields' defaults).
static func clear(f: FloorLayout) -> void:
	f.rune_room = -1
	f.rune_host = -1
	f.rune_door = -1
	f.rune_pillars = PackedVector2Array()
	f.rune_target = PackedInt32Array()
	f.rune_start = PackedInt32Array()
	f.rune_door_wall = null


## The one room a dead end's doorway leads to.
static func host_of(f: FloorLayout, room: int) -> int:
	var door := TimedDoorRooms.only_door(f, room)
	return f.door_rooms[door].x if f.door_rooms[door].y == room else f.door_rooms[door].y


## Quarter turns (the presses) pillar k needs from face `from` to its target.
static func presses_needed(from: int, target: int) -> int:
	return posmod(target - from, FACES)


## Three pillar spots in `host` (drawn from rng) passing the rules, or fewer when none do.
static func pillar_spots(
	f: FloorLayout, host: int, door: int, avoid: PackedVector2Array, rng: RngStream
) -> PackedVector2Array:
	var ok := PackedVector2Array()
	var approaches := f.door_approaches(host, 1.0)
	var carving := PackedVector2Array([f.door_centers[door]])
	for q in f.spawn_points[host]:
		if _far(q, approaches, DOOR_GAP_M) and _far(q, avoid, AVOID_M):
			if _far(q, f.item_spots, AVOID_M) and _near(q, carving, CARVING_M):
				ok.append(q)
	if ok.size() < PILLARS:
		return PackedVector2Array()
	for k in range(ok.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := ok[k]
		ok[k] = ok[j]
		ok[j] = swap
	for a in ok:
		var out := PackedVector2Array([a])
		for q in ok:
			if _far(q, out, PILLAR_GAP_M) and _near(q, out, PILLAR_SPAN_M):
				out.append(q)
				if out.size() == PILLARS:
					return out
	return PackedVector2Array()


static func _shuffle(a: PackedInt32Array, rng: RngStream) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := a[k]
		a[k] = a[j]
		a[j] = swap


static func _near(q: Vector2, points: PackedVector2Array, span: float) -> bool:
	for p in points:
		if Kin.length(p - q) > span:
			return false
	return true


static func _far(q: Vector2, points: PackedVector2Array, gap: float) -> bool:
	for p in points:
		if Kin.length(p - q) < gap:
			return false
	return true
