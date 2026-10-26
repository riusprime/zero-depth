extends GutTest
## v0.9.0 AF3 (owner Q7; ATTACK_FORMS.md F9 "A wide slow wave that rolls forward through everything … 3 m wide, 6 m/s,
## pierces, every 0.9 s", Twin and Backfire yes, the rest off, elements all): the Wave form. One wide band every 0.9 s
## at 6 m/s; it passes through every enemy it rolls over and hits each once; 3 m wide; a wall ends it and shields what
## is behind; Twin's copies at its share; Backfire a wave behind; the elements on every enemy it hits; its row; a
## snapshot mid-flight plays on the same; its single-target DPS against the orbs (reported, see WAVE_WISPS.md).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const WAVE_ON: Array[StringName] = [
	&"gun_twin",
	&"gun_backfire",
	&"gun_ricochet",  # v0.9.5 FC8: the eight cards of FORM_COMBOS W1-W8
	&"gun_homing",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
	&"gun_spiral",
	&"ember_core",
	&"storm_core",
	&"frost_core",
	&"venom_core",
	&"shared_bleed"
]


func _world(
	items: Array = [], at: Array = [Vector2(4.0, 0.0)], orbs: bool = false, r: float = 0.35
) -> World:
	var ids: Array = [] if orbs else [&"gun_wave"]
	ids.append_array(items)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, r, HP)
	return w


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


func _waves(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if WaveShots.is_wave_projectile(w, i):
			out.append(i)
	return out


## One wave: SHOOT for a tick, then `rest` ticks without.
func _one(w: World, rest: int = 150) -> void:
	W.run(w, 1, 0, W.S)
	W.run(w, rest, 0, 0)


func test_the_card_makes_the_shot_a_wide_slow_wave() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	var orb := Modifiers.bolt(W.world(&"gun"))
	assert_true(WaveShots.is_wave(s))
	assert_eq(s.form, AttackSpec.Form.BOLT)
	assert_eq(s.wave_mm, 3000, "3 m wide")
	assert_almost_eq(WaveShots.half_m(w, s), 1.5, 1e-6)
	assert_almost_eq(s.speed * SimTick.TICKS_PER_SECOND, 6.0, 0.01, "6 m/s")
	assert_eq(s.period_ticks, 54, "every 0.9 s")
	assert_almost_eq(
		s.speed * s.life_ticks, orb.speed * orb.life_ticks, 0.11, "as far as an orb flies"
	)
	assert_eq(s.damage, orb.damage * 6, "× 6 an orb hit (the class doc: one target about the orbs)")
	assert_false(s.has_tag(&"wave"), "not the Blade's wave: Split Wave never reads it")
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_wave")
	assert_eq([def.rarity, def.requires_weapon], [ItemDefinition.Rarity.RARE, &"gun"])
	assert_eq(w.item_tables[W.item(w, &"gun_wave")].slot_category, AttackSlots.FORM)
	assert_eq([def.name_key, def.desc_key], [&"ITEM_GUN_WAVE", &"ITEM_GUN_WAVE_DESC"])
	assert_ne(def.id, &"echo_slash")


func test_it_rolls_through_every_enemy_once() -> void:
	var at: Array = [Vector2(2.0, 0.0), Vector2(4.0, 0.3), Vector2(6.0, -0.3), Vector2(9.0, 0.0)]
	var w := _world([], at)
	W.run(w, 1, 0, W.S)
	assert_eq(_waves(w).size(), 1, "one wave a shot")
	W.run(w, 200, 0, 0)
	for k in [1, 2, 3, 4]:
		assert_eq(_dealt(w, k), [1, 30], "enemy %d: one hit of 30 as the wave rolls over" % k)
	assert_eq(_waves(w).size(), 0, "gone at the end of its flight")
	var far := _world([], [Vector2(12.0, 0.0)])
	_one(far, 250)
	assert_eq(_dealt(far, 1)[0], 0, "past its 10.8 m: missed")


func test_it_flies_along_the_aim() -> void:
	for aim: int in [0, 1024, 2560]:
		var w := _world([], [])
		W.run(w, 1, 0, W.S, aim)
		var v := Vector2(w.projectiles.vel_x[0], w.projectiles.vel_y[0])
		assert_almost_eq(v.normalized().dot(Kin.dir(aim)), 1.0, 1e-3, "aim %d" % aim)


func test_it_is_three_metres_wide() -> void:
	var at: Array = [Vector2(4.0, 1.4), Vector2(4.0, -1.4), Vector2(6.0, 1.8), Vector2(6.0, -2.3)]
	var w := _world([], at)
	_one(w)
	assert_eq(_dealt(w, 1)[0], 1, "1.4 m to the side: in the band")
	assert_eq(_dealt(w, 2)[0], 1, "and on the other side")
	assert_eq(_dealt(w, 3)[0], 1, "1.8 m: its body reaches the band's edge")
	assert_eq(_dealt(w, 4)[0], 0, "2.3 m: clear of it")


func test_a_wall_ends_it_and_shields_what_is_behind() -> void:
	var w := _world([], [Vector2(1.6, 0.0), Vector2(4.0, 0.0), Vector2(4.0, 1.2)])
	w.add_wall_now(Obb.make(Vector2(2.8, 0.0), Vector2(0.2, 2.5), 0))
	_one(w)
	assert_eq(_dealt(w, 1)[0], 1, "before the wall: hit")
	assert_eq(_dealt(w, 2)[0], 0, "behind it: safe")
	assert_eq(_dealt(w, 3)[0], 0, "behind it off the centre: safe")
	assert_eq(_waves(w).size(), 0, "the wall ended it")
	var corner := _world([], [Vector2(3.0, 1.2)])
	corner.add_wall_now(Obb.make(Vector2(3.0, 0.6), Vector2(0.6, 0.1), 0))
	_one(corner)
	assert_eq(_dealt(corner, 1)[0], 0, "a wall between the shot and the enemy shields it")


func test_shots_come_every_point_nine_seconds() -> void:
	var w := _world([], [])
	var ids := {}
	for k in 240:
		W.run(w, 1, 0, W.S)
		for i in _waves(w):
			ids[w.projectiles.ids[i]] = w.tick
	assert_eq(ids.size(), 5, "4 s held: at ticks 0, 54, 108, 162, 216")


func test_twin_fires_side_by_side_waves_at_its_share_and_backfire_one_behind() -> void:
	var w := _world([&"gun_twin"], [Vector2(4.0, 0.0)])
	_one(w)
	assert_eq(_dealt(w, 1), [2, 42], "two waves, each 70 % of 30")  # v0.9.5 CLV: Twin level 1 is 70 %
	var twin := W.item(w, &"gun_twin")
	CardLevels.set_level(w, twin, 3)  # v0.9.5 CLV: Twin tops out at level 3
	W.run(w, 1, 0, W.S)
	assert_eq(_waves(w).size(), 3, "Lv 3: three")
	var b := _world([&"gun_backfire"], [Vector2(-4.0, 0.0), Vector2(4.0, 0.0)])
	_one(b)
	assert_eq(_dealt(b, 2)[0], 1, "the wave ahead")
	assert_eq(_dealt(b, 1)[0], 1, "and one behind")


func test_the_elements_feed_every_enemy_it_hits() -> void:
	var at: Array = [Vector2(2.0, 0.0), Vector2(4.0, 1.0), Vector2(6.0, -1.0)]
	var w := _world([&"ember_core"], at)
	_one(w)
	for k in [1, 2, 3]:
		assert_gt(w.actors.burn_stacks[k], 0, "Fire on enemy %d" % k)
	var v := _world([&"venom_core"], at)
	_one(v)
	assert_eq(
		W.events(v, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size(), 3, "one feed each"
	)


func test_single_target_dps_against_the_orbs() -> void:
	var o := _world([], [Vector2(4.0, 0.0)], true)
	W.run(o, 1800, 0, W.S)
	var orbs := _dealt(o, 1, 120, 1800)
	var w := _world()
	W.run(w, 1800, 0, W.S)
	var d := _dealt(w, 1, 120, 1800)
	var ratio := float(d[1]) / float(orbs[1])
	gut.p(
		(
			"AF3 Wave one target 4 m, 28 s: %d dmg in %d hits; orbs %d in %d; ratio %.3f"
			% [d[1], d[0], orbs[1], orbs[0], ratio]
		)
	)
	assert_gt(ratio, 0.8)
	var at: Array = []
	for k in 5:
		at.append(Vector2(2.0 + 1.5 * k, -1.0 + 0.5 * k))
	var crowd := _world([], at)
	var orbs5 := _world([], at, true)
	W.run(crowd, 720, 0, W.S)
	W.run(orbs5, 720, 0, W.S)
	var wt := 0
	var ot := 0
	for k in range(1, 6):
		wt += int(_dealt(crowd, k, 120, 720)[1])
		ot += int(_dealt(orbs5, k, 120, 720)[1])
	gut.p(
		(
			"AF3 Wave five spread 2-8 m ahead, 1 m either side, 10 s: wave %d, orbs %d, ratio %.3f"
			% [wt, ot, float(wt) / float(ot)]
		)
	)
	assert_gt(wt, ot, "a crowd: the wave beats the orbs")


func test_it_is_deterministic_and_a_snapshot_mid_flight_plays_on_the_same() -> void:
	var at: Array = [Vector2(2.0, 0.0), Vector2(5.0, 0.0)]
	var a := _world([], at)
	var b := _world([], at)
	for x: World in [a, b]:
		W.run(x, 30, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")
	assert_gt(_dealt(a, 1)[0], 0, "the first enemy was hit before the snapshot")
	var snap := a.to_snapshot()
	var c := _world([], at)
	assert_eq(WorldSnapshot.apply(c, snap), "")
	assert_eq(c.state_hash(), a.state_hash(), "restored mid-flight")
	for x: World in [a, c]:
		W.run(x, 60, 0, 0)
	assert_eq(c.state_hash(), a.state_hash(), "the same hits after")
	assert_eq(_dealt(a, 1)[0], 1, "the first enemy is not hit twice after the restore")


# --- The slots ------------------------------------------------------------------------------------------------------
func _slot_world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	return w


func test_the_wave_row_offers_only_its_cards() -> void:
	var w := _slot_world()
	assert_true(BuildSlots.take(w, W.item(w, &"gun_wave")))
	assert_eq(AttackSlots.form_id(w), &"wave")
	for idx in w.item_tables.size():
		var it := w.item_tables[idx]
		var cat := AttackSlots.category(w, idx)
		if (
			it.retired
			or it.requires_weapon == PlayerTable.WEAPON_BLADE
			or cat in [AttackSlots.FREE, AttackSlots.FORM]
		):
			continue
		assert_eq(AttackSlots.usable(w, idx), WAVE_ON.has(it.id), "%s with the Wave" % it.id)


func test_the_wave_replaces_the_other_forms() -> void:
	var w := _slot_world()
	var wv := W.item(w, &"gun_wave")
	for other: StringName in [&"gun_laser", &"gun_bomb", &"gun_void", &"gun_lance", &"gun_scatter"]:
		var o := W.item(w, other)
		assert_true(BuildSlots.take(w, o))
		assert_eq(int(Offers.info(w, wv)["replaces"]), o, "the Wave replaces %s" % other)
		assert_true(BuildSlots.take(w, wv))
		assert_false(w.items_owned.has(o), "the Wave and %s never coexist" % other)
		assert_eq(AttackSlots.form_id(w), &"wave")
		assert_true(WaveShots.is_wave(Modifiers.bolt(w)))
