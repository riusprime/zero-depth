extends GutTest
## v0.10.5 O4 (owner D46, "it feels overcrowded if you are weak, could we also adjust it to not make it unfair based
## on the strength?" → "Read your state live"): the intensity director reads the hero every tick. STRUGGLING (HP under
## 40 %, or kills in the last ~10 s of fighting under half the expected with enemies out) → a lower peak that runs
## out faster, a quiet 50 % longer and packs one smaller; STRONG (HP over 70 % and at least the expected kills) and
## BETWEEN → as before. The kill window is saved with the world.

const LONG := 1 << 24
const KIND := ActorStore.Kind
const M := IntensityState.Mode
const S := IntensityState.Standing


func _repo() -> ContentRepository:
	return SharedContent.repo()


## A wall-less world with the real enemies, a ring of spawn points at 9 m and the shipped spawner and director.
func _world(seed_value: int = 11) -> World:
	var repo := _repo()
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	for k in 8:
		w.spawn_points.append(Kin.dir(k * 512) * 9.0)
	w.spawner = ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo)
	w.spawner.intensity = IntensityCompiler.compile(repo.get_def(&"intensity", &"director"))
	w.actors.invuln[0] = LONG
	return w


func _tick(w: World, n: int = 1) -> void:
	for k in n:
		Intensity.advance(w)
		w.tick += 1


func _standing(w: World) -> int:
	return Intensity.read_standing(w, w.spawner.intensity, w.intensity)


## A full window of fighting counted, holding `kills`.
func _full_window(w: World, kills: int) -> void:
	w.intensity.kill_ring.resize(IntensityState.KILL_SLOTS)
	w.intensity.kill_ring.fill(0)
	w.intensity.kill_ring[0] = kills
	w.intensity.ring_ticks = IntensityState.KILL_SLOTS * SimTick.TICKS_PER_SECOND


func _set_hp_permille(w: World, permille: int) -> void:
	w.actors.hp[0] = w.actors.max_hp[0] * permille / 1000


func test_the_shipped_starting_values() -> void:
	# A copy: get_def() hands out the cached shared resource, and the edit below must not leak to other tests.
	var def: IntensityDirectorDefinition = _repo().get_def(&"intensity", &"director").duplicate()
	assert_eq(def.validate(), [] as Array[ValidationIssue])
	var t := IntensityCompiler.compile(def)
	assert_eq([t.struggle_hp_permille, t.strong_hp_permille], [400, 700])
	assert_eq([t.expected_kill_permille, t.slow_kill_permille, t.slow_min_alive], [200, 500, 4])
	assert_eq([t.struggle_peak_level, t.struggle_peak_speed], [600000, 2])
	assert_eq([t.struggle_quiet_permille, t.struggle_pack_cut], [1500, 1])
	def.struggle_peak_intensity = def.peak_intensity + 1
	var codes := []
	for i in def.validate():
		codes.append(String(i.code))
	assert_has(codes, "intensity_order", "a struggling peak never above the normal one")


func test_low_hp_struggles_high_hp_is_strong_and_between_is_neither() -> void:
	var w := _world()
	_set_hp_permille(w, 390)
	assert_eq(_standing(w), S.STRUGGLING, "under 40 %")
	_set_hp_permille(w, 550)
	assert_eq(_standing(w), S.BETWEEN)
	_set_hp_permille(w, 710)
	assert_eq(_standing(w), S.STRONG, "over 70 %, before a full window: HP alone")


func test_a_slow_kill_rate_struggles_only_with_enemies_out() -> void:
	var w := _world()
	var t := w.spawner.intensity
	t.expected_kill_permille = 1000  # the cap's worth in the window, so half of it is a whole number of kills
	_full_window(w, 0)
	assert_eq(_standing(w), S.BETWEEN, "no enemies out: not slow, but not strong either")
	for k in t.slow_min_alive:
		w.add_enemy(KIND.CHARGER, Vector2(20, k))
	assert_eq(_standing(w), S.STRUGGLING, "enemies out and no kills")
	var expected := w.spawner.cap_now(w.floor_index, w.run_ticks)
	_full_window(w, expected)
	assert_eq(_standing(w), S.STRONG, "the expected kills and full HP")
	_full_window(w, (expected + 1) / 2)
	assert_eq(_standing(w), S.BETWEEN, "half the expected: not slow")


func test_the_window_counts_kills_per_second_outside_the_quiet() -> void:
	var w := _world()
	_tick(w)  # the first read syncs
	w.kills += 3
	_tick(w)
	assert_eq(w.intensity.window_kills(), 3)
	w.intensity.mode = M.QUIET
	w.intensity.timer = LONG
	w.kills += 5
	_tick(w)
	assert_eq(w.intensity.window_kills(), 3, "a quiet's kills don't count")
	w.intensity.mode = M.BUILD_UP
	w.tick += 7  # a gap (an arena): its kills don't count
	w.kills += 4
	_tick(w)
	assert_eq(w.intensity.window_kills(), 3)
	_tick(w, IntensityState.KILL_SLOTS * SimTick.TICKS_PER_SECOND)
	assert_eq(w.intensity.window_kills(), 0, "10 s of fighting later the slot is gone")


func test_a_struggling_hero_peaks_lower_and_its_peak_ends_sooner() -> void:
	var t := _world().spawner.intensity
	for weak: bool in [false, true]:
		var w := _world()
		_set_hp_permille(w, 300 if weak else 1000)
		w.intensity.last_hp = w.actors.hp[0]
		w.intensity.level = t.struggle_peak_level
		_tick(w)
		assert_eq(w.intensity.mode, M.PEAK if weak else M.BUILD_UP, "weak %s" % weak)
	var w := _world()
	_set_hp_permille(w, 300)
	w.intensity.last_hp = w.actors.hp[0]
	w.intensity.mode = M.PEAK
	w.intensity.timer = 10
	_tick(w, 5)
	assert_eq(w.intensity.mode, M.PULL_BACK, "the peak's clock runs twice as fast")


func test_a_quiet_begun_while_struggling_is_longer() -> void:
	var t := _world().spawner.intensity
	for weak: bool in [false, true]:
		var w := _world()
		_set_hp_permille(w, 300 if weak else 1000)
		w.intensity.last_hp = w.actors.hp[0]
		w.intensity.mode = M.PULL_BACK
		w.intensity.timer = 1
		w.intensity.quiet_len = 800
		_tick(w)
		assert_eq(w.intensity.mode, M.QUIET)
		var want := SpawnTable.scale(800, t.struggle_quiet_permille) if weak else 800
		assert_eq(w.intensity.timer, want, "weak %s" % weak)
		assert_eq(w.intensity.quiet_len, want)


func test_a_struggling_hero_gets_packs_one_smaller() -> void:
	var w := _world()
	var sp := w.spawner
	var drawn := -1
	var fixed := -1
	for k in sp.kinds.size():
		var p := sp.packs[k] if k < sp.packs.size() else 0
		if p > 1 and fixed < 0:
			fixed = k
		if p <= 0 and drawn < 0:
			drawn = k
	var top := sp.pack_max(w.floor_index)
	w.intensity.standing = S.STRONG
	assert_eq(Intensity.pack_size(w, sp, drawn, top), top, "strong: as before")
	w.intensity.standing = S.STRUGGLING
	assert_eq(
		Intensity.pack_size(w, sp, drawn, top), maxi(1, top - 1), "the largest pack, one smaller"
	)
	assert_eq(Intensity.pack_size(w, sp, drawn, 1), 1, "never below 1")
	if fixed >= 0:
		assert_eq(
			Intensity.pack_size(w, sp, fixed, sp.packs[fixed]),
			sp.packs[fixed] - 1,
			"a fixed pack too"
		)
	sp.intensity = null
	assert_eq(Intensity.pack_size(w, sp, drawn, top), top, "off without the director")


func test_the_snapshot_keeps_the_window_and_an_older_save_reads_afresh() -> void:
	var w := SaveLab.floor_world(3, 1)
	SaveLab.run(w, FightBot.new(3), 900)
	_full_window(w, 4)
	w.intensity.standing = S.STRUGGLING
	var snap := w.to_snapshot()
	var base := SaveLab.floor_world(3, 1)
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.intensity.window_kills(), 4)
	assert_eq(base.intensity.ring_ticks, w.intensity.ring_ticks)
	assert_eq(base.intensity.standing, S.STRUGGLING)
	assert_eq(base.state_hash(), w.state_hash())
	var old := w.to_snapshot()
	var it: Dictionary = (old["world"] as Dictionary)[&"intensity"]
	for f in [&"kill_ring", &"kill_seen", &"ring_ticks", &"standing"]:
		it.erase(f)
		it.erase(String(f))
	var base2 := SaveLab.floor_world(3, 1)
	assert_eq(WorldSnapshot.apply(base2, old), "", "a save from before O4 loads")
	assert_eq(base2.intensity.kill_ring.size(), 0, "with no window")
	Intensity.count_kills(base2, base2.intensity, true)
	assert_eq(
		base2.intensity.window_kills(),
		0,
		"the first read syncs: the run's earlier kills don't count"
	)
	assert_eq(base2.intensity.kill_seen, base2.kills)
