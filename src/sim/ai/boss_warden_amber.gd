class_name BossWardenAmber
extends RefCounted
## The amber Warden's fast sword work (BossTwin calls it for the pair's boss body).
## - The sword combo (`sword_combo`): `count` arcs, the first after the telegraph and the rest gap_ticks apart. Before
##   each hit the Warden first follows the hero with its aim, then for the last STEP_TICKS commits: the aim holds and
##   it steps step_m toward where the hero stood (never into them, never through a wall). The arc is cut round where
##   the body stands when the hit lands. Each hit may land (the hero's hurt i-frames apply); the hits before the last
##   deal BossWardensTable.combo_light_permille of the attack's damage.
## - The side dash: between two attacks (free, its cooldown still running) it dashes dash_m to the side of the line
##   to the hero in dash_ticks, at most once every dash_every_ticks: the side it tried last time second, and only a
##   side with room for at least half the dash. It deals no damage and picks no attack while it dashes.
## - The charges on their own clocks (BossWardensTable charge_attack, ward_charge_attack): never picked, each starts
##   when its clock says, a wait drawn from the ai stream; the phase-1 one aims where the hero will be.
## Pure but for those waits (the ai stream).

const S := EnemyAi.State
## The ticks before each hit in which the aim holds and the body steps in.
const STEP_TICKS := 6
## The hero must be within this of the Warden for it to bother dashing.
const DASH_NEAR_M := 10.0
## STATUS_APPLY, source the Warden: a side dash began (amount = its ticks).
const DASH := &"warden_dash"

# --- the sword combo ----------------------------------------------------------------------------------------------


## The attack tick boss i is on: the wind-up's ticks, then the active ones after them.
static func attack_tick(w: World, i: int, atk: BossAttackTable) -> int:
	var a := w.actors
	return a.state_t[i] if a.state[i] == S.WINDUP else atk.windup_ticks + a.state_t[i]


## The attack tick hit k lands on.
static func hit_tick(atk: BossAttackTable, k: int) -> int:
	return atk.windup_ticks + k * atk.gap_ticks


## The hit pending at attack tick t (0 .. count - 1).
static func pending(atk: BossAttackTable, t: int) -> int:
	if t <= atk.windup_ticks:
		return 0
	return mini(atk.count - 1, (t - atk.windup_ticks + atk.gap_ticks - 1) / atk.gap_ticks)


## True once the pending hit's aim holds at attack tick t.
static func committed(atk: BossAttackTable, t: int) -> bool:
	return t >= hit_tick(atk, pending(atk, t)) - STEP_TICKS


## Tick phase 5 (BossTwin.moves), through the wind-up and the hits: the aim follows the hero, then holds while the
## body steps in. The arc's centre is the body.
static func combo_move(w: World, i: int, atk: BossAttackTable, slow: float) -> void:
	var a := w.actors
	var t := attack_tick(w, i, atk)
	var at := a.pos(i)
	if w.player_dead() or t > hit_tick(atk, atk.count - 1):
		return
	if not committed(atk, t):
		var aim := Kin.angle_of(w.player_pos() - at)
		a.lock_a[i] = aim
		a.facing[i] = aim
	elif t < hit_tick(atk, pending(atk, t)):
		var room := Kin.length(w.player_pos() - at) - a.radius[i] - w.player.radius_m - 0.1
		var want := minf(atk.step_m / STEP_TICKS * slow, maxf(room, 0.0))
		var step := minf(want, EnemyAi.clear_run(w, at, a.lock_a[i], want, a.radius[i]))
		if step > 0.0:
			a.set_pos(i, at + Kin.dir(a.lock_a[i]) * step)
	a.lock_x[i] = a.pos_x[i]
	a.lock_y[i] = a.pos_y[i]


## [center, own_r, angle, half_arc, reach] of the pending hit (AttackShapes.arc_touches).
static func combo_arc(w: World, i: int, atk: BossAttackTable) -> Array:
	var a := w.actors
	return [a.pos(i), a.radius[i], a.lock_a[i], atk.half_arc, atk.reach_m]


## The damage of hit k (before the boss's catch-up).
static func hit_damage(w: World, i: int, atk: BossAttackTable, k: int) -> int:
	var wt := BossAi.table_of(w, i).wardens
	if k >= atk.count - 1 or wt == null:
		return atk.damage
	return maxi(1, atk.damage * wt.combo_light_permille / 1000)


## Tick phase 6 (BossTwin.resolve): hit k lands on active tick k × gap_ticks.
static func combo_resolve(w: World, i: int, atk: BossAttackTable, st: int) -> void:
	if st % atk.gap_ticks != 0 or st / atk.gap_ticks >= atk.count:
		return
	var c := combo_arc(w, i, atk)
	var p := w.player_pos()
	if not AttackShapes.arc_touches(c[0], c[1], c[2], c[3], c[4], p, w.player.radius_m):
		return
	var a := w.actors
	var dmg := BossAi.powered(w, i, hit_damage(w, i, atk, st / atk.gap_ticks))
	Damage.hit(w, 0, dmg, a.ids[i], a.ids[i], w.take_root(), SimEvent.TAG_MELEE, c[0], p)
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = w.bosses.attack[BossAi.entry_of(w, i)]


## BossTwin.telegraph: the pending hit's &"arc", "tracked", "locked" once its aim holds, "progress" over the hit's own
## time (the telegraph for the first, the gap for the rest), "strike" (its index), "strikes" and "striking" on the
## tick it lands.
static func combo_telegraph(w: World, i: int, atk: BossAttackTable) -> Dictionary:
	var a := w.actors
	var t := attack_tick(w, i, atk)
	var k := pending(atk, t)
	if t > hit_tick(atk, atk.count - 1):
		return {}
	var c := combo_arc(w, i, atk)
	var span := atk.windup_ticks if k == 0 else atk.gap_ticks
	var into := span - (hit_tick(atk, k) - t)
	return {
		"shape": &"arc",
		"center": c[0],
		"own_r": c[1],
		"angle": c[2],
		"half_arc": c[3],
		"reach": c[4],
		"progress": clampi(into * 1000 / maxi(1, span), 0, 1000),
		"move": atk.move,
		"tracked": true,
		"locked": committed(atk, t),
		"strike": k,
		"strikes": atk.count,
		"striking": a.state[i] == S.ACTIVE and t == hit_tick(atk, k),
	}


# --- the side dash ------------------------------------------------------------------------------------------------


## True while the pair's boss dashes.
static func dashing(w: World) -> bool:
	return w.boss_fight.wd_dash_t > 0


## Tick phase 3 (BossTwin.think, the boss's turn): the dash's clock; free between two attacks with its clock out, it
## starts one.
static func dash_think(w: World, i: int, wt: BossWardensTable) -> void:
	var bs := w.boss_fight
	var a := w.actors
	if bs.wd_dash_cd > 0:
		bs.wd_dash_cd -= 1
	if a.state[i] != S.MOVE:
		bs.wd_dash_t = 0
		return
	if bs.wd_dash_t > 0 or bs.wd_dash_cd > 0 or a.cd[i] <= 0 or w.player_dead():
		return
	var at := a.pos(i)
	var to := w.player_pos() - at
	if Kin.length(to) > DASH_NEAR_M or Kin.length(to) < 0.0001:
		return
	var aim := Kin.angle_of(to)
	var first := 1 if bs.wd_dash_side >= 0 else -1
	for side: int in [first, -first]:
		var ang := (aim + side * 1024) & 4095
		if EnemyAi.clear_run(w, at, ang, wt.dash_m, a.radius[i]) < wt.dash_m * 0.5:
			continue
		var v := Kin.dir(ang) * (wt.dash_m / wt.dash_ticks)
		bs.wd_dash_t = wt.dash_ticks
		bs.wd_dash_vx = v.x
		bs.wd_dash_vy = v.y
		bs.wd_dash_side = -side
		bs.wd_dash_cd = wt.dash_every_ticks
		var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[i], a.ids[i], at)
		e.effect_id = DASH
		e.amount = wt.dash_ticks
		return
	bs.wd_dash_cd = wt.dash_ticks  # No room on either side: it asks again shortly


## Tick phase 5 (BossTwin.moves): a dash's step, stopped by walls. True while it dashes (nothing else moves it).
static func dash_move(w: World, i: int, slow: float) -> bool:
	var bs := w.boss_fight
	if bs.wd_dash_t <= 0:
		return false
	var a := w.actors
	if a.state[i] != S.MOVE:  # A gate or a stun ends it
		bs.wd_dash_t = 0
		return false
	bs.wd_dash_t -= 1
	var v := Vector2(bs.wd_dash_vx, bs.wd_dash_vy) * slow
	var len := Kin.length(v)
	if len > 0.0001:
		var run := EnemyAi.clear_run(w, a.pos(i), Kin.angle_of(v), len, a.radius[i])
		a.set_pos(i, a.pos(i) + v * (clampf(run, 0.0, len) / len))
	return true


# --- the charges on their own clocks ------------------------------------------------------------------------------


## True for an attack only its clock starts (BossTwin.may_use leaves it out of the weighted pick): the two clock
## charges and the whole ward's cast.
static func on_clock(wt: BossWardensTable, k: int) -> bool:
	return k >= 0 and (k == wt.charge_attack or k == wt.ward_charge_attack or k == wt.ward_attack)


## The charge whose clock runs for the amber Warden i now (an attack index), or -1: while he leads, the phase-1
## charge in a phase that lists it, or the ward-breaking one in a phase that lists it while the whole ward stands.
static func clock_charge(w: World, i: int, wt: BossWardensTable) -> int:
	if not BossTwin.leads(w, i):
		return -1
	var listed := BossAi.table_of(w, i).phase_attacks[w.bosses.phase[BossAi.entry_of(w, i)]]
	if wt.charge_attack >= 0 and listed.has(wt.charge_attack):
		return wt.charge_attack
	var j := BossTwin.partner_of(w, i)
	if wt.ward_charge_attack >= 0 and listed.has(wt.ward_charge_attack) and BossWard.full(w, j):
		return wt.ward_charge_attack
	return -1


## Tick phase 3 (BossTwin.think), the amber Warden free: its clock charge; true when it starts one now. The wait is
## drawn (the ai stream) as the clock starts to run and at each start, so one charge comes every so often from one
## start to the next, at any distance; the clock stops while no clock charge runs. A due charge waits out his side
## dash and, in phase 3, his turn (BossTwin.may_start: the two bodies alternate and never overlap).
static func charge_think(w: World, i: int, wt: BossWardensTable) -> bool:
	var fs := w.boss_fight
	var k := clock_charge(w, i, wt)
	if k < 0:
		fs.wd_charge_due = -1
		return false
	if fs.wd_charge_due < 0:
		fs.wd_charge_due = w.tick + _wait(w, wt, k)
		return false
	if w.tick < fs.wd_charge_due or fs.wd_dash_t > 0 or w.player_dead():
		return false
	if not BossTwin.may_start(w, i, BossTwin.pair_of(w, i)):
		return false  # Phase 3: his turn, the other body not attacking
	BossAi.start_attack(w, i, k)
	fs.wd_charge_due = w.tick + _wait(w, wt, k)
	return true


static func _wait(w: World, wt: BossWardensTable, k: int) -> int:
	if k == wt.charge_attack:
		return w.rng_ai.range_int(wt.charge_min_ticks, wt.charge_max_ticks)
	return w.rng_ai.range_int(wt.ward_charge_min_ticks, wt.ward_charge_max_ticks)


## True while the amber Warden i winds up the phase-1 clock charge (its tell is his body's flash, not a lane).
static func flashing(w: World, i: int) -> bool:
	var wt := BossAi.table_of(w, i).wardens
	if wt == null or wt.charge_attack < 0 or w.actors.state[i] != S.WINDUP:
		return false
	return w.bosses.attack[BossAi.entry_of(w, i)] == wt.charge_attack


## BossChallenge.aim_point, boss entry b: true while it aims the phase-1 clock charge (from its first tick: the
## wind-up starts before BossAi.start_attack locks the aim).
static func leads_charge(w: World, b: int) -> bool:
	var i := w.actors.index_of(w.bosses.ids[b])
	return i >= 0 and flashing(w, i)


## Where the phase-1 clock charge aims (BossChallenge.aim_point, so its wind-up tracks it until it commits): where the
## hero will be when it reaches them, from the hero's last step (World.vel, metres a tick) over the wind-up left and
## the run to them (once refined; the run no longer than the charge). Walking away does not take the hero out of it;
## a dash does.
static func lead_point(w: World, b: int) -> Vector2:
	var i := w.actors.index_of(w.bosses.ids[b])
	var atk := BossAi.attack_of(w, i)
	var at := w.actors.pos(i)
	var p := w.player_pos()
	var left := maxi(0, atk.windup_ticks - w.actors.state_t[i])
	var target := p
	for n in 2:
		var run := minf(Kin.length(target - at), atk.length_m)
		target = p + w.vel * (left + run / maxf(atk.speed, 0.0001))
	return target
