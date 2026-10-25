extends GutTest
## v0.9.0 AF3 (owner Q7; ATTACK_FORMS.md F10 "Orbs circle you and fire on their own at the nearest enemy while you aim
## and fire too … 3 wisps, each a 40 % orb every 0.6 s", every pattern and secondary off, elements all): the Wisps form.
## Three wisps circle the hero; each fires a 40 % orb every 0.6 s (staggered) at the nearest enemy it can see, SHOOT
## held or not; no enemy, no shot; the hero's own orbs are unchanged; the elements ride the wisps' orbs; the caps hold;
## its row; deterministic with no state of its own; its DPS over the orbs (reported, see WAVE_WISPS.md).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const WISPS_ON: Array[StringName] = [
	&"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed"
]


func _world(
	items: Array = [], at: Array = [Vector2(5.0, 0.0)], orbs: bool = false, r: float = 0.35
) -> World:
	var ids: Array = [] if orbs else [&"gun_wisps"]
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


func test_the_card_brings_three_wisps_and_keeps_the_orbs() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	var orb := Modifiers.bolt(W.world(&"gun"))
	assert_true(Wisps.is_wisps(s))
	assert_eq([s.wisps, s.wisp_ticks, s.wisp_permille], [3, 36, 400], "3 wisps, every 0.6 s, 40 %")
	assert_eq(
		[s.form, s.damage, s.period_ticks, s.count, s.speed, s.life_ticks],
		[orb.form, orb.damage, orb.period_ticks, orb.count, orb.speed, orb.life_ticks],
		"the hero's own shot stays the orbs"
	)
	assert_eq(Wisps.read(w).size(), 3)
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_wisps")
	assert_eq([def.rarity, def.requires_weapon], [ItemDefinition.Rarity.RARE, &"gun"])
	assert_eq(w.item_tables[W.item(w, &"gun_wisps")].slot_category, AttackSlots.FORM)
	assert_eq([def.name_key, def.desc_key], [&"ITEM_GUN_WISPS", &"ITEM_GUN_WISPS_DESC"])


func test_the_wisps_circle_the_hero_evenly() -> void:
	var w := _world([], [])
	var ws := Wisps.read(w)
	for wd: Dictionary in ws:
		assert_almost_eq(
			(wd["pos"] as Vector2).distance_to(w.player_pos()), Wisps.ORBIT_R_M, 0.01, "on the ring"
		)
	assert_eq((int(ws[1]["angle"]) - int(ws[0]["angle"])) & 4095, 1365, "a third of a turn apart")
	var a0 := int(ws[0]["angle"])
	W.run(w, 75, 0, 0)
	assert_eq((int(Wisps.read(w)[0]["angle"]) - a0) & 4095, 2048, "half a turn in 1.25 s")


func test_they_fire_on_their_own_at_the_nearest_enemy() -> void:
	var w := _world([], [Vector2(4.0, 0.0), Vector2(8.0, 0.0)])
	W.run(w, 360, 0, 0)
	var near := _dealt(w, 1)
	assert_eq(_dealt(w, 2)[0], 0, "the nearer enemy draws them all")
	assert_between(
		near[0], 28, 30, "3 wisps × 10 shots in 6 s, SHOOT never held (the last in flight)"
	)
	assert_eq(near[1], near[0] * 2, "each 40 % of 5")
	var none := _world([], [])
	W.run(none, 120, 0, 0)
	assert_eq(none.projectiles.size(), 0, "no enemy, no shot")


func test_they_stagger_over_the_period() -> void:
	var w := _world([], [Vector2(4.0, 0.0)])
	var ticks: Array[int] = []
	var seen := {}
	for k in 36:
		W.run(w, 1, 0, 0)
		for i in w.projectiles.size():
			if not seen.has(w.projectiles.ids[i]):
				seen[w.projectiles.ids[i]] = true
				ticks.append(w.tick)
	assert_eq(ticks.size(), 3, "one shot a wisp in 0.6 s")
	assert_eq([ticks[1] - ticks[0], ticks[2] - ticks[1]], [12, 12], "0.2 s apart")


func test_a_wall_hides_an_enemy_from_them() -> void:
	var w := _world([], [Vector2(5.0, 0.0)])
	w.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 3.0), 0))
	W.run(w, 120, 0, 0)
	assert_eq(w.projectiles.size(), 0, "behind a wall: no shot")


func test_the_hero_fires_too_and_the_wisps_add_damage() -> void:
	var o := _world([], [Vector2(4.0, 0.0)], true)
	var w := _world([], [Vector2(4.0, 0.0)])
	W.run(o, 1800, 0, W.S)
	W.run(w, 1800, 0, W.S)
	var orbs := _dealt(o, 1, 120, 1800)
	var both := _dealt(w, 1, 120, 1800)
	var ratio := float(both[1]) / float(orbs[1])
	(
		gut
		. p(
			(
				"AF3 Wisps + orbs one target 4 m, 28 s: %d dmg in %d hits; orbs alone %d in %d; ratio %.3f"
				% [both[1], both[0], orbs[1], orbs[0], ratio]
			)
		)
	)
	assert_gt(ratio, 1.2, "the orbs plus three wisps' 40 % orbs")
	var idle := _world([], [Vector2(4.0, 0.0)])
	W.run(idle, 1800, 0, 0)
	var alone := _dealt(idle, 1, 120, 1800)
	(
		gut
		. p(
			(
				"AF3 Wisps alone (SHOOT never held) one target 4 m, 28 s: %d dmg in %d hits; ratio to the orbs %.3f"
				% [alone[1], alone[0], float(alone[1]) / float(orbs[1])]
			)
		)
	)


func test_the_elements_ride_the_wisps_orbs() -> void:
	var w := _world([&"ember_core"], [Vector2(4.0, 0.0)])
	W.run(w, 120, 0, 0)
	assert_gt(w.actors.burn_stacks[1], 0, "Fire from the wisps alone")


func test_their_orbs_are_no_root_launch_and_stay_under_forty_a_second() -> void:
	var w := _world([], [Vector2(4.0, 0.0)])
	var launched := {}
	var per_tick: Array[int] = []
	var most := 0
	var wisp := 0
	for k in 600:
		W.run(w, 1, 0, W.S)
		var n := 0
		for i in w.projectiles.size():
			var pid := w.projectiles.ids[i]
			if w.projectiles.team[i] == ActorStore.TEAM_PLAYER and not launched.has(pid):
				launched[pid] = true
				n += 1
				wisp += 1 if Wisps.is_wisp_shot(w, i) else 0
		per_tick.append(n)
		var window := 0
		for j in range(maxi(0, per_tick.size() - 60), per_tick.size()):
			window += per_tick[j]
		most = maxi(most, window)
	gut.p(
		(
			"AF3 Wisps + orbs held 10 s: most launched in any 60 ticks %d; wisp orbs %d of %d"
			% [most, wisp, launched.size()]
		)
	)
	assert_lte(most, 40, "40 a second at most")
	assert_between(wisp, 48, 51, "5 a second from the wisps")


func test_it_is_deterministic_and_a_snapshot_plays_on_the_same() -> void:
	var a := _world()
	var b := _world()
	for x: World in [a, b]:
		W.run(x, 50, 0, 0)
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")
	var snap := a.to_snapshot()
	var c := _world()
	assert_eq(WorldSnapshot.apply(c, snap), "")
	assert_eq(c.state_hash(), a.state_hash(), "restored")
	for x: World in [a, c]:
		W.run(x, 60, 0, 0)
	assert_eq(c.state_hash(), a.state_hash(), "the same shots after")


# --- The slots ------------------------------------------------------------------------------------------------------
func _slot_world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	return w


func test_the_wisps_row_offers_only_the_elements() -> void:
	var w := _slot_world()
	assert_true(BuildSlots.take(w, W.item(w, &"gun_wisps")))
	assert_eq(AttackSlots.form_id(w), &"wisps")
	for idx in w.item_tables.size():
		var it := w.item_tables[idx]
		var cat := AttackSlots.category(w, idx)
		if (
			it.retired
			or it.requires_weapon == PlayerTable.WEAPON_BLADE
			or cat in [AttackSlots.FREE, AttackSlots.FORM]
		):
			continue
		assert_eq(AttackSlots.usable(w, idx), WISPS_ON.has(it.id), "%s with the Wisps" % it.id)


func test_the_wisps_replace_the_other_forms() -> void:
	var w := _slot_world()
	var wi := W.item(w, &"gun_wisps")
	for other: StringName in [
		&"gun_laser", &"gun_bomb", &"gun_void", &"gun_lance", &"gun_scatter", &"gun_wave"
	]:
		var o := W.item(w, other)
		assert_true(BuildSlots.take(w, o))
		assert_eq(int(Offers.info(w, wi)["replaces"]), o, "the Wisps replace %s" % other)
		assert_true(BuildSlots.take(w, wi))
		assert_false(w.items_owned.has(o), "the Wisps and %s never coexist" % other)
		assert_eq(AttackSlots.form_id(w), &"wisps")
		assert_true(Wisps.is_wisps(Modifiers.bolt(w)))
