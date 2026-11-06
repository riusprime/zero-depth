extends GutTest
## The difficulty curve (v0.4.0 TU, owner 2026-10-08 D1–D4, "distribute presenting them through the first 3
## floors"): phase lookup and the ramp (CurveTable), the calm phase's rules (cap, kinds, no tier growth), the order
## kinds open in, the peak (SC's tier max) and that it holds, the kinds per floor, enemies that join through
## queue_enemy scaled like the spawner's, and the floor's first reward, an altar next to the start hall.
## v0.5.5 EC (owner D1, "Very calm, that fits the first 30 seconds of the first floor then it should ramp a bit
## faster"): floor 1's calm phase lasts 30 s and its ramp to the peak is steeper (60 s, was 84 s); floors 2-3 have
## no calm phase and start at the warm-up level. The peak times are data (starting values), no longer the
## expected-build bot's door times (owner P1).

const KIND := ActorStore.Kind
const CALM: Array[int] = [KIND.CHARGER, KIND.NEEDLE, KIND.SWARMER]
## v0.5.5 D1 (starting values): floor 1's calm phase, its ramp to the peak, and when each floor peaks.
const CALM_S := 30
const FLOOR_1_RAMP_S := 60
const PEAK_S := {1: 90, 2: 30, 3: 30}
const PHASES := {1: 5, 2: 4, 3: 4}
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


## Floor `f`'s peak start in ticks (its curve's last phase).
func _peak(f: int) -> int:
	var c := _table(f).curve
	return c.starts[c.phase_count() - 1]


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


func test_floor_1_is_calm_for_30_s_then_ramps_faster() -> void:
	var t := _table(1)
	var c := t.curve
	assert_eq(c.starts[0], 0)
	assert_eq(c.holds[0], 1, "floor 1 opens with a calm phase that holds")
	assert_eq(c.name_keys[0], &"PHASE_CALM")
	assert_eq(c.starts[1], CALM_S * 60, "D1: the calm phase is the first 30 s")
	for ticks in [0, 900, CALM_S * 60 - 1]:
		assert_eq(t.danger_tier(ticks), 0, "no tier growth in the calm phase")
		assert_eq(t.power_now(ticks), t.power_now(0), "the calm phase's damage holds")
		assert_eq(t.hp_now(100, ticks), t.hp_now(100, 0), "the calm phase's HP holds")
		assert_eq(_open_kinds(t, ticks).size(), CALM.size())
		for k: int in _open_kinds(t, ticks):
			assert_has(CALM, k, "only the calm kinds")
		assert_eq(t.pack_cap_now(ticks), 1, "calm kinds come one at a time (no Swarmer pack)")
	assert_lte(t.power_now(0), 1000, "calm enemies hit no harder than SC's tier 0")
	assert_gt(t.interval_now(0), t.interval(0), "calm spawns come slower than SC's tier 0")
	assert_between(t.cap_now(1, 0), 4, 6, "floor 1's calm cap is 4-6")
	var ramp := c.starts[c.phase_count() - 1] - c.starts[1]
	assert_eq(ramp, FLOOR_1_RAMP_S * 60, "D1: the ramp to the peak takes 60 s")
	assert_lt(ramp, 84 * 60, "steeper than v0.4.0's 84 s ramp to the same peak")


func test_floors_2_and_3_start_at_the_warm_up_level() -> void:
	var one := _table(1).curve
	for f in [2, 3]:
		var t := _table(f)
		var c := t.curve
		assert_eq(c.starts[0], 0)
		assert_eq(c.holds[0], 0, "floor %d: no calm phase" % f)
		assert_ne(c.name_keys[0], &"PHASE_CALM", "floor %d: no calm phase" % f)
		assert_eq(c.name_keys[0], one.name_keys[1], "floor %d opens at the warm-up phase" % f)
		assert_eq(
			[c.tier_permille[0], c.interval_permille[0], c.hp_permille[0], c.damage_permille[0]],
			[
				one.tier_permille[1],
				one.interval_permille[1],
				one.hp_permille[1],
				one.damage_permille[1]
			],
			"floor %d starts at floor 1's warm-up level" % f
		)
		assert_gt(t.danger_permille(600), 0, "floor %d: the tier grows from the start" % f)
		for k: int in CALM:
			assert_has(_open_kinds(t, 0), k, "floor %d: the basic kinds are in from the start" % f)
	assert_gt(
		_table(2).cap_now(2, 0), _table(1).cap_now(1, 0), "floor 2 starts higher than floor 1"
	)
	assert_gte(
		_table(3).cap_now(3, 0), _table(2).cap_now(2, 0), "floor 3 starts no lower than floor 2"
	)
	assert_lt(_table(3).cap_now(3, 0), _table(3).cap(3, 0), "but still under SC's tier 0")


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
		assert_eq(c.phase_count(), PHASES[f])


func test_the_peak_comes_on_time_and_holds() -> void:
	var sc: SpawnDirectorDefinition = _repo.get_def(&"spawning", &"floor_1")
	var tier_max := sc.hp_tier_permille.size() - 1
	for f in [1, 2, 3]:
		var t := _table(f)
		var c := t.curve
		var peak := c.starts[c.phase_count() - 1]
		assert_eq(peak, PEAK_S[f] * 60, "floor %d: the peak's start (data, D1)" % f)
		var top := [
			t.danger_permille(peak), t.cap_now(f, peak), t.hp_now(100, peak), t.power_now(peak)
		]
		assert_between(t.danger_tier(peak), 1, tier_max, "within SC's tables")
		for ticks in [peak + 600, 5399]:  # v0.9.5 DC: it holds until the overtime (90 s)
			if ticks <= peak or ticks >= 5400:
				continue
			assert_eq(
				[
					t.danger_permille(ticks),
					t.cap_now(f, ticks),
					t.hp_now(100, ticks),
					t.power_now(ticks)
				],
				top,
				"floor %d: the peak holds" % f
			)
		var last := [0, 0, 0, 0]
		for ticks in range(0, peak + 1, 300):
			var now := [
				t.danger_permille(ticks),
				t.cap_now(f, ticks),
				t.hp_now(100, ticks),
				t.power_now(ticks)
			]
			for k in 4:
				assert_gte(now[k], last[k], "floor %d: never easier on the way up" % f)
				assert_lte(now[k], top[k], "floor %d: the peak is the most" % f)
			last = now


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
	for ticks in range(0, _peak(1) * 2, 300):
		for k: int in _open_kinds(t, ticks):
			assert_does_not_have(later, k)
	# And in play: the last 2 min before the peak of the real floor 1 with an invulnerable player, every enemy
	# that appears (checked each second).
	w.actors.invuln[0] = 1 << 24
	w.run_ticks = _peak(1)
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
	w.run_ticks = _peak(1)
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
	assert_almost_eq(r.phase_seconds_left(), float(CALM_S), 0.02)
	w.run_ticks = _peak(1)
	assert_eq(r.phase(), r.phase_count() - 1)
	assert_eq(r.phase_name_key(), &"PHASE_PEAK")
	assert_eq(r.phase_seconds_left(), 0.0)


# --- v0.9.5 DC (owner: "aim to a 10 minutes max per floor"): the danger tier keeps rising past the peak -------------


func _at_s(t: SpawnTable, seconds: float) -> int:
	return t.danger_tier(SimTick.seconds_to_ticks(seconds))


func test_the_overtime_tier_schedule_on_floors_1_2_and_5() -> void:
	var want := {
		89.0: 3,
		90.0: 4,
		150.0: 5,
		239.0: 5,
		240.0: 6,
		600.0: 10,
		629.0: 10,
		630.0: 11,
		900.0: 20,
		1200.0: 20,
	}  # gdlint: disable=max-line-length
	for f in [1, 2, 5]:
		var t := _table(f)
		for s: float in want:
			assert_eq(_at_s(t, s), want[s], "floor %d at %d s" % [f, int(s)])
		var last := 0
		for s in range(0, 1300, 5):
			var tier := _at_s(t, float(s))
			assert_gte(tier, last, "floor %d: the tier never falls (%d s)" % [f, s])
			last = tier


func test_the_overtime_grows_the_cap_and_shortens_the_interval() -> void:
	var t := _table(3)
	var t3 := SimTick.seconds_to_ticks(80.0)
	var t10 := SimTick.seconds_to_ticks(600.0)
	assert_eq(t.danger_tier(t3), 3)
	var base_cap := SpawnTable.scale(t.cap(3, 10), t.curve.cap_permille_at(t10))
	assert_eq(
		t.cap_now(3, t10),
		SpawnTable.scale(base_cap, 1400),
		"cap x(1 + 0.08 x 7) at tier 10, held at the x1.4 ceiling (v0.9.5: tier 8 on)"
	)
	assert_gt(t.cap_now(3, t10), t.cap_now(3, SimTick.seconds_to_ticks(89.0)))
	var base_iv := maxi(1, SpawnTable.scale(t.interval(10), t.curve.interval_permille_at(t10)))
	assert_lte(t.interval_now(t10), base_iv)
	for s in range(90, 1300, 30):
		assert_gte(t.interval_now(SimTick.seconds_to_ticks(float(s))), 48, "never below 0.8 s")
	assert_eq(t.curve.overtime_interval(1000, 20), 320, "x(1 - 0.04 x 17)")
	assert_eq(t.curve.overtime_interval(100, 20), 48, "32 is under the floor")
	assert_eq(t.curve.overtime_interval(60, 20), 48, "the 0.8 s floor")
	assert_eq(t.curve.overtime_interval(40, 20), 48, "the floor holds from tier 4 on")
	assert_eq(t.curve.overtime_interval(1000, 3), 1000, "no change at tier 3")
	assert_eq(t.curve.cap_bonus_permille(3), 1000)
	assert_eq(t.curve.cap_bonus_permille(7), 1320, "x(1 + 0.08 x 4) under the ceiling")
	assert_eq(t.curve.cap_bonus_permille(8), 1400, "the ceiling")
	assert_eq(
		t.curve.cap_bonus_permille(20),
		1400,
		"held: more danger comes from the tier tables, not more enemies"
	)


func test_the_overtime_bumps_the_pack_cap_at_tiers_6_10_and_15() -> void:
	var t := _table(1)
	var base := t.curve.pack_cap[t.curve.phase_count() - 1]
	assert_gt(base, 0)
	var seen := {}
	for s in range(60, 1000, 10):
		seen[s] = t.pack_cap_now(SimTick.seconds_to_ticks(float(s)))
	assert_eq(seen[80], base, "tier 3")
	assert_eq(seen[330], base + 1, "tier 7 (6 reached)")
	assert_eq(seen[240], base + 1, "tier 6")
	assert_eq(seen[150], base, "tier 5")
	assert_eq(seen[600], base + 2, "tier 10")
	assert_eq(seen[510], base + 1, "tier 9")

	assert_eq(seen[740], base + 2, "tier 14")
	assert_eq(seen[750], base + 3, "tier 15")


func test_a_floor_resumes_the_overtime_tier_from_a_save() -> void:
	var w := SaveLab.floor_world(4109, 3)
	w.run_ticks = SimTick.seconds_to_ticks(360.0)
	assert_eq(w.spawner.danger_tier(w.run_ticks), 7, "6:00 is tier 7")
	var snap := WorldSnapshot.take(w, PackedStringArray())
	var r := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), SaveLab.floor_world(4109, 3))
	assert_not_null(r)
	if r == null:
		return
	assert_eq(r.run_ticks, w.run_ticks)
	assert_eq(r.spawner.danger_tier(r.run_ticks), 7, "the save resumes tier 7")
	assert_eq(r.state_hash(), w.state_hash())
