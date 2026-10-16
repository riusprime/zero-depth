extends GutTest
## v0.8.0 P2 (owner O24: "Change Void so shots have a chance to spawn a small black hole lasting 2 seconds, attracting
## nearby enemies and dealing damage"): Void's black holes in the sim (BlackHoles). The card compiles a chance (8 % at
## level 1, +3 % a level: starting values) and no pull; a shot that ends (or a slash that lands) rolls once on the
## `ability` stream; a hole stands 120 ticks, at most 3 at once (the oldest replaced), pulls nearby enemies (not
## bosses) toward its centre and pulses damage-over-time on the ones in its core; it replays, snapshots and restores
## exactly, and a build without Void draws nothing. Mechanics only: no bot, no balance (owner P1).

const W := preload("res://tests/support/mx4_world.gd")
const VOID := &"gravity_well"


## `w` with its Void card raised to `level` (duplicates, as an altar's pick).
func _level(w: World, level: int) -> World:
	var k := W.item(w, VOID)
	for n in level - 1:
		Offers.apply(w, k)
	assert_eq(CardLevels.level(w, k), level)
	return w


func test_the_card_compiles_a_chance_rising_with_its_level_and_no_pull() -> void:
	var want := [80, 110, 140, 170, 200]
	for weapon: StringName in [&"gun", &"blade"]:
		for level in range(1, 6):
			var w := _level(W.world(weapon, [VOID]), level)
			var s := Modifiers.bolt(w) if weapon == &"gun" else Modifiers.step(w, 0)
			assert_eq(s.hole_permille, want[level - 1], "%s level %d: its chance" % [weapon, level])
			assert_eq(s.hole_damage_permille, 300, "%s: each pulse 30 %% of the shot" % weapon)
			assert_null(W.hook_of(s, VOID), "%s: no pull burst on every hit any more" % weapon)
			assert_eq(s.pull_m, 0.0)
			assert_has(s.elements, "void", "%s: still Void's look" % weapon)
	var plain := W.world(&"gun")
	assert_eq(Modifiers.bolt(plain).hole_permille, 0, "without the card: never")


func test_the_roll_takes_its_chance_from_the_ability_stream() -> void:
	var w := W.world(&"gun", [VOID])
	var spec := Modifiers.bolt(w)
	var tries := 5000
	var state := w.rng_ability.state
	BlackHoles.roll(w, spec, Vector2(5.0, 0.0), 10)
	assert_ne(w.rng_ability.state, state, "one draw a roll")
	w.mx.hole_pos.clear()
	w.mx.hole_from.clear()
	w.mx.hole_dmg.clear()
	# Each roll from an empty list: a hole stands after it or not.
	var n := 0
	for k in tries:
		BlackHoles.roll(w, spec, Vector2(5.0, 0.0), 10)
		n += w.mx.hole_pos.size()
		w.mx.hole_pos.clear()
		w.mx.hole_from.clear()
		w.mx.hole_dmg.clear()
	var rate := float(n) / tries
	gut.p("8 %% card: %d holes in %d rolls (%.3f)" % [n, tries, rate])
	assert_between(rate, 0.065, 0.095, "about 8 %")


func test_a_hole_stands_two_seconds_and_at_most_three_stand() -> void:
	var w := W.world(&"gun", [VOID])
	BlackHoles.open(w, Vector2(10.0, 0.0), 5)
	assert_eq(w.mx.hole_pos.size(), 1)
	W.run(w, 120)
	assert_eq(w.mx.hole_pos.size(), 1, "it stands its 120 ticks (2 s)")
	W.run(w, 1)
	assert_eq(w.mx.hole_pos.size(), 0, "then it is gone")
	for k in 4:
		BlackHoles.open(w, Vector2(10.0 + k, 0.0), 5)
		W.run(w, 1)
	assert_eq(w.mx.hole_pos.size(), 3, "at most 3")
	assert_eq(w.mx.hole_pos[0], Vector2(11.0, 0.0), "the oldest was replaced")
	assert_eq(w.mx.hole_pos[2], Vector2(13.0, 0.0), "the newest stands")
	assert_eq(WorldReader.new(w).black_holes().size(), 3, "the views read them")


func test_a_hole_pulls_nearby_enemies_in_and_not_far_ones_or_bosses() -> void:
	var w := W.world(&"gun", [VOID], [[Vector2(13.0, 0.0), 5000], [Vector2(10.0, 6.0), 5000]])
	var near := w.actors.ids[1]
	var far := w.actors.ids[2]
	var far_at := w.actors.pos(2)
	BlackHoles.open(w, Vector2(10.0, 0.0), 1)
	W.run(w, 30)
	var d := w.actors.pos(w.actors.index_of(near)).distance_to(Vector2(10.0, 0.0))
	assert_almost_eq(d, 3.0 - 30 * 0.05, 0.05, "pulled 3 m/s toward the centre")
	assert_eq(w.actors.pos(w.actors.index_of(far)), far_at, "6 m away: out of its reach")
	W.run(w, 60)
	d = w.actors.pos(w.actors.index_of(near)).distance_to(Vector2(10.0, 0.0))
	assert_gte(d, BlackHoles.CORE_GAP_M - 0.01, "never past its core")
	assert_lt(d, 0.5, "gathered at the centre")


func test_a_hole_pulses_damage_over_time_on_its_core() -> void:
	var w := W.world(&"gun", [VOID], [[Vector2(10.0, 0.5), 5000], [Vector2(10.0, 3.0), 5000]])
	var core := w.actors.ids[1]
	BlackHoles.open(w, Vector2(10.0, 0.0), 7)
	var hp := w.actors.hp[1]
	W.run(w, 12)
	assert_eq(W.damage(w, BlackHoles.EFFECT).size(), 0, "the first pulse comes after 0.2 s")
	W.run(w, 1)
	var first := W.damage(w, BlackHoles.EFFECT)
	assert_eq(first.size(), 1, "one enemy in the core (the other is pulled, not yet hurt)")
	assert_eq(first[0].target_id, core)
	assert_eq(first[0].amount, 7, "the pulse's damage")
	assert_ne(first[0].tags & SimEvent.TAG_DOT, 0, "a damage-over-time tick")
	assert_eq(first[0].proc_pct, 0, "it never procs")
	assert_eq(W.events(w, SimEvent.Kind.HIT, BlackHoles.EFFECT).size(), 0, "never a HIT")
	W.run(w, 108)
	var hits := 0
	for e in W.damage(w, BlackHoles.EFFECT):
		hits += 1 if e.target_id == core else 0
	assert_eq(hits, 9, "every 0.2 s while it stands: 9 pulses")
	assert_lt(w.actors.hp[w.actors.index_of(core)], hp)


## The pulse is the shot's damage × the card's share, rounded, at least 1.
func test_the_pulse_is_a_share_of_the_shot() -> void:
	var w := W.world(&"gun", [VOID])
	var spec := Modifiers.bolt(w).copy()
	spec.hole_permille = 1000
	BlackHoles.roll(w, spec, Vector2(10.0, 0.0), 5)
	assert_eq(w.mx.hole_dmg[0], 2, "5 x 30 % = 1.5, rounded to 2")
	BlackHoles.roll(w, spec, Vector2(10.0, 0.0), 1)
	assert_eq(w.mx.hole_dmg[1], 1, "at least 1")


## A shooting fight with a level-5 Void (20 %): holes open where the bolts end; the run replays to the same holes and
## hash; a snapshot taken while holes stand restores to the same hash and plays on the same.
func _gun_fight() -> World:
	var w := _level(
		W.world(&"gun", [VOID], [[Vector2(2.5, 0.0), 1000000], [Vector2(3.5, 1.5), 1000000]]), 5
	)
	return w


func test_in_play_shots_open_holes_and_replay_exactly() -> void:
	var a := _gun_fight()
	var b := _gun_fight()
	var seen := {}
	for t in 600:
		a.step(W.frame(0, W.S))
		b.step(W.frame(0, W.S))
		for k in a.mx.hole_from.size():
			seen[str([a.mx.hole_from[k], a.mx.hole_pos[k]])] = true
		assert_lte(a.mx.hole_pos.size(), 3, "never more than 3")
	var opened_a := seen.size()
	gut.p("level-5 Void, 600 ticks of shooting: %d holes opened" % opened_a)
	assert_gt(opened_a, 0, "shots opened black holes")
	assert_gt(W.damage(a, BlackHoles.EFFECT).size(), 0, "which hurt the enemy")
	assert_eq(a.state_hash(), b.state_hash(), "replays to the same hash")
	assert_eq(a.mx.hole_pos, b.mx.hole_pos)
	assert_eq(a.mx.hole_from, b.mx.hole_from)


func test_a_snapshot_with_holes_standing_round_trips() -> void:
	var w := _gun_fight()
	var guard := 0
	while w.mx.hole_pos.is_empty() and guard < 2000:
		w.step(W.frame(0, W.S))
		guard += 1
	assert_false(w.mx.hole_pos.is_empty(), "a hole stands")
	var snap := WorldSnapshot.take(w)
	var base := _gun_fight()
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.state_hash(), w.state_hash(), "restored to the same hash")
	for t in 60:
		w.step(W.frame(0, W.S))
		base.step(W.frame(0, W.S))
	assert_eq(base.state_hash(), w.state_hash(), "and plays on the same")


func test_slashes_that_land_open_holes_too() -> void:
	var w := _level(W.world(&"blade", [VOID], [[Vector2(1.0, 0.0), 1000000]]), 5)
	var seen := {}
	for n in 60:
		W.run(w, 1, W.P)
		for t in 14:
			W.run(w, 1)
			for k in w.mx.hole_from.size():
				seen[w.mx.hole_from[k]] = true
	var opened := seen.size()
	gut.p("level-5 Void, 60 slashes: %d holes" % opened)
	assert_gt(opened, 0, "a landing slash opens one")


func test_a_build_without_void_draws_nothing() -> void:
	var w := W.world(&"gun", [], [[Vector2(2.5, 0.0), 1000000]])
	var state := w.rng_ability.state
	W.run(w, 300, 0, W.S)
	assert_eq(w.rng_ability.state, state, "no draw on the ability stream")
	assert_true(w.mx.hole_pos.is_empty())
