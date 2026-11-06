extends GutTest
## v0.10.5 (owner: "I could not open it shooting it with L2"): the cracked wall breaks to the Skill pressed on the
## pad's left trigger (JOY_AXIS_TRIGGER_LEFT, InputDefaults `skill`), three uses, for the Gun's Scatter Blast and the
## Blade's Lunge Cleave, through main.tscn with real input only (test_e2e_cracked_wall has the Blade on Q). Run seed
## SEED's floor 1 holds a cracked wall (asserted). God from the dev panel (the walk is safe), the left stick walks the
## hero up to the wall and turns it to it (with no right-stick aim the Gun aims where the hero faces, O65), then L2.
## Each use that lands is seen and heard: the cracks darken (BreakablesView.crack_shade) and AudioEvents plays the hit.

const SEED := 40  # test_e2e_cracked_wall's


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _grant(e: E2e, main: Main, id: StringName) -> void:
	var w := e.world()
	var guard := 0
	while (
		(main.driver.debug.mod_choice < 0 or w.item_tables[main.driver.debug.mod_choice].id != id)
		and guard < 160
	):
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


func _break_with_l2(build: StringName, from_m: float, card := &"") -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, SEED)
	await e.start_from_menu(build)
	var w := e.world()
	assert_true(w.breakables != null and w.breakables.has_crack(), "this floor has a cracked wall")
	if w.breakables == null or not w.breakables.has_crack():
		return
	var f := w.floor_layout
	var b := w.breakables
	var view := main.view.breakables
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	if card != &"":
		await _grant(e, main, card)
		assert_eq(
			Modifiers.skill(w).form, AttackSpec.Form.RING, "the Ring makes the Blast a flying ring"
		)
	await e.tap(KEY_QUOTELEFT)
	var goal := CrackLab.before_wall(w, from_m)
	var to_wall := (f.door_centers[f.crack_door] - goal).normalized()
	var uses := 0
	var shades: Array[float] = [view.crack_shade]
	while b.crack_broken == 0 and uses < 6:
		assert_true(await e.walk_to(goal, 0.5), "walked up to the wall")
		var wait := 0
		while not PlayerSkill.ready(w) and wait < 400:
			await e.frames(5)
			wait += 5
		e.stick_toward(to_wall)  # face it
		await e.frames(4)
		e.stick_toward(Vector2.ZERO)
		await e.frames(2)
		e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
		await e.frames(2)
		e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
		await e.frames(40)
		uses += 1
		shades.append(view.crack_shade)
	assert_eq(b.crack_broken, 1, "L2 broke it (%s)" % build)
	assert_eq(uses, 3, "in three Skill uses")
	assert_gt(shades[1], shades[0], "the first hit darkens the cracks")
	assert_gt(shades[2], shades[1], "and the second more")
	assert_true(view.revealed, "the hidden room comes into sight")
	gut.p("CRACK_PAD_E2E| build=%s seed=%d uses=%d shades=%s" % [build, SEED, uses, shades])


func test_the_guns_scatter_blast_on_l2_breaks_it() -> void:
	await _break_with_l2(&"gun", 1.4)


func test_the_blades_lunge_cleave_on_l2_breaks_it() -> void:
	await _break_with_l2(&"blade", 1.4)


## W3-O1 (owner, 2026-11-04: "I shot at the wall, actually seeing the blast hit it and it did not break or open"): with
## the Ring card the Blast is a ring that flies along the aim until the first wall (WandRings, owner O47). From 4 m the
## ring flew into the wall and burst on it, but the wall counted only a ring round the hero (2 m), so it took no hit.
func test_the_rings_flying_blast_on_l2_breaks_it_from_four_metres() -> void:
	await _break_with_l2(&"gun", 4.0, &"gun_ring")
