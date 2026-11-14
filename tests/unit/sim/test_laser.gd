# gdlint: disable=max-public-methods
extends GutTest
## v0.9.0 LZ (owner C §6.2, Q8; PLAN C48–C50, C72; ATTACK_FORMS.md F2): the Laser form. v0.11.0 O1 (owner, PLAN L1,
## L3b; Q4–Q7, Q28): the Laser is a lance. Held, it fires one shot every 3 s (the first at once, no release needed),
## each dealing 3 s of the old beam's damage (30 old ticks); it is instant and passes every enemy on its path (a wall
## stops it), reaches 9 m; Twin gives 2 lances (3 at Lv 5); attack speed shortens the 3 s at half its value; the hero
## moves at full speed while it is held (O1c); each enemy after the first takes 15 % less (O1c); each enemy hit is fed 3
## hits' worth of its statuses, its hit hooks fire once.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
## The shot period: 3 s.
const PERIOD := 180
## The old beam's tick on a dummy (v0.10.5 W3-P5: 1000 per mille of the orb's 5) and the lance's 19 of them (O1d: -35
## %).
const TICK := 5
const SHOT := 95
## ATTACK_FORMS.md F2: Twin on; Halo, Ring, Backfire, Spiral, Swirl off; every Secondary off (v0.11.0 O1: Pierce and
## Mine too, Q6, Q28); the five elements on (Void, gravity_well, leaves in VP: off).
const LASER_ON: Array[StringName] = [
	&"gun_twin",
	&"halo_shot",  # v0.9.5 FC1: the cards LaserMods reads
	&"gun_ring",
	&"gun_backfire",
	&"gun_ricochet",
	&"gun_homing",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_spiral",
	&"ember_core",
	&"storm_core",
	&"frost_core",
	&"venom_core",
	&"shared_bleed"
]


## A Gun world holding `items` (the Laser first unless `orbs`) and a dummy at each of `at` (x on the aim's line).
func _world(items: Array = [], at: Array = [4.0], orbs: bool = false) -> World:
	var enemies := []
	for x: float in at:
		enemies.append([Vector2(x, 0.0), HP])
	var ids: Array = [] if orbs else [&"gun_laser"]
	ids.append_array(items)
	return W.world(&"gun", ids, enemies)


## The direct (not damage-over-time) damage the player dealt to actor `idx`, in ticks [from, to): [hits, total].
func _dealt(w: World, idx: int, from: int = 0, to: int = 1 << 30) -> Array:
	var id := w.actors.ids[idx]
	var total := 0
	var n := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id != id or e.tags & SimEvent.TAG_DOT or e.tick < from or e.tick >= to:
			continue
		total += e.amount
		n += 1
	return [n, total]


## The ticks of the direct hits on actor `idx`, in order.
func _ticks(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			out.append(e.tick)
	return out


func test_the_card_makes_the_guns_shot_a_lance_every_3_s() -> void:
	var w := _world()
	var s := Modifiers.bolt(w)
	assert_true(Laser.held(s))
	assert_eq(s.form, AttackSpec.Form.BEAM)
	assert_eq(s.period_ticks, PERIOD, "one shot every 3 s (owner L1)")
	assert_almost_eq(s.reach_m, 9.0, 0.001, "9 m")
	assert_eq([s.beam_permille, s.rate_scale_permille, s.move_permille], [1000, 500, 0])  # W3-P5; O1c: no slow
	var it := w.item_tables[W.item(w, &"gun_laser")]
	assert_eq(it.slot_category, AttackSlots.FORM, "a Form card")
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_laser")
	assert_eq(def.rarity, ItemDefinition.Rarity.RARE)
	assert_eq(def.requires_weapon, &"gun", "Gun only (Q6)")


func test_held_it_fires_once_every_3_s_without_a_release() -> void:
	var w := _world()
	W.run(w, 4 * PERIOD, 0, W.S)
	var ticks := _ticks(w, 1)
	assert_eq(ticks.size(), 4, "4 shots in 12 s held, the first at once")
	for k in range(1, ticks.size()):
		assert_eq(int(ticks[k]) - int(ticks[k - 1]), PERIOD, "3 s apart")
	assert_lt(int(ticks[0]), 3, "the first shot comes at once")


func test_a_shot_deals_3_s_of_the_old_beam_and_matches_its_dps() -> void:
	var w := _world()
	var s := Modifiers.bolt(w)
	assert_eq(
		LaserMods.param(w, "lance_ticks"), 19, "O1d: was 30, 3 s at the old 10 ticks a second"
	)
	assert_eq(Laser.shot_damage(w, Laser.milli_of(s, TICK)), 19 * TICK, "19 x the old tick")
	W.run(w, 10 * PERIOD, 0, W.S)
	var lance := _dealt(w, 1)
	assert_eq(lance, [10, 10 * SHOT], "10 shots of 95 in 30 s")
	assert_eq(lance[1], 190 * TICK, "O1d: 190 of the old beam's ticks of 5 in 30 s (was 300)")
	var o := _world([], [4.0], true)
	W.run(o, 10 * PERIOD, 0, W.S)
	var orbs := _dealt(o, 1)
	gut.p(
		(
			"O1 one target, 30 s held: lance %d dmg in %d shots, orbs %d dmg"
			% [lance[1], lance[0], orbs[1]]
		)
	)


func test_the_lance_pierces_every_enemy_in_a_line_of_six() -> void:
	var w := _world([], [1.5, 2.5, 3.5, 4.5, 5.5, 6.5])
	W.run(w, 2, 0, W.S)
	for k in range(1, 7):
		assert_eq(
			_dealt(w, k), [1, _fall(SHOT, k - 1)], "enemy %d takes its share of the shot once" % k
		)  # O1c: falloff


func test_crit_rolls_once_per_enemy_hit() -> void:
	var w := _world([], [1.5, 2.5, 3.5, 4.5, 5.5, 6.5])
	w.player.crit_chance_permille = 500
	W.run(w, 2, 0, W.S)
	var crits := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		crits += 1 if e.tags & SimEvent.TAG_CRIT else 0
	for k in range(1, 7):
		assert_eq(_dealt(w, k)[0], 1, "enemy %d: one hit, one roll" % k)
	gut.p("O1 crit at 50 %%: %d of 6 hits" % crits)
	assert_between(crits, 1, 5, "the rolls differ by enemy (seed 9)")


func test_a_wall_stops_the_lance_and_it_reaches_nine_metres() -> void:
	var w := _world([], [1.0, 4.0])
	w.add_wall_now(Obb.make(Vector2(2.0, 0.0), Vector2(0.2, 2.0), 0))
	W.run(w, 60, 0, W.S)
	assert_eq(_dealt(w, 1)[0], 1, "before the wall: hit")
	assert_eq(_dealt(w, 2)[1], 0, "behind the wall: not")
	var b: Dictionary = Laser.trace(w, Modifiers.bolt(w), w.player_pos(), 0)[0]
	assert_true(b["wall"])
	assert_lt((b["to"] as Vector2).x, 2.0, "it ends at the wall")
	var far := _world([], [10.0])
	var near := _world([], [9.0])
	W.run(far, 30, 0, W.S)
	W.run(near, 30, 0, W.S)
	assert_eq(_dealt(far, 1)[1], 0, "past 9 m (its near edge 9.65 m out)")
	assert_gt(_dealt(near, 1)[1], 0, "within 9 m")


func test_twin_gives_two_lances_and_three_at_level_three() -> void:
	var w := _world([&"gun_twin"], [])
	var twin := W.item(w, &"gun_twin")
	var expect := {1: [2, 700], 2: [2, 900], 3: [3, 750]}
	for lvl: int in expect:
		CardLevels.set_level(w, twin, lvl)
		var s := Modifiers.bolt(w)
		var beams := Laser.trace(w, s, w.player_pos(), 0)
		assert_eq([beams.size(), s.share_permille], expect[lvl], "Twin Lv %d" % lvl)
		assert_eq(
			Laser.milli_of(s, 5), 5 * int(expect[lvl][1]), "each lance's share of the old tick"
		)
	var two := _world([&"gun_twin"], [])
	var p: Array[Dictionary] = Laser.trace(two, Modifiers.bolt(two), two.player_pos(), 0)
	var gap := (p[1]["from"] as Vector2) - (p[0]["from"] as Vector2)
	assert_almost_eq(gap.x, 0.0, 0.001, "two lances side by side")
	assert_gt(absf(gap.y), 0.3, "apart")


func test_a_twin_lance_on_one_target_deals_its_share() -> void:
	var w := _world([&"gun_twin"], [4.0])
	W.run(w, 4 * PERIOD, 0, W.S)
	var two := _dealt(w, 1)
	assert_eq(two[0], 8, "both lances hit a wide-enough target, 4 shots")
	assert_eq(two[1], 4 * 2 * (19 * 3500 / 1000), "2 x 19 x (5.0 x 70 %) a shot")


func test_attack_speed_shortens_the_3_s_at_half_its_value() -> void:
	var w := _world()
	var o := _world([], [4.0], true)
	for x: World in [w, o]:
		Stats.add_card(x, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
		Stats.add_card(x, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
	var r := AttackRate.rate(w, 0)
	assert_gt(r, 1000)
	assert_eq(AttackRate.form_rate(Modifiers.bolt(w), r), 1000 + (r - 1000) / 2)
	assert_eq(ItemEffects.shot_period_ticks(w), AttackRate.scaled(PERIOD, 1000 + (r - 1000) / 2))
	assert_eq(ItemEffects.shot_period_ticks(o), AttackRate.scaled(9, r), "the orbs take it whole")
	assert_eq(AttackRate.form_rate(Modifiers.bolt(o), r), r)
	W.run(w, 2, 0, W.S)
	assert_eq(_dealt(w, 1)[1], SHOT, "the damage a shot is fixed (Q4)")


func test_the_hero_moves_at_full_speed_while_the_lance_is_held() -> void:
	var a := _world([], [])
	var b := _world([], [])
	var c := _world([], [], true)
	var right := Vector2i(SimTick.MOVE_MAX, 0)
	W.run(a, 60, 0, W.S, 1024, right)
	W.run(b, 60, 0, 0, 1024, right)
	W.run(c, 60, 0, W.S, 1024, right)
	var fired := a.player_pos().x
	var walked := b.player_pos().x
	assert_almost_eq(fired / walked, 1.0, 0.001, "full speed while held (v0.11.0 O1c, owner)")
	assert_eq(Laser.move_factor(a), 1.0, "the move factor is 1000 per mille while held")
	assert_almost_eq(c.player_pos().x, walked, 0.001, "the orbs don't slow")
	assert_eq(Laser.move_factor(b), 1.0, "not held: no slow")


func test_a_shot_feeds_three_hits_worth_of_its_status() -> void:
	var w := _world([&"venom_core"], [3.0, 5.0])
	var per_hit := Modifiers.bolt(w).stacks_of(&"poison")
	assert_gt(per_hit, 0)
	W.run(w, 2, 0, W.S)
	var want := mini(3 * per_hit, ElementLevels.poison_cap(w))
	assert_eq(w.actors.poison_stacks[1], want, "3 hits' worth on the first enemy (Q5)")
	assert_eq(w.actors.poison_stacks[2], want, "and on the one behind it")
	var o := _world([&"venom_core"], [3.0], true)
	for k in 120:
		W.run(o, 1, 0, W.S)
		if o.actors.poison_stacks[1] > 0:
			break
	assert_eq(o.actors.poison_stacks[1], per_hit, "an orb's first hit feeds one")


func test_a_lightning_lance_jumps_once_per_enemy_hit() -> void:
	var w := _world([&"storm_core"], [4.0, 4.1])
	w.actors.set_pos(2, Vector2(4.0, 2.5))
	W.run(w, 4 * PERIOD, 0, W.S)
	var chained: int = _dealt(w, 2)[0]
	assert_gt(chained, 0, "the jump fires")
	assert_lte(chained, 4, "at most once a shot, 4 shots")


func test_the_lance_is_no_projectile_and_spends_no_shot_budget() -> void:
	var w := _world([&"gun_twin"])
	var r := W.repo()
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	Modifiers.invalidate(w)
	W.run(w, 120, 0, W.S)
	assert_eq(w.player_projectiles(), 0, "no projectile")
	assert_eq(ShotCap.last_second(w), 0, "no extras counted")
	assert_eq(ShotCap.shots(Modifiers.bolt(w)), 1, "one attack, not a volley")


func test_the_view_reads_the_shot_the_sim_hit_for_half_a_second() -> void:
	var w := _world([], [3.0])
	W.run(w, 2, 0, W.S)
	var rd := WorldReader.new(w)
	var b: Array[Dictionary] = rd.beams()
	assert_eq(b.size(), 1, "the shot's lance")
	assert_almost_eq(
		(b[0]["to"] as Vector2).x, 9.0 + w.player.radius_m, 0.01, "through the enemy, to 9 m"
	)
	W.run(w, WorldReader.LANCE_GLOW_TICKS, 0, W.S)
	assert_eq(rd.beams().size(), 0, "gone after the glow, until the next shot")


# --- The slots (AS: the form row, the replace rule) -----------------------------------------------------------------
## A Gun world with the shipped wand and its slot table (test_attack_slots' world), holding nothing yet.
func _slot_world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	return w


func _take(w: World, ids: Array) -> void:
	for id: StringName in ids:
		assert_true(BuildSlots.take(w, W.item(w, id)), "took %s" % id)


func test_the_laser_row_offers_only_its_cards() -> void:
	var w := _slot_world()
	_take(w, [&"gun_laser"])
	assert_eq(AttackSlots.form_id(w), &"laser", "the Laser fires now")
	for idx in w.item_tables.size():
		var it := w.item_tables[idx]
		var cat := AttackSlots.category(w, idx)
		if it.retired or it.requires_weapon == PlayerTable.WEAPON_BLADE or cat == AttackSlots.FREE:
			continue
		if cat == AttackSlots.FORM:
			continue
		assert_eq(AttackSlots.usable(w, idx), LASER_ON.has(it.id), "%s with the Laser" % it.id)
	for k in 200:
		w.rng_loot = RngStream.derive(k, "loot")
		for idx in ItemPool.draw_weighted(w, 3, 3):
			var cat := AttackSlots.category(w, idx)
			if cat != AttackSlots.FREE and cat != AttackSlots.FORM:
				assert_true(LASER_ON.has(w.item_tables[idx].id), "draw %d offers %s" % [k, idx])


## v0.11.0 O1 (owner Q28: "Pierce everything, no card"; Q6: "mine is disabled for laser").
func test_pierce_and_mine_are_never_offered_with_the_laser() -> void:
	var w := _slot_world()
	_take(w, [&"gun_laser"])
	for id: StringName in [&"gun_pierce", &"gun_mine"]:
		var idx := W.item(w, id)
		assert_false(AttackSlots.usable(w, idx), "%s is off the Laser's row" % id)
		assert_false(ItemPool.usable(w, idx), "%s is never offered" % id)
	for k in 300:
		w.rng_loot = RngStream.derive(k, "loot")
		for idx in ItemPool.draw_weighted(w, 3, 3):
			assert_false([&"gun_pierce", &"gun_mine"].has(w.item_tables[idx].id), "draw %d" % k)


func test_the_laser_replaces_the_orbs_and_a_held_off_card_stops_compiling() -> void:
	var w := _slot_world()
	_take(w, [&"orbit_rounds", &"gun_swirl", &"ember_core"])
	assert_eq(AttackSlots.form_id(w), &"orbs")
	var laser := W.item(w, &"gun_laser")
	assert_true(ItemPool.usable(w, laser), "offered on the orbs")
	assert_eq(int(Offers.info(w, laser)["replaces"]), -1, "the orbs have no card to burn")
	_take(w, [&"gun_laser"])
	assert_eq(AttackSlots.form_id(w), &"laser")
	var s := Modifiers.bolt(w)
	assert_true(Laser.held(s), "the Gun's shot is the lance")
	assert_eq([s.orbit_ticks, s.swirl], [0, 0], "Orbit and Swirl don't compile")
	assert_true(s.has_status(&"burn"), "Fire does")


func test_a_later_form_card_replaces_the_laser() -> void:
	var w := _slot_world()
	var lab := W.item(w, &"gun_big_shot")  # a lab form (the next forms ship in later steps)
	w.item_tables[lab].slot_category = AttackSlots.FORM
	w.slot_table.form_ids.append(&"lab")
	w.slot_table.form_cards.append(lab)
	w.slot_table.form_cells.append({})
	_take(w, [&"gun_laser"])
	var laser := W.item(w, &"gun_laser")
	assert_eq(int(Offers.info(w, lab)["replaces"]), laser, "the card says it replaces the Laser")
	_take(w, [&"gun_big_shot"])
	assert_false(w.items_owned.has(laser), "the Laser leaves")
	assert_eq(AttackSlots.form_id(w), &"lab")
	assert_false(Laser.held(Modifiers.bolt(w)), "the lance is gone")


## The damage the lance should deal to the enemy at rank `k` (0 first) of a line, from the rule in integers: each enemy
## 850 per mille of the one before, never under 400 per mille of the first (v0.11.0 O1c).
func _fall(first: int, k: int) -> int:
	var f := 1000
	for _j in k:
		f = maxi(400, f * 850 / 1000)
	return maxi(1, first * f / 1000)


func test_each_enemy_down_the_lance_takes_15_percent_less_than_the_one_before() -> void:
	var at := []
	for k in 6:
		at.append(2.0 + 1.0 * k)
	var w := _world([], at)
	W.run(w, 2, 0, W.S)
	var got := []
	for i in range(1, 7):
		got.append(_dealt(w, i)[1])
	assert_eq(got, [95, 80, 68, 58, 49, 41], "95 x 1000, 850, 722, 613, 521, 442 per mille")
	for k in 6:
		assert_eq(got[k], _fall(SHOT, k))


func test_the_falloff_stops_at_40_percent_of_the_first_hit() -> void:
	var at := []
	for k in 12:
		at.append(1.5 + 0.6 * k)
	var w := _world([], at)
	W.run(w, 2, 0, W.S)
	for k in 12:
		assert_eq(_dealt(w, k + 1)[1], _fall(SHOT, k), "enemy %d" % k)
	assert_eq(_dealt(w, 12)[1], 38, "the floor: 400 per mille of 95")
	assert_eq(_dealt(w, 8)[1], 38, "held from the seventh on")


func test_twins_second_lane_starts_again_at_full_damage() -> void:
	var w := _world([&"gun_twin"], [3.0, 4.5, 6.0])
	W.run(w, 2, 0, W.S)
	var amounts := {}
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.tags & SimEvent.TAG_DOT:
			continue
		for i in range(1, 4):
			if e.target_id == w.actors.ids[i]:
				amounts[i] = amounts.get(i, []) + [e.amount]
	var first: Array = amounts[1]
	assert_eq(first.size(), 2, "both lanes hit the first enemy")
	assert_eq(first[0], first[1], "each lane's first hit is full")
	var second: Array = amounts[2]
	assert_eq(second.size(), 2)
	for a in second:
		assert_eq(a, maxi(1, first[0] * 850 / 1000), "each lane's second hit is 15 % less")
	var third: Array = amounts[3]
	for a in third:
		assert_lt(a, second[0], "and the third less again")


func test_every_enemy_in_a_line_is_fed_three_hits_of_status_whatever_the_falloff() -> void:
	var w := _world([&"venom_core"], [2.0, 3.0, 4.0, 5.0, 6.0, 7.0])
	var per_hit := Modifiers.bolt(w).stacks_of(&"poison")
	W.run(w, 2, 0, W.S)
	var want := mini(3 * per_hit, ElementLevels.poison_cap(w))
	for i in range(1, 7):
		assert_eq(w.actors.poison_stacks[i], want, "enemy %d: 3 hits' worth" % i)
