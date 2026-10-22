extends GutTest
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F5 "Hold to charge, release one piercing line shot; longer charge, more damage
## … up to 1.2 s, ×1 → ×5 damage, pierces all", Twin yes, the rest off, elements along the line): the Lance form. The
## charge grows while SHOOT is held and waits full; the release is one line that hits every enemy on it once, a wall
## stops it; × 1 for a tap, × 5 at 1.2 s, linear between; Twin's lines at its share; no projectile; the elements on
## every enemy along the line; its row; its single-target DPS against the orbs (reported, see LANCE_SCATTER.md).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const LANCE_ON: Array[StringName] = [
	&"gun_twin", &"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed"
]


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


func test_the_card_makes_the_shot_a_charged_line() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	var orb := Modifiers.bolt(W.world(&"gun"))
	assert_true(Lance.is_lance(s))
	assert_eq(s.form, AttackSpec.Form.BEAM, "a line, no projectile")
	assert_eq([s.hold_ticks, s.hold_permille], [72, 5000], "up to 1.2 s, × 5 at full")
	assert_almost_eq(s.reach_m, orb.speed * orb.life_ticks, 0.05, "as far as an orb flies")
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
	W.run(w, 200, 0, W.S)
	assert_almost_eq(Lance.charge(w), 1.0, 1e-6, "full")
	assert_eq(W.events(w, SimEvent.Kind.LANCE).size(), 0, "held: nothing fires, even full")
	assert_eq(_dealt(w, 1)[0], 0)
	W.run(w, 1, 0, 0)
	assert_eq(W.events(w, SimEvent.Kind.LANCE).size(), 1, "the release fires one line")
	assert_eq(_dealt(w, 1), [1, 25], "× 5 at full: 25")
	assert_eq(Lance.charge(w), 0.0, "spent")
	assert_eq(w.projectiles.size(), 0, "no projectile")


func test_damage_grows_linearly_from_a_tap_to_full() -> void:
	for c: Array in [[1, 5], [36, 15], [72, 25]]:
		var w := _world()
		_charge_release(w, c[0])
		assert_eq(_dealt(w, 1), [1, c[1]], "%d ticks held: %d" % c)


func test_the_line_pierces_every_enemy_on_it_once_and_a_wall_stops_it() -> void:
	var at: Array = [Vector2(2.0, 0.0), Vector2(4.0, 0.1), Vector2(6.0, -0.1), Vector2(9.5, 0.0)]
	var w := _world([], at)
	_charge_release(w, 72)
	for k in [1, 2, 3, 4]:
		assert_eq(_dealt(w, k), [1, 25], "enemy %d on the line: one full hit" % k)
	var off := _world([], [Vector2(4.0, 1.0), Vector2(12.0, 0.0)])
	_charge_release(off, 72)
	assert_eq(_dealt(off, 1)[0], 0, "1 m off the line: missed")
	assert_eq(_dealt(off, 2)[0], 0, "past its 10.8 m: missed")
	var walled := _world([], [Vector2(1.5, 0.0), Vector2(4.0, 0.0)])
	walled.add_wall_now(Obb.make(Vector2(2.5, 0.0), Vector2(0.2, 2.0), 0))
	_charge_release(walled, 72)
	assert_eq(_dealt(walled, 1)[0], 1, "before the wall: hit")
	assert_eq(_dealt(walled, 2)[0], 0, "behind it: safe")
	var e: SimEvent = W.events(walled, SimEvent.Kind.LANCE)[0]
	assert_lt(e.amount, 2500, "the line ends on the wall")


func test_releases_wait_the_period_then_charge_again() -> void:
	var w := _world()
	_charge_release(w, 72)
	W.run(w, 10, 0, W.S)
	assert_eq(Lance.charge(w), 0.0, "the period first: no charge yet")
	W.run(w, 72, 0, W.S)
	assert_gt(Lance.charge(w), 0.0, "then it charges")
	W.run(w, 1, 0, 0)
	assert_eq(W.events(w, SimEvent.Kind.LANCE).size(), 2)


func test_twin_fires_two_lines_and_three_at_level_five_at_its_share() -> void:
	var w := _world([&"gun_twin"], [Vector2(5.0, 0.0)], false, 1.2)
	var twin := W.item(w, &"gun_twin")
	assert_eq(Lance.trace(w, Modifiers.bolt(w), Vector2.ZERO, 0).size(), 2, "Lv 1: two")
	CardLevels.set_level(w, twin, 5)
	assert_eq(Lance.trace(w, Modifiers.bolt(w), Vector2.ZERO, 0).size(), 3, "Lv 5: three")
	CardLevels.set_level(w, twin, 1)
	_charge_release(w, 72)
	assert_eq(W.events(w, SimEvent.Kind.LANCE).size(), 2, "two lines")
	assert_eq(_dealt(w, 1), [2, 30], "a wide enemy on both: 60 % of 25 each")
	assert_eq(w.projectiles.size(), 0, "no projectile spent")


func test_the_elements_feed_every_enemy_along_the_line() -> void:
	var at: Array = [Vector2(2.0, 0.0), Vector2(4.0, 0.0), Vector2(6.0, 0.0)]
	var w := _world([&"ember_core"], at)
	_charge_release(w, 72)
	for k in [1, 2, 3]:
		assert_gt(w.actors.burn_stacks[k], 0, "Fire on enemy %d" % k)
	var v := _world([&"venom_core"], at)
	_charge_release(v, 30)
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
					"AF1 Lance one target 4 m, %s charge (%d ticks), 28 s: %d dmg in %d hits; orbs %d in %d; ratio %.3f"
					% [c[0], c[1], d[1], d[0], orbs[1], orbs[0], out[c[0]]]
				)
			)
		)
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
			"AF1 Lance five in a line 2-8 m, full charge, 10 s: lance %d, orbs %d, ratio %.3f"
			% [lt, ot, float(lt) / float(ot)]
		)
	)
	assert_gt(lt, 0)


func test_it_is_deterministic_and_a_snapshot_mid_charge_plays_on_the_same() -> void:
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
		W.run(x, 1, 0, 0)
	assert_eq(c.state_hash(), a.state_hash(), "the same release")


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
