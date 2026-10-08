class_name E2e
extends RefCounted
## Drives the real game the way a player does: Input.parse_input_event, then flush, then wait for physics
## frames (TEST_MATRIX T-E2E). No calls into game objects to make things happen; reads are fine.

## walk_to's budget (frames of stick input).
const WALK_FRAMES := 2400

var test: GutTest
var main: Main


func _init(p_test: GutTest) -> void:
	test = p_test


## Boots main.tscn with a memory-only profile (optionally pre-filled) and waits for the menu.
func boot(profile: ProfileStore = null) -> Main:
	ProfileStore.use_shared(profile if profile != null else ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))  # v0.4.0 SV: no run save from an earlier test
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	test.add_child_autofree(main)
	await frames(2)
	return main


func frames(n: int) -> void:
	for i in n:
		await test.get_tree().physics_frame


func send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = pressed
	send(ev)


## Press and release in the same frame: a tap shorter than one tick.
func tap(keycode: Key) -> void:
	key(keycode, true)
	key(keycode, false)
	await frames(1)


func joy_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	send(ev)


func joy_button(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	send(ev)


func mouse_button(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	send(ev)


## Moves the mouse so the game receives `pos` in viewport coordinates. Headless windows are 0x0, so Godot's
## stretch transform rescales injected positions; the scale is measured once and divided out.
func mouse_to(pos: Vector2) -> void:
	var scale := await _mouse_scale()
	var ev := InputEventMouseMotion.new()
	ev.position = pos / scale
	ev.global_position = pos / scale
	send(ev)
	await frames(1)


func _mouse_scale() -> Vector2:
	var probe := InputEventMouseMotion.new()
	probe.position = Vector2(100, 100)
	probe.global_position = probe.position
	send(probe)
	await frames(1)
	var got := main.get_viewport().get_mouse_position()
	return got / 100.0 if got.x > 0.0 and got.y > 0.0 else Vector2.ONE


## Play from the main menu with the keyboard: the Play button has focus, then the build screen's last pick (Blade on
## a fresh profile; Right moves to Gun). v0.4.0 BS (F11): no utility pick; the run starts with weapon, dash, skill
## and vent.
func start_from_menu(build: StringName = &"blade") -> void:
	await tap(KEY_ENTER)
	await frames(2)
	if build == &"gun":
		await tap(KEY_RIGHT)
	await tap(KEY_ENTER)
	await frames(4)


func world() -> World:
	return main.driver.world if main.driver != null else null


## A left click at `pos` in viewport coordinates (move there, press, release), scaled like mouse_to.
func click_at(pos: Vector2) -> void:
	var scale := await _mouse_scale()
	await mouse_to(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos / scale
		ev.global_position = pos / scale
		send(ev)
		await frames(1)


## Pushes the left stick toward a sim-plane direction (the inverse of the +45 degree screen-to-sim rotation; stick y
## is down). ZERO releases it.
func stick_toward(dir: Vector2) -> void:
	var c := InputLatch.C45
	joy_axis(JOY_AXIS_LEFT_X, (dir.x + dir.y) * c)
	joy_axis(JOY_AXIS_LEFT_Y, -(dir.y - dir.x) * c)


## The reward (RewardStore.Kind) nearest the player (v0.3.0 E), or -1. A read, not an action.
static func nearest_reward(w: World, kind: int) -> int:
	var best := -1
	for i in w.rewards.size():
		if w.rewards.kind[i] != kind:
			continue
		if (
			best < 0
			or (
				w.rewards.pos(i).distance_to(w.player_pos())
				< w.rewards.pos(best).distance_to(w.player_pos())
			)
		):
			best = i
	return best


## The flood's goal for `target`: its own cell, or (when a wall is within the enemies' nav clearance of it, as on
## a v0.5.9 themed floor where a vignette may stand by a shop's front) the nearest free cell, from which the walk goes
## straight in. The player's radius is smaller than the nav clearance, so the target itself stays reachable.
static func _free_goal(nav: NavField, target: Vector2) -> Vector2:
	var c := nav.cell_of(target)
	if not nav.inside(c) or nav.blocked[c.y * nav.size.x + c.x] == 0:
		return target
	for ring in range(1, 8):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var n := c + Vector2i(dx, dy)
				if nav.inside(n) and nav.blocked[n.y * nav.size.x + n.x] == 0:
					return nav.center(n)
	return target


## Walks with the left stick only (a flow field toward `target`, then straight in) until within `within` m, then
## lets go and waits for the player to stop. False if it didn't get there (or died).
func walk_to(target: Vector2, within: float) -> bool:
	var w := world()
	var nav := NavField.new()
	nav.build(w.walls)
	nav.flood(_free_goal(nav, target))
	var ok := false
	for k in WALK_FRAMES:
		var p := w.player_pos()
		if (target - p).length() <= within:
			ok = true
			break
		if w.player_dead():
			break
		var dir := nav.direction(p)
		if (target - p).length() < 1.5 or dir == Vector2.ZERO:
			dir = (target - p).normalized()
		# Sim direction -> screen stick (the inverse of the +45 degree screen-to-sim rotation); stick y is down.
		var c := InputLatch.C45
		var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
		joy_axis(JOY_AXIS_LEFT_X, screen.x)
		joy_axis(JOY_AXIS_LEFT_Y, -screen.y)
		await frames(1)
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	await frames(12)
	return ok
