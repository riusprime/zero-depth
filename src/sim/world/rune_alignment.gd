class_name RuneAlignment
extends RefCounted
## v0.9.0 RA (owner W §4 A: "Several rune pillars can be rotated. The player aligns symbols according to a visual clue
## to unlock a reward"; Q22 "3 pillars, 4 faces (Recommended)": interact turns one a quarter, a carving on the wall
## shows the 3 symbols to match, solved opens a chest or a hidden room; Q22 puzzle calm; Q23 the hidden room unseen
## until it opens; W3 understood in under 5 s, solved in under 30 s): the floor's rune puzzle. World.runes holds it
## (null on a floor without one; FloorLayout.rune_* from RuneRooms.mark).
## - The three pillars are shared interactables (Interactables.Kind.RUNE_PILLAR, PILLAR_REACH_M); an entry's state is
##   the face it shows (0..3), its ref the pillar's index. A press turns it a quarter (face + 1, mod 4). No time limit.
## - The carving (on the slab that seals the hidden room's doorway) shows each pillar's target
##   (FloorLayout.rune_target). When every pillar shows its target the puzzle is solved: the pillars take no more
##   presses, the slab is gone for good, the hidden room (its reward: an epic altar or a chest,
##   Secrets.place_reward from `loot:rune_alignment`) is open and seen, and the host room's puzzle calm ends.
## - The slab stands as a barrier from the floor's first tick (World.add_barrier, as the timed door's) until solved.
## The views read the faces, the targets, the pillars' press ticks (the grind) and solve_tick (the flare).

const PILLAR_REACH_M := 1.8
const REWARD_STREAM := "loot:rune_alignment"

## The pillars' entries in World.interactables (pillar k: pillars[k]), and the host room's calm entry.
var pillars := PackedInt32Array()
var target := PackedInt32Array()
var calm_k := -1
## 1 once every pillar shows its target, and the tick it did (-1 not yet).
var solved := 0
var solve_tick := -1
## 1 while the slab stands as a barrier in World.walls.
var wall_up := 0
## The hidden room's reward (its id, -1 none) and whether it is an epic altar.
var reward_id := -1
var reward_epic := 0


## Sets up `w`'s rune puzzle (setup, after the floor's rewards, events, shrine, shop and timed door are placed): marks
## the layout (RuneRooms.mark: `chance_permille` of floors), registers the pillars and the calm room, drops the hidden
## room's spawn spots and places its reward. No-op on a floor that gets none.
static func setup(w: World, chance_permille: int) -> void:
	var f := w.floor_layout
	if f == null:
		return
	if RuneRooms.mark(f, chance_permille, Secrets.taken_rooms(w), Secrets.avoid_spots(w)) < 0:
		return
	var r := RuneAlignment.new()
	r.target = f.rune_target.duplicate()
	for k in f.rune_pillars.size():
		var i := w.interactables.add(
			Interactables.Kind.RUNE_PILLAR, f.rune_pillars[k], PILLAR_REACH_M + w.solids.bonus(), k
		)
		w.interactables.state[i] = f.rune_start[k]
		w.solids.add_square(Solids.Kind.RUNE_PILLAR, k, f.rune_pillars[k])  # v0.9.5 SB
		r.pillars.append(i)
	r.calm_k = w.interactables.add_calm_room(f.rune_host)
	Secrets.drop_spawns(w, f.rune_room)
	w.runes = r
	var got := Secrets.place_reward(w, f.rune_room, REWARD_STREAM)
	r.reward_id = got.x
	r.reward_epic = got.y


## The press on registry entry i (Interactables.handle): the pillar turns a quarter; the last match solves it.
static func press(w: World, i: int) -> void:
	var r := w.runes
	var reg := w.interactables
	if r == null or r.solved == 1:
		return
	reg.state[i] = (reg.state[i] + 1) % RuneRooms.FACES
	if not r.all_aligned(reg):
		return
	r.solved = 1
	r.solve_tick = w.tick
	for p in r.pillars:
		reg.enabled[p] = 0
	reg.solve_calm(r.calm_k)  # Q22: solved, normal spawning there from now on
	if r.wall_up == 1:
		var slab: Array[Obb] = [w.floor_layout.rune_door_wall]
		w.remove_barriers(slab)
		r.wall_up = 0


## Tick phase 9: the slab stands until solved.
static func advance(w: World) -> void:
	var r := w.runes
	if r != null and r.solved == 0 and r.wall_up == 0:
		w.add_barrier(w.floor_layout.rune_door_wall)
		r.wall_up = 1


## Every pillar shows its target face.
func all_aligned(reg: Interactables) -> bool:
	for k in pillars.size():
		if reg.state[pillars[k]] != target[k]:
			return false
	return true


func hash_into(h: StateHasher) -> void:
	for v in [calm_k, solved, solve_tick, wall_up, reward_id, reward_epic]:
		h.add_int(v)
	h.add_ints(pillars)
	h.add_ints(target)
