extends GutTest
## v0.11.0 O11 (owner Q17-Q20; docs/roadmap/v0.11.0/SPELLS.md, every row approved): the full roster with the shipped
## data. Each spell's Lv 1 effect and its Lv 5 extra (O10's three included: Frost Nova's shatter, Fireball's burning
## ground, Sky Strike's stun); the offer rule offers each element's three spells; Leech's heal cap; Meteor's mark locks
## and enemies can walk out of it; Static Field's dash discharge; a soak with every spell at Lv 5 (no LIMIT event, the
## same hash replayed) and the snapshot with the lasting spells in flight. Crit is off, so the numbers are exact.

const W := preload("res://tests/support/mx4_world.gd")
const ALL_CARDS := [&"frost_core", &"ember_core", &"storm_core", &"venom_core", &"shared_bleed"]


func _world(items: Array = [], enemies: Array = [], seed_value: int = 9) -> World:
	var w := W.world(&"gun", items, enemies, [], false, seed_value)
	w.reward_table = ContentCompiler.compile_rewards(W.repo().get_def(&"rewards", &"floor"))
	w.spell_tables = SpellCompiler.compile(W.repo(), w.item_tables)
	w.spell_rules = SpellCompiler.compile_rules(W.repo())
	w.pair_table = WandCompiler.pairs(W.repo())  # the game's (Lightning's charge needs it)
	return w


## Spell k held at level `lv` (loop 2 opens Lv 4-5).
func _hold(w: World, k: int, lv: int = 1) -> void:
	if lv > 3:
		w.loop = 2
	for n in lv:
		Offers.apply(w, Offers.spell_code(k))
	assert_eq(Spells.level(w, k), lv, "held at Lv %d" % lv)


func _lost(w: World, id: int) -> int:
	var i := w.actors.index_of(id)
	return w.actors.max_hp[i] - w.actors.hp[i]


func _hits(w: World, effect: StringName, target := -1) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in W.events(w, SimEvent.Kind.HIT, effect):
		if target < 0 or e.target_id == target:
			out.append(e)
	return out


func _fx(w: World, kind: int) -> int:
	var n := 0
	for k in w.spell_fx_kind.size():
		if w.spell_fx_kind[k] == kind:
			n += 1
	return n


func _zones(w: World, kind: int) -> Array[int]:
	var out: Array[int] = []
	for k in w.spell_zone_kind.size():
		if w.spell_zone_kind[k] == kind:
			out.append(k)
	return out


func _ring(at: Vector2, r: float, n: int, hp: int) -> Array:
	var out := []
	for k in n:
		var a := TAU * k / n
		out.append([at + Vector2(cos(a), sin(a)) * r, hp])
	return out


func test_the_fifteen_compile_and_each_element_offers_its_three() -> void:
	var w := _world()
	assert_eq(w.spell_tables.size(), 15, "all fifteen rows ship")
	for k in 15:
		var t := Spells.table(w, k)
		assert_not_null(t, "spell %d" % k)
		assert_eq(t.id, SpellDefinition.SPELLS[k])
		assert_eq(t.damage.size(), 5, "%s: Lv 1-5" % t.id)
		assert_eq(t.level_keys.size(), 5)
		assert_eq(t.element, k / 3, "%s: its row's element" % t.id)
	assert_eq(Spells.table(w, Spells.BURNING_GROUND).cooldown_ticks, 600, "B2: 10 s")
	assert_eq(Spells.table(w, Spells.METEOR).cooldown_ticks, 960, "B3: 16 s")
	var groups := {
		&"frost_core": [Spells.BLIZZARD, Spells.FROST_NOVA, Spells.ICE_LANCES],
		&"ember_core": [Spells.FIREBALL, Spells.BURNING_GROUND, Spells.METEOR],
		&"storm_core": [Spells.SKY_STRIKE, Spells.BALL_LIGHTNING, Spells.STATIC_FIELD],
		&"venom_core": [Spells.VENOM_ORB, Spells.TOXIC_CLOUD, Spells.SPITTER_VINE],
		&"shared_bleed": [Spells.BLOOD_THORNS, Spells.HEMORRHAGE, Spells.LEECH],
	}
	for card: StringName in groups:
		var cw := _world([card])
		assert_eq(Spells.pool(cw), PackedInt32Array(groups[card]), "%s: its three" % card)
		var got := {}
		for s in 300:
			var ow := _world([card], [], 4000 + s)
			var id := ow.add_reward(RewardStore.Kind.ALTAR, Vector2(100, 100), 0)
			var k := Spells.offer_card(ow, ow.rewards.index_of(id))
			if k >= 0:
				got[k] = int(got.get(k, 0)) + 1
		gut.p("%s offers %s" % [card, got])
		for k: int in groups[card]:
			assert_gt(int(got.get(k, 0)), 10, "%s: spell %d is offered" % [card, k])


func test_blizzard_storms_the_pack_pulses_and_chills_lv5_freezes_at_the_end() -> void:
	var enemies := [[Vector2(0, 7), 100000], [Vector2(1, 7.5), 100000], [Vector2(-1, 7.2), 100000]]
	enemies.append([Vector2(6, -6), 100000])  # outside the storm
	var w := _world([&"frost_core"], enemies)
	var inside := w.actors.ids[1]
	var out := w.actors.ids[4]
	_hold(w, Spells.BLIZZARD)
	W.run(w, 1)
	assert_eq(_zones(w, SpellZones.BLIZZARD).size(), 1, "a storm")
	assert_eq(w.spell_zone_pos[0], Vector2(0, 7), "on the densest pack")
	assert_almost_eq(w.spell_zone_r[0], 4.0, 0.001, "4 m")
	assert_gt(w.actors.slow_t[w.actors.index_of(inside)], 0, "chilled")
	W.run(w, 260)
	assert_eq(_zones(w, SpellZones.BLIZZARD).size(), 0, "over after 4 s")
	assert_eq(_hits(w, &"spell_blizzard", inside).size(), 8, "a hit every 0.5 s for 4 s")
	assert_eq(_lost(w, out), 0, "outside: untouched")
	var w5 := _world([&"frost_core"], enemies)
	_hold(w5, Spells.BLIZZARD, 5)
	W.run(w5, 1)
	var end := w5.spell_zone_end[0]
	assert_almost_eq(w5.spell_zone_r[0], 5.5, 0.001, "Lv 5: 5.5 m")
	W.run(w5, end - w5.tick)  # the tick before its end (w.tick reads the next tick)
	var i := w5.actors.index_of(inside)
	w5.actors.frozen_t[i] = 0  # TEST HELPER: clear the stacks' own freeze, so the end's shows
	w5.actors.frost_stacks[i] = 0
	W.run(w5, 1)
	assert_eq(_zones(w5, SpellZones.BLIZZARD).size(), 0, "ended")
	assert_gt(w5.actors.frozen_t[i], 50, "Lv 5: still inside at the end: frozen 1 s")
	assert_eq(_hits(w5, &"spell_blizzard", inside).size(), 12, "Lv 5: 6 s")


func test_ice_lances_three_shards_pass_through_two_and_lv5_kills_split() -> void:
	var enemies := [
		[Vector2(3, 0), 100000],  # A, its line holds three more
		[Vector2(5, 0), 100000],
		[Vector2(7, 0), 100000],
		[Vector2(9, 0), 100000],
		[Vector2(-1.5, 2.6), 100000],  # B, C: 3 m away at other angles
		[Vector2(-1.5, -2.6), 100000],
	]
	var w := _world([&"frost_core"], enemies)
	var ids := []
	for k in 6:
		ids.append(w.actors.ids[k + 1])
	_hold(w, Spells.ICE_LANCES)
	W.run(w, 1)
	assert_eq(_fx(w, Spells.FX_LANCE), 3, "3 shards")
	for k in [0, 1, 2, 4, 5]:
		assert_eq(_lost(w, ids[k]), 13, "enemy %d: one 13 hit" % k)
	assert_eq(_lost(w, ids[3]), 0, "the 4th on the line: past the 2 a shard passes")
	assert_gt(w.actors.frost_stacks[w.actors.index_of(ids[0])], 0, "frost stacks")
	var w5 := _world(
		[&"frost_core"], [[Vector2(3, 0), 5], [Vector2(3, 3), 100000], [Vector2(3, -3), 100000]]
	)
	var sides := [w5.actors.ids[2], w5.actors.ids[3]]
	_hold(w5, Spells.ICE_LANCES, 5)
	W.run(w5, 1)
	var split := 0
	for id: int in sides:
		split += _hits(w5, &"spell_ice_lances", id).size()
	assert_gt(
		split, 2, "Lv 5: the kill split into 2 more (the sides: their own shards and the splits)"
	)
	var w4 := _world(
		[&"frost_core"], [[Vector2(3, 0), 5], [Vector2(3, 3), 100000], [Vector2(3, -3), 100000]]
	)
	_hold(w4, Spells.ICE_LANCES, 4)
	W.run(w4, 1)
	assert_eq(
		_fx(w5, Spells.FX_LANCE) - _fx(w4, Spells.FX_LANCE), 2, "two more shard lines at Lv 5"
	)


func test_burning_ground_burns_under_you_on_10_s_and_lv5_follows() -> void:
	var w := _world([&"ember_core"], [[Vector2(1, 0), 100000], [Vector2(4, 0), 100000]])
	var near := w.actors.ids[1]
	var far := w.actors.ids[2]
	_hold(w, Spells.BURNING_GROUND)
	W.run(w, 1)
	assert_eq(_zones(w, SpellZones.FIRE).size(), 1, "a patch under you")
	assert_almost_eq(w.spell_zone_r[0], 3.0, 0.001)
	assert_eq(w.spell_cd[0], 600, "10 s")
	assert_gt(w.actors.burn_stacks[w.actors.index_of(near)], 0, "it burns")
	W.run(w, 300)
	assert_eq(_hits(w, &"spell_burning_ground", near).size(), 10, "5 s at a hit each 0.5 s")
	assert_eq(_hits(w, &"spell_burning_ground", far).size(), 0, "4 m: outside")
	assert_eq(_zones(w, SpellZones.FIRE).size(), 0, "out after 5 s")
	var w5 := _world([&"ember_core"], [[Vector2(1, 0), 100000]])
	_hold(w5, Spells.BURNING_GROUND, 5)
	W.run(w5, 1)
	w5.actors.set_pos(0, Vector2(6, 0))  # TEST HELPER: the hero steps away
	W.run(w5, 60)
	assert_almost_eq(w5.spell_zone_pos[0].x, 3.0, 0.1, "Lv 5: it followed at 3 m/s (half speed)")


func test_meteor_marks_and_locks_enemies_can_walk_out_then_it_strikes_and_knocks_down() -> void:
	var pack := [[Vector2(0, 7), 100000], [Vector2(1, 7.5), 100000], [Vector2(-1, 7.2), 100000]]
	var w := _world([&"ember_core"], pack)
	var stay := w.actors.ids[1]
	var leaver := w.actors.ids[3]
	_hold(w, Spells.METEOR)
	W.run(w, 1)
	var marks := _zones(w, SpellZones.METEOR_MARK)
	assert_eq(marks.size(), 1, "a mark")
	assert_eq(w.spell_zone_pos[0], Vector2(0, 7), "on the densest pack")
	assert_eq(w.spell_cd[0], 960, "16 s")
	w.actors.set_pos(w.actors.index_of(leaver), Vector2(-1, 13))  # TEST HELPER: it walks out
	w.actors.set_pos(w.actors.index_of(stay), Vector2(0.5, 7))
	W.run(w, 40)
	assert_eq(w.spell_zone_pos[0], Vector2(0, 7), "locked where it appeared")
	assert_eq(_hits(w, &"spell_meteor").size(), 0, "not yet")
	W.run(w, 40)
	assert_eq(_zones(w, SpellZones.METEOR_MARK).size(), 0, "struck after 1.2 s")
	assert_eq(_lost(w, stay), 16, "inside: 16")
	assert_eq(_lost(w, leaver), 0, "walked out: untouched")
	assert_eq(_fx(w, Spells.FX_STRIKE), 1)
	var w2 := _world([&"ember_core"], pack)
	_hold(w2, Spells.METEOR)
	W.run(w2, 73)
	var i := w2.actors.index_of(w2.actors.ids[1])
	assert_true(Spells.held_still(w2, i), "knocked down")
	assert_eq(ItemProcs.slow_factor(w2, i), 0.0, "it doesn't walk")
	W.run(w2, 31)
	assert_false(Spells.held_still(w2, i), "up again after 0.5 s")
	var w5 := _world([&"ember_core"], pack)
	_hold(w5, Spells.METEOR, 5)
	W.run(w5, 74)
	assert_eq(_zones(w5, SpellZones.FIRE).size(), 1, "Lv 5: the crater burns")
	W.run(w5, 240)
	assert_eq(_zones(w5, SpellZones.FIRE).size(), 0, "for 4 s")


func test_sky_strike_lv5_bolts_stun_for_a_moment() -> void:
	var enemies := []
	for k in 6:
		enemies.append([Vector2(2 + k * 1.2, 0), 100000])
	var w := _world([&"storm_core"], enemies, 41)
	_hold(w, Spells.SKY_STRIKE, 5)
	W.run(w, 1)
	var held := 0
	for i in range(1, w.actors.size()):
		if Spells.held_still(w, i):
			held += 1
	assert_gt(held, 0, "Lv 5: the struck are stunned")
	W.run(w, 18)
	for i in range(1, w.actors.size()):
		assert_false(Spells.held_still(w, i), "0.3 s later: free")
	var w4 := _world([&"storm_core"], enemies, 41)
	_hold(w4, Spells.SKY_STRIKE, 4)
	W.run(w4, 1)
	assert_true(w4.spell_hold_id.is_empty(), "Lv 4: no stun")


func test_ball_lightning_rolls_ahead_zapping_one_and_lv5_bursts() -> void:
	var w := _world([&"storm_core"], [[Vector2(2, 0), 100000], [Vector2(3, 0.5), 100000]])
	_hold(w, Spells.BALL_LIGHTNING)
	W.run(w, 1)
	var orbs := _zones(w, SpellZones.ORB)
	assert_eq(orbs.size(), 1, "an orb")
	W.run(w, 30)
	assert_gt(w.spell_zone_pos[0].x, 0.5, "it rolls out ahead (the facing)")
	W.run(w, 220)
	assert_eq(_zones(w, SpellZones.ORB).size(), 0, "gone after 4 s")
	var zaps := _hits(w, &"spell_ball_lightning")
	assert_gt(zaps.size(), 5, "zaps every 0.3 s while they are in reach")
	var ticks := {}
	for e in zaps:
		ticks[e.tick] = int(ticks.get(e.tick, 0)) + 1
	for t: int in ticks:
		assert_eq(ticks[t], 1, "Lv 1: one enemy a zap")
	var w5 := _world(
		[&"storm_core"],
		[[Vector2(2, 0), 100000], [Vector2(3, 0.5), 100000], [Vector2(8.5, 0), 100000]]
	)
	_hold(w5, Spells.BALL_LIGHTNING, 5)
	W.run(w5, 260)
	assert_eq(_fx(w5, Spells.FX_DISCHARGE), 1, "Lv 5: it bursts at the end")
	var burst := 0
	for e in _hits(w5, &"spell_ball_lightning"):
		if e.amount == 15:
			burst += 1
	assert_gt(burst, 0, "the burst's 15")


func test_static_field_shocks_around_you_and_lv5_dash_discharges_it() -> void:
	var w := _world([&"storm_core"], [[Vector2(1.5, 0), 100000], [Vector2(3.5, 0), 100000]])
	var near := w.actors.ids[1]
	var far := w.actors.ids[2]
	_hold(w, Spells.STATIC_FIELD)
	W.run(w, 241)
	assert_eq(_hits(w, &"spell_static_field", near).size(), 8, "every 0.5 s for 4 s")
	assert_eq(_hits(w, &"spell_static_field", far).size(), 0, "3.5 m: outside the 2.5 m ring")
	assert_gt(w.actors.charged_t[w.actors.index_of(near)], 0, "charged, as a Storm hit")
	var w5 := _world([&"storm_core"], [[Vector2(1.5, 0), 100000], [Vector2(3.8, 0), 100000]])
	_hold(w5, Spells.STATIC_FIELD, 5)
	W.run(w5, 10)
	assert_eq(_zones(w5, SpellZones.STATIC).size(), 1)
	assert_eq(_fx(w5, Spells.FX_DISCHARGE), 0, "no dash: no discharge")
	var d := InputFrame.DASH
	W.run(w5, 1, d, d, 0, Vector2i(0, 127))
	assert_true(w5.is_dashing())
	assert_eq(_fx(w5, Spells.FX_DISCHARGE), 1, "Lv 5: the dash discharges it")
	assert_eq(_zones(w5, SpellZones.STATIC).size(), 0, "spent")
	var big := 0
	for e in _hits(w5, &"spell_static_field"):
		if e.amount == 12:
			big += 1
	assert_eq(big, 2, "a 4 m burst of 12: both")
	var w4 := _world([&"storm_core"], [[Vector2(1.5, 0), 100000]])
	_hold(w4, Spells.STATIC_FIELD, 4)
	W.run(w4, 10)
	W.run(w4, 1, d, d, 0, Vector2i(0, 127))
	assert_eq(_fx(w4, Spells.FX_DISCHARGE), 0, "Lv 4: a dash does nothing")


func test_venom_orb_lands_a_pool_that_stacks_venom_and_lv5_deaths_leave_pools() -> void:
	var pack := [[Vector2(0, 6), 100000], [Vector2(1, 6.5), 100000], [Vector2(-1, 6.2), 100000]]
	var w := _world([&"venom_core"], pack)
	var one := w.actors.ids[1]
	_hold(w, Spells.VENOM_ORB)
	W.run(w, 1)
	assert_eq(w.spell_ball_pos.size(), 1, "the orb is lobbed")
	W.run(w, 50)
	assert_eq(w.spell_ball_pos.size(), 0, "landed")
	var pools := _zones(w, SpellZones.POOL)
	assert_eq(pools.size(), 1, "a pool")
	assert_eq(w.spell_zone_pos[pools[0]], Vector2(0, 6), "at the pack")
	W.run(w, 61)
	assert_gte(w.actors.poison_stacks[w.actors.index_of(one)], 2, "a venom stack each 0.5 s")
	W.run(w, 300)
	assert_eq(_zones(w, SpellZones.POOL).size(), 0, "dried after 5 s")
	assert_eq(_hits(w, &"spell_venom_orb", one).size(), 10, "10 pulses")
	var low := [[Vector2(0, 6), 3], [Vector2(1, 6.5), 100000], [Vector2(-1, 6.2), 100000]]
	var w5 := _world([&"venom_core"], low)
	_hold(w5, Spells.VENOM_ORB, 5)
	W.run(w5, 80)
	var small := 0
	for k in _zones(w5, SpellZones.POOL):
		if w5.spell_zone_aux[k] == 1:
			small += 1
			assert_almost_eq(w5.spell_zone_r[k], 1.5, 0.001, "a small pool")
	assert_eq(small, 1, "Lv 5: the one that died in it left a small pool")


func test_toxic_cloud_puffs_behind_you_one_hit_a_tick_and_lv5_slows() -> void:
	var w := _world([&"venom_core"], [[Vector2(1, 0), 100000]])
	var e := w.actors.ids[1]
	_hold(w, Spells.TOXIC_CLOUD)
	W.run(w, 1)
	assert_eq(_zones(w, SpellZones.CLOUD).size(), 1, "the cloud")
	assert_eq(_zones(w, SpellZones.PUFF).size(), 1, "its first puff")
	W.run(w, 100)
	assert_gt(_zones(w, SpellZones.PUFF).size(), 2, "the puffs overlap")
	var ticks := {}
	for h in _hits(w, &"spell_toxic_cloud", e):
		ticks[h.tick] = int(ticks.get(h.tick, 0)) + 1
	for t: int in ticks:
		assert_eq(ticks[t], 1, "one hit a tick however many puffs")
	assert_gt(w.actors.poison_stacks[w.actors.index_of(e)], 0, "venom")
	assert_eq(Spells.hold_permille(w, w.actors.index_of(e)), 1000, "Lv 1: no slow")
	W.run(w, 500)
	assert_eq(w.spell_zone_kind.size(), 0, "all gone after 6 + 2 s")
	var w5 := _world([&"venom_core"], [[Vector2(1, 0), 100000]])
	_hold(w5, Spells.TOXIC_CLOUD, 5)
	W.run(w5, 2)
	var i := w5.actors.index_of(w5.actors.ids[1])
	assert_eq(Spells.hold_permille(w5, i), 600, "Lv 5: slowed to 60 %")
	assert_almost_eq(ItemProcs.slow_factor(w5, i), 0.6, 0.001)


func test_spitter_vine_spits_from_where_you_stood_two_heads_and_lv5_through() -> void:
	var w := _world([&"venom_core"], [[Vector2(5, 0), 100000], [Vector2(-5, 0), 100000]])
	_hold(w, Spells.SPITTER_VINE)
	W.run(w, 1)
	var vines := _zones(w, SpellZones.VINE)
	assert_eq(vines.size(), 1)
	w.actors.set_pos(0, Vector2(0, 20))  # TEST HELPER: you walk off; the vine stays
	W.run(w, 480)
	assert_eq(_zones(w, SpellZones.VINE).size(), 0, "8 s")
	var shots := _hits(w, &"spell_spitter_vine")
	assert_eq(shots.size(), 14, "one shot each 0.6 s for 8 s")
	var w3 := _world([&"venom_core"], [[Vector2(5, 0), 100000], [Vector2(-5, 0), 100000]])
	_hold(w3, Spells.SPITTER_VINE, 3)
	W.run(w3, 1)
	assert_eq(_hits(w3, &"spell_spitter_vine").size(), 2, "Lv 3: two heads, two enemies")
	var line := [[Vector2(3, 0), 100000], [Vector2(5, 0), 100000], [Vector2(6.5, 0), 100000]]
	var w5 := _world([&"venom_core"], line)
	var back := w5.actors.ids[3]
	_hold(w5, Spells.SPITTER_VINE, 5)
	W.run(w5, 1)
	assert_gt(_hits(w5, &"spell_spitter_vine", back).size(), 0, "Lv 5: through to the third")
	var w4 := _world([&"venom_core"], line)
	_hold(w4, Spells.SPITTER_VINE, 4)
	W.run(w4, 1)
	assert_eq(_hits(w4, &"spell_spitter_vine", w4.actors.ids[3]).size(), 0, "Lv 4: not through")


func test_blood_thorns_ring_from_2_to_4_m_bleeds_lv3_twice_lv5_wall() -> void:
	var enemies := [[Vector2(1, 0), 100000], [Vector2(3, 0), 100000], [Vector2(5, 0), 100000]]
	var w := _world([&"shared_bleed"], enemies)
	var ids := [w.actors.ids[1], w.actors.ids[2], w.actors.ids[3]]
	_hold(w, Spells.BLOOD_THORNS)
	W.run(w, 1)
	assert_eq(_lost(w, ids[0]), 0, "1 m: inside the ring's hole")
	assert_eq(_hits(w, &"spell_blood_thorns", ids[1]).size(), 1, "3 m: hit")
	assert_eq(_hits(w, &"spell_blood_thorns", ids[1])[0].amount, 20)
	assert_gt(w.actors.bleed_stacks[w.actors.index_of(ids[1])], 0, "it bleeds")
	assert_eq(_lost(w, ids[2]), 0, "5 m: beyond")
	var w3 := _world([&"shared_bleed"], enemies)
	_hold(w3, Spells.BLOOD_THORNS, 3)
	W.run(w3, 30)
	assert_eq(_hits(w3, &"spell_blood_thorns", w3.actors.ids[2]).size(), 2, "Lv 3: a second ring")
	var w5 := _world([&"shared_bleed"], enemies)
	_hold(w5, Spells.BLOOD_THORNS, 5)
	W.run(w5, 1)
	assert_eq(_zones(w5, SpellZones.THORN_WALL).size(), 1, "Lv 5: the wall stands")
	W.run(w5, 130)
	var wall := 0
	for e in _hits(w5, &"spell_blood_thorns", w5.actors.ids[2]):
		if e.amount == 4:
			wall += 1
	assert_eq(wall, 3, "2 s of wall: a hit each 0.5 s after the ring")
	assert_eq(_zones(w5, SpellZones.THORN_WALL).size(), 0, "gone after 2 s")


func test_hemorrhage_marks_the_most_hp_cashes_its_bleed_and_spreads() -> void:
	var enemies := [[Vector2(3, 0), 5000], [Vector2(4.5, 0), 1000], [Vector2(-4, 0), 1000]]
	var w := _world([&"shared_bleed"], enemies)
	var big := w.actors.ids[1]
	var near := w.actors.ids[2]
	var far := w.actors.ids[3]
	_hold(w, Spells.HEMORRHAGE)
	W.run(w, 1)
	var marks := _zones(w, SpellZones.HEMO)
	assert_eq(marks.size(), 1, "one mark")
	assert_eq(w.spell_zone_aux[marks[0]], big, "on the most HP")
	var bi := w.actors.index_of(big)
	for n in 170:
		Engines.add_bleed(w, bi, 1, 1)  # TEST HELPER: the wand's bleed kept on it
		W.run(w, 1)
	assert_eq(_hits(w, &"spell_hemorrhage").size(), 0, "waits 3 s")
	var stacks := w.actors.bleed_stacks[bi]
	W.run(w, 12)
	assert_eq(_hits(w, &"spell_hemorrhage", big).size(), 1, "the hit")
	assert_eq(_hits(w, &"spell_hemorrhage", big)[0].amount, 40)
	var cash := W.damage(w, Spells.EFFECT_HEMORRHAGE)
	assert_eq(cash.size(), 1, "all its bleed at once")
	assert_gt(cash[0].amount, stacks, "its bleed's damage")
	assert_eq(w.actors.bleed_stacks[bi], 0, "the bleed is spent")
	assert_gte(w.actors.bleed_stacks[w.actors.index_of(near)], stacks, "spread within 3 m")
	assert_eq(w.actors.bleed_stacks[w.actors.index_of(far)], 0, "not to one 7 m off")
	var w5 := _world([&"shared_bleed"], enemies)
	_hold(w5, Spells.HEMORRHAGE, 5)
	W.run(w5, 1)
	assert_eq(_zones(w5, SpellZones.HEMO).size(), 2, "Lv 5: two marks")


func test_leech_drains_the_bleeding_and_heals_at_most_its_cap() -> void:
	var crowd := _ring(Vector2.ZERO, 3.0, 20, 100000)
	crowd.append([Vector2(0, 5), 100000])  # one that never bleeds
	var w := _world([&"shared_bleed"], crowd)
	var dry := w.actors.ids[21]
	w.actors.hp[0] = w.actors.max_hp[0] - 60  # TEST HELPER: hurt, so the heal shows
	_hold(w, Spells.LEECH)
	W.run(w, 1)
	assert_eq(w.spell_cast_tick[0], -1, "no enemy bleeds: it waits")
	for i in range(1, 21):
		Engines.add_bleed(w, i, 3, 1)  # TEST HELPER: the wand's bleed
	for n in 260:
		for i in range(1, 21):
			if w.actors.bleed_stacks[i] == 0:
				Engines.add_bleed(w, i, 1, 1)
		W.run(w, 1)
	var drained := 0
	for e in W.damage(w, &"spell_leech"):
		drained += e.amount_applied
	var healed := 0
	for e in W.events(w, SimEvent.Kind.HEAL, &"spell_leech"):
		healed += e.amount_applied
	gut.p("Leech drained %d, healed %d" % [drained, healed])
	assert_gt(drained, 25 * 10, "drained enough for more than the cap")
	assert_eq(healed, 10, "Lv 1: at most 10 HP a cast")
	assert_eq(_hits(w, &"spell_leech", dry).size(), 0, "a dry one isn't drained")
	var w1 := _world([&"shared_bleed"], [[Vector2(2, 0), 100000]])
	w1.actors.hp[0] = w1.actors.max_hp[0] - 60
	_hold(w1, Spells.LEECH)
	Engines.add_bleed(w1, 1, 3, 1)
	W.run(w1, 241)
	var little := 0
	for e in W.events(w1, SimEvent.Kind.HEAL, &"spell_leech"):
		little += e.amount_applied
	assert_eq(little, 0, "1 HP per 25 drained: 8 pulses of 3 is 24, so 0 HP")
	var w5 := _world([&"shared_bleed"], [[Vector2(2, 0), 100000]])
	var e5 := w5.actors.ids[1]
	_hold(w5, Spells.LEECH, 5)
	W.run(w5, 1)
	assert_eq(_hits(w5, &"spell_leech", e5).size(), 1, "Lv 5: a dry one is drained too")
	assert_eq(_hits(w5, &"spell_leech", e5)[0].amount, 2, "at half (5 / 2)")


func test_frost_nova_lv5_a_frozen_enemy_you_hit_shatters() -> void:
	var w := _world([&"frost_core"], [[Vector2(2, 0), 100000]])
	var id := w.actors.ids[1]
	_hold(w, Spells.FROST_NOVA, 5)
	W.run(w, 1)
	var i := w.actors.index_of(id)
	assert_gt(w.actors.frozen_t[i], 0, "frozen")
	var pid := w.actors.ids[0]
	Damage.hit(w, i, 5, pid, pid, w.take_root(), 0, Vector2.ZERO, w.actors.pos(i))  # TEST HELPER: a wand hit
	assert_eq(w.actors.frozen_t[i], 0, "it shatters: the freeze ends")
	var sh := _hits(w, Spells.EFFECT_SHATTER, id)
	assert_eq(sh.size(), 1, "one shatter")
	assert_eq(sh[0].amount, 12, "bonus 12")
	var w4 := _world([&"frost_core"], [[Vector2(2, 0), 100000]])
	_hold(w4, Spells.FROST_NOVA, 4)
	W.run(w4, 1)
	var j := w4.actors.index_of(w4.actors.ids[1])
	Damage.hit(w4, j, 5, pid, pid, w4.take_root(), 0, Vector2.ZERO, w4.actors.pos(j))
	assert_gt(w4.actors.frozen_t[j], 0, "Lv 4: still frozen")
	assert_eq(_hits(w4, Spells.EFFECT_SHATTER).size(), 0)


func test_fireball_lv5_leaves_burning_ground_3_s() -> void:
	var pack := [[Vector2(0, 7), 100000], [Vector2(1, 7.5), 100000], [Vector2(-1, 7.2), 100000]]
	var w := _world([&"ember_core"], pack)
	_hold(w, Spells.FIREBALL, 5)
	W.run(w, 60)
	var fires := _zones(w, SpellZones.FIRE)
	assert_eq(fires.size(), 2, "Lv 5: each of the 2 bursts leaves burning ground")
	W.run(w, 200)
	assert_eq(_zones(w, SpellZones.FIRE).size(), 0, "for 3 s")
	var ground := 0
	for e in _hits(w, &"spell_fireball"):
		if e.amount == 2:
			ground += 1
	assert_gt(ground, 0, "the ground's 2 a pulse")
	var w4 := _world([&"ember_core"], pack)
	_hold(w4, Spells.FIREBALL, 4)
	W.run(w4, 60)
	assert_eq(_zones(w4, SpellZones.FIRE).size(), 0, "Lv 4: none")


## The soak: every spell at Lv 5, four at a time (the slots), every element card, a crowd of 40 refilled: no watchdog
## LIMIT, the zones and the holds bounded, the same hash replayed.
func test_every_spell_at_lv5_runs_bounded_and_replays() -> void:
	var enemies := []
	for k in 40:
		enemies.append([Vector2(-6 + (k % 8) * 1.6, -4 + (k / 8) * 1.8), 300])
	var groups := [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11], [12, 13, 14]]
	for g: Array in groups:
		var runs: Array[World] = []
		for r in 2:
			var w := _world(ALL_CARDS, enemies, 77)
			for k: int in g:
				_hold(w, k, 5)
			for n in 1200:
				var dash := InputFrame.DASH if n % 150 == 0 else 0
				W.run(
					w,
					1,
					dash,
					dash,
					(n * 37) % 4096,
					Vector2i(0, 127) if n % 300 < 150 else Vector2i.ZERO
				)
				assert_lte(w.spell_zone_kind.size(), SpellZones.MAX, "zones bounded")
				assert_lte(w.spell_hold_id.size(), Spells.HOLDS_MAX, "holds bounded")
				if n % 300 == 0:
					for e in 6:
						w.add_dummy(Vector2(1 + e, 2), 0.35, 300)
			assert_eq(
				W.events(w, SimEvent.Kind.LIMIT).size(), 0, "group %s: no watchdog LIMIT" % [g]
			)
			runs.append(w)
		assert_eq(
			runs[0].state_hash(), runs[1].state_hash(), "group %s: the same hash replayed" % [g]
		)
		for k: int in g:
			var id: StringName = SpellDefinition.SPELLS[k]
			var hit := W.events(runs[0], SimEvent.Kind.HIT, id).size()
			assert_gt(hit, 0, "%s hit something" % id)


func test_the_snapshot_keeps_the_lasting_spells_replay_exact() -> void:
	var pack := [[Vector2(0, 5), 100000], [Vector2(1, 5.5), 100000], [Vector2(2, 0), 100000]]
	var w := _world(ALL_CARDS, pack)
	for k in [Spells.BLIZZARD, Spells.METEOR, Spells.TOXIC_CLOUD, Spells.SKY_STRIKE]:
		_hold(w, k, 5)
	W.run(w, 20)
	assert_gt(w.spell_zone_kind.size(), 2, "storm, mark, cloud and puffs in flight")
	var base := _world(ALL_CARDS, pack)
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray())
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.state_hash(), w.state_hash(), "replay-exact")
	W.run(w, 400)
	W.run(base, 400)
	assert_eq(base.state_hash(), w.state_hash(), "the same 400 ticks later")
	var plain := _world(ALL_CARDS, pack)
	var other := _world(ALL_CARDS, pack)
	assert_eq(plain.state_hash(), other.state_hash())
	other.spell_zone_kind.append(0)  # TEST HELPER: a zone is hashed
	other.spell_zone_spell.append(0)
	for f: String in ["level", "root", "end", "next", "dmg", "aux", "aux2"]:
		var arr: PackedInt32Array = other.get("spell_zone_" + f)
		arr.append(0)
		other.set("spell_zone_" + f, arr)
	other.spell_zone_pos.append(Vector2.ZERO)
	other.spell_zone_vel.append(Vector2.ZERO)
	other.spell_zone_r.append(1.0)
	assert_ne(plain.state_hash(), other.state_hash(), "the zones are in the hash")
