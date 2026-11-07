extends GutTest
## v0.11.0 O10 (owner Q17, Q19; SPELLS.md) through the real game (main.tscn, input by Input.parse_input_event only): a
## Gun run takes the Fire card from the dev panel's Grant (real clicks), so Fireball is in the run's spell pool; an
## altar's pick offers it (the offer forced: TEST HELPER, the rate is test_spells'), E opens it and 1, Enter take it
## into the first spell slot. With a standing pack in reach (TEST HELPER dummies), the Fireball casts by itself, its
## HUD square flashes and its cooldown sweep runs down, and the ball bursts on the pack.

const W := preload("res://tests/support/mx4_world.gd")


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


## The altar nearest the hero (its index), or -1.
func _altar(w: World) -> int:
	var best := -1
	for i in w.rewards.size():
		if w.rewards.kind[i] != RewardStore.Kind.ALTAR or Arenas.locked(w, i):
			continue
		var d := w.rewards.pos(i).distance_to(w.player_pos())
		if best < 0 or d < w.rewards.pos(best).distance_to(w.player_pos()):
			best = i
	return best


func test_a_spell_is_taken_at_an_altar_and_casts_by_itself_with_its_hud_square() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	var fire := W.item(w, &"ember_core")
	assert_true(Spells.pool(w).is_empty(), "no element card: no spell in the pool")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _click(e, main, "God")  # the walk is about the spell, not survival
	var guard := 0
	while main.driver.debug.mod_choice != fire and guard < 300:
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(w.items_owned.has(fire), "the Fire card held")
	assert_true(Spells.pool(w).has(Spells.FIREBALL), "Fire held: Fireball in the run's pool")
	var altar := _altar(w)
	assert_gte(altar, 0, "an altar on the floor")
	if altar < 0:
		return
	var code := Offers.spell_code(Spells.FIREBALL)
	w.rewards.set_offer(altar, PackedInt32Array([code, W.item(w, &"gun_twin")]))  # TEST HELPER (labelled)
	assert_true(await e.walk_to(w.rewards.pos(altar), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var hud: Hud = main.get_node("UI/Hud")
	var panel := hud.pick_panel()
	assert_true(panel.is_open(), "E opened the altar")
	for n in 240:
		if panel.deal.done():
			break
		await e.frames(1)
	assert_eq(panel.slot(0).face_type(), WorldReader.CARD_SPELL, "a spell card")
	await e.tap(KEY_1)
	await e.tap(KEY_ENTER)
	await e.frames(20)
	assert_eq(w.spell_slots, PackedInt32Array([Spells.FIREBALL]), "taken into the first spell slot")
	assert_false(w.mod_slots.has(code), "not a wand card")
	var sq := hud.spell_squares
	assert_true(sq.visible, "the spell squares show")
	assert_eq(sq.slot_count(), 4, "four squares")
	assert_eq(sq.spell_id(0), &"spell_fireball")
	# TEST HELPER (labelled): a standing pack of three 5 m away on a clear line, so the cast has its target in reach.
	var laser := load("res://tests/e2e/test_e2e_laser.gd")
	var at: Vector2 = laser.clear_spot(w, 5.0)
	assert_ne(at, Vector2.INF, "a clear line from the hero")
	var side := (at - w.player_pos()).normalized().orthogonal()
	w.dummy_speed = 0.0
	var pack: Array[int] = [
		w.add_dummy(at, 0.35, 90000),
		w.add_dummy(at + side * 1.2, 0.35, 90000),
		w.add_dummy(at - side * 1.2, 0.35, 90000),
	]
	var flashed := false
	var cast_tick := -1
	for n in 240:
		await e.frames(1)
		flashed = flashed or sq.flashing(0)
		if w.spell_cast_tick[0] >= 0 and cast_tick < 0:
			cast_tick = w.spell_cast_tick[0]
		if cast_tick >= 0 and flashed:
			break
	assert_gte(cast_tick, 0, "it cast by itself")
	assert_true(flashed, "its square flashed on the cast")
	var first := sq.sweep(0)
	assert_gt(first, 0.8, "the sweep starts full")
	await e.frames(120)
	assert_lt(sq.sweep(0), first, "the sweep runs down")
	var burnt := 0
	for id in pack:
		var i := w.actors.index_of(id)
		if i >= 0 and w.actors.hp[i] < w.actors.max_hp[i]:
			burnt += 1
	assert_gt(burnt, 0, "the ball burst on the pack")
	assert_gt(
		int(main.view.attack_forms.spell_drawn().get(WorldReader.SPELL_FX_BURST, 0)),
		0,
		"the burst is drawn"
	)
