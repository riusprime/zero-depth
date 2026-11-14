class_name BossWardens
extends RefCounted
## The Twin Wardens' own mechanics, held together: which pair runs them (BossStore.wd_boss, the amber Warden's id,
## set as the pair rises when its table has `wardens`), their tick, their end and what the view reads. The pieces:
## BossWardenAmber (the sword combo, the side dash), BossWard (the Mirror Ward, the last phase's ward and its break),
## BossShadowSwords, BossRift (Through the Rift) and BossChargeBurst (the charge's burst, any boss's). They end with
## the pair, and the set piece and the wards' hint also when the hero is dead.


## BossTwin.on_spawn: the pair of boss body i runs the mechanics when its table has them.
static func begin(w: World, i: int) -> void:
	if BossAi.table_of(w, i).wardens == null:
		return
	w.bosses.clear_wardens()
	w.bosses.wd_boss = w.actors.ids[i]
	w.bosses.wd_dash_cd = BossAi.table_of(w, i).wardens.dash_every_ticks


## The amber Warden's actor index while a pair runs the mechanics, else -1.
static func lead(w: World) -> int:
	return w.actors.index_of(w.bosses.wd_boss) if w.bosses.wd_boss >= 0 else -1


## The violet Warden's actor index while a pair runs the mechanics, else -1.
static func violet(w: World) -> int:
	var bs := w.bosses
	var k := bs.twin_lead.find(bs.wd_boss) if bs.wd_boss >= 0 else -1
	return w.actors.index_of(bs.twin_body[k]) if k >= 0 else -1


## The table of the pair running the mechanics, or null.
static func table(w: World) -> BossWardensTable:
	var i := lead(w)
	return BossAi.table_of(w, i).wardens if i >= 0 else null


## Tick phase 6 (BossSignatures.advance): the wards' ends and hint, the set piece.
static func advance(w: World) -> void:
	var i := lead(w)
	var j := violet(w)
	if i < 0 or j < 0:
		return
	if w.player_dead():
		BossRift.close(w, i)
		w.objectives.clear(ObjectiveMarkers.TWINS_WARD)
		return
	BossWard.advance(w, i, j)
	BossRift.advance(w, i, j, BossAi.table_of(w, i).wardens)


## BossTwin.on_boss_gone: the pair is gone and its clocks with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var bs := w.bosses
	if bs.wd_boss < 0:
		return
	var k := bs.twin_lead.find(bs.wd_boss)
	if bs.wd_boss != boss_id and (k < 0 or bs.twin_body[k] != boss_id):
		return
	bs.clear_wardens()
	w.objectives.clear(ObjectiveMarkers.TWINS_WARD)


## WorldReader.boss_wardens: {} with no pair running the mechanics; else "lead" and "violet" (actor indices), "ward"
## (BossWard.state), "swords" (BossShadowSwords.rows), "rift" (BossRift.state), "dash" (ticks left of the amber
## Warden's side dash, 0 none) and, while he winds a charge up, "charge" {"lane" (Obb), "end" (where it will burst),
## "radius" (the burst's, 0 = none), "locked" (the aim holds), "progress" (0..1000), "breaks" (the violet Warden
## stands on the lane under her ward)}.
static func state(w: World) -> Dictionary:
	var i := lead(w)
	var j := violet(w)
	if i < 0 or j < 0:
		return {}
	var wt := BossAi.table_of(w, i).wardens
	var out := {
		"lead": i,
		"violet": j,
		"ward": BossWard.state(w, j),
		"swords": BossShadowSwords.rows(w, j),
		"rift": BossRift.state(w, i, wt),
		"dash": w.bosses.wd_dash_t,
	}
	var a := w.actors
	var atk := BossAi.attack_of(w, i)
	if (
		atk != null
		and atk.move == BossAttackTable.Move.CHARGE
		and a.state[i] == EnemyAi.State.WINDUP
	):
		var lane := EnemyAi.charge_lane(w, i)
		out["charge"] = {
			"lane": lane,
			"end": BossChargeBurst.end_of(w, i),
			"radius": atk.burst_radius_m,
			"locked": a.state_t[i] >= atk.windup_ticks - atk.lock_ticks,
			"progress": clampi(a.state_t[i] * 1000 / maxi(1, atk.windup_ticks), 0, 1000),
			"breaks":
			(
				BossWard.full(w, j)
				and Collide.circle_vs_obb(a.pos(j), a.radius[j], lane) != Vector2.ZERO
			),
		}
	return out
