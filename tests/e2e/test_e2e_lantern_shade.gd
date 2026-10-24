extends GutTest
## v0.9.0 NB4 (BOSSES_4_5.md N4): The Lantern Shade reaches the real game. Through main.tscn with real input only: a
## floor-5 save (seed 1: floor 5's pool draws the Shade; built with SaveLab as Main builds floors) continued from the
## menu (Enter); God from the dev panel (clicked); the stick walks to the boss door, E opens it, the stick walks in and
## the door seals; the Shade rises (its model, its name on the boss bar) and its Lights Out comes, shielded: the room
## goes dark (ShadeViews' dark at full, four lanterns lit on the room's edge); the stick waits out a lantern's burn
## beside it, then steps in and relights it by passing. NB4b (owner: "Dark comes and goes"): the dark lifts 8 s after
## it fell (drawn lit again, the Shade hittable anywhere); the next Lights Out brings it back, and in that dark the hero
## closes in, inside its own light, and the mouse's attack lands hits on the lit Shade.

const FLOOR := 5
const LEG_FRAMES := 900


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


func _walk(e: E2e, target: Vector2, done: Callable) -> bool:
	var w := e.world()
	var nav := NavField.new()
	nav.build(E2e.walk_walls(w, target))
	nav.flood(target)
	for k in LEG_FRAMES:
		if done.call():
			break
		var p := w.player_pos()
		var dir := nav.direction(p)
		if (target - p).length() < 1.5 or dir == Vector2.ZERO:
			dir = (target - p).normalized() if (target - p).length() > 0.2 else Vector2.ZERO
		e.stick_toward(dir)
		await e.frames(1)
	e.stick_toward(Vector2.ZERO)
	return done.call()


## Walks to just outside the nearest lantern's reach, waits out its 6 s burn there (inside the 8 s dark), then steps
## in: passing relights it.
func _relight_a_lantern(e: E2e, w: World, reader: WorldReader, shades: ShadeViews) -> bool:
	var lamps0: Array = reader.boss_light().get("lamps", [])
	var out_k := -1
	var out_at := Vector2.INF
	var mid := Vector2.ZERO
	for m in lamps0.size():
		mid += (lamps0[m]["pos"] as Vector2) / float(lamps0.size())
		var d := (lamps0[m]["pos"] as Vector2).distance_to(w.player_pos())
		if out_k < 0 or d < out_at.distance_to(w.player_pos()):
			out_k = m
			out_at = lamps0[m]["pos"]
	assert_gte(out_k, 0, "a lantern to relight")
	if out_k < 0:
		return false
	var lamp_out := func() -> bool:
		var ls: Array = reader.boss_light().get("lamps", [])
		return out_k < ls.size() and not bool(ls[out_k]["lit"])
	await _walk(e, out_at + (mid - out_at).normalized() * 3.0, lamp_out)
	for k in 60 * 7:
		if lamp_out.call():
			break
		await e.frames(1)
	assert_true(lamp_out.call(), "the lantern burnt out")
	assert_true(bool(reader.boss_light().get("dark", false)), "still dark as it does")
	if not lamp_out.call():
		return false
	var relit: bool = await _walk(
		e,
		out_at,
		func() -> bool:
			var ls: Array = reader.boss_light().get("lamps", [])
			return (
				out_k < ls.size()
				and bool(ls[out_k]["lit"])
				and w.player_pos().distance_to(out_at) < 2.0
			)
	)
	assert_true(relit, "passing the out lantern relit it")
	assert_gte(shades.lamps_lit(), 1, "its flame and pool drawn again")
	return relit


## NB4b (owner: "Dark comes and goes"): the dark lifts 8 s after it fell and the light comes back (drawn lit, the
## Shade hittable anywhere); the next Lights Out brings the dark back.
func _dark_lifts_and_returns(
	e: E2e, w: World, reader: WorldReader, shades: ShadeViews, bid: int
) -> bool:
	var lifted := false
	for k in 60 * 6:
		await e.frames(1)
		if not bool(reader.boss_light().get("dark", true)):
			lifted = true
			break
	assert_true(lifted, "the dark lifted")
	if not lifted:
		return false
	for k in 40:  # the lift's short fade
		await e.frames(1)
	assert_almost_eq(shades.dark_strength(), 0.0, 0.01, "the room drawn lit again")
	assert_true(bool(reader.boss_light().get("boss_lit", false)), "the Shade hittable anywhere")
	var again := false
	for k in 60 * 14:
		var a := TAU * float(k) / 150.0
		e.stick_toward(Vector2(cos(a), sin(a)) * 0.5)
		await e.frames(1)
		if w.actors.index_of(bid) < 0:
			break
		if bool(reader.boss_light().get("dark", false)):
			again = true
			break
	e.stick_toward(Vector2.ZERO)
	assert_true(again, "the dark came back with the next Lights Out")
	return again


func test_continue_floor_5_and_fight_the_shade_in_the_dark() -> void:
	var run_seed := 1
	var e := E2e.new(self)
	var run := SaveLab.run_state(run_seed, FLOOR, &"blade")
	var saved := SaveLab.build_floor(run)
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(saved, run, run_seed, PackedByteArray())))
	var main: Main = await e.boot(null, store, run_seed)
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	assert_eq(main.run.floor_index, FLOOR, "floor 5 continues")
	await e.landed()
	var w := e.world()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	assert_true(main.driver.debug.god, "God mode for the fight")
	await e.tap(KEY_QUOTELEFT)
	assert_true(await e.open_boss_door(), "E opened the boss door")
	var f := w.floor_layout
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.5), func() -> bool: return w.boss_flow.door_sealed()
	)
	assert_true(sealed, "walked in: the door sealed")
	if not sealed:
		return
	var reader := main.driver.reader
	for k in 300:
		if reader.boss_index() >= 0:
			break
		await e.frames(1)
	var bi := reader.boss_index()
	assert_gte(bi, 0, "the boss rose")
	if bi < 0:
		return
	assert_eq(reader.actor_kind(bi), WorldReader.KIND_LANTERN_SHADE, "floor 5's boss is the Shade")
	var bid := reader.actor_id(bi)
	var hud: Hud = main.get_node("UI/Hud")
	var avatar: Node = null
	for n in main.view.actors.find_children("*", "Node3D", true, false):
		if n is LanternShadeAvatar:
			avatar = n
	assert_true(avatar is LanternShadeAvatar, "its avatar")
	assert_not_null((avatar as LanternShadeAvatar).imported, "the owner's model")
	assert_eq(tr(reader.boss_name_key(bi)), "The Lantern Shade", "its name")
	var shades := main.view.shades
	# The stick circles; Lights Out comes on its cadence, shielded, and the room goes dark.
	var shielded := false
	var dark := false
	for k in 60 * 16:
		var a := TAU * float(k) / 150.0
		e.stick_toward(Vector2(cos(a), sin(a)))
		await e.frames(1)
		var i := w.actors.index_of(bid)
		if i < 0:
			break
		var atk := BossAi.attack_of(w, i)
		if atk != null and atk.dark_ticks > 0 and reader.boss_shielded(i):
			shielded = true
		if bool(reader.boss_light().get("dark", false)):
			dark = true
			break
	assert_true(shielded, "shielded through Lights Out")
	assert_true(dark, "the room went dark")
	if not dark:
		return
	for k in 60:  # the dark finishes ramping in
		await e.frames(1)
	assert_almost_eq(shades.dark_strength(), 1.0, 0.01, "the dark drawn at full")
	assert_eq(shades.lamps_shown(), 4, "four lanterns on the room's edge")
	assert_true(hud.boss_bar.visible, "its bar")
	if not await _relight_a_lantern(e, w, reader, shades):
		return
	if not await _dark_lifts_and_returns(e, w, reader, shades, bid):
		return
	# The hero closes in: in the dark, the Shade inside the hero's light (and its shield down) is hittable.
	for k in 400:
		var j0 := w.actors.index_of(bid)
		if j0 < 0 or not reader.boss_shielded(j0):
			break
		await e.frames(1)
	await _walk(
		e,
		w.actors.pos(w.actors.index_of(bid)),
		func() -> bool:
			var j := w.actors.index_of(bid)
			return j < 0 or w.player_pos().distance_to(w.actors.pos(j)) < w.actors.radius[j] + 1.2
	)
	var j1 := w.actors.index_of(bid)
	assert_true(bool(reader.boss_light()["dark"]), "still dark as the hero closes in")
	if j1 >= 0:
		assert_true(bool(reader.boss_light()["boss_lit"]), "the Shade stands in the hero's light")
	var hp0 := w.actors.hp[j1] if j1 >= 0 else 0
	var hit_in_dark := false
	for k in 20:
		await e.mouse_button(MOUSE_BUTTON_LEFT, true)
		await e.frames(10)
		await e.mouse_button(MOUSE_BUTTON_LEFT, false)
		await e.frames(10)
		var jk := w.actors.index_of(bid)
		if jk < 0 or w.actors.hp[jk] < hp0:
			# Dark since before the swings and still dark now: the hit landed in the dark, in the hero's light.
			hit_in_dark = bool(reader.boss_light().get("dark", false))
			break
	var j := w.actors.index_of(bid)
	assert_true(j < 0 or w.actors.hp[j] < hp0, "the hero's hits landed on the lit Shade")
	assert_true(hit_in_dark, "in the dark, inside the hero's light")
