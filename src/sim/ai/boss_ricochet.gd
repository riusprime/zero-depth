class_name BossRicochet
extends RefCounted
## v0.8.0 BS2 (owner O5; docs/roadmap/v0.8.0/BOSS_SIGNATURES.md S5, approved 2026-10-14; SIM_CONTRACTS §10f): the
## Siege Engine's ricochet shells. A `pattern` attack with `bounces` (its Turret Cross) fires embers that bounce off
## a wall once instead of breaking on it, so the cross comes back at you from behind; from its `deploy` attack's
## bounce_phase on (phase 3) the turrets it deployed shoot shots that bounce once too. The bounce is the projectile
## sweep's own (World._projectile_hits, ItemEffects.bounce: reflected on the wall face's normal, an exact flip for the
## room's axis-aligned walls). Fair: a hostile shot never bounces when its way back would reach the player within
## SAFE_TICKS (0.5 s) of the bounce; it breaks on the wall instead. After its bounce a shot carries its attack's late
## part as its cause, so the recap names the ricochet. Pure: no stream is drawn here.

## A ricochet never comes back onto the player inside this many ticks of its bounce (the G1's 0.5 s).
const SAFE_TICKS := 30


## BossDodge.resolve_pattern, after BulletPatterns.fire queued `n` shots of attack `atk`: they bounce atk.bounces
## times.
static func arm_pattern(w: World, atk: BossAttackTable, n: int) -> void:
	if atk.bounces > 0 and n > 0:
		w.set_pending_bounces(n, atk.bounces)


## EnemyAi, a turret's shot just queued by actor i: from the live boss's deploy attack's bounce_phase on, a turret of
## the kind it deploys shoots a shot that bounces once, carrying that attack as its cause.
static func arm_turret(w: World, i: int) -> void:
	if w.boss_id < 0:
		return
	var bi := w.actors.index_of(w.boss_id)
	if bi < 0 or w.actors.dead[bi] == 1 or not BossAi.is_boss_kind(w.actors.kinds[bi]):
		return
	var t := BossAi.table_of(w, bi)
	var phase := w.bosses.phase[BossAi.entry_of(w, bi)]
	for k in t.attacks.size():
		var atk := t.attacks[k]
		if (
			atk.move == BossAttackTable.Move.DEPLOY
			and atk.bounce_phase <= phase
			and atk.enemy_kind == w.actors.kinds[i]
		):
			w.set_pending_bounces(1, 1)
			w.set_pending_cause(k)
			return


## World._projectile_hits: may projectile pi, at `at` on `wall`, bounce? A player's shot always may (Ricochet Core);
## a hostile one not when its reflected path would touch the player within SAFE_TICKS.
static func may_bounce(w: World, pi: int, at: Vector2, wall: Obb) -> bool:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_ENEMY or w.player_dead():
		return true
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var n := ItemEffects.wall_normal(at, p.radius[pi], wall)
	var back := v - n * (2.0 * v.dot(n))
	var from := at + n * ItemEffects.BOUNCE_CLEARANCE_M
	var to := from + back * SAFE_TICKS
	return Collide.sweep_vs_circle(from, to, p.radius[pi], w.player_pos(), w.player.radius_m) < 0.0


## After hostile projectile pi bounced: it carries its attack's late part (BossSignatures.LATE_CAUSE + the attack).
static func on_bounce(w: World, pi: int) -> void:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_ENEMY:
		return
	var c := p.cause_of(pi)
	if c >= 0 and c < BossSignatures.LATE_CAUSE:
		p.set_cause(pi, BossSignatures.LATE_CAUSE + c)
