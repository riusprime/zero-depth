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


func test_quantize_curve_and_clamp() -> void:
	# The actions' dead zone already ran (Input.get_vector); the latch adds no second one.
	assert_eq(InputLatch.quantize_move(Vector2.ZERO), Vector2i.ZERO)
	assert_gt(
		InputLatch.quantize_move(Vector2(0.1, 0.0)).x, 0, "a light tilt past the dead zone moves"
	)
	assert_eq(InputLatch.quantize_move(Vector2(InputLatch.FULL_TILT * 0.5, 0.0)), Vector2i(64, 0))
	assert_eq(
		InputLatch.quantize_move(Vector2(InputLatch.FULL_TILT, 0.0)), Vector2i(127, 0), "full speed"
	)
	assert_eq(InputLatch.quantize_move(Vector2(1.0, 0.0)), Vector2i(127, 0))
	var diag := InputLatch.quantize_move(Vector2(1.0, 1.0))
	assert_eq(diag, Vector2i(90, 90), "length clamped to 1")


func test_wand_moves_queue_one_per_frame_in_order_after_a_latched_pick() -> void:
	# v0.6.5 WN2: the Build page's and the Swap's moves wait in the latch and reach the sim one per tick, in order.
	var latch := InputLatch.new()
	latch.note_pick(InputFrame.PICK_SWAP_BASE + 2)  # a pick latched first goes first
	latch.queue_wand_move(InputFrame.wand_move(0, 2))
	latch.queue_wand_move(InputFrame.wand_move(3, 1))
	latch.note_pick(InputFrame.PICK_SWAP_SKIP)  # a pick noted while moves wait goes after them
	assert_eq(
		latch.pending_picks(),
		PackedInt32Array(
			[
				InputFrame.PICK_SWAP_BASE + 2,
				InputFrame.wand_move(0, 2),
				InputFrame.wand_move(3, 1),
				InputFrame.PICK_SWAP_SKIP
			]
		)
	)
	var got := []
	for k in 5:
		got.append(latch.close_frame(Vector2.ZERO, Vector2.RIGHT, 1.0).pick)
	assert_eq(
		got,
		[
			InputFrame.PICK_SWAP_BASE + 2,
			InputFrame.wand_move(0, 2),
			InputFrame.wand_move(3, 1),
			InputFrame.PICK_SWAP_SKIP,
			InputFrame.PICK_NONE
		]
	)
	assert_eq(latch.pending_picks().size(), 0)


func test_presses_from_a_paused_menu_can_be_dropped() -> void:
	var latch := InputLatch.new()
	latch.note_pressed(InputFrame.PRIMARY)
	latch.note_released(InputFrame.PRIMARY)
	latch.drop_presses()
	var f := latch.close_frame(Vector2.ZERO, Vector2.RIGHT, 1.0)
	assert_eq(f.pressed, 0, "a click on the Build page is not a swing")
	assert_eq(f.held, 0)
