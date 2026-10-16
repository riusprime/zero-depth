extends GutTest
## v0.7.5 BF1 (owner N15, "Track, then lock 0.8 s" and "Shielded during big patterns"; BOSS_FIGHTS.md): ground
## markers follow the player's exact position while they charge, lock for 0.8 s, then strike where they locked; the
## signature pattern shields the boss; and the Gatekeeper's and the Warlord's phase scripts.

const S := EnemyAi.State
const LONG := 1 << 20


func _fight(id: StringName, player_at: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


func _atk(w: World, aid: int) -> BossAttackTable:
	return BossAi.attack_of(w, w.actors.index_of(aid))


func test_a_fist_slam_follows_you_then_locks_then_strikes_where_it_locked() -> void:
	var s := _fight(&"gatekeeper", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"fist_slam")
	var atk := _atk(w, aid)
	assert_eq(atk.lock_ticks, 48, "0.8 s")
	var track := atk.windup_ticks - atk.lock_ticks
	var at := Vector2(6, 0)
	var locked_at := Vector2.INF
	for t in atk.windup_ticks:
		var i := w.actors.index_of(aid)
		var tg := BossAi.telegraph(w, i)
		var mark := BossDodge.mark_of(w, i, 0)
		if t < track:
			assert_eq(mark, at, "tick %d: on the player's exact position" % t)
			assert_false(tg["items"][0]["locked"], "a dull outline while it tracks")
		else:
			if locked_at == Vector2.INF:
				locked_at = mark
			assert_eq(mark, locked_at, "tick %d: locked" % t)
			assert_true(tg["items"][0]["locked"], "the lock flash")
		at = Vector2(6, 0) + Vector2(0, 0.05) * t  # the player keeps walking, slowly
		w.actors.set_pos(0, at)
		w.step(InputFrame.new())
	assert_true(locked_at != Vector2.INF)


func test_moving_after_the_lock_escapes_and_standing_still_is_hit() -> void:
	for stay: bool in [true, false]:
		var s := _fight(&"gatekeeper", Vector2(6, 0))
		var w: World = s[0]
		var aid: int = s[1]
		BossLab.start(w, w.actors.index_of(aid), &"fist_slam")
		var atk := _atk(w, aid)
		var hit := false
		for t in atk.windup_ticks + 2:
			var i := w.actors.index_of(aid)
			if (
				not stay
				and w.actors.state[i] == S.WINDUP
				and t >= atk.windup_ticks - atk.lock_ticks
			):
				w.actors.set_pos(0, w.player_pos() + Vector2(0, 0.12))  # 7.2 m/s, after the lock only
			w.step(InputFrame.new())
			hit = hit or CombatLab.player_damage(w).size() > 0
		assert_eq(hit, stay, "stays: hit" if stay else "moved after the lock: missed")


func test_the_strike_is_the_drawn_circle() -> void:
	var s := _fight(&"gatekeeper", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"fist_slam")
	var atk := _atk(w, aid)
	CombatLab.idle(w, atk.windup_ticks - 2)
	var tg := BossAi.telegraph(w, w.actors.index_of(aid))
	var c: Vector2 = tg["items"][0]["center"]
	var r: float = tg["items"][0]["radius"]
	w.actors.set_pos(0, c + Vector2(r + w.player.radius_m + 0.05, 0))  # just outside the drawn edge
	CombatLab.idle(w, 4)
	assert_eq(CombatLab.player_damage(w), [], "outside the circle: safe")


func test_the_second_and_third_circles_track_in_turn() -> void:
	var s := _fight(&"gatekeeper", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"fist_slam_3")
	var atk := _atk(w, aid)
	assert_eq(atk.count, 3)
	var strikes := []
	var seq := w.last_event_seq()
	for t in atk.windup_ticks + atk.active_ticks + 2:
		w.actors.set_pos(0, Vector2(6, 0) + Vector2(0, 0.06) * t)  # walking through all of them
		w.step(InputFrame.new())
		for e in w.events_since(seq):
			seq = e.seq
	for k in 3:
		strikes.append(BossDodge.mark_of(w, w.actors.index_of(aid), k))
	assert_ne(strikes[0], strikes[1], "each circle locked where you were in its turn")
	assert_ne(strikes[1], strikes[2])
	assert_gt(strikes[2].y, strikes[1].y, "the later one locked later")


func test_shock_lanes_take_your_row_and_column() -> void:
	var s := _fight(&"gatekeeper", Vector2(5, 3))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"shock_lanes")
	var tg := BossAi.telegraph(w, w.actors.index_of(aid))
	var lanes: Array = tg["items"][0]["obbs"]
	assert_eq(lanes.size(), 2, "a row and a column")
	var row: Obb = lanes[0]
	var col: Obb = lanes[1]
	assert_eq(row.center.y, 3.0, "the row through you")
	assert_eq(col.center.x, 5.0, "the column through you")
	assert_true(tg["tracked"])
	assert_false(tg["locked"])
	var atk := _atk(w, aid)
	CombatLab.idle(w, atk.windup_ticks - atk.lock_ticks + 1)
	assert_true(BossAi.telegraph(w, w.actors.index_of(aid))["locked"], "then it locks")


func test_the_warlords_lunge_and_spears_lock_on_your_exact_position() -> void:
	for attack_id: StringName in [&"lunge_dash", &"spear_lines"]:
		var s := _fight(&"warlord", Vector2(8, 0))
		var w: World = s[0]
		var aid: int = s[1]
		BossLab.start(w, w.actors.index_of(aid), attack_id)
		var atk := _atk(w, aid)
		assert_eq(atk.lock_ticks, 48, "%s: locks 0.8 s" % attack_id)
		var aims := []
		for t in atk.windup_ticks - 1:
			w.actors.set_pos(0, Vector2(8, 0) + Vector2(0, 0.08) * t)
			w.step(InputFrame.new())
			var i := w.actors.index_of(aid)
			aims.append(w.actors.lock_a[i])
			var tg := BossAi.telegraph(w, i)
			assert_eq(tg["locked"], w.actors.state_t[i] >= atk.windup_ticks - atk.lock_ticks)
		var track := atk.windup_ticks - atk.lock_ticks
		assert_ne(aims[0], aims[track - 3], "%s follows you" % attack_id)
		for t in range(track, aims.size()):
			assert_eq(aims[t], aims[track], "%s: locked for its last 0.8 s" % attack_id)
		# Exact, not led: the aim at the lock points at where the player stood.
		var i := w.actors.index_of(aid)
		var at := Vector2(8, 0) + Vector2(0, 0.08) * (track - 2)  # the last position it read
		assert_almost_eq(
			aims[track], Kin.angle_of(at - w.actors.pos(i)), 3, "%s aims exact" % attack_id
		)


func test_the_signature_pattern_shields_the_boss_and_it_opens_between_patterns() -> void:
	for spec in [[&"gatekeeper", &"rock_rings"], [&"warlord", &"shield_wall"]]:
		var s := _fight(spec[0], Vector2(0, 4))
		var w: World = s[0]
		var aid: int = s[1]
		var i := w.actors.index_of(aid)
		var hp := w.actors.hp[i]
		BossLab.start(w, i, spec[1])
		var reader := WorldReader.new(w)
		assert_true(reader.boss_shielded(i), "%s: shielded as it winds up" % spec[0])
		assert_eq(reader.boss_pattern(i)["shielded"], true)
		var seq := w.last_event_seq()
		assert_eq(Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 0)
		var hits := w.events_since(seq).filter(
			func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.HIT and e.target_id == aid
		)
		assert_eq(hits.size(), 1, "the hit still shows")
		assert_ne(hits[0].tags & SimEvent.TAG_BLOCKED, 0, "it sparks off the shell")
		assert_eq(Damage.tick_dot(w, i, 50, 1, 1, &"burn"), 0, "damage over time too")
		CombatLab.idle(w, 60)
		i = w.actors.index_of(aid)
		assert_eq(w.actors.state[i], S.ACTIVE, "firing")
		assert_true(BossDodge.shielded(w, i), "shielded while it fires")
		assert_eq(Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 0)
		assert_eq(w.actors.hp[i], hp, "no damage while shielded")
		CombatLab.until(
			w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
		)
		i = w.actors.index_of(aid)
		assert_false(BossDodge.shielded(w, i), "open between patterns")
		assert_gt(w.bosses.exposed_t[BossAi.entry_of(w, i)], 0, "and its weak point with it")
		assert_gt(Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 0)
		assert_lt(w.actors.hp[i], hp)


func test_the_dev_panels_kill_passes_the_shield() -> void:
	var s := _fight(&"gatekeeper", Vector2(0, 4))
	var w: World = s[0]
	var i := w.actors.index_of(s[1])
	BossLab.start(w, i, &"rock_rings")
	Damage.hit(w, i, 999999, 0, 0, 1, 0, w.actors.pos(i), w.actors.pos(i))
	assert_eq(w.actors.dead[i], 1, "the world's own hit (owner 0)")


func test_the_patterns_fire_fireballs_of_the_bosss_look() -> void:
	# v0.8.0 BP (owner O27): the Warlord's javelins come and go faster (6.5 m/s, under the 7 m/s slow-shot cap).
	for spec in [
		[&"gatekeeper", &"rock_rings", "ember_stone", 3.0, 5.0],
		[&"warlord", &"javelin_fan", "spear_ember", 6.0, 7.0]
	]:
		var s := _fight(spec[0], Vector2(9, 0))
		var w: World = s[0]
		var aid: int = s[1]
		BossLab.start(w, w.actors.index_of(aid), spec[1])
		CombatLab.until(
			w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
		)
		var reader := WorldReader.new(w)
		assert_gt(reader.projectile_count(), 6, "%s: many shots" % spec[1])
		for k in reader.projectile_count():
			assert_eq(reader.projectile_look(k), spec[2])
			var v := reader.projectile_vel(k).length() * SimTick.TICKS_PER_SECOND
			assert_between(v, spec[3], spec[4], "%s: %.1f-%.1f m/s" % [spec[1], spec[3], spec[4]])


func test_the_gatekeepers_phase_script() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"gatekeeper")]
	var ids := func(k: int) -> Array:
		return Array(t.phase_attacks[k]).map(func(a: int) -> StringName: return t.attacks[a].id)
	# v0.8.0 BS1 (owner O5, S1): Cross Quake trimmed (the Siege Engine owns the cross); the shock lanes' pillars
	# are its signature now, and phase 3 opens with two of their crosses.
	assert_eq(ids.call(0), [&"rock_rings", &"fist_slam", &"shock_lanes", &"sweep"])
	assert_eq(ids.call(1), [&"rock_rings_4", &"fist_slam_2", &"shock_lanes", &"sweep"])
	assert_eq(ids.call(2), [&"rock_rings_4", &"fist_slam_3", &"shock_lanes_2", &"sweep"])
	assert_eq(t.attacks[t.phase_entry[1]].id, &"rock_rings_4", "phase 2 opens with four rings")
	assert_eq(t.attacks[t.phase_entry[2]].id, &"shock_lanes_2", "phase 3 with two pillar crosses")
	var rings := t.attacks[t.attack_index(&"rock_rings")].pattern
	var rings_4 := t.attacks[t.attack_index(&"rock_rings_4")].pattern
	assert_eq([rings.count, rings.waves], [16, 3], "3 rings of 16")
	assert_gt(rings_4.waves, rings.waves, "phases add rings")
	assert_gt(rings_4.speed, rings.speed, "and speed them up")
	assert_eq(t.attack_index(&"cross_quake"), -1, "no cross quake")


func test_the_warlords_phase_script() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"warlord")]
	var ids := func(k: int) -> Array:
		return Array(t.phase_attacks[k]).map(func(a: int) -> StringName: return t.attacks[a].id)
	assert_true(ids.call(0).has(&"shield_wall") and ids.call(0).has(&"javelin_fan"))
	assert_true(ids.call(0).has(&"spear_lines") and ids.call(0).has(&"lunge_dash"))
	assert_true(ids.call(1).has(&"spear_wall"), "phase 2: five spear lines")
	assert_true(ids.call(2).has(&"shield_wall_cross"), "phase 3: two walls crossing")
	assert_true(ids.call(2).has(&"javelin_fan_fast"))
	assert_eq(t.attacks[t.phase_entry[2]].id, &"shield_wall_cross")
	var fan := t.attacks[t.attack_index(&"javelin_fan")].pattern
	assert_eq([fan.count, fan.waves], [7, 3], "3 waves of 7")
	assert_true(fan.alternate, "offset each wave")
	assert_true(t.attacks[t.attack_index(&"shield_wall_cross")].pattern.crossing)
	assert_false(t.attacks[t.attack_index(&"shield_wall")].pattern.crossing)
