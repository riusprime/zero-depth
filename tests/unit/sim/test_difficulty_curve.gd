extends GutTest
## The difficulty curve (v0.4.0 TU, owner 2026-10-08 D1–D4, "distribute presenting them through the first 3
## floors"): phase lookup and the ramp (CurveTable), the calm minute's rules (cap, kinds, no tier growth), the order
## kinds open in, the peak (SC's tier max) at the floor's expected end, the kinds per floor, enemies that join through
## queue_enemy scaled like the spawner's, and the floor's first reward, an altar next to the start hall.

const KIND := ActorStore.Kind
const CALM: Array[int] = [KIND.CHARGER, KIND.NEEDLE, KIND.SWARMER]
## The kinds each floor brings into the run (owner, 2026-10-08), and the calm minute's on every floor.
const NEW_BY_FLOOR := {
	1: [KIND.CHARGER, KIND.NEEDLE, KIND.SWARMER, KIND.WARDEN, KIND.ARC_CASTER, KIND.SPLITTER],
	2: [KIND.SHIELD_BEARER, KIND.BOMB_DRONE, KIND.MINE_LAYER],
	3: [KIND.MENDER, KIND.SNIPER],
}

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _table(floor_index: int) -> SpawnTable:
	return ContentCompiler.compile_floor_spawning(_repo, floor_index)


## The mix rows open at `ticks`, as actor kinds.
func _open_kinds(t: SpawnTable, ticks: int) -> Array:
	var out := []
	for k in t.kinds.size():
		if t.row_open(k, ticks):
			out.append(t.kinds[k])
	return out


func test_phase_lookup_and_the_ramp() -> void:
	var c := CurveTable.new()
	c.starts = PackedInt32Array([0, 600, 1200])
	c.tier_permille = PackedInt32Array([0, 2000, 4000])
	c.cap_permille = PackedInt32Array([300, 500, 1000])
	c.interval_permille = PackedInt32Array([2000, 1500, 1000])
	c.hp_permille = PackedInt32Array([500, 700, 1000])
	c.damage_permille = PackedInt32Array([500, 800, 1000])
	c.pack_cap = PackedInt32Array([1, 2, 0])
	c.holds = PackedByteArray([1, 0, 0])
	c.name_keys = [&"A", &"B", &"C"]
	assert_eq([c.phase_at(0), c.phase_at(599), c.phase_at(600), c.phase_at(99999)], [0, 0, 1, 2])
	assert_eq(
		[c.tier_permille_at(0), c.tier_permille_at(599)], [0, 0], "a holding phase keeps its values"
	)
	assert_eq(c.cap_permille_at(599), 300)
	assert_eq(c.tier_permille_at(900), 3000, "halfway through a ramping phase")
	assert_eq(c.interval_permille_at(900), 1250)
	assert_eq(c.hp_permille_at(900), 850)
	assert_eq(c.tier_permille_at(5000), 4000, "the peak holds")
	assert_eq([c.pack_cap_at(0), c.pack_cap_at(700), c.pack_cap_at(2000)], [1, 2, 0])
	assert_eq([c.ticks_to_next(100), c.ticks_to_next(1300)], [500, 0])


func test_every_floor_has_a_curve_and_the_run_uses_it() -> void:
	for f in [1, 2, 3]:
		var t := _table(f)
		assert_not_null(t.curve, "floor %d has a curve" % f)
		assert_eq(t.curve.kind_phase.size(), t.kinds.size())


func test_the_calm_minute() -> void:
	for f in [1, 2, 3]:
		var t := _table(f)
		var c := t.curve
		assert_eq(c.starts[0], 0)
		assert_eq(c.starts[1], 3600, "floor %d: the calm phase is the first minute" % f)
		for ticks in [0, 1800, 3599]:
			assert_eq(t.danger_tier(ticks), 0, "no tier growth in the calm minute")
			assert_eq(t.power_now(ticks), t.power_now(0), "the calm minute's damage holds")
			assert_eq(t.hp_now(100, ticks), t.hp_now(100, 0), "the calm minute's HP holds")
			assert_eq(_open_kinds(t, ticks).size(), CALM.size())
			for k: int in _open_kinds(t, ticks):
				assert_has(CALM, k, "floor %d: only the calm kinds" % f)
			assert_eq(t.pack_cap_now(ticks), 1, "calm kinds come one at a time (no Swarmer pack)")
		assert_lte(t.power_now(0), 1000, "calm enemies hit no harder than SC's tier 0")
		assert_gt(t.interval_now(0), t.interval(0), "calm spawns come slower than SC's tier 0")
	assert_between(_table(1).cap_now(1, 0), 4, 6, "floor 1's calm cap is 4-6")
	assert_gt(
		_table(2).cap_now(2, 0), _table(1).cap_now(1, 0), "floor 2 starts higher than floor 1"
	)
	assert_gt(
		_table(3).cap_now(3, 0), _table(2).cap_now(2, 0), "floor 3 starts higher than floor 2"
	)
	assert_lt(_table(3).cap_now(3, 0), _table(3).cap(3, 0), "but still calmer than SC's tier 0")


func test_kinds_open_phase_by_phase_and_never_close() -> void:
	for f in [1, 2, 3]:
		var t := _table(f)
		var c := t.curve
		var before := []
		for p in c.phase_count():
			var now := _open_kinds(t, c.starts[p])
			for k: int in before:
				assert_has(now, k, "floor %d phase %d keeps the kinds before it" % [f, p])
			assert_eq(_open_kinds(t, c.starts[p] - 1 if p > 0 else 0), before if p > 0 else now)
			before = now
		assert_eq(c.phase_count(), 5)


func test_the_peak_is_sc_s_tier_max_at_the_floor_s_end() -> void:
	var sc: SpawnDirectorDefinition = _repo.get_def(&"spawning", &"floor_1")
	var tier_max := sc.hp_tier_permille.size() - 1
	for f in [1, 2, 3]:
		var t := _table(f)
		var c := t.curve
		var peak := c.starts[c.phase_count() - 1]
		assert_eq(
			peak, TuningRun.EXPECTED_END_TICKS, "floor %d peaks at the floor's expected end" % f
		)
		for ticks in [peak, peak + 36000]:
			assert_eq(t.danger_tier(ticks), tier_max, "the peak is SC's tier max, and it holds")
			assert_eq(t.cap_now(f, ticks), t.cap(f, tier_max))
			assert_eq(t.interval_now(ticks), t.interval(tier_max))
			assert_eq(t.hp_now(100, ticks), t.scaled_hp(100, tier_max))
			assert_eq(t.power_now(ticks), t.damage_permille(tier_max))
		var last := 0
		for ticks in range(0, peak + 1, 600):
			assert_gte(t.danger_permille(ticks), last, "the danger never falls on the way up")
			last = t.danger_permille(ticks)


func test_kinds_are_introduced_across_the_three_floors() -> void:
	var seen := {}
	for f in [1, 2, 3]:
		var t := _table(f)
		var all := _open_kinds(t, 1 << 24)
		for k: int in NEW_BY_FLOOR[f]:
			assert_has(all, k, "floor %d brings kind %d" % [f, k])
			seen[k] = true
		for k: int in all:
			assert_true(
				seen.has(k), "floor %d: kind %d comes from this floor or one before" % [f, k]
			)
		var news := Array(t.curve.new_kinds)
		news.sort()
		var want: Array = NEW_BY_FLOOR[f].duplicate()
		want.sort()
		assert_eq(news, want, "floor %d announces its new kinds" % f)


func test_floor_1_never_spawns_a_later_floor_s_kind() -> void:
	var w := RunLab.new(_repo, 4242, &"blade").floor_world()
	var later := NEW_BY_FLOOR[2] + NEW_BY_FLOOR[3]
	var t := w.spawner
	for ticks in range(0, TuningRun.EXPECTED_END_TICKS * 2, 300):
		for k: int in _open_kinds(t, ticks):
			assert_does_not_have(later, k)
	# And in play: the last 2 min before the peak of the real floor 1 with an invulnerable player, every enemy
	# that appears (checked each second).
	w.actors.invuln[0] = 1 << 24
	w.run_ticks = TuningRun.EXPECTED_END_TICKS - 2 * 3600
	var kinds := {}
	for n in 2 * 3600:
		w.step(InputFrame.new())
		if n % 60 == 0:
			for i in range(1, w.actors.size()):
				kinds[w.actors.kinds[i]] = true
	assert_gt(kinds.size(), 3, "the floor's kinds came")
	for k: int in kinds:
		assert_does_not_have(later, k, "floor 1 spawned a later floor's kind")


func test_enemies_that_join_through_queue_enemy_get_the_tier_scaling() -> void:
	var w := CombatLab.world()
	w.spawner = ContentCompiler.compile_spawning(_repo.get_def(&"spawning", &"floor_1"), _repo)
	w.spawner.cap_by_floor = PackedInt32Array([0])
	w.spawner.cap_per_tier = 0  # no spawner packs: only the queued ones
	w.run_ticks = w.spawner.tier_ticks * 5
	w.queue_enemy(KIND.SPLITLING, Vector2(8, 0))
	w.queue_enemy(KIND.HATCHLING, Vector2(-8, 0))
	w.step(InputFrame.new())
	var tier := w.spawner.danger_tier(w.run_ticks)
	assert_eq(tier, 5)
	for kind in [KIND.SPLITLING, KIND.HATCHLING]:
		var i := -1
		for k in range(1, w.actors.size()):
			if w.actors.kinds[k] == kind:
				i = k
		assert_gte(i, 0)
		var want := w.spawner.scaled_hp(w.enemy_table(kind).hp, tier)
		assert_gt(want, w.enemy_table(kind).hp)
		assert_eq([w.actors.max_hp[i], w.actors.hp[i]], [want, want], "kind %d: tier HP" % kind)
		assert_eq(w.actors.power[i], w.spawner.damage_permille(tier), "kind %d: tier damage" % kind)


func test_a_splitter_s_splitlings_arrive_scaled_on_a_curved_floor() -> void:
	var w := CombatLab.world()
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	w.spawner = _table(1)
	w.spawner.cap_by_floor = PackedInt32Array([0])
	w.spawner.cap_per_tier = 0
	w.run_ticks = TuningRun.EXPECTED_END_TICKS
	var id := w.add_enemy(KIND.SPLITTER, Vector2(8, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	var i := w.actors.index_of(id)
	Damage.hit(w, i, 100000, 1, 1, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i))
	CombatLab.idle(w, 2)
	var lings := 0
	for k in range(1, w.actors.size()):
		if w.actors.kinds[k] == KIND.SPLITLING and w.actors.dead[k] == 0:
			lings += 1
			var want := w.spawner.hp_now(w.enemy_table(KIND.SPLITLING).hp, w.run_ticks - 2)
			assert_almost_eq(
				w.actors.max_hp[k], want, 1, "a Splitling at the peak has the peak's HP"
			)
	assert_eq(lings, 2)


func test_the_first_reward_is_an_altar_next_to_the_start_hall() -> void:
	for s in 8:
		var w := RunLab.new(_repo, 5100 + s, &"blade").floor_world()
		var f := w.floor_layout
		var best := 1 << 20
		for r in f.room_count():
			if r != f.start_room and r != f.boss_room:
				best = mini(best, f.hops[r])
		var near_altar := false
		for i in w.rewards.size():
			var room := f.room_of(w.rewards.pos(i))
			if w.rewards.kind[i] == RewardStore.Kind.ALTAR and room >= 0 and f.hops[room] == 1:
				near_altar = true
		assert_true(
			near_altar, "seed %d: a free altar in a room next to the start hall" % (5100 + s)
		)
		assert_eq(best, 1)


func test_the_reader_names_the_phase() -> void:
	var w := RunLab.new(_repo, 4243, &"gun").floor_world()
	var r := WorldReader.new(w)
	assert_true(r.has_curve())
	assert_eq([r.phase(), r.phase_name_key(), r.tier()], [0, &"PHASE_CALM", 0])
	assert_almost_eq(r.phase_seconds_left(), 60.0, 0.02)
	w.run_ticks = TuningRun.EXPECTED_END_TICKS
	assert_eq(r.phase(), r.phase_count() - 1)
	assert_eq(r.phase_name_key(), &"PHASE_PEAK")
	assert_eq(r.phase_seconds_left(), 0.0)
