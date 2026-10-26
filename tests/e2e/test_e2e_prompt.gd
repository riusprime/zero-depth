extends GutTest
## v0.9.5 PR (owner L15, Q10 a): the short prompt under the hero, through real input. Walk to a chest on the real
## game: the prompt reads the verb and its cost ("Open · 40 ◆"), red while you cannot pay, sits below the hero's feet,
## and shows the keyboard's key cap for the bound interact key; E opens the chest and the prompt goes.

const CHEST_SEED := 20261007


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"shoot"]:
		Input.action_release(a)


func test_the_chest_prompt_is_a_verb_and_its_cost_under_the_hero() -> void:
	TranslationServer.set_locale("en")
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, CHEST_SEED)
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var i := E2e.nearest_reward(w, RewardStore.Kind.CHEST)
	assert_gte(i, 0, "a chest on the floor")
	if i < 0:
		return
	var price := w.rewards.price[i]
	var reached: bool = await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6)
	assert_true(reached, "walked up to the chest")
	await e.frames(3)
	var p := hud.find_child("RewardPrompt", true, false) as InteractPrompt
	assert_eq(hud.prompt_text(), "Open · %d ◆" % price, "the verb, then the cost")
	assert_true(p.visible, "shown")
	assert_false(hud.prompt_text().contains("shards"), "no long sentence")
	# The walk used the stick, so the button is the pad's: Xbox-style X (this headless pad has no name).
	assert_true(p.pad_active, "a pad walk")
	assert_eq(p.glyph().spec["style"], &"xbox")
	assert_eq(p.glyph().spec["label"], "X")
	# A key event (an unbound key) turns it to the key cap with the bound interact key.
	await e.tap(KEY_F13)
	await e.frames(2)
	assert_false(p.pad_active, "a key was the last device")
	assert_eq(p.glyph().spec["style"], &"key")
	assert_eq(
		p.glyph().spec["label"], InputLabels.short_text(KitHud.key_spec_for(&"interact", false))
	)
	# Under the hero: centred on the feet, below them by 40 px at 1080p scaled to this viewport.
	var cam := get_viewport().get_camera_3d()
	var feet := cam.unproject_position(SimPlane.to_3d(w.player_pos()))
	var k := get_viewport().get_visible_rect().size.y / InteractPrompt.REF_H
	assert_almost_eq(
		p.position.y, feet.y + InteractPrompt.BELOW_PX * k, 1.5, "40 px under the feet"
	)
	assert_almost_eq(p.position.x + p.size.x * 0.5, feet.x, 1.5, "centred on the hero")
	# Pay and open it with the interact action.
	w.shards = price + 7  # TEST HELPER (labelled): the shards by hand; earning them is test_e2e_rewards.
	await e.frames(2)
	assert_false(hud.prompt_poor(), "not red once you can pay")
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.choosing, w.rewards.ids[i], "E opened the chest")
	assert_eq(hud.prompt_text(), "", "no prompt while choosing")
