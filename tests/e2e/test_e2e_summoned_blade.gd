extends GutTest
## The rune-summoned Blade in the real game, through main.tscn and real input only (Input.parse_input_event): on a
## Blade run, a left click swings and the owner's Blade shows for the swing (formed in a rune flash), then breaks into
## motes and is gone; Q's Lunge Cleave keeps it out through the lunge and the cleave. Read through the view.


func after_each() -> void:
	for a in [&"skill", &"primary"]:
		Input.action_release(a)


func test_a_swing_and_the_lunge_cleave_summon_the_blade() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"blade")
	await e.frames(5)
	assert_true(main.is_playing())
	var r := WorldReader.new(e.world())
	var blade: SummonedBlade = main.view.kit.summoned
	assert_true(blade.has_model(), "the owner's model is in the game")
	assert_false(blade.blade_visible(), "nothing shows before a swing")
	var cam := main.view.rig.camera
	await e.click_at(
		cam.unproject_position(SimPlane.to_3d(r.player_pos() + Vector2(1.5, 0.0), 0.4))
	)
	var shown := false
	var swung := false
	for k in 40:
		await e.frames(1)
		swung = swung or r.swing_tick() > 0
		shown = shown or (r.swing_tick() > 0 and blade.blade_visible())
		if swung and r.swing_tick() == 0:
			break
	await e.frames(2)
	assert_true(swung, "the click swung")
	assert_true(shown, "the Blade showed for the swing")
	assert_gt(blade.flashes, 0, "formed in a flash of runes")
	assert_false(blade.blade_visible(), "gone after the recovery")
	assert_gt(blade.motes, 0, "in motes")
	var forms := blade.forms
	await e.tap(KEY_Q)
	var lunging := 0
	var out_while_lunging := 0
	for k in 20:
		await e.frames(1)
		if int(r.skill_state()["running"]) > 0:
			lunging += 1
			out_while_lunging += 1 if blade.blade_visible() else 0
	assert_gt(lunging, 0, "Q lunged")
	assert_eq(out_while_lunging, lunging, "the Blade was out for the whole lunge")
	assert_gt(blade.forms, forms, "summoned again for the cleave")
	assert_eq(get_errors().size(), 0, "no engine or script error")
