class_name E2e
extends RefCounted
## Drives the real game the way a player does: Input.parse_input_event, then flush, then wait for physics
## frames (TEST_MATRIX T-E2E). No calls into game objects to make things happen; reads are fine.

var test: GutTest
var main: Main


func _init(p_test: GutTest) -> void:
	test = p_test


## Boots main.tscn with a memory-only profile (optionally pre-filled) and waits for the menu.
func boot(profile: ProfileStore = null) -> Main:
	ProfileStore.use_shared(profile if profile != null else ProfileStore.new(""))
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


## Play from the main menu with the keyboard: the Play button has focus.
func start_from_menu() -> void:
	await tap(KEY_ENTER)
	await frames(2)


func world() -> World:
	return main.driver.world if main.driver != null else null
