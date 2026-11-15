class_name BossRift
extends RefCounted
## The Twin Wardens' set piece, Through the Rift (BossWardensTable.rift_*; BossFightStore.wd_rift_*). Once a fight,
## in the last phase, when rift_hp_permille of its bar is left and the amber Warden is free (between two attacks):
## 1. OPEN: three rifts open on a ring round the middle of the boss room, rift_gap_m apart, each clear of walls (the
##    ring is turned until all three fit; with no fit the set piece is skipped for good). Neither Warden starts
##    anything for rift_open_ticks (the violet one ends the attack she is in first).
## 2. RUN: the amber Warden runs to the nearest rift at its exit charge's speed.
## 3. INSIDE: it is gone for rift_inside_ticks (hidden, untouchable, in nobody's way). As it goes in, the rift it
##    leaves by is drawn from the `ai` stream among the other two. rift_mark_ticks before the end the exit is marked
##    for the view and the hero's spot is taken as the aim.
## 4. OUT: it stands at the exit and its exit charge (the table's rift_attack, a `charge`) runs at once along the line
##    from the exit to that aim: BossAi runs it as any charge (the contact hit, the walls), BossChargeBurst bursts
##    where it ends and BossWard breaks the violet Warden's ward when she stands on the lane. When the charge is
##    over the rifts close.
## The violet Warden starts nothing through 1-3 and fights again in 4. It ends early when the hero or a Warden is gone.
## Only the exit draws a stream.

const S := EnemyAi.State
const NONE := 0
const OPEN := 1
const RUN := 2
const INSIDE := 3
const OUT := 4
const COUNT := 3
## A run to the rift that a body or a wall holds up this long ends with him going in from where he is, so the set
## piece never stalls.
const RUN_LIMIT_TICKS := 120
## The ring's turns tried for a fit (1/4096 turns).
const TURNS: Array[int] = [0, 341, 683, 1024, 170, 512, 853, 1195]
## STATUS_APPLY, source the amber Warden unless said: the rifts opened (source the violet Warden, amount = ticks until
## he runs), he went in (pos = the rift), the exit is marked (pos = the exit, amount = ticks until he is out), he is
## out (pos = the exit), the rifts closed.
const OPENED := &"warden_rift_open"
const ENTER := &"warden_rift_enter"
const MARK := &"warden_rift_mark"
const EXIT := &"warden_rift_exit"
const CLOSED := &"warden_rift_close"


## True while actor i is the amber Warden inside the rifts (BossAi.hidden, passes_through).
static func inside(w: World, i: int) -> bool:
	var bs := w.boss_fight
	return bs.wd_rift_stage == INSIDE and bs.wd_boss == w.actors.ids[i]


## True while the set piece holds the Wardens from starting anything (stages 1-3).
static func holds(w: World) -> bool:
	var st := w.boss_fight.wd_rift_stage
	return st >= OPEN and st <= INSIDE


## Rift k's centre.
static func spot(w: World, k: int) -> Vector2:
	return Vector2(w.boss_fight.wd_rift_x[k], w.boss_fight.wd_rift_y[k])


## Tick phase 6 (BossWardens.advance).
static func advance(w: World, lead: int, violet: int, wt: BossWardensTable) -> void:
	var bs := w.boss_fight
	var a := w.actors
	match bs.wd_rift_stage:
		NONE:
			if _due(w, lead, violet, wt):
				_open(w, lead, violet, wt)
		OPEN:
			if w.tick >= bs.wd_rift_at + wt.rift_open_ticks:
				bs.wd_rift_stage = RUN
				bs.wd_rift_at = w.tick
				bs.wd_rift_in = _nearest(w, a.pos(lead))
		INSIDE:
			a.invuln[lead] = maxi(a.invuln[lead], 2)
			var out_at := bs.wd_rift_at + wt.rift_inside_ticks
			if w.tick == out_at - wt.rift_mark_ticks:
				bs.wd_aim_x = w.player_pos().x
				bs.wd_aim_y = w.player_pos().y
				_tell(w, lead, MARK, spot(w, bs.wd_rift_out), wt.rift_mark_ticks)
			if w.tick >= out_at:
				_emerge(w, lead, wt)
		OUT:
			if a.state[lead] != S.ACTIVE:
				close(w, lead)


## True when the set piece begins now.
static func _due(w: World, lead: int, violet: int, wt: BossWardensTable) -> bool:
	var bs := w.bosses
	var fs := w.boss_fight
	var a := w.actors
	if fs.wd_rift_done == 1 or wt.rift_hp_permille <= 0 or wt.rift_attack < 0 or w.player_dead():
		return false
	var t := BossAi.table_of(w, lead)
	var last := t.phase_threshold.size() - 1
	if bs.phase[BossAi.entry_of(w, lead)] < last or a.state[lead] != S.MOVE:
		return false
	if fs.wd_dash_t > 0 or a.dead[violet] == 1:
		return false
	# hp / max_hp <= the last bar's share × rift_hp_permille, in per mille of per mille
	return a.hp[lead] * 1000000 <= a.max_hp[lead] * t.phase_threshold[last] * wt.rift_hp_permille


static func _open(w: World, lead: int, violet: int, wt: BossWardensTable) -> void:
	var bs := w.bosses
	var fs := w.boss_fight
	fs.wd_rift_done = 1
	var room := bs.arena
	var c := room.get_center() if room.has_area() else w.actors.pos(violet)
	# Three points on a circle are rift_gap_m apart when its radius is the gap over the square root of 3
	var ring := wt.rift_gap_m * 0.5774 + 0.05
	var clear := wt.rift_radius_m + w.actors.radius[lead]
	var base := Kin.angle_of(w.player_pos() - c)
	for turn in TURNS:
		var xs := PackedFloat32Array()
		var ys := PackedFloat32Array()
		for k in COUNT:
			var p := c + Kin.dir((base + turn + k * 4096 / COUNT) & 4095) * ring
			if room.has_area() and not room.grow(-clear).has_point(p):
				break
			if not EnemyAi.clear_of_walls(w, p, clear):
				break
			xs.append(p.x)
			ys.append(p.y)
		if xs.size() < COUNT:
			continue
		fs.wd_rift_x = xs
		fs.wd_rift_y = ys
		fs.wd_rift_stage = OPEN
		fs.wd_rift_at = w.tick
		fs.wd_rift_in = -1
		fs.wd_rift_out = -1
		_tell(w, violet, OPENED, w.actors.pos(violet), wt.rift_open_ticks)
		return


static func _nearest(w: World, at: Vector2) -> int:
	var best := 0
	for k in range(1, COUNT):
		if Kin.length(spot(w, k) - at) < Kin.length(spot(w, best) - at):
			best = k
	return best


## Tick phase 5 (BossTwin.moves): true while the set piece moves the Wardens itself (they stand; in RUN the amber one
## runs to its rift and goes in when it gets there).
static func moves(w: World, i: int, wt: BossWardensTable, slow: float) -> bool:
	var bs := w.boss_fight
	if not holds(w):
		return false
	var a := w.actors
	if a.state[i] != S.MOVE:
		return false  # She ends the attack she is in
	if bs.wd_rift_stage != RUN or bs.wd_boss != a.ids[i]:
		return true
	var atk := BossAi.table_of(w, i).attacks[wt.rift_attack]
	var at := a.pos(i)
	var to := spot(w, bs.wd_rift_in) - at
	var dist := Kin.length(to)
	var step := atk.speed * slow
	if dist > step and dist > 0.0001 and w.tick < bs.wd_rift_at + RUN_LIMIT_TICKS:
		a.facing[i] = Kin.angle_of(to)
		a.set_pos(i, at + EnemyAi.steer(w, at, to / dist, a.radius[i]) * step)
		return true
	_tell(w, i, ENTER, spot(w, bs.wd_rift_in), wt.rift_inside_ticks)
	var others := PackedInt32Array()
	for k in COUNT:
		if k != bs.wd_rift_in:
			others.append(k)
	bs.wd_rift_out = others[w.rng_ai.range_int(0, others.size() - 1)]
	bs.wd_rift_stage = INSIDE
	bs.wd_rift_at = w.tick
	a.set_pos(i, spot(w, bs.wd_rift_out))
	a.invuln[i] = maxi(a.invuln[i], 2)
	return true


## The amber Warden is out: its exit charge runs from the exit toward where the hero stood when it was marked.
static func _emerge(w: World, lead: int, wt: BossWardensTable) -> void:
	var bs := w.bosses
	var fs := w.boss_fight
	var a := w.actors
	var b := BossAi.entry_of(w, lead)
	var atk := BossAi.table_of(w, lead).attacks[wt.rift_attack]
	var from := spot(w, fs.wd_rift_out)
	var to := Vector2(fs.wd_aim_x, fs.wd_aim_y) - from
	var aim := Kin.angle_of(to) if Kin.length(to) > 0.0001 else a.facing[lead]
	a.set_pos(lead, from)
	a.invuln[lead] = 0
	EnemyAi.enter_state(a, lead, S.ACTIVE)
	a.fire_cd[lead] = 0
	a.facing[lead] = aim
	a.lock_x[lead] = from.x
	a.lock_y[lead] = from.y
	a.lock_a[lead] = aim
	a.lock_len[lead] = EnemyAi.clear_run(w, from, aim, atk.length_m, a.radius[lead])
	bs.attack[b] = wt.rift_attack
	bs.last_attack[b] = wt.rift_attack
	bs.step[b] = 0
	bs.hit[b] = 0
	bs.chained[b] = 1
	fs.wd_rift_stage = OUT
	fs.wd_rift_at = w.tick
	_tell(w, lead, EXIT, from, 0)


## The rifts close (the charge is over, or the fight is).
static func close(w: World, lead: int) -> void:
	var bs := w.boss_fight
	if bs.wd_rift_stage == NONE:
		return
	if bs.wd_rift_stage == INSIDE and lead >= 0:
		w.actors.invuln[lead] = 0
	bs.wd_rift_stage = NONE
	bs.wd_rift_in = -1
	bs.wd_rift_out = -1
	bs.wd_rift_x = PackedFloat32Array()
	bs.wd_rift_y = PackedFloat32Array()
	if lead >= 0:
		_tell(w, lead, CLOSED, w.actors.pos(lead), 0)


static func _tell(w: World, i: int, effect: StringName, at: Vector2, ticks: int) -> void:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = effect
	e.amount = ticks


## BossWardens.state: {} with no set piece running; else "stage" (OPEN, RUN, INSIDE, OUT), "rifts" ([{centre, radius,
## entry (he runs to it), exit (true only once the exit is marked)}]), "inside" (he is gone), "exit_in" (ticks until
## he is out, -1 outside INSIDE) and, once marked, "lane" ([from, to]: where he will charge).
static func state(w: World, lead: int, wt: BossWardensTable) -> Dictionary:
	var bs := w.boss_fight
	if bs.wd_rift_stage == NONE:
		return {}
	var left := bs.wd_rift_at + wt.rift_inside_ticks - w.tick if bs.wd_rift_stage == INSIDE else -1
	var marked := (
		bs.wd_rift_stage == OUT or (bs.wd_rift_stage == INSIDE and left <= wt.rift_mark_ticks)
	)
	var rifts := []
	for k in bs.wd_rift_x.size():
		(
			rifts
			. append(
				{
					"centre": spot(w, k),
					"radius": wt.rift_radius_m,
					"entry": k == bs.wd_rift_in,
					"exit": marked and k == bs.wd_rift_out,
				}
			)
		)
	var out := {
		"stage": bs.wd_rift_stage,
		"rifts": rifts,
		"inside": bs.wd_rift_stage == INSIDE,
		"exit_in": left,
	}
	if marked and bs.wd_rift_stage == INSIDE:
		var atk := BossAi.table_of(w, lead).attacks[wt.rift_attack]
		var from := spot(w, bs.wd_rift_out)
		var to := Vector2(bs.wd_aim_x, bs.wd_aim_y) - from
		var d := Kin.length(to)
		if d > 0.0001:
			out["lane"] = [from, from + to / d * atk.length_m]
			out["burst_radius"] = atk.burst_radius_m
	return out
