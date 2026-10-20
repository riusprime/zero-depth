extends GutTest
## v0.8.0 RM (owner O91: "Threadline: consecutive projectiles connect briefly with damaging threads. Faultline: blade
## contact/projectile impacts leave cracks; subsequent attacks crossing them cause eruptions. Gravity Stitch: hits leave
## short-lived anchors that bend projectiles and pull enemies. Stress Mark: hits mark enemies; a later hit from a
## different direction breaks the mark. Dodge Imprint … Double Exposure … Grand Finale … Rework Finisher+ into Fracture
## Bank"): each remnant card's rule in play (Remnants), Grand Finale's reach (left of it, same trigger section), Dodge
## Imprint's origin; determinism and a snapshot taken while remnants stand (the store's own rules: test_remnants.gd).
## Mechanics only: no bot, no balance (owner P1).

const W := preload("res://tests/support/mx4_world.gd")
const K := RemnantRule.Kind
const A := RemnantRule.Activate


func _hook(s: AttackSpec, id: StringName) -> AttackHook:
	return W.hook_of(s, id)


func _ctx(w: World, at: Vector2, angle: int, dmg: int, depth: int = 0) -> AttackContext:
	var c := AttackContext.make(at, angle, dmg, w.take_root(), SimEvent.TAG_MELEE, &"")
	c.depth = depth
	c.proc_pct = maxi(1, 100 >> depth)
	return c


## The events of `kind` whose effect is `card`, since the log began.
func _ev(w: World, kind: int, card: StringName) -> Array[SimEvent]:
	return W.events(w, kind, card)


func test_threadline_links_a_volley_and_consecutive_shots() -> void:
	var w := W.world(&"gun", [&"gun_threadline", &"gun_spread"], [[Vector2(4.0, 0.0), 100000]])
	var most := 0
	for t in 120:
		w.step(W.frame(0, W.S))
		most = maxi(most, w.mx.rem_uid.size())
	assert_gt(_ev(w, SimEvent.Kind.REMNANT_SPAWN, &"gun_threadline").size(), 0, "threads link")
	assert_lte(most, 6, "6 threads at most")
	assert_eq(W.events(w, SimEvent.Kind.LIMIT, Remnants.EFFECT_LIMIT).size(), 0)


func test_faultline_cracks_then_a_later_slash_erupts_it() -> void:
	var w := W.world(&"blade", [&"shared_faultline"], [[Vector2(1.2, 0.0), 100000]])
	W.run(w, 1, W.P)
	W.run(w, 20)
	assert_eq(_ev(w, SimEvent.Kind.REMNANT_SPAWN, &"shared_faultline").size(), 1, "one crack")
	assert_eq(W.damage(w, &"shared_faultline").size(), 0, "the slash that made it doesn't erupt it")
	W.run(w, 1, W.P)
	W.run(w, 20)
	assert_gt(_ev(w, SimEvent.Kind.REMNANT_ACTIVATE, &"shared_faultline").size(), 0, "it erupts")
	assert_gt(W.damage(w, &"shared_faultline").size(), 0, "hurting the enemy")
	var spent := false
	for e in _ev(w, SimEvent.Kind.REMNANT_END, &"shared_faultline"):
		spent = spent or e.amount == Remnants.END_SPENT
	assert_true(spent, "and is spent")


func test_a_later_shot_across_a_crack_erupts_it() -> void:
	var w := W.world(&"gun", [&"shared_faultline"], [[Vector2(3.0, 0.0), 100000]])
	var k := _hook(Modifiers.bolt(w), &"shared_faultline")
	Remnants.on_hook(w, k, _ctx(w, Vector2(2.0, 0.0), 1024, 10), Vector2(2.0, 0.0), 1)
	assert_eq(w.mx.rem_uid.size(), 1)
	for t in 30:
		w.step(W.frame(0, W.S))
	assert_gt(
		_ev(w, SimEvent.Kind.REMNANT_ACTIVATE, &"shared_faultline").size(), 0, "a bolt crossed"
	)


func test_gravity_stitch_pulls_enemies_and_bends_shots() -> void:
	var w := W.world(&"gun", [&"shared_gravity_stitch"], [[Vector2(5.0, 0.0), 100000]])
	var k := _hook(Modifiers.bolt(w), &"shared_gravity_stitch")
	Remnants.on_hook(w, k, _ctx(w, Vector2(3.0, 0.0), 0, 10), Vector2(3.0, 0.0), 1)
	assert_eq(w.mx.rem_kind, PackedInt32Array([K.ANCHOR]))
	var pid := w.actors.ids[0]
	w.queue_projectile(
		pid, ActorStore.TEAM_PLAYER, Vector2(1.0, -1.5), Vector2(0.27, 0.0), 5, 0.1, 60, 2
	)
	W.run(w, 5)
	var bent := false
	for pi in w.projectiles.size():
		if w.projectiles.team[pi] == ActorStore.TEAM_PLAYER:
			bent = bent or w.projectiles.vel_y[pi] > 0.01
	assert_true(bent, "the shot passing by turns toward it")
	W.run(w, 15)
	var d := w.actors.pos(1).distance_to(Vector2(3.0, 0.0))
	assert_almost_eq(d, 2.0 - 20 * 0.025, 0.05, "pulled 1.5 m/s toward the anchor")
	W.run(w, 60)
	assert_eq(w.mx.rem_uid.size(), 0, "1.2 s, then gone")


func test_stress_mark_breaks_on_a_hit_from_another_side() -> void:
	var w := W.world(&"blade", [&"shared_stress_mark"], [[Vector2(2.0, 0.0), 100000]])
	var k := _hook(Modifiers.step(w, 0), &"shared_stress_mark")
	Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 10), Vector2(2.0, 0.0), 1)
	assert_eq(w.mx.rem_kind, PackedInt32Array([K.MARK]), "the first hit marks")
	assert_eq(w.mx.rem_dir[0], 0, "with the hit's direction")
	Remnants.on_hook(w, k, _ctx(w, Vector2(0.0, 1.0), 0, 10), Vector2(2.0, 0.0), 1)
	assert_eq(w.mx.rem_uid.size(), 1, "a hit about 27° away doesn't break it")
	Remnants.on_hook(w, k, _ctx(w, Vector2(2.0, 2.0), 0, 30), Vector2(2.0, 0.0), 1)
	assert_eq(w.mx.rem_uid.size(), 0, "a hit from 90° away breaks it")
	var dmg := W.damage(w, &"shared_stress_mark")
	assert_eq(dmg.size(), 1)
	assert_eq(dmg[0].amount, 30, "+100 % of that hit")
	Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 10), Vector2(2.0, 0.0), 1)
	assert_eq(w.mx.rem_uid.size(), 1, "the next hit marks it again")


func test_fracture_bank_extracts_every_lodged_fragment() -> void:
	var w := W.world(&"blade", [&"finisher_plus"], [[Vector2(2.0, 0.0), 100000]])
	var lodge := _hook(Modifiers.step(w, 0), &"finisher_plus")
	var last := _hook(Modifiers.step(w, w.player.combo.size() - 1), &"finisher_plus")
	for n in 6:
		Remnants.on_hook(w, lodge, _ctx(w, Vector2.ZERO, 0, 10), Vector2(2.0, 0.0), 1)
	assert_eq(w.mx.rem_count, PackedInt32Array([4]), "4 fragments at most")
	Remnants.on_hook(w, last, _ctx(w, Vector2.ZERO, 0, 50), Vector2(2.0, 0.0), 1)
	assert_eq(w.mx.rem_uid.size(), 0, "the finisher extracts them")
	var dmg := W.damage(w, &"finisher_plus")
	assert_eq(dmg.size(), 1, "as one burst")
	assert_eq(dmg[0].amount, 50 * 4 * 400 / 1000, "40 % of the finisher a fragment")


func test_fracture_bank_in_a_combo() -> void:
	var w := W.world(&"blade", [&"finisher_plus"], [[Vector2(1.2, 0.0), 1000000]])
	for n in 12:
		W.run(w, 1, W.P)
		W.run(w, 14)
	assert_gt(_ev(w, SimEvent.Kind.REMNANT_SPAWN, &"finisher_plus").size(), 0, "combo hits lodge")
	assert_gt(
		_ev(w, SimEvent.Kind.REMNANT_ACTIVATE, &"finisher_plus").size(), 0, "finishers extract"
	)


func test_double_exposure_replays_a_slash_once() -> void:
	var w := W.world(&"blade", [&"mut_double_exposure"])
	var spec := Modifiers.step(w, 0)
	var r := w.player.radius_m + Attacks.arc_reach_m(w, spec) * Remnants.PATH_REACH
	w.add_dummy(Vector2(r - 0.1, 0.0), 0.35, 100000)
	W.run(w, 1, W.P)
	W.run(w, 10)
	assert_eq(
		_ev(w, SimEvent.Kind.REMNANT_SPAWN, &"mut_double_exposure").size(), Remnants.ARC_CHORDS
	)
	assert_eq(W.damage(w, &"mut_double_exposure").size(), 0, "not yet")
	W.run(w, 40)
	assert_eq(W.damage(w, &"mut_double_exposure").size(), 1, "0.6 s later the arc hurts once")
	W.run(w, 120)
	assert_eq(W.damage(w, &"mut_double_exposure").size(), 1, "its replay never replays")
	assert_eq(w.mx.rem_uid.size(), 0)


func test_double_exposure_replays_a_bolts_line() -> void:
	var w := W.world(&"gun", [&"mut_double_exposure"], [[Vector2(3.0, 0.0), 100000]])
	w.step(W.frame(0, W.S))
	W.run(w, 80)
	assert_gt(_ev(w, SimEvent.Kind.REMNANT_SPAWN, &"mut_double_exposure").size(), 0, "its line")
	assert_gt(W.damage(w, &"mut_double_exposure").size(), 0, "hurts the enemy on it")


func _finale(order: Array) -> World:
	var w := W.world(&"blade", order, [[Vector2(2.0, 0.0), 100000]])
	W.run(w, 100)
	var k := _hook(Modifiers.step(w, 0), &"shared_faultline")
	Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 20), Vector2(2.0, 0.0), 1)
	W.run(w, 150)
	return w


func test_grand_finale_releases_the_remnants_left_of_it() -> void:
	var w := _finale([&"shared_faultline", &"mut_grand_finale"])
	assert_eq(w.mx.rem_uid.size(), 0, "consumed at 4 s")
	var ends := _ev(w, SimEvent.Kind.REMNANT_END, &"shared_faultline")
	assert_eq(ends[ends.size() - 1].amount, Remnants.END_CONSUMED)
	assert_eq(_ev(w, SimEvent.Kind.REMNANT_ACTIVATE, &"mut_grand_finale").size(), 1)
	var dmg := W.damage(w, &"mut_grand_finale")
	assert_eq(dmg.size(), 1, "a 1.5 m burst on the enemy beside it")
	assert_eq(dmg[0].amount, 12, "60 % of the hit that made it")


func test_grand_finale_leaves_the_cards_right_of_it_and_past_a_trigger() -> void:
	var right := _finale([&"mut_grand_finale", &"shared_faultline"])
	assert_eq(right.mx.rem_uid.size(), 1, "a card right of it: left alone")
	var other := _finale([&"shared_faultline", &"trigger_on_hit", &"mut_grand_finale"])
	assert_eq(_hook(Modifiers.step(other, 0), &"shared_faultline").section, 0)
	assert_eq(other.mx.rem_uid.size(), 1, "another trigger section: left alone")
	assert_eq(W.damage(other, &"mut_grand_finale").size(), 0)


func test_dodge_imprint_casts_the_next_attack_where_the_dash_began() -> void:
	var dash := Modifiers.dash(W.world(&"blade", [&"long_shadow"]))
	assert_eq([dash.imprint_ticks, dash.imprint_permille], [90, 1100], "1.5 s, +10 %")
	assert_null(W.hook_of(dash, &"long_shadow"), "no ghost copy any more")
	var hp := []
	for ids: Array in [[], [&"long_shadow"]]:
		var w := W.world(&"blade", ids, [[Vector2(1.0, 0.8), 100000]])
		var right := Vector2i(SimTick.MOVE_MAX, 0)
		W.run(w, 1, W.D, 0, 0, right)
		W.run(w, 12, 0, 0, 0, right)
		assert_gt(w.player_pos().x, 3.0, "the dash took the player away")
		W.run(w, 1, W.P)
		W.run(w, 20)
		hp.append(w.actors.hp[1])
		if ids.is_empty():
			continue
		assert_eq(_ev(w, SimEvent.Kind.REMNANT_ACTIVATE, &"long_shadow").size(), 1)
		assert_lt(w.mx.imprint_until, w.tick, "spent")
	assert_eq(hp[0], 100000, "without it, the slash where you stand misses")
	assert_lt(hp[1], 100000, "with it, the slash comes from where the dash began")


# --- Determinism and saves ---------------------------------------------------------------------------------------
func _fight() -> World:
	return W.world(
		&"gun",
		[&"gun_threadline", &"shared_faultline", &"shared_gravity_stitch", &"shared_stress_mark"],
		[[Vector2(3.0, 0.4), 1000000], [Vector2(5.0, -0.6), 1000000]]
	)


func test_the_same_seed_plays_to_the_same_hash() -> void:
	var a := _fight()
	var b := _fight()
	for t in 300:
		a.step(W.frame(0, W.S, (t * 37) % 400))
		b.step(W.frame(0, W.S, (t * 37) % 400))
	assert_true(a.mx.remnants_touched(), "remnants were left")
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.mx.rem_uid, b.mx.rem_uid)


func test_a_snapshot_with_remnants_standing_round_trips() -> void:
	var w := _fight()
	var guard := 0
	while w.mx.rem_uid.size() < 2 and guard < 600:
		w.step(W.frame(0, W.S))
		guard += 1
	assert_gte(w.mx.rem_uid.size(), 2, "remnants stand")
	var snap := WorldSnapshot.take(w)
	var base := _fight()
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.state_hash(), w.state_hash(), "restored to the same hash")
	for t in 60:
		w.step(W.frame(0, W.S))
		base.step(W.frame(0, W.S))
	assert_eq(base.state_hash(), w.state_hash(), "and plays on the same")


func test_a_build_without_remnant_cards_never_touches_the_store() -> void:
	var w := W.world(&"gun", [&"gun_spread"], [[Vector2(3.0, 0.0), 100000]])
	W.run(w, 200, 0, W.S)
	assert_false(w.mx.remnants_touched(), "no block in its hash")
	assert_eq(W.events(w, SimEvent.Kind.REMNANT_SPAWN).size(), 0)
