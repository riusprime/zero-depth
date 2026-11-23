# gdlint: disable=max-public-methods
extends GutTest
## The Fallen takes your cards (FallenTheft): at 66 % and 33 % of its HP, a cast in its rhythm (never with a remembered
## mechanic, a mimic window or the calm after one), then your strongest card goes dark in its slot and does nothing;
## eight hits on its back (the rear 120 degrees) give it back. Two at most. Every way out of the fight gives every card
## back: its death, the hero's, the body gone by the dev panel's jump, a save (the theft restores exactly; a run carried
## on holds the whole wand), the run's end and a new loop.

const R := preload("res://src/sim/ai/boss_remembered.gd")
const SEED := 931
## Split Shot (level 5) is the strongest, then Ember Core (3), Twin (2), Halo (1).
const GUN_CARDS := [[&"gun_twin", 2], [&"split_shot", 5], [&"ember_core", 3], [&"halo_shot", 1]]


func _world(seed_value: int = SEED, windows: bool = false, held: bool = true) -> World:
	return NemesisLab.world(seed_value, &"gun", GUN_CARDS, held, not windows)


func _m(w: World) -> FallenRememberedTable:
	return R.table_of(w)


## The remembered mechanics out of the way: both their gates met, their clock far off.
func _quiet_mechanics(w: World) -> void:
	var fs := w.boss_fight
	fs.fl_gates = 3
	fs.fl_open = w.tick
	fs.fl_next = w.tick + 1000000
	fs.fl_end = -1


## The Fallen's HP to `permille` of its max (a test's write; the theft's gates read it).
func _hp(w: World, permille: int) -> void:
	var i := FinalLab.body(w)
	w.actors.hp[i] = w.actors.max_hp[i] * permille / 1000


## Steps until The Fallen holds `n` cards (at most `limit` ticks); the ticks stepped, or -1.
func _until_held(w: World, n: int, limit: int = 900) -> int:
	for k in limit:
		if w.boss_fight.fl_tk_code.size() == n:
			return k
		w.step(InputFrame.new())
	return -1


## Takes the strongest card now (its gate reached, the mechanics quiet).
func _steal_one(w: World, permille: int = 650) -> void:
	_quiet_mechanics(w)
	_hp(w, permille)
	assert_gt(_until_held(w, w.boss_fight.fl_tk_code.size() + 1), -1, "a card is taken")


func _has_split(w: World) -> bool:
	for h in Modifiers.bolt(w).hooks:
		if h.child != null and h.child.form == AttackSpec.Form.BOLT:
			return true
	return false


## A hero hit of 1 on The Fallen arriving from `side` (+1 its back, -1 its front) at 2 m.
func _hit_from(w: World, side: float) -> void:
	var i := FinalLab.body(w)
	var at := w.actors.pos(i)
	var from := at - Kin.dir(w.actors.facing[i]) * 2.0 * side
	var pid := w.actors.ids[0]
	Damage.hit(w, i, 1, pid, pid, w.take_root(), 0, from, at)


func _seq(w: World) -> int:
	return w.last_event_seq()


func _effects(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == effect:
			out.append(e)
	return out


func _assert_whole(w: World, why: String) -> void:
	assert_true(w.boss_fight.fl_tk_code.is_empty(), why + ": it holds nothing")
	assert_true(_has_split(w), why + ": Split Shot splits again")
	for c: Dictionary in WorldReader.new(w).wand()["cards"]:
		assert_false(bool(c["taken"]), why + ": no slot dark (%s)" % c["id"])


# --- data -----------------------------------------------------------------------------------------------------------


func test_the_data_compiles_and_bad_numbers_are_refused() -> void:
	var w := _world()
	var m := _m(w)
	assert_eq(m.theft_gates, PackedInt32Array([660, 330]))
	assert_eq([m.theft_cast_ticks, m.theft_held, m.theft_hits, m.theft_half_arc], [90, 2, 8, 683])
	var d: FinalBossDefinition = SharedContent.repo().get_def(&"final_bosses", &"nemesis")
	assert_eq(d.validate().size(), 0)
	for bad in [["theft_second_permille", 700], ["theft_hits", 0], ["theft_held", 3]]:
		var e: FinalBossDefinition = d.duplicate()
		e.remembered = d.remembered.duplicate()
		e.remembered[bad[0]] = bad[1]
		assert_gt(e.validate().size(), 0, "%s = %s is refused" % bad)


# --- the theft --------------------------------------------------------------------------------------------------------


func test_the_strongest_card_goes_dark_in_its_slot_and_does_nothing() -> void:
	var w := _world()
	var split := NemesisLab.card(w, &"split_shot")
	var order := w.mod_slots.duplicate()
	var levels: Array[int] = []
	for s in w.mod_slots.size():
		levels.append(BuildSlots.level_at(w, s))
	assert_true(_has_split(w), "it splits before")
	_quiet_mechanics(w)
	_hp(w, 650)
	var seq := _seq(w)
	assert_gt(_until_held(w, 1), -1)
	assert_eq(w.boss_fight.fl_tk_code, PackedInt32Array([split]), "Split Shot, level 5, is taken")
	assert_eq(w.mod_slots, order, "the wand's order is untouched")
	for s in w.mod_slots.size():
		assert_eq(BuildSlots.level_at(w, s), levels[s], "every level stays")
	assert_false(_has_split(w), "its effect is off: no split")
	var cards: Array = WorldReader.new(w).wand()["cards"]
	for s in cards.size():
		assert_eq(bool(cards[s]["taken"]), int(cards[s]["code"]) == split, "only its slot is dark")
	var cast := _effects(w, FallenTheft.CAST, seq)
	var taken := _effects(w, FallenTheft.TAKEN, seq)
	assert_eq(cast.size(), 1, "one cast")
	assert_eq(cast[0].amount, 90)
	assert_eq(taken.size(), 1)
	assert_eq(taken[0].tick - cast[0].tick, 90, "it takes the card as its 1.5 s cast ends")
	assert_eq([taken[0].amount, taken[0].amount_applied], [w.mod_slots.find(split), split])
	var codes: Array[int] = []
	for c in w.final_fight.casts.slice(0, BossAi.table_of(w, FinalLab.body(w)).card_casts):
		codes.append(c.code)
	assert_has(codes, split, "its mimic windows cast it")


func test_it_holds_still_and_starts_nothing_during_the_cast() -> void:
	var w := _world()
	var i := FinalLab.body(w)
	_quiet_mechanics(w)
	_hp(w, 650)
	for k in 600:
		w.step(InputFrame.new())
		if FallenTheft.casting(w):
			break
	assert_true(FallenTheft.casting(w), "the cast began")
	var at := w.actors.pos(i)
	while FallenTheft.casting(w):
		assert_eq(w.boss_fight.fl_stage, R.STAGE_NONE, "no remembered mechanic")
		assert_true(BossRemembered.holds_window(w), "no window may begin")
		assert_lt(w.bosses.attack[BossAi.entry_of(w, i)], 0, "no attack of its own")
		w.step(InputFrame.new())
	assert_almost_eq(Kin.length(w.actors.pos(i) - at), 0.0, 0.01, "it stood still")


func test_it_waits_for_a_remembered_mechanic_and_the_calm_after_it() -> void:
	var w := _world()
	var fs := w.boss_fight
	var m := _m(w)
	fs.fl_open = w.tick
	_hp(w, 650)  # Both the remembered gate and the theft's
	var cast_at := -1
	var ended_at := -1
	for k in 4000:
		w.step(InputFrame.new())
		assert_false(
			FallenTheft.casting(w) and fs.fl_stage != R.STAGE_NONE, "never both at tick %d" % w.tick
		)
		if fs.fl_stage != R.STAGE_NONE:
			ended_at = -1
		elif ended_at < 0 and fs.fl_end >= 0:
			ended_at = fs.fl_end
		if FallenTheft.casting(w) and cast_at < 0:
			cast_at = w.tick
		if not fs.fl_tk_code.is_empty():
			break
	assert_gt(fs.fl_n, 0, "the remembered mechanic went first")
	assert_gt(cast_at, -1, "then the theft")
	assert_gte(cast_at, ended_at + m.calm_ticks, "after the calm")
	assert_eq(fs.fl_tk_code.size(), 1)


func test_never_in_a_mimic_window_and_no_window_during_it() -> void:
	var w := _world(SEED + 1, true)
	var fs := w.boss_fight
	_quiet_mechanics(w)
	_hp(w, 650)
	var cast_ticks := 0
	for k in 3600:
		w.step(InputFrame.new())
		if FallenTheft.casting(w):
			cast_ticks += 1
			assert_eq(FinalPace.window(w), FinalPace.Mimic.OFF, "no window at tick %d" % w.tick)
		if not fs.fl_tk_code.is_empty():
			break
	assert_eq(cast_ticks, 90, "one whole cast")
	assert_eq(fs.fl_tk_code.size(), 1)


func test_two_cards_held_at_most_and_a_gate_with_nothing_to_take_passes() -> void:
	var w := _world()
	var split := NemesisLab.card(w, &"split_shot")
	_steal_one(w, 650)
	var second := FallenTheft.target(w)
	_quiet_mechanics(w)
	w.boss_fight.fl_end = -1
	_steal_one(w, 320)
	assert_eq(w.boss_fight.fl_tk_code, PackedInt32Array([split, second]), "the next strongest")
	assert_ne(second, split)
	assert_eq(w.boss_fight.fl_tk_gates, 3, "both gates met")
	var bare := NemesisLab.world(SEED, &"gun", [], true, true)
	_quiet_mechanics(bare)
	_hp(bare, 300)
	var seq := _seq(bare)
	for k in 300:
		bare.step(InputFrame.new())
	assert_eq(bare.boss_fight.fl_tk_gates, 3, "no card: both gates pass")
	assert_eq(_effects(bare, FallenTheft.CAST, seq).size(), 0, "silently: no cast")


func test_the_ember_card_taken_stops_its_fire() -> void:
	var w := _world()
	var ember := NemesisLab.card(w, &"ember_core")
	assert_true(ElementLevelsFsf.held(w, ElementLevelsFsf.FIRE), "the fire is on")
	w.boss_fight.fl_tk_code = PackedInt32Array([ember])  # A test's write: Ember Core held by The Fallen
	w.boss_fight.fl_tk_hits = PackedInt32Array([8])
	w.refresh_build(false)
	assert_false(ElementLevelsFsf.held(w, ElementLevelsFsf.FIRE), "its fire is off")
	assert_true(_has_split(w), "the other cards still act")


# --- taking it back ---------------------------------------------------------------------------------------------------


func test_eight_hits_on_its_back_return_the_oldest_card() -> void:
	var w := _world()
	var split := NemesisLab.card(w, &"split_shot")
	_steal_one(w)
	_hp(w, 640)
	var seq := _seq(w)
	for k in 5:
		_hit_from(w, -1.0)
	assert_eq(w.boss_fight.fl_tk_hits[0], 8, "hits from the front do not count")
	assert_eq(_effects(w, FallenTheft.MARK_HIT, seq).size(), 0)
	for k in 7:
		_hit_from(w, 1.0)
	assert_eq(w.boss_fight.fl_tk_hits[0], 1, "seven on its back")
	var marks := _effects(w, FallenTheft.MARK_HIT, seq)
	assert_eq(marks.size(), 7, "an event for each")
	assert_eq(marks[6].amount, 1)
	assert_false(_has_split(w))
	var state := WorldReader.new(w).boss_fallen()
	assert_eq((state["taken"] as Array)[0]["hits_left"], 1)
	assert_true(bool(state["mark"]["on"]))
	_hit_from(w, 1.0)
	assert_true(w.boss_fight.fl_tk_code.is_empty(), "the eighth gives it back")
	var back := _effects(w, FallenTheft.RETURNED, seq)
	assert_eq(back.size(), 1)
	assert_eq(back[0].amount_applied, split)
	_assert_whole(w, "returned")
	assert_true(WorldReader.new(w).boss_fallen()["mark"].is_empty(), "the mark goes")


func test_the_back_counts_toward_the_oldest_of_two() -> void:
	var w := _world()
	var split := NemesisLab.card(w, &"split_shot")
	_steal_one(w, 650)
	w.boss_fight.fl_end = -1
	_steal_one(w, 320)
	var second := w.boss_fight.fl_tk_code[1]
	_hp(w, 310)
	for k in 8:
		_hit_from(w, 1.0)
	assert_eq(w.boss_fight.fl_tk_code, PackedInt32Array([second]), "Split Shot back first")
	assert_true(_has_split(w))
	assert_eq(w.boss_fight.fl_tk_hits[0], 8, "the next starts at eight")
	assert_ne(second, split)


# --- every way out gives every card back ------------------------------------------------------------------------------


func test_the_fallen_s_death_gives_them_back() -> void:
	var w := _world()
	_steal_one(w)
	FinalLab.end_segment(w)
	w.step(InputFrame.new())
	assert_true(w.final_fight.won, "won")
	_assert_whole(w, "its death")
	assert_eq(w.boss_fight.fl_tk_boss, -1)


func test_the_hero_s_death_gives_them_back() -> void:
	var w := _world(SEED, false, false)
	_steal_one(w)
	w.actors.hp[0] = 0
	w.actors.dead[0] = 1
	w.step(InputFrame.new())
	_assert_whole(w, "the hero dead (the recap's wand)")


func test_the_body_gone_by_the_dev_panel_gives_them_back() -> void:
	var w := _world()
	_steal_one(w)
	FinalBoss.jump(w, 2)  # The dev panel's and the Playground's jump: the body leaves with no kill
	_assert_whole(w, "the body dissolved")
	assert_eq(w.boss_fight.fl_tk_boss, -1)
	var k := _world(SEED + 2)
	_steal_one(k)
	var i := FinalLab.body(k)
	k.actors.invuln[i] = 0
	var at := k.actors.pos(i)
	Damage.hit(k, i, k.actors.hp[i] * 10, 0, 0, k.take_root(), 0, at, at)  # The dev panel's Kill boss
	k.step(InputFrame.new())
	k.step(InputFrame.new())
	_assert_whole(k, "Kill boss")


func test_a_snapshot_mid_theft_restores_it_exactly() -> void:
	for stage in ["cast", "held"]:
		var run := FinalLab.run_state(SEED + 3, &"gun")
		var w := FinalLab.arena(run)
		w.actors.invuln[0] = NemesisLab.LONG
		NemesisLab.grant(w, GUN_CARDS)
		FinalLab.past_rise(w)
		FinalBoss.jump(w, 2)
		FinalLab.past_rise(w)
		_quiet_mechanics(w)
		_hp(w, 650)
		for k in 900:
			w.step(InputFrame.new())
			if stage == "cast" and FallenTheft.casting(w):
				break
			if stage == "held" and not w.boss_fight.fl_tk_code.is_empty():
				break
		if stage == "held":
			_hit_from(w, 1.0)
			_hit_from(w, 1.0)
		var snap := w.to_snapshot()
		var w2 := FinalLab.arena(run, false)
		assert_eq(WorldSnapshot.apply(w2, snap), "", stage + ": restores")
		assert_eq(w2.state_hash(), w.state_hash(), stage + ": the same hash")
		assert_eq(w2.boss_fight.fl_tk_code, w.boss_fight.fl_tk_code, stage)
		assert_eq(w2.boss_fight.fl_tk_hits, w.boss_fight.fl_tk_hits, stage)
		assert_eq(w2.boss_fight.fl_tk_from, w.boss_fight.fl_tk_from, stage)
		assert_eq(_has_split(w2), _has_split(w), stage + ": the card does what it did")
		for k in 300:
			w.step(InputFrame.new())
			w2.step(InputFrame.new())
		assert_eq(w2.state_hash(), w.state_hash(), stage + ": the same after")
		assert_false(_has_split(w2), stage + ": still held")


func test_a_run_carried_on_holds_the_whole_wand() -> void:
	var run := FinalLab.run_state(SEED + 4, &"gun")
	var w := _world(SEED + 4)
	_steal_one(w)
	var carry := RunCarry.take(w, 0)
	assert_eq(carry[&"mod_slots"], w.mod_slots, "the carry holds the wand as it is")
	run.loop = 2  # The run's end and a new loop after the final boss: a new world from the carry
	var next := FinalLab.arena(run, false)
	RunCarry.apply(next, carry)
	_assert_whole(next, "a new world")


func test_a_theft_is_deterministic() -> void:
	var hashes := []
	for n in 2:
		var w := _world(SEED + 5)
		_steal_one(w)
		for k in 6:
			_hit_from(w, 1.0)
		for k in 200:
			w.step(InputFrame.new())
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])
