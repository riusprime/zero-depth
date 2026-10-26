extends GutTest
## v0.9.5 FC0 (owner: Rune Explosion replaces Scatter; FORM_COMBOS.md R0, R1): the Rune Explosion form. A ring centred
## on the hero grows 0 to 3.5 m over 21 ticks (linear, whole mm) every 1.1 s while the hero attacks; each enemy is hit
## once per burst as the edge passes it, for 3.75 x an orb hit (3.0 before the DPS check), and shoved 0.4 m outward;
## Twin adds smaller later bursts (70 % size and share, 0.2 s apart; Lv 3 two of them); at most 3 live; its heat is the
## firing time only (v0.9.5 HT); a snapshot mid-burst plays on
## the same; an old save holding Scatter loads holding Rune Explosion.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const RUNE := &"gun_rune_explosion"


func _world(items: Array = [], at: Array = [Vector2(2.0, 0.0)], orbs: bool = false) -> World:
	var ids: Array = [] if orbs else [RUNE]
	ids.append_array(items)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, 0.35, HP)
	return w


## [hits, total] the player dealt on actor index `idx`.
func _dealt(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var n := 0
	var total := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id != id or e.tags & SimEvent.TAG_DOT:
			continue
		n += 1
		total += e.amount
	return [n, total]


## The ticks the dummy `idx` was hit on.
func _ticks(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			out.append(e.tick)
	return out


## One burst: SHOOT for a tick, then `rest` ticks without.
func _one(w: World, rest: int = 100) -> void:
	W.run(w, 1, 0, W.S)
	W.run(w, rest, 0, 0)


func test_the_card_makes_the_shot_a_rune_burst() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	var orb := Modifiers.bolt(W.world(&"gun"))
	assert_true(RuneExplosion.is_rune(s))
	assert_eq(s.rune_mm, 3500, "3.5 m")
	assert_eq(s.rune_ticks, 21, "0.35 s")
	assert_eq(s.period_ticks, 66, "every 1.1 s")
	assert_eq(s.damage, orb.damage * 375 / 100, "3.75 x an orb hit (3.0 tuned up by the DPS check)")
	_one(w, 5)
	assert_eq(w.projectiles.size(), 0, "no bolt leaves the hero")


func test_the_ring_grows_linearly_to_the_full_radius() -> void:
	var w := _world([], [])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	var edges: Array[float] = []
	var first := r.rune_bursts()
	assert_eq(first.size(), 1, "one burst")
	edges.append(first[0]["edge"])
	for k in 25:
		W.run(w, 1, 0, 0)
		var b := r.rune_bursts()
		if b.is_empty():
			break
		edges.append(b[0]["edge"])
	assert_almost_eq(edges[0], 0.0, 1e-6, "starts at the hero")
	for a in range(1, 22):
		assert_almost_eq(edges[a], 3.5 * a / 21.0, 0.002, "age %d" % a)
	assert_almost_eq(edges[21], 3.5, 1e-6, "full at 21 ticks")
	assert_almost_eq(edges[22], 3.5, 1e-6, "holds while it fades")
	assert_true(r.rune_active())


func test_each_enemy_is_hit_once_as_the_edge_passes_it() -> void:
	var w := _world([], [Vector2(2.0, 0.0), Vector2(0.0, 3.0), Vector2(5.0, 0.0)])
	_one(w, 120)
	for idx in [1, 2]:
		assert_eq(_dealt(w, idx)[0], 1, "enemy %d hit once" % idx)
	assert_eq(_dealt(w, 3)[0], 0, "past 3.5 m + its radius: not hit")
	# The edge reaches enemy 1 (2.0 m, 0.35 radius: 1.65 m) at age 10, enemy 2 (3.0 m: 2.65 m) at age 16.
	var t0: int = _ticks(w, 1)[0]
	var t1: int = _ticks(w, 2)[0]
	assert_eq(t1 - t0, 6, "the nearer one first, six ticks apart")


func test_it_hits_for_three_and_three_quarter_orb_hits() -> void:
	var o := _world([], [Vector2(2.0, 0.0)], true)
	W.run(o, 8, 0, W.S)
	var orb_hit: int = _dealt(o, 1)[1] / maxi(1, _dealt(o, 1)[0])
	var w := _world([], [Vector2(2.0, 0.0)])
	_one(w, 60)
	assert_eq(_dealt(w, 1)[1], orb_hit * 375 / 100, "x3.75 one orb hit")


func test_a_hit_enemy_is_shoved_four_tenths_of_a_metre_outward() -> void:
	var w := _world([], [Vector2(2.0, 0.0)])
	var id := w.actors.ids[1]
	_one(w, 40)
	var at := w.actors.pos(w.actors.index_of(id))
	assert_almost_eq(at.x, 2.4, 0.02, "0.4 m along hero -> enemy")
	assert_almost_eq(at.y, 0.0, 0.02)
	var far := _world([], [Vector2(5.0, 0.0)])
	_one(far, 40)
	assert_almost_eq(far.actors.pos(1).x, 5.0, 1e-4, "an enemy out of reach stays")


func test_the_burst_follows_the_hero() -> void:
	var w := _world([], [])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	var at: Vector2 = r.rune_bursts()[0]["pos"]
	W.run(w, 6, 0, 0, 0, Vector2i(127, 0))
	var now: Vector2 = r.rune_bursts()[0]["pos"]
	assert_gt(now.x, at.x + 0.2, "centred on the hero each tick")
	assert_eq(now, r.player_pos())


func test_its_heat_is_the_firing_time_only() -> void:  # v0.9.5 HT (was: it adds no heat)
	var w := W.world(&"gun", [RUNE], [[Vector2(2.0, 0.0), HP]], [], true)
	W.run(w, 150, 0, W.S)
	assert_gt(_dealt(w, 1)[0], 0, "it hit")
	assert_eq(Heat.points(w), 17, "no heat per hit; 150 firing ticks of 100/840 per tick")


func test_it_fires_on_its_period_while_attacking_and_not_without() -> void:
	var w := _world([], [Vector2(2.0, 0.0)])
	W.run(w, 200, 0, 0)
	assert_eq(_dealt(w, 1)[0], 0, "nothing without the button")
	W.run(w, 150, 0, W.S)
	assert_eq(_dealt(w, 1)[0], 3, "bursts at 0, 66 and 132 of 150 ticks held")


func test_twin_adds_a_smaller_burst_twelve_ticks_later() -> void:
	var w := _world([&"gun_twin"], [Vector2(2.0, 0.0), Vector2(3.0, 0.0)])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	W.run(w, 12, 0, 0)
	var bs := r.rune_bursts()
	assert_eq(bs.size(), 2, "two bursts")
	assert_almost_eq(float(bs[0]["radius"]), 3.5, 1e-6)
	assert_almost_eq(float(bs[1]["radius"]), 2.45, 1e-6, "70 % size")
	assert_eq(int(bs[0]["age"]) - int(bs[1]["age"]), 12, "0.2 s apart")
	W.run(w, 100, 0, 0)
	assert_eq(_dealt(w, 1)[0], 2, "the near enemy is in both")
	assert_eq(_dealt(w, 2)[0], 1, "3.0 m is past the small one's 2.45 m + 0.35")
	var ts := _ticks(w, 1)
	var first: int = _dealt(w, 1)[1]
	assert_gt(first, 0)
	assert_eq(ts.size(), 2)


func test_twin_extra_burst_deals_seventy_percent() -> void:
	var w := _world([&"gun_twin"], [Vector2(2.0, 0.0)])
	_one(w, 100)
	var amounts := []
	var id := w.actors.ids[1]
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			amounts.append(e.amount)
	assert_eq(amounts.size(), 2)
	var spec := Modifiers.bolt(w)
	assert_eq(amounts[1], maxi(1, (amounts[0] * spec.share_permille + 500) / 1000), "Twin's share")


func test_twin_level_three_adds_two_bursts() -> void:
	var w := _world([&"gun_twin"], [])
	CardLevels.set_level(w, W.item(w, &"gun_twin"), 3)
	assert_eq(Modifiers.bolt(w).twin, 2)
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	W.run(w, 24, 0, 0)
	var bs := r.rune_bursts()
	assert_eq(bs.size(), 3, "the first and two more")
	assert_almost_eq(float(bs[2]["radius"]), 2.45, 1e-6)
	assert_eq(int(bs[0]["age"]) - int(bs[2]["age"]), 24, "the third at 0.4 s")


func test_at_most_three_bursts_are_alive() -> void:
	var w := _world([&"gun_twin"], [])
	CardLevels.set_level(w, W.item(w, &"gun_twin"), 3)
	var s := Modifiers.bolt(w)
	var worst := 0
	for k in 300:
		W.run(w, 1, 0, W.S)
		worst = maxi(worst, w.mx.rune_uid.size())
	assert_lte(worst, RuneExplosion.LIVE_MAX)
	assert_eq(s.twin, 2)


func test_a_snapshot_mid_burst_plays_on_the_same() -> void:
	var at: Array = [Vector2(2.0, 0.0), Vector2(3.0, 0.0)]
	var a := _world([&"gun_twin"], at)
	var b := _world([&"gun_twin"], at)
	for x: World in [a, b]:
		W.run(x, 14, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")
	assert_gt(a.mx.rune_uid.size(), 0, "a burst is alive")
	var snap := a.to_snapshot()
	var c := _world([&"gun_twin"], at)
	assert_eq(WorldSnapshot.apply(c, snap), "")
	assert_eq(c.state_hash(), a.state_hash(), "restored mid-burst")
	for x: World in [a, c]:
		W.run(x, 80, 0, 0)
	assert_eq(c.state_hash(), a.state_hash(), "the same hits and shoves after")
	assert_eq(c.actors.hp[1], a.actors.hp[1], "the same damage taken")


func test_the_row_allows_twin_and_the_five_elements_only() -> void:
	var row: AttackFormRow = null
	var slots: AttackSlotsDefinition = W.repo().get_def(&"wand", &"attack_slots")
	for f in slots.forms:
		if f.id == &"rune_explosion":
			row = f
	assert_not_null(row)
	assert_eq(row.card, RUNE)
	var want: Array[StringName] = [
		&"gun_twin", &"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed"
	]
	assert_eq(row.allowed, want)


func test_scatter_is_retired_into_rune_explosion() -> void:
	var w := W.world(&"gun")
	var scatter := W.item(w, &"gun_scatter")
	assert_true(w.item_tables[scatter].retired, "Scatter is retired")
	assert_does_not_have(ItemPool.available(w), scatter, "never offered again")
	assert_has(ItemPool.available(w), W.item(w, RUNE), "Rune Explosion is offered")
