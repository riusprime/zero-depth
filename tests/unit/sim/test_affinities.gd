extends GutTest
## v0.9.0 RB (owner, PLAN "Owner decisions" RB; docs/roadmap/v0.9.0/AFFINITIES.md A0-A5): each rune affinity's effect
## in the sim, from the shipped data (data/wardrobe), and None leaving the world as it was before RB.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 100000


func _table(id: StringName, w: World) -> AffinityTable:
	return RunContentCompiler.compile_affinity(W.repo().get_def(&"affinity", id), w.item_tables)


func _with(id: StringName, w: World) -> World:
	Affinities.setup(w, _table(id, w))
	return w


func test_none_builds_no_state_and_leaves_the_hash() -> void:
	var a := W.world(&"gun", [], [[Vector2(4, 0), HP]])
	var b := _with(&"none", W.world(&"gun", [], [[Vector2(4, 0), HP]]))
	assert_null(_table(&"none", b), "None compiles to no table")
	assert_null(b.affinity, "and the world holds no affinity state")
	W.run(a, 180, 0, W.S)
	W.run(b, 180, 0, W.S)
	assert_eq(b.state_hash(), a.state_hash(), "None hashes as a world before RB")


func test_every_other_affinity_builds_its_state() -> void:
	for id: StringName in [&"ember", &"storm", &"venom", &"astral", &"guardian"]:
		var w := _with(id, W.world(&"gun"))
		assert_not_null(w.affinity, "%s has a state" % id)
		assert_eq(w.affinity.table.id, id)


func _max_burn(w: World, i: int, ticks: int) -> int:
	var best := 0
	for k in ticks:
		w.step(W.frame(0, W.S, 0))
		best = maxi(best, w.actors.burn_t[i])
	return best


func test_ember_burns_last_half_again_as_long() -> void:
	var plain := W.world(&"gun", [&"ember_core"], [[Vector2(3, 0), HP]])
	var ember := _with(&"ember", W.world(&"gun", [&"ember_core"], [[Vector2(3, 0), HP]]))
	var base := plain.item_mods.burn_duration_ticks
	assert_gt(base, 0, "Ember Core burns")
	var p := _max_burn(plain, 1, 240)
	var e := _max_burn(ember, 1, 240)
	assert_gt(p, base - 2, "a plain burn lasts its duration (less the tick it already ran)")
	assert_eq(e - p, base * 1500 / 1000 - base, "Ember: 50 % longer")


func test_offer_weights_follow_the_affinity() -> void:
	var w := W.world(&"gun")
	var ember_core := W.item(w, &"ember_core")
	var frost_core := W.item(w, &"frost_core")
	var venom_core := W.item(w, &"venom_core")
	var gun_void := W.item(w, &"gun_void")
	var plain := {}
	for idx in [ember_core, frost_core, venom_core, gun_void]:
		plain[idx] = ItemPool.card_weight(w, idx, 3)
	_with(&"ember", w)
	assert_eq(ItemPool.card_weight(w, ember_core, 3), plain[ember_core] * 1300 / 1000, "ember x1.3")
	assert_eq(ItemPool.card_weight(w, frost_core, 3), plain[frost_core] * 700 / 1000, "frost x0.7")
	assert_eq(ItemPool.card_weight(w, venom_core, 3), plain[venom_core], "the others unchanged")
	_with(&"storm", w)
	assert_eq(
		ItemPool.card_weight(w, venom_core, 3), plain[venom_core] * 700 / 1000, "Storm: venom x0.7"
	)
	_with(&"venom", w)
	assert_eq(
		ItemPool.card_weight(w, venom_core, 3), plain[venom_core] * 1300 / 1000, "Venom: venom x1.3"
	)
	assert_eq(
		ItemPool.card_weight(w, ember_core, 3), plain[ember_core] * 700 / 1000, "Venom: ember x0.7"
	)
	_with(&"astral", w)
	assert_eq(
		ItemPool.card_weight(w, gun_void, 3), plain[gun_void] * 1300 / 1000, "Astral: void x1.3"
	)
	_with(&"guardian", w)
	for idx in plain:
		assert_eq(ItemPool.card_weight(w, idx, 3), plain[idx], "Guardian: no offer bias")


func _dash_past(w: World) -> void:
	# Dash along +x (4 m), past a dummy 0.8 m off the path and one 3 m off it.
	w.step(W.frame(W.D, 0, 0, Vector2i(127, 0)))
	W.run(w, 30)


func test_storm_dash_shocks_enemies_near_its_path_once() -> void:
	var enemies := [[Vector2(2.0, 0.8), HP], [Vector2(2.0, 3.0), HP]]
	var plain := W.world(&"gun", [&"static_chain"], enemies)
	var storm := _with(&"storm", W.world(&"gun", [&"static_chain"], enemies))
	_dash_past(plain)
	_dash_past(storm)
	assert_eq(plain.actors.shock_stacks[1], 0, "no crackle without Storm")
	assert_eq(storm.affinity.shocks, 1, "one enemy within 1 m of the path")
	assert_eq(storm.actors.shock_stacks[1], 1, "one shock stack")
	assert_eq(storm.actors.shock_stacks[2], 0, "the one 3 m off the path is untouched")


func test_storm_needs_shock_on_the_wand() -> void:
	var storm := _with(&"storm", W.world(&"gun", [], [[Vector2(2.0, 0.5), HP]]))
	_dash_past(storm)
	assert_eq(storm.affinity.shocks, 0, "no shock card: nothing holds the crackle")
	assert_eq(storm.actors.shock_stacks[1], 0)


func _poison_and_kill(w: World) -> void:
	var a := w.actors
	W.run(w, 2)  # a tick or two first: the actor grid the neighbour search reads
	var root := w.take_root()
	Venom.add(w, 1, 3, root)
	Damage.hit(w, 1, HP * 2, a.ids[0], a.ids[0], w.take_root(), 0, a.pos(0), a.pos(1))
	W.run(w, 2)


func test_venom_jumps_to_the_nearest_enemy_within_3m() -> void:
	# The dying one at 3 m; the nearest 3 m from it (beyond Venom Core's 2.5 m spread), the next 5 m from it.
	var enemies := [[Vector2(3, 0), 10], [Vector2(6, 0), HP], [Vector2(3, 5), HP]]
	var plain := W.world(&"gun", [&"venom_core"], enemies)
	var venom := _with(&"venom", W.world(&"gun", [&"venom_core"], enemies))
	_poison_and_kill(plain)
	_poison_and_kill(venom)
	assert_eq(
		plain.actors.poison_stacks[1],
		0,
		"without Venom the poison dies with it (beyond the spread)"
	)
	assert_eq(venom.affinity.jumps, 1, "Venom: one jump")
	assert_eq(venom.actors.poison_stacks[1], 3, "its stacks on the nearest within 3 m")
	assert_eq(venom.actors.poison_stacks[2], 0, "never farther")


func test_astral_has_no_combat_effect() -> void:
	var enemies := [[Vector2(4, 0), HP], [Vector2(6, 1), HP]]
	var plain := W.world(&"gun", [&"ember_core"], enemies)
	var astral := _with(&"astral", W.world(&"gun", [&"ember_core"], enemies))
	W.run(plain, 300, 0, W.S)
	W.run(astral, 300, 0, W.S)
	for i in plain.actors.size():
		assert_eq(astral.actors.hp[i], plain.actors.hp[i], "the same fight (actor %d)" % i)
	var r := WorldReader.new(astral)
	assert_eq(r.affinity_sense_m(), 8.0, "secrets within 8 m pulse")
	assert_true(r.affinity_maps_secrets(), "the minimap marks their rooms")
	assert_eq(WorldReader.new(plain).affinity_sense_m(), 0.0)


func test_guardian_ward_blocks_one_hit_a_floor() -> void:
	var w := _with(&"guardian", W.world(&"gun", [], [[Vector2(3, 0), HP]]))
	var a := w.actors
	var foe := a.ids[1]
	var hp := a.hp[0]
	assert_eq(w.affinity.ward, 1, "one ward at the floor's start")
	var got := Damage.hit(w, 0, 10, foe, foe, w.take_root(), 0, a.pos(1), a.pos(0))
	assert_eq(got, 0, "the ward takes the first hit")
	assert_eq(a.hp[0], hp, "no damage")
	assert_eq(w.affinity.ward, 0, "spent")
	assert_eq(w.affinity.ward_tick, w.tick)
	assert_eq(W.events(w, SimEvent.Kind.STATUS_APPLY, Affinities.EFFECT_WARD).size(), 1, "its cue")
	got = Damage.hit(w, 0, 10, foe, foe, w.take_root(), 0, a.pos(1), a.pos(0))
	assert_gt(got, 0, "the next hit lands")
	var fresh := _with(&"guardian", W.world(&"gun"))
	assert_eq(fresh.affinity.ward, 1, "a new floor's world: the ward is full again")


func test_guardian_picks_up_fewer_shards() -> void:
	var w := _with(&"guardian", W.world(&"gun"))
	assert_eq(Affinities.shards(w, 10), 8, "20 % fewer")
	assert_eq(Affinities.shards(w, 3), 2, "rounded half up")
	var plain := W.world(&"gun")
	assert_eq(Affinities.shards(plain, 10), 10, "unchanged without one")


func test_guardian_ward_does_not_eat_the_heros_own_blasts() -> void:
	var w := _with(&"guardian", W.world(&"gun"))
	var pid := w.actors.ids[0]
	Damage.hit(w, 0, 10, pid, pid, w.take_root(), 0, Vector2.ZERO, Vector2.ZERO)
	assert_eq(w.affinity.ward, 1, "the hero's own damage never spends it")
