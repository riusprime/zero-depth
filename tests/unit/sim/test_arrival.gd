extends GutTest
## v0.8.0 N11 (owner O69: "the spawning enemies would be paused, right? And there would be no main character yet";
## "Nothing spawns until you land"): every run floor opens with the hero's arrival on its receiver, in ticks (EI-03),
## its length data (SimTuning's arrival_*; floor 1 of a run 4.0 s since v0.9.0 SA, Q16; later floors ~0.8 s, reduced
## motion 0.3 s). While it plays no input acts, nothing spawns, the hero can't be hit, the enemies already placed don't
## act and the run's clock waits; it ends on its tick and play starts. It is saved and hashed: a save made
## mid-arrival resumes the rest of it, an older save (no arrival in it) resumes with none.

const SEED := 20261017
## v0.9.0 SA (owner Q16: "4.0 s"): floor 1 of a run's arrival, on the altar (was 96, 1.6 s).
const FIRST := 240


func _move(dir: Vector2, buttons: int = 0) -> InputFrame:
	return InputFrame.make(
		Vector2i(roundi(dir.x * SimTick.MOVE_MAX), roundi(dir.y * SimTick.MOVE_MAX)),
		Kin.angle_of(dir),
		1000,
		buttons,
		buttons
	)


## Floor `floor_index` of a run as Main builds it, then the arrival Main gives it (floor 1 the long one).
func _arriving(floor_index: int, calm: bool = false) -> World:
	var w := SaveLab.floor_world(SEED, floor_index)
	w.tuning = RunContentCompiler.compile_sim_tuning(
		ContentRepository.load_all().get_def(&"tuning", &"sim")
	)
	w.boss_flow.set_transit(
		calm, true, BossFlow.arrival_length(w.tuning, calm, w.run_floor_index() == 1)
	)
	return w


func _enemies(w: World) -> int:
	var n := 0
	for i in range(1, w.actors.size()):
		if EnemyAi.is_enemy_kind(w.actors.kinds[i]) and w.actors.dead[i] == 0:
			n += 1
	return n


func test_the_lengths_are_data_floor_one_longest() -> void:
	var t := RunContentCompiler.compile_sim_tuning(
		ContentRepository.load_all().get_def(&"tuning", &"sim")
	)
	assert_eq(BossFlow.arrival_length(t, false, true), FIRST, "floor 1 of a run: 4.0 s")
	assert_eq(BossFlow.arrival_length(t, false, false), 48, "a later floor: 0.8 s")
	assert_eq(BossFlow.arrival_length(t, true, true), 18, "reduced motion: 0.3 s")
	assert_eq(BossFlow.arrival_length(t, true, false), 18)
	t.arrival_first_ticks = 30
	assert_eq(BossFlow.arrival_length(t, false, true), 30, "the tuning sets it")
	var w := _arriving(1)
	assert_eq(w.boss_flow.arrive_ticks, FIRST)
	assert_true(WorldReader.new(w).arriving())
	assert_true(WorldReader.new(w).arrival_first(), "floor 1's is the big landing")
	assert_false(WorldReader.new(_arriving(2)).arrival_first(), "floor 2's is the step-out")


func test_nothing_spawns_nothing_acts_until_the_hero_lands() -> void:
	var w := _arriving(1)
	var reader := WorldReader.new(w)
	assert_not_null(w.spawner, "the floor has the horde's director")
	# An enemy already on the floor beside the hero, and a hostile shot about to hit it.
	var kind: int = w.enemy_tables.keys()[0]
	var near := w.player_pos() + Vector2(1.6, 0.0)
	var id := w.add_enemy(kind, near)
	var ei := w.actors.index_of(id)
	w.actors.invuln[ei] = 0
	var shot_at := w.player_pos() + Vector2(-0.8, 0.0)
	w.projectiles.add(
		w.take_id(),
		id,
		ActorStore.TEAM_ENEMY,
		shot_at,
		Vector2(0.2, 0.0),
		0.2,
		120,
		10,
		SimEvent.TAG_PROJECTILE,
		0
	)
	var hp := w.actors.hp[0]
	var actors0 := w.actors.size()
	var seq := w.last_event_seq()
	var at := w.player_pos()
	var busy := _move(
		Vector2(1, 0),
		InputFrame.PRIMARY | InputFrame.DASH | InputFrame.UTILITY | InputFrame.INTERACT
	)
	for k in FIRST:
		assert_true(reader.arriving(), "still arriving on tick %d" % k)
		w.step(busy)
		assert_eq(w.player_pos(), at, "no input moves the hero (tick %d)" % k)
	assert_eq(w.actors.hp[0], hp, "the hero wasn't hit")
	assert_eq(w.actors.pos(w.actors.index_of(id)), near, "the enemy already there didn't act")
	assert_eq(w.projectiles.size(), 1, "the shot hangs where it was")
	assert_eq(w.actors.size(), actors0, "nothing spawned")
	assert_eq(w.last_event_seq(), seq, "nothing happened at all")
	assert_eq(w.run_ticks, 0, "the run's clock waited")
	assert_eq(w.dash_ticks_left, 0, "no dash")
	assert_eq(w.swing_t, 0, "no swing")
	assert_eq(w.tick, FIRST, "the ticks counted")
	assert_false(reader.arriving(), "the arrival ends on its tick")
	assert_eq(reader.arrival_progress(), -1.0)
	# Play starts: the stick moves the hero, the floor's clock runs and the horde comes.
	for k in 10:
		w.step(_move(Vector2(1, 0)))
	assert_ne(w.player_pos(), at, "the stick moves the hero now")
	assert_gt(w.run_ticks, 0, "the clock runs")
	var arrived := CombatLab.until(w, func(x: World) -> bool: return _enemies(x) > 1, 1800)
	assert_gte(arrived, 0, "enemies spawn once the hero landed")


func test_later_floors_and_reduced_motion_end_on_time() -> void:
	for c: Array in [[2, false, 48], [1, true, 18], [3, true, 18]]:
		var w := _arriving(c[0], c[1])
		var reader := WorldReader.new(w)
		var used := CombatLab.until(
			w, func(x: World) -> bool: return not x.boss_flow.holds_world(), 200
		)
		assert_eq(used, c[2], "floor %d calm %s: %d ticks" % c)
		assert_false(reader.arriving())


func test_a_save_mid_arrival_resumes_the_rest_of_it() -> void:
	var w := _arriving(1)
	CombatLab.idle(w, 40)
	var snap := WorldSnapshot.take(w)
	var base := _arriving(1)
	assert_eq(WorldSnapshot.apply(base, snap), "", "the snapshot fits")
	assert_eq(base.state_hash(), w.state_hash(), "restored exactly")
	assert_eq(base.boss_flow.arrive_left, FIRST - 40, "the rest of it left")
	var frame := _move(Vector2(0, 1), InputFrame.PRIMARY)
	for k in FIRST:
		w.step(frame)
		base.step(frame)
	assert_eq(base.state_hash(), w.state_hash(), "the same play after it")
	assert_false(base.boss_flow.holds_world())


func test_an_older_save_without_an_arrival_resumes_with_none() -> void:
	var old := SaveLab.floor_world(SEED, 1)  # floor 1 before N11: no arrival
	assert_false(old.boss_flow.holds_world())
	CombatLab.idle(old, 5)
	var base := _arriving(1)
	assert_true(base.boss_flow.holds_world())
	assert_eq(WorldSnapshot.apply(base, WorldSnapshot.take(old)), "")
	assert_false(base.boss_flow.holds_world(), "no arrival in it: play goes on at once")
	var at := base.player_pos()
	for k in 10:
		base.step(_move(Vector2(1, 0)))
	assert_ne(base.player_pos(), at)


func test_the_arrival_is_hashed_and_deterministic() -> void:
	var a := SaveLab.floor_world(SEED, 1)
	var b := _arriving(1)
	b.tuning = a.tuning
	assert_ne(a.state_hash(), b.state_hash(), "the arrival is part of the state")
	var hashes: Array[String] = []
	for k in 2:
		var w := _arriving(1)
		for t in 200:
			w.step(_move(Vector2(1, 1)))
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1], "same seed, same arrival, same play")


## v0.8.0 N11 fix (test_e2e_wand_build's Swap at eight slots): a card that needs the Swap, given while the hero is still
## arriving (the dev panel's grant lands between ticks, even at tick 0), never stops the arrival: it ends on its tick
## and the Swap is still waiting for its answer, once the HUD shows it.
func test_a_swap_opened_mid_arrival_waits_for_the_landing() -> void:
	var w := _arriving(1)
	var cards: Array[int] = []
	# free cards (since AS a second Pattern replaces the first instead of filling a slot)
	for id: StringName in [&"heavy", &"echo_slash", &"flurry", &"chain_cut", &"wide_arc"]:
		cards.append(WandLab.code(w, id))
	for k in Wand.slots(w):
		assert_true(BuildSlots.take(w, cards[k]), "fills slot %d" % (k + 1))
	var extra := cards[Wand.slots(w)]
	assert_true(BuildSlots.needs_swap(w, extra), "the slots are full")
	Offers.apply(w, extra)  # as DebugApi.grant_mod (and a found card) does
	assert_true(BuildSlots.swapping(w))
	var used := CombatLab.until(
		w, func(x: World) -> bool: return not WorldReader.new(x).arriving(), 400
	)
	assert_eq(used, FIRST, "the arrival ends on its tick with the Swap open")
	assert_true(BuildSlots.swapping(w), "and the Swap still waits for its answer")
	CombatLab.idle(w, 10)
	assert_true(BuildSlots.swapping(w), "until it gets one")
