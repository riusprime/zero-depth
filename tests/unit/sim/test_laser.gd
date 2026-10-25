extends GutTest
## v0.9.0 LZ (owner C §6.2, Q8; PLAN C48–C50, C72; ATTACK_FORMS.md F2): the Laser form. Held, the beam deals a damage
## tick 10 times a second; on one target it out-damages the orbs (about 1.2 ×); it stops at the first enemy unless
## Pierce, a wall stops it, it reaches 9 m; Twin gives 2 beams (3 at Lv 5); attack speed counts at half on the tick
## rate; the hero moves at 75 % while it fires; its statuses feed per tick at the orbs' rate (Laser's fair rule).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
## ATTACK_FORMS.md F2: Twin on; Halo, Ring, Backfire, Spiral, Swirl off; every Secondary off but Pierce; the five
## elements on (Void, gravity_well, leaves in VP: off).
const LASER_ON: Array[StringName] = [
	&"gun_twin",
	&"gun_pierce",
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


## The direct (not damage-over-time) damage the player dealt to actor `idx`, in ticks [from, to).
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


func test_the_card_makes_the_guns_shot_a_held_beam() -> void:
	var w := _world()
	var s := Modifiers.bolt(w)
	assert_true(Laser.held(s))
	assert_eq(s.form, AttackSpec.Form.BEAM)
	assert_eq(s.period_ticks, 6, "10 ticks a second")
	assert_almost_eq(s.reach_m, 9.0, 0.001, "9 m")
	assert_eq([s.beam_permille, s.rate_scale_permille, s.move_permille], [800, 500, 750])
	var it := w.item_tables[W.item(w, &"gun_laser")]
	assert_eq(it.slot_category, AttackSlots.FORM, "a Form card")
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_laser")
	assert_eq(def.rarity, ItemDefinition.Rarity.RARE)
	assert_eq(def.requires_weapon, &"gun", "Gun only (Q6)")


func test_held_fire_ticks_ten_times_a_second_and_beats_the_orbs_on_one_target() -> void:
	var w := _world()
	W.run(w, 720, 0, W.S)
	var beam := _dealt(w, 1, 120, 720)
	assert_eq(beam[0], 100, "10 ticks a second over 10 s")
	assert_eq(beam[1], 400, "each tick 4 (800 per mille of the orb's 5)")
	var o := _world([], [4.0], true)
	W.run(o, 720, 0, W.S)
	var orbs := _dealt(o, 1, 120, 720)
	var ratio := float(beam[1]) / float(orbs[1])
	gut.p(
		(
			"LZ one target, 10 s held: beam %d dmg in %d ticks, orbs %d dmg in %d hits, ratio %.3f"
			% [beam[1], beam[0], orbs[1], orbs[0], ratio]
		)
	)
	assert_between(ratio, 1.1, 1.3, "about 1.2 × the orbs' single-target DPS (Q8)")


func test_the_beam_stops_at_the_first_enemy() -> void:
	var w := _world([], [3.0, 5.0])
	W.run(w, 60, 0, W.S)
	assert_gt(_dealt(w, 1)[1], 0, "the first takes the beam")
	assert_eq(_dealt(w, 2)[1], 0, "the one behind it doesn't")


func test_pierce_passes_through_as_many_as_it_allows() -> void:
	var w := _world([&"gun_pierce"], [1.5, 2.5, 3.5, 4.5, 5.5, 6.5])
	assert_eq(Modifiers.bolt(w).pierce, 4, "Pierce: through 4")
	W.run(w, 60, 0, W.S)
	for k in [1, 2, 3, 4, 5]:
		assert_gt(_dealt(w, k)[1], 0, "enemy %d is hit" % k)
	assert_eq(_dealt(w, 6)[1], 0, "the sixth is past Pierce")


func test_a_wall_stops_the_beam_and_it_reaches_nine_metres() -> void:
	var w := _world([], [4.0])
	w.add_wall_now(Obb.make(Vector2(2.0, 0.0), Vector2(0.2, 2.0), 0))
	W.run(w, 60, 0, W.S)
	assert_eq(_dealt(w, 1)[1], 0, "behind the wall")
	var b: Dictionary = Laser.trace(w, Modifiers.bolt(w), w.player_pos(), 0)[0]
	assert_true(b["wall"])
	assert_lt((b["to"] as Vector2).x, 2.0, "it ends at the wall")
	var far := _world([], [10.0])
	var near := _world([], [9.0])
	W.run(far, 30, 0, W.S)
	W.run(near, 30, 0, W.S)
	assert_eq(_dealt(far, 1)[1], 0, "past 9 m (its near edge 9.65 m out)")
	assert_gt(_dealt(near, 1)[1], 0, "within 9 m")


func test_twin_gives_two_beams_and_three_at_level_three() -> void:
	var w := _world([&"gun_twin"], [])
	var twin := W.item(w, &"gun_twin")
	var expect := {1: [2, 700], 2: [2, 900], 3: [3, 750]}
	for lvl: int in expect:
		CardLevels.set_level(w, twin, lvl)
		var s := Modifiers.bolt(w)
		var beams := Laser.trace(w, s, w.player_pos(), 0)
		assert_eq([beams.size(), s.share_permille], expect[lvl], "Twin Lv %d" % lvl)
		assert_eq(Laser.milli_of(s, 5), 4 * int(expect[lvl][1]), "each beam's share of the tick")
	var two := _world([&"gun_twin"], [])
	var p: Array[Dictionary] = Laser.trace(two, Modifiers.bolt(two), two.player_pos(), 0)
	var gap := (p[1]["from"] as Vector2) - (p[0]["from"] as Vector2)
	assert_almost_eq(gap.x, 0.0, 0.001, "two beams side by side")
	assert_gt(absf(gap.y), 0.3, "apart")


func test_a_twin_beam_on_one_target_deals_its_share_and_feeds_as_a_second() -> void:
	var w := _world([&"gun_twin"], [4.0])
	W.run(w, 720, 0, W.S)
	var two := _dealt(w, 1, 120, 720)
	assert_eq(two[0], 200, "both beams tick on a wide-enough target")
	assert_eq(two[1], 560, "2 × 4 × 70 %")


func test_attack_speed_raises_the_tick_rate_at_half_its_value() -> void:
	var w := _world()
	var o := _world([], [4.0], true)
	for x: World in [w, o]:
		Stats.add_card(x, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
		Stats.add_card(x, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
	var r := AttackRate.rate(w, 0)
	assert_gt(r, 1000)
	assert_eq(AttackRate.form_rate(Modifiers.bolt(w), r), 1000 + (r - 1000) / 2)
	assert_eq(ItemEffects.shot_period_ticks(w), AttackRate.scaled(6, 1000 + (r - 1000) / 2))
	assert_eq(ItemEffects.shot_period_ticks(o), AttackRate.scaled(9, r), "the orbs take it whole")
	assert_eq(AttackRate.form_rate(Modifiers.bolt(o), r), r)


func test_the_hero_moves_at_three_quarters_while_the_beam_fires() -> void:
	var a := _world([], [])
	var b := _world([], [])
	var c := _world([], [], true)
	var right := Vector2i(SimTick.MOVE_MAX, 0)
	W.run(a, 60, 0, W.S, 1024, right)
	W.run(b, 60, 0, 0, 1024, right)
	W.run(c, 60, 0, W.S, 1024, right)
	var fired := a.player_pos().x
	var walked := b.player_pos().x
	assert_almost_eq(fired / walked, 0.75, 0.02, "75 % while firing (Q8)")
	assert_almost_eq(c.player_pos().x, walked, 0.001, "the orbs don't slow")
	assert_eq(Laser.move_factor(b), 1.0, "not firing: no slow")


func test_the_beam_feeds_statuses_at_the_orbs_rate_not_ten_times_a_second() -> void:
	assert_eq(Laser.feed_permille(_world(), Modifiers.bolt(_world())), 666, "6 / 9 of its ticks")
	var fed := 0
	for n in range(1, 301):
		fed += 1 if Laser.feeds(n, 666) else 0
	assert_eq(fed, 199, "two ticks in three")
	var w := _world([&"venom_core"])
	var o := _world([&"venom_core"], [4.0], true)
	W.run(w, 600, 0, W.S)
	W.run(o, 600, 0, W.S)
	var beam := W.events(w, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size()
	var orbs := W.events(o, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size()
	gut.p("LZ venom feeds in 10 s on one target: beam %d (100 ticks), orbs %d" % [beam, orbs])
	assert_between(float(beam) / float(orbs), 0.9, 1.1, "as often as the orbs")
	var hits: int = _dealt(w, 1)[0]
	assert_gt(hits, beam + 20, "though it ticks more often")


func test_a_lightning_beam_jumps_only_on_its_feeding_ticks() -> void:
	var w := _world([&"storm_core"], [4.0, 4.0 + 0.1])
	w.actors.set_pos(2, Vector2(4.0, 2.5))
	W.run(w, 600, 0, W.S)
	var chained: int = _dealt(w, 2)[0]
	assert_gt(chained, 40, "the jump fires")
	assert_lt(chained, 80, "but on two ticks in three, not all 100")


func test_the_beam_is_no_projectile_and_spends_no_shot_budget() -> void:
	var w := _world([&"gun_twin"])
	var r := W.repo()
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	Modifiers.invalidate(w)
	W.run(w, 120, 0, W.S)
	assert_eq(w.player_projectiles(), 0, "no projectile")
	assert_eq(ShotCap.last_second(w), 0, "no extras counted")
	assert_eq(ShotCap.shots(Modifiers.bolt(w)), 1, "one attack, not a volley")


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


func test_the_laser_replaces_the_orbs_and_a_held_off_card_stops_compiling() -> void:
	var w := _slot_world()
	_take(w, [&"halo_shot", &"gun_ricochet", &"ember_core"])
	assert_eq(AttackSlots.form_id(w), &"orbs")
	var laser := W.item(w, &"gun_laser")
	assert_true(ItemPool.usable(w, laser), "offered on the orbs")
	assert_eq(int(Offers.info(w, laser)["replaces"]), -1, "the orbs have no card to burn")
	_take(w, [&"gun_laser"])
	assert_eq(AttackSlots.form_id(w), &"laser")
	var s := Modifiers.bolt(w)
	assert_true(Laser.held(s), "the Gun's shot is the beam")
	assert_eq(
		[s.directions, s.bounces], [AttackSpec.DIR_FORWARD, 0], "Halo and Ricochet don't compile"
	)
	assert_true(s.has_status(&"burn"), "Fire does")


func test_the_laser_card_shapes_the_shot_wherever_it_sits() -> void:
	var w := _slot_world()
	_take(w, [&"trigger_on_hit", &"gun_laser"])
	assert_true(Laser.held(Modifiers.bolt(w)), "right of a trigger it still makes the Gun's shot")


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
	assert_false(Laser.held(Modifiers.bolt(w)), "the beam is gone")
