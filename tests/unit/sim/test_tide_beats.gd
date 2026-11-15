extends GutTest
## The Tidecaller's fight rhythm (BossTideBeats): one big mechanic at a time (the Pull, a row of Riptide, a High
## Tide) in each phase's order, with calm between; nothing else starts while one runs; the push sets the hero down
## clear of the rings; a Riptide warning lasts the walk to its safe strip; the strips cover the whole floor of the
## real boss room (and of the Playground's room); determinism and a save. TideLab's walled 24 m room unless named.

const S := EnemyAi.State
const B := preload("res://src/sim/ai/boss_tide_beats.gd")
## The long fights: 3 minutes a phase.
const MINUTES := 3


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## The Tidecaller in phase `phase` whose only attack is its Pull (so the rhythm alone decides when anything starts),
## no punish, no gap-closer and no stream unless `streams`.
func _rhythm(phase: int, streams := false, seed_value := 11) -> Array:
	var s := TideLab.fight(Vector2(-6, 0), Vector2(6, 0), seed_value)
	var w: World = s[0]
	var t := TideLab.table(w, s[1])
	var pull := t.attack_index(&"the_pull")
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array([pull])
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.streams = streams
	TideLab.set_phase(w, s[1], phase)
	return s


## The big mechanic running now (B.NONE, PULL, RIPTIDE, HIGH_TIDE), and how many run (never more than one).
func _running(w: World, i: int) -> Array:
	var on: Array[int] = []
	if B.pulling(w, i):
		on.append(B.PULL)
	if w.bosses.dance_rip_from >= 0:
		on.append(B.RIPTIDE)
	if w.bosses.dance_ht_from >= 0:
		on.append(B.HIGH_TIDE)
	return [on[0] if not on.is_empty() else B.NONE, on.size()]


## Steps `ticks` with the hero idle and refilled, the boss kept in its phase. Returns [kind, start, end] of each big
## mechanic (the tick it began and the first tick it no longer ran; -1 when it still runs), the first tick seen,
## the ticks a ring left, a wave formed, or another attack began, and the most that ran at once.
func _play(w: World, aid: int, ticks: int) -> Dictionary:
	var beats: Array = []
	var rings := PackedInt32Array()
	var waves := PackedInt32Array()
	var attacks := PackedInt32Array()
	var most := 0
	var was := B.NONE
	var hp := w.actors.hp[_i(w, aid)]
	var first := w.tick
	for k in ticks:
		var i := _i(w, aid)
		var rn := w.bosses.str_ring_n[0] if not w.bosses.str_ring_n.is_empty() else 0
		w.step(InputFrame.new())
		var now := w.tick - 1
		i = _i(w, aid)
		w.actors.hp[i] = hp
		TideLab.take_lost(w)
		var r := _running(w, i)
		most = maxi(most, r[1])
		if r[0] != was:
			if was != B.NONE:
				beats.back()[2] = now
			if r[0] != B.NONE:
				beats.append([r[0], now, -1])
			was = r[0]
		if not w.bosses.str_ring_n.is_empty() and w.bosses.str_ring_n[0] > rn:
			rings.append(now)
		if w.bosses.wv_from.has(now):
			waves.append(now)
		var atk := BossAi.attack_of(w, i)
		if (
			w.actors.state[i] == S.WINDUP
			and w.actors.state_t[i] == 0
			and atk.move != BossAttackTable.Move.TIDE
		):
			attacks.append(now)
	return {
		"beats": beats,
		"first": first,
		"rings": rings,
		"waves": waves,
		"attacks": attacks,
		"most": most
	}


# --- the order and the spacing, tick-exact ---------------------------------------------------------------------


func test_phase_1_is_pull_after_pull_with_calm_and_12_s_between() -> void:
	var s := _rhythm(0)
	var w: World = s[0]
	var d := TideLab.dance(w, s[1])
	var got := _play(w, s[1], 60 * 70)
	var beats: Array = got["beats"]
	assert_gte(beats.size(), 3, "three Pulls in 70 s")
	assert_eq(beats[0][1], int(got["first"]) + 360, "the first 6 s into the fight")
	for k in beats.size():
		assert_eq(beats[k][0], B.PULL, "only Pulls in phase 1")
		if beats[k][2] >= 0:
			assert_eq(beats[k][2] - beats[k][1], 270, "the bell, the pull and the push: 4.5 s")
		if k > 0:
			assert_eq(
				beats[k][1] - beats[k - 1][2], d.calm_ticks + 720, "3 s of calm and 12 s after"
			)


func test_phase_2_opens_with_its_riptide_then_alternates_with_the_pull() -> void:
	var s := _rhythm(1)
	var w: World = s[0]
	var got := _play(w, s[1], 60 * 90)
	var beats: Array = got["beats"]
	assert_gte(beats.size(), 4)
	assert_eq(beats[0][1], int(got["first"]) + 360, "the first beat 6 s into the phase")
	for k in beats.size():
		assert_eq(beats[k][0], B.RIPTIDE if k % 2 == 0 else B.PULL, "Riptide, Pull, Riptide, ...")
		if k > 0:
			assert_eq(beats[k][1] - beats[k - 1][2], 180 + 480, "3 s of calm and 8 s after")


func test_phase_3_is_high_tide_then_riptide_and_never_a_pull() -> void:
	var s := _rhythm(2)
	var w: World = s[0]
	var got := _play(w, s[1], 60 * 100)
	var beats: Array = got["beats"]
	assert_gte(beats.size(), 4)
	assert_eq(beats[0][1], int(got["first"]) + 480, "the first beat 8 s into the phase")
	for k in beats.size():
		assert_eq(beats[k][0], B.HIGH_TIDE if k % 2 == 0 else B.RIPTIDE, "High Tide, Riptide, ...")
		if k > 0:
			assert_eq(beats[k][1] - beats[k - 1][2], 180 + 600, "3 s of calm and 10 s after")
	var t := TideLab.table(w, s[1])
	assert_eq(t.phase_wave_n[2], 0, "no crossing waves in the Maelstrom")
	assert_eq(t.phase_ring_atk[2], t.attack_index(&"ring_stream"), "and the plain ring stream")


func test_the_first_beat_of_a_phase_comes_after_its_gate() -> void:
	var s := TideLab.fight(Vector2(-6, 0), Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := _i(w, aid)
	w.actors.hp[i] = w.actors.max_hp[i] * 650 / 1000
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] == BossAi.GATE, 600
	)
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] != BossAi.GATE, 600
	)
	var stood := w.tick - 1
	assert_eq(w.bosses.dance_beat_phase, 1, "phase 2's order")
	assert_eq(w.bosses.dance_beat_at, stood + 360, "its first beat 6 s after the gate")
	var reader: Dictionary = WorldReader.new(w).boss_dance()["beats"]
	assert_eq(reader["next"], B.RIPTIDE, "the Riptide it brings")
	assert_eq(reader["order"], PackedInt32Array([B.RIPTIDE, B.PULL]))


# --- the hold, over a long real fight per phase ----------------------------------------------------------------


func test_three_minutes_a_phase_one_at_a_time_and_nothing_else_meanwhile() -> void:
	for phase in 3:
		var s := TideLab.fight(Vector2(-6, 0), Vector2(6, 0), 21 + phase)
		var w: World = s[0]
		var d := TideLab.dance(w, s[1])
		TideLab.set_phase(w, s[1], phase)
		var got := _play(w, s[1], 60 * 60 * MINUTES)
		var beats: Array = got["beats"]
		assert_eq(got["most"], 1, "phase %d: never two big mechanics at once" % (phase + 1))
		assert_gt(beats.size(), 3, "phase %d: its beats came" % (phase + 1))
		# From the tick each was due to 1.5 s after it ended: no ring, no wave, no other attack begins.
		var due := int(got["first"]) + d.first_ticks(phase)
		var held := 0
		for k in beats.size():
			var b: Array = beats[k]
			assert_gte(b[1], due, "phase %d beat %d: not before it was due" % [phase + 1, k])
			if k > 0:
				assert_gte(b[1] - beats[k - 1][2], d.calm_ticks, "the calm holds")
			var until: int = (b[2] if b[2] >= 0 else w.tick) + d.resume_ticks
			for key: String in ["rings", "waves", "attacks"]:
				for at in got[key] as PackedInt32Array:
					if at >= due and at < until:
						held += 1
						fail_test(
							"phase %d: a %s at %d, held %d..%d" % [phase + 1, key, at, due, until]
						)
			if b[2] >= 0:
				due = b[2] + d.calm_ticks + d.gap_ticks(phase)
		assert_eq(held, 0, "phase %d: the stream, the waves and the attacks wait" % (phase + 1))
		assert_gt((got["rings"] as PackedInt32Array).size(), 0, "the stream runs between beats")
		assert_gt((got["attacks"] as PackedInt32Array).size(), 0, "and so do its attacks")
		if phase < 2:
			assert_gt((got["waves"] as PackedInt32Array).size(), 0, "and its crossing waves")
		else:
			assert_eq((got["waves"] as PackedInt32Array).size(), 0, "none in the Maelstrom")
		_print_minutes(phase, got)


## The evidence's numbers: each minute's seconds with a big mechanic running and its Pulls, rows and High Tides.
func _print_minutes(phase: int, got: Dictionary) -> void:
	var first: int = got["first"]
	for m in MINUTES:
		var lo := first + m * 3600
		var hi := lo + 3600
		var running := 0
		var count := {B.PULL: 0, B.RIPTIDE: 0, B.HIGH_TIDE: 0}
		for b: Array in got["beats"]:
			var end: int = b[2] if b[2] >= 0 else first + MINUTES * 3600
			running += maxi(0, mini(end, hi) - maxi(b[1], lo))
			if b[1] >= lo and b[1] < hi:
				count[b[0]] += 1
		print(
			(
				"TIDEBEATS| phase=%d minute=%d running_s=%.1f pulls=%d rows=%d high_tides=%d"
				% [
					phase + 1,
					m + 1,
					running / 60.0,
					count[B.PULL],
					count[B.RIPTIDE],
					count[B.HIGH_TIDE]
				]
			)
		)


# --- the push --------------------------------------------------------------------------------------------------


func test_the_push_throws_4_m_and_pops_the_shots_near_where_it_sets_you_down() -> void:
	var s := TideLab.fight(Vector2(8, 0), Vector2.ZERO)
	var w: World = s[0]
	var aid: int = s[1]
	TideLab.hush(w, aid)
	BossLab.start(w, _i(w, aid), &"the_pull")
	var atk := BossAi.attack_of(w, _i(w, aid))
	var last := atk.tide_pull_ticks + atk.tide_push_ticks - 1
	CombatLab.until(
		w,
		func(x: World) -> bool:
			var j := _i(x, aid)
			return x.actors.state[j] == S.ACTIVE and x.actors.state_t[j] == last - 1,
		400
	)
	var p := w.player_pos()
	var boss := w.actors.ids[_i(w, aid)]
	var put := func(at: Vector2, team: int) -> void:
		w.projectiles.add(w.take_id(), boss, team, p + at, Vector2.ZERO, 0.3, 600, 10)
	put.call(Vector2(1.0, 0.0), ActorStore.TEAM_ENEMY)
	put.call(Vector2(0.0, 2.5), ActorStore.TEAM_ENEMY)
	put.call(Vector2(0.0, 3.6), ActorStore.TEAM_ENEMY)
	put.call(Vector2(0.0, -6.0), ActorStore.TEAM_ENEMY)
	put.call(Vector2(0.5, 0.5), ActorStore.TEAM_PLAYER)
	var seen := w.events_since(0)
	var seq := 0 if seen.is_empty() else seen.back().seq as int
	assert_eq(JudgeLab.effects(w, BossTide.PUSH_POP, seq).size(), 0)
	w.step(InputFrame.new())
	var pops := JudgeLab.effects(w, BossTide.PUSH_POP, seq)
	assert_eq(pops.size(), 1, "the set-down pops")
	assert_eq(pops[0].amount, 2, "the two hostile shots within 3 m")
	assert_eq(w.projectiles.size(), 3, "the farther two and the hero's own stay")
	for k in w.projectiles.size():
		var at := Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])
		if w.projectiles.team[k] != ActorStore.TEAM_PLAYER:
			assert_gt(at.distance_to(w.player_pos()), 3.3, "none left within 3 m of the hero")
	assert_eq(TideLab.take_lost(w), 0, "a pop does no damage")
	assert_eq(w.actors.state_t[_i(w, aid)], last, "on the push's last tick")
	w.step(InputFrame.new())
	assert_eq(BossTide.phase_of(w, _i(w, aid)), BossTide.NONE, "the throw is over")
	assert_eq(JudgeLab.effects(w, BossTide.PUSH_POP, seq).size(), 1, "once")


# --- the walk to the safe strip --------------------------------------------------------------------------------


## A Riptide row's four casts in `room` (the hero still at (0, 0)): their warnings and the reader's warn_left as each
## began. The 24 m walled room is TideLab's; a wider rectangle only widens the strips.
func _row(room: Rect2) -> Array:
	var s := TideLab.fight(Vector2(0, 0), Vector2(-9, 9))
	var w: World = s[0]
	TideLab.hush(w, s[1])
	var d := TideLab.dance(w, s[1])
	d.ht_phase = 9
	d.mael_phase = 9
	w.bosses.arena = room
	TideLab.set_phase(w, s[1], 1)
	var amounts: Array[int] = []
	var left: Array[int] = []
	var waits: Array[int] = []
	var seen := 0
	for k in 1400:
		w.step(InputFrame.new())
		w.actors.set_pos(0, Vector2(0, 0))
		var casts := JudgeLab.effects(w, BossDance.RIP_CAST)
		if casts.size() > seen:
			seen = casts.size()
			amounts.append(casts.back().amount)
			left.append(int(WorldReader.new(w).boss_dance()["riptide"]["warn_left"]))
		if seen == 4:
			break
	var casts := JudgeLab.effects(w, BossDance.RIP_CAST)
	var safe: Array[int] = []
	for e in casts:
		safe.append(e.amount_applied)
	JudgeLab.until_effect(w, BossDance.RIP_WAVE, 700, casts.back().seq)
	for e in JudgeLab.effects(w, BossDance.RIP_WAVE):
		waits.append(e.tick)
	return [amounts, left, safe, waits, casts, w, d]


func test_a_wide_room_gives_each_cast_the_walk_to_its_safe_strip() -> void:
	var small := _row(Rect2(-12, -12, 24, 24))
	assert_eq(
		small[0], [150, 150, 150, 180], "in a 24 m room the written 2.5 s (3.0 s the last) hold"
	)
	var wide := _row(Rect2(-30, -30, 60, 60))
	var w: World = wide[5]
	var d: BossDanceTable = wide[6]
	var strips := SafeArea.strips(Rect2(-30, -30, 60, 60), 4)
	var safe: Array = wide[2]
	var speed := BossTide.run_speed(w)
	assert_almost_eq(speed, 0.1, 0.0001, "the hero runs 6 m/s")
	var casts: Array = wide[4]
	var waves: Array = wide[3]
	for n in 4:
		var gap := 0.0
		if n > 0:
			gap = BossDance.rect_gap(strips[safe[n - 1]], strips[safe[n]])
			assert_almost_eq(
				gap, (absi(safe[n] - safe[n - 1]) - 1) * 15.0, 0.001, "the strips between"
			)
		var walk := ceili((gap + 1.0) / speed * 1300 / 1000.0)
		var written := 180 if n == 3 else 150
		assert_eq(
			wide[0][n], maxi(written, walk), "cast %d: the longer of the written and the walk" % n
		)
		assert_eq(wide[1][n], wide[0][n] - 1, "the reader's warn_left counts the real warning")
		assert_eq(waves[n] - casts[n].tick, wide[0][n], "its wave comes when the warning ends")
	assert_gt(wide[0][3], 400, "the far side of a 60 m room: about 6.7 s to walk 2 strips")
	assert_gt(wide[0][2], 150, "a strip away: longer than written")
	assert_eq(d.rip_run_margin, 1300)


# --- the strips cover the floor --------------------------------------------------------------------------------


func test_the_strips_cover_every_walkable_cell_of_the_real_boss_room_over_seeds() -> void:
	var tw := BossLab.world()
	var t: BossTable = tw.boss_tables[BossLab.table_index(tw, &"tidecaller")]
	var r := PlayerTable.starting_values().radius_m
	for sv in Seeds.count(1000):
		var f := FloorGenerator.generate(sv + 1)
		BossRoomBuilder.attach(f, BossArenaSpec.make(t.arena_cells, t.arena_template, 0))
		var room := f.rooms[f.boss_room]  # What the run flow seals as the dance's room (BossFlow)
		var strips := SafeArea.strips(room, BossDanceTable.STRIPS)
		var cells := f.boss_cells_rect
		var near: Array[Obb] = [f.boss_door_wall]
		for wall in f.walls:
			if wall.bounds().grow(r).intersects(cells):
				near.append(wall)
		var y := cells.position.y + NavField.CELL * 0.5
		while y < cells.end.y:
			var x := cells.position.x + NavField.CELL * 0.5
			while x < cells.end.x:
				var p := Vector2(x, y)
				var bad := _cover_fault(p, room, strips, near, r)
				if bad != "":
					fail_test("seed %d: %s at %s (room %s)" % [sv + 1, bad, p, room])
					return
				x += NavField.CELL
			y += NavField.CELL
	assert_true(true, "every cell centre the hero can stand on lies in exactly one strip")


## "" when p is fine: inside the room and in exactly one strip, or outside it and not walkable (a wall within the
## hero's radius).
func _cover_fault(
	p: Vector2, room: Rect2, strips: Array[Rect2], walls: Array[Obb], r: float
) -> String:
	if room.has_point(p):
		var n := 0
		for k in strips:
			n += 1 if k.has_point(p) else 0
		return "" if n == 1 else "in %d strips" % n
	for wall in walls:
		if Collide.circle_vs_obb(p, r, wall) != Vector2.ZERO:
			return ""
	return "walkable floor outside the strips"


func test_in_a_real_run_the_dance_is_the_sealed_rooms_interior() -> void:
	var w := FightLab.floor_world(3, 4, &"guard", [], &"tidecaller")
	FightLab.enter_boss_room(w)
	CombatLab.until(
		w, func(x: World) -> bool: return not WorldReader.new(x).boss_dance().is_empty()
	)
	var f := w.floor_layout
	assert_true(w.bosses.arena.has_area(), "the door sealed")
	var st := WorldReader.new(w).boss_dance()
	assert_false(st.is_empty(), "the Tidecaller dances")
	assert_eq(
		st["room"], f.rooms[f.boss_room], "over the boss room's interior, wall face to wall face"
	)
	var strips: Array = st["strips"]
	var all: Rect2 = strips[0]
	for k: Rect2 in strips:
		all = all.merge(k)
	var whole := f.rooms[f.boss_room]
	assert_almost_eq(
		all.position, whole.position, Vector2(0.001, 0.001), "the four strips together"
	)
	assert_almost_eq(all.end, whole.end, Vector2(0.001, 0.001), "are the whole of it")


func test_in_the_playground_the_dance_and_the_waves_cover_its_room() -> void:
	var repo := SharedContent.repo()
	var w := PlaygroundScenario.build(repo, &"gun", repo.get_def(&"biomes", &"ruins"))
	var room := w.floor_layout.rooms[0]
	var i := BossLab.ready_boss(w, &"tidecaller", room.get_center())
	CombatLab.idle(w, 2)
	assert_false(w.bosses.arena.has_area(), "no sealed boss room here")
	assert_eq(BossDance.room_of(w, i), room, "the dance is cut from the room it stands in")
	assert_eq(BossStream.room_of(w, i), room, "and the crossing waves cross all of it")
	assert_eq(WorldReader.new(w).boss_dance()["room"], room)
	assert_gt(room.size.x, 24.0, "the Playground's room is wider than the old 24 m square")


# --- determinism and a save ------------------------------------------------------------------------------------


func test_the_rhythm_is_deterministic_hashed_and_restores_mid_beat() -> void:
	var make := func(ticks: int) -> World:
		var s := TideLab.fight(Vector2(-6, 0), Vector2(6, 0), 31)
		var w: World = s[0]
		TideLab.set_phase(w, s[1], 1)
		for k in ticks:
			w.step(InputFrame.new())
			w.actors.hp[0] = TideLab.LONG
			w.actors.hp[w.actors.index_of(s[1])] = 1500
		return w
	var a: World = make.call(60 * 20)
	var b: World = make.call(60 * 20)
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	assert_gte(a.bosses.dance_beat_k, 1, "a beat has come")
	var before := a.state_hash()
	a.bosses.dance_beat_at += 1
	assert_ne(a.state_hash(), before, "the rhythm is hashed")
	a.bosses.dance_beat_at -= 1
	a.bosses.dance_rip_warn += 1
	assert_ne(a.state_hash(), before, "and the warning's length")
	a.bosses.dance_rip_warn -= 1
	for ticks: int in [60 * 10, 60 * 26]:  # In a row of Riptide, then waiting on the next beat
		var c: World = make.call(ticks)
		var snap := WorldSnapshot.take(c)
		var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), JudgeLab.world(31))
		assert_not_null(restored, "restores")
		if restored == null:
			return
		assert_eq(restored.state_hash(), c.state_hash(), "same hash restored")
		assert_eq(WorldReader.new(restored).boss_dance(), WorldReader.new(c).boss_dance())
		for k in 900:
			c.step(InputFrame.new())
			restored.step(InputFrame.new())
			c.actors.hp[0] = TideLab.LONG
			restored.actors.hp[0] = TideLab.LONG
		assert_eq(restored.state_hash(), c.state_hash(), "same hash 900 ticks on")
