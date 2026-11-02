class_name BossPrismLast
extends RefCounted
## v0.10.5 O3 (owner L6, 2026-11-01: "The prism feels better, we still have to work on the last phase"; "Needs
## something cooler while he's down and not on the dodging pattern"; "Boring pattern"; O3_PRISM.md): the Prism's last
## phase (her phase from 50 % HP: data/final_boss/prism.tres), beside BossPrism. Every number is in data, a starting
## value (owner, 2026-11-01).
## - The Facet Lances (`lances`): her shards fly to `count` rim spots distance_m from the fight's centre (stopped short
##   of walls), `spread` apart round it, the first on the player's side (her aim as the windup began: lock_a). Lance k
##   starts k × mark_gap_ticks into the active time: its line from its rim spot follows the player for track_ticks,
##   holds where it locked for lock_ticks (at least the telegraph minimum), then strikes for strike_ticks as a lane
##   half_width_m each side, from its rim spot through that point as far as length_m or a wall, hurting a player it
##   touches once. Each needs a sidestep a new way. She is shielded throughout (the attack's `shielded`).
## - The Shattered Kneel (`kneel`), right after: her shards spent, she falls (the windup), is down for the active time
##   (not shielded, nothing fired), then rises (the recovery). Hits from within the weak point's range of her edge deal
##   core_mult_permille (BossChallenge.hit_mult, TAG_EXPOSED). Her crack fills with the HP she loses from the down
##   time's start: at crack_permille of her max HP her core bursts: burst_permille of her max HP as the world's own
##   damage (owner 0: not the player's, so the pace's bucket does not cap it), STATUS_APPLY EFFECT_BURST for the views,
##   and the down time ends (she rises).
## One shape function each (lane, rim), drawn and hit alike (EI-07). Pure: integer angles (Kin), no stream drawn.

## STATUS_APPLY effect id: her core burst (amount: the burst's damage).
const EFFECT_BURST := &"prism_core_burst"
## A rim spot stands this far short of the wall that stops its run (m), and at least MIN_RIM_M from the centre.
const RIM_MARGIN_M := 0.6
const MIN_RIM_M := 1.0
## BossStore point of a kneel: her HP as the down time began (x), the tick her core burst (y; -1 not yet).
const KNEEL_AT := 0
## Lance phases (lance_phase).
const NOT_YET := -1
const TRACKING := 0
const LOCKED := 1
const STRIKING := 2
const DONE := 3

const M := BossAttackTable.Move


## Tick phase 6 (BossAi.resolve) for her last phase's moves, `st` ticks into the active time.
static func resolve(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	if atk.move == M.LANCES:
		_lances(w, i, b, atk, st)
	elif atk.move == M.KNEEL:
		_kneel(w, i, b, atk, st)


# --- the Facet Lances -------------------------------------------------------------------------------------------


## Lance k's phase `st` ticks into the active time: NOT_YET, TRACKING, LOCKED, STRIKING or DONE.
static func lance_phase(atk: BossAttackTable, k: int, st: int) -> int:
	var rel := st - k * atk.mark_gap_ticks
	if rel < 0:
		return NOT_YET
	if rel < atk.track_ticks:
		return TRACKING
	if rel < atk.track_ticks + atk.lock_ticks:
		return LOCKED
	if rel < atk.track_ticks + atk.lock_ticks + atk.strike_ticks:
		return STRIKING
	return DONE


## The active tick lance k strikes first.
static func strike_tick(atk: BossAttackTable, k: int) -> int:
	return k * atk.mark_gap_ticks + atk.track_ticks + atk.lock_ticks


## Lance k's rim spot: distance_m from the fight's centre (short of a wall), its share of the turn from her aim.
static func rim(w: World, i: int, atk: BossAttackTable, k: int) -> Vector2:
	var centre := w.final_fight.home if w.final_fight != null else w.actors.pos(i)
	var ang := (w.actors.lock_a[i] + k * atk.spread) & 4095
	var run := EnemyAi.clear_run(w, centre, ang, atk.distance_m, atk.half_width_m)
	var r := maxf(MIN_RIM_M, minf(atk.distance_m, run - RIM_MARGIN_M))
	return centre + Kin.dir(ang) * r


## Lance k's lane: from its rim spot through its tracked (then locked) point, as far as length_m or a wall.
static func lane(w: World, i: int, atk: BossAttackTable, k: int) -> Obb:
	var from := rim(w, i, atk, k)
	var to := w.bosses.pt(BossAi.entry_of(w, i), k) - from
	var ang := (
		Kin.angle_of(to)
		if to.x * to.x + to.y * to.y > 0.0001
		else (w.actors.lock_a[i] + k * atk.spread + 2048) & 4095
	)
	var run := EnemyAi.clear_run(w, from, ang, atk.length_m, atk.half_width_m)
	return AttackShapes.lane(from, ang, maxf(run, 0.01), atk.half_width_m)


static func _lances(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var bs := w.bosses
	var p := w.player_pos()
	for k in mini(atk.count, BossStore.MAX_PTS):
		var ph := lance_phase(atk, k, st)
		if ph == TRACKING:
			bs.set_pt(b, k, p)
		elif ph == STRIKING:
			if st == strike_tick(atk, k):
				bs.hit[b] = 0  # each lance can hit once
			if Collide.circle_vs_obb(p, w.player.radius_m, lane(w, i, atk, k)) != Vector2.ZERO:
				BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, rim(w, i, atk, k))


## Boss i's Facet Lances for the views: {} or {"winding" (the gather), "progress" (0..1000 of the windup or the active
## time), "half_width", "rims" (every lance's rim spot), "done" (the lances that have struck and gone), "lances"
## ([{"k", "phase", "progress" (0..1000 of its phase), "from", "to"}] for each lance tracking, locked or striking)}.
static func state(w: World, i: int) -> Dictionary:
	var atk := BossAi.attack_of(w, i)
	var s := w.actors.state[i]
	if (
		atk == null
		or atk.move != M.LANCES
		or (s != EnemyAi.State.WINDUP and s != EnemyAi.State.ACTIVE)
	):
		return {}
	var winding := s == EnemyAi.State.WINDUP
	var st := w.actors.state_t[i]
	var rims := PackedVector2Array()
	var lances: Array = []
	var done := 0
	var n := mini(atk.count, BossStore.MAX_PTS)
	for k in n:
		rims.append(rim(w, i, atk, k))
		if winding:
			continue
		var ph := lance_phase(atk, k, st)
		done += 1 if ph == DONE else 0
		if ph != TRACKING and ph != LOCKED and ph != STRIKING:
			continue
		var rel := st - k * atk.mark_gap_ticks
		var into := rel
		var span := atk.track_ticks
		if ph == LOCKED:
			into = rel - atk.track_ticks
			span = atk.lock_ticks
		elif ph == STRIKING:
			into = rel - atk.track_ticks - atk.lock_ticks
			span = atk.strike_ticks
		var o := lane(w, i, atk, k)
		var d := Kin.dir(o.angle)
		(
			lances
			. append(
				{
					"k": k,
					"phase": ph,
					"progress": clampi(into * 1000 / maxi(1, span), 0, 1000),
					"from": o.center - d * o.half.x,
					"to": o.center + d * o.half.x,
				}
			)
		)
	var total := atk.windup_ticks if winding else atk.active_ticks
	return {
		"winding": winding,
		"progress": clampi(st * 1000 / maxi(1, total), 0, 1000),
		"half_width": atk.half_width_m,
		"rims": rims,
		"done": done,
		"lances": lances,
	}


# --- the Shattered Kneel ----------------------------------------------------------------------------------------


## True while boss i is down in a kneel (its active time).
static func kneeling(w: World, i: int) -> bool:
	var atk := BossAi.attack_of(w, i)
	return (
		atk != null
		and atk.move == M.KNEEL
		and w.actors.state[i] == EnemyAi.State.ACTIVE
		and BossAi.entry_of(w, i) >= 0
	)


## BossChallenge.hit_mult: the core's multiplier while she kneels (1000 otherwise).
static func core_mult(w: World, i: int) -> int:
	return BossAi.attack_of(w, i).core_mult_permille if kneeling(w, i) else 1000


## The crack in the kneel in progress, 0..1000: the HP she lost since the down time began over crack_permille of her
## max HP (1000 once burst).
static func crack(w: World, i: int) -> int:
	var atk := BossAi.attack_of(w, i)
	var b := BossAi.entry_of(w, i)
	if atk == null or atk.move != M.KNEEL or b < 0:
		return 0
	var bs := w.bosses
	if w.actors.state[i] == EnemyAi.State.WINDUP:
		return 0
	if int(bs.pts_y[b * BossStore.MAX_PTS + KNEEL_AT]) >= 0:
		return 1000
	var need := maxi(1, w.actors.max_hp[i] * atk.crack_permille / 1000)
	var lost := int(bs.pts_x[b * BossStore.MAX_PTS + KNEEL_AT]) - w.actors.hp[i]
	return clampi(lost * 1000 / need, 0, 1000)


static func _kneel(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var bs := w.bosses
	var a := w.actors
	var at := b * BossStore.MAX_PTS + KNEEL_AT
	if st == 0:
		bs.pts_x[at] = a.hp[i]
		bs.pts_y[at] = -1.0
	if st >= atk.active_ticks or int(bs.pts_y[at]) >= 0 or crack(w, i) < 1000:
		return
	bs.pts_y[at] = w.tick
	var dmg := maxi(1, a.max_hp[i] * atk.burst_permille / 1000)
	var id := a.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, a.pos(i))
	e.effect_id = EFFECT_BURST
	e.amount = dmg
	if atk.burst_permille > 0:
		Damage.hit(w, i, dmg, 0, 0, w.take_root(), SimEvent.TAG_EXPOSED, a.pos(i), a.pos(i))
	if a.dead[i] == 0:
		a.state_t[i] = atk.active_ticks  # she rises at once (BossAi.think ends the active time next tick)


## Boss i's kneel for the views: {} or {"stage" (0 falling, 1 down, 2 rising), "progress" (0..1000 of the stage),
## "crack" (0..1000), "burst_tick" (the tick her core burst, -1 not yet), "range" (the core's reach from her centre)}.
static func kneel_state(w: World, i: int) -> Dictionary:
	var atk := BossAi.attack_of(w, i)
	var b := BossAi.entry_of(w, i)
	if atk == null or atk.move != M.KNEEL or b < 0:
		return {}
	var s := w.actors.state[i]
	var stage := -1
	var span := 1
	match s:
		EnemyAi.State.WINDUP:
			stage = 0
			span = atk.windup_ticks
		EnemyAi.State.ACTIVE:
			stage = 1
			span = atk.active_ticks
		EnemyAi.State.RECOVER:
			stage = 2
			span = atk.recover_ticks
	if stage < 0:
		return {}
	var t := BossAi.table_of(w, i)
	return {
		"stage": stage,
		"progress": clampi(w.actors.state_t[i] * 1000 / maxi(1, span), 0, 1000),
		"crack": crack(w, i),
		"burst_tick": int(w.bosses.pts_y[b * BossStore.MAX_PTS + KNEEL_AT]) if stage > 0 else -1,
		"range": w.actors.radius[i] + t.weak_range_m,
	}
