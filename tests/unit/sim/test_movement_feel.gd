extends GutTest
## Movement eases toward full speed and to a stop on a fast smooth curve (owner, 2026-10-07; PLAN L17).


func _speed(w: World, before: Vector2) -> float:
	return (w.player_pos() - before).length()


func test_reaches_top_speed_fast_but_not_instantly() -> void:
	var w := World.new(1, PlayerTable.starting_values())
	var top := w.player.move_speed
	var go := InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0)
	var p := w.player_pos()
	w.step(go)
	var first := _speed(w, p)
	assert_between(first, top * 0.2, top * 0.5, "the first tick is a fast start, not full speed")
	for i in 4:
		w.step(go)
	p = w.player_pos()
	w.step(go)
	assert_gte(_speed(w, p), top * 0.9, "90% of top speed by 0.1 s")


func test_stops_fast_and_smoothly() -> void:
	var w := World.new(1, PlayerTable.starting_values())
	var top := w.player.move_speed
	for i in 30:
		w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0))
	var p := w.player_pos()
	w.step(InputFrame.new())
	var first := _speed(w, p)
	assert_between(first, top * 0.4, top * 0.75, "the first tick of a stop still slides a little")
	for i in 4:
		w.step(InputFrame.new())
	p = w.player_pos()
	w.step(InputFrame.new())
	assert_lte(_speed(w, p), top * 0.1, "under 10% after 5 ticks (0.08 s)")


func test_the_compiled_player_has_the_bigger_bolt_hitbox() -> void:
	var t := ContentCompiler.compile_player(
		ContentRepository.load_all().get_def(&"player", &"runner")
	)
	assert_almost_eq(t.bolt_radius_m, 0.16, 0.0001)
	assert_eq(t.accel_permille, 319)
	assert_eq(t.decel_permille, 369)
