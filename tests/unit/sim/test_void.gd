extends GutTest
## v0.9.0 VP (owner C §6.4, §8; Q10 "No pull on them"; PLAN C54–C58, C70; ATTACK_FORMS.md F4): the Void form. One shot
## every 0.6 s at 0.6 × the orbs' speed; it passes through enemies; its 1.0 m aura hits an enemy as it comes in and 5
## times a second while it stays; its single-target DPS sits with the orbs'; the pull (3 m, at most 1.0 m/s toward the
## path) never stacks across voids, keeps enemies apart, is half on heavies and none on bosses and elites; Twin throws
## 2 (3 at Lv 5) at its share; the elements apply on the aura's hits at Laser's fair rate; the row; the floor black hole
## is gone (an old snapshot holding black holes still restores).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const TOP_STEP := 1.0 / 60.0
const VOID_ON: Array[StringName] = [
	&"gun_twin", &"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed"
]


## A Gun world holding `items` (the Void first unless `orbs`) and a standing dummy at each of `at` (radius `r`).
func _world(
	items: Array = [], at: Array = [Vector2(4.0, 0.0)], orbs: bool = false, r: float = 0.35
) -> World:
	var ids: Array = [] if orbs else [&"gun_void"]
	ids.append_array(items)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, r, HP)
	return w


## The direct damage the player dealt to actor `idx` in ticks [from, to): [hits, total].
func _dealt(w: World, idx: int, from: int = 0, to: int = 1 << 30) -> Array:
	var id := w.actors.ids[idx]
	var n := 0
	var total := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id != id or e.tags & SimEvent.TAG_DOT or e.tick < from or e.tick >= to:
			continue
		n += 1
		total += e.amount
	return [n, total]


func _voids(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if VoidShots.is_void_projectile(w, i):
			out.append(i)
	return out


func test_the_card_makes_the_shot_a_slow_void() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	var orb := Modifiers.bolt(W.world(&"gun"))
	assert_true(VoidShots.is_void(s))
	assert_eq(s.form, AttackSpec.Form.BOLT, "a projectile, thrown along the aim")
	assert_eq(s.period_ticks, 36, "one every 0.6 s")
	assert_almost_eq(s.speed / orb.speed, 0.6, 0.001, "0.6 × the orbs' speed")
	assert_almost_eq(s.speed * s.life_ticks, orb.speed * orb.life_ticks, 0.1, "as far as an orb")
	assert_eq(
		[s.void_mm, s.void_tick_ticks, s.void_pull_mm, s.void_pull_mmps], [1000, 12, 3000, 1000]
	)
	assert_eq(s.damage, 10, "each aura hit 2 × the orb's 5")
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_void")
	assert_eq([def.rarity, def.requires_weapon], [ItemDefinition.Rarity.RARE, &"gun"])
	assert_eq(w.item_tables[W.item(w, &"gun_void")].slot_category, AttackSlots.FORM)
	assert_eq([def.name_key, def.desc_key], [&"ITEM_GUN_VOID", &"ITEM_GUN_VOID_DESC"])


func test_one_shot_every_point_six_seconds() -> void:
	var w := _world([], [])
	var seen := {}
	for k in 360:
		W.run(w, 1, 0, W.S)
		for i in _voids(w):
			seen[w.projectiles.ids[i]] = true
	assert_eq(seen.size(), 10, "10 shots in 6 s")


func test_it_passes_through_enemies_and_its_aura_hits_twice_in_a_pass() -> void:
	var w := _world()
	W.run(w, 1, 0, W.S)
	W.run(w, 34, 0, 0)
	var far := 0.0
	for i in _voids(w):
		far = maxf(far, w.projectiles.pos_x[i])
	assert_gt(far, 5.0, "past the enemy at 4 m: it went through")
	assert_eq(
		_dealt(w, 1), [2, 20], "in as it came, then 0.2 s later while it was still in the aura"
	)


func test_the_aura_reaches_one_metre_from_its_centre_to_an_enemy_edge() -> void:
	var w := _world([], [Vector2(4.0, 1.25), Vector2(5.0, -1.45)])
	w.ev.elite_ids.append_array([w.actors.ids[1], w.actors.ids[2]])  # no pull, so they stand where they are
	W.run(w, 1, 0, W.S)
	W.run(w, 60, 0, 0)
	assert_gt(_dealt(w, 1)[0], 0, "1.25 m off the path (0.9 m to its edge): hit")
	assert_eq(_dealt(w, 2)[0], 0, "1.45 m off (1.1 m to its edge): not hit")


func test_single_target_dps_sits_with_the_orbs() -> void:
	var w := _world()
	W.run(w, 720, 0, W.S)
	var v := _dealt(w, 1, 120, 720)
	var o := _world([], [Vector2(4.0, 0.0)], true)
	W.run(o, 720, 0, W.S)
	var orbs := _dealt(o, 1, 120, 720)
	var ratio := float(v[1]) / float(orbs[1])
	(
		gut
		. p(
			(
				"VP one target 4 m out, 10 s held: void %d dmg in %d hits, orbs %d dmg in %d hits, ratio %.3f"
				% [v[1], v[0], orbs[1], orbs[0], ratio]
			)
		)
	)
	assert_between(
		ratio, 0.9, 1.1, "with the orbs (≈ 0.9–1.1 ×): it trades raw damage for the pull"
	)
	for dist: float in [3.0, 6.0, 8.0]:
		var d := _world([], [Vector2(dist, 0.0)])
		W.run(d, 720, 0, W.S)
		var r := float(_dealt(d, 1, 120, 720)[1]) / float(orbs[1])
		gut.p("VP one target %.0f m out: ratio %.3f" % [dist, r])
		assert_between(r, 0.85, 1.15, "%.0f m out" % dist)


func test_the_pull_draws_toward_the_path_at_most_one_metre_a_second() -> void:
	var w := _world([], [Vector2(3.0, 2.0)])
	var most := 0.0
	var before := w.actors.pos(1)
	W.run(w, 1, 0, W.S)
	for k in 40:
		var at := w.actors.pos(1)
		W.run(w, 1, 0, 0)
		most = maxf(most, Kin.length(w.actors.pos(1) - at))
	assert_lt(w.actors.pos(1).y, before.y - 0.05, "drawn toward the shot's path (y = 0)")
	assert_gt(w.actors.pos(1).y, 0.5, "subtly: it isn't dragged onto the path")
	assert_lte(most, TOP_STEP + 0.0001, "never faster than 1 m/s")
	gut.p("VP pull: %.3f m over one pass, top %.4f m a tick" % [before.y - w.actors.pos(1).y, most])


func test_three_voids_never_stack_their_pull() -> void:
	var w := _world([&"gun_twin"], [Vector2(3.2, 0.9)])
	CardLevels.set_level(w, W.item(w, &"gun_twin"), 5)
	W.run(w, 1, 0, W.S)
	var over := false
	var most := 0.0
	for k in 40:
		var shots := _voids(w)
		if shots.size() == 3:
			var singles := 0.0
			for pi in shots:
				var one: PackedVector2Array = VoidShots.steps(w, PackedInt32Array([pi]))[1]
				singles += Kin.length(one[0]) if one.size() > 0 else 0.0
			var all: PackedVector2Array = VoidShots.steps(w, shots)[1]
			if all.size() > 0:
				assert_lte(
					Kin.length(all[0]), TOP_STEP + 0.0001, "three pulls on one enemy: one top speed"
				)
				over = over or singles > TOP_STEP + 0.001
		var at := w.actors.pos(1)
		W.run(w, 1, 0, 0)
		most = maxf(most, Kin.length(w.actors.pos(1) - at))
	assert_true(over, "the three pulls added would have passed 1 m/s")
	assert_lte(most, TOP_STEP + 0.0001, "never past 1 m/s")


func test_a_pulled_crowd_lines_up_and_never_bunches() -> void:
	var at: Array = []
	for k in 10:
		at.append(Vector2(3.0 + (k % 5) * 0.9, (1.0 if k < 5 else -1.0) * (1.2 + (k % 3) * 0.3)))
	var w := _world([], at)
	var least := 99.0
	for t in 600:
		W.run(w, 1, 0, W.S)
		for a in range(1, 11):
			for b in range(a + 1, 11):
				least = minf(least, Kin.length(w.actors.pos(a) - w.actors.pos(b)))
	gut.p("VP crowd of 10 pulled for 10 s: closest pair %.3f m (bodies touch at 0.70)" % least)
	assert_gte(least, 0.6, "never piled on one another (two 0.35 m bodies)")
	var xs := []
	for a in range(1, 11):
		xs.append(w.actors.pos(a).x)
	assert_gt(xs.max() - xs.min(), 3.0, "still spread along the path, not gathered on one point")


func test_heavies_take_half_the_pull() -> void:
	var w := _world([], [Vector2(3.0, 2.0)])
	var h := _world([], [Vector2(3.0, 2.2)], false, 0.55)
	for x: World in [w, h]:
		W.run(x, 1, 0, W.S)
		W.run(x, 30, 0, 0)
	var light := 2.0 - w.actors.pos(1).y
	var heavy := 2.2 - h.actors.pos(1).y
	gut.p("VP pull in one pass: a 0.35 m body %.3f m, a 0.55 m heavy %.3f m" % [light, heavy])
	assert_between(heavy / light, 0.4, 0.6, "a heavy (0.55 m) half")


func test_bosses_and_elites_feel_no_pull() -> void:
	var w := _world([], [Vector2(3.0, 2.0), Vector2(3.0, -2.0)])
	w.ev.elite_ids.append(w.actors.ids[2])
	W.run(w, 1, 0, W.S)
	W.run(w, 30, 0, 0)
	assert_almost_eq(w.actors.pos(2).y, -2.0, 0.0001, "an elite: none")
	assert_lt(w.actors.pos(1).y, 1.95, "the normal one beside it is pulled")
	var b := _world([], [Vector2(3.0, 2.0)])
	W.run(b, 8, 0, W.S)
	b.actors.kinds[1] = ActorStore.Kind.GATEKEEPER
	assert_eq(VoidShots.pull_permille(b, 1), 0, "a boss: none")
	assert_eq((VoidShots.steps(b, _voids(b))[0] as PackedInt32Array).size(), 0, "no step on it")
	b.actors.kinds[1] = ActorStore.Kind.DUMMY
	assert_eq(VoidShots.pull_permille(b, 1), 1000)


func test_twin_throws_two_voids_and_three_at_level_five_at_its_share() -> void:
	var w := _world([&"gun_twin"], [])
	var twin := W.item(w, &"gun_twin")
	for lvl in [1, 4, 5]:
		CardLevels.set_level(w, twin, lvl)
		assert_eq(ShotCap.shots(Modifiers.bolt(w)), 3 if lvl == 5 else 2, "Twin Lv %d" % lvl)
	CardLevels.set_level(w, twin, 1)
	W.run(w, 2, 0, W.S)
	var dmg := []
	for i in _voids(w):
		dmg.append(w.projectiles.damage[i])
	assert_eq(dmg, [6, 6], "two voids at 60 % of 10 each")


func test_the_elements_apply_on_the_aura_at_the_fair_rate() -> void:
	var w := _world([&"venom_core"])
	assert_eq(
		VoidShots.feed_permille(w, Modifiers.bolt(w)),
		1000,
		"0.2 s ticks over the orbs' 0.15 s: every hit"
	)
	var o := _world([&"venom_core"], [Vector2(4.0, 0.0)], true)
	W.run(w, 600, 0, W.S)
	W.run(o, 600, 0, W.S)
	var v := W.events(w, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size()
	var orbs := W.events(o, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size()
	var hits: int = _dealt(w, 1)[0]
	gut.p("VP venom feeds in 10 s on one target: void %d (%d aura hits), orbs %d" % [v, hits, orbs])
	assert_eq(v, hits, "one feed an aura hit")
	assert_lte(v, orbs, "never more often than the orbs")
	var at: Array = [Vector2(4.0, 0.0), Vector2(4.5, 0.8), Vector2(5.0, -0.8)]
	var f := _world([&"ember_core"], at)
	W.run(f, 50, 0, W.S)
	for k in [1, 2, 3]:
		assert_gt(f.actors.burn_stacks[k], 0, "Fire on enemy %d in the aura" % k)


func test_its_state_is_hashed_only_while_it_waits_and_drops_with_the_shot() -> void:
	var w := _world()
	W.run(w, 1, 0, W.S)
	W.run(w, 18, 0, 0)
	assert_false(w.mx.void_shot.is_empty(), "the enemy waits for the shot's next tick")
	assert_true(w.mx.touched())
	W.run(w, 80, 0, 0)
	assert_true(w.mx.void_shot.is_empty(), "the waits leave once their tick comes")
	var a := _world()
	var b := _world()
	for x: World in [a, b]:
		W.run(x, 200, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")


# --- The slots ------------------------------------------------------------------------------------------------------
func _slot_world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	return w


func test_the_void_row_offers_only_its_cards() -> void:
	var w := _slot_world()
	assert_true(BuildSlots.take(w, W.item(w, &"gun_void")))
	assert_eq(AttackSlots.form_id(w), &"void")
	for id: StringName in [
		&"gun_ring", &"halo_shot", &"gun_backfire", &"gun_spiral", &"gun_swirl", &"gun_pierce"
	]:
		assert_false(ItemPool.usable(w, W.item(w, id)), "%s with the Void: never" % id)
	for idx in w.item_tables.size():
		var it := w.item_tables[idx]
		var cat := AttackSlots.category(w, idx)
		if (
			it.retired
			or it.requires_weapon == PlayerTable.WEAPON_BLADE
			or cat in [AttackSlots.FREE, AttackSlots.FORM]
		):
			continue
		assert_eq(AttackSlots.usable(w, idx), VOID_ON.has(it.id), "%s with the Void" % it.id)
	var off := []
	for id: StringName in [&"gun_ring", &"halo_shot", &"gun_backfire", &"gun_spiral", &"gun_swirl"]:
		off.append(W.item(w, id))
	for k in 200:
		w.rng_loot = RngStream.derive(k, "loot")
		for c in ItemPool.draw_weighted(w, 3, 3):
			assert_false(off.has(c), "draw %d offers no off card" % k)


func test_the_void_replaces_the_orbs_the_laser_and_the_bomb() -> void:
	var w := _slot_world()
	var void_card := W.item(w, &"gun_void")
	assert_eq(AttackSlots.form_id(w), &"orbs")
	for other: StringName in [&"gun_laser", &"gun_bomb"]:
		var o := W.item(w, other)
		assert_true(BuildSlots.take(w, o))
		assert_eq(
			int(Offers.info(w, void_card)["replaces"]),
			o,
			"the Void card says it replaces %s" % other
		)
		assert_true(BuildSlots.take(w, void_card))
		assert_false(w.items_owned.has(o), "the Void and %s never coexist" % other)
		assert_eq(AttackSlots.form_id(w), &"void")
		assert_true(VoidShots.is_void(Modifiers.bolt(w)))
		assert_eq(int(Offers.info(w, o)["replaces"]), void_card)
	assert_true(BuildSlots.take(w, W.item(w, &"gun_laser")))
	assert_false(w.items_owned.has(void_card), "a later form replaces the Void")
	assert_false(VoidShots.is_void(Modifiers.bolt(w)))


# --- The floor black hole is gone -----------------------------------------------------------------------------------
func test_the_old_void_card_is_retired_and_leaves_no_black_hole() -> void:
	var w := W.world(&"gun", [&"gravity_well"], [[Vector2(4.0, 0.0), HP]])
	var s := Modifiers.bolt(w)
	assert_false(VoidShots.is_void(s), "the retired card makes no Void shot")
	assert_false(&"hole_permille" in AttackSpec.LATE_INT_FIELDS, "the black hole's fields are gone")
	assert_false(ModifierOpDefinition.FIELD_STAGE.has(&"hole_chance_permille"))
	W.run(w, 600, 0, W.S)
	assert_eq(W.events(w, SimEvent.Kind.DAMAGE, &"void_hole").size(), 0, "no black hole pulses")
	assert_false(&"hole_pos" in WorldSnapshot.script_fields(w.mx), "no black-hole state")


func test_a_snapshot_holding_black_holes_restores_without_them() -> void:
	var w := _world()
	W.run(w, 90, 0, W.S)
	var snap := WorldSnapshot.take(w)
	var mx := _find_class(snap["world"], "ModifierState")
	assert_false(mx.is_empty(), "the snapshot holds the modifier state")
	mx["hole_pos"] = PackedVector2Array([Vector2(3.0, 1.0), Vector2(5.0, -1.0)])  # a v0.8.0 save's two black holes
	mx["hole_from"] = PackedInt32Array([60, 80])
	mx["hole_dmg"] = PackedInt32Array([2, 2])
	var base := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), _world())
	assert_not_null(base, "it restores")
	if base == null:
		return
	assert_eq(base.state_hash(), w.state_hash(), "the black holes dropped, the rest as it was")
	W.run(base, 60, 0, W.S)
	W.run(w, 60, 0, W.S)
	assert_eq(base.state_hash(), w.state_hash(), "and it plays on the same")


func _find_class(d: Variant, cls: String) -> Dictionary:
	if typeof(d) == TYPE_DICTIONARY:
		var dict: Dictionary = d
		if String(dict.get(WorldSnapshot.CLASS_KEY, "")) == cls:
			return dict
		for k: Variant in dict:
			var f := _find_class(dict[k], cls)
			if not f.is_empty():
				return f
	elif typeof(d) == TYPE_ARRAY:
		for v: Variant in d:
			var f := _find_class(v, cls)
			if not f.is_empty():
				return f
	return {}
