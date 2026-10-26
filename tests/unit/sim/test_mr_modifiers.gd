extends GutTest
## v0.8.0 MR (owner O91; docs/roadmap/v0.8.0/BALANCE_PASS.md "MR"; WAND.md rules 10–11; SIM_CONTRACTS §8k): the existing
## modifiers reworked. Extra bolts and repeats share the damage and run at the secondary proc; a repeat never repeats
## (no later cast); Rapid Fire ramps while held, Flurry is a burst after a pause; Split Wave works without Wave; a card
## that can't act where it sits is flagged. Mechanics only: no bot, no balance (P1).

const W := preload("res://tests/support/mx4_world.gd")
const FAR_HP := 100000


func _mine(w: World) -> Array[int]:
	var out: Array[int] = []
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			out.append(i)
	return out


func _at(w: World, id: StringName, lvl: int) -> void:
	assert_true(CardLevels.set_level(w, WandLab.code(w, id), lvl), "%s to level %d" % [id, lvl])


func _hooks(s: AttackSpec, id: StringName) -> Array[AttackHook]:
	var out: Array[AttackHook] = []
	for k in s.hooks:
		if k.id == id:
			out.append(k)
	return out


## A world of `weapon` holding `ids` in that wand order, with dummies at `spots`, facing +x, no walls.
func _solo(weapon: StringName, ids: Array, spots: Array, hp: int = FAR_HP) -> World:
	var w := WandLab.world(weapon)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	for id: StringName in ids:
		w.add_item(AttackScenario.item_index(w.item_tables, id))
	WandLab.set_order(w, ids)
	for p: Vector2 in spots:
		w.add_dummy(p, 0.35, hp)
	return w


## Presses Primary once (aim +x) and runs `ticks` ticks: the player's HIT events by effect id.
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


func _plain_bolt_damage() -> int:
	var p := W.world(&"gun")
	W.run(p, 1, 0, W.S)
	return p.projectiles.damage[_mine(p)[0]]


# --- 1. Shares and the secondary proc --------------------------------------------------------------------------
func test_twin_lanes_each_deal_sixty_percent_and_the_second_is_secondary() -> void:
	var d := _plain_bolt_damage()
	var w := W.world(&"gun", [&"gun_twin"])
	assert_eq(Modifiers.bolt(w).share_permille, 700)  # v0.9.5 CLV: Twin level 1 is 70 %
	W.run(w, 1, 0, W.S)
	var m := _mine(w)
	assert_eq(m.size(), 2)
	for i in m:
		assert_eq(w.projectiles.damage[i], maxi(1, (d * 700 + 500) / 1000), "each lane 70 %")
	assert_eq(w.projectiles.second_of(m[0]), 0, "the first lane is the primary")
	assert_eq(
		w.projectiles.second_of(m[1]), ProjectileStore.SECONDARY, "the second lane is secondary"
	)


## v0.9.0 TW (owner Q8: Twin and Spread merged; "+10 % per level"; "Side by side, fan at 3"): two copies at levels
## 1–4 at 60 / 70 / 80 / 90 % each, three at level 5 at 70 % each; two side by side, three fanned from one point.
func test_twin_copies_and_share_by_level() -> void:
	var d := _plain_bolt_damage()
	var w := W.world(&"gun", [&"gun_twin"])
	var got := []
	# v0.9.5 CLV: Twin has 3 levels: 2 copies at 70 %, 2 at 90 %, 3 at 75 %
	for lvl in range(1, 4):
		_at(w, &"gun_twin", lvl)
		var s := Modifiers.bolt(w)
		got.append([s.twin + 1, s.share_permille])
	assert_eq(got, [[2, 700], [2, 900], [3, 750]])
	W.run(w, 1, 0, W.S)
	var m := _mine(w)
	assert_eq(m.size(), 3, "level 3: three copies")
	var p := w.projectiles
	var turns := []
	for i in m:
		assert_eq(p.damage[i], maxi(1, (d * 750 + 500) / 1000), "each copy 75 %")
		turns.append(Kin.angle_of(Vector2(p.vel_x[i], p.vel_y[i])))
	turns.sort()  # 0 (straight), then one fanned left (+), then one fanned right (just under a full turn)
	assert_eq(turns[0], 0, "the middle copy flies straight")
	assert_almost_eq(turns[1], GunForms.TWIN_FAN, 1, "one fans one way")
	assert_almost_eq(4096 - turns[2], GunForms.TWIN_FAN, 1, "the other the other way")
	var kinds := []
	for i in m:
		kinds.append(p.second_of(i))
	assert_eq(
		kinds, [ProjectileStore.SECONDARY, 0, ProjectileStore.SECONDARY], "the middle is primary"
	)


func test_twin_two_copies_fly_side_by_side() -> void:
	var w := W.world(&"gun", [&"gun_twin"])
	_at(w, &"gun_twin", 2)  # v0.9.5 CLV: two copies at levels 1-2 (level 3 fans three)
	W.run(w, 1, 0, W.S)
	var m := _mine(w)
	assert_eq(m.size(), 2)
	var p := w.projectiles
	for i in m:
		assert_eq(Kin.angle_of(Vector2(p.vel_x[i], p.vel_y[i])), 0, "parallel")
	assert_gt(absf(p.pos_y[m[0]] - p.pos_y[m[1]]), 0.1, "apart, across the aim")


func test_spread_is_two_more_then_one_a_level_each_bolt_a_share() -> void:
	var d := _plain_bolt_damage()
	var w := W.world(&"gun", [&"gun_spread"])
	var got := []
	for lvl in range(1, 6):
		_at(w, &"gun_spread", lvl)
		var s := Modifiers.bolt(w)
		got.append([s.count, s.share_permille])
	assert_eq(got, [[3, 550], [4, 580], [5, 610], [6, 640], [7, 670]])
	_at(w, &"gun_spread", 1)
	W.run(w, 1, 0, W.S)
	var m := _mine(w)
	assert_eq(m.size(), 3)
	var kinds := []
	for i in m:
		# v0.8.0 RM lead fix: a share rounds half up (Attacks._shared_form).
		assert_eq(w.projectiles.damage[i], maxi(1, (d * 550 + 500) / 1000), "each bolt 55 %")
		kinds.append(w.projectiles.second_of(i))
	assert_eq(kinds, [1, 0, 1], "only the centre bolt is primary")


func test_halo_ring_bolts_deal_forty_percent() -> void:
	var d := _plain_bolt_damage()
	var w := W.world(&"gun", [&"halo_shot"])
	assert_eq(Modifiers.bolt(w).share_permille, 400)
	W.run(w, 1, 0, W.S)
	var m := _mine(w)
	assert_eq(m.size(), 4)  # v0.9.5 CLV: Halo level 1 is 4 bolts
	assert_eq(w.projectiles.damage[m[0]], maxi(1, d * 400 / 1000))
	assert_eq(
		[w.projectiles.second_of(m[0]), w.projectiles.second_of(m[1])],
		[0, ProjectileStore.SECONDARY],
		"the ring's first bolt is the primary"
	)


func test_shares_multiply_down_the_wand_and_the_view_weighs_them() -> void:
	var w := W.world(&"gun", [&"gun_twin", &"gun_spread"])
	var s := Modifiers.bolt(w)
	# v0.9.5 CLV: Twin level 1 is 70 %
	assert_eq(s.share_permille, 700 * 550 / 1000)
	assert_eq(s.damage_mul_permille, 700 * 550 / 1000, "the view's weight is each bolt's")


func test_echo_repeats_at_half_as_a_secondary_repeat() -> void:
	var w := W.world(&"gun", [&"gun_echo"])
	var s := Modifiers.bolt(w)
	assert_eq(s.repeat_damage_permille, 600)  # v0.9.5 CLV: Echo is fixed at 60 %
	W.run(w, 1, 0, W.S)
	W.run(w, 18)
	var m := _mine(w)
	assert_eq(m.size(), 2)
	assert_eq(w.projectiles.damage[m[1]], s.damage * 600 / 1000)
	assert_eq(
		w.projectiles.second_of(m[1]),
		ProjectileStore.SECONDARY | ProjectileStore.REPEAT,
		"secondary, and a repeat's"
	)
	# v0.9.5 CLV: one level, no +5 % a level
	assert_eq(Modifiers.bolt(w).repeat_damage_permille, 600, "no growth")


func test_double_slash_repeats_at_sixty_percent() -> void:
	var w := WandLab.fight(&"blade", [&"double_slash"])
	assert_eq(Modifiers.step(w, 0).repeat_damage_permille, 600)


func test_secondary_stacks_round_down_and_carry_the_rest() -> void:
	var w := W.world(&"gun")
	var got := []
	for k in 4:
		got.append(SecondaryProc.stacks(w, 1, 500))
	assert_eq(got, [0, 1, 0, 1], "a 1-stack feed at 50 %: every other one")
	assert_eq(SecondaryProc.stacks(w, 3, 1000), 3, "a primary feeds whole")
	assert_eq(SecondaryProc.stacks(w, 3, 500), 1, "3 × 0.5 = 1.5: 1 now")
	assert_eq(SecondaryProc.stacks(w, 1, 500), 1, "the half owed comes next")
	assert_eq(w.mx.sec_carry, 0)
	assert_eq(SecondaryProc.permille(w), 500, "data/wand/wand.tres")


func test_a_secondary_lane_feeds_half_the_bleed() -> void:
	var full := -1
	var half := -1
	for pm: int in [1000, 500]:
		var w := _solo(&"gun", [&"gun_twin", &"shared_bleed"], [Vector2(2.0, 0.0)])
		var t := WandTable.new()
		t.secondary_proc_permille = pm
		w.wand_table = t
		var stacks := 0
		for k in 30:
			w.step(InputFrame.make(Vector2i.ZERO, 0, 300, InputFrame.SHOOT if k == 0 else 0, 0))
			stacks = maxi(stacks, w.actors.bleed_stacks[1])
		if pm == 1000:
			full = stacks
		else:
			half = stacks
	assert_gt(full, 0, "Twin's two lanes bleed")
	assert_lt(half, full, "the second lane at 50 % feeds less")


# --- 2. A repeat never repeats -------------------------------------------------------------------------------
func test_a_later_cast_is_a_repeat_and_casts_its_triggers_once() -> void:
	var w := WandLab.fight(&"blade", [&"trigger_on_hit", &"trigger_on_kill", &"shared_explosive"])
	var casts := _hooks(Modifiers.step(w, 0), &"trigger_on_hit")
	assert_eq(casts.size(), 2, "a slash hit casts twice")
	assert_eq([casts[0].child.recast, casts[1].child.recast], [0, 1], "the second cast is a repeat")
	assert_eq(
		_hooks(casts[0].child, &"trigger_on_kill").size(), 2, "the first cast's slash casts twice"
	)
	assert_eq(_hooks(casts[1].child, &"trigger_on_kill").size(), 1, "the repeat's casts once")


func test_a_double_slash_echo_launches_no_later_cast() -> void:
	var w := _solo(&"blade", [&"double_slash", &"trigger_on_hit"], [Vector2(1.3, 0.0)])
	var hits := _swing(w, 90)
	assert_eq(int(hits.get(&"", 0)), 1, "one slash")
	assert_eq(int(hits.get(ItemEffects.EFFECT_TWIN_ARC, 0)), 1, "one echo")
	assert_eq(int(hits.get(&"trigger_on_hit", 0)), 3, "the slash casts twice, its echo once")


# --- 3. Rapid Fire and Flurry --------------------------------------------------------------------------------
func test_rapid_fire_ramps_while_held_and_resets_after_a_pause() -> void:
	var w := W.world(&"gun", [&"gun_rapid_fire"])
	var s := Modifiers.bolt(w)
	assert_eq(
		[s.rate_bonus_permille, s.ramp_permille, s.ramp_cap_permille, s.ramp_reset_ticks],
		[300, 100, 900, 24]  # v0.9.5 CLV: Rapid Fire's cap is fixed at 900
	)
	assert_eq(s.damage, Modifiers.bolt(W.world(&"gun")).damage * 850 / 1000)
	var gaps := _shot_gaps(w, 150)
	assert_gt(gaps.size(), 8)
	assert_lt(gaps[gaps.size() - 1], gaps[0], "held fire comes faster: %s" % [gaps])
	for k in range(1, gaps.size()):
		assert_lte(gaps[k], gaps[k - 1], "never slower while held")
	W.run(w, 40)  # a pause past 0.4 s
	var again := _shot_gaps(w, 40)
	assert_eq(again[0], gaps[0], "the ramp starts over")
	# v0.9.5 CLV: one level, no cap growth (a level asked for past the max stays at it)
	assert_eq(Modifiers.bolt(w).ramp_cap_permille, 900, "no cap growth")


## Holds Shoot `ticks` ticks: the gaps (ticks) between the player's shots.
func _shot_gaps(w: World, ticks: int) -> Array:
	var seen := w.last_event_seq()
	var at := []
	for t in ticks:
		w.step(W.frame(0, W.S))
		var shot := false
		for e in w.events_since(seen):
			seen = e.seq
			shot = shot or e.kind == SimEvent.Kind.SPAWN
		if shot:
			at.append(w.tick)
	var gaps := []
	for k in range(1, at.size()):
		gaps.append(at[k] - at[k - 1])
	return gaps


func test_flurry_is_a_burst_of_three_swings_after_a_pause() -> void:
	var w := _solo(&"blade", [&"flurry"], [])
	var plain := _solo(&"blade", [], [])
	var s := Modifiers.step(w, 0)
	assert_eq(
		[s.burst_permille, s.burst_swings, s.burst_pause_ticks, s.rate_bonus_permille],
		[800, 3, 36, 0]
	)
	assert_eq(s.damage, Modifiers.step(plain, 0).damage * 850 / 1000, "×0.85 at every level")
	var places := []
	var fast := []
	for t in 200:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY))
		if w.swing_t == 1:
			places.append(w.mx.burst_n)
			var k := w.combo_step
			fast.append(BladeForms.step(w, k).ticks < BladeForms.step(plain, k).ticks)
	assert_gt(places.size(), 4)
	assert_eq(places.slice(0, 4), [1, 2, 3, 4], "the burst's swings, then the rest")
	assert_eq(fast.slice(0, 4), [true, true, true, false], "the first three come faster")
	W.run(w, 80)  # a pause past 0.6 s
	w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY))
	assert_eq(w.mx.burst_n, 1, "after a pause the burst starts over")
	var swings := []
	for lvl in range(1, 6):
		_at(w, &"flurry", lvl)
		swings.append(Modifiers.step(w, 0).burst_swings)
	assert_eq(swings, [3, 3, 4, 4, 5], "+1 burst swing at levels 3 and 5")


# --- 4. Split Wave without Wave ------------------------------------------------------------------------------
func test_split_wave_alone_throws_crescents_from_each_slash_hit() -> void:
	var w := WandLab.fight(&"blade", [&"split_wave"])
	var k := _hooks(Modifiers.step(w, 0), &"split_wave")
	assert_eq(k.size(), 1, "the slash itself throws them")
	assert_eq(
		[k[0].trigger, k[0].child.form, k[0].child.count, k[0].damage_permille],
		[AttackSpec.Trigger.ON_HIT, AttackSpec.Form.BOLT, 2, 400]
	)
	_at(w, &"split_wave", 2)
	k = _hooks(Modifiers.step(w, 0), &"split_wave")
	assert_eq([k[0].child.count, k[0].damage_permille], [3, 450], "+1 crescent, +5 % a level")
	var waved := WandLab.fight(&"blade", [&"echo_slash", &"split_wave"])
	assert_eq(
		_hooks(Modifiers.step(waved, 0), &"split_wave").size(), 0, "with a wave: not the slash"
	)
	var crescent := _hooks(Modifiers.step(waved, 0), &"echo_slash")[0].child
	assert_eq(_hooks(crescent, &"split_wave")[0].child.count, 3, "it splits the wave as before")
	var play := _solo(
		&"blade", [&"split_wave"], [Vector2(1.3, 0.0), Vector2(2.4, 0.65), Vector2(2.4, -0.65)]
	)
	assert_gt(
		int(_swing(play, 60).get(&"split_wave", 0)), 0, "the crescents hit past the first enemy"
	)


# --- 5. Placement flags --------------------------------------------------------------------------------------
func test_echo_double_slash_and_charge_right_of_a_trigger_are_flagged() -> void:
	for pair: Array in [
		[&"gun", &"gun_echo"], [&"gun", &"gun_charge"], [&"blade", &"double_slash"]
	]:
		var after := WandLab.fight(pair[0], [&"trigger_on_hit", pair[1]])
		var read := Wand.read(after)
		assert_eq(Wand.flags(read), [&"", Wand.DEAD_AFTER_TRIGGER], "%s after a trigger" % pair[1])
		var lines := Wand.describe(read)
		assert_eq(lines[lines.size() - 1]["key"], &"WAND_READ_DEAD", "the read-back says so")
		var before := WandLab.fight(pair[0], [pair[1], &"trigger_on_hit"])
		assert_eq(Wand.flags(Wand.read(before)), [&"", &""], "%s before it acts" % pair[1])
	var moved := WorldReader.wand_moved(
		Wand.read(WandLab.fight(&"gun", [&"gun_echo", &"trigger_on_hit"])), 0, 1
	)
	assert_eq(Wand.flags(moved), [&"", Wand.DEAD_AFTER_TRIGGER], "a preview flags it too")


func test_flag_keys_have_text() -> void:
	for key: StringName in [Wand.DEAD_AFTER_TRIGGER, Wand.DEAD_TOO_DEEP, &"WAND_READ_DEAD"]:
		assert_ne(tr(key), String(key), "%s has an en text" % key)
