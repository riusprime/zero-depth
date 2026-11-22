extends GutTest
## v0.7.5 PG (owner N20, pick "Total + per-source"): the Playground's DPS meter counts the player's damage from the
## event log, over the last 5 s and since the first hit, by source.


func test_the_window_and_the_average() -> void:
	var t := DpsTally.new()
	assert_eq(t.dps_recent(100), 0.0, "nothing yet")
	for tick in range(0, 600):  # 10 s of 10 damage a tick
		t.add(tick, DpsTally.BASIC, 10)
	assert_eq(t.total, 6000)
	assert_almost_eq(t.dps_recent(599), 600.0, 0.01, "10 a tick is 600 a second")
	assert_almost_eq(t.dps_overall(599), 600.0, 0.01)
	assert_almost_eq(t.seconds(599), 10.0, 0.01)
	assert_almost_eq(t.dps_recent(899), 0.0, 0.01, "5 s later the window is empty")
	assert_almost_eq(t.dps_overall(899), 400.0, 0.01, "the average keeps the quiet time")


func test_the_first_seconds_are_not_diluted() -> void:
	var t := DpsTally.new()
	for tick in range(1000, 1060):  # one second of hits, starting late
		t.add(tick, DpsTally.BASIC, 5)
	assert_almost_eq(t.dps_recent(1059), 300.0, 0.01, "over the time since the first hit")


func test_sources_rank_by_damage() -> void:
	var t := DpsTally.new()
	t.add(1, DpsTally.BASIC, 30)
	t.add(1, &"bleed", 50)
	t.add(2, &"burn", 20)
	t.add(3, &"bleed", 5)
	var r := t.ranked()
	assert_eq(r[0], [&"bleed", 55])
	assert_eq(r[1], [DpsTally.BASIC, 30])
	assert_eq(r[2], [&"burn", 20])


func test_a_source_is_the_effect_id_or_the_basic_attack() -> void:
	var e := SimEvent.new()
	assert_eq(DpsTally.source_of(e), DpsTally.BASIC)
	e.effect_id = &"split_shot"
	assert_eq(DpsTally.source_of(e), &"split_shot")


func test_reset_starts_again() -> void:
	var t := DpsTally.new()
	t.add(5, DpsTally.BASIC, 100)
	t.reset()
	assert_eq(t.total, 0)
	assert_eq(t.first_tick, -1)
	assert_eq(t.ranked().size(), 0)
	assert_eq(t.dps_recent(10), 0.0)


func test_it_counts_the_players_damage_from_a_world() -> void:
	var repo := AttackScenario.repo()
	var w := PlaygroundScenario.build(repo, &"gun", repo.get_def(&"biomes", &"ruins"))
	var pg := PlaygroundApi.new(w)
	pg.place_dummy_now(w.player_pos() + Vector2(3, 0))
	var reader := WorldReader.new(w)
	var t := DpsTally.new()
	for tick in 240:
		pg.apply_pending()
		w.step(InputFrame.make(Vector2.ZERO, 0, 300, InputFrame.SHOOT, 0))
		t.observe(reader)
	var applied := 0
	for e: SimEvent in w.events_since(-1):
		if (
			e.kind == SimEvent.Kind.DAMAGE
			and e.owner_id == w.actors.ids[0]
			and e.target_id != e.owner_id
		):
			applied += e.amount_applied
	assert_gt(t.total, 0, "the Gun's bolts hit the dummy")
	assert_eq(t.total, applied, "every point of damage the dummy took, once")
	assert_true(t.by_source.has(DpsTally.BASIC))
	t.reset(reader)
	t.observe(reader)
	assert_eq(t.total, 0, "what came before the reset is not counted again")


## The recent window is kept as hits come in and the window moves: every read is the full read of the slots.
func test_the_kept_window_matches_a_full_read() -> void:
	var t := DpsTally.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	var now := 0
	for step in 4000:
		var roll := rng.randi_range(0, 9)
		if roll < 6:  # A hit this tick, a little in the past, or far behind
			var back := 0 if roll < 4 else rng.randi_range(0, 700)
			t.add(maxi(0, now - back), DpsTally.BASIC, rng.randi_range(1, 50))
		elif roll < 9:  # The clock moves a tick or a few (a frame that ran several)
			now += rng.randi_range(1, 4)
		elif rng.randi_range(0, 30) == 0:  # A long quiet, or a reset
			now += rng.randi_range(200, 900)
			if rng.randi_range(0, 2) == 0:
				t.reset()
		assert_eq(t.dps_recent(now), _full_read(t, now), "tick %d (step %d)" % [now, step])


func _full_read(t: DpsTally, now: int) -> float:
	if t.first_tick < 0:
		return 0.0
	var sum := 0
	for k in DpsTally.WINDOW_TICKS:
		if t._stamp[k] > now - DpsTally.WINDOW_TICKS and t._stamp[k] <= now:
			sum += t._bucket[k]
	var span := mini(DpsTally.WINDOW_TICKS, now - t.first_tick + 1)
	return float(sum) * SimTick.TICKS_PER_SECOND / maxi(span, 1)
