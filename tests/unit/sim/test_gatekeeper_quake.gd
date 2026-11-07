extends GutTest
## v0.11.0 O3 (owner L5; Q9 a: "boss takes more damage during the stun, this should happen at most 2 times per
## phase"; BossQuake): the Gatekeeper's quake pillars. Three rise as its phase 2 begins and come back to three in
## phase 3; each pulses every 3 s for 3 % of the player's max HP inside its ring; a Shock Lanes strike through one
## shatters it and stuns the Gatekeeper 2 s at +50 % damage taken, at most twice a phase (a third break only removes
## it); the placement comes from the ai stream (same seed, same spots) and survives a save. TEST_MATRIX (a boss step):
## a scripted player beats it two ways, by luring the cross into the pillars and by ignoring them.

const S := EnemyAi.State
const LONG := 1 << 20
const LIMIT_TICKS := 60 * 600
## How far from a pillar, along its row or column, the luring player stands (outside its 2.6 m ring).
const LURE_M := 3.4


## A Gatekeeper at boss_at past its rise, the player at player_at (huge HP, untouchable when asked). [world, boss id].
func _fight(
	player_at: Vector2, boss_at := Vector2.ZERO, untouchable := true, seed_value := 11
) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"gatekeeper", boss_at)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	if untouchable:
		w.actors.invuln[0] = LONG
	return [w, w.actors.ids[i]]


## Drops boss `aid` just under phase `phase`'s threshold and steps one tick: that phase begins (its gate, its pillars).
func _to_phase(w: World, aid: int, phase: int) -> void:
	var i := w.actors.index_of(aid)
	var t := BossAi.table_of(w, i)
	w.actors.hp[i] = w.actors.max_hp[i] * (t.phase_threshold[phase] - 10) / 1000
	w.step(InputFrame.new())


## Holds boss `aid` still (the tests' hold: a long STAGGERED, not a quake stun's length).
func _hold(w: World, aid: int) -> void:
	var i := w.actors.index_of(aid)
	w.actors.state[i] = BossAi.STAGGERED
	w.actors.state_t[i] = 0
	w.bosses.stagger_t[BossAi.entry_of(w, i)] = LONG
	w.bosses.attack[BossAi.entry_of(w, i)] = -1


func _centers(w: World, aid: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in BossQuake.pillars_of(w, aid):
		out.append(BossQuake.center(w.bosses, k))
	return out


## A spot LURE_M from pillar c along its row or column, clear of walls and of the other pillars' rings.
func _lure_spot(w: World, c: Vector2, q: QuakeTable) -> Vector2:
	for d: Vector2 in [
		Vector2(LURE_M, 0), Vector2(-LURE_M, 0), Vector2(0, LURE_M), Vector2(0, -LURE_M)
	]:
		var at := c + d
		if EnemyAi.clear_of_walls(w, at, w.player.radius_m + 0.1):
			var ok := true
			for k in w.bosses.pillar_x.size():
				var o := BossQuake.center(w.bosses, k)
				if o != c and Kin.length(o - at) < q.ring_m + 0.6:
					ok = false
			if ok:
				return at
	return Vector2.INF


## Stands the player beside pillar c along its row and runs Shock Lanes (the phase's), holding them there, until the
## strike has come and gone. Returns how many quake pillars it shattered.
func _lure_once(w: World, aid: int, c: Vector2) -> int:
	var i := w.actors.index_of(aid)
	var spot := _lure_spot(w, c, BossAi.table_of(w, i).quake)
	assert_ne(spot, Vector2.INF, "a spot on the pillar's row")
	var before := BossQuake.pillars_of(w, aid).size()
	w.actors.state[i] = S.MOVE
	w.bosses.stagger_t[BossAi.entry_of(w, i)] = 0
	w.actors.set_pos(0, spot)
	var lanes := (
		&"shock_lanes_2" if w.bosses.phase[BossAi.entry_of(w, i)] >= 2 else &"shock_lanes_follow"
	)
	BossLab.start(w, i, lanes)
	for k in 200:
		w.actors.set_pos(0, spot)
		w.step(InputFrame.new())
		i = w.actors.index_of(aid)
		if w.actors.state[i] != S.WINDUP and w.actors.state[i] != S.ACTIVE:
			break
	return before - BossQuake.pillars_of(w, aid).size()


func test_three_pillars_rise_as_phase_two_begins_and_are_walls_and_hints() -> void:
	var s := _fight(Vector2(7, 2))
	var w: World = s[0]
	var aid: int = s[1]
	var walls := w.walls.size()
	assert_eq(BossQuake.pillars_of(w, aid).size(), 0, "none in phase 1")
	_to_phase(w, aid, 1)
	var i := w.actors.index_of(aid)
	var q := BossAi.table_of(w, i).quake
	assert_not_null(q)
	assert_eq(q.count, 3, "3 pillars (owner Q9 a)")
	var cs := _centers(w, aid)
	assert_eq(cs.size(), 3, "3 rise with phase 2")
	assert_eq(w.walls.size(), walls + 3, "each one a wall")
	for a in cs.size():
		for b in range(a + 1, cs.size()):
			assert_gte(Kin.length(cs[a] - cs[b]), q.gap_m, "pillars apart")
		assert_gte(
			Kin.length(cs[a] - w.actors.pos(i)),
			w.actors.radius[i] + q.boss_m + q.half_m,
			"clear of the boss"
		)
	for k in BossQuake.pillars_of(w, aid):
		var o := BossSignatures.pillar_obb(w.bosses, k)
		for j in w.actors.size():
			assert_eq(
				Collide.circle_vs_obb(w.actors.pos(j), w.actors.radius[j], o),
				Vector2.ZERO,
				"not on a body"
			)
	assert_eq(w.objectives.size(), 3, "the hint points at each pillar")
	assert_true(w.objectives.has(ObjectiveMarkers.GATEKEEPER_PILLAR))
	assert_eq(WorldReader.new(w).boss_quake_pillars().size(), 3, "the view reads them")
	assert_eq(WorldReader.new(w).boss_pillars().size(), 0, "not as Shock Lanes' sinking pillars")


func test_a_pillar_pulses_every_three_seconds_for_three_percent_inside_its_ring() -> void:
	var s := _fight(Vector2(7, 2), Vector2.ZERO, false)
	var w: World = s[0]
	var aid: int = s[1]
	w.actors.max_hp[0] = 100000
	w.actors.hp[0] = 100000
	_to_phase(w, aid, 1)
	_hold(w, aid)
	var k := BossQuake.pillars_of(w, aid)[0]
	var c := BossQuake.center(w.bosses, k)
	var rose := w.bosses.pillar_from[k]
	var q := BossAi.table_of(w, w.actors.index_of(aid)).quake
	assert_eq(q.pulse_ticks, 180, "every 3 s (a starting value)")
	var inside := c + Vector2(q.half_m + w.player.radius_m + 0.4, 0)
	var seq := w.last_event_seq()
	var hits := []
	for t in 400:
		w.actors.set_pos(0, inside)
		w.step(InputFrame.new())
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
			if e.effect_id == BossQuake.EFFECT:
				hits.append([e.tick, e.amount_applied])
	assert_eq(hits.size(), 2, "two pulses in 400 ticks: %s" % [hits])
	if hits.size() == 2:
		assert_eq(int(hits[0][0]), rose + 180, "the first 3 s after it rose")
		assert_eq(int(hits[1][0]), rose + 360, "then every 3 s")
		assert_eq(int(hits[0][1]), 3000, "3 % of the max HP")
	# outside the ring: no pulse
	seq = w.last_event_seq()
	var outside := c + Vector2(q.ring_m + w.player.radius_m + 0.3, 0)
	for t in 200:
		w.actors.set_pos(0, outside)
		w.step(InputFrame.new())
	var n := 0
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.DAMAGE and e.effect_id == BossQuake.EFFECT:
			n += 1
	assert_eq(n, 0, "nothing beyond the ring")


func test_the_ring_telegraph_grows_over_its_warning_before_the_pulse() -> void:
	var s := _fight(Vector2(7, 2))
	var w: World = s[0]
	var aid: int = s[1]
	_to_phase(w, aid, 1)
	_hold(w, aid)
	var k := BossQuake.pillars_of(w, aid)[0]
	var q := BossAi.table_of(w, w.actors.index_of(aid)).quake
	assert_gte(
		q.warn_ticks, SimTick.MIN_TELEGRAPH_TICKS, "the ring warns at least the telegraph minimum"
	)
	var rose := w.bosses.pillar_from[k]
	CombatLab.idle(w, rose + q.pulse_ticks - q.warn_ticks - w.tick - 1)
	assert_eq(int(BossQuake.ring_state(w, q, k)["warn"]), -1, "quiet before the warning")
	w.step(InputFrame.new())
	assert_eq(int(BossQuake.ring_state(w, q, k)["warn"]), 0, "the ring starts")
	CombatLab.idle(w, q.warn_ticks / 2)
	var mid := int(BossQuake.ring_state(w, q, k)["warn"])
	assert_between(mid, 400, 600, "half grown halfway")


func test_a_lane_through_a_pillar_shatters_it_and_stuns_two_seconds_at_plus_fifty_percent() -> void:
	var s := _fight(Vector2(7, 2))
	var w: World = s[0]
	var aid: int = s[1]
	_to_phase(w, aid, 1)
	BossLab.through_gate(w, aid)
	var walls := w.walls.size()
	var c := _centers(w, aid)[0]
	var broke := _lure_once(w, aid, c)
	assert_gte(broke, 1, "the cross shattered the pillar it ran into")
	assert_false(_centers(w, aid).has(c), "that pillar is gone")
	assert_eq(w.walls.size(), walls - broke, "its wall too")
	assert_eq(w.objectives.size(), 3 - broke, "the hint points at the ones left")
	var i := w.actors.index_of(aid)
	var b := BossAi.entry_of(w, i)
	assert_eq(w.actors.state[i], BossAi.STAGGERED, "stunned")
	assert_true(BossQuake.stunned(w, i))
	assert_true(WorldReader.new(w).boss_stunned(i), "the bar reads it")
	assert_eq(BossQuake.stuns_of(w, aid), 1)
	var left := w.bosses.stagger_t[b]
	assert_between(left, 100, 120, "2 s (120 ticks) of stun, a few already gone")
	# +50 % damage: the same hit during the stun and after it
	w.bosses.exposed_t[b] = 0
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(w.actors.radius[i] + 1.0, 0))
	var during := _hit(w, i)
	CombatLab.idle(w, left + 1)
	i = w.actors.index_of(aid)
	assert_ne(w.actors.state[i], BossAi.STAGGERED, "the stun ends on time")
	assert_false(BossQuake.stunned(w, i))
	_hold_off(w, aid)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(w.actors.radius[i] + 1.0, 0))
	var after := _hit(w, i)
	assert_eq(during, after * 3 / 2, "it takes +50 %% while stunned (%d vs %d)" % [during, after])


## The HP a 100-point player hit takes off boss i.
func _hit(w: World, i: int) -> int:
	w.bosses.exposed_t[BossAi.entry_of(w, i)] = 0
	var before := w.actors.hp[i]
	var p := w.player_pos()
	Damage.hit(
		w,
		i,
		100,
		w.actors.ids[0],
		w.actors.ids[0],
		w.take_root(),
		SimEvent.TAG_MELEE,
		p,
		w.actors.pos(i)
	)
	return before - w.actors.hp[i]


## Ends boss `aid`'s attack (it stands in MOVE, cooling down) so a test hit meets no weak point.
func _hold_off(w: World, aid: int) -> void:
	var i := w.actors.index_of(aid)
	w.actors.state[i] = S.MOVE
	w.actors.cd[i] = LONG
	w.bosses.attack[BossAi.entry_of(w, i)] = -1


func test_a_third_break_in_a_phase_shatters_without_a_stun_and_phase_three_brings_them_back(
) -> void:
	var s := _fight(Vector2(7, 2))
	var w: World = s[0]
	var aid: int = s[1]
	_to_phase(w, aid, 1)
	BossLab.through_gate(w, aid)
	var stuns := []
	while not _centers(w, aid).is_empty():
		var broke := _lure_once(w, aid, _centers(w, aid)[0])
		assert_gt(broke, 0, "each lure breaks one")
		if broke == 0:
			return
		var i := w.actors.index_of(aid)
		stuns.append(w.actors.state[i] == BossAi.STAGGERED)
	assert_eq(BossQuake.stuns_of(w, aid), 2, "two stuns this phase")
	assert_eq(stuns.count(true), 2, "the first two breaks stun")
	assert_false(stuns.back(), "a later break only removes the pillar")
	assert_false(w.objectives.has(ObjectiveMarkers.GATEKEEPER_PILLAR), "no hint once none stands")
	_hold_off(w, aid)
	_to_phase(w, aid, 2)
	assert_eq(_centers(w, aid).size(), 3, "phase 3: three again")
	assert_eq(BossQuake.stuns_of(w, aid), 0, "the count starts again")
	assert_eq(w.objectives.size(), 3)


func test_phase_three_tops_the_pillars_up_to_three() -> void:
	var s := _fight(Vector2(7, 2))
	var w: World = s[0]
	var aid: int = s[1]
	_to_phase(w, aid, 1)
	BossLab.through_gate(w, aid)
	var kept := _centers(w, aid)
	_lure_once(w, aid, kept[0])
	var left := _centers(w, aid)
	assert_lt(left.size(), 3)
	_hold_off(w, aid)
	_to_phase(w, aid, 2)
	var now := _centers(w, aid)
	assert_eq(now.size(), 3, "back to three")
	for c in left:
		assert_true(now.has(c), "the standing ones stay where they are")


func test_the_placement_is_deterministic_by_seed_and_survives_a_save() -> void:
	var f1 := _floor_fight()
	if f1.is_empty():
		fail_test("no run seed in 1..79 has the Gatekeeper on floor 1")
		return
	var a: World = f1[0]
	var b: World = _floor_fight()[0]
	for w: World in [a, b]:
		_to_phase(w, w.boss_id, 1)
	assert_eq(_centers(a, a.boss_id), _centers(b, b.boss_id), "same seed, same spots")
	assert_eq(_centers(a, a.boss_id).size(), 3)
	for c: Vector2 in _centers(a, a.boss_id):
		assert_true(a.bosses.arena.has_point(c), "inside the boss room")
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	var other := _fight(Vector2(7, 2), Vector2.ZERO, true, 12)
	var mine := _fight(Vector2(7, 2), Vector2.ZERO, true, 11)
	_to_phase(other[0], other[1], 1)
	_to_phase(mine[0], mine[1], 1)
	assert_ne(_centers(other[0], other[1]), _centers(mine[0], mine[1]), "another seed, other spots")
	var snap := WorldSnapshot.take(a)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), _floor_fight()[0])
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "same hash restored")
	for k in 420:
		var f := (
			InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
		)
		a.step(f)
		restored.step(f)
	assert_eq(restored.state_hash(), a.state_hash(), "same hash 420 ticks on")


## A real floor 1 whose boss is the Gatekeeper, the fight begun and the boss past its rise: [world].
func _floor_fight() -> Array:
	for run_seed in range(1, 80):
		var w := SaveLab.floor_world(run_seed, 1)
		w.actors.hp[0] = LONG
		w.actors.max_hp[0] = LONG
		FightLab.enter_boss_room(w)
		CombatLab.idle(w, 3)
		if w.boss_id < 0:
			continue
		var i := w.actors.index_of(w.boss_id)
		if BossAi.table_of(w, i).id != &"gatekeeper":
			continue
		w.actors.state[i] = S.MOVE
		w.actors.state_t[i] = 0
		w.actors.invuln[i] = 0
		return [w]
	return []


func test_a_pulse_that_kills_names_its_line_and_reads_as_a_cause() -> void:
	var s := _fight(Vector2(7, 2), Vector2.ZERO, false)
	var w: World = s[0]
	var aid: int = s[1]
	var rc := ReadableCause.new(w)
	_to_phase(w, aid, 1)
	_hold(w, aid)
	w.actors.max_hp[0] = 1000
	w.actors.hp[0] = 10
	var c := _centers(w, aid)[0]
	var q := BossAi.table_of(w, w.actors.index_of(aid)).quake
	for t in 400:
		if w.player_dead():
			break
		w.actors.set_pos(0, c + Vector2(q.half_m + w.player.radius_m + 0.4, 0))
		w.step(InputFrame.new())
		rc.observe(w)
	assert_true(w.player_dead(), "the pulse killed")
	assert_eq(WorldReader.new(w).killer_cause_key(), &"CAUSE_GATEKEEPER_PILLAR")
	assert_eq(rc.violations, [], "readable: its ring warned, its line in en and es")
	assert_eq(rc.last_cause, "CAUSE_GATEKEEPER_PILLAR")


# --- TEST_MATRIX: a scripted player beats it two ways -----------------------------------------------------------


## [ticks to kill (or -1), stuns, pillars broken, hits while stunned] for a melee player (the Blade) who `lures` the
## cross into the pillars while it may still stun (else just fights), or ignores them.
static func duel(lures: bool, seed_value: int = 5) -> Array:
	var w := BossLab.world(seed_value)
	var build: BuildDefinition = ContentRepository.load_all().get_def(&"build", &"blade")
	ContentCompiler.apply_build(w.player, build)
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	var bid := w.spawn_boss(BossLab.table_index(w, &"gatekeeper"), Vector2(9, 0))
	var seq := 0
	var stuns := 0
	var broken := 0
	var stunned_hits := 0
	for t in LIMIT_TICKS:
		var i := w.actors.index_of(bid)
		if i < 0:
			return [t, stuns, broken, stunned_hits]
		var was_stunned := BossQuake.stunned(w, i)
		w.step(_bot_frame(w, i, bid, lures, t))
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == BossQuake.STUN:
				stuns += 1
			if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == BossQuake.SHATTER:
				broken += 1
			if was_stunned and e.kind == SimEvent.Kind.HIT and e.target_id == bid:
				stunned_hits += 1
	return [-1, stuns, broken, stunned_hits]


## The bot's input: luring, it walks to a spot LURE_M along a standing pillar's row or column and waits there for
## the cross (while the phase may still stun); stunned, or otherwise, it walks in and keeps swinging.
static func _bot_frame(w: World, i: int, bid: int, lures: bool, t: int) -> InputFrame:
	var to := w.actors.pos(i) - w.player_pos()
	var dist := Kin.length(to)
	var q := BossAi.table_of(w, i).quake
	if (
		lures
		and not BossQuake.stunned(w, i)
		and q != null
		and BossQuake.stuns_of(w, bid) < q.stuns_per_phase
		and not BossQuake.pillars_of(w, bid).is_empty()
	):
		var spot := _bot_spot(w, i, bid, q)
		if spot != Vector2.INF:
			var go := spot - w.player_pos()
			var mv := Vector2i.ZERO
			if Kin.length(go) > 0.15:
				var d := go / Kin.length(go)
				mv = Vector2i(roundi(d.x * 127.0), roundi(d.y * 127.0))
			return InputFrame.make(mv, Kin.angle_of(to), int(dist * 100.0), 0, 0)
	var mv2 := Vector2i.ZERO
	if dist > 0.001:
		var dir := to / dist
		var near := w.actors.radius[i] + 1.2
		var s := 127.0 if dist > near else 40.0  # keep facing the boss (L29)
		mv2 = Vector2i(roundi(dir.x * s), roundi(dir.y * s))
	var pressed := InputFrame.PRIMARY if t % 6 == 0 else 0
	return InputFrame.make(mv2, Kin.angle_of(to), int(dist * 100.0), 0, pressed)


## The luring spot: LURE_M along the row or column of the standing pillar nearest the player, the one of its four
## farthest from the boss, clear of walls and of the other pillars' rings.
static func _bot_spot(w: World, i: int, bid: int, q: QuakeTable) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	var p := w.player_pos()
	for k in BossQuake.pillars_of(w, bid):
		var c := BossQuake.center(w.bosses, k)
		var d := Kin.length(c - p)
		if d >= best_d:
			continue
		var far := -1.0
		for off: Vector2 in [
			Vector2(LURE_M, 0), Vector2(-LURE_M, 0), Vector2(0, LURE_M), Vector2(0, -LURE_M)
		]:
			var at := c + off
			if not EnemyAi.clear_of_walls(w, at, w.player.radius_m + 0.1):
				continue
			var in_ring := false
			for o in BossQuake.pillars_of(w, bid):
				if o != k and Kin.length(BossQuake.center(w.bosses, o) - at) < q.ring_m + 0.6:
					in_ring = true
			if in_ring:
				continue
			var from_boss := Kin.length(at - w.actors.pos(i))
			if from_boss > far:
				far = from_boss
				best = at
				best_d = d
	return best


func test_a_scripted_player_wins_by_luring_the_cross_into_the_pillars() -> void:
	var r := duel(true)
	print(
		(
			"QUAKE_DUEL| lure ticks=%d seconds=%.1f stuns=%d broken=%d stunned_hits=%d"
			% [r[0], r[0] / 60.0, r[1], r[2], r[3]]
		)
	)
	assert_gt(int(r[0]), 0, "the Gatekeeper dies")
	assert_gte(int(r[1]), 2, "the cross broke pillars and stunned it")
	assert_gt(int(r[3]), 0, "it hit the stunned Gatekeeper")
	assert_lte(int(r[1]), 4, "at most two stuns in each of phases 2 and 3")


func test_a_scripted_player_wins_by_ignoring_the_pillars() -> void:
	var r := duel(false)
	print(
		(
			"QUAKE_DUEL| ignore ticks=%d seconds=%.1f stuns=%d broken=%d"
			% [r[0], r[0] / 60.0, r[1], r[2]]
		)
	)
	assert_gt(int(r[0]), 0, "the Gatekeeper dies without luring")
