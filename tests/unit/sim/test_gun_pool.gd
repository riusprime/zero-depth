extends GutTest
## v0.6.5 WN3 (docs/design/WAND.md, the Gun pool G1–G16, owner "Approve all"): each Gun card's rewrite of the bolt
## (the compiled spec, the numbers the table names as starting values) and its effect in a scripted Gun scene
## (standing dummies, scripted input, crit off), then the same card in the AttackScenario fight, whose events it
## changes. Order, levels and the pool: test_gun_pool_order.gd. Mechanics only: no bot, no balance (owner P1).

const W := preload("res://tests/support/mx4_world.gd")
const FORM := AttackSpec.Form
const TRIG := AttackSpec.Trigger
const CARDS: Array[StringName] = [
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"gun_twin",
	&"gun_spread",
	&"split_shot",
	&"gun_pierce",
	&"gun_ricochet",
	&"gun_homing",
	&"boomerang",
	&"orbit_rounds",
	&"gun_spiral",
	&"gun_mine",
	&"gun_charge",
	&"gun_echo",
	&"gun_backfire",
	&"halo_shot",
]


func _plain() -> AttackSpec:
	return Modifiers.bolt(W.world(&"gun"))


## The player's projectiles (index list).
func _mine(w: World) -> Array[int]:
	var out: Array[int] = []
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			out.append(i)
	return out


func _pos(w: World, i: int) -> Vector2:
	return Vector2(w.projectiles.pos_x[i], w.projectiles.pos_y[i])


func test_the_sixteen_cards_are_gun_wand_cards() -> void:
	var w := W.world(&"gun")
	for id in CARDS:
		var k := W.item(w, id)
		assert_gte(k, 0, "%s shipped" % id)
		var t := w.item_tables[k]
		assert_true(CardLevels.is_card(w, k), "%s levels up (tag wand)" % id)
		assert_eq(t.requires_weapon, PlayerTable.WEAPON_GUN, "%s: the Gun's pool" % id)
		assert_true(BuildSlots.is_slot_item(t), "%s takes a wand slot" % id)
		assert_ne(String(tr(t.name_key)), String(t.name_key), "%s has an en name" % id)


# --- G1–G16, each ----------------------------------------------------------------------------------------------
func test_g1_big_shot_is_a_fat_slow_orb() -> void:
	var p := _plain()
	var w := W.world(&"gun", [&"gun_big_shot"], [[Vector2(3.0, 0.0), 2000]])
	var s := Modifiers.bolt(w)
	assert_almost_eq(s.radius_m, p.radius_m * 2.0, 1e-5, "× 2 size")
	assert_almost_eq(s.speed, p.speed * 0.75, 1e-5, "− 25 % speed")
	assert_eq(s.damage, p.damage * 1600 / 1000, "× 1.6 damage")
	assert_eq(s.damage_mul_permille, 1600, "the view's weight")
	W.run(w, 1, 0, W.S)
	W.run(w, 1)
	assert_almost_eq(
		w.projectiles.radius[_mine(w)[0]], p.radius_m * 2.0, 1e-5, "the bolt in flight"
	)
	W.run(w, 30)
	var d := W.damage(w, &"")
	assert_gt(d.size(), 0)
	assert_eq(d[0].amount_applied, s.damage)


func test_g2_rapid_fire_is_a_stream_of_small_bolts() -> void:
	var p := _plain()
	var w := W.world(&"gun", [&"gun_rapid_fire"])
	var s := Modifiers.bolt(w)
	assert_almost_eq(s.radius_m, p.radius_m * 0.6, 1e-5)
	assert_eq(s.rate_bonus_permille, 600)
	assert_eq(s.damage, p.damage * 700 / 1000)
	assert_lt(ItemEffects.shot_period_ticks(w), ItemEffects.shot_period_ticks(W.world(&"gun")))
	var plain := W.world(&"gun")
	W.run(w, 60, 0, W.S)
	W.run(plain, 60, 0, W.S)
	var a := W.events(w, SimEvent.Kind.SPAWN).size()
	var b := W.events(plain, SimEvent.Kind.SPAWN).size()
	# v0.8.0 GF1: 9 ticks a shot plain, 9 / 1.6 = 5.6 -> 6 with Rapid Fire: 7 vs 10 in a second (+50 % in whole
	# ticks, the card's +60 % rounded; it was 7 / 1.6 = 4.4 -> 4, +75 %, before).
	assert_eq([a, b], [10, 7], "more bolts in a second (%d vs %d)" % [a, b])


func test_g3_twin_fires_two_side_by_side() -> void:
	var w := W.world(&"gun", [&"gun_twin"])
	assert_eq(Modifiers.bolt(w).twin, 1)
	W.run(w, 1, 0, W.S)
	var m := _mine(w)
	assert_eq(m.size(), 2, "paired bolts")
	assert_eq(
		[w.projectiles.vel_x[m[0]], w.projectiles.vel_y[m[0]]],
		[w.projectiles.vel_x[m[1]], w.projectiles.vel_y[m[1]]],
		"parallel"
	)
	var gap := absf(_pos(w, m[0]).y - _pos(w, m[1]).y)
	assert_almost_eq(
		gap, Modifiers.bolt(w).radius_m * GunForms.TWIN_GAP_RADII, 1e-4, "side by side"
	)


func test_g4_spread_becomes_a_three_shot_fan() -> void:
	var w := W.world(&"gun", [&"gun_spread"])
	var s := Modifiers.bolt(w)
	assert_eq([s.count, s.spread], [3, ContentCompiler.degrees_to_units(30.0)])
	W.run(w, 1, 0, W.S)
	var m := _mine(w)
	assert_eq(m.size(), 3, "a fan")
	var ys := []
	for i in m:
		ys.append(signf(w.projectiles.vel_y[i]))
	ys.sort()
	assert_eq(ys, [-1.0, 0.0, 1.0], "one each way and one straight")


func test_g5_split_bursts_into_three_half_size_shards_at_the_hit() -> void:
	var w := W.world(&"gun", [&"split_shot"], [[Vector2(2.0, 0.0), 2000]])
	var k := W.hook_of(Modifiers.bolt(w), &"split_shot")
	assert_eq([k.trigger, k.child.count], [TRIG.ON_HIT, 3])
	# v0.8.0 GF1: the splits keep the card's own 0.08 m (half the old 0.16 m bolt; the bolt grew, the card didn't).
	assert_almost_eq(k.child.radius_m, 0.08, 1e-5, "the card's size")
	assert_lt(k.child.radius_m, _plain().radius_m * 0.5, "under half the bolt")
	W.run(w, 1, 0, W.S)
	var seen := 0
	for t in 20:
		w.step(W.frame())
		seen = maxi(seen, W.projectiles_of(w, &"split_shot"))
	assert_eq(seen, 3)


func test_g6_pierce_streaks_through_two_enemies() -> void:
	var line := [[Vector2(2.0, 0.0), 2000], [Vector2(3.0, 0.0), 2000], [Vector2(4.0, 0.0), 2000]]
	var w := W.world(&"gun", [&"gun_pierce"], line)
	assert_eq(Modifiers.bolt(w).pierce, 2)
	W.run(w, 1, 0, W.S)
	W.run(w, 30)
	assert_eq(W.targets(W.damage(w, &"")).size(), 3, "one bolt, three enemies in a line")
	var plain := W.world(&"gun", [], line)
	W.run(plain, 1, 0, W.S)
	W.run(plain, 30)
	assert_eq(W.targets(W.damage(plain, &"")).size(), 1, "a plain bolt stops at the first")


func test_g7_ricochet_bounces_off_walls_twice() -> void:
	var w := W.world(&"gun", [&"gun_ricochet"])
	var walls: Array[Obb] = [Obb.make(Vector2(3.0, 0.0), Vector2(0.3, 4.0), 0)]
	w.set_walls(walls)
	assert_eq(Modifiers.bolt(w).bounces, 2)
	W.run(w, 1, 0, W.S)
	var back := false
	for t in 20:
		w.step(W.frame())
		var m := _mine(w)
		back = back or (not m.is_empty() and w.projectiles.vel_x[m[0]] < 0.0)
	assert_true(back, "it comes off the wall")
	assert_eq(w.projectiles.bounces[_mine(w)[0]], 1, "one bounce left")


func test_g8_homing_curves_toward_the_nearest_enemy() -> void:
	var w := W.world(&"gun", [&"gun_homing"], [[Vector2(3.0, 2.0), 2000]])
	assert_gt(Modifiers.bolt(w).homing, 0)
	W.run(w, 1, 0, W.S)
	W.run(w, 40)
	assert_gt(W.damage(w, &"").size(), 0, "a bolt aimed along +x turns into the enemy off its line")


func test_g9_boomerang_comes_back_through_you() -> void:
	var w := W.world(&"gun", [&"boomerang"])
	assert_eq(Modifiers.bolt(w).returns, 1)
	W.run(w, 1, 0, W.S)
	var far := 0.0
	var near_end := 99.0
	for t in Modifiers.bolt(w).life_ticks + 2:
		w.step(W.frame())
		var m := _mine(w)
		if m.is_empty():
			break
		var d := _pos(w, m[0]).length()
		far = maxf(far, d)
		near_end = d
	assert_gt(far, 3.0, "out")
	assert_lt(near_end, 1.0, "and back to the player")


func test_g10_orbit_circles_you_once_before_it_flies_out() -> void:
	var w := W.world(&"gun", [&"orbit_rounds"])
	assert_eq(Modifiers.bolt(w).orbit_ticks, 30)
	W.run(w, 1, 0, W.S)
	W.run(w, 20)
	assert_lt(_pos(w, _mine(w)[0]).length(), ProjectileMoves.ORBIT_R_M + 0.3, "round you")
	W.run(w, 30)
	assert_gt(_pos(w, _mine(w)[0]).length(), ProjectileMoves.ORBIT_R_M + 1.0, "then out")


func test_g11_spiral_travels_in_a_corkscrew() -> void:
	var w := W.world(&"gun", [&"gun_spiral"])
	assert_eq(Modifiers.bolt(w).spiral, ContentCompiler.degrees_to_units(35.0))
	W.run(w, 1, 0, W.S)
	var lo := 0.0
	var hi := 0.0
	var crossings := 0
	var last := 0.0
	for t in 34:
		w.step(W.frame())
		var y := _pos(w, _mine(w)[0]).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
		if signf(y) != signf(last) and absf(y) > 0.02:
			crossings += 1
			last = y
		elif absf(y) > 0.02:
			last = y
	assert_gt(hi, 0.2, "it swings to one side of its line")
	assert_lt(lo, -0.2, "and the other")
	assert_gte(crossings, 2, "round and round (a helix seen from above)")
	assert_gt(_pos(w, _mine(w)[0]).x, 6.0, "while it flies on along the aim")


func test_g12_mine_stops_at_its_range_waits_and_explodes_on_contact() -> void:
	var w := W.world(&"gun", [&"gun_mine"])
	var s := Modifiers.bolt(w)
	assert_eq(s.mine_ticks, 180, "3 s")
	var k := W.hook_of(s, &"gun_mine")
	assert_eq([k.trigger, k.child.form], [TRIG.ON_END, FORM.BURST])
	W.run(w, 1, 0, W.S)
	W.run(w, s.life_ticks + 10)
	var m := _mine(w)
	assert_eq(m.size(), 1, "still there past its flight")
	var at := _pos(w, m[0])
	assert_almost_eq(at.length(), s.speed * s.life_ticks, 1.0, "where its flight ended")
	assert_eq(Vector2(w.projectiles.vel_x[m[0]], w.projectiles.vel_y[m[0]]), Vector2.ZERO, "still")
	w.add_dummy(at + Vector2(0.3, 0.0), 0.35, 2000)
	W.run(w, 2)
	assert_eq(_mine(w).size(), 0, "the touch sets it off")
	assert_gt(W.damage(w, &"gun_mine").size(), 0, "the blast hits")
	var lone := W.world(&"gun", [&"gun_mine"])
	W.run(lone, 1, 0, W.S)
	W.run(lone, s.life_ticks + 170)
	assert_eq(_mine(lone).size(), 1, "an untouched mine waits its 3 s")
	W.run(lone, 20)
	assert_eq(_mine(lone).size(), 0, "then it's gone")


func test_g13_charge_grows_while_held_and_fires_on_release() -> void:
	var p := _plain()
	var w := W.world(&"gun", [&"gun_charge"])
	var s := Modifiers.bolt(w)
	assert_eq([s.hold_ticks, s.hold_permille], [60, 3000])
	W.run(w, 30, 0, W.S)
	assert_eq(_mine(w).size(), 0, "holding charges, nothing fires yet")
	assert_eq(w.mx.hold_t, 30)
	assert_almost_eq(GunForms.charge_fraction(w), 0.5, 1e-6, "the view's swelling orb")
	W.run(w, 1)
	var m := _mine(w)
	assert_eq(m.size(), 1, "the release fires")
	assert_almost_eq(w.projectiles.radius[m[0]], p.radius_m * 2.0, 1e-5, "half charged: × 2")
	assert_eq(w.projectiles.damage[m[0]], p.damage * 2)
	var full := W.world(&"gun", [&"gun_charge"])
	W.run(full, 61, 0, W.S)
	var f := _mine(full)
	assert_eq(f.size(), 1, "a full charge fires by itself")
	assert_almost_eq(full.projectiles.radius[f[0]], p.radius_m * 3.0, 1e-5, "up to × 3 size")
	assert_eq(full.projectiles.damage[f[0]], p.damage * 3, "and damage")


func test_g14_echo_fires_again_later_at_sixty_percent() -> void:
	var w := W.world(&"gun", [&"gun_echo"])
	var s := Modifiers.bolt(w)
	assert_eq([s.repeat_delay_ticks, s.repeat_damage_permille], [18, 600])
	W.run(w, 1, 0, W.S)
	assert_eq(_mine(w).size(), 1)
	assert_eq(w.mx.q_key.size(), 1, "the echo waits")
	W.run(w, 18)
	var m := _mine(w)
	assert_eq(m.size(), 2, "a ghost volley follows")
	assert_eq(w.projectiles.damage[m[1]], s.damage * 600 / 1000)


func test_g15_backfire_also_fires_behind_you() -> void:
	var w := W.world(&"gun", [&"gun_backfire"], [[Vector2(-2.0, 0.0), 2000]])
	assert_eq(Modifiers.bolt(w).back_permille, 1000)
	W.run(w, 1, 0, W.S)
	var m := _mine(w)
	assert_eq(m.size(), 2, "both directions")
	assert_eq(w.projectiles.damage[m[0]], w.projectiles.damage[m[1]], "the same bolt")
	W.run(w, 20)
	assert_gt(W.damage(w, &"").size(), 0, "the enemy behind is hit")


func test_g16_halo_fires_a_ring_at_half_range() -> void:
	var p := _plain()
	var w := W.world(&"gun", [&"halo_shot"])
	var s := Modifiers.bolt(w)
	assert_eq([s.count, s.directions, s.life_ticks], [3, AttackSpec.DIR_CIRCLE, p.life_ticks / 2])
	W.run(w, 1, 0, W.S)
	assert_eq(_mine(w).size(), 3, "a ring of shots")


# --- In a fight --------------------------------------------------------------------------------------------------
func test_every_gun_card_changes_the_scripted_gun_fight_and_replays() -> void:
	var plain := WandLab.run(WandLab.fight(&"gun", []), 240)
	# v0.8.0 GF1: the bigger bolt lands every shot of the first 6 s, so Ricochet first bounces later (8 s).
	var plain_long := WandLab.run(WandLab.fight(&"gun", []), 480)
	for id in CARDS:
		var n := 480 if id == &"gun_ricochet" else 240
		var a := WandLab.run(WandLab.fight(&"gun", [id]), n)
		var b := WandLab.run(WandLab.fight(&"gun", [id]), n)
		var base: Dictionary = plain_long if n == 480 else plain
		assert_ne(a["digest"], base["digest"], "%s changes what happens" % id)
		assert_eq([b["digest"], b["hash"]], [a["digest"], a["hash"]], "%s replays" % id)


func test_the_view_reads_each_cards_look_on_the_bolt() -> void:
	# AttackFormLooks composes the bolt from its spec (never from the cards held): size, count, path and cue.
	var want := {
		&"gun_big_shot": ["width", 1.3],
		&"gun_twin": ["cue", &"twin"],
		&"gun_spread": ["count", 3],
		&"gun_pierce": ["cue", &"streak"],
		&"gun_ricochet": ["cue", &"bounce_flash"],
		&"gun_homing": ["cue", &"curve"],
		&"boomerang": ["cue", &"tether"],
		&"gun_spiral": ["cue", &"helix"],
		&"gun_mine": ["cue", &"mine"],
		&"gun_charge": ["cue", &"swell"],
		&"halo_shot": ["count", 3],
	}
	for id: StringName in want:
		var r := WorldReader.new(W.world(&"gun", [id]))
		var look := AttackFormLooks.compose(r.attack_spec(WorldReader.ATTACK_BOLT))
		var w: Array = want[id]
		match String(w[0]):
			"cue":
				assert_has(look["cues"], w[1], String(id))
			"count":
				assert_eq(look["count"], w[1], String(id))
			"width":
				assert_almost_eq(float(look["width"]), float(w[1]), 1e-4, String(id))
