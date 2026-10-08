# gdlint: disable=max-public-methods
extends GutTest
## v0.4.0 AB with the shipped data: Arc Field, Frost Nova and Flame Trail (damage, targeting, levels, the status
## engines they feed, determinism) and the eight ability combos (the L3 trigger rule, each effect, the ancestry
## guard). Crit is off (crit_chance_permille = 0) so damage numbers are exact; dummies stand still.

const U := InputFrame.UTILITY

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(
	build: StringName = &"blade", enemies: Array = [], hp: int = 5000, seed_value := 11
) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	if build != &"":
		ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	t.crit_chance_permille = 0
	var w := World.new(seed_value, t)
	w.dummy_speed = 0.0
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, hp)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _idx(w: World, id: StringName) -> int:
	for k in w.ability_tables.size():
		if w.ability_tables[k].id == id:
			return k
	return -1


## Grants ability `id` up to `level` (a new slot, then level-ups).
func _grant(w: World, id: StringName, level: int = 1) -> void:
	var idx := _idx(w, id)
	while Abilities.level_of(w, idx) < level:
		assert_true(Abilities.grant(w, idx), "grant %s" % id)


func _f(pressed: int = 0, move := Vector2i.ZERO, held: int = 0) -> InputFrame:
	return InputFrame.make(move, 0, 300, held, pressed)


func _run(w: World, n: int, move := Vector2i.ZERO) -> void:
	for i in n:
		w.step(_f(0, move))


func _events(w: World, kind: SimEvent.Kind, effect: StringName, after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == kind and e.effect_id == effect:
			out.append(e)
	return out


func _damage(w: World, effect: StringName, after: int = 0) -> Array[SimEvent]:
	return _events(w, SimEvent.Kind.DAMAGE, effect, after)


# --- Data ---------------------------------------------------------------------------------------------------------
func test_the_three_abilities_compile_with_their_engines() -> void:
	var w := _world()
	var arc := w.ability_tables[_idx(w, &"arc_field")]
	assert_eq([arc.kind, arc.damage, arc.auto], [AbilityTable.Kind.ARC_FIELD, 12, true])
	assert_almost_eq(arc.range_m, 6.0, 1e-6)
	assert_eq(arc.level_count, PackedInt32Array([3, 4, 5, 6, 7]), "+1 target per level")
	assert_eq(arc.level_cooldown, PackedInt32Array([90, 84, 78, 72, 66]), "1.5 s, -0.1 s per level")
	assert_eq(arc.engine.id, &"static_chain", "the shock engine's numbers")
	var nova := w.ability_tables[_idx(w, &"frost_nova")]
	assert_eq([nova.damage, nova.level_cooldown], [10, PackedInt32Array([240, 240, 240, 240, 180])])
	assert_eq(nova.level_extra, PackedInt32Array([2, 2, 4, 4, 4]), "L3: a nova freezes on its own")
	assert_eq(nova.engine.id, &"glacial_edge")
	var flame := w.ability_tables[_idx(w, &"flame_trail")]
	assert_eq(
		[flame.damage, flame.duration_ticks, flame.hit_ticks], [3, 120, 30], "6 dmg/s for 2 s"
	)
	assert_eq(flame.level_rate, PackedInt32Array([1000, 1250, 1500, 1750, 2000]), "+25 % duration")
	assert_eq(flame.engine.id, &"ember_edge")


func test_owning_an_engine_ability_borrows_its_engine() -> void:
	var w := _world()
	assert_eq(w.item_mods.shock_threshold, 0, "no shock engine yet")
	_grant(w, &"arc_field")
	assert_eq(w.item_mods.shock_threshold, 5, "Static Chain's threshold")
	_grant(w, &"frost_nova")
	assert_eq(w.item_mods.frost_threshold, 4)
	_grant(w, &"flame_trail")
	assert_eq(w.item_mods.burn_max_stacks, 5)
	assert_eq(w.item_mods.burn_damage, 2)


# --- Arc Field ----------------------------------------------------------------------------------------------------
func test_arc_field_strikes_three_enemies_in_range() -> void:
	var near := [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 3), Vector2(0, -4), Vector2(4, 4)]
	var w := _world(&"blade", near + [Vector2(9, 0)])
	var far_id := w.actors.ids[6]
	_grant(w, &"arc_field")
	w.step(_f())
	var hits := _damage(w, ElementAbilities.EFFECT_ARC)
	assert_eq(hits.size(), 3, "three strikes")
	var ids := {}
	for e in hits:
		assert_eq(e.amount, 12)
		assert_ne(e.target_id, far_id, "never past 6 m")
		ids[e.target_id] = true
		var i := w.actors.index_of(e.target_id)
		assert_eq(w.actors.shock_stacks[i], 1, "a shock stack each")
	assert_eq(ids.size(), 3, "three different enemies")
	assert_eq(w.ab.arc_to.size(), 3, "the view sees the three bolts")
	var seq := w.last_event_seq()
	_run(w, 89)
	assert_eq(_damage(w, ElementAbilities.EFFECT_ARC, seq).size(), 0, "1.5 s cooldown")
	w.step(_f())
	assert_eq(_damage(w, ElementAbilities.EFFECT_ARC, seq).size(), 3, "then again")


func test_arc_field_levels_add_targets_and_waits_for_one() -> void:
	var w := _world(&"blade", [])
	_grant(w, &"arc_field", 3)
	_run(w, 100)
	assert_eq(w.ab.arc_tick, -1, "nothing in range: no strike")
	for k in 8:
		w.add_dummy(Kin.dir(k * 512) * 3.0, 0.35, 5000)
	w.step(_f())
	assert_eq(_damage(w, ElementAbilities.EFFECT_ARC).size(), 5, "L3: five targets")
	var w2 := _world(&"blade", [Vector2(2, 0), Vector2(-2, 0)])
	_grant(w2, &"arc_field")
	w2.step(_f())
	assert_eq(_damage(w2, ElementAbilities.EFFECT_ARC).size(), 2, "fewer enemies: all of them")


func test_arc_field_picks_from_the_ability_stream_deterministically() -> void:
	var pts := []
	for k in 10:
		pts.append(Kin.dir(k * 409) * 4.0)
	var a := _world(&"blade", pts)
	var b := _world(&"blade", pts)
	_grant(a, &"arc_field")
	_grant(b, &"arc_field")
	var before := a.rng_ability.state
	for k in 300:
		a.step(_f())
		b.step(_f())
	assert_ne(a.rng_ability.state, before, "targets come from the ability stream")
	assert_eq(a.state_hash(), b.state_hash(), "same seed, same strikes")


func test_arc_field_shock_discharges_at_the_threshold() -> void:
	var w := _world(&"blade", [Vector2(3, 0), Vector2(4, 1)], 100000)
	_grant(w, &"arc_field")
	_run(w, 90 * 3 + 1)  # strikes at ticks 0, 90, 180, 270
	assert_eq(
		_events(w, SimEvent.Kind.HIT, Engines.EFFECT_DISCHARGE).size(), 0, "4 stacks: not yet"
	)
	_run(w, 90)
	assert_gt(
		_damage(w, Engines.EFFECT_DISCHARGE).size(), 0, "the fifth stack discharges (the engine)"
	)


# --- Frost Nova ---------------------------------------------------------------------------------------------------
func test_frost_nova_hits_everything_in_its_radius_with_frost() -> void:
	var w := _world(&"blade", [Vector2(2, 0), Vector2(0, -2.5), Vector2(3.6, 0)])
	var out_id := w.actors.ids[3]
	_grant(w, &"frost_nova")
	w.step(_f())
	var hits := _damage(w, ElementAbilities.EFFECT_NOVA)
	assert_eq(hits.size(), 2, "the 3 m nova")
	for e in hits:
		assert_eq(e.amount, 10)
		assert_ne(e.target_id, out_id)
		assert_eq(w.actors.frost_stacks[w.actors.index_of(e.target_id)], 2, "two frost stacks")
	assert_almost_eq(w.ab.nova_r, 3.0, 1e-5)
	var seq := w.last_event_seq()
	_run(w, 239)
	assert_eq(_damage(w, ElementAbilities.EFFECT_NOVA, seq).size(), 0, "every 4 s")
	w.step(_f())
	assert_eq(_damage(w, ElementAbilities.EFFECT_NOVA, seq).size(), 2)


func test_frost_nova_levels_widen_freeze_and_quicken() -> void:
	var w := _world(&"blade", [Vector2(3.6, 0)])
	_grant(w, &"frost_nova", 3)
	w.step(_f())
	assert_almost_eq(w.ab.nova_r, 3.8, 0.01, "+0.4 m per level")
	assert_gt(w.actors.frozen_t[1], 0, "L3: four stacks freeze at once")
	_grant(w, &"frost_nova", 5)
	var s := w.ability_owned.find(_idx(w, &"frost_nova"))
	_run(w, 240)
	var seq := w.last_event_seq()
	var gap := 0
	while _damage(w, ElementAbilities.EFFECT_NOVA, seq).is_empty() and gap < 400:
		w.step(_f())
		gap += 1
	assert_eq(w.ab.cd[s], 180, "L5: every 3 s")


# --- Flame Trail --------------------------------------------------------------------------------------------------
func test_flame_trail_leaves_fire_only_while_moving() -> void:
	var w := _world(&"blade", [])
	_grant(w, &"flame_trail")
	_run(w, 60)
	assert_eq(w.ab.fire_pos.size(), 0, "standing still: no fire")
	_run(w, 60, Vector2i(SimTick.MOVE_MAX, 0))
	assert_gt(w.ab.fire_pos.size(), 3, "moving: a trail")
	for k in range(1, w.ab.fire_pos.size()):
		assert_gte(w.ab.fire_pos[k].distance_to(w.ab.fire_pos[k - 1]), 0.79, "spaced")
	_run(w, 121)
	assert_eq(w.ab.fire_pos.size(), 0, "each patch burns 2 s")


func test_flame_trail_burns_enemies_in_it() -> void:
	var w := _world(&"blade", [Vector2(2.5, 0)])
	_grant(w, &"flame_trail")
	_run(w, 40, Vector2i(SimTick.MOVE_MAX, 0))
	_run(w, 60)
	var hits := _damage(w, ElementAbilities.EFFECT_FLAME)
	assert_gt(hits.size(), 0, "the dummy in the trail burns")
	for e in hits:
		assert_eq(e.amount, 3, "3 per half second: 6 dmg/s")
	var ticks := []
	for e in hits:
		ticks.append(e.tick)
	for k in range(1, ticks.size()):
		assert_gte(ticks[k] - ticks[k - 1], 30, "once per 0.5 s")
	assert_gt(w.actors.burn_stacks[1], 0, "and burn stacks (the engine ticks them)")
	assert_gt(_events(w, SimEvent.Kind.DAMAGE, ItemEffects.EFFECT_EMBER_EDGE).size(), 0, "burn DoT")


func test_flame_trail_level_two_is_stronger_and_longer() -> void:
	var w := _world(&"blade", [])
	_grant(w, &"flame_trail", 2)
	_run(w, 30, Vector2i(SimTick.MOVE_MAX, 0))
	assert_eq(w.ab.fire_dmg[0], 4, "3 x 1.25, rounded")
	var t := w.ability_tables[_idx(w, &"flame_trail")]
	assert_eq(ElementAbilities.trail_ticks(t, 2), 150, "2.5 s")


# --- Ability combos: the trigger rule -------------------------------------------------------------------------------
func test_a_pair_evolves_at_level_three() -> void:
	var w := _world()
	_grant(w, &"bomb_lobber", 3)
	_grant(w, &"arc_field", 2)
	assert_false(Engines.has_combo(w, ComboTable.Effect.STORM_BOMBS), "L3 + L2: not yet")
	var seq := w.last_event_seq()
	_grant(w, &"arc_field", 3)
	assert_true(Engines.has_combo(w, ComboTable.Effect.STORM_BOMBS), "both at L3: Storm Bombs")
	var ev := _events(w, SimEvent.Kind.COMBO_UNLOCKED, &"storm_bombs", seq)
	assert_eq(ev.size(), 1, "announced once (the combo card)")
	_grant(w, &"arc_field", 4)
	assert_eq(_events(w, SimEvent.Kind.COMBO_UNLOCKED, &"storm_bombs", seq).size(), 1, "only once")


func test_eight_ability_combos_ship() -> void:
	var tables := ContentCompiler.compile_combos(_repo)
	var ids := []
	for t in tables:
		if t.ability_a >= 0:
			ids.append(String(t.id))
			assert_eq(t.min_level, 3)
	ids.sort()
	assert_eq(
		ids,
		[
			"blade_dance",
			"blink_charge",
			"ember_ward",
			"glacier_ring",
			"napalm_drone",
			"storm_bombs",
			"superconductor",
			"wingman"
		]
	)


func test_combos_carry_and_rebuild_on_a_new_floor() -> void:
	var w := _world()
	_grant(w, &"orbit_blades", 3)
	_grant(w, &"frost_nova", 3)
	var carry := RunCarry.take(w, 0)
	var v := _world()
	RunCarry.apply(v, carry)
	Abilities.start_floor(v)
	assert_true(Engines.has_combo(v, ComboTable.Effect.GLACIER_RING), "the mask follows the carry")
	assert_eq(v.item_mods.frost_threshold, 4, "and the borrowed engine")


# --- Ability combos: the effects ----------------------------------------------------------------------------------
func test_storm_bombs_chain_lightning_from_each_blast() -> void:
	var w := _world(&"blade", [Vector2(5, 0), Vector2(5.5, 0.4), Vector2(8.5, 0), Vector2(9, 2)])
	_grant(w, &"bomb_lobber", 3)
	_grant(w, &"arc_field", 3)
	_run(w, 40)
	var storm := _damage(w, AbilityCombos.EFFECT_STORM)
	assert_between(storm.size(), 1, 6, "each of the two L3 blasts chains (up to 3 each)")
	assert_between(w.ab.storm_to.size(), 1, 3, "a chain reaches the 3 nearest at most")
	for e in storm:
		assert_eq(e.amount, 10)
	assert_gte(w.ab.storm_tick, 0, "the view sees the chain")


func test_storm_bombs_respect_the_ancestry_guard() -> void:
	var w := _world(&"blade", [Vector2(2, 0)])
	_grant(w, &"bomb_lobber", 3)
	_grant(w, &"arc_field", 3)
	w.engine_chain.append(AbilityCombos.EFFECT_STORM)
	w.step(_f())  # phase 6 runs once with the effect already in the chain
	AbilityCombos.on_blast(w, Vector2(2, 0), w.take_root())
	assert_eq(_damage(w, AbilityCombos.EFFECT_STORM).size(), 0, "never inside its own chain")
	w.engine_chain.clear()
	var root := w.take_root()
	AbilityCombos.on_blast(w, Vector2(2, 0), root)
	AbilityCombos.on_blast(w, Vector2(2, 0), root)
	assert_eq(_damage(w, AbilityCombos.EFFECT_STORM).size(), 1, "once per root")


func test_napalm_drone_bolts_leave_fire() -> void:
	var w := _world(&"blade", [Vector2(4, 0)])
	_grant(w, &"drone_buddy", 3)
	_grant(w, &"flame_trail", 3)
	assert_true(Engines.has_combo(w, ComboTable.Effect.NAPALM_DRONE))
	_run(w, 60)
	assert_true(w.ab.fire_kind.has(ElementAbilities.FIRE_NAPALM), "a napalm patch where a bolt hit")
	assert_gt(_damage(w, AbilityCombos.EFFECT_NAPALM).size(), 0, "and it burns")


func test_glacier_ring_blades_add_frost() -> void:
	var w := _world(&"blade", [Vector2(1.6, 0)])
	_grant(w, &"orbit_blades", 3)
	_grant(w, &"frost_nova", 3)
	w.ab.cd[w.ability_owned.find(_idx(w, &"frost_nova"))] = 10000  # the nova out of the way
	_run(w, 80)
	assert_gt(_events(w, SimEvent.Kind.STATUS_APPLY, AbilityCombos.EFFECT_GLACIER).size(), 0)
	assert_gte(w.ab.glacier_tick, 0)


func test_blink_charge_leaves_bombs_where_you_left() -> void:
	var w := _world(&"blade", [])
	_grant(w, &"blink", 3)
	_grant(w, &"bomb_lobber", 3)
	var start := w.player_pos()
	w.step(_f(U, Vector2i(SimTick.MOVE_MAX, 0)))
	_run(w, 2)
	assert_eq(w.ab.bomb_pos.size(), 2, "two bombs")
	for p in w.ab.bomb_pos:
		assert_lt(p.distance_to(start), 2.0, "at the blink's start")
	assert_gte(w.ab.charge_tick, 0)


func test_blade_dance_widens_and_sharpens_the_blades_after_a_landed_swing() -> void:
	var w := _world(&"blade", [])
	_grant(w, &"orbit_blades", 3)
	_grant(w, &"combo_sword", 3)
	var t := w.ability_tables[_idx(w, &"orbit_blades")]
	var r0 := Abilities.orbit_radius(w, t, 3)
	AbilityCombos.after_swing(w, false)
	assert_false(AbilityCombos.dancing(w), "a whiff doesn't dance")
	AbilityCombos.after_swing(w, true)
	assert_true(AbilityCombos.dancing(w))
	assert_almost_eq(Abilities.orbit_radius(w, t, 3), r0 + 0.8, 1e-4, "+0.8 m")
	assert_eq(AbilityCombos.dance_permille(w), 1500, "+50 % damage")
	_run(w, 90)
	assert_false(AbilityCombos.dancing(w), "for 1.5 s")


func test_wingman_drones_fire_with_your_shot() -> void:
	var w := _world(&"gun", [])
	_grant(w, &"pulse_gun", 3)
	_grant(w, &"drone_buddy", 3)
	assert_true(Engines.has_combo(w, ComboTable.Effect.WINGMAN))
	w.step(_f())
	var before := w.projectiles.size()
	AbilityCombos.on_shot(w)
	w.step(_f())
	assert_eq(w.ab.wing_tick, w.tick - 1, "a volley")
	assert_gte(w.projectiles.size() - before, 2, "one bolt per drone (two at L3)")
	AbilityCombos.on_shot(w)
	assert_eq(w.ab.wing_tick, w.tick - 1, "at most every 0.25 s")


func test_superconductor_doubles_arcs_on_chilled_enemies() -> void:
	var w := _world(&"blade", [Vector2(4.5, 0)])
	_grant(w, &"arc_field", 3)
	_grant(w, &"frost_nova", 3)
	w.ab.cd[w.ability_owned.find(_idx(w, &"frost_nova"))] = 10000
	w.actors.frost_stacks[1] = 1
	w.actors.frost_t[1] = 600
	w.step(_f())
	var hits := _damage(w, AbilityCombos.EFFECT_SUPER)
	assert_eq(hits.size(), 1, "the strike on a chilled enemy is a Superconductor hit")
	assert_eq(hits[0].amount, 24, "x2")


func test_ember_ward_bursts_fire_on_a_guard_block() -> void:
	var w := _world(&"blade", [Vector2(1.5, 0), Vector2(6, 0)])
	_grant(w, &"aegis", 3)
	_grant(w, &"flame_trail", 3)
	assert_true(Engines.has_combo(w, ComboTable.Effect.EMBER_WARD))
	w.step(_f())
	AbilityCombos.on_guard_block(w, w.take_root())
	var hits := _damage(w, AbilityCombos.EFFECT_WARD)
	assert_eq(hits.size(), 1, "the near enemy only (2.5 m)")
	assert_eq(hits[0].amount, 14)
	assert_eq(w.actors.burn_stacks[1], 2, "two burn stacks")
	AbilityCombos.on_guard_block(w, w.take_root())
	assert_eq(_damage(w, AbilityCombos.EFFECT_WARD).size(), 1, "once a second")


func test_ability_worlds_replay_to_the_same_hash() -> void:
	var hashes := []
	for k in 2:
		var w := _world(&"blade", [Vector2(3, 0), Vector2(-3, 1), Vector2(1, 4)], 400)
		for id: StringName in [&"arc_field", &"frost_nova", &"flame_trail"]:
			_grant(w, id, 3)
		for n in 400:
			w.step(_f(0, Vector2i(SimTick.MOVE_MAX if (n / 60) % 2 == 0 else -SimTick.MOVE_MAX, 0)))
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])
