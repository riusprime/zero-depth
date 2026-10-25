extends GutTest
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F5) and AF1b (owner, PLAN "Owner decisions" AF1b: the charge "the same as
## the original ball", "a circle in front of the player", "moves the player back"; "Pierces all", "A small step",
## "Grows with charge"): the Lance form. The charge grows while SHOOT is held and waits full; the release is one ball
## like the orb (its speed and range) that pierces every enemy once and stops on a wall; × 1 for a tap, × 11.6 at
## 1.2 s, linear between; the ball × 1 → × 2 wide; the hero pushed back 0.5 m at full (walls stop it); Twin's balls at
## its share; the elements on every enemy it crosses; its row; its single-target DPS against the orbs
## (LANCE_SCATTER.md).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const LANCE_ON: Array[StringName] = [
	&"gun_twin", &"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed"
]
## Ticks after a release for a ball to fly its whole range.
const FLY := 60


## A Gun world holding `items` (the Lance first unless `orbs`) and a standing dummy at each of `at` (radius `r`).
func _world(
	items: Array = [], at: Array = [Vector2(4.0, 0.0)], orbs: bool = false, r: float = 0.35
) -> World:
	var ids: Array = [] if orbs else [&"gun_lance"]
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


## Holds SHOOT `held` ticks, then lets go for `rest` ticks.
func _charge_release(w: World, held: int, rest: int = 1) -> void:
	W.run(w, held, 0, W.S)
	W.run(w, rest, 0, 0)


func test_the_card_makes_the_shot_a_charged_piercing_ball() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	var orb := Modifiers.bolt(W.world(&"gun"))
	assert_true(Lance.is_lance(s))
	assert_eq(s.form, AttackSpec.Form.BOLT, "a ball, as the orb")
	assert_eq(s.pierce, Lance.PIERCE_ALL, "pierces all")
	assert_eq([s.hold_ticks, s.hold_permille], [72, 11600], "up to 1.2 s, × 11.6 at full")
	assert_eq(
		[s.speed, s.life_ticks, s.radius_m], [orb.speed, orb.life_ticks, orb.radius_m], "the orb's"
	)
	assert_eq(s.period_ticks, 24, "0.4 s between a release and the next charge")
	assert_eq(s.damage, orb.damage, "× 1 is one orb hit")
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_lance")
	assert_eq([def.rarity, def.requires_weapon], [ItemDefinition.Rarity.RARE, &"gun"])
	assert_eq(w.item_tables[W.item(w, &"gun_lance")].slot_category, AttackSlots.FORM)
	assert_eq([def.name_key, def.desc_key], [&"ITEM_GUN_LANCE", &"ITEM_GUN_LANCE_DESC"])


func test_holding_charges_and_a_full_lance_waits_for_the_release() -> void:
	var w := _world()
	W.run(w, 36, 0, W.S)
	assert_almost_eq(Lance.charge(w), 0.5, 1e-6, "half way at 0.6 s")
	assert_false(Lance.orb(w).is_empty(), "the charging ball in front of the hero")
	W.run(w, 200, 0, W.S)
	assert_almost_eq(Lance.charge(w), 1.0, 1e-6, "full")
	assert_eq(W.events(w, SimEvent.Kind.LANCE).size(), 0, "held: nothing fires, even full")
	assert_eq(w.projectiles.size(), 0)
	W.run(w, 1, 0, 0)
	assert_eq(W.events(w, SimEvent.Kind.LANCE).size(), 1, "the release fires one ball")
	assert_eq(Lance.charge(w), 0.0, "spent")
	assert_true(Lance.orb(w).is_empty())
	W.run(w, FLY, 0, 0)
	assert_eq(_dealt(w, 1), [1, 58], "× 11.6 at full: 58")


func test_damage_grows_linearly_from_a_tap_to_full() -> void:
	for c: Array in [[1, 5], [36, 31], [72, 58]]:
		var w := _world()
		_charge_release(w, c[0], FLY)
		assert_eq(_dealt(w, 1), [1, c[1]], "%d ticks held: %d" % c)


func test_the_ball_grows_with_the_charge_and_its_hit_is_as_wide() -> void:
	var orb_r := Modifiers.bolt(W.world(&"gun")).radius_m
	var radii := []
	for held: int in [1, 36, 72]:
		var w := _world([], [])
		_charge_release(w, held, 2)
		assert_eq(w.projectiles.size(), 1, "one ball")
		radii.append(w.projectiles.radius[0])
		var e: SimEvent = W.events(w, SimEvent.Kind.LANCE)[0]
		assert_almost_eq(e.amount / 1000.0, w.projectiles.radius[0], 0.001, "the event's radius")
	gut.p(
		(
			"AF1b Lance ball radius: tap %.3f, half %.3f, full %.3f (orb %.3f)"
			% [radii[0], radii[1], radii[2], orb_r]
		)
	)
	assert_almost_eq(float(radii[0]), orb_r, orb_r * 0.02, "a tap: orb-sized")
	assert_almost_eq(float(radii[1]), orb_r * 1.5, orb_r * 0.02, "half: × 1.5")
	assert_almost_eq(float(radii[2]), orb_r * 2.0, 1e-4, "full: × 2")
	# An enemy just outside a tap's reach of the line but inside a full ball's is hit only by the full ball.
	var off := 0.35 + orb_r * 1.5
	var tap := _world([], [Vector2(4.0, off)])
	_charge_release(tap, 1, FLY)
	assert_eq(_dealt(tap, 1)[0], 0, "a tap misses %.2f m off the line" % off)
	var full := _world([], [Vector2(4.0, off)])
	_charge_release(full, 72, FLY)
	assert_eq(_dealt(full, 1)[0], 1, "the full ball's wider hit reaches it")


func test_the_ball_pierces_every_enemy_once_and_a_wall_stops_it() -> void:
	var at: Array = [Vector2(2.0, 0.0), Vector2(4.0, 0.1), Vector2(6.0, -0.1), Vector2(9.5, 0.0)]
	var w := _world([], at)
	_charge_release(w, 72, FLY)
	for k in [1, 2, 3, 4]:
		assert_eq(_dealt(w, k), [1, 58], "enemy %d in its path: one full hit" % k)
	var off := _world([], [Vector2(4.0, 1.2), Vector2(12.5, 0.0)])
	_charge_release(off, 72, FLY)
	assert_eq(_dealt(off, 1)[0], 0, "1.2 m off the line: missed")
	assert_eq(_dealt(off, 2)[0], 0, "past the orb's range: missed")
	var walled := _world([], [Vector2(1.5, 0.0), Vector2(4.0, 0.0)])
	walled.add_wall_now(Obb.make(Vector2(2.5, 0.0), Vector2(0.2, 2.0), 0))
	_charge_release(walled, 72, FLY)
	assert_eq(_dealt(walled, 1)[0], 1, "before the wall: hit")
	assert_eq(_dealt(walled, 2)[0], 0, "behind it: safe")
	assert_eq(walled.projectiles.size(), 0, "the wall ended it")


func test_the_release_pushes_the_hero_back_and_walls_stop_it() -> void:
	var pushes := []
	for held: int in [1, 36, 72]:
		var w := _world([], [])
		_charge_release(w, held, 1)
		if held == 72:
			assert_eq(w.mx.recoil_t, Lance.RECOIL_TICKS - 1, "the push back runs")
		W.run(w, 20, 0, 0)
		assert_eq(w.mx.recoil_t, 0, "and ends")
		pushes.append(w.player_pos())
	gut.p(
		(
			"AF1b Lance recoil (aim +x, from 0,0): tap %.4f m, half %.4f m, full %.4f m"
			% [-pushes[0].x, -pushes[1].x, -pushes[2].x]
		)
	)
	assert_almost_eq(pushes[2].x, -Lance.RECOIL_M, 0.01, "full: 0.5 m back, opposite the aim")
	assert_almost_eq(pushes[1].x, -Lance.RECOIL_M * 0.5, 0.01, "half: a quarter metre")
	assert_gt(pushes[0].x, -0.02, "a tap: almost none")
	assert_almost_eq(pushes[2].y, 0.0, 1e-4)
	var aimed := _world([], [])
	W.run(aimed, 72, 0, W.S, 1024)  # aim +y
	W.run(aimed, 21, 0, 0, 1024)
	assert_almost_eq(aimed.player_pos().y, -Lance.RECOIL_M, 0.01, "aimed +y: pushed to -y")
	var walled := _world([], [])
	walled.add_wall_now(Obb.make(Vector2(-0.6, 0.0), Vector2(0.1, 2.0), 0))  # its face at x = -0.5
	_charge_release(walled, 72, 30)
	var x := walled.player_pos().x
	gut.p(
		(
			"AF1b Lance recoil against a wall 0.5 m behind: hero x %.4f (radius %.2f)"
			% [x, walled.player.radius_m]
		)
	)
	assert_gte(x, -0.5 + walled.player.radius_m - 0.01, "the wall stops it")
	assert_lt(x, 0.0, "it still stepped back up to the wall")


func test_releases_wait_the_period_then_charge_again() -> void:
	var w := _world()
	_charge_release(w, 72)
	W.run(w, 10, 0, W.S)
	assert_eq(Lance.charge(w), 0.0, "the period first: no charge yet")
	W.run(w, 72, 0, W.S)
	assert_gt(Lance.charge(w), 0.0, "then it charges")
	W.run(w, 1, 0, 0)
	assert_eq(W.events(w, SimEvent.Kind.LANCE).size(), 2)


func test_twin_fires_two_balls_and_three_at_level_five_at_its_share() -> void:
	var w := _world([&"gun_twin"], [Vector2(5.0, 0.0)], false, 1.2)
	_charge_release(w, 72, 2)
	assert_eq(w.projectiles.size(), 2, "Lv 1: two balls")
	W.run(w, FLY, 0, 0)
	assert_eq(_dealt(w, 1), [2, 70], "a wide enemy on both: 60 % of 58 each (rounded)")
	var five := _world([&"gun_twin"], [])
	CardLevels.set_level(five, W.item(five, &"gun_twin"), 5)
	_charge_release(five, 72, 2)
	assert_eq(five.projectiles.size(), 3, "Lv 5: three balls")
	var vy := []
	for k in 3:
		vy.append(signf(snappedf(five.projectiles.vel_y[k], 0.001)))
	vy.sort()
	assert_eq(vy, [-1.0, 0.0, 1.0], "fanned: one straight, one either side")
	assert_eq(W.events(five, SimEvent.Kind.LANCE).size(), 1, "one release")


func test_the_elements_feed_every_enemy_along_its_path() -> void:
	var at: Array = [Vector2(2.0, 0.0), Vector2(4.0, 0.0), Vector2(6.0, 0.0)]
	var w := _world([&"ember_core"], at)
	_charge_release(w, 72, FLY)
	for k in [1, 2, 3]:
		assert_gt(w.actors.burn_stacks[k], 0, "Fire on enemy %d" % k)
	var v := _world([&"venom_core"], at)
	_charge_release(v, 30, FLY)
	assert_eq(
		W.events(v, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size(), 3, "one feed each"
	)


func test_single_target_dps_against_the_orbs() -> void:
	var o := _world([], [Vector2(4.0, 0.0)], true)
	W.run(o, 1800, 0, W.S)
	var orbs := _dealt(o, 1, 120, 1800)
	var out := {}
	for c: Array in [["full", 72], ["half", 36], ["tap", 1]]:
		var w := _world()
		while w.tick < 1800:
			_charge_release(w, c[1], 1)
			W.run(w, 23, 0, 0)  # the period runs out (24 ticks after the release)
		var d := _dealt(w, 1, 120, 1800)
		out[c[0]] = float(d[1]) / float(orbs[1])
		(
			gut
			. p(
				(
					"AF1b Lance one target 4 m, %s charge (%d ticks), 28 s: %d dmg in %d hits; orbs %d in %d; ratio %.3f"
					% [c[0], c[1], d[1], d[0], orbs[1], orbs[0], out[c[0]]]
				)
			)
		)
	assert_between(out["full"], 0.9, 1.1, "a full charge about 1.0x the orbs on one target (AF1)")
	assert_gt(out["full"], out["half"], "a full charge beats a half one")
	assert_gt(out["half"], out["tap"], "and a half one beats tapping")
	var at: Array = []
	for k in 5:
		at.append(Vector2(2.0 + 1.5 * k, 0.0))
	var line := _world([], at)
	var lined := _world([], at, true)
	while line.tick < 720:
		_charge_release(line, 72, 1)
		W.run(line, 23, 0, 0)
	W.run(lined, 720, 0, W.S)
	var lt := 0
	var ot := 0
	for k in range(1, 6):
		lt += int(_dealt(line, k, 120, 720)[1])
		ot += int(_dealt(lined, k, 120, 720)[1])
	gut.p(
		(
			"AF1b Lance five in a line 2-8 m, full charge, 10 s: lance %d, orbs %d, ratio %.3f"
			% [lt, ot, float(lt) / float(ot)]
		)
	)
	assert_gt(float(lt) / float(ot), 1.5, "far stronger on a line")


func test_it_is_deterministic_and_a_snapshot_mid_charge_or_recoil_plays_on_the_same() -> void:
	var a := _world()
	var b := _world()
	for x: World in [a, b]:
		W.run(x, 50, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")
	var snap := a.to_snapshot()
	var c := _world()
	assert_eq(WorldSnapshot.apply(c, snap), "")
	assert_eq(c.state_hash(), a.state_hash(), "restored mid-charge")
	for x: World in [a, c]:
		W.run(x, 30, 0, W.S)
		W.run(x, 3, 0, 0)
	assert_gt(a.mx.recoil_t, 0, "mid push back")
	var mid := a.to_snapshot()
	var d := _world()
	assert_eq(WorldSnapshot.apply(d, mid), "")
	assert_eq(d.state_hash(), a.state_hash(), "restored mid push back")
	var before := a.state_hash()
	a.mx.recoil_t += 1
	assert_ne(a.state_hash(), before, "the push back is hashed")
	a.mx.recoil_t -= 1
	for x: World in [a, c, d]:
		W.run(x, 30, 0, 0)
	assert_eq(c.state_hash(), a.state_hash(), "the same release")
	assert_eq(d.state_hash(), a.state_hash(), "the same push back")
	assert_eq(a.player_pos(), d.player_pos())


# --- The slots ------------------------------------------------------------------------------------------------------
func _slot_world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	return w


func test_the_lance_row_offers_only_its_cards() -> void:
	var w := _slot_world()
	assert_true(BuildSlots.take(w, W.item(w, &"gun_lance")))
	assert_eq(AttackSlots.form_id(w), &"lance")
	for idx in w.item_tables.size():
		var it := w.item_tables[idx]
		var cat := AttackSlots.category(w, idx)
		if (
			it.retired
			or it.requires_weapon == PlayerTable.WEAPON_BLADE
			or cat in [AttackSlots.FREE, AttackSlots.FORM]
		):
			continue
		assert_eq(AttackSlots.usable(w, idx), LANCE_ON.has(it.id), "%s with the Lance" % it.id)


func test_the_lance_replaces_the_other_forms() -> void:
	var w := _slot_world()
	var lance := W.item(w, &"gun_lance")
	for other: StringName in [&"gun_laser", &"gun_bomb", &"gun_void", &"gun_scatter"]:
		var o := W.item(w, other)
		assert_true(BuildSlots.take(w, o))
		assert_eq(int(Offers.info(w, lance)["replaces"]), o, "the Lance replaces %s" % other)
		assert_true(BuildSlots.take(w, lance))
		assert_false(w.items_owned.has(o), "the Lance and %s never coexist" % other)
		assert_eq(AttackSlots.form_id(w), &"lance")
		assert_true(Lance.is_lance(Modifiers.bolt(w)))
