extends GutTest
## Overclock heat (v0.3.0 PLAN L18; docs/design/SIGNATURE.md §Overclock) with the shipped data's numbers: gain per
## attack type, the decay, Hot and Overclock, the overheat stall, the vent blast, the three heat items, and worlds
## without heat keeping their behaviour. Aim angle 0 = +x.

const P := InputFrame.PRIMARY
const S := InputFrame.SHOOT
const U := InputFrame.UTILITY
const D := InputFrame.DASH
const M := HeatTable.MILLI

var _repo: ContentRepository
var _items: Array[ItemTable] = []
var _heat: HeatTable


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_items = ContentCompiler.compile_items(_repo)
	_heat = ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock"))


func _index(id: StringName) -> int:
	for i in _items.size():
		if _items[i].id == id:
			return i
	return -1


## The runner (four-slash combo) with heat, the item tables, the given items owned, still dummies at `enemies`.
func _world(
	items: Array = [], enemies: Array = [Vector2(1.2, 0)], utility: int = PlayerTable.Utility.NONE
) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.utility = utility
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.set_item_tables(_items)
	Heat.enable(w, _heat)
	for id: StringName in items:
		assert_true(w.add_item(_index(id)), "added %s" % id)
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 5000)
	return w


func _f(held: int = 0, pressed: int = 0, aim: int = 0, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, aim, 300, held, pressed)


func _idle(w: World, n: int, held: int = 0) -> void:
	for i in n:
		w.step(_f(held))


## Presses attack and steps until the swing and its hit-stop are over.
func _swing(w: World) -> void:
	w.step(_f(0, P))
	for k in 120:
		if w.swing_t == 0 and w.freeze_ticks == 0 and w.input_buffer[0] == 0:
			break
		w.step(_f())


func _events(w: World, kind: SimEvent.Kind, effect := &"", after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == kind and (effect == &"" or e.effect_id == effect):
			out.append(e)
	return out


func test_the_data_compiles_to_the_starting_values() -> void:
	var def: HeatDefinition = _repo.get_def(&"heat", &"overclock")
	assert_not_null(def)
	assert_eq(def.validate().size(), 0, "the shipped heat validates")
	assert_eq(_heat.max_heat, 100)
	assert_eq([_heat.gain_swing, _heat.gain_finisher, _heat.gain_bolt], [2500, 5000, 900])
	assert_eq(_heat.decay_delay_ticks, 60, "decay waits 1 s")
	assert_eq(_heat.decay_per_tick, 250, "then 15 heat per second")
	assert_eq([_heat.hot_threshold, _heat.overclock_threshold], [40, 75])
	assert_eq([_heat.hot_reach_permille, _heat.overclock_damage_permille], [200, 250])
	assert_eq(_heat.stall_ticks, 72, "a 1.2 s stall")
	assert_eq(_heat.stall_move_permille, 600)
	assert_eq(_heat.vent_damage_permille, 500)
	assert_almost_eq(_heat.vent_radius_m, 2.5, 1e-6)


func test_bad_heat_definitions_are_rejected() -> void:
	var d := HeatDefinition.new()
	d.id = &"bad"
	d.hot_threshold = 80
	d.overclock_threshold = 60
	d.gain_bolt = 0.0
	d.overheat_move_multiplier = 0.0
	var codes := d.validate().map(func(i: ValidationIssue) -> StringName: return i.code)
	assert_has(codes, &"range")
	assert_has(codes, &"not_positive")


func test_each_landed_attack_adds_its_type_once() -> void:
	var two := _world([], [Vector2(1.2, 0.4), Vector2(1.2, -0.4)])
	_swing(two)
	assert_eq(_events(two, SimEvent.Kind.HIT).size(), 2)
	assert_eq(two.heat.milli, 2500, "a slash hitting two enemies adds 2.5 once")
	var w := _world()
	var got := []
	for k in 4:
		_swing(w)
		got.append(w.heat.milli)
	assert_eq(got, [2500, 5000, 7500, 12500], "slash, backhand, thrust 2.5 each; the finisher 5")
	var v := _world([], [Vector2(3, 0)])
	v.step(_f(S))
	_idle(v, 12, 0)
	assert_eq(v.heat.milli, 900, "one landed bolt adds 0.9")
	var miss := _world([], [Vector2(-3, 0)])
	_swing(miss)
	assert_eq(miss.heat.milli, 0, "a whiff adds nothing")


func test_heat_holds_a_second_then_decays_at_15_per_second() -> void:
	var w := _world()
	w.heat.milli = 50 * M
	w.heat.idle = 0
	_idle(w, 60)
	assert_eq(w.heat.milli, 50 * M, "held for 1 s after the last gain")
	_idle(w, 60)
	assert_eq(w.heat.milli, 35 * M, "then 15 heat in the next second")
	_idle(w, 200)
	assert_eq(w.heat.milli, 0, "down to 0, never below")


func test_a_sustained_fight_reaches_the_thresholds_in_6_to_10_seconds() -> void:
	for mode in ["blade", "gun"]:
		var w := _world([], [Vector2(1.2, 0)])
		# Each mode is its starting build (v0.3.0 L15/L16): heat counts hits, not damage, so the factors don't move it.
		ContentCompiler.apply_build(w.player, _repo.get_def(&"build", StringName(mode)))
		var hot := -1
		var oc := -1
		for k in 900:
			if mode == "blade":
				w.step(_f(0, P if k % 4 == 0 else 0))
			else:
				w.step(_f(S))
			if hot < 0 and Heat.points(w) >= 40:
				hot = w.tick
			if oc < 0 and Heat.points(w) >= 75:
				oc = w.tick
		gut.p("%s: Hot at %.2f s, Overclock at %.2f s" % [mode, hot / 60.0, oc / 60.0])
		assert_between(hot, 4 * 60, 6 * 60, "%s: Hot in 4-6 s" % mode)
		assert_between(oc, 6 * 60, 10 * 60, "%s: Overclock in 6-10 s" % mode)


func test_hot_reaches_farther_and_bolts_pierce_one_enemy() -> void:
	var w := _world([], [])
	var base := ItemEffects.swing_reach_m(w, 0)
	w.heat.milli = 40 * M
	Heat.advance(w)
	assert_eq(Heat.tier_of(w), Heat.TIER_HOT)
	assert_almost_eq(
		ItemEffects.swing_reach_m(w, 0), base * 1.2, 1e-5, "the blade reaches 20 % farther"
	)
	assert_almost_eq(
		WorldReader.new(w).swing_reach_m(0), base * 1.2, 1e-5, "and the view draws that reach"
	)
	var v := _world([], [Vector2(2, 0), Vector2(3.2, 0), Vector2(4.4, 0)])
	v.heat.milli = 45 * M
	v.step(_f(S))
	_idle(v, 30)
	var hit_ids := {}
	for e in _events(v, SimEvent.Kind.HIT):
		if e.tags & SimEvent.TAG_PROJECTILE:
			hit_ids[e.target_id] = true
	assert_eq(
		hit_ids.size(), 2, "the bolt went through the first enemy into the second, and stopped"
	)
	assert_true(hit_ids.has(v.actors.ids[1]) and hit_ids.has(v.actors.ids[2]))
	var c := _world([], [Vector2(2, 0), Vector2(3.2, 0)])
	c.step(_f(S))
	_idle(c, 30)
	assert_eq(_events(c, SimEvent.Kind.HIT).size(), 1, "a cool bolt stops at the first enemy")


func test_overclock_hits_harder_leaves_embers_and_feeds_the_fire_engine() -> void:
	var w := _world([&"cinder_shot"])
	w.heat.milli = 80 * M
	var seq := w.last_event_seq()
	_swing(w)
	var hits := _events(w, SimEvent.Kind.HIT, &"", seq)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 12, "the 10-damage slash deals 25 % more")
	assert_ne(hits[0].tags & SimEvent.TAG_OVERCLOCK, 0, "tagged Overclock")
	assert_eq(w.heat.ember_tick, hits[0].tick, "an ember where it hit")
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, Heat.EFFECT_OVERCLOCK, seq).size(), 1)
	var cool := _world([&"cinder_shot"])
	_swing(cool)
	assert_eq(
		w.actors.burn_stacks[1],
		cool.actors.burn_stacks[1] + 1,
		"with a burn item owned, an Overclock hit adds one more burn stack"
	)
	var plain := _world()
	plain.heat.milli = 80 * M
	_swing(plain)
	assert_eq(plain.actors.burn_stacks[1], 0, "no fire engine, no burn")
	var hot := _world()
	hot.heat.milli = 50 * M
	_swing(hot)
	assert_eq(_events(hot, SimEvent.Kind.HIT)[0].amount, 10, "Hot alone deals no extra")


func test_reaching_the_overheat_point_stalls_for_1_2_seconds() -> void:
	var w := _world()
	w.heat.milli = 99 * M
	_swing(w)
	assert_true(Heat.stalled(w), "overheated")
	assert_eq(w.heat.overheat_tick, _events(w, SimEvent.Kind.HIT)[0].tick)
	assert_eq(Heat.tier_of(w), Heat.TIER_OVERHEAT)
	var left := w.heat.stall
	assert_gt(left, 50, "most of the 72-tick stall is still ahead")
	var hits := _events(w, SimEvent.Kind.HIT).size()
	for k in left - 1:
		w.step(_f(S, P if k % 5 == 0 else 0, 0, Vector2i(127, 0)))
		assert_eq(w.swing_t, 0, "no swing while stalled")
	assert_eq(_events(w, SimEvent.Kind.HIT).size(), hits, "nor a shot")
	assert_almost_eq(Kin.length(w.vel), w.player.move_speed * 0.6, 1e-4, "moving at 60 %")
	assert_lt(w.heat.milli, 3 * M, "the heat drained with the stall")
	w.step(_f())
	assert_false(Heat.stalled(w), "the stall is over after 72 ticks")
	assert_eq(w.heat.milli, 0)
	_swing(w)
	assert_gt(w.heat.milli, 0, "attacking again")


func test_a_dash_while_hot_vents_a_blast_and_resets_heat() -> void:
	var w := _world([], [Vector2(1.5, 0), Vector2(4.5, 0)])
	w.heat.milli = 50 * M + 600
	w.step(_f(0, D, 0, Vector2i(0, 127)))
	var blast := _events(w, SimEvent.Kind.HIT, Heat.EFFECT_VENT)
	assert_eq(blast.size(), 1, "the near enemy is in the 2.5 m blast, the far one isn't")
	assert_eq(blast[0].target_id, w.actors.ids[1])
	assert_eq(blast[0].amount, 25, "50 heat x 0.5")
	assert_ne(blast[0].tags & SimEvent.TAG_AREA, 0)
	assert_eq(
		blast[0].ancestry, PackedStringArray([Heat.EFFECT_VENT]), "the blast runs as a payoff"
	)
	assert_eq(w.heat.milli, 0, "heat reset to 0")
	assert_eq(w.heat.vent_tick, blast[0].tick)
	assert_eq(w.heat.vent_heat, 50)
	assert_almost_eq(w.heat.vent_radius, 2.5, 1e-6)
	var cool := _world([], [Vector2(1.5, 0)])
	cool.heat.milli = 39 * M
	cool.step(_f(0, D, 0, Vector2i(0, 127)))
	assert_eq(_events(cool, SimEvent.Kind.HIT).size(), 0, "under Hot a dash vents nothing")
	assert_eq(cool.heat.milli, 39 * M)


func test_a_blink_while_hot_vents_where_it_lands() -> void:
	var w := _world([], [Vector2(5, 1.0)], PlayerTable.Utility.BLINK)
	w.heat.milli = 60 * M
	w.step(_f(0, U, 0, Vector2i(127, 0)))
	var blast := _events(w, SimEvent.Kind.HIT, Heat.EFFECT_VENT)
	assert_eq(blast.size(), 1, "blinked 5 m next to the enemy and vented there")
	assert_eq(blast[0].amount, 30)
	assert_eq(w.heat.milli, 0)


func test_the_vent_blast_adds_no_heat_and_no_stacks_and_respects_ancestry() -> void:
	var w := _world([&"serrated_edge"], [Vector2(1.5, 0)])
	w.heat.milli = 60 * M
	w.step(_f(0, D, 0, Vector2i(0, 127)))
	assert_eq(_events(w, SimEvent.Kind.HIT, Heat.EFFECT_VENT).size(), 1)
	assert_eq(w.heat.milli, 0, "the blast's own hit adds no heat")
	assert_eq(w.actors.bleed_stacks[1], 0, "and feeds no engine (a payoff)")
	var v := _world([], [Vector2(1.5, 0)])
	v.heat.milli = 60 * M
	v.engine_chain.append(Heat.EFFECT_VENT)
	Heat.on_move(v)
	assert_eq(
		_events(v, SimEvent.Kind.HIT, Heat.EFFECT_VENT).size(), 0, "a vent inside a vent never runs"
	)


func test_heat_sink_makes_vent_blasts_bigger() -> void:
	var w := _world([&"heat_sink"], [Vector2(3.2, 0)])
	w.heat.milli = 50 * M
	w.step(_f(0, D, 0, Vector2i(0, 127)))
	var blast := _events(w, SimEvent.Kind.HIT, Heat.EFFECT_VENT)
	assert_eq(blast.size(), 1, "3.25 m reaches the enemy at 3.2 m")
	assert_eq(blast[0].amount, 37, "50 x 0.5 x 1.5")
	assert_almost_eq(w.heat.vent_radius, 3.25, 1e-5)


func test_thermal_edge_runs_hot_from_30() -> void:
	var w := _world([&"thermal_edge"])
	w.heat.milli = 30 * M
	assert_true(Heat.hot(w))
	assert_eq(Heat.read(w)["hot"], 30, "the meter marks Hot at 30")
	var plain := _world()
	plain.heat.milli = 30 * M
	assert_false(Heat.hot(plain))


func test_meltdown_explodes_instead_of_stalling() -> void:
	var w := _world([&"meltdown"], [Vector2(1.2, 0), Vector2(-2, 0)])
	w.heat.milli = 99 * M
	_swing(w)
	assert_false(Heat.stalled(w), "no stall")
	assert_true(w.heat.meltdown)
	assert_eq(w.heat.milli, 0)
	var blast := _events(w, SimEvent.Kind.HIT, Heat.EFFECT_MELTDOWN)
	assert_eq(blast.size(), 2, "both enemies in the blast")
	assert_eq(blast[0].amount, 50, "a full-heat blast: 100 x 0.5")
	w.step(_f(0, P))
	assert_gt(w.swing_t, 0, "you keep attacking")


func test_heat_items_are_offered_only_with_heat() -> void:
	var w := _world([], [])
	var t := PlayerTable.starting_values()
	var v := World.new(5, t)
	v.set_item_tables(_items)
	var heat_items := [_index(&"heat_sink"), _index(&"thermal_edge"), _index(&"meltdown")]
	for idx in heat_items:
		assert_gte(idx, 0)
		assert_true(_items[idx].requires_heat)
		assert_has(ItemPool.available(w), idx, "offered with heat")
		assert_does_not_have(ItemPool.available(v), idx, "never without")
	assert_eq(_items[_index(&"meltdown")].rarity, ItemTable.RARE)


func test_a_world_without_heat_is_unchanged() -> void:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	var w := World.new(5, t)
	w.add_dummy(Vector2(1.2, 0), 0.35, 5000)
	assert_null(w.heat)
	assert_eq(WorldReader.new(w).heat_state(), {})
	assert_eq(Heat.points(w), 0)
	assert_eq(Heat.reach_permille(w), 1000)
	assert_eq(Heat.bolt_tags(w), 0)
	var h := w.state_hash()
	var v := World.new(5, t)
	v.add_dummy(Vector2(1.2, 0), 0.35, 5000)
	Heat.enable(v, null)
	assert_eq(v.state_hash(), h, "enabling a null table leaves the world (and its hash) alone")


func test_heat_is_deterministic_and_hashed() -> void:
	var a := _world()
	var b := _world()
	for k in 600:
		var f := _f(S if k % 90 < 60 else 0, P if k % 7 == 0 else (D if k % 97 == 0 else 0))
		a.step(f)
		b.step(f)
	assert_eq(a.state_hash(), b.state_hash())
	var before := a.state_hash()
	a.heat.milli += 1
	assert_ne(a.state_hash(), before, "heat is in the hash")


func test_gamble_heat_capacity_makes_each_attack_fill_less() -> void:
	var w := _world()
	w.gamble_table = ContentCompiler.compile_gamble(
		ContentRepository.load_all().get_def(&"gamble", &"shrine")
	)
	Heat.add(w, 10000)
	var plain := w.heat.milli
	w.heat.milli = 0
	w.gamble_stacks.resize(GambleTable.STAT_COUNT)
	w.gamble_stacks[GambleTable.Stat.HEAT] = 2  # +8 % each: 1160 per mille of capacity
	Heat.add(w, 10000)
	assert_eq(plain, 10000)
	assert_eq(w.heat.milli, 10000 * 1000 / 1160, "the same attack fills 1/1.16 as much")
