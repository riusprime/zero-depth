extends GutTest
## v0.9.0 BM (owner C §6.3, Q9; PLAN C51–C53; ATTACK_FORMS.md F3): the Bomb form. One bomb a second thrown straight
## along the aim; it bursts on the first enemy, on a wall or 8 m out; the blast (2.2 m, 4.5 × an orb hit) hits every
## enemy in it once; attack speed counts at half; Twin throws 2 bombs (3 at Lv 5) at its share; the elements apply on
## the blast; overlapping blasts past 8 in a tick merge. v0.9.5 BR: the card is retired into the Void (no row, never
## offered); its code stays reachable for a held retired card, so these tests stay.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000


func _world(items: Array = [], at: Array = [Vector2(4.0, 0.0)]) -> World:
	var enemies := []
	for p: Vector2 in at:
		enemies.append([p, HP])
	var ids: Array = [&"gun_bomb"]
	ids.append_array(items)
	return W.world(&"gun", ids, enemies)


func _blasts(w: World) -> Array[SimEvent]:
	return W.events(w, SimEvent.Kind.BLAST)


## The direct damage the player dealt to actor `idx`: [hits, total].
func _dealt(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var n := 0
	var total := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			n += 1
			total += e.amount
	return [n, total]


func test_the_card_makes_the_shot_a_bomb() -> void:
	var w := _world()
	var s := Modifiers.bolt(w)
	assert_true(Bomb.is_bomb(s))
	assert_eq(s.form, AttackSpec.Form.BOLT, "thrown straight (Q9), a bolt that bursts")
	assert_eq(
		[s.period_ticks, s.blast_mm, s.rate_scale_permille],
		[60, 2200, 500],
		"1 a second, 2.2 m, half"
	)
	assert_eq(s.damage, 22, "4.5 × the orb's 5, rounded down")
	assert_almost_eq(s.speed * s.life_ticks, 8.0, 0.05, "8 m")
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_bomb")
	assert_eq([def.rarity, def.requires_weapon], [ItemDefinition.Rarity.RARE, &"gun"])
	assert_eq(w.item_tables[W.item(w, &"gun_bomb")].slot_category, AttackSlots.FORM)


func test_one_bomb_a_second_bursting_on_the_first_enemy() -> void:
	var w := _world()
	W.run(w, 300, 0, W.S)
	var b := _blasts(w)
	assert_eq(b.size(), 5, "5 bombs in 5 s, each burst")
	for e in b:
		assert_lt(absf(e.pos.x - (4.0 - 0.35 - 0.3)), 0.25, "on the enemy's near edge")
	var d := _dealt(w, 1)
	assert_eq(d, [5, 110], "only the blast hurts: 5 × 22, the touch deals nothing")


func test_a_wall_or_eight_metres_bursts_it() -> void:
	var w := _world([], [])
	w.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 2.0), 0))
	W.run(w, 40, 0, W.S)
	var b := _blasts(w)
	assert_eq(b.size(), 1, "it burst on the wall")
	assert_lt(b[0].pos.x, 3.0)
	var open := _world([], [])
	W.run(open, 60, 0, W.S)
	var o := _blasts(open)
	assert_eq(o.size(), 1, "with nothing ahead it bursts at the end of its flight")
	assert_almost_eq(o[0].pos.x, 8.0 + 0.35 + 0.3 + 0.05, 0.3, "about 8 m out")


func test_the_blast_hits_every_enemy_in_its_radius_once() -> void:
	var at: Array = [Vector2(4.0, 0.0), Vector2(4.5, 1.5), Vector2(3.5, -1.6), Vector2(4.0, 3.2)]
	var w := _world([], at)
	W.run(w, 30, 0, W.S)
	assert_eq(_blasts(w).size(), 1)
	for k in [1, 2, 3]:
		assert_eq(_dealt(w, k), [1, 22], "enemy %d in the 2.2 m blast" % k)
	assert_eq(_dealt(w, 4)[0], 0, "the one 3.2 m off is outside it")


func test_attack_speed_counts_at_half() -> void:
	var w := _world()
	var o := W.world(&"gun")
	for x: World in [w, o]:
		Stats.add_card(x, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
		Stats.add_card(x, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
	var r := AttackRate.rate(w, 0)
	assert_gt(r, 1000)
	assert_eq(ItemEffects.shot_period_ticks(w), AttackRate.scaled(60, 1000 + (r - 1000) / 2))
	assert_eq(ItemEffects.shot_period_ticks(o), AttackRate.scaled(9, r), "the orbs take it whole")


func test_twin_throws_two_bombs_and_three_at_level_three_at_its_share() -> void:
	var w := _world([&"gun_twin"], [])
	var twin := W.item(w, &"gun_twin")
	for lvl in [1, 2, 3]:
		CardLevels.set_level(w, twin, lvl)
		var s := Modifiers.bolt(w)
		assert_eq(ShotCap.shots(s), 3 if lvl == 3 else 2, "Twin Lv %d" % lvl)
	CardLevels.set_level(w, twin, 1)
	W.run(w, 2, 0, W.S)
	var dmg := []
	for i in w.projectiles.size():
		if Bomb.touches(w, i):
			dmg.append(w.projectiles.damage[i])
	assert_eq(dmg, [15, 15], "two bombs at 70 % of 22 each: not double, a trade (spread blasts)")


func test_the_elements_apply_on_the_blast_to_every_enemy_in_it() -> void:
	var at: Array = [Vector2(4.0, 0.0), Vector2(4.5, 1.5), Vector2(3.5, -1.6)]
	var w := _world([&"venom_core"], at)
	W.run(w, 30, 0, W.S)
	var poisoned := W.targets(W.events(w, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON))
	assert_eq(poisoned.size(), 3, "Venom on all three in the blast")
	var f := _world([&"ember_core"], at)
	W.run(f, 30, 0, W.S)
	for k in [1, 2, 3]:
		assert_gt(f.actors.burn_stacks[k], 0, "Fire burns enemy %d" % k)


func test_overlapping_blasts_past_eight_in_a_tick_merge() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	var r := Bomb.radius_m(w, s)
	var merged := []
	for k in 12:
		merged.append(Attacks.merged_at(w, Vector2(1.0, 0.0), r))
	assert_eq(merged.count(false), 8, "8 blasts a tick go off (WandTable.blast_merge_after)")
	assert_eq(merged.count(true), 4, "the overlapping rest merge")
	assert_true(Attacks.merged_at(w, Vector2(1.5, 0.0), r), "another within its radius merges")
	assert_false(Attacks.merged_at(w, Vector2(20.0, 0.0), r), "one far away still goes off")
	assert_gt(w.blast_merged, 0)


## v0.9.5 BR (owner, 2026-10-31: "let's just remove the bomb I didnt quite enjoy playing it"): the Bomb card is retired
## into the Void (migration.tres), has no form row and is never offered; its code stays for a held retired card.
func test_the_bomb_has_no_row_and_is_never_offered() -> void:
	var w := W.world(&"gun")
	var bomb := W.item(w, &"gun_bomb")
	assert_true(w.item_tables[bomb].retired, "retired")
	assert_does_not_have(ItemPool.available(w), bomb, "never offered")
	var slots: AttackSlotsDefinition = W.repo().get_def(&"wand", &"attack_slots")
	for f in slots.forms:
		assert_ne(f.card, &"gun_bomb", "no row")
		assert_ne(f.id, &"bomb", "no row id")
	w.floor_index = 3
	w.run_floor = 3
	for k in 200:
		w.rng_loot = RngStream.derive(k, "loot")
		assert_false(ItemPool.draw_weighted(w, 3, 3).has(bomb), "draw %d" % k)
