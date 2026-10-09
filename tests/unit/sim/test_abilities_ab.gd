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


# --- Arc Field (v0.6.0 MX2: a weapon attack leaves a shock field where it ends) ---------------------------------
func _attack_at(w: World, at: Vector2) -> void:
	ModifierAbilities.on_attack(w, at)


func test_arc_field_leaves_a_shock_field_where_an_attack_ends() -> void:
	var w := _world(&"blade", [Vector2(2, 0), Vector2(2.6, 0.6), Vector2(6, 0)])
	var far_id := w.actors.ids[3]
	_grant(w, &"arc_field")
	w.step(_f())
	_attack_at(w, Vector2(2.2, 0.2))
	assert_eq(w.ab.fire_kind, PackedInt32Array([ElementAbilities.FIRE_FIELD]), "a field")
	assert_almost_eq(w.ab.fire_r[0], 1.6, 1e-5, "1.6 m")
	w.step(_f())
	var hits := _damage(w, ElementAbilities.EFFECT_ARC)
	assert_eq(hits.size(), 2, "the two in it")
	for e in hits:
		assert_eq(e.amount, 12, "v0.5's 12")
		assert_ne(e.target_id, far_id)
		assert_eq(w.actors.shock_stacks[w.actors.index_of(e.target_id)], 1, "a shock stack each")
	_attack_at(w, Vector2(2.2, 0.2))
	assert_eq(w.ab.fire_pos.size(), 1, "1.5 s between fields")
	_run(w, 90)
	_attack_at(w, Vector2(2.2, 0.2))
	assert_eq(w.ab.fire_pos.size(), 2, "then the next attack leaves another")


func test_arc_field_hits_at_most_its_level_count_a_tick() -> void:
	var pts := []
	for k in 6:
		pts.append(Vector2(3, 0) + Kin.dir(k * 682) * 0.5)
	var w := _world(&"blade", pts)
	_grant(w, &"arc_field")
	w.step(_f())
	_attack_at(w, Vector2(3, 0))
	w.step(_f())
	assert_eq(_damage(w, ElementAbilities.EFFECT_ARC).size(), 3, "L1: three a tick")
	var v := _world(&"blade", pts)
	_grant(v, &"arc_field", 3)
	v.step(_f())
	_attack_at(v, Vector2(3, 0))
	v.step(_f())
	assert_eq(_damage(v, ElementAbilities.EFFECT_ARC).size(), 5, "L3: five")


func test_arc_field_shock_discharges_at_the_threshold() -> void:
	var w := _world(&"blade", [Vector2(3, 0)], 100000)
	_grant(w, &"arc_field")
	w.step(_f())
	_attack_at(w, Vector2(3, 0))
	_run(w, 90)  # the field hits every 0.5 s: 4 stacks in its 2 s
	assert_eq(_damage(w, Engines.EFFECT_DISCHARGE).size(), 0, "4 stacks: not yet")
	_attack_at(w, Vector2(3, 0))
	_run(w, 40)
	assert_gt(_damage(w, Engines.EFFECT_DISCHARGE).size(), 0, "the fifth discharges (the engine)")


# --- Frost Nova (v0.6.0 MX2: the frost element on the weapon, a ring on a kill streak) -----------------------
func _streak(w: World, n: int) -> void:
	for k in n:
		ModifierAbilities.on_kill(w)


func test_frost_nova_gives_the_weapon_frost() -> void:
	var w := _world(&"blade", [Vector2(1.2, 0)])
	_grant(w, &"frost_nova")
	assert_true(Modifiers.step(w, 0).has_status(&"frost"))
	assert_true(Modifiers.step(w, 0).elements.has("frost"))
	w.step(_f(InputFrame.PRIMARY))
	_run(w, 20)
	assert_gt(w.actors.frost_stacks[1] + w.actors.frozen_t[1], 0, "a swing feeds frost")


func test_frost_nova_rings_on_a_kill_streak_with_its_v0_5_numbers() -> void:
	var w := _world(&"blade", [Vector2(2, 0), Vector2(0, -2.5), Vector2(3.6, 0)])
	var out_id := w.actors.ids[3]
	_grant(w, &"frost_nova")
	w.step(_f())
	_streak(w, 3)
	assert_eq(w.ab.nova_tick, -1, "three kills: no ring")
	_streak(w, 1)
	assert_eq(w.ab.nova_tick, w.tick, "the fourth: the ring")
	assert_almost_eq(w.ab.nova_r, 3.0, 1e-5)
	_run(w, Modifiers.RING_TICKS + 2)
	var hits := _damage(w, ElementAbilities.EFFECT_NOVA)
	assert_eq(hits.size(), 2, "the 3 m ring passes two")
	for e in hits:
		assert_eq(e.amount, 10)
		assert_ne(e.target_id, out_id)
		assert_eq(w.actors.frost_stacks[w.actors.index_of(e.target_id)], 2, "two frost stacks")
	_streak(w, 4)
	assert_eq(_damage(w, ElementAbilities.EFFECT_NOVA).size(), 2, "4 s between rings")


func test_a_streak_breaks_after_two_seconds() -> void:
	var w := _world(&"blade", [Vector2(2, 0)])
	_grant(w, &"frost_nova")
	w.step(_f())
	_streak(w, 3)
	_run(w, 121)
	_streak(w, 1)
	assert_eq(w.ab.nova_tick, -1, "the streak broke")
	assert_eq(w.ab.streak_n, 1)


func test_frost_nova_levels_widen_freeze_and_quicken() -> void:
	var w := _world(&"blade", [Vector2(3.6, 0)])
	_grant(w, &"frost_nova", 3)
	w.step(_f())
	_streak(w, 4)
	assert_almost_eq(w.ab.nova_r, 3.8, 0.01, "+0.4 m per level")
	_run(w, Modifiers.RING_TICKS + 2)
	assert_gt(w.actors.frozen_t[1], 0, "L3: four stacks freeze at once")
	_grant(w, &"frost_nova", 5)
	var s := w.ability_owned.find(_idx(w, &"frost_nova"))
	_run(w, 240)
	_streak(w, 4)
	assert_eq(w.ab.cd[s], 180, "L5: every 3 s")


# --- Flame Trail (v0.6.0 MX2: the dash and the projectiles leave fire) -----------------------------------------
func _dash(w: World, ticks: int = 20) -> void:
	w.step(_f(InputFrame.DASH, Vector2i(SimTick.MOVE_MAX, 0)))
	_run(w, ticks, Vector2i(SimTick.MOVE_MAX, 0))


func test_flame_trail_leaves_fire_from_the_dash_not_from_walking() -> void:
	var w := _world(&"blade", [])
	_grant(w, &"flame_trail")
	_run(w, 60, Vector2i(SimTick.MOVE_MAX, 0))
	assert_eq(w.ab.fire_pos.size(), 0, "walking: no fire")
	_dash(w)
	assert_gt(w.ab.fire_pos.size(), 0, "a dash: a trail")
	for k in range(1, w.ab.fire_pos.size()):
		assert_gte(w.ab.fire_pos[k].distance_to(w.ab.fire_pos[k - 1]), 0.79, "spaced")
	_run(w, 121)
	assert_eq(w.ab.fire_pos.size(), 0, "each patch burns 2 s")


func test_flame_trail_burns_enemies_in_it() -> void:
	var w := _world(&"blade", [Vector2(1.6, 0.8)])
	_grant(w, &"flame_trail")
	_dash(w, 5)
	_run(w, 60)
	var hits := _damage(w, ElementAbilities.EFFECT_FLAME)
	assert_gt(hits.size(), 0, "the dummy by the trail burns")
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
	_dash(w)
	assert_eq(w.ab.fire_dmg[0], 4, "3 x 1.25, rounded")
	var spec := Modifiers.ability(w, w.ability_tables[_idx(w, &"flame_trail")])
	assert_eq(spec.life_ticks, 150, "2.5 s")


func test_flame_trail_fire_where_a_shot_ends() -> void:
	var w := _world(&"gun", [])
	_grant(w, &"flame_trail")
	for k in 70:
		w.step(_f(0, Vector2i.ZERO, InputFrame.SHOOT))
	assert_gt(w.ab.fire_pos.size(), 0, "a bolt's end leaves fire")
	assert_lte(w.ab.fire_pos.size(), 70 / 9 + 1, "at most one every 0.15 s")


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
	w.step(_f())
	for k in 4:  # v0.6.0 MX2: the fourth attack lobs (the field it leaves is far from the bombs)
		_attack_at(w, Vector2(-9, -9))
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
	_attack_at(w, Vector2(4.5, 0))  # v0.6.0 MX2: the field
	w.step(_f())
	var hits := _damage(w, AbilityCombos.EFFECT_SUPER)
	assert_eq(hits.size(), 1, "the field's hit on a chilled enemy is a Superconductor hit")
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
			var mv := Vector2i(SimTick.MOVE_MAX if (n / 60) % 2 == 0 else -SimTick.MOVE_MAX, 0)
			var press := (
				InputFrame.PRIMARY if n % 15 == 0 else (InputFrame.DASH if n % 97 == 5 else 0)
			)
			w.step(_f(press, mv))
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])
