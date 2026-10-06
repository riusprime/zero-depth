extends GutTest


func test_tap_between_ticks_is_delivered_once() -> void:
	var latch := InputLatch.new()
	latch.note_pressed(InputFrame.DASH)
	latch.note_released(InputFrame.DASH)
	var f1 := latch.close_frame(Vector2.ZERO, Vector2.RIGHT, 1.0)
	var f2 := latch.close_frame(Vector2.ZERO, Vector2.RIGHT, 1.0)
	assert_eq(f1.pressed & InputFrame.DASH, InputFrame.DASH)
	assert_eq(f1.held & InputFrame.DASH, 0, "released before the tick")
	assert_eq(f2.pressed, 0, "delivered exactly once")


func test_rotation_table_from_sim_contracts() -> void:
	# SIM_CONTRACTS §3: W -> 1536, D -> 512, S -> 3584, A -> 2560.
	var table := {
		Vector2(0, 1): 1536, Vector2(1, 0): 512, Vector2(0, -1): 3584, Vector2(-1, 0): 2560
	}
	for screen: Vector2 in table:
		var q := InputLatch.quantize_move(InputLatch.screen_to_sim(screen))
		assert_eq(Kin.angle_of(Vector2(q.x, q.y)), table[screen], "screen %s" % screen)


func test_quantize_deadzone_and_clamp() -> void:
	assert_eq(InputLatch.quantize_move(Vector2(0.1, 0.0)), Vector2i.ZERO)
	assert_eq(InputLatch.quantize_move(Vector2(1.0, 0.0)), Vector2i(127, 0))
	var diag := InputLatch.quantize_move(Vector2(1.0, 1.0))
	assert_eq(diag, Vector2i(90, 90), "length clamped to 1")
