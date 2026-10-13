extends GutTest
## v0.7.5 BF2 (owner N15, BOSS_FIGHTS.md; "Track, then lock 0.8 s", "Shielded during big patterns"): the Brood Mother
## and the Hive Lens fight dodge-first. The Egg Storm's eggs land on circles that track you then lock, each bursting
## into an 8-point star of acid globs with you in a gap; the Web Spiral's 2 arms turn back; the Leap and the Burrow's
## eruption track your exact position then lock; the Prism Spiral's 3 arms reverse halfway with the eye shielded;
## the Petal Bloom's 5 petals, the Glare Ring's 2 gaps; the Focus Beam tracks then locks; both phase scripts and HP.

const S := EnemyAi.State
const LONG := 1 << 20


func _fight(id: StringName, player_at: Vector2, seed_value: int = 11) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _ids(t: BossTable, k: int) -> Array:
	return Array(t.phase_attacks[k]).map(func(a: int) -> StringName: return t.attacks[a].id)


func _pattern(t: BossTable, id: StringName) -> BulletPatternTable:
	return t.attacks[t.attack_index(id)].pattern


## The new shots of this tick (ids not in `seen`), and `seen` updated.
func _new_shots(w: World, seen: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var reader := WorldReader.new(w)
	for k in reader.projectile_count():
		var id := reader.projectile_id(k)
		if not seen.has(id):
			seen[id] = true
			out.append(reader.projectile_pos(k))
	return out


## The gaps (1/4096 turns) between neighbouring shot directions of one wave, widest first.
func _gaps(p: BulletPatternTable, k: int) -> Array:
	var shots := BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, 1.3)
	var a := []
	for v: Vector2 in shots[1]:
		a.append(Kin.angle_of(v) & 4095)
	a.sort()
	var out := []
	for j in a.size():
		var nxt: int = a[(j + 1) % a.size()] + (4096 if j == a.size() - 1 else 0)
		out.append(nxt - int(a[j]))
	out.sort()
	out.reverse()
	return out


func _angle_diff(a: int, b: int) -> int:
	var d := (a - b) & 4095
	return mini(d, 4096 - d)


# --- the Brood Mother ----------------------------------------------------------------------------------------


func test_the_brood_mothers_phase_script_and_hp() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"brood_mother")]
	assert_eq(t.hp, 2000, "1600 in v0.7.0, x1.25")
	assert_eq(_ids(t, 0), [&"egg_storm", &"web_spiral", &"leap", &"burrow", &"brood"])
	assert_eq(_ids(t, 1), [&"egg_storm_5", &"web_spiral", &"leap_chain", &"burrow", &"brood_4"])
	assert_eq(
		_ids(t, 2),
		[
			&"egg_storm_5",
			&"web_spiral_fast",
			&"leap_chain",
			&"burrow_2",
			&"brood_4",
			&"pounce_chain"
		]
	)
	assert_eq(t.attacks[t.phase_entry[1]].id, &"egg_storm_5", "phase 2 opens with five eggs")
	assert_eq(t.attacks[t.phase_entry[2]].id, &"web_spiral_fast", "phase 3 with the fast web")
	assert_eq(Array(t.phase_threshold), [1000, 660, 330], "the 66 % and 33 % gates stay")
	var eggs := t.attacks[t.attack_index(&"egg_storm")]
	var eggs_5 := t.attacks[t.attack_index(&"egg_storm_5")]
	assert_true(eggs.shielded and eggs_5.shielded, "the Egg Storm is the shielded signature")
	assert_eq([eggs.count, eggs.pattern.count], [3, 8], "3 eggs, each an 8-point star")
	assert_gt(eggs_5.count, eggs.count, "phases add eggs")
	assert_gt(eggs_5.pattern.waves, eggs.pattern.waves, "and a second star")
	var web := _pattern(t, &"web_spiral")
	assert_eq(web.arms, 2, "2 arms")
	assert_gt(web.reverse_ticks, 0, "then reversed")
	var fast := _pattern(t, &"web_spiral_fast")
	assert_gt(absi(fast.spin_milli), absi(web.spin_milli), "phase 3 turns faster")
	assert_gt(fast.speed, web.speed)
	for id: StringName in [&"egg_storm", &"leap", &"leap_chain", &"pounce_chain", &"burrow"]:
		assert_eq(t.attacks[t.attack_index(id)].lock_ticks, 48, "%s: tracks, then locks 0.8 s" % id)
	assert_true(_ids(t, 0).has(&"brood"), "the Hatchlings stay")
	assert_eq(t.attacks[t.gap_attack].id, &"leap")
	assert_eq(t.attacks[t.punish_attack].id, &"pounce_chain")


func test_an_egg_storms_circles_track_you_then_lock_in_turn() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, _i(w, aid), &"egg_storm")
	var atk := BossAi.attack_of(w, _i(w, aid))
	var locked: Array = [Vector2.INF, Vector2.INF, Vector2.INF]
	for t in atk.windup_ticks + atk.active_ticks:
		var at := Vector2(6, 0) + Vector2(0, 0.05) * t  # walking, 3 m/s
		w.actors.set_pos(0, at)
		w.step(InputFrame.new())
		var i := _i(w, aid)
		if w.actors.state[i] != S.WINDUP and w.actors.state[i] != S.ACTIVE:
			break
		var tt := BossDodge.attack_ticks(w, i, atk)
		var lobs := 0
		var in_air := 0
		for k in 3:
			var st := BossDodge.mark_state(atk, k, tt)
			var c := BossDodge.mark_of(w, i, k)
			if st == 0:
				assert_eq(c, at, "egg %d: on your exact position while it tracks" % k)
			elif st == 1:
				in_air += 1
				if locked[k] == Vector2.INF:
					locked[k] = c
				assert_eq(c, locked[k], "egg %d: locked" % k)
		var tg := BossAi.telegraph(w, i)
		for item: Dictionary in tg.get("items", []):
			lobs += 1 if item.has("lob") else 0
		assert_eq(lobs, in_air, "each locked circle's egg is in the air")
	assert_ne(locked[0], Vector2.INF)
	assert_ne(locked[0], locked[1], "each circle locked where you were in its turn")
	assert_gt(locked[2].y, locked[1].y, "the later one later")


func test_each_egg_bursts_into_an_8_point_star_with_you_in_a_gap() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, _i(w, aid), &"egg_storm")
	var atk := BossAi.attack_of(w, _i(w, aid))
	CombatLab.idle(w, atk.windup_ticks - 1)
	var c := BossDodge.mark_of(w, _i(w, aid), 0)
	var stand := c + Vector2(0, 5)  # out of the circle once it locked, beside it
	w.actors.set_pos(0, stand)
	var seen := {}
	_new_shots(w, seen)
	var hp := w.actors.hp[0]
	w.step(InputFrame.new())  # the first egg lands and bursts
	var star := _new_shots(w, seen)
	assert_eq(star.size(), 8, "an 8-point star")
	assert_eq(w.actors.hp[0], hp, "out of its circle: the landing missed")
	var to_player := Kin.angle_of(stand - c)
	for p: Vector2 in star:
		assert_almost_eq(p.distance_to(c), BossDodge.egg_r(atk), 0.15, "from the egg's circle")
		assert_gte(
			_angle_diff(Kin.angle_of(p - c), to_player), 200, "no glob flies straight at you"
		)
	var reader := WorldReader.new(w)
	for k in reader.projectile_count():
		assert_eq(reader.projectile_look(k), "acid_glob", "sickly green acid globs")
		var v := reader.projectile_vel(k).length() * SimTick.TICKS_PER_SECOND
		assert_between(v, 3.0, 5.0, "slow")


func test_no_glob_spawns_on_you_and_standing_in_the_circle_is_hit() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, _i(w, aid), &"egg_storm")
	var atk := BossAi.attack_of(w, _i(w, aid))
	var seen := {}
	CombatLab.idle(w, atk.windup_ticks - 1)
	var c := BossDodge.mark_of(w, _i(w, aid), 0)
	w.actors.set_pos(0, c + Vector2(1.2, 0))  # still inside the locked circle, off its centre
	_new_shots(w, seen)
	w.step(InputFrame.new())
	var star := _new_shots(w, seen)
	var safe := atk.pattern.safe_radius_m + w.player.radius_m
	for p: Vector2 in star:
		assert_gt(p.distance_to(w.player_pos()), safe, "no shot spawns on top of you")
	assert_lt(star.size(), 8, "the globs that would spawn on you are left out")
	assert_gt(star.size(), 0, "the rest of the star flies")
	assert_gt(CombatLab.player_damage(w).size(), 0, "still in the circle: the egg landed on you")


func test_the_egg_storm_shields_her_and_she_opens_after() -> void:
	var s := _fight(&"brood_mother", Vector2(0, 5))
	var w: World = s[0]
	var aid: int = s[1]
	var i := _i(w, aid)
	var hp := w.actors.hp[i]
	BossLab.start(w, i, &"egg_storm_5")
	var reader := WorldReader.new(w)
	assert_true(reader.boss_shielded(i), "shielded as the eggs are thrown")
	CombatLab.idle(w, 100)
	i = _i(w, aid)
	assert_eq(w.actors.state[i], S.ACTIVE)
	assert_true(BossDodge.shielded(w, i), "and while they burst")
	assert_eq(Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 0)
	assert_eq(w.actors.hp[i], hp, "hits spark off")
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] == S.RECOVER)
	i = _i(w, aid)
	assert_false(BossDodge.shielded(w, i), "open between patterns")
	assert_gt(Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 0)


func test_an_egg_storm_is_deterministic() -> void:
	var hashes := []
	for run in 2:
		var s := _fight(&"brood_mother", Vector2(6, 1), 93)
		var w: World = s[0]
		BossLab.start(w, _i(w, s[1]), &"egg_storm_5")
		for t in 400:
			w.step(InputFrame.make(Vector2i(0, 60 if (t / 50) % 2 == 0 else -60), 0, 500, 0, 0))
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_the_web_spiral_turns_back() -> void:
	var w := BossLab.world()
	var p := _pattern(w.boss_tables[BossLab.table_index(w, &"brood_mother")], &"web_spiral")
	var r := p.reverse_ticks
	assert_gt(BulletPatterns.spin_at(p, r), BulletPatterns.spin_at(p, r - 30), "turning one way")
	assert_lt(BulletPatterns.spin_at(p, r + 30), BulletPatterns.spin_at(p, r), "then reversed")
	for k in p.waves:
		assert_eq((BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, 1.3)[0] as Array).size(), 2)
		assert_gte(_gaps(p, k)[1], 2000, "two arms: half the room free each side")


func test_the_leap_tracks_your_exact_position_then_locks() -> void:
	var s := _fight(&"brood_mother", Vector2(8, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, _i(w, aid), &"leap")
	var atk := BossAi.attack_of(w, _i(w, aid))
	var track := atk.windup_ticks - atk.lock_ticks
	var held := Vector2.INF
	for t in atk.windup_ticks - 1:
		var at := Vector2(8, 0) + Vector2(0, 0.06) * t
		w.actors.set_pos(0, at)
		w.step(InputFrame.new())
		var i := _i(w, aid)
		var tg := BossAi.telegraph(w, i)
		var c: Vector2 = tg["center"]
		if w.actors.state_t[i] < track:
			assert_eq(c, at, "tick %d: on you (exact, no lead)" % t)
			assert_false(tg["locked"])
		else:
			if held == Vector2.INF:
				held = c
			assert_eq(c, held, "tick %d: locked" % t)
			assert_true(tg["locked"], "the lock flash")
	assert_ne(held, Vector2.INF)


func test_the_burrows_eruption_tracks_you_locks_and_erupts_in_a_ring() -> void:
	for stay: bool in [true, false]:
		var s := _fight(&"brood_mother", Vector2(7, 0))
		var w: World = s[0]
		var aid: int = s[1]
		BossLab.start(w, _i(w, aid), &"burrow")
		var atk := BossAi.attack_of(w, _i(w, aid))
		CombatLab.idle(w, atk.windup_ticks + 1)
		var at := Vector2(7, 0)
		var locked_at := Vector2.INF
		var seen := {}
		var ring: Array[Vector2] = []
		var erupt_at := Vector2.INF
		for t in atk.track_ticks + atk.erupt_ticks + 4:
			var i := _i(w, aid)
			var tg := BossAi.telegraph(w, i)
			if not tg.is_empty() and tg["shape"] == &"disc":
				assert_true(tg["tracked"])
				if not tg["locked"]:
					assert_eq(tg["center"], at, "the eruption circle is on you")
					at += Vector2(0, 0.04)  # keep walking while it tracks
				else:
					if locked_at == Vector2.INF:
						locked_at = tg["center"]
					assert_eq(tg["center"], locked_at, "locked where it will erupt")
					if not stay:
						at = locked_at + Vector2(0, atk.radius_m + 1.2)  # stepped out after the lock
			w.actors.set_pos(0, at)
			w.step(InputFrame.new())
			var shots := _new_shots(w, seen)
			if not shots.is_empty() and erupt_at == Vector2.INF:
				ring = shots
				erupt_at = locked_at
		assert_ne(locked_at, Vector2.INF, "it locked")
		var hit := CombatLab.player_damage(w).size() > 0
		assert_eq(hit, stay, "stayed: hit" if stay else "moved after the lock: missed")
		if not stay:
			assert_gt(ring.size(), 6, "a ring of globs bursts out of the eruption")
			var to_player := Kin.angle_of(at - erupt_at)
			for p: Vector2 in ring:
				assert_gte(
					_angle_diff(Kin.angle_of(p - erupt_at), to_player), 300, "you're in its gap"
				)


# --- the Hive Lens -------------------------------------------------------------------------------------------


func test_the_hive_lens_phase_script_and_hp() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"hive_lens")]
	assert_eq(t.hp, 2063, "1650 in v0.7.0, x1.25 (2062.5 rounded up)")
	var p0 := _ids(t, 0)
	for id: StringName in [&"prism_spiral", &"petal_bloom", &"glare_ring", &"focus_beam"]:
		assert_true(p0.has(id), "phase 1 has %s" % id)
	assert_eq(t.attacks[t.phase_entry[1]].id, &"split", "the Lens Drones still break off at 66 %")
	assert_true(_ids(t, 1).has(&"glare_ring_fast"), "phase 2 speeds the rings")
	var p2 := _ids(t, 2)
	for id: StringName in [
		&"prism_spiral_fast", &"petal_bloom_fast", &"glare_ring_fast", &"focus_beam_3"
	]:
		assert_true(p2.has(id), "phase 3, the hardest mix, has %s" % id)
	assert_eq(t.attacks[t.phase_entry[2]].id, &"prism_spiral_fast")
	assert_eq(Array(t.phase_threshold), [1000, 660, 330])
	assert_true(t.attacks[t.attack_index(&"prism_spiral")].shielded, "the eye closes: shielded")
	assert_true(t.attacks[t.attack_index(&"prism_spiral_fast")].shielded)
	for id: StringName in [&"focus_beam", &"focus_beam_3", &"dive"]:
		assert_eq(t.attacks[t.attack_index(id)].lock_ticks, 48, "%s locks 0.8 s" % id)
	assert_eq(t.attacks[t.punish_attack].id, &"focus_beam")
	assert_eq(t.attacks[t.gap_attack].id, &"dive")


func test_the_prism_spiral_has_3_arms_that_reverse_halfway() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"hive_lens")]
	for id: StringName in [&"prism_spiral", &"prism_spiral_fast"]:
		var p := _pattern(t, id)
		assert_eq(p.arms, 3, "%s: 3 arms" % id)
		var whole := p.wave_gap_ticks * (p.waves - 1)
		assert_almost_eq(float(p.reverse_ticks), whole * 0.5, whole * 0.06, "%s: halfway" % id)
		var r := p.reverse_ticks
		var before := BulletPatterns.spin_at(p, r) - BulletPatterns.spin_at(p, r - 20)
		var after := BulletPatterns.spin_at(p, r + 20) - BulletPatterns.spin_at(p, r)
		assert_true(signi(before) == -signi(after) and before != 0, "%s reverses" % id)
		for k in p.waves:
			assert_gte(_gaps(p, k)[2], 1300, "three arms: a third of the room between")
	assert_gt(_pattern(t, &"prism_spiral_fast").speed, _pattern(t, &"prism_spiral").speed)


func test_the_eye_is_closed_shielded_through_the_prism_spiral() -> void:
	var s := _fight(&"hive_lens", Vector2(0, 6))
	var w: World = s[0]
	var aid: int = s[1]
	var i := _i(w, aid)
	BossLab.start(w, i, &"prism_spiral")
	var reader := WorldReader.new(w)
	assert_true(reader.boss_shielded(i))
	assert_eq(reader.boss_pattern(i)["id"], &"hive_prism_spiral")
	var hp := w.actors.hp[i]
	CombatLab.idle(w, 90)
	i = _i(w, aid)
	assert_true(reader.boss_shielded(i), "shielded while the spiral turns")
	assert_eq(Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 0)
	assert_eq(w.actors.hp[i], hp)
	assert_gt(reader.projectile_count(), 10, "prism orbs in flight")
	for k in reader.projectile_count():
		assert_eq(reader.projectile_look(k), "prism_orb", "magenta-red prism orbs")
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] == S.RECOVER)
	assert_false(reader.boss_shielded(_i(w, aid)), "the eye opens after")


func test_the_petal_bloom_opens_5_petals_with_gaps_between() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"hive_lens")]
	for id: StringName in [&"petal_bloom", &"petal_bloom_fast"]:
		var p := _pattern(t, id)
		assert_eq(p.petals, 5)
		var g := _gaps(p, 0)
		var wide := g.filter(func(x: int) -> bool: return x >= 300)
		assert_eq(wide.size(), 5, "%s: five gaps, one between each two petals" % id)
		var shots := BulletPatterns.wave_shots(p, 0, Vector2.ZERO, 0, 1.3)
		var speeds := {}
		for v: Vector2 in shots[1]:
			speeds[snappedf(v.length(), 0.001)] = true
		assert_gt(speeds.size(), 2, "%s: the petals open out (tips faster than the sides)" % id)


func test_the_glare_ring_has_two_gaps() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"hive_lens")]
	for id: StringName in [&"glare_ring", &"glare_ring_fast"]:
		var p := _pattern(t, id)
		assert_eq(p.gap_count, 2)
		for k in p.waves:
			var g := _gaps(p, k)
			var step := 4096 / p.count
			assert_gt(g[1], step, "%s wave %d: two gaps" % [id, k])
			assert_lte(g[2], step + 1, "and only two")


func test_the_focus_beam_tracks_then_locks_and_a_step_aside_escapes() -> void:
	for stay: bool in [true, false]:
		var s := _fight(&"hive_lens", Vector2(9, 0))
		var w: World = s[0]
		var aid: int = s[1]
		BossLab.start(w, _i(w, aid), &"focus_beam")
		var atk := BossAi.attack_of(w, _i(w, aid))
		var track := atk.windup_ticks - atk.lock_ticks
		var aims := []
		var at := Vector2(9, 0)
		for t in atk.windup_ticks + atk.active_ticks + 2:
			var i := _i(w, aid)
			if w.actors.state[i] == S.WINDUP and w.actors.state_t[i] < track:
				at = Vector2(9, 0) + Vector2(0, 0.05) * t
			elif not stay and w.actors.state[i] == S.WINDUP:
				at += Vector2(0, 0.06)  # a sidestep after the lock
			w.actors.set_pos(0, at)
			w.step(InputFrame.new())
			i = _i(w, aid)
			if w.actors.state[i] == S.WINDUP:
				aims.append(w.actors.lock_a[i])
				var tg := BossAi.telegraph(w, i)
				assert_true(tg["tracked"])
				assert_eq(tg["locked"], w.actors.state_t[i] >= track)
		assert_ne(aims[0], aims[track - 3], "the line follows you")
		for k in range(track, aims.size()):
			assert_eq(aims[k], aims[track], "then holds")
		var hit := CombatLab.player_damage(w).size() > 0
		assert_eq(hit, stay, "stood still: hit" if stay else "stepped aside after the lock: missed")


func test_both_bosses_patterns_fire_slow_shots_in_their_looks() -> void:
	for spec in [
		[&"brood_mother", &"web_spiral", "acid_glob"],
		[&"hive_lens", &"petal_bloom", "prism_orb"],
		[&"hive_lens", &"glare_ring", "prism_orb"],
	]:
		var s := _fight(spec[0], Vector2(9, 0))
		var w: World = s[0]
		var aid: int = s[1]
		BossLab.start(w, _i(w, aid), spec[1])
		CombatLab.until(w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] == S.RECOVER)
		var reader := WorldReader.new(w)
		assert_gt(reader.projectile_count(), 6, "%s: many shots" % spec[1])
		for k in reader.projectile_count():
			assert_eq(reader.projectile_look(k), spec[2])
			var v := reader.projectile_vel(k).length() * SimTick.TICKS_PER_SECOND
			assert_between(v, 1.5, 5.0, "%s: slow" % spec[1])
