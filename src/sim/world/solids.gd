class_name Solids
extends RefCounted
## v0.9.5 SB (owner: "Some models you can just go through ... lets make sure ... they have the 3D and feel like they
## have actual height and you can't just go through them"): the footprints of props that look solid. Each entry is an
## oriented box that blocks ACTORS (the hero and the enemies: World's wall pass and the enemies' steering) once the
## hero is clear of it (CLEAR_M from its surface), so a prop that appears under the hero's feet never traps them, and
## leaves with its owner (remove). They are NOT in World.walls: shots, beams, glaives, bombs, area attacks and lines of
## sight pass over them, as over the shrine and the fountain. A world holds them only under floor rules after
## FLOOR_RULES_V090_CF2 (`on`): a floor saved before SB has none. Pure: no stream is drawn.

## Owners of an entry (with the owner's own ref).
enum Kind { REWARD, EVENT, PYLON, RUNE_PILLAR, DAIS, MURAL, ASCENSION, LOOP_DEVICE, ARRIVAL }

## Half the side of a 1.2 m prop (altars, chests, pedestals, pillars, the dais, the mural's plinth).
const PROP_HALF_M := 0.6
## Half the side of a pylon (1 m).
const PYLON_HALF_M := 0.5
## How far (m) from its surface the hero must be before an entry becomes a wall.
const CLEAR_M := 0.5
## The free circle (m) kept at a room's doorways and their approaches (clear_of_doors).
const DOOR_CLEAR_M := 0.6

var on := false
var kind := PackedInt32Array()
var ref := PackedInt32Array()
var center := PackedVector2Array()
var half := PackedVector2Array()
var angle := PackedInt32Array()
var placed := PackedByteArray()


## Whether a run's current floor uses the solids (a new floor; a world built with no run, as the tests do, has none).
static func rules_on(run: RunState) -> bool:
	return run != null and run.floor_rules > RunState.FLOOR_RULES_V090_CF2


func size() -> int:
	return kind.size()


func is_empty() -> bool:
	return kind.is_empty()


func obb(i: int) -> Obb:
	return Obb.make(center[i], half[i], angle[i])


func find(p_kind: int, p_ref: int) -> int:
	for i in kind.size():
		if kind[i] == p_kind and ref[i] == p_ref:
			return i
	return -1


## How many entries stand as walls now.
func placed_count() -> int:
	var n := 0
	for v in placed:
		n += v
	return n


## Registers an entry (no-op when `on` is false or the owner already holds one). It becomes a wall in step().
func add(p_kind: int, p_ref: int, p_center: Vector2, p_half: Vector2, p_angle: int = 0) -> void:
	if not on or find(p_kind, p_ref) >= 0:
		return
	kind.append(p_kind)
	ref.append(p_ref)
	center.append(p_center)
	half.append(p_half)
	angle.append(p_angle & 4095)
	placed.append(0)


## A square prop of half-side `h` at `p`.
func add_square(p_kind: int, p_ref: int, p: Vector2, h: float = PROP_HALF_M) -> void:
	add(p_kind, p_ref, p, Vector2(h, h), 0)


## Drops the owner's entry (and its wall).
func remove(_w: World, p_kind: int, p_ref: int) -> void:
	var i := find(p_kind, p_ref)
	if i < 0:
		return
	kind.remove_at(i)
	ref.remove_at(i)
	center.remove_at(i)
	half.remove_at(i)
	angle.remove_at(i)
	placed.remove_at(i)


## The extra interact reach (m) a prop of this entry's size needs: its half-extent (0 without an entry).
static func reach_bonus(w: World, p_kind: int, p_ref: int) -> float:
	var i := w.solids.find(p_kind, p_ref)
	return maxf(w.solids.half[i].x, w.solids.half[i].y) if i >= 0 else 0.0


## v0.9.5 SB (generation safety): `p`, a prop of half-side `h` placed on a spawn spot, moved just far enough that its
## footprint leaves a 0.6 m circle (the hero and 0.2 m to spare) free at each of its room's doorways and their
## approaches. Unchanged when it already does (and when the solids are off).
func clear_of_doors(f: FloorLayout, p: Vector2, h: float = PROP_HALF_M) -> Vector2:
	if not on or f == null:
		return p
	var room := f.room_of(p)
	if room < 0:
		return p
	var pts := PackedVector2Array(f.door_centers)
	pts.append_array(f.door_approaches(room, 1.0))
	var inside := f.rooms[room].grow(-h)
	for pass_k in 6:
		var moved := false
		for q in pts:
			var push := Collide.circle_vs_obb(q, DOOR_CLEAR_M, Obb.make(p, Vector2(h, h), 0))
			if push != Vector2.ZERO:
				p = Vector2(
					clampf(p.x - push.x, inside.position.x, inside.end.x),
					clampf(p.y - push.y, inside.position.y, inside.end.y)
				)
				moved = true
		if not moved:
			break
	return p


## Tick (World.step, before movement): every entry the hero is clear of becomes a wall.
static func step(w: World) -> void:
	var s := w.solids
	if s.kind.is_empty() or s.placed_count() == s.kind.size():
		return
	var p := w.player_pos()
	var r := w.actors.radius[0] + CLEAR_M
	for i in s.kind.size():
		if s.placed[i] == 0:
			var o := s.obb(i)
			if Collide.circle_vs_obb(p, r, o) == Vector2.ZERO:
				s.placed[i] = 1


func hash_into(h: StateHasher) -> void:
	for i in kind.size():
		h.add_int(kind[i])
		h.add_int(ref[i])
		h.add_int(placed[i])


## The reach a prop of half-side `h` adds to its interact reach (0 when the solids are off).
func bonus(h: float = PROP_HALF_M) -> float:
	return h if on else 0.0


## The standing footprints' push on a circle of radius r at `at` (the sum over the entries it overlaps).
func push(at: Vector2, r: float) -> Vector2:
	var out := Vector2.ZERO
	for i in kind.size():
		if placed[i] == 1:
			var reach := r + half[i].length()
			if absf(at.x - center[i].x) <= reach and absf(at.y - center[i].y) <= reach:
				out += Collide.circle_vs_obb(at + out, r, obb(i))
	return out


## Whether a standing footprint may touch the box `rect`.
func any_near(rect: Rect2) -> bool:
	for i in kind.size():
		if placed[i] == 1 and rect.grow(half[i].length()).has_point(center[i]):
			return true
	return false


## Whether a body of radius r sweeping from a to b meets a standing footprint (the enemies' steering).
func blocks(a: Vector2, b: Vector2, r: float) -> bool:
	for i in kind.size():
		if placed[i] == 1 and Collide.sweep_vs_obb(a, b, r, obb(i)) >= 0.0:
			return true
	return false
