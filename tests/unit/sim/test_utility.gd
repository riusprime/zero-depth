extends GutTest
## Guard and blink (PLAN v0.1.0 Step 3). Aim angle 0 = +x.

const U := InputFrame.UTILITY


func _world(kind: int) -> World:
	var t := PlayerTable.starting_values()
	t.utility = kind
	return World.new(5, t)


func _f(held: int = 0, pressed: int = 0, dist_cm: int = 1000, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, 0, dist_cm, held, pressed)


func test_guard_cuts_hits_from_the_front_only() -> void:
	var w := _world(PlayerTable.Utility.GUARD)
	w.step(_f(U, U))
	assert_true(w.guarding())
	assert_eq(Damage.hit(w, 0, 50, 9, 9, 9, 0, Vector2(3, 0), Vector2.ZERO), 10, "front: a fifth")
	w.actors.invuln[0] = 0
	assert_eq(Damage.hit(w, 0, 50, 9, 9, 9, 0, Vector2(-3, 0), Vector2.ZERO), 50, "behind: full")


func test_guard_slows_and_stops_attacks() -> void:
	var w := _world(PlayerTable.Utility.GUARD)
	var free := _world(PlayerTable.Utility.GUARD)
	for i in 30:
		w.step(_f(U, InputFrame.PRIMARY if i == 5 else 0, 1000, Vector2i(127, 0)))
		free.step(_f(0, 0, 1000, Vector2i(127, 0)))
	assert_almost_eq(w.player_pos().x, free.player_pos().x * 0.4, 0.05)
	assert_eq(w.swing_t, 0, "no swing while guarding")


func test_blink_follows_movement_not_the_aim() -> void:
	var w := _world(PlayerTable.Utility.BLINK)
	# Moving +x while aiming -x (angle 2048): the blink goes +x, its full 5 m.
	w.step(InputFrame.make(Vector2i(127, 0), 2048, 300, 0, U))
	assert_almost_eq(w.player_pos().x, 5.0 + w.player.move_speed, 0.01)
	assert_true(w.actors.invuln[0] > 0, "briefly invulnerable")


func test_standing_still_blinks_toward_the_aim_with_a_cooldown() -> void:
	var w := _world(PlayerTable.Utility.BLINK)
	w.step(_f(0, U, 300))
	assert_almost_eq(w.player_pos().x, 5.0, 0.01, "the full range, whatever the aim distance")
	w.step(_f(0, U))
	assert_almost_eq(w.player_pos().x, 5.0, 0.01, "still on cooldown")
	for i in w.player.blink_cooldown_ticks:
		w.step(_f())
	w.step(_f(0, U))
	assert_almost_eq(w.player_pos().x, 10.0, 0.01)


func test_blink_stops_before_a_wall() -> void:
	var w := _world(PlayerTable.Utility.BLINK)
	var walls: Array[Obb] = [Obb.make(Vector2(2.5, 0), Vector2(0.2, 3), 0)]
	w.set_walls(walls)
	w.step(_f(0, U, 500))
	assert_lt(w.player_pos().x, 2.3 - w.player.radius_m + 0.05)
	assert_gt(w.player_pos().x, 1.5)


func test_a_guard_player_cannot_blink() -> void:
	var w := _world(PlayerTable.Utility.GUARD)
	w.step(_f(0, U, 300))
	assert_eq(w.player_pos(), Vector2.ZERO)
