extends GutTest
## v0.10.5 Q5 (owner: "Q5 yes fix it"; PERF_Q5 §5 fix 1): the sim still steps every tick, the world views sync once a
## rendered frame on the latest tick (SimDriver.frame_ticked), and nothing that happened between two frames is lost:
## the hits and damage numbers come from the event log (each view's own cursor), and what lasts one tick (a Gun shot,
## an enemy's one-tick strike) is kept by the views' LatchedReader until their next sync.


func _gun_world() -> World:
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	t.crit_chance_permille = 0
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"gun"))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	return w


func _shoot(k: int) -> InputFrame:
	return InputFrame.make(
		Vector2i.ZERO, 0, 400, InputFrame.SHOOT, InputFrame.SHOOT if k == 0 else 0
	)


func test_the_driver_signals_once_a_frame_that_ran_ticks() -> void:
	var driver := SimDriver.new()
	driver.setup(World.new(1, PlayerTable.starting_values()))
	driver.input_source = func() -> Array: return [Vector2.ZERO, Vector2.RIGHT, 1.0]
	var got := {"ticks": 0, "frames": 0}
	driver.ticked.connect(func() -> void: got["ticks"] += 1)
	driver.frame_ticked.connect(func() -> void: got["frames"] += 1)
	for i in 3:  # a frame that fell behind: three ticks
		driver.step_once()
	driver._process(0.05)
	assert_eq(got["ticks"], 3, "the sim stepped every tick")
	assert_eq(got["frames"], 1, "the views' signal came once, after them")
	driver._process(0.004)  # a fast frame with no tick: nothing new to show
	assert_eq(got["frames"], 1, "a frame with no tick does not sync")
	driver.step_once()
	driver._process(0.016)
	assert_eq(got["frames"], 2, "one tick, one sync")
	driver.free()


func test_hits_between_two_syncs_still_flash_and_number() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	var a := w.add_dummy(Vector2(1.2, 0), 0.35, 500)
	var b := w.add_dummy(Vector2(-3.0, 2.0), 0.35, 500)
	var reader := LatchedReader.new(WorldReader.new(w))
	var views := ActorViews.new()
	add_child_autofree(views)
	views.set_process(false)  # the flash counts down in frame time: held for the check
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var feel := HitFeel.new(views, rig)
	add_child_autofree(feel)
	var numbers := DamageNumbers.new()
	add_child_autofree(numbers)
	numbers.set_process(false)
	reader.settle()
	views.sync(reader)
	feel.sync(reader)
	numbers.sync(reader)
	var hero := w.actors.ids[0]
	var ia := w.actors.index_of(a)
	var ib := w.actors.index_of(b)
	# Three ticks with no sync between them (a frame that fell behind): a hit on the first, one on the third.
	Damage.hit(w, ia, 7, hero, hero, hero, 0, Vector2.ZERO, w.actors.pos(ia))
	w.step(InputFrame.new())
	reader.note()
	w.step(InputFrame.new())
	reader.note()
	Damage.hit(w, ib, 9, hero, hero, hero, 0, Vector2.ZERO, w.actors.pos(ib))
	w.step(InputFrame.new())
	reader.note()
	reader.settle()
	views.sync(reader)
	feel.sync(reader)
	numbers.sync(reader)
	assert_true(views.is_flashing(a), "the first tick's hit still flashes its target")
	assert_true(views.is_flashing(b), "and the third tick's")
	var texts := numbers.shown().map(func(s: Array) -> String: return String(s[0]))
	assert_eq(texts.size(), 2, "both hits get their number: %s" % [texts])
	assert_has(texts, "7")
	assert_has(texts, "9")


func test_every_shot_between_syncs_still_casts() -> void:
	var w := _gun_world()
	var reader := LatchedReader.new(WorldReader.new(w))
	var plain := WorldReader.new(w)  # the tick's own shot
	var fx := HeroCastFx.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.sync(reader)
	var shots := 0
	for k in 90:
		w.step(_shoot(k))
		reader.note()
		shots += 1 if plain.shot_fired() else 0
		if k % 3 == 2:  # three ticks a frame
			reader.settle()
			fx.sync(reader)
			fx._process(3.0 / 60.0)
	assert_eq(shots, 10, "90 ticks at 9 a shot")
	assert_eq(
		fx.started + fx.merged, shots, "each shot reached the cast, though most fell between syncs"
	)


func test_a_one_tick_strike_reads_active_at_the_next_sync_only() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	var id := w.add_dummy(Vector2(2.0, 0), 0.35, 500)
	var i := w.actors.index_of(id)
	var reader := LatchedReader.new(WorldReader.new(w))
	var rest := reader.actor_state(i)
	assert_ne(rest, WorldReader.STATE_ACTIVE)
	w.actors.state[i] = WorldReader.STATE_ACTIVE  # the strike's one tick
	reader.note()
	w.actors.state[i] = WorldReader.STATE_RECOVER  # the next tick, before any sync
	reader.note()
	reader.settle()
	assert_eq(
		reader.actor_state(i), WorldReader.STATE_ACTIVE, "the sync after it still sees the strike"
	)
	reader.note()
	reader.settle()
	assert_eq(
		reader.actor_state(i), WorldReader.STATE_RECOVER, "once: the next sync reads the tick's own"
	)


func test_a_half_rate_view_still_syncs_at_two_ticks_a_frame() -> void:
	for id: StringName in ViewSchedule.HALF_RATE:
		var seen := {}
		var runs := 0
		for t in range(0, 40, 2):  # a steady two ticks a frame: always the same parity
			runs += 1 if ViewSchedule.due(id, t, seen) else 0
		assert_eq(runs, 20, "%s syncs on every frame (two ticks passed)" % id)
		seen = {}
		runs = 0
		for t in 40:  # one tick a frame: every other tick, as before
			runs += 1 if ViewSchedule.due(id, t, seen) else 0
		assert_between(runs, 20, 21, "%s at one tick a frame: half the ticks" % id)


## v0.10.5 W3-Q7 (owner playtest: the Gun's bolt "lags or sticks", "flickers"): on a frame that ran two ticks the shot
## views drew a shot from its place at the last sync, a tick or more behind, then caught up the next frame. They now
## draw it between its places at the last two ticks, as on a one-tick frame; a one-tick frame is unchanged.
func test_a_shot_is_drawn_between_the_last_two_ticks_when_a_frame_ran_several() -> void:
	var w := _gun_world()
	var reader := LatchedReader.new(WorldReader.new(w))
	var pulses := HeroPulseViews.new()
	add_child_autofree(pulses)
	pulses.set_process(false)
	var places := []  # the shot's place at each tick
	var id := -1
	for k in 8:
		w.step(_shoot(k))
		reader.note()
		var r := WorldReader.new(w)
		if id < 0 and r.projectile_count() > 0:
			id = r.projectile_id(0)
		var i := -1
		for j in r.projectile_count():
			if r.projectile_id(j) == id:
				i = j
		places.append(r.projectile_pos(i) if i >= 0 else Vector2.INF)
		if k == 2 or k == 3 or k == 5:  # syncs after ticks 2 and 3 (one tick apart), then after 5 (two ticks)
			reader.settle()
			pulses.sync(reader)
			if k == 3:
				assert_eq(
					pulses._before[id], places[2], "a one-tick frame: from the last sync's place"
				)
			if k == 5:
				assert_ne(places[4], places[3], "the shot moved between the ticks")
				assert_eq(
					pulses._before[id],
					places[4],
					"a two-tick frame: from the tick before the latest"
				)
	assert_gte(id, 0, "the Gun fired")
	assert_eq(pulses._now[id], places[5], "to the latest")
