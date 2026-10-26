extends GutTest
## v0.9.5 FC1 (owner: "homing + laser would make the laser follow the neares enemy making a smooth curve, and with
## pierce it would make a smooth curve trying to hit the closest 5 enemies") through the real game (main.tscn, input by
## Input.parse_input_event only): a Gun run takes the Laser at an altar (E and the pick panel), takes Homing and Pierce
## with the dev panel's Grant (real clicks), and holds the shoot button with the mouse on the nearest of five standing
## dummies laid on a curve: the beam bends along it and every one of the five takes damage, the beam drawn as a curve of
## several ribbons.

const W := preload("res://tests/support/mx4_world.gd")
## Five dummies on a gentle curve, in the hero's frame (x ahead, y to the left), nearest first.
const ARC: Array[Vector2] = [
	Vector2(2.0, 0.3), Vector2(3.5, 1.2), Vector2(4.5, 2.6), Vector2(5.0, 4.2), Vector2(4.8, 5.8)
]


func after_each() -> void:
	Input.action_release(&"shoot")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## The arc laid out from the hero (scaled down, mirrored or turned until the path hero -> 1 -> ... -> 5 crosses no
## wall), or [].
func _arc(w: World) -> Array[Vector2]:
	var p := w.player_pos()
	for scale: float in [1.0, 0.9, 0.8]:
		for mirror: float in [1.0, -1.0]:
			for k in 48:
				var fwd := Vector2.from_angle(TAU * k / 48.0)
				var left := fwd.orthogonal() * mirror
				var out: Array[Vector2] = []
				var ok := true
				var prev := p
				for a in ARC:
					var at: Vector2 = p + (fwd * a.x + left * a.y) * scale
					for i in w.walls_along(prev, at, 0.7):
						if Collide.sweep_vs_obb(prev, at, 0.7, w.walls[i]) >= 0.0:
							ok = false
					for i in w.walls.size():
						if Collide.circle_vs_obb(at, 0.8, w.walls[i]) != Vector2.ZERO:
							ok = false
					prev = at
					out.append(at)
				if ok:
					return out
	return []


## Takes card `id` at the nearest altar (its offer forced: TEST HELPER). True when taken.
func _take_at_altar(e: E2e, main: Main, id: StringName, others: Array) -> bool:
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	var i := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gte(i, 0, "an altar on the floor")
	if i < 0:
		return false
	var offer := PackedInt32Array([W.item(w, id)])
	for o: StringName in others:
		offer.append(W.item(w, o))
	w.rewards.set_offer(i, offer)
	assert_true(await e.walk_to(w.rewards.pos(i), w.reward_table.interact_radius_m * 0.6))
	await e.tap(KEY_E)
	await e.frames(2)
	var panel := hud.pick_panel()
	assert_true(panel.is_open(), "E opened the altar")
	for k in 240:
		if panel.deal.done():
			break
		await e.frames(1)
	await e.tap(KEY_1)
	await e.tap(KEY_ENTER)
	await e.frames(70)
	return w.items_owned.has(W.item(w, id))


func _grant(e: E2e, main: Main, w: World, id: StringName) -> void:
	var k := W.item(w, id)
	var guard := 0
	while main.driver.debug.mod_choice != k and guard < 300:
		await _click(e, main, "NextMod")
		guard += 1
	await _click(e, main, "GrantMod")
	await e.frames(3)


func test_homing_and_pierce_make_the_laser_thread_five_enemies() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(await _take_at_altar(e, main, &"gun_laser", [&"gun_twin"]), "took the Laser")
	# TEST HELPER (labelled): the dev panel's Grant, by real clicks, takes Homing and Pierce.
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	await _grant(e, main, w, &"gun_homing")
	await _grant(e, main, w, &"gun_pierce")
	await e.tap(KEY_QUOTELEFT)
	await e.frames(2)
	assert_true(w.items_owned.has(W.item(w, &"gun_homing")), "Homing is in the wand")
	assert_true(w.items_owned.has(W.item(w, &"gun_pierce")), "Pierce is in the wand")
	var s := Modifiers.bolt(w)
	assert_eq(LaserMods.mask(s) & LaserMods.HOMING, LaserMods.HOMING, "the beam reads Homing")
	assert_eq(s.pierce, 4, "and Pierce")
	# TEST HELPER (labelled): the floor's own enemies are cleared (they would shove the hero and take the nearest
	# targets), then five standing dummies stand on a curve ahead on a clear line.
	for i in range(1, w.actors.size()):
		if w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.dead[i] = 1
	var arc := _arc(w)
	assert_eq(arc.size(), 5, "a clear curve around the hero")
	if arc.size() != 5:
		return
	w.dummy_speed = 0.0
	var ids := []
	for at in arc:
		ids.append(w.add_dummy(at, 0.35, 90000))
	var cam := main.view.rig.camera
	var curved := false
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(arc[0], SimPlane.CORE_HEIGHT)))
	for n in 240:
		await e.frames(1)
		curved = curved or main.view.laser.shown >= 3
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	var hurt := 0
	for id: int in ids:
		var j := w.actors.index_of(id)
		if j >= 0 and w.actors.hp[j] < w.actors.max_hp[j]:
			hurt += 1
	gut.p(
		(
			"FC1 e2e: %d of 5 dummies hurt after 240 frames held; curve drawn as >= 3 ribbons: %s"
			% [hurt, curved]
		)
	)
	assert_eq(hurt, 5, "all five take damage")
	assert_true(curved, "the beam is drawn as a curve of several ribbons")
	await e.frames(4)
	assert_eq(main.view.laser.shown, 0, "let go: the beam is gone")
