extends GutTest
## v0.10.5 W3-P10a (owner W7, docs/roadmap/v0.10.5/W3_W7_LOOP_POWER_G1.md A1-A5): from loop 2 the caps keep paying.
## Crit chance caps at 200 % and past 100 % the one `crit` roll picks a double crit (the crit multiplier twice, at most
## x10, TAG_DOUBLE_CRIT); the crit multiplier caps at x6 (loop 2) and x8 (loop 3+); attack speed has no cap and its raw
## bonus past the curve's top turns into damage (+10 per mille per 20); hooks go one level deeper a loop. Loop 1 keeps
## every old number.

const W := preload("res://tests/support/mx4_world.gd")
const STAGE := ModifierTable.Stage
const OP := ModifierOp.Op
const FORM := AttackSpec.Form
const TRIGGER := AttackSpec.Trigger
const CC := Stats.Stat.CRIT_CHANCE
const CD := Stats.Stat.CRIT_DAMAGE
const AS := Stats.Stat.ATTACK_SPEED


func _world(loop: int) -> World:
	var w := W.world(&"gun")
	w.loop = loop
	return w


## Sets stat `s`'s raw value straight (past any cap: what a loop-2 run's cards can reach).
func _put(w: World, s: int, v: int) -> void:
	Stats.grow(w, s)
	w.stat_values[s] = v


# --- A1: the crit-chance cap and the double crit ------------------------------------------------------------------
func test_crit_chance_caps_at_75_in_loop_1_and_200_from_loop_2() -> void:
	for loop in [1, 2, 3]:
		var w := _world(loop)
		_put(w, CC, 2600)
		assert_eq(Stats.crit_chance(w), 750 if loop == 1 else 2000, "loop %d" % loop)
		assert_eq(Stats.double_crit_chance(w), 0 if loop == 1 else 1000)
		assert_true(Stats.at_cap(w, CC))
	var two := _world(2)
	_put(two, CC, 800)
	assert_false(Stats.at_cap(two, CC), "80 % is under loop 2's cap: still offered")
	var one := _world(1)
	_put(one, CC, 800)
	assert_true(Stats.at_cap(one, CC), "and at loop 1's")


func test_a_chance_past_100_always_crits_and_doubles_under_the_excess() -> void:
	var w := _world(3)
	_put(w, CC, 1500)  # 50 % of the hits double
	_put(w, CD, 4000 - w.player.crit_mult_permille)  # x4 (loop 3 caps at x8)
	assert_eq(Stats.crit_mult(w), 4000)
	assert_eq(Stats.double_crit_mult(w), 10000, "x4 twice is x16: at most x10")
	var doubles := 0
	for k in 400:
		var out := Stats.outgoing(w, 10, 0)
		assert_ne(out[1] & SimEvent.TAG_CRIT, 0, "every hit crits past 100 %")
		if out[1] & SimEvent.TAG_DOUBLE_CRIT:
			doubles += 1
			assert_eq(out[0], 100, "a double crit: 10 x the x10 bound")
		else:
			assert_eq(out[0], 40, "a crit: 10 x 4")
	assert_between(doubles, 140, 260, "about half double (roll < 500)")


func test_a_double_crit_takes_the_multiplier_twice_under_the_bound() -> void:
	var w := _world(2)
	_put(w, CC, 2000)  # every hit doubles
	_put(w, CD, 2000 - w.player.crit_mult_permille)  # x2
	var out := Stats.outgoing(w, 10, 0)
	assert_eq(out[1], SimEvent.TAG_CRIT | SimEvent.TAG_DOUBLE_CRIT)
	assert_eq(out[0], 40, "x2 twice: 10 x 4")


func test_loop_1_draws_the_same_rolls_and_never_doubles() -> void:
	var a := _world(1)
	var b := _world(1)
	_put(a, CC, 2600)
	_put(b, CC, 750)
	for k in 200:
		var x := Stats.outgoing(a, 10, 0)
		var y := Stats.outgoing(b, 10, 0)
		assert_eq(x, y, "capped at 75 %: the same hit as a 75 % world")
		assert_eq(x[1] & SimEvent.TAG_DOUBLE_CRIT, 0)
	assert_eq(a.rng_crit.state, b.rng_crit.state, "one roll a hit, as before")


func test_a_dot_tick_never_crits_or_rolls_at_loop_2() -> void:
	var w := _world(2)
	_put(w, CC, 2000)
	var before := w.rng_crit.state
	var out := Stats.outgoing(w, 10, SimEvent.TAG_DOT)
	assert_eq(out[1], 0)
	assert_eq(w.rng_crit.state, before)


# --- A3: the crit-damage cap --------------------------------------------------------------------------------------
func test_the_crit_multiplier_caps_at_x4_then_x6_then_x8() -> void:
	var want := {1: 4000, 2: 6000, 3: 8000, 4: 8000}
	for loop: int in want:
		var w := _world(loop)
		_put(w, CD, 20000)
		assert_eq(Stats.crit_mult(w), want[loop], "loop %d" % loop)
		assert_eq(Stats.cap_of(w, CD, Stats.table(w, CD)), want[loop])


# --- A4: haste overflow -------------------------------------------------------------------------------------------
func test_the_curve_tops_out_at_plus_100_percent_where_loop_1_caps_the_stat() -> void:
	var w := _world(1)
	assert_eq(AttackRate.top(w.tuning), 1500)
	assert_eq(AttackRate.curve(w.tuning, 1500), 1000, "+100 % rate at the top")
	assert_eq(
		Stats.table(w, AS).cap, 1000 + AttackRate.top(w.tuning), "loop 1's 2.5 sits on the top"
	)


func test_loop_1_caps_attack_speed_and_adds_no_damage() -> void:
	var w := _world(1)
	_put(w, AS, 2500)
	var dmg := Stats.damage_permille(w)
	Stats.add_amount(w, AS, 180)
	assert_eq(Stats.value(w, AS), 2500, "capped at 2.5")
	assert_eq(Stats.damage_permille(w), dmg)
	assert_eq(AttackRate.overflow_at(w, 4000), 0, "no overflow in loop 1")
	assert_true(Stats.at_cap(w, AS))


func test_from_loop_2_haste_past_the_top_turns_into_damage() -> void:
	var w := _world(2)
	_put(w, AS, 2500)
	var dmg := Stats.damage_permille(w)
	var rate := AttackRate.rate(w, 0)
	assert_false(Stats.at_cap(w, AS), "no cap: still offered")
	Stats.add_amount(w, AS, 180)
	assert_eq(Stats.value(w, AS), 2680, "past 2.5")
	assert_eq(AttackRate.rate(w, 0), rate, "no more rate past the top")
	assert_eq(AttackRate.stat_bonus(w), 1500, "the catch-up reads the rated stat too")
	assert_eq(AttackRate.overflow_at(w, 2680), 180)
	assert_eq(Stats.haste_damage_at(w, 2680), 90, "every 20 per mille past it: +10")
	assert_eq(Stats.damage_permille(w), dmg + 90)
	assert_eq(Stats.haste_damage_at(w, 2519), 0, "a part step adds nothing")
	assert_eq(Stats.haste_damage_at(w, 2539), 10)


func test_the_attack_speed_forecast_shows_the_damage_past_the_top() -> void:
	var w := _world(2)
	_put(w, AS, 2500)
	var code := Offers.stat_code(AS, Stats.Rarity.EPIC)
	var f := CardForecast.of(w, code)
	assert_eq(int(f["new"]), int(f["old"]), "no rate past the top")
	var d := Stats.value(w, Stats.Stat.DAMAGE)
	assert_eq(int(f["dmg_old"]), Stats.bucket_at(w, d, false))
	Stats.add_card(w, AS, Stats.Rarity.EPIC)
	assert_eq(
		int(f["dmg_new"]), Stats.bucket_at(w, d, false), "the forecast is the outcome (EI-07)"
	)
	assert_gt(int(f["dmg_new"]), int(f["dmg_old"]))
	var one := _world(1)
	_put(one, AS, 2400)
	assert_false(CardForecast.of(one, code).has("dmg_old"), "loop 1's forecast keeps its keys")


# --- A5: deeper chains --------------------------------------------------------------------------------------------
func test_hook_depth_reads_the_loop() -> void:
	var want := {1: 2, 2: 3, 3: 4, 4: 4, 7: 4}
	for loop: int in want:
		assert_eq(Attacks.hook_depth(_world(loop)), want[loop], "loop %d" % loop)


static func _mod(id: StringName) -> ModifierTable:
	var o := ModifierOp.new()
	o.op = OP.HOOK
	o.stage = STAGE.HOOK
	o.form = FORM.BURST
	o.trigger = TRIGGER.ON_HIT
	o.hook_tags = PackedStringArray(["area"])
	o.radius_m = 3.0
	o.damage_permille = 500
	o.effect_id = id
	var m := ModifierTable.new()
	m.id = id
	m.target = (
		PackedStringArray(["area"]) if id != &"h1" else PackedStringArray(["weapon", "melee"])
	)
	m.ops = [o] as Array[ModifierOp]
	return m


## A Blade world at `loop` whose wand holds `n` chained burst hooks h1..hn (h1 on the swing, the rest on area).
func _chain_world(loop: int, n: int) -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.loop = loop
	w.dummy_speed = 0.0
	w.set_item_tables(ContentCompiler.compile_items(AttackScenario.repo()))
	for at: Vector2 in [Vector2(1.2, 0), Vector2(1.2, 0.9), Vector2(0.4, 1.4)]:
		w.add_dummy(at, 0.35, 5000)
	var mods: Array[ModifierTable] = []
	for k in n:
		mods.append(_mod(StringName("h%d" % (k + 1))))
	w.attack_book = Modifiers.compile_for(w, mods)
	return w


## The deepest level the compiled Blade step reaches (following each spec's first hook).
func _deepest(w: World) -> int:
	var s := w.attack_book.spec(&"blade_step_0")
	while not s.hooks.is_empty():
		s = s.hooks[0].child
	return s.depth


func test_the_compile_builds_one_level_deeper_a_loop() -> void:
	assert_eq(_deepest(_chain_world(1, 5)), 2, "loop 1: nothing below depth 2")
	assert_eq(_deepest(_chain_world(2, 5)), 3)
	assert_eq(_deepest(_chain_world(3, 5)), 4)
	assert_eq(_deepest(_chain_world(5, 5)), 4, "at most 4")


func test_a_loop_2_chain_lands_its_third_level_at_a_halved_proc() -> void:
	# h1's burst (depth 1) carries h2 and h3; h2's (depth 2) carries h3, a depth-3 burst only from loop 2.
	for loop in [1, 2]:
		var w := _chain_world(loop, 3)
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY))
		for i in 20:
			w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))
		var procs := {}
		for e in w.events_since(0):
			if e.kind == SimEvent.Kind.HIT and e.effect_id != &"":
				var seen: Array = procs.get(e.effect_id, [])
				if not seen.has(e.proc_pct):
					seen.append(e.proc_pct)
				procs[e.effect_id] = seen
			assert_ne(e.kind, SimEvent.Kind.LIMIT, "no watchdog")
		assert_eq(procs.get(&"h1"), [50], "depth 1")
		assert_eq(procs.get(&"h2"), [25], "depth 2")
		var h3: Array = procs.get(&"h3", [])
		h3.sort()
		assert_eq(
			h3,
			[25] if loop == 1 else [12, 25],
			"loop %d: depth 3 (100 >> 3) only from loop 2" % loop
		)
		assert_true(w.hook_chain.is_empty(), "the chain closes")


func test_the_wand_read_flags_cards_past_the_loops_depth() -> void:
	var trig := {"trigger": 0, "name_key": &"T"}
	var card := {"trigger": -1, "name_key": &"C"}
	var wand := {"cards": [trig, trig, trig, card]}
	assert_eq(Wand.flags(wand)[3], Wand.DEAD_TOO_DEEP, "past the third trigger: too deep in loop 1")
	wand["depth"] = 3
	assert_eq(Wand.flags(wand)[3], &"", "loop 2 casts it")
	assert_eq(Wand.read(_world(2))["depth"], 3)
	assert_eq(Wand.read(_world(1))["depth"], 2)
