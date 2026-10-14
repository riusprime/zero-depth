class_name BossGaze
extends RefCounted
## v0.8.0 BS2 (owner O5, "something that actually stands out for each boss"; docs/roadmap/v0.8.0/BOSS_SIGNATURES.md
## S4, approved 2026-10-14; SIM_CONTRACTS §10f): the Hive Lens's Gaze, a `gaze` attack. A continuous beam from its
## eye's edge, as long as its length_m unless a wall stops it (EnemyAi.clear_run: the room's walls, the Gatekeeper's
## pillars, a sealed door), half_width_m each side. Through its windup the eye brightens and a thin aim line shows
## where the beam will start: straight away from the player, re-aimed every tick, so it never starts on you. Then it
## turns a quarter turn (1024) every quarter_ticks, one way (the ai stream picks which as the windup begins),
## reversing every reverse_ticks, for its active time, hurting a player it touches once every burn_ticks; its orbs
## (the attack's pattern) fire again every orb_every_ticks, aimed at the player, while it turns. Drawn and hit alike
## (beam(): EI-07). Pure: integer angles (Kin), the ai stream only for the turn's way.

## The beam starts this far round from the player (a half turn: straight away).
const AWAY := 2048
## Returning orbs carry this cause (BossSignatures.LATE_CAUSE + the attack): the recap names the orbs, not the beam.
const ORB_CAUSE := BossSignatures.LATE_CAUSE


## BossAi._lock, as the windup begins: aimed away from the player; the way it will turn (BossStore.span, +1 or -1).
static func lock(w: World, i: int, b: int) -> void:
	keep_away(w, i)
	w.bosses.span[b] = 1 if w.rng_ai.range_int(0, 1) == 0 else -1


## Each windup tick (BossAi.think): the start keeps straight away from the player, wherever they go.
static func keep_away(w: World, i: int) -> void:
	var a := w.actors
	if not w.player_dead():
		a.lock_a[i] = (Kin.angle_of(w.player_pos() - a.pos(i)) + AWAY) & 4095
	a.facing[i] = a.lock_a[i]


## The beam's angle `st` active ticks in (st = 0: where the windup aimed it): a quarter turn every quarter_ticks
## along span's way, back the other way every reverse_ticks (integer maths).
static func angle_at(w: World, i: int, st: int) -> int:
	var atk := BossAi.attack_of(w, i)
	var period := maxi(1, atk.reverse_ticks)
	var into := st % period
	var along := into if (st / period) % 2 == 0 else period - into
	var turn := w.bosses.span[BossAi.entry_of(w, i)] * along * 1024 / maxi(1, atk.quarter_ticks)
	return (w.actors.lock_a[i] + turn) & 4095


## The beam along angle `ang`: from the eye's edge, as far as length_m unless a wall stops it.
static func beam_at(w: World, i: int, ang: int) -> Obb:
	var atk := BossAi.attack_of(w, i)
	var start := w.actors.pos(i) + Kin.dir(ang) * w.actors.radius[i]
	var run := EnemyAi.clear_run(w, start, ang, atk.length_m, atk.half_width_m)
	return AttackShapes.lane(start, ang, maxf(run, 0.01), atk.half_width_m)


## The beam on active tick `st`.
static func beam(w: World, i: int, st: int) -> Obb:
	return beam_at(w, i, angle_at(w, i, st))


## Tick phase 6 (BossAi.resolve): the beam hurts a player it touches, at most once every burn_ticks (the player's
## hurt iframes still apply); its orbs fire.
static func resolve(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	if st >= atk.active_ticks:
		return
	if st % atk.burn_ticks == 0:
		w.bosses.hit[b] = 0
	var o := beam(w, i, st)
	if Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, o) != Vector2.ZERO:
		BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, o.center)
	_orbs(w, i, atk, st)


## The orbs: the attack's pattern fires again every orb_every_ticks from orb_every_ticks on, from the body, aimed at
## where the player stands then (the pattern's gaps hold the aim), through BulletPatterns.fire (its fairness and caps).
static func _orbs(w: World, i: int, atk: BossAttackTable, st: int) -> void:
	var pat := atk.pattern
	if pat == null or atk.orb_every_ticks <= 0 or st < atk.orb_every_ticks:
		return
	var kw := BulletPatterns.wave_at(pat, st % atk.orb_every_ticks)
	if kw < 0:
		return
	var c := w.actors.pos(i)
	BulletPatterns.fire(
		w,
		i,
		pat,
		kw,
		c,
		Kin.angle_of(w.player_pos() - c),
		w.actors.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M,
		BossAi.powered(w, i, atk.damage),
		ORB_CAUSE + w.bosses.attack[BossAi.entry_of(w, i)]
	)


## Boss i's gaze for the views: {} or {"winding" (true in the windup: the eye brightening, the thin aim line),
## "progress" (0..1000 of the windup, then of the active time), "from", "to" (the beam's ends now, the aim line's in
## the windup), "angle" (1/4096 turns), "half_width", "way" (+1 or -1, the way it turns), "hit" (true where a wall
## stopped it short of its length)}.
static func state(w: World, i: int) -> Dictionary:
	var atk := BossAi.attack_of(w, i)
	var s := w.actors.state[i]
	if (
		atk == null
		or atk.move != BossAttackTable.Move.GAZE
		or (s != EnemyAi.State.WINDUP and s != EnemyAi.State.ACTIVE)
	):
		return {}
	var winding := s == EnemyAi.State.WINDUP
	var st := w.actors.state_t[i]
	var ang := w.actors.lock_a[i] if winding else angle_at(w, i, mini(st, atk.active_ticks - 1))
	var o := beam_at(w, i, ang)
	var d := Kin.dir(ang)
	var total := atk.windup_ticks if winding else atk.active_ticks
	return {
		"winding": winding,
		"progress": clampi(st * 1000 / maxi(1, total), 0, 1000),
		"from": o.center - d * o.half.x,
		"to": o.center + d * o.half.x,
		"angle": ang,
		"half_width": atk.half_width_m,
		"way": w.bosses.span[BossAi.entry_of(w, i)],
		"hit": o.half.x * 2.0 < atk.length_m - 0.01,
	}
