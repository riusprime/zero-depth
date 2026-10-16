extends GutTest
## v0.8.0 N5 (owner O58, Left 4 Dead's director: "It doesn't change how hard the game hits. It changes when."): the
## hidden intensity rises on hits (by their share of max HP), on kills beside the hero and while enemies are close;
## it drains only after the calm time with no hit and no enemy close. BUILD_UP → PEAK at the threshold (3-5 s) →
## PULL_BACK (no new packs) → QUIET (10-20 s, from the `ai:intensity:<cycle>` stream; no new packs) → BUILD_UP. The
## director only gates when packs come: what arrives and how strong is unchanged. Off without its table.

const LONG := 1 << 24
const KIND := ActorStore.Kind
const M := IntensityState.Mode


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


func _table() -> IntensityTable:
	return IntensityCompiler.compile(_repo().get_def(&"intensity", &"director"))


## A wall-less world with the real enemies, a ring of spawn points at 9 m and the shipped spawner and director.
func _world(seed_value: int = 11, director: bool = true) -> World:
	var repo := _repo()
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	for k in 8:
		w.spawn_points.append(Kin.dir(k * 512) * 9.0)
	w.spawner = ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo)
	if director:
		w.spawner.intensity = _table()
	w.actors.invuln[0] = LONG
	return w


## One director tick, as SpawnDirector.advance runs it in phase 9 (the tick counter moves on after).
func _tick(w: World, n: int = 1) -> void:
	for k in n:
		Intensity.advance(w)
		w.tick += 1


func _level(w: World) -> int:
	return w.intensity.level / 1000


func test_the_shipped_definition_is_valid_and_compiles_to_ticks() -> void:
	var def: IntensityDirectorDefinition = _repo().get_def(&"intensity", &"director")
	assert_not_null(def, "data/spawning/intensity.tres")
	assert_eq(def.validate(), [] as Array[ValidationIssue])
	var t := _table()
	assert_eq(t.calm_ticks, 120, "2 s")
	assert_eq(t.peak_level, 750000)
	assert_eq([t.peak_ticks_min, t.peak_ticks_max], [180, 300], "3-5 s")
	assert_eq([t.quiet_ticks_min, t.quiet_ticks_max], [600, 1200], "10-20 s")
	assert_eq(t.drain_per_tick, def.drain_per_second * 1000 / 60)


func test_bad_values_are_rejected() -> void:
	var def := IntensityDirectorDefinition.new()
	def.id = &"director"
	def.relax_intensity = 800
	def.peak_seconds_min = 6.0
	def.close_radius_m = 0.0
	def.drain_per_second = 0
	var codes := []
	for i in def.validate():
		codes.append(String(i.code))
	for c in ["intensity_order", "duration_range", "not_positive", "range"]:
		assert_has(codes, c)


func test_a_hit_adds_its_share_of_max_hp() -> void:
	var w := _world()
	var t := w.spawner.intensity
	_tick(w)
	var max_hp := w.actors.max_hp[0]
	w.actors.hp[0] -= max_hp / 10
	_tick(w)
	var want := (max_hp / 10) * t.hit_full_hp_gain / max_hp / 1000
	assert_eq(_level(w), want, "10 % of max HP")
	assert_gt(want, 0)


func test_a_gap_in_the_director_counts_no_hit() -> void:
	var w := _world()
	_tick(w)
	w.tick += 30  # an arena or the boss room: the director didn't run
	w.actors.hp[0] -= 20
	_tick(w)
	assert_eq(w.intensity.level, 0, "HP lost while paused is not a hit")


func test_close_enemies_add_a_little_every_tick_and_far_ones_nothing() -> void:
	var w := _world()
	var t := w.spawner.intensity
	w.add_enemy(KIND.CHARGER, Vector2(6, 0))
	_tick(w, 10)
	assert_eq(w.intensity.level, 0, "6 m is not close")
	w.actors.set_pos(1, Vector2(2, 0))
	_tick(w, 10)
	assert_eq(w.intensity.level, 10 * t.close_gain_per_tick)


func test_a_kill_beside_the_hero_adds_and_a_far_one_does_not() -> void:
	var w := _world()
	var t := w.spawner.intensity
	_tick(w)
	w.add_enemy(KIND.CHARGER, Vector2(2, 0))
	w.add_enemy(KIND.CHARGER, Vector2(7, 0))
	Intensity.on_death(w, 2)
	assert_eq(w.intensity.level, 0, "7 m away")
	Intensity.on_death(w, 1)
	assert_eq(w.intensity.level, t.close_kill_gain)


func test_a_kill_in_play_goes_through_remove_dead() -> void:
	var w := _world()
	var t := w.spawner.intensity
	w.step(InputFrame.new())
	w.add_enemy(KIND.CHARGER, Vector2(2.5, 0))
	w.actors.invuln[1] = 0
	w.intensity.level = 0
	w.actors.dead[1] = 1
	var before := w.intensity.level
	w.step(InputFrame.new())
	assert_gte(w.intensity.level - before, t.close_kill_gain, "the kill counted in phase 9")


func test_it_drains_only_after_the_calm_time() -> void:
	var w := _world()
	var t := w.spawner.intensity
	w.intensity.level = 500000
	_tick(w)
	w.actors.hp[0] -= 1  # a hit: the calm starts again
	_tick(w)
	var after_hit := w.intensity.level
	_tick(w, t.calm_ticks - 1)
	assert_eq(w.intensity.level, after_hit, "no drain before the calm time")
	_tick(w, 10)
	assert_eq(w.intensity.level, after_hit - 10 * t.drain_per_tick, "then drain_per_tick a tick")
	w.add_enemy(KIND.CHARGER, Vector2(1.5, 0))
	var close_from := w.intensity.level
	_tick(w, 200)
	assert_eq(
		w.intensity.level, close_from + 200 * t.close_gain_per_tick, "never while one is close"
	)
	w.intensity.level = 100
	w.actors.set_pos(1, Vector2(30, 0))
	_tick(w, t.calm_ticks + 50)
	assert_eq(w.intensity.level, 0, "never below 0")


func test_build_up_turns_into_a_peak_at_the_threshold() -> void:
	var w := _world()
	var t := w.spawner.intensity
	w.intensity.level = t.peak_level - 1
	_tick(w)
	assert_eq(w.intensity.mode, M.BUILD_UP, "drains a little: still building")
	w.intensity.level = t.peak_level
	w.actors.hp[0] -= 1
	_tick(w)
	assert_eq(w.intensity.mode, M.PEAK)
	assert_between(w.intensity.timer, t.peak_ticks_min, t.peak_ticks_max, "3-5 s")
	assert_between(w.intensity.quiet_len, t.quiet_ticks_min, t.quiet_ticks_max, "10-20 s")


func test_the_peak_holds_then_pulls_back() -> void:
	var w := _world()
	var t := w.spawner.intensity
	w.intensity.mode = M.PEAK
	w.intensity.timer = 5
	w.intensity.level = 0
	_tick(w, 4)
	assert_eq(w.intensity.mode, M.PEAK)
	assert_true(Intensity.sending(w), "a peak still sends")
	_tick(w)
	assert_eq(w.intensity.mode, M.PULL_BACK)
	assert_eq(w.intensity.timer, t.pull_back_max_ticks)
	assert_false(Intensity.sending(w), "pulling back sends nothing new")


func test_pull_back_waits_for_few_enemies_near_or_its_timeout() -> void:
	var w := _world()
	var t := w.spawner.intensity
	for k in t.pull_back_enemies + 1:
		w.add_enemy(KIND.CHARGER, Vector2(5, k))
	w.intensity.mode = M.PULL_BACK
	w.intensity.timer = t.pull_back_max_ticks
	w.intensity.quiet_len = 700
	_tick(w, 10)
	assert_eq(w.intensity.mode, M.PULL_BACK, "too many near")
	w.actors.set_pos(1, Vector2(20, 0))
	_tick(w)
	assert_eq(w.intensity.mode, M.QUIET, "few near: quiet")
	assert_eq(w.intensity.timer, 700, "for the length drawn at the peak")
	w.intensity.mode = M.PULL_BACK
	w.actors.set_pos(1, Vector2(5, 0))
	w.intensity.timer = 3
	_tick(w, 3)
	assert_eq(w.intensity.mode, M.QUIET, "or its timeout")


func test_quiet_ends_when_its_time_is_up_and_intensity_is_low() -> void:
	var w := _world()
	var t := w.spawner.intensity
	w.intensity.mode = M.QUIET
	w.intensity.quiet_len = 600
	w.intensity.timer = 600
	w.intensity.level = t.relax_level + 1
	w.add_enemy(KIND.CHARGER, Vector2(1.5, 0))  # close: no drain
	_tick(w, 599)
	assert_eq(w.intensity.mode, M.QUIET)
	_tick(w)
	assert_eq(w.intensity.mode, M.QUIET, "time up but intensity still high")
	w.actors.set_pos(1, Vector2(30, 0))
	w.intensity.level = t.relax_level
	w.intensity.calm = t.calm_ticks
	_tick(w)
	assert_eq(w.intensity.mode, M.BUILD_UP, "time up and relaxed")
	assert_eq(w.intensity.cycle, 1)


func test_quiet_never_runs_past_its_longest() -> void:
	var w := _world()
	var t := w.spawner.intensity
	w.intensity.mode = M.QUIET
	w.intensity.quiet_len = t.quiet_ticks_min
	w.intensity.timer = t.quiet_ticks_min
	w.add_enemy(KIND.CHARGER, Vector2(1.5, 0))
	w.intensity.level = IntensityTable.TOP
	_tick(w, t.quiet_ticks_max - 1)
	assert_eq(w.intensity.mode, M.QUIET)
	_tick(w)
	assert_eq(w.intensity.mode, M.BUILD_UP, "the 20 s end")
	assert_lte(w.intensity.level, t.relax_level + t.close_gain_per_tick, "from relax")


func test_no_new_packs_while_quiet_and_packs_again_after() -> void:
	var w := _world()
	w.intensity.mode = M.QUIET
	w.intensity.quiet_len = 1200
	w.intensity.timer = 1200
	for k in 900:
		w.step(InputFrame.new())
	assert_eq(WaveDirector.enemies_alive(w), 0, "quiet: nothing sent")
	w.intensity.timer = 1
	w.intensity.level = 0
	for k in 60:
		w.step(InputFrame.new())
	assert_eq(w.intensity.mode, M.BUILD_UP)
	assert_gt(WaveDirector.enemies_alive(w), 0, "building up: packs again")


## The same seed sends the same arrivals with and without the director while it builds up (its ramp set to ×1, so
## they arrive on the same ticks): same kinds, HP and power. The ramp only brings the packs sooner.
func test_it_never_changes_what_arrives_or_how_strong() -> void:
	var on := _world(5, true)
	on.spawner.intensity.build_interval_permille = 1000
	var off := _world(5, false)
	for k in 2400:
		on.intensity.level = 0  # held in build-up
		on.step(InputFrame.new())
		off.step(InputFrame.new())
	assert_gt(off.actors.size(), 1)
	assert_eq(on.actors.size(), off.actors.size(), "the same packs")
	for i in range(1, mini(on.actors.size(), off.actors.size())):
		assert_eq(on.actors.kinds[i], off.actors.kinds[i])
		assert_eq(on.actors.max_hp[i], off.actors.max_hp[i])
		assert_eq(on.actors.power[i], off.actors.power[i])


func test_the_draws_come_from_the_seed_and_the_cycle() -> void:
	var lens := {}
	for s in [1, 2, 3, 4, 5, 6]:
		var a := _world(s)
		var b := _world(s)
		for w: World in [a, b]:
			w.intensity.level = IntensityTable.TOP
			w.actors.hp[0] -= 1
			_tick(w, 2)
		assert_eq(a.intensity.timer, b.intensity.timer, "seed %d: replayable" % s)
		assert_eq(a.intensity.quiet_len, b.intensity.quiet_len)
		lens[a.intensity.quiet_len] = true
	assert_gt(lens.size(), 1, "different seeds draw different quiet lengths")


func test_off_without_the_table() -> void:
	var w := _world(11, false)
	assert_true(Intensity.sending(w))
	var h := w.state_hash()
	w.intensity.level = 12345
	w.intensity.mode = M.QUIET
	assert_eq(w.state_hash(), h, "not hashed without the director")
	assert_true(Intensity.sending(w))
	var on := _world(11, true)
	var h2 := on.state_hash()
	on.intensity.level = 12345
	assert_ne(on.state_hash(), h2, "hashed with it")


func test_the_reader_shows_it() -> void:
	var w := _world()
	w.intensity.level = 512345
	w.intensity.mode = M.PEAK
	w.intensity.timer = 120
	var r := WorldReader.new(w)
	assert_true(r.has_intensity())
	assert_eq(r.intensity(), 512)
	assert_eq(r.intensity_mode(), M.PEAK)
	assert_eq(DevPanel.intensity_text(r), "intensity 512 PEAK 2.0 s")
	assert_eq(DevPanel.intensity_text(WorldReader.new(_world(11, false))), "")


func test_the_snapshot_keeps_it_and_an_older_save_starts_building_up() -> void:
	var w := SaveLab.floor_world(3, 1)
	assert_not_null(w.spawner.intensity, "the run's floors have the director")
	SaveLab.run(w, FightBot.new(3), 900)
	w.intensity.mode = M.QUIET
	w.intensity.timer = 77
	var snap := w.to_snapshot()
	var base := SaveLab.floor_world(3, 1)
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.intensity.mode, M.QUIET)
	assert_eq(base.intensity.timer, 77)
	assert_eq(base.state_hash(), w.state_hash())
	var old := w.to_snapshot()
	(old["world"] as Dictionary).erase(&"intensity")
	var base2 := SaveLab.floor_world(3, 1)
	assert_eq(WorldSnapshot.apply(base2, old), "", "a save from before N5 loads")
	assert_eq(base2.intensity.mode, M.BUILD_UP, "and builds up")


func test_the_build_up_ramp_shortens_the_interval_only_while_building() -> void:
	var w := _world()
	var t := w.spawner.intensity
	assert_eq(Intensity.interval(w, 100), SpawnTable.scale(100, t.build_interval_permille))
	w.intensity.mode = M.PEAK
	assert_eq(Intensity.interval(w, 100), 100, "the peak keeps the curve's")
	assert_eq(Intensity.interval(_world(11, false), 100), 100, "off: the curve's")
