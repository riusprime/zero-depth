class_name Gamble
extends RefCounted
## The gamble shrine (v0.3.0 PLAN L19). v0.8.0 N14 (owner O72: "shrine should also me rarer, not at the start of every
## floor, and have a cap of 3 upgrades with a 30% chance of failing, cost still goes up if it misses, at 3 upgrades it
## gets blocked"): some floors only, in a combat room away from the start hall (site); a floor resumed from a save made
## before N14 keeps its shrine in the start hall (spot; RunState.rare_shrine).
## v0.9.0 SH (owner Q29b): the player knows it as the Fortune Shrine, one of the floor's three shrine kinds (Shrines
## draws the kind for the site chosen here); its rules below are unchanged. A floor saved before SH (floor rules
## 1-13) keeps it as it was: every shrine there is a Fortune Shrine.
## - Price: GambleTable.price(uses on this floor, floor number): 25 shards on floor 1, then × 1.5 per use (rounded
##   half up: 25, 38, 57, 86, 129 ...). Every paid use counts, a failed one too. The count of uses resets on each
##   floor (it is not carried), and a later floor's base is raised like the chests' (× 1.5 on floor 2, × 2 on floor 3).
## - The interact button within reach pays, then rolls the failure (fail_permille, on `loot:shrine:<use>`): a failed
##   use grants nothing (World.gamble_fail_tick, a GAMBLE_FAIL event); otherwise one stat at once, a weighted draw
##   from the loot stream over the stats still under their cap, and one win (World.gamble_wins). After max_wins wins
##   the shrine is spent. Too poor, spent, or every stat capped: the world records the refusal (for the view) and
##   nothing is paid. An altar or chest in reach takes the press first (Rewards.interact).
## - The stats won (World.gamble_stacks, wins per GambleTable.Stat) last the whole run (RunCarry) and are hashed.
##   Each stat's hook reads bonus(): max HP (raised at once, and healed by the same amount), melee and shot damage,
##   move speed, the dash cooldown, the shards a kill pays; REGEN and HEAT are exposed for the regen (P) and heat (H)
##   workstreams through regen_bonus_permille() and heat_capacity_bonus_permille().

## v0.8.0 N14: the floor's draw (does it have a shrine, and in which room) and each use's failure roll (one stream per
## use, derived from the floor seed, so a resumed save rolls what the first try rolled).
const STREAM := "map:shrine"
const FAIL_STREAM := "loot:shrine"
## v0.8.0 N14: a shrine away from the start hall keeps this far from the room's doorway approaches and item spots.
const DOOR_GAP_M := 2.5
const ITEM_GAP_M := 2.5
## Where you stand to use it, from its centre (the e2e walks there; reachability is checked through it).
const FRONT_M := 1.2
const _DOOR_APPROACH := 1.0

## Half the side of the shrine's square footprint (turned 45°, under the plinth's 0.78 m hexagon).
const FOOTPRINT_HALF_M := 0.5


## Places the floor's shrine at `at` (setup, after the rewards; site() chose the spot). Returns its id.
static func place(w: World, at: Vector2) -> int:
	w.gamble_pos = at
	w.gamble_id = w.take_root()
	w.emit_event(SimEvent.Kind.SPAWN, w.gamble_id, w.gamble_id, w.gamble_id, w.gamble_pos)
	return w.gamble_id


## v0.8.0 N14 (O72): where the floor's shrine stands, or [] for a floor without one. `legacy` (a floor saved before
## N14): always, in the start hall (spot). Otherwise a draw on STREAM, from the floor seed: a shrine with
## floor_chance_permille; then the candidate rooms (rooms()) in an order drawn from the same stream, the first with a
## spot (room_spot) wins. Pure: a function of the layout, the rules and the floor seed.
static func site(
	layout: FloorLayout, t: GambleTable, legacy: bool, params: FloorParams = null
) -> PackedVector2Array:
	if legacy:
		return PackedVector2Array([spot(layout, t)])
	var rng := stream(layout.seed_value, STREAM)
	if not rng.chance_permille(t.floor_chance_permille):
		return PackedVector2Array()
	var order := rooms(layout)
	for k in range(order.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := order[k]
		order[k] = order[j]
		order[j] = swap
	var p := params if params != null else FloorParams.defaults()
	for room in order:
		var at := room_spot(layout, room, t, p)
		if not at.is_empty():
			return at
	return PackedVector2Array()


## v0.8.0 N14: the rooms a shrine may stand in, ascending: combat rooms (ArenaRooms.candidates: not the start hall,
## the boss room or its host, the portal room, the Overrun room or the shop's room) that are not sealed arenas.
## v0.9.0 CF2: nor a Lockdown (marked first from floor rules 17; none marked yet on an older floor's rules).
static func rooms(layout: FloorLayout) -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in ArenaRooms.candidates(layout):
		if layout.lockdown_rooms.has(r):
			continue
		if not layout.arena_rooms.has(r) and r < layout.hops.size() and layout.hops[r] > 0:
			out.append(r)
	return out


## v0.8.0 N14: the shrine's spot in `room` ([] when none): the room's centre, then its spawn points nearest the
## centre; the first inside the room and clear of every wall by clear_radius_m, DOOR_GAP_M from its doorway
## approaches and ITEM_GAP_M from every item spot, where, with the shrine's footprint as a wall, the room's open floor
## stays one region holding every doorway approach, every item spot and the shrine's front (at the enemies'
## clearance, like the shop: ShopPlacement).
static func room_spot(
	layout: FloorLayout, room: int, t: GambleTable, p: FloorParams
) -> PackedVector2Array:
	var r := layout.rooms[room]
	var approaches := layout.door_approaches(room, _DOOR_APPROACH)
	if approaches.is_empty():
		return PackedVector2Array()
	var centre := r.get_center()
	var tries := [centre]
	var pts := (
		layout.spawn_points[room] if room < layout.spawn_points.size() else PackedVector2Array()
	)
	var order := Array(pts)
	order.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			var da := Kin.length(a - centre)
			var db := Kin.length(b - centre)
			return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y)))
	)
	tries.append_array(order)
	var walls := layout.room_walls(room)
	for q: Vector2 in tries:
		if not _clear(layout, room, q, t.clear_radius_m):
			continue
		var near := false
		for a in approaches:
			near = near or Kin.length(a - q) < DOOR_GAP_M
		for s in layout.item_spots:
			near = near or Kin.length(s - q) < ITEM_GAP_M
		if near:
			continue
		var with: Array[Obb] = walls.duplicate()
		with.append(collider(q))
		var must := approaches.duplicate()
		must.append(front(q, approaches[0]))
		for i in layout.item_spots.size():
			if layout.item_rooms[i] == room:
				must.append(layout.item_spots[i])
		if FloorReach.whole(r, with, p.nav_clearance, must):
			return PackedVector2Array([q])
	return PackedVector2Array()


## v0.8.0 N14: `points` without those within clear_radius_m + FOOTPRINT_HALF_M of a shrine at `at` (no enemy spawns
## in or against its footprint).
static func free_spawns(
	points: PackedVector2Array, at: Vector2, t: GambleTable
) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in points:
		if Kin.length(q - at) >= t.clear_radius_m + FOOTPRINT_HALF_M:
			out.append(q)
	return out


## Where you stand to use a shrine at `at`: FRONT_M toward `toward` (the room's first doorway approach).
static func front(at: Vector2, toward: Vector2) -> Vector2:
	var d := toward - at
	if Kin.length(d) <= 0.0:
		return at + Vector2(FRONT_M, 0.0)
	return at + d / Kin.length(d) * FRONT_M


## Where the shrine of a floor saved before N14 stands, in the start hall (a pure function of the layout and the
## rules; no stream is drawn): spot_distance_m from the start point, first on the side of the hall away from its exit,
## then turning by 45° steps (left before right) until the spot is inside the hall and clear of every wall by
## clear_radius_m. Without one: the hall's spawn point nearest the start that is clear, then the same in the rooms next
## to the hall, then the start.
static func spot(layout: FloorLayout, t: GambleTable) -> Vector2:
	var hall := layout.start_room
	var start := layout.start_pos
	var exit_angle := 0
	for d in layout.door_rooms.size():
		if layout.door_rooms[d].x == hall:
			exit_angle = layout.door_angles[d]
			break
		if layout.door_rooms[d].y == hall:
			exit_angle = layout.door_angles[d] + 2048
			break
	var back := exit_angle + 2048
	for turn in [0, 512, -512, 1024, -1024, 1536, -1536, 2048]:
		var p := start + Kin.dir((back + turn) & 4095) * t.spot_distance_m
		if _clear(layout, hall, p, t.clear_radius_m):
			return p
	var rooms := PackedInt32Array([hall])
	rooms.append_array(layout.neighbours(hall))
	for room in rooms:
		if room >= layout.spawn_points.size():
			continue
		var best := Vector2.ZERO
		var best_d := -1.0
		for p in layout.spawn_points[room]:
			var d := Kin.length(p - start)
			if (best_d < 0.0 or d < best_d) and _clear(layout, room, p, t.clear_radius_m):
				best = p
				best_d = d
		if best_d >= 0.0:
			return best
	return start


## The shrine's footprint (a square under its plinth) as a wall, so you walk up to it, not through it.
static func collider(at: Vector2) -> Obb:
	return Obb.make(at, Vector2(FOOTPRINT_HALF_M, FOOTPRINT_HALF_M), 512)


static func _clear(layout: FloorLayout, room: int, p: Vector2, r: float) -> bool:
	if not layout.rooms[room].grow(-r).has_point(p):
		return false
	for o in layout.walls:
		if Collide.circle_vs_obb(p, r, o) != Vector2.ZERO:
			return false
	return true


## v0.9.0 SH (owner Q29b: "Today's gamble shrine becomes the Fortune Shrine"): the floor's shrine is this one only
## when its kind is Fortune (a Blood or Chaos shrine stands on the same site instead: Shrines; gamble_id and
## gamble_pos stay the site every other room kind keeps away from).
static func present(w: World) -> bool:
	return w.gamble_id >= 0 and (w.shrine == null or w.shrine.kind == ShrineTable.Kind.FORTUNE)


## The player stands within the shrine's interact radius.
static func in_reach(w: World) -> bool:
	var reach := Stats.reach(w, w.gamble_table.interact_radius_m)  # v0.4.0 BS: pickup range
	return present(w) and Kin.length(w.gamble_pos - w.player_pos()) <= reach


## Shards for the next use on this floor.
static func price(w: World) -> int:
	return Curses.price(w, w.gamble_table.price(w.gamble_uses, w.floor_index))  # v0.5.0 EV


static func can_afford(w: World) -> bool:
	return w.shards >= price(w)


## Wins of `stat` so far this run.
static func stacks(w: World, stat: int) -> int:
	return w.gamble_stacks[stat] if stat < w.gamble_stacks.size() else 0


## What the wins of `stat` add (HP for MAX_HP, per mille otherwise).
static func bonus(w: World, stat: int) -> int:
	return stacks(w, stat) * w.gamble_table.amount[stat]


## What the hooks below add: bonus(), or 0 for a stat the shrine pays into the stat cards' values instead
## (v0.4.0 BS, Stats.from_gamble), so no win counts twice.
static func hook_bonus(w: World, stat: int) -> int:
	return 0 if Stats.from_gamble(w, stat) >= 0 else bonus(w, stat)


## Draw weights now: a stat at its cap (or without weight) has 0, and so has a stat for the weapon the run's build
## lacks (v0.3.0 L15: no melee damage in a Gun run, no shot damage in a Blade run).
static func weights(w: World) -> PackedInt32Array:
	var t := w.gamble_table
	var out := PackedInt32Array()
	for s in GambleTable.STAT_COUNT:
		var need := t.requires_weapon[s] if s < t.requires_weapon.size() else 0
		var usable := need == 0 or (need & w.player.weapons) != 0
		out.append(t.weight[s] if stacks(w, s) < t.cap[s] and usable else 0)
	return out


## v0.8.0 N14 (O72): the shrine's wins on this floor, how many it grants, and the chance a use fails (per mille).
static func wins(w: World) -> int:
	return w.gamble_wins


static func max_wins(w: World) -> int:
	return w.gamble_table.max_wins


static func fail_permille(w: World) -> int:
	return w.gamble_table.fail_permille


## v0.8.0 N14 (O72): the shrine gave its max_wins stats: it is blocked.
static func spent(w: World) -> bool:
	return w.gamble_table.max_wins > 0 and w.gamble_wins >= w.gamble_table.max_wins


## v0.8.0 N14 (O72): whether paid use number `use` (0-based, this floor) fails: one draw on its own stream
## (FAIL_STREAM:<use>, from the floor seed), so the outcome of each try is fixed by the floor.
static func fails(w: World, use: int) -> bool:
	var p := w.gamble_table.fail_permille
	if p <= 0:
		return false
	return stream(w.seed_value, "%s:%d" % [FAIL_STREAM, use]).chance_permille(p)


## v0.8.0 N14: the named stream `stream_name` of floor seed `seed_value`, its first draw dropped: the first output of
## a freshly derived state follows nearby seeds too closely for a single yes/no (measured over 4,000 seeds 1..4000:
## 416 per mille for a 400 chance, 395 with the first draw dropped).
static func stream(seed_value: int, stream_name: String) -> RngStream:
	var rng := RngStream.derive(seed_value, stream_name)
	rng.next_u32()
	return rng


## Every stat is at its cap: the shrine has nothing left to give.
static func exhausted(w: World) -> bool:
	for v in weights(w):
		if v > 0:
			return false
	return true


## Tick phase 2b, after Rewards.interact: a buffered interact press by the shrine pays, then fails (fail_permille:
## nothing granted, the price still steps up) or grants a stat and counts a win. True if it granted one.
static func interact(w: World) -> bool:
	if w.player_dead() or w.buffered(InputFrame.INTERACT) == 0 or not in_reach(w):
		return false
	w.consume_buffered(InputFrame.INTERACT)
	if not can_afford(w) or spent(w) or exhausted(w):
		w.gamble_denied_tick = w.tick
		return false
	w.shards -= price(w)
	var failed := fails(w, w.gamble_uses)
	w.gamble_uses += 1
	if failed:  # v0.8.0 N14 (O72): paid, no stat
		w.gamble_fail_tick = w.tick
		w.emit_event(SimEvent.Kind.GAMBLE_FAIL, w.gamble_id, w.gamble_id, w.gamble_id, w.gamble_pos)
		return false
	var stat := draw(w)
	grant(w, stat)
	w.gamble_wins += 1
	w.gamble_last_stat = stat
	w.gamble_tick = w.tick
	return true


## One weighted draw from the loot stream over the stats still under their cap (exhausted() must be false).
static func draw(w: World) -> int:
	var ids := PackedInt32Array()
	var positive := PackedInt32Array()
	var all := weights(w)
	for s in all.size():
		if all[s] > 0:
			ids.append(s)
			positive.append(all[s])
	return ids[w.rng_loot.pick_weighted(positive)]


## Adds one win of `stat` (the draw's result; tests call it directly). Max HP rises at once and heals by as much.
static func grant(w: World, stat: int) -> void:
	if w.gamble_stacks.size() < GambleTable.STAT_COUNT:
		w.gamble_stacks.resize(GambleTable.STAT_COUNT)
	w.gamble_stacks[stat] += 1
	var card := Stats.from_gamble(w, stat)
	if card >= 0:  # v0.4.0 BS: in a run with stat cards the win raises that stat by the shrine's own amount
		Stats.add_amount(w, card, gamble_permille(w, stat))
	elif stat == GambleTable.Stat.MAX_HP:
		var add := w.gamble_table.amount[stat]
		w.actors.max_hp[0] += add
		w.actors.hp[0] = mini(w.actors.max_hp[0], w.actors.hp[0] + add)


## A win of `stat` in the stat cards' unit (v0.4.0 BS): per mille, max HP as a share of the table's HP.
static func gamble_permille(w: World, stat: int) -> int:
	var amount := w.gamble_table.amount[stat]
	if stat == GambleTable.Stat.MAX_HP:
		return amount * 1000 / maxi(1, w.player.hp)
	return amount


## After a run's carry restored gamble_stacks on a fresh floor (RunCarry.apply): max HP follows the wins.
static func after_carry(w: World) -> void:
	w.actors.max_hp[0] = Stats.max_hp(w)  # the table's HP x the max HP stat (v0.4.0), + old-style wins


# --- Hooks: each stat's effect where the sim computes it ---------------------------------------------------
## `base` raised by `permille`, rounded half up (unchanged at 0).
static func raise(base: int, permille: int) -> int:
	if permille == 0:
		return base
	return (base * (1000 + permille) + 500) / 1000


static func melee_damage(w: World, dmg: int) -> int:
	return raise(dmg, hook_bonus(w, GambleTable.Stat.MELEE))


static func shot_damage(w: World, dmg: int) -> int:
	return raise(dmg, hook_bonus(w, GambleTable.Stat.SHOT))


static func shard_gain(w: World, amount: int) -> int:
	return raise(amount, hook_bonus(w, GambleTable.Stat.SHARDS))


static func move_speed_bonus_permille(w: World) -> int:
	return hook_bonus(w, GambleTable.Stat.MOVE)


static func dash_cooldown_cut_permille(w: World) -> int:
	return hook_bonus(w, GambleTable.Stat.DASH_CD)


## Extra out-of-combat regen, in per mille of max HP per second (for the regen hook, workstream P).
static func regen_bonus_permille(w: World) -> int:
	return hook_bonus(w, GambleTable.Stat.REGEN)


## Extra heat capacity, in per mille of the base capacity (for the heat hook, workstream H).
static func heat_capacity_bonus_permille(w: World) -> int:
	return hook_bonus(w, GambleTable.Stat.HEAT)
