extends GutTest
## v0.9.0 SH, HF (owner Q29b: "Blood and Chaos shrines are added (at most one shrine a floor, costs shown first) ...
## Healing fountains (rare, one use)") through main.tscn with real input only. A run saved on floor 2 is continued from
## the menu (Enter on Continue); God from the dev panel (clicked with the mouse: the dev route, so the walk is safe);
## the stick walks up to the floor's Blood shrine, the shared prompt names its HP price, E pays it: the HP drops by the
## price, the HUD says so and a free altar rises beside it. Another run's floor 2 holds a healing fountain (the hero
## saved hurt): the prompt names the heal, E heals it, the prompt goes and a second E heals nothing.

## Run seeds whose floor 2 holds a Blood shrine (BLOOD_SEED) and a fountain (FOUNTAIN_SEED), found with ShrineLab (as
## Main builds floors; asserted below).
const BLOOD_SEED := 5
const FOUNTAIN_SEED := 1
const FLOOR := 2


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## Boots main.tscn on a save of run `seed_value`'s floor 2 (the hero at `hp`, -1: as built), continues it from the
## menu and turns God on from the dev panel.
func _continue(e: E2e, seed_value: int, hp: int = -1) -> Main:
	var run := SaveLab.run_state(seed_value, FLOOR, &"blade")
	var saved := SaveLab.build_floor(run)
	if hp > 0:
		saved.actors.hp[0] = hp
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(saved, run, seed_value, PackedByteArray())))
	var main: Main = await e.boot(null, store, seed_value)
	var focus := main.get_viewport().gui_get_focus_owner()
	assert_eq(focus.name if focus != null else &"", &"Continue", "the save offers Continue")
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	assert_eq(main.run.floor_index, FLOOR, "floor 2 continues")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	return main


func _front(w: World, at: Vector2) -> Vector2:
	var f := w.floor_layout
	return Gamble.front(at, f.door_approaches(f.room_of(at), 1.0)[0])


func test_walk_to_the_blood_shrine_read_its_price_and_pay() -> void:
	var e := E2e.new(self)
	var main := await _continue(e, BLOOD_SEED)
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_not_null(w.shrine, "this floor has a Blood shrine")
	if w.shrine == null or w.shrine.kind != ShrineTable.Kind.BLOOD:
		return
	assert_not_null(main.view.shrines, "it is drawn")
	assert_true(await e.walk_to(_front(w, w.shrine.pos), 0.5), "walked up to the Blood shrine")
	E2e.center_sticks()
	await e.frames(3)
	var hp := w.actors.hp[0]
	var cost := Shrines.blood_cost(w)
	assert_gt(cost, 0)
	assert_eq(
		hud.interact.prompt_text(), tr("SHRINE_BLOOD_PROMPT") % cost, "the price before the press"
	)
	var rewards := w.rewards.size()
	await e.tap(KEY_E)
	await e.frames(3)
	assert_eq(w.shrine.paid, cost, "E paid the price")
	assert_lte(w.actors.hp[0], hp - cost + 1, "in HP (a regen tick at most since)")
	assert_eq(w.rewards.size(), rewards + 1, "and a free altar rose")
	assert_true(hud.shrine_hud.visible, "the HUD says what it took")
	assert_eq(hud.shrine_hud.detail.text, tr("SHRINE_BLOOD_DONE") % cost)
	assert_true(main.view.shrines.spent(), "the shrine sleeps")
	assert_true(main.view.rewards.node_of(w.shrine.reward_ids[0]).visible, "the altar is in sight")
	gut.p("SHRINES_E2E| blood seed=%d cost=%d hp=%d->%d" % [BLOOD_SEED, cost, hp, w.actors.hp[0]])


func test_walk_to_the_fountain_it_heals_once() -> void:
	var e := E2e.new(self)
	var main := await _continue(e, FOUNTAIN_SEED, 20)
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_true(w.shrine != null and w.shrine.has_fountain(), "this floor has a fountain")
	if w.shrine == null or not w.shrine.has_fountain():
		return
	var at := w.shrine.fountain_pos
	assert_true(await e.walk_to(_front(w, at), 0.5), "walked up to the fountain")
	E2e.center_sticks()
	await e.frames(3)
	var hp := w.actors.hp[0]
	var heal := Shrines.fountain_heal(w)
	assert_gt(heal, 0, "hurt: it would heal")
	assert_eq(hud.interact.prompt_text(), tr("FOUNTAIN_PROMPT") % heal, "the heal before the press")
	await e.tap(KEY_E)
	await e.frames(3)
	assert_eq(w.shrine.fountain_healed, heal, "E healed by what the prompt said")
	assert_gte(w.actors.hp[0], hp + heal, "the HP rose")
	assert_eq(hud.interact.prompt_text(), "", "dry: no prompt")
	assert_true(main.view.shrines.dry(), "drawn dry")
	var tick := w.shrine.fountain_tick
	await e.tap(KEY_E)
	await e.frames(3)
	assert_eq(w.shrine.fountain_tick, tick, "a second E heals nothing")
	assert_eq(w.shrine.fountain_healed, heal)
	gut.p("SHRINES_E2E| fountain seed=%d heal=%d hp=%d->%d" % [FOUNTAIN_SEED, heal, hp, hp + heal])
