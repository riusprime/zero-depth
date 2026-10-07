class_name BossChallenge
extends RefCounted
## The boss challenge (PLAN v0.3.0 BX; owner lines L17, L20, L26): what makes kiting a boss from afar a losing plan.
## - Ranged armour: the player's hits on a boss deal less the farther the player stands (hit_mult; TAG_DEFLECTED).
## - Punish: staying beyond the punish distance for long enough makes the boss perform its punish attack (a pull, a
##   chain of leaps, a room-wide shockwave), started from BossAi.think through punish_due().
## - Weak point: the recovery of some attacks opens it for a while; hits from up close deal more and fill the
##   stagger meter faster (hit_mult, stagger_permille; TAG_EXPOSED).
## - Closing arena: a damaging band creeps in from the boss room's walls in marked steps (band, touches_band,
##   resolve_arena), capped so the room's centre stays safe.
## - Summoning the boss dissolves every normal enemy on the floor (dissolve_floor; ENEMY_DISSOLVED).
## Distances are from the boss's edge to the player's centre. Pure sim: no trig, randomness only from the ai stream.

## World.killer_attack when the closing band killed the player (the recap's cause line).
const ARENA_ATTACK := -2
## Moves that aim at a point and so lead a moving player (BossTable.lead_ticks).
const LEADING_MOVES: Array[int] = [
	BossAttackTable.Move.LANES,
	BossAttackTable.Move.CHARGE,
	BossAttackTable.Move.LEAP,
	BossAttackTable.Move.BARRAGE,
	BossAttackTable.Move.RAIL,
	BossAttackTable.Move.BOLT_FAN,
	BossAttackTable.Move.FLOOD,
]


## How far the player stands from boss i's edge (negative when overlapping).
static func edge_distance(w: World, i: int) -> float:
	return Kin.length(w.player_pos() - w.actors.pos(i)) - w.actors.radius[i]


## [per mille, tags] for a hit the player lands on boss i: the open weak point up close, else the ranged armour.
static func hit_mult(w: World, i: int) -> Array[int]:
	var b := BossAi.entry_of(w, i)
	if b < 0:
		return [1000, 0]
	var t: BossTable = w.boss_tables[w.bosses.table[b]]
	var d := edge_distance(w, i)
	if w.bosses.exposed_t[b] > 0 and d <= t.weak_range_m:
		return [t.weak_mult_permille, SimEvent.TAG_EXPOSED]
	var pm := ranged_permille(t, d)
	return [pm, SimEvent.TAG_DEFLECTED if pm < 1000 else 0]


## The ranged armour's multiplier at distance d: 1000 up to ranged_full_m, linear to ranged_far_permille at
## ranged_far_m, flat beyond.
static func ranged_permille(t: BossTable, d: float) -> int:
	if d <= t.ranged_full_m or t.ranged_far_permille >= 1000:
		return 1000
	var f := clampf((d - t.ranged_full_m) / (t.ranged_far_m - t.ranged_full_m), 0.0, 1.0)
	return 1000 - int((1000 - t.ranged_far_permille) * f)


## Per mille of a hit's damage that fills boss i's stagger meter (the weak point fills it faster).
static func stagger_permille(w: World, i: int, tags: int) -> int:
	if not (tags & SimEvent.TAG_EXPOSED):
		return 1000
	return BossAi.table_of(w, i).weak_stagger_permille


# --- phase 3 (BossAi.think) ------------------------------------------------------------------------------------


## Counts the fight's clocks for boss entry b: the far timer, the weak point, the closing arena.
static func think(w: World, i: int, b: int, t: BossTable) -> void:
	var bs := w.bosses
	if w.actors.state[i] == EnemyAi.State.SPAWN:
		return
	bs.fight_t[b] += 1
	if bs.exposed_t[b] > 0:
		bs.exposed_t[b] -= 1
	if not w.player_dead() and edge_distance(w, i) > t.punish_distance_m:
		bs.far_t[b] += 1
	else:
		bs.far_t[b] = 0
	if bs.hazard_cd[b] > 0:
		bs.hazard_cd[b] -= 1
	_read_player(w, i, b, t)
	if bs.close_t[b] > 0:
		bs.close_t[b] += 1
	elif _closing_starts(w, b, t):
		bs.close_t[b] = 1


static func _closing_starts(w: World, b: int, t: BossTable) -> bool:
	if t.close_step_m <= 0.0 or not w.bosses.arena.has_area():
		return false
	if t.close_phase >= 0 and w.bosses.phase[b] >= t.close_phase:
		return true
	return t.close_after_ticks > 0 and w.bosses.fight_t[b] >= t.close_after_ticks


## v0.3.5 AI (F3): the gap-closer's clock (the player out of reach), and the last dash's landing point.
static func _read_player(w: World, i: int, b: int, t: BossTable) -> void:
	var bs := w.bosses
	if t.gap_attack >= 0 and not w.player_dead() and edge_distance(w, i) > t.gap_distance_m:
		bs.gap_t[b] += 1
	else:
		bs.gap_t[b] = 0
	if t.dash_read_ticks <= 0:
		return
	if w.is_dashing() and not w.player_dead():
		var at := dash_landing(w)
		bs.dash_x[b] = at.x
		bs.dash_y[b] = at.y
		bs.dash_t[b] = t.dash_read_ticks
	elif bs.dash_t[b] > 0:
		bs.dash_t[b] -= 1


## Where the player's dash in progress ends: the rest of its distance along its direction (walls aside).
static func dash_landing(w: World) -> Vector2:
	var step := w.player.dash_distance_m / maxi(1, w.player.dash_ticks)
	return w.player_pos() + w.dash_dir * (step * w.dash_ticks_left)


## The gap-closer's index when it is due now (the player stayed out of reach long enough), else -1.
static func gap_close_due(w: World, b: int, t: BossTable) -> int:
	if t.gap_attack < 0 or t.gap_ticks <= 0 or w.player_dead():
		return -1
	return t.gap_attack if w.bosses.gap_t[b] >= t.gap_ticks else -1


## The punish attack's index when it is due now (the player stayed far long enough), else -1.
static func punish_due(w: World, b: int, t: BossTable) -> int:
	if t.punish_attack < 0 or t.punish_ticks <= 0 or w.player_dead():
		return -1
	return t.punish_attack if w.bosses.far_t[b] >= t.punish_ticks else -1


## Where an attack aims: the player, led by the boss's lead time at the player's velocity for aimed moves; for
## dash_read_ticks after a dash (v0.3.5 AI, F3), aimed moves go at that dash's landing point instead.
static func aim_point(w: World, b: int, move: int) -> Vector2:
	var p := w.player_pos()
	var t: BossTable = w.boss_tables[w.bosses.table[b]]
	if not LEADING_MOVES.has(move):
		return p
	if w.bosses.dash_t[b] > 0:
		return Vector2(w.bosses.dash_x[b], w.bosses.dash_y[b])
	if t.lead_ticks <= 0:
		return p
	return p + w.vel * t.lead_ticks


## The pull's drag on the player this tick (phase 5, during the windup of a PULL): toward the boss at the attack's
## pull speed, stopping at its body. A dashing player isn't dragged.
static func drag(w: World, i: int, atk: BossAttackTable) -> void:
	if w.player_dead() or w.is_dashing() or atk.pull <= 0.0:
		return
	var p := w.player_pos()
	var to := w.actors.pos(i) - p
	var d := Kin.length(to)
	var gap := d - w.actors.radius[i] - w.player.radius_m
	if d <= 0.0001 or gap <= 0.0 or d - w.actors.radius[i] > atk.pull_range_m:
		return
	w.actors.set_pos(0, p + to * (minf(atk.pull, gap) / d))


# --- the closing arena (one shape: band(); the view draws it, resolve_arena hits with it) ------------------------


## How deep the band is (per axis, metres) after `steps` steps: step_m each, capped safe_half_m from the centre.
static func band_depth(arena: Rect2, t: BossTable, steps: int) -> Vector2:
	var d := t.close_step_m * steps
	return Vector2(
		clampf(d, 0.0, maxf(0.0, arena.size.x * 0.5 - t.safe_half_m)),
		clampf(d, 0.0, maxf(0.0, arena.size.y * 0.5 - t.safe_half_m))
	)


## The closing band of the live boss: {} when none, else "arena" (Rect2), "depth" (Vector2, the band that hurts
## now), "next" (Vector2, the band it grows to next), "warn" (0..1000 while the next step is marked, else -1).
static func band(w: World) -> Dictionary:
	var arena := w.bosses.arena
	if not arena.has_area():
		return {}
	for b in w.bosses.size():
		var i := w.actors.index_of(w.bosses.ids[b])
		if i < 0 or w.actors.dead[i] == 1 or w.bosses.close_t[b] <= 0:
			continue
		var t: BossTable = w.boss_tables[w.bosses.table[b]]
		var ct := w.bosses.close_t[b] - 1
		var steps := ct / t.close_step_ticks
		var depth := band_depth(arena, t, steps)
		var next := band_depth(arena, t, steps + 1)
		var into := ct % t.close_step_ticks
		var warn := -1
		var lead := t.close_step_ticks - t.close_warn_ticks
		if next != depth and into >= lead:
			warn = clampi((into - lead) * 1000 / maxi(1, t.close_warn_ticks), 0, 1000)
		return {"arena": arena, "depth": depth, "next": next, "warn": warn}
	return {}


## True if a circle at p of radius r touches the band `depth` deep inside `arena`.
static func touches_band(arena: Rect2, depth: Vector2, p: Vector2, r: float) -> bool:
	if depth.x > 0.0 and (p.x - r < arena.position.x + depth.x or p.x + r > arena.end.x - depth.x):
		return true
	return (
		depth.y > 0.0 and (p.y - r < arena.position.y + depth.y or p.y + r > arena.end.y - depth.y)
	)


## Phase 6: the band hurts a player who touches it, at most once per hazard period (damage over time from the boss:
## no guard, no armour).
static func resolve_arena(w: World, i: int) -> void:
	var b := BossAi.entry_of(w, i)
	if b < 0 or w.player_dead() or w.bosses.hazard_cd[b] > 0:
		return
	var t: BossTable = w.boss_tables[w.bosses.table[b]]
	if t.hazard_damage <= 0:
		return
	var bd := band(w)
	if (
		bd.is_empty()
		or not touches_band(bd["arena"], bd["depth"], w.player_pos(), w.player.radius_m)
	):
		return
	w.bosses.hazard_cd[b] = t.hazard_ticks
	Damage.tick_dot(w, 0, t.hazard_damage, w.actors.ids[i], w.actors.ids[i], &"arena_band")
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = ARENA_ATTACK


# --- summoning (BossFlow, the dev panel) --------------------------------------------------------------------------


## Removes every normal enemy on the floor as the boss is summoned: no kill, no shards, one ENEMY_DISSOLVED each (in
## actor order). Nothing happens while a boss is already alive (its own hatchlings and turrets stay). Returns how many
## dissolved.
static func dissolve_floor(w: World) -> int:
	if w.boss_alive():
		return 0
	var a := w.actors
	var gone := PackedInt32Array()
	for i in range(1, a.size()):
		if (
			a.dead[i] == 1
			or BossAi.is_boss_kind(a.kinds[i])
			or not EnemyAi.is_enemy_kind(a.kinds[i])
		):
			continue
		gone.append(i)
		var e := w.emit_event(SimEvent.Kind.ENEMY_DISSOLVED, a.ids[i], a.ids[i], a.ids[i], a.pos(i))
		e.amount = a.kinds[i]
	a.remove_sorted(gone)
	return gone.size()
