class_name Gamble
extends RefCounted
## The gamble shrine (v0.3.0 PLAN L19): one per floor, in the start hall, so it is always reachable and you can come
## back to it.
## - Price: GambleTable.price(uses on this floor, floor number): 25 shards on floor 1, then × 1.5 per use (rounded
##   half up: 25, 38, 57, 86, 129 ...). The count of uses resets on each floor (it is not carried), and a later
##   floor's base is raised like the chests' (× 1.5 on floor 2, × 2 on floor 3).
## - The interact button within reach pays and grants one stat at once: a weighted draw from the loot stream over the
##   stats still under their cap. You can't afford it, or every stat is capped: the world records the refusal (for
##   the view) and nothing is paid. An altar or chest in reach takes the press first (Rewards.interact).
## - The stats won (World.gamble_stacks, wins per GambleTable.Stat) last the whole run (RunCarry) and are hashed.
##   Each stat's hook reads bonus(): max HP (raised at once, and healed by the same amount), melee and shot damage,
##   move speed, the dash cooldown, the shards a kill pays; REGEN and HEAT are exposed for the regen (P) and heat (H)
##   workstreams through regen_bonus_permille() and heat_capacity_bonus_permille().

## Half the side of the shrine's square footprint (turned 45°, under the plinth's 0.78 m hexagon).
const FOOTPRINT_HALF_M := 0.5


## Places the floor's shrine (setup, after the rewards). Returns its id.
static func place(w: World, layout: FloorLayout) -> int:
	w.gamble_pos = spot(layout, w.gamble_table)
	w.gamble_id = w.take_root()
	w.emit_event(SimEvent.Kind.SPAWN, w.gamble_id, w.gamble_id, w.gamble_id, w.gamble_pos)
	return w.gamble_id


## Where the shrine stands (a pure function of the layout and the rules; no stream is drawn):
## spot_distance_m from the start point, first on the side of the hall away from its exit, then turning by 45° steps
## (left before right) until the spot is inside the hall and clear of every wall by clear_radius_m. Without one: the
## hall's spawn point nearest the start that is clear, then the same in the rooms next to the hall, then the start.
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


static func present(w: World) -> bool:
	return w.gamble_id >= 0


## The player stands within the shrine's interact radius.
static func in_reach(w: World) -> bool:
	return (
		present(w) and Kin.length(w.gamble_pos - w.player_pos()) <= w.gamble_table.interact_radius_m
	)


## Shards for the next use on this floor.
static func price(w: World) -> int:
	return w.gamble_table.price(w.gamble_uses, w.floor_index)


static func can_afford(w: World) -> bool:
	return w.shards >= price(w)


## Wins of `stat` so far this run.
static func stacks(w: World, stat: int) -> int:
	return w.gamble_stacks[stat] if stat < w.gamble_stacks.size() else 0


## What the wins of `stat` add (HP for MAX_HP, per mille otherwise).
static func bonus(w: World, stat: int) -> int:
	return stacks(w, stat) * w.gamble_table.amount[stat]


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


## Every stat is at its cap: the shrine has nothing left to give.
static func exhausted(w: World) -> bool:
	for v in weights(w):
		if v > 0:
			return false
	return true


## Tick phase 2b, after Rewards.interact: a buffered interact press by the shrine pays and grants a stat. True if
## it granted one.
static func interact(w: World) -> bool:
	if w.player_dead() or w.buffered(InputFrame.INTERACT) == 0 or not in_reach(w):
		return false
	w.consume_buffered(InputFrame.INTERACT)
	if not can_afford(w) or exhausted(w):
		w.gamble_denied_tick = w.tick
		return false
	w.shards -= price(w)
	var stat := draw(w)
	grant(w, stat)
	w.gamble_uses += 1
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
	if stat == GambleTable.Stat.MAX_HP:
		var add := w.gamble_table.amount[stat]
		w.actors.max_hp[0] += add
		w.actors.hp[0] = mini(w.actors.max_hp[0], w.actors.hp[0] + add)


## After a run's carry restored gamble_stacks on a fresh floor (RunCarry.apply): max HP follows the wins.
static func after_carry(w: World) -> void:
	w.actors.max_hp[0] = w.player.hp + bonus(w, GambleTable.Stat.MAX_HP)


# --- Hooks: each stat's effect where the sim computes it ---------------------------------------------------
## `base` raised by `permille`, rounded half up (unchanged at 0).
static func raise(base: int, permille: int) -> int:
	if permille == 0:
		return base
	return (base * (1000 + permille) + 500) / 1000


static func melee_damage(w: World, dmg: int) -> int:
	return raise(dmg, bonus(w, GambleTable.Stat.MELEE))


static func shot_damage(w: World, dmg: int) -> int:
	return raise(dmg, bonus(w, GambleTable.Stat.SHOT))


static func shard_gain(w: World, amount: int) -> int:
	return raise(amount, bonus(w, GambleTable.Stat.SHARDS))


static func move_speed_bonus_permille(w: World) -> int:
	return bonus(w, GambleTable.Stat.MOVE)


static func dash_cooldown_cut_permille(w: World) -> int:
	return bonus(w, GambleTable.Stat.DASH_CD)


## Extra out-of-combat regen, in per mille of max HP per second (for the regen hook, workstream P).
static func regen_bonus_permille(w: World) -> int:
	return bonus(w, GambleTable.Stat.REGEN)


## Extra heat capacity, in per mille of the base capacity (for the heat hook, workstream H).
static func heat_capacity_bonus_permille(w: World) -> int:
	return bonus(w, GambleTable.Stat.HEAT)
