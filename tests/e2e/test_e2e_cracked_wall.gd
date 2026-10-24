extends GutTest
## v0.9.0 DX (owner W §4 C: "Breaking them reveals hidden spaces"; Q23: "The Skill (Q / pad Y)", "hidden room should
## not appear or be visible until you open it") through main.tscn with real input only: run seed SEED's floor 1 holds
## a cracked wall (asserted below). God from the dev panel (clicked with the mouse: the dev route, so the walk is safe),
## then the stick walks up to the wall and turns the hero to it, and Q (the Blade's Lunge Cleave) hits it, three times;
## it breaks, the hidden room comes into sight and the hero walks in to its reward.

## Run seed SEED: floor 1 holds a cracked wall (found with the floor plan, asserted below).
## v0.9.0 FV: five floors made floor 1 smaller (10-12 rooms; 2 of seeds 1-120 hold one): seed 22; v0.9.0 CF2: the
## Lockdowns take their rooms first, seed 40.
const SEED := 40


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_break_the_cracked_wall_with_the_skill_and_walk_in() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, SEED)
	await e.start_from_menu()
	var w := e.world()
	assert_true(w.breakables != null and w.breakables.has_crack(), "this floor has a cracked wall")
	if w.breakables == null or not w.breakables.has_crack():
		return
	var f := w.floor_layout
	var b := w.breakables
	var view := main.view.breakables
	assert_not_null(view, "the wall is drawn")
	assert_false(view.revealed, "the hidden room unseen")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	var goal := CrackLab.before_wall(w, 1.4)
	var to_wall := (f.door_centers[f.crack_door] - goal).normalized()
	var uses := 0
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
		await e.tap(KEY_Q)
		await e.frames(40)
		uses += 1
	assert_eq(b.crack_broken, 1, "Q broke it")
	assert_eq(uses, 3, "in three Skill uses")
	assert_true(view.revealed, "the hidden room comes into sight")
	var reward := w.rewards.index_of(b.crack_reward_id)
	assert_true(await e.walk_to(w.rewards.pos(reward), 1.2), "walked through the gap to the reward")
	assert_eq(f.room_of(w.player_pos()), f.crack_room, "inside the hidden room")
	assert_true(main.view.rewards.node_of(b.crack_reward_id).visible, "its reward in sight")
	gut.p("CRACK_E2E| seed=%d uses=%d" % [SEED, uses])
