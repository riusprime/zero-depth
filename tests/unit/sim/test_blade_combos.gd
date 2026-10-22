extends GutTest
## v0.8.0 BL (docs/roadmap/v0.8.0/BLADE_AUDIT.md, rows B1–B6 approved by the owner 2026-10-14; PLAN row O10): the
## Blade's cards multiply like the Gun's, and the Gun's top end stops multiplying past its first generation.
## - B1: Double Slash +1 repeat a level (each 70 %), Wave +1 crescent a level, Split Wave +1 split a level.
## - B2: Heavy's slowdown, Flurry's damage loss and Thrust's narrow arc shrink from level 3 and are gone at level 5.
## - B3: a Blade slash's hit triggers cast twice (the Gun's once).
## - B4: Blade Storm (2 returning blades a slash, +1 a level) and Riposte Chain (a kill slashes on, 2 in a chain, +1).
## - B5: a mod draw weighs the run's own weapon's wand cards ×1.5 against the shared ones.
## - B6: Split's splits (and anything built from Split or Explosive) neither split nor explode; Explosive's blasts
##   past 8 in one tick merge when they overlap one already set off.
## Mechanics only: no bot, no balance (P1).

const FAR_HP := 100000


func _code(w: World, id: StringName) -> int:
	return WandLab.code(w, id)


func _at(w: World, id: StringName, lvl: int) -> void:
	assert_true(CardLevels.set_level(w, _code(w, id), lvl), "%s to level %d" % [id, lvl])


func _hook(s: AttackSpec, id: StringName) -> AttackHook:
	for k in s.hooks:
		if k.id == id:
			return k
	return null


func _hooks(s: AttackSpec, id: StringName) -> Array[AttackHook]:
	var out: Array[AttackHook] = []
	for k in s.hooks:
		if k.id == id:
			out.append(k)
	return out


## A Blade world holding `ids` (in that wand order) with dummies at `spots` (hp each `hp`), facing +x, no walls.
func _solo(ids: Array, spots: Array, hp: int = FAR_HP) -> World:
	var w := WandLab.world(&"blade")
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	for id: StringName in ids:
		w.add_item(AttackScenario.item_index(w.item_tables, id))
	WandLab.set_order(w, ids)
	for p: Vector2 in spots:
		w.add_dummy(p, 0.35, hp)
	return w


## Presses Primary once (aim +x, standing still) and runs `ticks` ticks: the player's HIT events by effect id.
func _swing(w: World, ticks: int) -> Dictionary:
	var seen := w.last_event_seq()
	var pid := w.actors.ids[0]
	var hits := {}
	for t in ticks:
		var pressed := InputFrame.PRIMARY if t == 0 else 0
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, pressed))
		for e in w.events_since(seen):
			seen = e.seq
			if e.kind == SimEvent.Kind.HIT and e.owner_id == pid and e.target_id != pid:
				hits[e.effect_id] = int(hits.get(e.effect_id, 0)) + 1
	return hits


# --- B1 --------------------------------------------------------------------------------------------------------
func test_b1_double_slash_repeats_once_more_each_level_at_60_percent() -> void:
	for lvl in range(1, 6):
		var w := _solo([&"double_slash"], [Vector2(1.3, 0.0)])
		_at(w, &"double_slash", lvl)
		var s := Modifiers.step(w, 0)
		assert_eq(s.repeats, lvl, "level %d: %d repeats" % [lvl, lvl])
		assert_eq(s.repeat_damage_permille, 600, "level %d: each at 60 %% (v0.8.0 MR)" % lvl)
		var hits := _swing(w, 90)
		assert_eq(
			int(hits.get(ItemEffects.EFFECT_TWIN_ARC, 0)),
			lvl,
			"level %d: the dummy takes the slash and %d mirrored repeats" % [lvl, lvl]
		)
		assert_eq(int(hits.get(&"", 0)), 1, "level %d: the slash itself once" % lvl)


func test_b1_a_repeat_deals_60_percent_of_the_slash() -> void:
	var w := _solo([&"double_slash"], [Vector2(1.3, 0.0)])
	_at(w, &"double_slash", 3)
	var seen := w.last_event_seq()
	var dmg := {}
	for t in 90:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY if t == 0 else 0))
		for e in w.events_since(seen):
			seen = e.seq
			if e.kind == SimEvent.Kind.DAMAGE and e.target_id != w.actors.ids[0]:
				if not dmg.has(e.effect_id):
					dmg[e.effect_id] = []
				(dmg[e.effect_id] as Array).append(e.amount)
	var slash: int = dmg[&""][0]
	assert_eq((dmg[ItemEffects.EFFECT_TWIN_ARC] as Array).size(), 3)
	for v: int in dmg[ItemEffects.EFFECT_TWIN_ARC]:
		assert_eq(v, maxi(1, slash * 600 / 1000), "each repeat: 60 % of the slash (v0.8.0 MR)")


func test_b1_the_next_swing_does_not_cancel_the_queued_repeats() -> void:
	var w := _solo([&"double_slash"], [Vector2(1.3, 0.0)])
	_at(w, &"double_slash", 5)
	var seen := w.last_event_seq()
	var echoes := 0
	var slashes := 0
	for t in 120:  # a press every 9 ticks: a swing starts before the five repeats are done
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY if t % 9 == 0 else 0))
		for e in w.events_since(seen):
			seen = e.seq
			if e.kind != SimEvent.Kind.HIT or e.owner_id != w.actors.ids[0]:
				continue
			if e.effect_id == ItemEffects.EFFECT_TWIN_ARC:
				echoes += 1
			elif e.effect_id == &"":
				slashes += 1
	assert_gt(slashes, 2, "several swings")
	assert_gte(echoes, (slashes - 1) * 5, "every finished swing's five repeats land")


func test_b1_wave_throws_one_more_crescent_each_level() -> void:
	var w := WandLab.fight(&"blade", [&"echo_slash"])
	var spreads := []
	for lvl in range(1, 6):
		_at(w, &"echo_slash", lvl)
		var k := _hook(Modifiers.step(w, 0), &"echo_slash")
		assert_eq(k.child.count, lvl, "level %d: %d crescents" % [lvl, lvl])
		spreads.append(k.child.spread)
	assert_eq(spreads[0], 0, "one crescent: no fan")
	for j in range(1, 5):
		assert_gt(spreads[j], spreads[j - 1], "the fan widens with the count")
	assert_gt(int(WandLab.run(w, 300)["hits_by_effect"].get(&"echo_slash", 0)), 0)


func test_b1_split_wave_splits_into_one_more_each_level() -> void:
	var w := WandLab.fight(&"blade", [&"echo_slash", &"split_wave"])
	for lvl in range(1, 6):
		_at(w, &"split_wave", lvl)
		var crescent := _hook(Modifiers.step(w, 0), &"echo_slash").child
		assert_eq(_hook(crescent, &"split_wave").child.count, 2 + lvl, "level %d" % lvl)


# --- B2 --------------------------------------------------------------------------------------------------------
func test_b2_heavy_slows_less_from_level_3_and_not_at_5() -> void:
	var w := WandLab.fight(&"blade", [&"heavy"])
	var got := []
	for lvl in range(1, 6):
		_at(w, &"heavy", lvl)
		got.append(Modifiers.step(w, 0).rate_bonus_permille)
	assert_eq(got, [-300, -300, -200, -100, 0], "−30 %, then 10 % less a level from level 3")
	_at(w, &"heavy", 5)
	var plain := WandLab.fight(&"blade", [])
	assert_eq(BladeForms.step(w, 0).ticks, BladeForms.step(plain, 0).ticks, "level 5: full speed")


func test_b2_flurry_deals_85_percent_at_every_level_since_mr() -> void:
	var plain := Modifiers.step(WandLab.fight(&"blade", []), 0).damage
	var w := WandLab.fight(&"blade", [&"flurry"])
	var got := []
	for lvl in range(1, 6):
		_at(w, &"flurry", lvl)
		got.append(Modifiers.step(w, 0).damage)
	# v0.8.0 MR (O91): Flurry is a burst now, ×0.85 at every level (its levels add burst swings)
	assert_eq(
		got,
		[
			plain * 850 / 1000,
			plain * 850 / 1000,
			plain * 850 / 1000,
			plain * 850 / 1000,
			plain * 850 / 1000
		]
	)


func test_b2_thrust_arc_widens_from_level_3_to_the_full_arc_at_5() -> void:
	var plain := Modifiers.step(WandLab.fight(&"blade", []), 0).half_arc
	var w := WandLab.fight(&"blade", [&"thrust"])
	var got := []
	for lvl in range(1, 6):
		_at(w, &"thrust", lvl)
		got.append(Modifiers.step(w, 0).half_arc)
	assert_eq(
		got,
		[plain * 400 / 1000, plain * 400 / 1000, plain * 600 / 1000, plain * 800 / 1000, plain],
		"×0.4, wider each level from 3, the whole arc at 5"
	)


# --- B3 --------------------------------------------------------------------------------------------------------
func test_b3_a_blade_slash_hit_casts_a_trigger_twice() -> void:
	var w := WandLab.fight(&"blade", [&"trigger_on_hit", &"shared_explosive"])
	var casts := _hooks(Modifiers.step(w, 0), &"trigger_on_hit")
	assert_eq(casts.size(), 2, "twice per slash hit")
	assert_eq(casts[0].delay_ticks, 0)
	assert_eq(casts[1].delay_ticks, w.wand_table.blade_cast_gap_ticks, "the second a moment later")
	var kill := WandLab.fight(&"blade", [&"trigger_on_kill", &"shared_explosive"])
	assert_eq(_hooks(Modifiers.step(kill, 0), &"trigger_on_kill").size(), 2, "On Kill too")
	var fin := WandLab.fight(&"blade", [&"trigger_on_finisher", &"shared_explosive"])
	var last := Modifiers.step(fin, fin.player.combo.size() - 1)
	assert_eq(_hooks(last, &"trigger_on_finisher").size(), 2, "On Finisher's hits too")


func test_b3_the_gun_and_a_slash_end_cast_once() -> void:
	var g := WandLab.fight(&"gun", [&"trigger_on_hit", &"shared_explosive"])
	assert_eq(_hooks(Modifiers.bolt(g), &"trigger_on_hit").size(), 1, "the Gun's bolt: once")
	var e := WandLab.fight(&"blade", [&"trigger_on_end", &"shared_explosive"])
	assert_eq(_hooks(Modifiers.step(e, 0), &"trigger_on_end").size(), 1, "a slash's end: once")


func test_b3_a_slash_hit_casts_the_spell_twice_in_play() -> void:
	var w := _solo([&"trigger_on_hit"], [Vector2(1.3, 0.0)])
	var hits := _swing(w, 60)
	assert_eq(int(hits.get(&"", 0)), 1, "one slash hit")
	assert_eq(int(hits.get(&"trigger_on_hit", 0)), 2, "two child slashes from it")


# --- B4 --------------------------------------------------------------------------------------------------------
func test_b4_blade_storm_throws_returning_blades_one_more_each_level() -> void:
	var w := WandLab.fight(&"blade", [&"blade_storm"])
	for lvl in range(1, 6):
		_at(w, &"blade_storm", lvl)
		var k := _hook(Modifiers.step(w, 0), &"blade_storm")
		assert_not_null(k, "every slash throws them")
		assert_eq(k.trigger, AttackSpec.Trigger.ON_LAUNCH)
		assert_eq(k.child.form, AttackSpec.Form.BOLT)
		assert_eq(k.child.count, 1 + lvl, "level %d: %d blades" % [lvl, 1 + lvl])
		assert_eq(k.child.returns, 1, "they fly out and back")
	var s := _solo([&"blade_storm"], [Vector2(2.0, 1.4), Vector2(2.0, -1.4)])  # the two blades' ways
	assert_gt(
		int(_swing(s, 60).get(&"blade_storm", 0)), 0, "the blades hit what the slash can't reach"
	)


func test_b4_riposte_chain_slashes_on_from_a_kill() -> void:
	var w := WandLab.fight(&"blade", [&"riposte_chain"])
	for lvl in range(1, 6):
		_at(w, &"riposte_chain", lvl)
		var k := _hook(Modifiers.step(w, 0), &"riposte_chain")
		assert_eq(k.trigger, AttackSpec.Trigger.ON_KILL)
		assert_true(k.child.seek, "it seeks the next enemy")
		assert_almost_eq(k.child.reach_m, 4.0, 0.001, "within 4 m")
		assert_eq(1 + k.child.chains, 1 + lvl, "level %d: %d slashes in the chain" % [lvl, 1 + lvl])
	for lvl: int in [1, 3]:
		var s := _solo([&"riposte_chain"], [Vector2(1.3, 0.0)], 1)
		for x in 5:
			s.add_dummy(Vector2(3.4 + 1.0 * x, 0.0), 0.35, FAR_HP)
		_at(s, &"riposte_chain", lvl)
		assert_eq(
			int(_swing(s, 30).get(&"riposte_chain", 0)),
			1 + lvl,
			"level %d: the kill slashes %d more enemies" % [lvl, 1 + lvl]
		)


func test_b4_the_new_cards_are_blade_wand_cards() -> void:
	for id: StringName in [&"blade_storm", &"riposte_chain"]:
		var t := WandLab.tables()[AttackScenario.item_index(WandLab.tables(), id)]
		assert_true(t.tags.has("wand"), "%s levels 1-5" % id)
		var b := WandLab.fight(&"blade", [])
		var g := WandLab.fight(&"gun", [])
		var idx := _code(b, id)
		assert_true(ItemPool.usable(b, idx), "%s: offered on a Blade run" % id)
		assert_false(ItemPool.usable(g, idx), "%s: never on a Gun run" % id)


func test_b4_the_new_cards_take_the_last_indices() -> void:
	var defs := ModifierCompiler.item_defs(WandLab.repo())
	var n := 0  # v0.8.0 RR: later index waves (Chain Blast, wave 2) come after these
	while n < defs.size() and (defs[n] as ItemDefinition).index_wave <= 1:
		n += 1
	assert_eq([defs[n - 2].id, defs[n - 1].id], [&"blade_storm", &"riposte_chain"])
	for k in n - 2:
		assert_eq((defs[k] as ItemDefinition).index_wave, 0, "%s keeps its index" % defs[k].id)
	assert_eq(defs[n - 3].id, &"trigger_on_kill_twice", "the v0.6.5 order ends where it did")
	for k in range(n, defs.size()):
		assert_gt((defs[k] as ItemDefinition).index_wave, 1, "%s: a later wave" % defs[k].id)


# --- B5 --------------------------------------------------------------------------------------------------------
func test_b5_the_runs_own_cards_weigh_one_and_a_half() -> void:
	var b := WandLab.fight(&"blade", [])
	b.reward_table = ContentCompiler.compile_rewards(WandLab.repo().get_def(&"rewards", &"floor"))
	assert_eq(b.reward_table.own_weapon_card_permille, 1500, "data/rewards/floor.tres")
	assert_eq(ItemPool.card_weight(b, _code(b, &"double_slash"), 3), 1500, "a Blade card")
	assert_eq(ItemPool.card_weight(b, _code(b, &"shared_bleed"), 3), 1000, "a shared card")
	assert_eq(ItemPool.card_weight(b, _code(b, &"trigger_on_hit"), 3), 1000, "a trigger")
	assert_eq(ItemPool.card_weight(b, _code(b, &"blade_storm"), 3), 4500, "a rare Blade card")
	var g := WandLab.fight(&"gun", [])
	assert_eq(ItemPool.card_weight(g, _code(g, &"gun_spread"), 3), 1500, "a Gun card on a Gun run")


# --- B6 --------------------------------------------------------------------------------------------------------
func test_b6_splits_neither_split_nor_explode_again() -> void:
	var w := WandLab.fight(&"gun", [&"gun_spread", &"split_shot", &"shared_explosive"])
	var bolt := Modifiers.bolt(w)
	assert_not_null(_hook(bolt, &"split_shot"), "the shot splits")
	assert_not_null(_hook(bolt, &"shared_explosive"), "the shot explodes")
	var split := _hook(bolt, &"split_shot").child
	assert_null(_hook(split, &"shared_explosive"), "its splits don't explode")
	assert_null(_hook(split, &"split_shot"), "nor split")


func test_b6_a_split_cast_does_not_explode_but_the_shots_cast_does() -> void:
	var w := WandLab.fight(&"gun", [&"split_shot", &"trigger_on_hit", &"shared_explosive"])
	var bolt := Modifiers.bolt(w)
	var cast := _hook(bolt, &"trigger_on_hit").child
	assert_not_null(_hook(cast, &"shared_explosive"), "the shot's hit casts an exploding spell")
	var split := _hook(bolt, &"split_shot").child
	var split_cast := _hook(split, &"trigger_on_hit").child
	assert_null(_hook(split_cast, &"shared_explosive"), "a split's cast: no blast again")


func test_b6_blasts_past_eight_in_a_tick_merge_when_they_overlap() -> void:
	var w := WandLab.world(&"gun")
	var k := AttackHook.new()
	k.id = &"shared_explosive"
	k.child = AttackSpec.new()
	k.child.radius_m = 1.4
	var got := []
	for n in 11:
		got.append(Attacks.merged(w, k, Vector2(0.1 * n, 0.0)))
	assert_eq(got, [false, false, false, false, false, false, false, false, true, true, true])
	assert_false(Attacks.merged(w, k, Vector2(9.0, 0.0)), "a blast away from the others goes off")
	assert_eq(w.blast_merged, 3)
	var other := AttackHook.new()
	other.id = &"split_shot"
	other.child = k.child
	assert_false(Attacks.merged(w, other, Vector2.ZERO), "only Explosive's blasts merge")
	w.tick += 1
	assert_false(Attacks.merged(w, k, Vector2.ZERO), "a new tick starts again")


func test_b6_the_owners_build_merges_blasts_in_play() -> void:
	# v0.8.0 MR: Spread is +1 a level now (7 at level 5), so Halo joins to keep a big volley (7 × 3 × 2 = 42 bolts)
	var w := WandLab.fight(&"gun", [&"gun_spread", &"halo_shot", &"shared_explosive", &"gun_twin"])
	_at(w, &"gun_spread", 5)
	var merged := 0
	for t in 300:
		w.step(AttackScenario.frame(t))
		if w.blast_tick == w.tick - 1:
			merged += w.blast_merged
			assert_lte(w.blast_pos.size(), 64, "the per-tick marks stay small")
	assert_gt(merged, 0, "42 bolts a volley: the blasts past 8 that overlap merge")
