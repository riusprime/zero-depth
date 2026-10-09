extends GutTest
## v0.6.0 MX4 (PLAN v0.5.5 M16–M30; docs/design/MODIFIER_ENGINE.md): each modifier's rewrite and its effect in a
## scripted scenario. The legendaries, the ability mods as modifiers and MX2's gaps: test_mx4_engine.gd. Mechanics
## only: no bot, no balance (owner P1).

const W := preload("res://tests/support/mx4_world.gd")
const FORM := AttackSpec.Form
const TRIG := AttackSpec.Trigger


func test_m16_shatter_kills_burst_into_four_shards() -> void:
	var w := W.world(&"gun", [&"shatter"], [[Vector2(2.0, 0.0), 4]])
	var k := W.hook_of(Modifiers.bolt(w), &"shatter")
	assert_eq(
		[k.trigger, k.child.form, k.child.count, k.child.directions],
		[TRIG.ON_KILL, FORM.BOLT, 4, 1]
	)
	W.run(w, 1, 0, W.S)
	var seen := 0
	for t in 20:
		w.step(W.frame())
		seen = maxi(seen, W.projectiles_of(w, &"shatter"))
	assert_eq(seen, 4, "four shards leave the kill")


func test_m17_aftershock_blasts_where_an_attack_ends() -> void:
	var w := W.world(&"blade", [&"aftershock"], [[Vector2(2.2, 0.0), 2000]])
	var k := W.hook_of(Modifiers.step(w, 0), &"aftershock")
	assert_eq([k.trigger, k.child.form], [TRIG.ON_END, FORM.BURST])
	assert_not_null(W.hook_of(Modifiers.bolt(w), &"aftershock"), "a bolt's end too")
	W.run(w, 20, W.P)
	assert_gt(W.damage(w, &"aftershock").size(), 0, "the blast at the arc's tip hits")


func test_m18_seeker_bolts_home_and_arcs_snap() -> void:
	var w := W.world(&"gun", [&"seeker"], [[Vector2(3.0, 2.0), 2000]])
	assert_gt(Modifiers.bolt(w).homing, 0)
	W.run(w, 1, 0, W.S)
	W.run(w, 40)
	assert_gt(W.damage(w, &"").size(), 0, "a bolt aimed along +x turns into the enemy off its line")
	var b := W.world(&"blade", [&"seeker"], [[Vector2(0.0, 1.4), 2000]])
	W.run(b, 20, W.P)
	assert_gt(W.damage(b, &"").size(), 0, "the swing snaps to the enemy beside the player")


func test_m19_long_shadow_repeats_the_last_attack_where_the_dash_began() -> void:
	var w := W.world(&"blade", [&"long_shadow"], [[Vector2(-1.2, 0.0), 2000]])
	var k := W.hook_of(Modifiers.dash(w), &"long_shadow")
	assert_eq([k.trigger, k.child.form, k.delay_ticks], [TRIG.ON_LAUNCH, FORM.WEAPON, 9])
	assert_true(Modifiers.dash(w).has_tag(&"moment"))
	W.run(w, 30, W.P, 0, 2048)  # a swing toward -x (the facing is the aim before any move)
	W.run(w, 1, W.D, 0, 2048, Vector2i(SimTick.MOVE_MAX, 0))
	assert_eq(w.mx.q_key.size(), 1, "the afterimage waits")
	W.run(w, 20, 0, 0, 2048)
	assert_gt(W.damage(w, &"long_shadow").size(), 0, "it swings that way where the dash began")


func test_m20_phase_dash_is_intangible_and_ends_in_shards() -> void:
	var w := W.world(&"blade", [&"phase_dash"])
	assert_eq(Modifiers.dash(w).intangible, 1)
	var k := W.hook_of(Modifiers.dash(w), &"phase_dash")
	assert_eq([k.trigger, k.child.count], [TRIG.ON_END, 6])
	W.run(w, 1, W.D, 0, 0, Vector2i(SimTick.MOVE_MAX, 0))
	var always := true
	var seen := 0
	for t in w.player.dash_ticks + 3:
		always = always and (not w.is_dashing() or w.dash_iframes_active())
		w.step(W.frame(0, 0, 0, Vector2i(SimTick.MOVE_MAX, 0)))
		seen = maxi(seen, W.projectiles_of(w, &"phase_dash"))
	assert_true(always, "untouchable for the whole dash")
	assert_eq(seen, 6, "six shards where it ends")


func test_m21_ember_trail_leaves_burning_crystals_while_walking() -> void:
	var w := W.world(&"blade", [&"ember_trail"])
	var k := W.hook_of(Modifiers.move(w), &"ember_trail")
	assert_eq([k.trigger, k.child.form], [TRIG.ON_LAUNCH, FORM.ZONE])
	assert_true(k.child.has_status(&"burn"))
	W.run(w, 120, 0, 0, 0, Vector2i(SimTick.MOVE_MAX, 0))
	assert_gt(w.ab.fire_pos.size(), 1, "a patch every few steps")
	assert_gt(w.mx.trail_tick, -1)


func test_m22_aether_shell_absorbs_one_hit_after_three_seconds_out_of_combat() -> void:
	var w := W.world(&"blade", [&"aether_shell"])
	assert_eq(Modifiers.body(w).barrier_ticks, 180)
	W.run(w, 200)
	assert_true(ModifierRuntime.shell_up(w))
	var hp := w.actors.hp[0]
	var e := w.add_dummy(Vector2(5.0, 0.0), 0.35, 100)
	var got := Damage.hit(w, 0, 10, e, e, w.take_root(), 0, Vector2(5.0, 0.0), w.player_pos())
	assert_eq([got, w.actors.hp[0]], [0, hp], "the shell takes the hit")
	assert_false(ModifierRuntime.shell_up(w), "and is down until 3 s more out of combat")
	assert_gt(W.events(w, SimEvent.Kind.STATUS_APPLY, &"aether_shell").size(), 0)


func test_m23_ascension_triples_the_first_attack_after_three_seconds() -> void:
	var first := []
	for items: Array in [[], [&"ascension"]]:
		var w := W.world(&"blade", items, [[Vector2(1.0, 0.0), 5000]])
		W.run(w, 200)
		W.run(w, 30, W.P)
		var hits := W.damage(w, &"")
		first.append(hits[0].amount_applied if not hits.is_empty() else 0)
		if not items.is_empty():
			assert_false(ModifierRuntime.charged(w), "spent by the swing")
			assert_eq(w.mx.charge_tick, w.mx.last_attack, "the charged one was the last attack")
	assert_eq(first[1], first[0] * 3, "×3 on the charged swing")


func test_m24_resonance_adds_fifteen_percent_per_status() -> void:
	var w := W.world(&"blade", [&"resonance_core"], [[Vector2(1.0, 0.0), 5000]])
	var a := w.actors
	assert_eq(ModifierRuntime.resonance_mult(w, 1, a.ids[0]), 1000)
	a.burn_stacks[1] = 1
	a.slow_t[1] = 10
	a.poison_stacks[1] = 2
	assert_eq(ModifierRuntime.resonance_mult(w, 1, a.ids[0]), 1450, "three statuses: +45 %")
	assert_eq(ModifierRuntime.resonance_mult(w, 1, a.ids[1]), 1000, "only the player's hits")


func test_m25_heat_sink_rounds_fire_an_extra_projectile_at_overclock() -> void:
	var w := W.world(&"gun", [&"heat_sink_rounds"], [], [], true)
	var k := W.hook_of(Modifiers.bolt(w), &"heat_sink_rounds")
	assert_eq([k.trigger, k.when], [TRIG.ON_LAUNCH, AttackHook.WHEN_OVERCLOCK])
	W.run(w, 2, 0, W.S)
	assert_eq(W.projectiles_of(w, &"heat_sink_rounds"), 0, "not below Overclock")
	w.heat.milli = w.heat.table.overclock_threshold * HeatTable.MILLI + 1
	w.step(W.frame(0, W.S))
	var t := 0
	while t < 20 and W.projectiles_of(w, &"heat_sink_rounds") == 0:
		w.step(W.frame(0, W.S))
		t += 1
	assert_eq(W.projectiles_of(w, &"heat_sink_rounds"), 1, "one extra bolt at Overclock")


func test_m26_meltdown_edge_vents_the_weapon_all_round() -> void:
	var w := W.world(&"gun", [&"meltdown_edge"], [], [], true)
	assert_not_null(Modifiers.vent(w), "Vent's blast is a spec with heat")
	var k := W.hook_of(Modifiers.vent(w), &"meltdown_edge")
	assert_eq(
		[k.trigger, k.child.form, k.child.directions, k.child.count],
		[TRIG.ON_LAUNCH, FORM.WEAPON, 1, 8]
	)
	w.heat.milli = w.heat.table.overclock_threshold * HeatTable.MILLI
	W.run(w, 2, W.V)
	assert_eq(W.projectiles_of(w, Modifiers.GUN_BOLT), 8, "eight shots round the player")
	var b := W.world(&"blade", [&"meltdown_edge"], [[Vector2(-1.0, 0.0), 2000]], [], true)
	b.heat.milli = b.heat.table.overclock_threshold * HeatTable.MILLI
	W.run(b, 2, W.V)
	assert_gt(W.damage(b, &"meltdown_edge").size(), 0, "the Blade's arc all round hits behind")


func test_m27_mirror_drone_copies_the_weapon() -> void:
	var w := W.world(&"gun", [&"splinter_shot", &"mirror_drone"], [], [&"drone_buddy"])
	var drone := Modifiers.ability(w, Abilities.owned_of_kind(w, AbilityTable.Kind.DRONE_BUDDY))
	var bolt := Modifiers.bolt(w)
	assert_eq([drone.mirror, drone.count, drone.spread], [1, bolt.count, bolt.spread])
	var b := W.world(&"blade", [&"echo_slash", &"mirror_drone"], [], [&"drone_buddy"])
	var bd := Modifiers.ability(b, Abilities.owned_of_kind(b, AbilityTable.Kind.DRONE_BUDDY))
	assert_eq(bd.half_arc, Modifiers.step(b, 0).half_arc, "a Blade drone throws crescents")
	assert_not_null(W.hook_of(bd, &"echo_slash"), "with the weapon's hooks, ON_LAUNCH ones too")


func test_m28_bomb_rounds_make_every_fifth_shot_a_bomb() -> void:
	var w := W.world(&"gun", [&"bomb_rounds"], [], [&"bomb_lobber"])
	var k := W.hook_of(Modifiers.bolt(w), &"bomb_rounds")
	assert_eq([k.trigger, k.every, k.child.form], [TRIG.EVERY_NTH, 5, FORM.LOB])
	var shots := 0
	var bombs := 0
	for t in 200:
		var before := w.ab.bomb_pos.size()
		w.step(W.frame(0, W.S))
		if w.ab.bomb_pos.size() > before:
			bombs += 1
	shots = int(w.mx.counts.get(Modifiers.bolt(w).key + "#nth", 0))
	assert_gte(shots, 10)
	assert_eq(bombs, shots / 5, "one bomb per five shots")


func test_m29_blade_orbit_takes_every_hook_of_the_weapon() -> void:
	var w := W.world(&"blade", [&"aftershock", &"blade_orbit"], [], [&"orbit_blades"])
	var t := Abilities.owned_of_kind(w, AbilityTable.Kind.ORBIT_BLADES)
	var plain := W.world(&"blade", [], [], [&"orbit_blades"])
	var orbit := Modifiers.ability(w, t)
	assert_eq(orbit.count, Modifiers.ability(plain, t).count + 1, "+1 blade")
	var on_touch := false
	for k in orbit.hooks:
		on_touch = on_touch or (k.id == &"aftershock" and k.trigger == TRIG.ON_HIT)
	assert_true(on_touch, "the weapon's ON_END hook fires on each touch")
	var bare := Modifiers.ability(W.world(&"blade", [&"aftershock"], [], [&"orbit_blades"]), t)
	for k in bare.hooks:
		assert_false(k.id == &"aftershock" and k.trigger == TRIG.ON_HIT, "not without Blade Orbit")


func test_m30_short_fuse_trades_range_for_damage() -> void:
	var plain := W.world(&"blade")
	var w := W.world(&"blade", [&"short_fuse"])
	var a := Modifiers.step(plain, 0)
	var b := Modifiers.step(w, 0)
	assert_almost_eq(b.reach_m, a.reach_m * 0.6, 1e-5)
	assert_eq(b.damage, a.damage * 1400 / 1000)
	assert_eq(Modifiers.bolt(w).life_ticks, Modifiers.bolt(plain).life_ticks * 600 / 1000)
