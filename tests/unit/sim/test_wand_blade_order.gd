extends GutTest
## v0.6.5 WN4 (docs/design/WAND.md rules 2, 6 and 8): the Blade pool's cards read left to right (an order changes the
## spell, or two cards commute and say so), a duplicate levels a card up in its slot (levels 1–5, carried and
## snapshotted), and the pool is offered only in Blade runs, its new cards indexed after every earlier card. The fights
## are test_wand_blade.gd's (AttackScenario). Mechanics only: no bot, no balance (P1).

const TICKS := 600
const MOTION := SwingStep.Motion


## The fight's counts: the player's HITs by effect id, their total and the damage dealt, and the most of what
## BladeForms.read showed at once (cut shots, pushed enemies, orbiting blades, fissure cracks) and the marks by kind.
func _run(w: World, ticks: int = TICKS) -> Dictionary:
	var seen := 0
	var effects := {}
	var hits := 0
	var dealt := 0
	var most := {"knocked": 0, "blades": 0, "cracks": 0}
	var marks := {}
	var pid := w.actors.ids[0]
	for t in ticks:
		w.step(AttackScenario.frame(t))
		for e in w.events_since(seen):
			seen = e.seq
			if e.owner_id != pid or e.target_id == pid:
				continue
			if e.kind == SimEvent.Kind.HIT:
				hits += 1
				effects[e.effect_id] = int(effects.get(e.effect_id, 0)) + 1
			elif e.kind == SimEvent.Kind.DAMAGE:
				dealt += e.amount_applied
		var r := BladeForms.read(w)
		most["knocked"] = maxi(most["knocked"], r["knocked"])
		most["blades"] = maxi(most["blades"], (r["blades"] as PackedVector2Array).size())
		most["cracks"] = maxi(most["cracks"], (r["cracks"] as Array).size())
		for f: Dictionary in r["fx"]:
			marks["%d/%d" % [f["kind"], f["tick"]]] = f["kind"]
	var by_kind := {}
	for k: int in marks.values():
		by_kind[k] = int(by_kind.get(k, 0)) + 1
	return {
		"effects": effects,
		"hits": hits,
		"dealt": dealt,
		"most": most,
		"marks": by_kind,
		"parried": w.blade.parried,
		"hash": w.state_hash(),
	}


func _fight(ids: Array) -> World:
	return WandLab.fight(&"blade", ids)


func _step(w: World, k: int = 0) -> AttackSpec:
	return Modifiers.step(w, k)


func _hook(s: AttackSpec, id: StringName) -> AttackHook:
	for k in s.hooks:
		if k.id == id:
			return k
	return null


func _units(deg: float) -> int:
	return ContentCompiler.degrees_to_units(deg)


# --- Order: the wand reads left to right -------------------------------------------------------------------------
func test_wave_split_wave_vs_split_wave_wave() -> void:
	var a := _fight([&"echo_slash", &"split_wave"])
	var b := _fight([&"split_wave", &"echo_slash"])
	assert_not_null(
		_hook(_hook(_step(a), &"echo_slash").child, &"split_wave"), "Wave·Split: it splits"
	)
	assert_null(
		_hook(_hook(_step(b), &"echo_slash").child, &"split_wave"),
		"Split·Wave: nothing to split yet"
	)
	var ra := _run(a)
	var rb := _run(b)
	assert_gt(int(ra["effects"].get(&"split_wave", 0)), 0)
	assert_eq(int(rb["effects"].get(&"split_wave", 0)), 0)
	assert_ne(ra["hash"], rb["hash"], "the fights differ")


func test_heavy_whirl_and_whirl_heavy_make_the_same_crushing_spin() -> void:
	var a := _fight([&"heavy", &"whirl"])
	var b := _fight([&"whirl", &"heavy"])
	for w: World in [a, b]:
		assert_eq(BladeForms.step(w, 0).motion, MOTION.SPIN)
		assert_eq(_step(w).directions, AttackSpec.DIR_CIRCLE)
		assert_eq(_step(w).damage_mul_permille, 1700)
	assert_eq(_step(a).damage, _step(b).damage, "shape and weight cards commute")
	assert_eq(BladeForms.step(a, 0).ticks, BladeForms.step(b, 0).ticks)
	assert_eq(_run(a)["hits"], _run(b)["hits"], "the same fight")


func test_whirl_wave_throws_a_ring_wave_whirl_one() -> void:
	var ring := _hook(_step(_fight([&"whirl", &"echo_slash"])), &"echo_slash").child
	var one := _hook(_step(_fight([&"echo_slash", &"whirl"])), &"echo_slash").child
	assert_eq(ring.directions, AttackSpec.DIR_CIRCLE, "Whirl·Wave: the spin's wave flies all round")
	assert_eq(ring.count, BladeForms.CRESCENT_RING)
	assert_eq(
		one.directions, AttackSpec.DIR_FORWARD, "Wave·Whirl: the wave was thrown before the spin"
	)
	assert_eq(one.count, 1)


func test_wide_arc_thrust_vs_thrust_wide_arc() -> void:
	var a := _step(_fight([&"wide_arc", &"thrust"]))
	var b := _step(_fight([&"thrust", &"wide_arc"]))
	assert_lt(a.half_arc, b.half_arc, "widened then narrowed < narrowed then widened")


# --- Levels (WAND.md rule 6) -----------------------------------------------------------------------------------
func test_a_duplicate_levels_up_in_its_slot() -> void:
	var w := _fight([&"wide_arc", &"echo_slash"])
	var code := WandLab.code(w, &"wide_arc")
	var slots := w.mod_slots.duplicate()
	var arc := _step(w).half_arc
	assert_true(ItemPool.available(w).has(code), "a held card below level 5 is still offered")
	assert_true(BuildSlots.take(w, code))
	assert_eq(CardLevels.level(w, code), 2)
	assert_eq(BuildSlots.level_at(w, 0), 2, "the slot reads its level")
	assert_eq(w.mod_slots, slots, "no new slot, same order")
	assert_eq(_step(w).half_arc, arc - _units(30.0) + _units(37.5), "+15° more arc at level 2")
	for n in 3:
		BuildSlots.take(w, code)
	assert_eq(CardLevels.level(w, code), 5)
	assert_false(ItemPool.available(w).has(code), "level 5: no longer offered")
	BuildSlots.take(w, code)
	assert_eq(CardLevels.level(w, code), 5, "the top")


func test_levels_grow_each_card() -> void:
	var w := _fight([&"echo_slash", &"split_wave", &"chain_cut"])
	var before := [
		_hook(_step(w), &"echo_slash").damage_permille,
		_hook(_hook(_step(w), &"echo_slash").child, &"split_wave").child.count,
		_hook(_step(w), &"chain_cut").child.chains,
	]
	for id: StringName in [&"echo_slash", &"split_wave", &"chain_cut"]:
		BuildSlots.take(w, WandLab.code(w, id))
	var after := [
		_hook(_step(w), &"echo_slash").damage_permille,
		_hook(_hook(_step(w), &"echo_slash").child, &"split_wave").child.count,
		_hook(_step(w), &"chain_cut").child.chains,
	]
	assert_eq(
		after,
		[before[0] + 100, before[1] + 1, before[2] + 1],
		"Wave hits harder, +1 split, +1 jump"
	)


func test_a_level_rides_the_carry_and_the_snapshot() -> void:
	var w := _fight([&"heavy"])
	var code := WandLab.code(w, &"heavy")
	BuildSlots.take(w, code)
	var carry := RunCarry.take(w, 0)
	assert_eq(CardLevels.level(w, code), 2)
	assert_true(carry.has(&"card_levels"), "run-long")
	var h := w.state_hash()
	var snap := w.to_snapshot()
	var base := _fight([&"heavy"])
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(CardLevels.level(base, code), 2)
	assert_eq(base.state_hash(), h, "equal hashes after the round trip")


# --- Pool --------------------------------------------------------------------------------------------------------
func test_the_blade_pool_is_offered_only_in_blade_runs() -> void:
	var ids := [
		&"wide_arc",
		&"echo_slash",
		&"split_wave",
		&"whirl",
		&"double_slash",
		&"thrust",
		&"heavy",
		&"flurry",
		&"fissure",
		&"chain_cut",
		&"parry_edge",
		&"long_shadow",
		&"lunge_step",
		&"finisher_plus",
		&"blade_orbit",
		&"counter",
	]
	var blade := _fight([])
	var gun := WandLab.fight(&"gun", [])
	for id: StringName in ids:
		var k := AttackScenario.item_index(blade.item_tables, id)
		assert_gt(k, -1, String(id))
		assert_true(CardLevels.is_card(blade, k), "%s levels 1–5 (tag wand)" % id)
		assert_true(ItemPool.usable(blade, k), "%s: a Blade run" % id)
		assert_false(ItemPool.usable(gun, k), "%s: never a Gun run" % id)


func test_new_cards_take_indices_after_every_earlier_card() -> void:
	var t := WandLab.tables()
	var last_trigger := AttackScenario.item_index(t, &"trigger_on_kill")
	for id: StringName in [&"split_wave", &"whirl", &"counter", &"thrust"]:
		assert_gt(
			AttackScenario.item_index(t, id), last_trigger, "%s after the saves' indices" % id
		)
	assert_lt(
		AttackScenario.item_index(t, &"echo_slash"), last_trigger, "a reused id keeps its index"
	)
