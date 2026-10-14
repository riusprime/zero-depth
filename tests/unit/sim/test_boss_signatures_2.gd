# gdlint: disable=max-public-methods
extends GutTest
## v0.8.0 BS2 (owner O5; docs/roadmap/v0.8.0/BOSS_SIGNATURES.md S4-S6, approved 2026-10-14): each boss's signature
## mechanic, part 2. S4 the Hive Lens's Gaze: a beam that starts aimed away from you (and keeps away through its
## windup), turns a quarter turn every few seconds and reverses, stops at walls, hurts what it touches, while its orbs
## fly. S5 the Siege Engine's ricochet shells: its Turret Cross's embers bounce off a wall once (reflected on the
## wall's normal), never back onto you within 0.5 s; phase 3's turrets ricochet too. S6 the Foundry's lava: Molten
## Flood lanes stay molten for 5 s (burning, avoided by the flow field, never closing every way to the boss and an
## exit), and the phase-3 meltdown melts the outer ring for good, closer step by step down to a minimum radius.
## Determinism, a mid-fight snapshot round trip, and the death lines.

const S := EnemyAi.State
const LONG := 1 << 20
## The independent way check's cell (m) for the lava's fairness test.
const CELL := 0.2
## A hostile shot from here at this velocity (m per tick) bounces off the +x wall of a half-10 room at (9.78, 0.5).
const RICOCHET_FROM := Vector2(4.98, 3.7)
const RICOCHET_V := Vector2(0.12, -0.08)


## A boss at boss_at past its rise, the player at player_at; `room` > 0: a square room of that half size round the
## origin (walls, the arena set as a sealed boss room's).
func _fight(id: StringName, player_at: Vector2, boss_at := Vector2.ZERO, room := 0.0) -> Array:
	var w := BossLab.world()
	if room > 0.0:
		_room(w, room)
	var i := BossLab.ready_boss(w, id, boss_at)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


## Four walls round a square of half size `half` at the origin; the boss arena is its interior.
func _room(w: World, half: float) -> void:
	var t := 0.5
	var walls: Array[Obb] = [
		Obb.make(Vector2(half + t, 0), Vector2(t, half + 2.0 * t), 0),
		Obb.make(Vector2(-half - t, 0), Vector2(t, half + 2.0 * t), 0),
		Obb.make(Vector2(0, half + t), Vector2(half + 2.0 * t, t), 0),
		Obb.make(Vector2(0, -half - t), Vector2(half + 2.0 * t, t), 0),
	]
	w.set_walls(walls)
	w.bosses.arena = Rect2(-half, -half, half * 2.0, half * 2.0)


## Boss `aid` picks no attack on its own (no phase list, no punish, no gap-closer, no closing band): only the attacks
## a test starts.
func _hush(w: World, aid: int) -> void:
	var t := BossAi.table_of(w, _i(w, aid))
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.close_step_m = 0.0


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _atk(w: World, aid: int) -> BossAttackTable:
	return BossAi.attack_of(w, _i(w, aid))


## Steps until boss `aid` turns active (at most `limit` ticks).
func _until_active(w: World, aid: int, limit: int = 400) -> void:
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] == S.ACTIVE, limit)


## A real floor whose boss is `id` (the boss room sealed, the boss past its rise): [world, boss actor id], or [].
func _floor_fight(id: StringName, floor_index: int) -> Array:
	for run_seed in range(1, 80):
		var w := SaveLab.floor_world(run_seed, floor_index)
		w.actors.hp[0] = LONG
		w.actors.max_hp[0] = LONG
		for t in 120:  # a later floor opens with its arrival: the door seals once it is over
			if w.boss_id >= 0:
				break
			FightLab.enter_boss_room(w)
			w.step(InputFrame.new())
		CombatLab.idle(w, 2)
		if w.boss_id < 0:
			continue
		var i := w.actors.index_of(w.boss_id)
		if BossAi.table_of(w, i).id != id:
			continue
		w.actors.state[i] = S.MOVE
		w.actors.state_t[i] = 0
		w.actors.invuln[i] = 0
		return [w, w.boss_id]
	return []


## Snapshot `w`, restore into `base` (built the same way), and step both with the same input.
func _round_trip(w: World, base: World, label: String, ticks: int = 360) -> void:
	var snap := WorldSnapshot.take(w)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, "%s: restores (%s)" % [label, WorldSnapshot.apply(base, snap)])
	if restored == null:
		return
	assert_eq(restored.state_hash(), w.state_hash(), "%s: same hash restored" % label)
	assert_eq(restored.nav.extra, w.nav.extra, "%s: the field goes round the same floor" % label)
	for k in ticks:
		var f := (
			InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
		)
		w.step(f)
		restored.step(f)
	assert_eq(restored.state_hash(), w.state_hash(), "%s: same hash %d ticks on" % [label, ticks])


# --- S4: the Hive Lens's Gaze -------------------------------------------------------------------------------------


func test_the_gaze_starts_aimed_away_and_keeps_away_through_its_windup() -> void:
	var s := _fight(&"hive_lens", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, _i(w, aid), &"gaze")
	var atk := _atk(w, aid)
	assert_eq(atk.move, BossAttackTable.Move.GAZE)
	assert_eq(atk.windup_ticks, 48, "0.8 s of brightening eye and aim line (a starting value)")
	var tg := BossAi.telegraph(w, _i(w, aid))
	assert_false(tg.get("ground", true), "nothing on the ground: the eye and its aim line")
	var at := Vector2(6, 0)
	for t in atk.windup_ticks:
		at = Vector2(6, 0) + Vector2(-0.08 * t, 0.11 * t)  # running round it
		w.actors.set_pos(0, at)
		w.step(InputFrame.new())
		var i := _i(w, aid)
		var to_player := Kin.angle_of(w.player_pos() - w.actors.pos(i))
		if w.actors.state[i] == S.WINDUP:
			assert_eq(
				Kin.angle_diff(w.actors.lock_a[i], to_player), 2048, "tick %d: straight away" % t
			)
	var i := _i(w, aid)
	assert_eq(w.actors.state[i], S.ACTIVE)
	assert_eq(
		Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, BossGaze.beam(w, i, 0)),
		Vector2.ZERO,
		"it never starts on you"
	)
	assert_eq(CombatLab.player_damage(w), [], "no hit as it opens")


func test_the_beam_turns_a_quarter_every_quarter_and_reverses() -> void:
	var s := _fight(&"hive_lens", Vector2(-6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	w.actors.invuln[0] = LONG
	BossLab.start(w, _i(w, aid), &"gaze")
	var atk := _atk(w, aid)
	_until_active(w, aid)
	var i := _i(w, aid)
	var a0 := w.actors.lock_a[i]
	assert_eq(a0, 0, "the player at -x: it starts along +x")
	var way := w.bosses.span[BossAi.entry_of(w, i)]
	assert_true(way == 1 or way == -1)
	assert_eq(atk.quarter_ticks, 120, "a quarter turn every 2.0 s (a starting value)")
	assert_eq(atk.reverse_ticks, 480, "reversing every 8.0 s: one whole turn each way")
	var q := atk.quarter_ticks
	assert_eq(BossGaze.angle_at(w, i, 0), a0)
	assert_eq(BossGaze.angle_at(w, i, q), (a0 + way * 1024) & 4095, "a quarter turn")
	assert_eq(BossGaze.angle_at(w, i, 2 * q), (a0 + way * 2048) & 4095, "a half turn")
	assert_eq(BossGaze.angle_at(w, i, atk.reverse_ticks - q), (a0 - way * 1024) & 4095)
	assert_eq(
		BossGaze.angle_at(w, i, atk.reverse_ticks + q),
		BossGaze.angle_at(w, i, atk.reverse_ticks - q),
		"then back the way it came"
	)
	# The sim turns it tick by tick: never more than a step a tick, and the eye looks along it.
	var last := BossGaze.angle_at(w, i, 0)
	for t in 200:
		w.step(InputFrame.new())
		i = _i(w, aid)
		if w.actors.state[i] != S.ACTIVE:
			break
		var now := BossGaze.angle_at(w, i, w.actors.state_t[i])
		assert_lte(Kin.angle_diff(now, last), 1024 / q + 1, "slow, smooth turn")
		last = now
	assert_eq(w.actors.state[i], S.ACTIVE, "12 s long: still gazing")


func test_the_beam_hurts_what_it_touches_once_per_burn() -> void:
	var s := _fight(&"hive_lens", Vector2(-6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, _i(w, aid), &"gaze")
	var atk := _atk(w, aid)
	_until_active(w, aid)
	var i := _i(w, aid)
	# Stand where the beam will be a quarter turn on, and stay there.
	var ang := BossGaze.angle_at(w, i, atk.quarter_ticks)
	w.actors.set_pos(0, w.actors.pos(i) + Kin.dir(ang) * 5.0)
	var before := CombatLab.player_damage(w).size()
	CombatLab.idle(w, atk.quarter_ticks - 24)
	assert_eq(CombatLab.player_damage(w).size(), before, "not yet: the beam is still coming")
	CombatLab.idle(w, 48)
	var hits := CombatLab.player_damage(w).size() - before
	assert_gt(hits, 0, "the beam burns you as it passes")
	assert_lte(hits, 48 / atk.burn_ticks + 1, "at most once per burn")
	assert_eq(BossAi.cause_key(w), &"", "alive")
	w.actors.hp[0] = 1
	w.actors.max_hp[0] = 100
	for t in 90:  # keep on the beam until it lands
		i = _i(w, aid)
		var on := BossGaze.angle_at(w, i, w.actors.state_t[i] + 1)
		w.actors.set_pos(0, w.actors.pos(i) + Kin.dir(on) * 4.0)
		w.actors.invuln[0] = 0
		w.step(InputFrame.new())
		if w.player_dead():
			break
	assert_true(w.player_dead())
	assert_eq(BossAi.cause_key(w), &"CAUSE_HIVE_GAZE", "the death names the gaze")


func test_a_wall_stops_the_beam() -> void:
	var s := _fight(&"hive_lens", Vector2(-6, 0), Vector2.ZERO, 12.0)
	var w: World = s[0]
	var aid: int = s[1]
	var wall := Obb.make(Vector2(5.0, 0.0), Vector2(0.4, 3.0), 0)
	w.add_barrier(wall)
	BossLab.start(w, _i(w, aid), &"gaze")
	_until_active(w, aid)
	var i := _i(w, aid)
	var o := BossGaze.beam(w, i, 0)
	var end := o.center + o.axis_u * o.half.x
	assert_almost_eq(end.x, 4.6 - _atk(w, aid).half_width_m, 0.05, "it stops on the wall's face")
	assert_true(BossGaze.state(w, i)["hit"], "and the view knows it struck a wall")
	w.actors.set_pos(0, Vector2(7.0, 0.0))  # behind the wall, on the beam's line
	var before := CombatLab.player_damage(w).size()
	CombatLab.idle(w, 6)
	assert_eq(CombatLab.player_damage(w).size(), before, "the wall shields you")


func test_its_orbs_fly_while_it_turns_and_name_their_death_line() -> void:
	var s := _fight(&"hive_lens", Vector2(-9, 0))
	var w: World = s[0]
	var aid: int = s[1]
	w.actors.invuln[0] = LONG
	BossLab.start(w, _i(w, aid), &"gaze")
	var atk := _atk(w, aid)
	assert_not_null(atk.pattern, "the orbs: the Petal Bloom's")
	assert_eq(atk.orb_every_ticks, 180)
	_until_active(w, aid)
	CombatLab.idle(w, atk.orb_every_ticks - 2)
	assert_eq(w.projectiles.size(), 0, "the beam turns alone first")
	CombatLab.idle(w, 6)
	assert_gt(w.projectiles.size(), 6, "then the orbs fly")
	for k in w.projectiles.size():
		var c := w.projectiles.cause_of(k)
		assert_eq(c, BossSignatures.LATE_CAUSE + w.bosses.attack[0], "the orbs' own line")
	var t := BossAi.table_of(w, _i(w, aid))
	assert_eq(
		BossSignatures.late_cause_key(t, BossSignatures.LATE_CAUSE + t.attack_index(&"gaze")),
		&"CAUSE_HIVE_GAZE_ORBS"
	)


func test_the_gaze_is_deterministic_and_survives_a_save() -> void:
	var make := func() -> World:
		var s := _fight(&"hive_lens", Vector2(-6, 2), Vector2.ZERO, 12.0)
		var w: World = s[0]
		BossLab.start(w, _i(w, s[1]), &"gaze")
		return w
	var a: World = make.call()
	var b: World = make.call()
	for k in 300:
		a.step(InputFrame.new())
		b.step(InputFrame.new())
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree mid-gaze")
	_round_trip(a, make.call(), "gaze")


# --- S5: the Siege Engine's ricochet shells -----------------------------------------------------------------------


## A hostile shot of boss `aid` from `from` at velocity `v` (m per tick), bouncing `bounces` times, cause `cause`.
func _shot(w: World, aid: int, from: Vector2, v: Vector2, bounces: int, cause: int = 0) -> void:
	w.queue_projectile(
		aid, ActorStore.TEAM_ENEMY, from, v, 5, 0.22, 600, SimEvent.TAG_PROJECTILE, bounces
	)
	w.set_pending_cause(cause)


func test_a_shell_bounces_off_a_wall_once_reflected_on_its_normal() -> void:
	var s := _fight(&"siege_engine", Vector2(0, 8), Vector2(0, -8), 10.0)
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	w.actors.invuln[0] = LONG
	_shot(w, aid, Vector2(0, 0), Vector2(0.1, 0.05), 1)
	w.step(InputFrame.new())
	var vin := Vector2(w.projectiles.vel_x[0], w.projectiles.vel_y[0])
	CombatLab.until(w, func(x: World) -> bool: return x.projectiles.bounce_tick[0] >= 0, 200)
	assert_eq(w.projectiles.size(), 1, "it bounced instead of breaking")
	var vout := Vector2(w.projectiles.vel_x[0], w.projectiles.vel_y[0])
	assert_eq(vout, Vector2(-vin.x, vin.y), "reflected exactly on the wall's normal (+x face)")
	assert_eq(w.projectiles.bounces[0], 0, "once")
	assert_eq(
		w.projectiles.cause_of(0), BossSignatures.LATE_CAUSE, "now a ricochet (its late part)"
	)
	CombatLab.until(w, func(x: World) -> bool: return x.projectiles.size() == 0, 400)
	assert_eq(w.projectiles.size(), 0, "the next wall breaks it: it bounces once only")


## Where a shot from RICOCHET_FROM at RICOCHET_V, bouncing off the +x wall of a half-10 room at (9.78, 0.5), passes
## `d` metres in from the wall on its way back.
func _on_the_way_back(d: float) -> Vector2:
	return Vector2(10.0 - d, 0.5 - (0.08 / 0.12) * (d - 0.22))


func test_a_ricochet_never_comes_back_onto_you_within_half_a_second() -> void:
	# You stand on its way back 1 m from the wall (inside 0.5 s at 8.7 m/s: it breaks) or 6 m (outside: it bounces).
	for spec: Array in [[1.0, false], [6.0, true]]:
		var s := _fight(&"siege_engine", Vector2(0, 0), Vector2(0, -8), 10.0)
		var w: World = s[0]
		var aid: int = s[1]
		_hush(w, aid)
		w.actors.invuln[0] = LONG
		w.actors.set_pos(0, _on_the_way_back(spec[0]))
		_shot(w, aid, RICOCHET_FROM, RICOCHET_V, 1)
		w.step(InputFrame.new())
		var bounced := false
		for t in 120:
			w.step(InputFrame.new())
			if w.projectiles.size() > 0 and w.projectiles.bounce_tick[0] >= 0:
				bounced = true
				break
			if w.projectiles.size() == 0:
				break
		assert_eq(
			bounced,
			spec[1],
			"%s m from the wall: %s" % [spec[0], "bounces" if spec[1] else "breaks"]
		)


func test_the_turret_cross_fires_shells_that_bounce_and_come_back() -> void:
	var s := _fight(&"siege_engine", Vector2(0, 7), Vector2.ZERO, 9.0)
	var w: World = s[0]
	var aid: int = s[1]
	w.actors.invuln[0] = LONG
	BossLab.start(w, _i(w, aid), &"turret_cross")
	_until_active(w, aid)
	CombatLab.idle(w, 3)
	assert_gt(w.projectiles.size(), 0)
	for k in w.projectiles.size():
		assert_eq(w.projectiles.bounces[k], 1, "every ember bounces once")
	var back := 0
	for t in 300:
		w.step(InputFrame.new())
		for k in w.projectiles.size():
			if w.projectiles.bounce_tick[k] == w.tick - 1:
				back += 1
	assert_gt(back, 8, "the cross comes back off the walls")


func test_phase_three_turrets_ricochet_and_name_it() -> void:
	for phase in [1, 2]:
		var s := _fight(&"siege_engine", Vector2(0, 6), Vector2(0, -8), 10.0)
		var w: World = s[0]
		var aid: int = s[1]
		_hush(w, aid)
		w.bosses.phase[BossAi.entry_of(w, _i(w, aid))] = phase
		w.queue_enemy(ActorStore.Kind.NEEDLE, Vector2(4, 0))
		w.step(InputFrame.new())
		var bounce := -1
		for t in 600:
			w.step(InputFrame.new())
			for k in w.projectiles.size():
				if w.projectiles.owner[k] != aid:
					bounce = w.projectiles.bounces[k]
			if bounce >= 0:
				break
		assert_eq(
			bounce,
			1 if phase == 2 else 0,
			"phase index %d: turret shots bounce %s" % [phase, phase == 2]
		)
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"siege_engine")]
	assert_eq(t.attacks[t.attack_index(&"deploy")].bounce_phase, 2, "from phase 3 (index 2)")
	w.killer_kind = ActorStore.Kind.NEEDLE
	w.killer_attack = BossSignatures.LATE_CAUSE + t.attack_index(&"deploy")
	BossLab.ready_boss(w, &"siege_engine")
	assert_eq(
		BossAi.cause_key(w), &"CAUSE_SIEGE_TURRET_RICOCHET", "a turret's ricochet names itself"
	)
	w.killer_kind = ActorStore.Kind.SIEGE_ENGINE
	w.killer_attack = BossSignatures.LATE_CAUSE + t.attack_index(&"turret_cross")
	assert_eq(BossAi.cause_key(w), &"CAUSE_SIEGE_RICOCHET", "a shell's ricochet")


func test_a_bounced_shell_kills_with_its_ricochet_line() -> void:
	var s := _fight(&"siege_engine", _on_the_way_back(6.0), Vector2(0, -8), 10.0)
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	w.actors.hp[0] = 1
	w.actors.max_hp[0] = 100
	var cross := BossAi.table_of(w, _i(w, aid)).attack_index(&"turret_cross")
	_shot(w, aid, RICOCHET_FROM, RICOCHET_V, 1, cross)  # off the +x wall, back at you
	CombatLab.until(w, func(x: World) -> bool: return x.player_dead(), 300)
	assert_true(w.player_dead(), "hit from behind by the ricochet")
	assert_eq(BossAi.cause_key(w), &"CAUSE_SIEGE_RICOCHET")


func test_ricochets_are_deterministic_and_survive_a_save() -> void:
	var make := func() -> World:
		var s := _fight(&"siege_engine", Vector2(0, 6), Vector2.ZERO, 9.0)
		var w: World = s[0]
		w.actors.invuln[0] = LONG
		BossLab.start(w, _i(w, s[1]), &"turret_cross")
		return w
	var a: World = make.call()
	var b: World = make.call()
	for k in 240:
		a.step(InputFrame.new())
		b.step(InputFrame.new())
	var bounced := 0
	for k in a.projectiles.size():
		bounced += 1 if a.projectiles.bounce_tick[k] >= 0 else 0
	assert_gt(bounced, 0, "some have bounced")
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree with ricochets in the air")
	_round_trip(a, make.call(), "ricochets", 240)


# --- S6: the Foundry's lava and meltdown --------------------------------------------------------------------------


## Runs boss `aid`'s attack `attack_id` (locked on the player where they stand) to the tick its lava is down.
func _flood(w: World, aid: int, attack_id: StringName) -> void:
	_hush(w, aid)
	w.actors.state[_i(w, aid)] = S.MOVE
	BossLab.start(w, _i(w, aid), attack_id)
	# Until it has stood its time (a hit-stop on the player can hold the clock a few ticks).
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] != S.WINDUP, 400)
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] != S.ACTIVE, 400)


func test_the_molten_flood_leaves_lava_where_it_struck_for_five_seconds() -> void:
	var s := _fight(&"foundry", Vector2(2, 3), Vector2(-4, -6), 11.0)
	var w: World = s[0]
	var aid: int = s[1]
	w.actors.invuln[0] = LONG
	BossLab.start(w, _i(w, aid), &"molten_flood")
	var atk := _atk(w, aid)
	assert_eq(atk.lava_ticks, 300, "5.0 s (a starting value)")
	CombatLab.idle(w, atk.windup_ticks + 2)
	var lanes: Array[Obb] = []
	for k in atk.count:
		lanes.append(BossDodge.row_flood_of(w, _i(w, aid), k))
	assert_eq(w.bosses.lava_x.size(), 0, "nothing molten while the flood stands")
	CombatLab.idle(w, atk.active_ticks)
	var bs := w.bosses
	assert_gt(bs.lava_x.size(), atk.count, "every lane stays molten, cut by its fords")
	for k in bs.lava_x.size():
		var r := BossLava.lava_rect(bs, k)
		var inside := false
		for o in lanes:
			if o.bounds().grow(0.01).encloses(r):
				inside = true
		assert_true(inside, "piece %d lies where a lane struck" % k)
		assert_eq(bs.lava_until[k] - bs.lava_from[k], 300)
		var boss_x := w.actors.pos(_i(w, aid)).x
		assert_false(
			r.position.x < boss_x and r.end.x > boss_x, "a ford at the boss's x (piece %d)" % k
		)
	CombatLab.idle(w, 290)
	assert_gt(bs.lava_x.size(), 0, "still molten at 4.9 s")
	CombatLab.idle(w, 15)
	assert_eq(bs.lava_x.size(), 0, "cooled by 5.2 s")
	assert_true(w.nav.extra.is_empty(), "and the field is open again")


func test_lava_burns_a_player_standing_in_it() -> void:
	var s := _fight(&"foundry", Vector2(2, 3), Vector2(-4, -6), 11.0)
	var w: World = s[0]
	var aid: int = s[1]
	w.actors.invuln[0] = LONG
	_flood(w, aid, &"molten_flood")
	var bs := w.bosses
	assert_gt(bs.lava_x.size(), 0)
	var r := BossLava.lava_rect(bs, 0)
	w.actors.set_pos(0, r.get_center())
	w.actors.invuln[0] = 0
	var before := CombatLab.player_damage(w).size()
	CombatLab.idle(w, 61)
	var got := CombatLab.player_damage(w).slice(before)
	assert_between(got.size(), 1, 3, "at most once every 0.5 s (the hurt iframes allowing)")
	assert_gt(got.size(), 0, "it burns")
	var atk := BossAi.table_of(w, _i(w, aid)).attacks[bs.lava_attack[0]]
	for d: int in got:
		assert_eq(d, BossAi.powered(w, _i(w, aid), atk.lava_damage), "lava_damage each burn")
	# Off the lava (in a band between the lanes): nothing.
	w.actors.set_pos(0, Vector2(r.get_center().x, r.position.y - 0.6))
	CombatLab.idle(w, 31)
	before = CombatLab.player_damage(w).size()
	CombatLab.idle(w, 60)
	assert_eq(CombatLab.player_damage(w).size(), before, "the cool floor doesn't burn")
	w.actors.set_pos(0, r.get_center())
	w.actors.hp[0] = 1
	w.actors.max_hp[0] = 100
	w.actors.invuln[0] = 0
	CombatLab.until(w, func(x: World) -> bool: return x.player_dead(), 60)
	assert_true(w.player_dead())
	assert_eq(BossAi.cause_key(w), &"CAUSE_FOUNDRY_LAVA", "the death names the lava")


func test_enemies_path_round_the_lava() -> void:
	var s := _fight(&"foundry", Vector2(2, 3), Vector2(-4, -6), 11.0)
	var w: World = s[0]
	var aid: int = s[1]
	w.actors.invuln[0] = LONG
	_flood(w, aid, &"molten_flood")
	var bs := w.bosses
	assert_gt(bs.lava_x.size(), 0)
	assert_false(w.nav.extra.is_empty(), "the field has extra cells")
	for k in bs.lava_x.size():
		if BossLava.lava_rect(bs, k).grow(1.0).has_point(w.player_pos()):
			continue  # the flood starts on the player's own cell
		var c := w.nav.cell_of(BossLava.lava_rect(bs, k).get_center())
		assert_eq(
			w.nav.extra[c.y * w.nav.size.x + c.x], 1, "piece %d is off the enemies' paths" % k
		)
		assert_eq(w.nav.dist[c.y * w.nav.size.x + c.x], NavField.UNREACHED, "not flooded through")


func test_lava_always_leaves_a_way_to_the_boss_and_an_exit() -> void:
	var f := _floor_fight(&"foundry", 3)
	if f.is_empty():
		fail_test("no run seed in 1..79 has the Foundry on floor 3")
		return
	var w: World = f[0]
	var aid: int = f[1]
	var room := w.bosses.arena
	var ex := BossLava.exits(w)
	assert_eq(ex.size(), 1, "the boss room's door is its exit")
	var laid := 0
	for spot: Vector2 in [
		Vector2(0.5, 0.5), Vector2(0.2, 0.3), Vector2(0.8, 0.7), Vector2(0.5, 0.85)
	]:
		w.actors.set_pos(0, room.position + room.size * spot)
		for attack_id: StringName in [&"molten_flood", &"molten_flood_5"]:
			_flood(w, aid, attack_id)
			laid += w.bosses.lava_x.size()
			assert_true(
				_way(w, aid, w.player_pos()), "%s at %s: a way to the boss" % [attack_id, spot]
			)
			assert_true(_way(w, aid, ex[0]), "%s at %s: a way to the exit" % [attack_id, spot])
			CombatLab.idle(w, 301)
	assert_gt(laid, 0, "lava was laid")


## An independent check (not the sim's): a CELL grid flood from the boss's edge over the floor the hero fits on
## without touching molten floor reaches `to`.
func _way(w: World, aid: int, to: Vector2) -> bool:
	var i := _i(w, aid)
	var pr := w.player.radius_m
	var lava := BossLava.rects(w)
	var free := func(p: Vector2) -> bool:
		if not EnemyAi.clear_of_walls(w, p, pr - 0.04):
			return false
		for r: Rect2 in lava:
			if r.grow(pr - 0.04).has_point(p):
				return false
		return true
	var origin := w.actors.pos(i)
	var seen := {}
	var queue: Array[Vector2i] = []
	var reach := w.actors.radius[i] + 1.0
	for y in range(-12, 13):
		for x in range(-12, 13):
			var c := Vector2i(x, y)
			var p := origin + Vector2(c) * CELL
			if Kin.length(p - origin) <= reach and free.call(p):
				seen[c] = true
				queue.append(c)
	var goal := 1.6 + pr
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		var p := origin + Vector2(c) * CELL
		if Kin.length(p - to) <= goal:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc := c + d
			if seen.has(nc) or absi(nc.x) > 200 or absi(nc.y) > 200:
				continue
			if not free.call(origin + Vector2(nc) * CELL):
				continue
			seen[nc] = true
			queue.append(nc)
	return false


func test_lava_that_would_close_every_way_is_not_laid() -> void:
	var s := _fight(&"foundry", Vector2(6, 6), Vector2(-4, -6), 11.0)
	var w: World = s[0]
	var aid: int = s[1]
	var wall_to_wall: Array[Rect2] = [Rect2(-11, 0, 22, 1.6)]  # a whole row: the boss cut off from you
	assert_false(BossLava.fair(w, _i(w, aid), wall_to_wall), "it would cut you off: refused")
	var gap: Array[Rect2] = [Rect2(-11, 0, 10, 1.6), Rect2(1, 0, 10, 1.6)]
	assert_true(BossLava.fair(w, _i(w, aid), gap), "a ford in it: fine")


func test_the_meltdown_melts_the_outer_ring_for_good_and_shrinks_to_its_minimum() -> void:
	var s := _fight(&"foundry", Vector2(1, 1), Vector2(-2, 0), 16.0)
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	w.actors.invuln[0] = LONG
	BossLab.start(w, _i(w, aid), &"meltdown")
	var atk := _atk(w, aid)
	assert_eq(atk.move, BossAttackTable.Move.MELT)
	assert_eq(atk.windup_ticks, 120, "a 2 s roar while the ring glows")
	CombatLab.idle(w, 10)
	var reader := WorldReader.new(w)
	var glow: Array = reader.boss_melts()
	assert_eq(glow.size(), 1, "the ring glows first")
	assert_eq(glow[0]["radius"], INF, "nothing molten yet")
	assert_gt(int(glow[0]["warn"]), 0)
	assert_true(w.bosses.melt_boss.is_empty())
	_until_active(w, aid)
	w.step(InputFrame.new())
	assert_eq(w.bosses.melt_boss.size(), 1, "melted on its strike")
	var radii := []
	for step in 6:
		radii.append(reader.boss_melts()[0]["radius"])
		CombatLab.idle(w, atk.melt_step_ticks)
	assert_eq(atk.melt_ring_m, 4.0, "the outer 4 m first (a starting value)")
	assert_eq(radii, [12.0, 10.0, 8.0, 7.0, 7.0, 7.0], "2 m closer every 8 s, never under 7 m")
	# The Foundry keeps to the cool ground; the player outside the ring burns, inside doesn't.
	var c := Vector2.ZERO
	assert_lte(Kin.length(w.actors.pos(_i(w, aid)) - c), 7.0, "the Foundry stays on cool ground")
	w.actors.invuln[0] = 0
	w.actors.set_pos(0, Vector2(0, -10.0))
	var before := CombatLab.player_damage(w).size()
	CombatLab.idle(w, 31)
	assert_gt(CombatLab.player_damage(w).size(), before, "the melted ring burns")
	w.actors.set_pos(0, Vector2(0, 4.0))
	CombatLab.idle(w, 31)
	before = CombatLab.player_damage(w).size()
	CombatLab.idle(w, 60)
	assert_eq(CombatLab.player_damage(w).size(), before, "the middle stays cool")
	var cell := w.nav.cell_of(Vector2(0, -11.0))
	assert_eq(w.nav.extra[cell.y * w.nav.size.x + cell.x], 1, "enemies keep off the melted ring")
	w.actors.set_pos(0, Vector2(0, -10.0))
	w.actors.hp[0] = 1
	w.actors.max_hp[0] = 100
	w.actors.invuln[0] = 0
	CombatLab.until(w, func(x: World) -> bool: return x.player_dead(), 60)
	assert_true(w.player_dead())
	assert_eq(BossAi.cause_key(w), &"CAUSE_FOUNDRY_MELT", "the death names the melt")


func test_phase_three_opens_with_the_meltdown_and_a_bridge_to_the_exit_stays_cool() -> void:
	var f := _floor_fight(&"foundry", 3)
	if f.is_empty():
		fail_test("no run seed in 1..79 has the Foundry on floor 3")
		return
	var w: World = f[0]
	var aid: int = f[1]
	w.actors.invuln[0] = LONG
	var i := _i(w, aid)
	w.actors.hp[i] = w.actors.max_hp[i] * 300 / 1000  # past the 33 % gate
	w.bosses.phase[BossAi.entry_of(w, i)] = 1
	CombatLab.until(w, func(x: World) -> bool: return not x.bosses.melt_boss.is_empty(), 900)
	assert_eq(w.bosses.melt_boss.size(), 1, "phase 3's entry melts the ring")
	var m: Array = BossLava.melt_shapes(w)[0]
	assert_true(m[BossLava.MELT_HAS_EXIT], "a bridge to the door")
	var ex := BossLava.exits(w)[0]
	var c: Vector2 = m[BossLava.MELT_CENTRE]
	assert_eq(c, w.bosses.arena.get_center(), "round the room's centre")
	for k in 11:
		var p := c + (ex - c) * (k / 10.0)
		assert_false(BossLava.melt_covers(m, p, 0.0), "the bridge is cool at %s" % p)
	assert_true(_way_melt(w, m, c, ex), "a way from the middle to the exit")


## Walks the straight bridge in CELL steps, checking each spot is off the melt with the hero's radius to spare.
func _way_melt(w: World, m: Array, from: Vector2, to: Vector2) -> bool:
	var n := int(Kin.length(to - from) / CELL) + 1
	for k in n + 1:
		var p := from + (to - from) * (float(k) / n)
		if BossLava.melt_covers(m, p, w.player.radius_m):
			return false
	return true


func test_lava_and_the_melt_are_deterministic_and_survive_a_save() -> void:
	var make := func() -> World:
		var s := _fight(&"foundry", Vector2(2, 3), Vector2(-4, -6), 11.0)
		var w: World = s[0]
		var aid: int = s[1]
		_hush(w, aid)
		BossLab.start(w, _i(w, aid), &"meltdown")
		CombatLab.idle(w, 200)
		_flood(w, aid, &"molten_flood")
		return w
	var a: World = make.call()
	var b: World = make.call()
	assert_gt(a.bosses.lava_x.size(), 0, "lava down")
	assert_eq(a.bosses.melt_boss.size(), 1, "and the ring melted")
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	_round_trip(a, make.call(), "lava")


func test_an_older_save_mid_fight_has_no_molten_floor_and_plays_on() -> void:
	var s := _fight(&"foundry", Vector2(2, 3), Vector2(-4, -6), 11.0)
	var w: World = s[0]
	CombatLab.idle(w, 30)
	var snap := WorldSnapshot.take(w)
	var bosses: Dictionary = snap["world"][&"bosses"]
	for f: StringName in WorldSnapshot.ADDED_SINCE_V05[&"BossStore"]:
		bosses.erase(f)
	var base := _fight(&"foundry", Vector2(2, 3), Vector2(-4, -6), 11.0)[0] as World
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save from before BS2 restores")
	assert_eq(base.state_hash(), w.state_hash(), "the same fight")
	assert_eq(base.bosses.lava_x.size(), 0)
	_flood(base, base.boss_id, &"molten_flood")
	assert_gt(base.bosses.lava_x.size(), 0, "and its next flood leaves lava")


func test_the_trimmed_moves_are_gone() -> void:
	var w := BossLab.world()
	for spec: Array in [
		[&"hive_lens", &"glare_ring"],
		[&"hive_lens", &"glare_ring_fast"],
		[&"siege_engine", &"turret_cross_reversing"],
		[&"foundry", &"furnace_waves_fast"],
	]:
		var t := w.boss_tables[BossLab.table_index(w, spec[0])]
		assert_eq(t.attack_index(spec[1]), -1, "%s: %s trimmed" % spec)
