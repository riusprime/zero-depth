class_name EliteAi
extends RefCounted
## v0.9.0 EL (owner Q26; G1 docs/roadmap/v0.9.0/ELITES.md rows E1-E3, "ok go for those"): the three elite archetypes'
## behaviour. Each is one state machine in ActorStore, as EnemyAi's (state, state_t, pick, cd, fire_cd, windup, lock_*),
## run from EnemyAi's hooks (think in phase 3, EnemyAi.move in phase 5: the walk follows EnemyAi.plan, resolve in
## phase 6). Every elite has ONE special ability (pick ABILITY: telegraph, strike, recovery: the punish window) and at
## most one plain attack between them (pick BASIC); no speed or damage stacking (W59). Numbers: EliteTable.
## - The Breaker (E1): walks at you slowly. Ground Slam, every_ticks start to start once you are near: it raises the
##   fist (windup_ticks; a ground circle of radius_m fills in under it), slams (damage in the circle), then stays stuck
##   recover_ticks with its fist in the ground, taking vulnerable_permille of every hit. Between slams a short punch
##   (basic_damage, reaching basic_range_m past its body) at you when you stand close.
## - The Rift Hunter (E2): keeps keep_min_m..keep_max_m away, circling. Rift Step, every_ticks start to start within
##   range_m: it marks a spot on you (a rift on the floor; the mark follows you for track_ticks, then locks), vanishes
##   for the windup's last vanish_ticks (no body, no hits), reappears on the mark and slashes the disc of radius_m round
##   it, then stands still recover_ticks.
## - The Conduit (E3): floats, keeps keep_min_m..keep_max_m away, never hurts by contact. Charged Beam, every_ticks
##   start to start: it plants its staff and charges (a line from it toward you, following you for track_ticks, then
##   locked and brightening), fires a beam half_width_m either side of the line to the room's wall (damage, once),
##   then overloads recover_ticks: down on the floor, taking vulnerable_permille of every hit. Between beams it casts a
##   slow fan of orbs (basic_pattern, basic_damage each) every basic_every_ticks.
## Fair (ELITES.md E0): every telegraph shows at least 0.8 s before its hit (the content validation); no attack starts
## or lands without a clear line to the hero (EnemyAi.sees_player: walls and a sealed doorway's bars); a mark never
## starts anywhere but where the hero stands now. Contact: touching a walking elite's body hurts for contact_damage
## at most every contact_cd_ticks (Elites holds the clock); never in its windup, strike or punish window. Deaths
## name the elite and the attack (cause_key).
## Pure sim code: Kin angles, no stream drawn (the archetypes' timings are fixed).

enum Attack { BASIC, ABILITY }

## World.killer_attack for an elite's kill (the recap: cause_key): its contact, its plain attack, its ability.
const CAUSE_CONTACT := 0
const CAUSE_BASIC := 1
const CAUSE_ABILITY := 2
## Aimed plain attacks (the punch, the orb fan) stop following you this many ticks before they land.
const COMMIT_TICKS := 12
## The Breaker slams once you are within its circle plus this margin (m).
const SLAM_REACH_M := 0.5
## A touch counts within this much of contact (the collision pass has pushed the bodies apart: EnemyAi's slop).
const CONTACT_SLOP_M := 0.05
## The punch lane's half-width (m).
const PUNCH_HALF_M := 0.6
## Where the Conduit's line starts: this far past its body, along its aim (its staff's crystal).
const STAFF_M := 0.2
## The Conduit's beam shows this long after it fired (ticks; the hit itself is one tick).
const BEAM_SHOW_TICKS := 12
const CAUSE_KEYS := {
	ActorStore.Kind.BREAKER:
	[&"CAUSE_ELITE_BREAKER_CONTACT", &"CAUSE_ELITE_BREAKER_PUNCH", &"CAUSE_ELITE_BREAKER_SLAM"],
	ActorStore.Kind.RIFT_HUNTER:
	[
		&"CAUSE_ELITE_RIFT_HUNTER_CONTACT",
		&"CAUSE_ELITE_RIFT_HUNTER_SLASH",
		&"CAUSE_ELITE_RIFT_HUNTER_SLASH"
	],
	ActorStore.Kind.CONDUIT:
	[&"CAUSE_ELITE_CONDUIT_ORBS", &"CAUSE_ELITE_CONDUIT_ORBS", &"CAUSE_ELITE_CONDUIT_BEAM"],
}


static func is_elite_kind(kind: int) -> bool:
	return kind >= ActorStore.Kind.BREAKER and kind <= ActorStore.Kind.CONDUIT


static func table_of(w: World, i: int) -> EliteTable:
	var t := w.enemy_table(w.actors.kinds[i])
	return t.elite if t != null else null


# --- think (tick phase 3) ------------------------------------------------------------------------------------------
static func think(w: World, i: int) -> void:
	var a := w.actors
	var e := table_of(w, i)
	if e == null:
		return
	if EnemyAi.plans_now(w, i):  # the staggered walk, as every enemy's (EnemyAi.plan; its walk is EnemyAi.move)
		EnemyAi.plan(w, i)
	if a.frozen_t[i] > 0:
		return
	a.state_t[i] += 1
	if a.cd[i] > 0:
		a.cd[i] -= 1
	if a.fire_cd[i] > 0:
		a.fire_cd[i] -= 1
	match a.state[i]:
		EnemyAi.State.SPAWN:
			if a.state_t[i] >= w.tuning.spawn_in_ticks:
				EnemyAi.enter_state(a, i, EnemyAi.State.MOVE)
		EnemyAi.State.MOVE:
			_choose(w, i, e)
		EnemyAi.State.WINDUP:
			_wind(w, i, e)
			if a.state_t[i] >= a.windup[i]:
				_strike(w, i, e)
				EnemyAi.enter_state(a, i, EnemyAi.State.ACTIVE)
		EnemyAi.State.ACTIVE:
			var pat := e.basic_pattern if a.pick[i] == Attack.BASIC else null
			if pat == null or a.state_t[i] >= pat.duration_ticks():
				EnemyAi.enter_state(a, i, EnemyAi.State.RECOVER)
		EnemyAi.State.RECOVER:
			var rec := e.recover_ticks if a.pick[i] == Attack.ABILITY else e.basic_recover_ticks
			if a.state_t[i] >= rec:
				EnemyAi.enter_state(a, i, EnemyAi.State.MOVE)


## Walking: it faces you, and starts its ability once ready and in reach, else its plain attack, only with a clear
## line to you.
static func _choose(w: World, i: int, e: EliteTable) -> void:
	var a := w.actors
	if w.player_dead():
		return
	var to := w.player_pos() - a.pos(i)
	var dist := Kin.length(to)
	a.facing[i] = Kin.angle_of(to)
	if not EnemyAi.sees_player(w, a.pos(i)):
		return
	if a.cd[i] == 0 and _ability_in_reach(w, i, e, dist):
		a.cd[i] = e.every_ticks
		_begin(w, i, Attack.ABILITY, e.windup_ticks)
	elif e.basic_damage > 0 and a.fire_cd[i] == 0 and _basic_in_reach(w, i, e, dist):
		a.fire_cd[i] = e.basic_every_ticks
		_begin(w, i, Attack.BASIC, e.basic_windup_ticks)


static func _ability_in_reach(w: World, i: int, e: EliteTable, dist: float) -> bool:
	match w.actors.kinds[i]:
		ActorStore.Kind.BREAKER:
			return dist <= e.radius_m + w.player.radius_m + SLAM_REACH_M
		_:
			return dist <= e.range_m


static func _basic_in_reach(w: World, i: int, e: EliteTable, dist: float) -> bool:
	if w.actors.kinds[i] == ActorStore.Kind.BREAKER:
		return dist <= w.actors.radius[i] + e.basic_range_m + w.player.radius_m
	return e.basic_pattern != null and dist <= e.range_m


static func _begin(w: World, i: int, which: int, windup: int) -> void:
	var a := w.actors
	a.pick[i] = which
	a.windup[i] = windup
	EnemyAi.enter_state(a, i, EnemyAi.State.WINDUP)
	a.lock_a[i] = a.facing[i]
	var at := a.pos(i)
	if a.kinds[i] == ActorStore.Kind.RIFT_HUNTER and which == Attack.ABILITY:
		at = w.player_pos()  # the mark starts on you
	a.lock_x[i] = at.x
	a.lock_y[i] = at.y
	a.lock_len[i] = 0.0
	if a.kinds[i] == ActorStore.Kind.CONDUIT and which == Attack.ABILITY:
		a.lock_len[i] = _beam_length(w, i)


## The windup: what still follows you (the mark, the line, a plain attack's aim) and the Rift Hunter's vanish.
static func _wind(w: World, i: int, e: EliteTable) -> void:
	var a := w.actors
	var st := a.state_t[i]
	var alive := not w.player_dead()
	if a.pick[i] == Attack.BASIC:
		if alive and st < a.windup[i] - COMMIT_TICKS:
			a.lock_a[i] = Kin.angle_of(w.player_pos() - a.pos(i))
			a.facing[i] = a.lock_a[i]
		return
	match a.kinds[i]:
		ActorStore.Kind.RIFT_HUNTER:
			if alive and st < e.track_ticks:
				a.lock_x[i] = w.player_pos().x
				a.lock_y[i] = w.player_pos().y
			if st == a.windup[i] - e.vanish_ticks:  # gone: no body to hit until it reappears
				a.invuln[i] = maxi(a.invuln[i], e.vanish_ticks + 1)
		ActorStore.Kind.CONDUIT:
			if alive and st < e.track_ticks:
				a.lock_a[i] = Kin.angle_of(w.player_pos() - a.pos(i))
				a.facing[i] = a.lock_a[i]
				a.lock_len[i] = _beam_length(w, i)


## The windup's end: the Rift Hunter reappears on its mark, facing you.
static func _strike(w: World, i: int, _e: EliteTable) -> void:
	var a := w.actors
	if a.kinds[i] == ActorStore.Kind.RIFT_HUNTER and a.pick[i] == Attack.ABILITY:
		a.set_pos(i, Vector2(a.lock_x[i], a.lock_y[i]))
		a.invuln[i] = 0
		if not w.player_dead():
			a.facing[i] = Kin.angle_of(w.player_pos() - a.pos(i))


# --- resolve (tick phase 6) ----------------------------------------------------------------------------------------
static func resolve(w: World, i: int) -> void:
	var a := w.actors
	var e := table_of(w, i)
	if e == null or w.player_dead() or Engines.frozen(w, i):
		return
	_contact(w, i, e)
	if a.state[i] != EnemyAi.State.ACTIVE or w.player_dead():
		return
	var p := w.player_pos()
	var pr := w.player.radius_m
	if a.pick[i] == Attack.BASIC:
		if e.basic_pattern != null:
			var k := BulletPatterns.wave_at(e.basic_pattern, a.state_t[i])
			if k >= 0:
				var r := a.radius[i] + e.basic_pattern.radius_m + BulletPatterns.MUZZLE_M
				var dmg := EnemyAi.powered(w, i, e.basic_damage)
				BulletPatterns.fire(
					w, i, e.basic_pattern, k, a.pos(i), a.lock_a[i], r, dmg, CAUSE_BASIC
				)
		elif a.state_t[i] == 0 and Collide.circle_vs_obb(p, pr, punch_lane(w, i)) != Vector2.ZERO:
			_hit(w, i, e.basic_damage, SimEvent.TAG_MELEE, a.pos(i), CAUSE_BASIC)
		return
	if a.state_t[i] != 0:
		return
	match a.kinds[i]:
		ActorStore.Kind.BREAKER, ActorStore.Kind.RIFT_HUNTER:
			var c := Vector2(a.lock_x[i], a.lock_y[i])
			if AttackShapes.disc_touches(c, e.radius_m, p, pr):
				_hit(w, i, e.damage, SimEvent.TAG_AREA, c, CAUSE_ABILITY)
		ActorStore.Kind.CONDUIT:
			if Collide.circle_vs_obb(p, pr, beam_lane(w, i)) != Vector2.ZERO:
				_hit(w, i, e.damage, SimEvent.TAG_AREA, a.pos(i), CAUSE_ABILITY)


## Touching its body while it walks hurts (contact_damage), at most every contact_cd_ticks.
static func _contact(w: World, i: int, e: EliteTable) -> void:
	var a := w.actors
	if e.contact_damage <= 0 or a.state[i] != EnemyAi.State.MOVE:
		return  # only while it walks: never as it rises, winds up, strikes or stands in its punish window
	var s := w.elites
	var k := s.ids.find(a.ids[i]) if s != null else -1
	if k < 0 or w.tick < s.contact_tick[k]:
		return
	var reach := a.radius[i] + w.player.radius_m + CONTACT_SLOP_M
	if Kin.length(w.player_pos() - a.pos(i)) > reach:
		return
	s.contact_tick[k] = w.tick + e.contact_cd_ticks
	_hit(w, i, e.contact_damage, SimEvent.TAG_MELEE, a.pos(i), CAUSE_CONTACT)


static func _hit(w: World, i: int, amount: int, tags: int, from: Vector2, cause: int) -> void:
	var was_dead := w.player_dead()
	EnemyAi.hit_player(w, i, amount, tags, from)
	if w.player_dead() and not was_dead:
		w.killer_attack = cause  # the recap names the elite's attack (cause_key)


# --- shapes (the hit and the telegraph read the same function: EI-07) ----------------------------------------------
## The Breaker's punch: a lane from its centre along its aim, basic_range_m past its body.
static func punch_lane(w: World, i: int) -> Obb:
	var a := w.actors
	var e := table_of(w, i)
	return AttackShapes.lane(a.pos(i), a.lock_a[i], a.radius[i] + e.basic_range_m, PUNCH_HALF_M)


## The Conduit's beam: from its staff along its aim to the first wall (at most range_m), half_width_m either side.
static func beam_lane(w: World, i: int) -> Obb:
	var a := w.actors
	var e := table_of(w, i)
	var start := a.pos(i) + Kin.dir(a.lock_a[i]) * STAFF_M
	return AttackShapes.lane(start, a.lock_a[i], maxf(a.lock_len[i], 0.01), e.half_width_m)


static func _beam_length(w: World, i: int) -> float:
	var a := w.actors
	var e := table_of(w, i)
	var start := a.pos(i) + Kin.dir(a.lock_a[i]) * STAFF_M
	return EnemyAi.clear_run(w, start, a.lock_a[i], e.range_m, 0.05)


# --- what the rest of the sim and the views read ------------------------------------------------------------------
## The Rift Hunter has vanished (the windup's last vanish_ticks): no body, no hits, no contact.
static func vanished(w: World, i: int) -> bool:
	var a := w.actors
	if a.kinds[i] != ActorStore.Kind.RIFT_HUNTER or a.state[i] != EnemyAi.State.WINDUP:
		return false
	if a.pick[i] != Attack.ABILITY:
		return false
	var e := table_of(w, i)
	return e != null and a.state_t[i] >= a.windup[i] - e.vanish_ticks


## In its punish window: recovering from its ability, taking vulnerable_permille of every hit (Damage.target_mult).
static func vulnerable(w: World, i: int) -> bool:
	var a := w.actors
	if a.state[i] != EnemyAi.State.RECOVER or a.pick[i] != Attack.ABILITY:
		return false
	var e := table_of(w, i)
	return e != null and e.vulnerable_permille > 1000


static func vulnerable_permille(w: World, i: int) -> int:
	var e := table_of(w, i)
	return e.vulnerable_permille if e != null else 1000


## What the views draw (EnemyAi.telegraph's shape): the slam's filling circle and the rift mark and the beam's line
## on the ground ("tracked" while they follow you, "locked" after), the punch and the orb fan as body cues only
## ("ground": false). "elite": its kind, "attack": Attack.
static func telegraph(w: World, i: int) -> Dictionary:
	var a := w.actors
	var e := table_of(w, i)
	if e == null or a.state[i] != EnemyAi.State.WINDUP:
		return {}
	var st := a.state_t[i]
	var progress := clampi(st * 1000 / maxi(1, a.windup[i]), 0, 1000)
	var base := {"elite": a.kinds[i], "attack": a.pick[i], "progress": progress}
	if a.pick[i] == Attack.BASIC:
		if e.basic_pattern != null:
			base.merge({"shape": &"cast", "ground": false, "look": e.basic_pattern.look})
		else:
			base.merge({"shape": &"lane", "ground": false, "obb": punch_lane(w, i)})
		return base
	match a.kinds[i]:
		ActorStore.Kind.BREAKER:
			base.merge(
				{
					"shape": &"disc",
					"ground": true,
					"center": Vector2(a.lock_x[i], a.lock_y[i]),
					"radius": e.radius_m
				}
			)
		ActorStore.Kind.RIFT_HUNTER:
			(
				base
				. merge(
					{
						"shape": &"disc",
						"ground": true,
						"center": Vector2(a.lock_x[i], a.lock_y[i]),
						"radius": e.radius_m,
						"tracked": true,
						"locked": st >= e.track_ticks,
						"vanished": vanished(w, i),
					}
				)
			)
		ActorStore.Kind.CONDUIT:
			(
				base
				. merge(
					{
						"shape": &"lane",
						"ground": true,
						"obb": beam_lane(w, i),
						"tracked": true,
						"locked": st >= e.track_ticks,
					}
				)
			)
	return base


## The Conduit's beam firing now (its ACTIVE tick and the recovery's first BEAM_SHOW_TICKS, for the views), or null.
static func beam_now(w: World, i: int) -> Obb:
	var a := w.actors
	if a.kinds[i] != ActorStore.Kind.CONDUIT or a.pick[i] != Attack.ABILITY:
		return null
	var firing := a.state[i] == EnemyAi.State.ACTIVE
	firing = firing or (a.state[i] == EnemyAi.State.RECOVER and a.state_t[i] < BEAM_SHOW_TICKS)
	return beam_lane(w, i) if firing else null


## The death recap's line for an elite's kill (World.killer_kind an elite kind), else &"".
static func cause_key(w: World) -> StringName:
	var keys: Array = CAUSE_KEYS.get(w.killer_kind, [])
	if keys.is_empty():
		return &""
	var k := w.killer_attack
	if w.killer_kind == ActorStore.Kind.CONDUIT and w.killer_tags & SimEvent.TAG_PROJECTILE:
		k = CAUSE_BASIC
	return keys[clampi(k, 0, keys.size() - 1)] if k >= 0 else keys[CAUSE_ABILITY]
