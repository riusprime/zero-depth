class_name PurpleRunes
extends RefCounted
## v0.9.0 DP (owner Q26b: "the purple portal should be linked to one of the new puzzles or events, not be there as
## default"; "one of the event rooms, in a big room, has activation purple runes, that make the screen shake so you know
## something happened, but then when you kill the boss the purple portal appears"): the floor's purple-rune room.
## World.purple holds it (null on a floor without one; FloorLayout.purple_* from PurpleRooms.mark).
## - The dais is one shared interactable (Interactables.Kind.PURPLE_DAIS, DAIS_REACH_M; the prompt "Awaken", FA's
##   pylons' string). One press awakens the runes for good: the entry is disabled, its state 1, `lit` set.
## - Awakened, the floor has earned the Purple Portal (earn): BossFlow.routes is set, so the boss's death opens the
##   Deep gate beside the gate (BossFlow.PORTAL_OPENED amount 1), and the Deep gate's footprint (placed at build by
##   Routes.place_deep_gate, as before) stands as a barrier from then on, as the gate's does (World.add_barrier; the
##   hero is in the purple room, never the boss room, when it is added). Awakened after the boss died, the Deep gate
##   opens at once. Unawakened, the floor has no Deep gate at all.
## - A floor needs a spot for the Deep gate to hold the runes (setup is a no-op without one).
## The views read the dais, lit and lit_tick (the runes lighting in turn, the vibration, the `purple_runes` sound).

const DAIS_REACH_M := 1.8

## The dais's entry in World.interactables.
var entry := -1
## 1 once awakened, and the tick it was (-1 not yet).
var lit := 0
var lit_tick := -1
## 1 while the Deep gate's footprint stands as a barrier in World.walls.
var wall_up := 0


## Sets up `w`'s purple-rune room (setup, after every other room kind and secret): marks the layout
## (PurpleRooms.mark at `chance_permille`, from chance()) and registers the dais. No-op on a floor that gets none, or
## one without a Deep gate spot.
## v0.9.0 SH, HF: `taken`, rooms it never takes (the shrine's and the fountain's, Shrines.site_rooms; none on a floor
## saved before SH, as it was built).
static func setup(
	w: World, chance_permille: int, taken: PackedInt32Array = PackedInt32Array()
) -> void:
	var f := w.floor_layout
	if f == null or not f.has_deep_portal or w.boss_flow == null:
		return
	if PurpleRooms.mark(f, chance_permille, taken, avoid_spots(w)) < 0:
		return
	var p := PurpleRunes.new()
	p.entry = w.interactables.add(
		Interactables.Kind.PURPLE_DAIS, f.purple_pos, DAIS_REACH_M + w.solids.bonus(), 0
	)
	w.solids.add_square(Solids.Kind.DAIS, 0, f.purple_pos)  # v0.9.5 SB: the dais is solid
	w.purple = p


## The spots the dais keeps clear of: rewards, events, the shrine, the puzzles' pieces, the containers and barrels.
static func avoid_spots(w: World) -> PackedVector2Array:
	var f := w.floor_layout
	var out := Secrets.avoid_spots(w)
	out.append_array(f.timed_switches)
	out.append_array(f.rune_pillars)
	if f.shop_room >= 0:
		out.append(f.shop_pos)
	if w.breakables != null:
		out.append_array(w.breakables.pos)
	return out


## v0.9.0 DP (owner Q26b: "never in floor 1, 50% of appearing in floor 2 if does not appear, then warrantee on the
## next floor"): run `run`'s current floor's chance (per mille) of a purple-rune room: `per_floor`'s entry for the
## floor within the loop (SecretsDefinition.purple_floor_permille), while the loop has had none yet (RunState.
## purple_floors: one a loop, the lead's reading); 0 on a floor that offers no Deep gate (the loop's last) and on a
## floor saved before DP.
static func chance(run: RunState, per_floor: PackedInt32Array) -> int:
	if run == null or legacy_deep_gate(run) or not Routes.offers_choice(run):
		return 0
	for f in run.purple_floors:
		if f > run.loop_floors:
			return 0
	var i := run.floor_index - 1
	return per_floor[i] if i >= 0 and i < per_floor.size() else 0


## Whether run `run`'s current floor keeps the Deep gate on every floor before the last (a floor resumed from a save
## made before DP, floor rules 1-11).
static func legacy_deep_gate(run: RunState) -> bool:
	return run.floor_rules <= RunState.FLOOR_RULES_V090_RA


## The press on registry entry i (Interactables.handle): the runes awaken, once.
static func press(w: World, i: int) -> void:
	var p := w.purple
	if p == null or p.lit == 1:
		return
	p.lit = 1
	p.lit_tick = w.tick
	w.interactables.enabled[i] = 0
	w.interactables.state[i] = 1
	earn(w)


## The floor has earned the Purple Portal: the boss opens the Deep gate beside the gate, whose footprint stands.
static func earn(w: World) -> void:
	w.boss_flow.routes = true
	if w.purple == null or w.purple.wall_up == 0:
		w.add_barrier(Routes.deep_gate_collider(w.floor_layout))
	if w.purple != null:
		w.purple.wall_up = 1


## Whether the floor's runes are awakened.
static func earned(w: World) -> bool:
	return w.purple != null and w.purple.lit == 1


func hash_into(h: StateHasher) -> void:
	for v in [entry, lit, lit_tick, wall_up]:
		h.add_int(v)
