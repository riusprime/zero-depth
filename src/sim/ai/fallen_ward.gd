class_name FallenWard
extends RefCounted
## The Twin Wardens' ward as The Fallen remembers it (BossRemembered): The Fallen stands still under a whole ward and
## takes nothing (Damage._blocked asks blocks) for at most ward_ticks. A shade of the amber Warden (no actor: a point
## with a state, BossFightStore.fl_sh_*, hit by nothing) stands ward_edge_m in from the room's edge farthest from the
## hero and charges at the hero, as the amber Warden's charge does:
## - a wind-up of ward_windup_ticks whose aim follows the hero until ward_lock_ticks before its end, then a run at
##   ward_speed to ward_overshoot_m past where the hero stood as it locked (a wall cuts it short);
## - its touch costs the hero ward_hit per mille of max HP once a charge; where the run ends a burst of ward_burst_m
##   costs ward_burst_hit ward_burst_ticks later (SafeArea's ONCE: armour and the dash's invulnerability apply; the
##   recap's line is the carrier fallen_shade);
## - a run whose lane touches The Fallen breaks the ward: the charge ends there without its burst and The Fallen is
##   stunned ward_stun_ticks (BossAi.STAGGERED; its table's quake stun_permille of every hit meanwhile, BossQuake);
##   the mechanic ends with the stun.
## A charge that misses is followed ward_gap_ticks after its end by the next (the shade stands at the farthest edge
## again) until ward_charges were run; after the last one's burst the ward ends by itself.
## Pure: no stream is drawn.

const S := EnemyAi.State
## STATUS_APPLY effects, source The Fallen. UP / DOWN: the ward stands / is gone. BREAK: a charge broke it (pos = The
## Fallen, amount = the stun's ticks). CHARGE: the shade winds a charge up (pos = where it stands, amount = the
## wind-up's ticks, amount_applied = which charge, 1 first). HIT: its touch hit the hero (amount = the HP it cost).
## Its burst: BossChargeBurst.ARMED and BURST.
const UP := &"fallen_ward_up"
const DOWN := &"fallen_ward_down"
const BREAK := &"fallen_ward_break"
const CHARGE := &"fallen_shade_charge"
const HIT := &"fallen_shade_hit"
## The damage's effect ids (the HIT and DAMAGE events).
const EFFECT := &"fallen_shade"
const BURST_EFFECT := &"fallen_shade_burst"
const WINDUP := 1
const RUN := 2
const WAIT := 3


## Damage._blocked: true while actor `target` is The Fallen under its ward.
static func blocks(w: World, target: int) -> bool:
	var fs := w.boss_fight
	return fs.fl_ward == 1 and target > 0 and w.actors.ids[target] == fs.fl_boss


static func begin(w: World, i: int, m: FallenRememberedTable) -> bool:
	var fs := w.boss_fight
	fs.fl_ward = 1
	fs.fl_stun_until = -1
	fs.fl_bu_at = -1
	fs.fl_sh_n = 0
	_tell(w, i, UP, w.actors.pos(i)).amount = m.ward_ticks
	_appear(w, i, m)
	return true


## The shade stands at the room's edge farthest from the hero and winds its next charge up.
static func _appear(w: World, i: int, m: FallenRememberedTable) -> void:
	var fs := w.boss_fight
	var home := w.final_fight.home
	var away := home - w.player_pos()
	if Kin.length(away) < 0.1:
		away = home - w.actors.pos(i)
	var dir := away / Kin.length(away) if Kin.length(away) >= 0.1 else Vector2.RIGHT
	var at := home + dir * maxf(0.0, fs.fl_r - m.ward_edge_m)
	fs.fl_sh_x = at.x
	fs.fl_sh_y = at.y
	fs.fl_sh_stage = WINDUP
	fs.fl_sh_at = w.tick
	fs.fl_sh_n += 1
	fs.fl_sh_hit = 0
	fs.fl_sh_a = Kin.angle_of(w.player_pos() - at)
	fs.fl_sh_len = _reach(w, at, fs.fl_sh_a, m)
	var e := _tell(w, i, CHARGE, at)
	e.amount = m.ward_windup_ticks
	e.amount_applied = fs.fl_sh_n


## How far a run from `from` along `angle` goes: ward_overshoot_m past the hero's spot, cut short by a wall.
static func _reach(w: World, from: Vector2, angle: int, m: FallenRememberedTable) -> float:
	var want := Kin.length(w.player_pos() - from) + m.ward_overshoot_m
	return clampf(EnemyAi.clear_run(w, from, angle, want, m.ward_radius_m), 0.0, want)


static func _shade(w: World) -> Vector2:
	return Vector2(w.boss_fight.fl_sh_x, w.boss_fight.fl_sh_y)


## One tick of the ward; true when it is over (the stun of its break ended, the last charge's burst went off, or its
## time ran out).
static func step(w: World, i: int, m: FallenRememberedTable) -> bool:
	var fs := w.boss_fight
	if fs.fl_stun_until >= 0:
		return w.tick >= fs.fl_stun_until
	_burst(w, i, m)
	match fs.fl_sh_stage:
		WINDUP:
			var t := w.tick - fs.fl_sh_at
			if t <= m.ward_windup_ticks - m.ward_lock_ticks:  # The aim follows, then locks
				fs.fl_sh_a = Kin.angle_of(w.player_pos() - _shade(w))
				fs.fl_sh_len = _reach(w, _shade(w), fs.fl_sh_a, m)
			if t >= m.ward_windup_ticks:
				fs.fl_sh_stage = RUN
				fs.fl_sh_at = w.tick
				fs.fl_sh_ox = fs.fl_sh_x
				fs.fl_sh_oy = fs.fl_sh_y
		RUN:
			_run(w, i, m)
		WAIT:
			if fs.fl_sh_n < m.ward_charges and w.tick - fs.fl_sh_at >= m.ward_gap_ticks:
				_appear(w, i, m)
			elif fs.fl_sh_n >= m.ward_charges and fs.fl_bu_at < 0:
				return true
	if fs.fl_stun_until >= 0:
		return false
	return w.tick - fs.fl_from >= m.ward_ticks


## The run's tick: the shade moves on along its lane; its touch hits the hero once; its lane through The Fallen
## breaks the ward; at its end it arms the burst.
static func _run(w: World, i: int, m: FallenRememberedTable) -> void:
	var fs := w.boss_fight
	var a := w.actors
	var from := Vector2(fs.fl_sh_ox, fs.fl_sh_oy)
	var dir := Kin.dir(fs.fl_sh_a)
	var was := _shade(w)
	var went := minf(fs.fl_sh_len, (w.tick - fs.fl_sh_at) * m.ward_speed)
	var now := from + dir * went
	fs.fl_sh_x = now.x
	fs.fl_sh_y = now.y
	var reach := m.ward_radius_m + a.radius[i] + EnemyAi.CONTACT_SLOP_M
	if BossNemesis.segment_distance(a.pos(i), from, now) <= reach:
		_break(w, i, m)
		return
	if (
		fs.fl_sh_hit == 0
		and not w.player_dead()
		and (
			BossNemesis.segment_distance(w.player_pos(), was, now)
			<= m.ward_radius_m + w.player.radius_m
		)
	):
		fs.fl_sh_hit = 1
		var cost := SafeArea.hurt(w, i, m.ward_hit, SafeArea.Mode.ONCE, m.ward_cause, EFFECT)
		var e := _tell(w, i, HIT, w.player_pos())
		e.target_id = a.ids[0]
		e.amount = cost
	if went >= fs.fl_sh_len - 0.0001:
		fs.fl_sh_stage = WAIT
		fs.fl_sh_at = w.tick
		fs.fl_bu_at = w.tick + m.ward_burst_ticks
		fs.fl_bu_x = now.x
		fs.fl_bu_y = now.y
		_tell(w, i, BossChargeBurst.ARMED, now).amount = m.ward_burst_ticks


## The armed burst goes off on its tick.
static func _burst(w: World, i: int, m: FallenRememberedTable) -> void:
	var fs := w.boss_fight
	if fs.fl_bu_at < 0 or w.tick < fs.fl_bu_at:
		return
	fs.fl_bu_at = -1
	var c := Vector2(fs.fl_bu_x, fs.fl_bu_y)
	var cost := 0
	if AttackShapes.disc_touches(c, m.ward_burst_m, w.player_pos(), w.player.radius_m):
		cost = SafeArea.hurt(w, i, m.ward_burst_hit, SafeArea.Mode.ONCE, m.ward_cause, BURST_EFFECT)
	var e := _tell(w, i, BossChargeBurst.BURST, c)
	e.target_id = w.actors.ids[0]
	e.amount = cost


## The lane touched The Fallen: the ward breaks, the charge ends without its burst, The Fallen is stunned.
static func _break(w: World, i: int, m: FallenRememberedTable) -> void:
	var fs := w.boss_fight
	var a := w.actors
	var b := BossAi.entry_of(w, i)
	fs.fl_ward = 0
	fs.fl_sh_stage = 0
	fs.fl_bu_at = -1
	fs.fl_stun_until = w.tick + m.ward_stun_ticks
	w.bosses.attack[b] = -1
	w.bosses.stagger_t[b] = m.ward_stun_ticks
	a.lock_len[i] = 0.0
	a.state[i] = BossAi.STAGGERED
	a.state_t[i] = 0
	_tell(w, i, BREAK, a.pos(i)).amount = m.ward_stun_ticks
	_tell(w, i, DOWN, a.pos(i))


static func finish(w: World, i: int) -> void:
	if w.boss_fight.fl_ward == 1:
		_tell(w, i, DOWN, w.actors.pos(i))
	clear(w)


## The ward, the shade and its burst are gone (a stun under way runs out by itself).
static func clear(w: World) -> void:
	var fs := w.boss_fight
	fs.fl_ward = 0
	fs.fl_sh_stage = 0
	fs.fl_bu_at = -1
	fs.fl_stun_until = -1


static func _tell(w: World, i: int, effect: StringName, at: Vector2) -> SimEvent:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = effect
	return e


# --- the view's read (BossRemembered.state) ---------------------------------------------------------------------


static func _running(w: World) -> bool:
	var fs := w.boss_fight
	return fs.fl_kind == BossRemembered.WARD and fs.fl_stage == BossRemembered.STAGE_RUN


## {} unless the ward mechanic runs; else "up", "stun_left" (ticks), "left" (ticks until it ends by its time).
static func ward_state(w: World, m: FallenRememberedTable) -> Dictionary:
	var fs := w.boss_fight
	if not _running(w):
		return {}
	var stun := maxi(0, fs.fl_stun_until - w.tick) if fs.fl_stun_until >= 0 else 0
	return {
		"up": fs.fl_ward == 1,
		"stun_left": stun,
		"left": stun if fs.fl_stun_until >= 0 else maxi(0, m.ward_ticks - (w.tick - fs.fl_from)),
	}


## {} with no shade; else its "position", "radius", "stage", "charge", "charges", "lane" (Obb from where its run
## starts), "locked", "progress" (0..1000 through the wind-up, 1000 running), "end" (where the run ends),
## "burst_radius".
static func shade_state(w: World, m: FallenRememberedTable) -> Dictionary:
	var fs := w.boss_fight
	if not _running(w) or fs.fl_sh_stage == 0 or fs.fl_sh_stage == WAIT:
		return {}
	var from := _shade(w) if fs.fl_sh_stage == WINDUP else Vector2(fs.fl_sh_ox, fs.fl_sh_oy)
	var t := w.tick - fs.fl_sh_at
	return {
		"position": _shade(w),
		"radius": m.ward_radius_m,
		"stage": fs.fl_sh_stage,
		"charge": fs.fl_sh_n,
		"charges": m.ward_charges,
		"lane": AttackShapes.lane(from, fs.fl_sh_a, fs.fl_sh_len, m.ward_radius_m),
		"locked": fs.fl_sh_stage == RUN or t > m.ward_windup_ticks - m.ward_lock_ticks,
		"progress":
		(
			clampi(t * 1000 / maxi(1, m.ward_windup_ticks), 0, 1000)
			if fs.fl_sh_stage == WINDUP
			else 1000
		),
		"end": from + Kin.dir(fs.fl_sh_a) * fs.fl_sh_len,
		"burst_radius": m.ward_burst_m,
	}


## {} with no burst armed; else "centre", "radius", "left" (ticks), "progress" (0..1000).
static func burst_state(w: World, m: FallenRememberedTable) -> Dictionary:
	var fs := w.boss_fight
	if fs.fl_bu_at < 0:
		return {}
	var left := fs.fl_bu_at - w.tick
	return {
		"centre": Vector2(fs.fl_bu_x, fs.fl_bu_y),
		"radius": m.ward_burst_m,
		"left": left,
		"progress": clampi(1000 - left * 1000 / maxi(1, m.ward_burst_ticks), 0, 1000),
	}
