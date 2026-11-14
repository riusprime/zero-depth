extends GutTest
## The native core is the only sim (NativeWorld): every World made anywhere gets its native side, and a run saved
## through the game's real save path (RunSaver and its store, encoded) resumes into the same hashed state and goes on
## exactly as the run that was never saved, since the native side holds only caches and every hashed column is
## GDScript's. (A GUT run without the library stops before its first test: tests/support/native_required_hook.gd.)

const SAVE_TICKS := 240
const RESUMED_TICKS := 600


func test_every_world_has_its_native_side() -> void:
	assert_true(NativeWorld.available(), "the library is loaded")
	var w := World.new(9, PlayerTable.starting_values())
	assert_not_null(w.native, "a World made directly")
	assert_true(w.native.has_trig(), "with the direction tables sent")


func test_a_field_of_its_own_floods_on_its_own_native_side() -> void:
	var walls: Array[Obb] = [
		Obb.make(Vector2(0, -5), Vector2(5, 0.25), 0), Obb.make(Vector2(0, 5), Vector2(5, 0.25), 0)
	]
	var f := NavField.new()
	f.build(walls)
	f.flood(Vector2.ZERO)
	var c := f.cell_of(Vector2(2, 1))
	assert_lt(f.dist[c.y * f.size.x + c.x], NavField.UNREACHED, "a cell near the goal is reached")


func test_a_saved_run_resumes_and_goes_on_as_the_run_that_was_not_saved() -> void:
	var run := SaveLab.run_state(31, 1)
	var w := SaveLab.build_floor(run)
	var saver := RunSaver.new(RunSaveStore.new(""))
	saver.begin_floor(w, run, 11)
	var bot := FightBot.new(3)
	for i in SAVE_TICKS:
		w.step(SaveLab.frame(w, bot))
		saver.after_tick(w, run, 11)
	var f := w.floor_layout
	w.actors.set_pos(0, f.rooms[f.neighbours(f.start_room)[0]].get_center())
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())
	var h := w.state_hash()
	assert_true(saver.after_tick(w, run, 11), "a first entry saves mid-run")
	var saved := saver.store.read()
	assert_false(saved.is_empty(), "the save reads back")
	var base := SaveLab.build_floor(RunSaver.run_from(saved, run.table))
	var r := World.from_snapshot(saved["world"], base)
	assert_not_null(r, "the save applies")
	if r == null:
		return
	assert_eq(r.state_hash(), h, "the same hashed state: the native side is caches only")
	var bot_a := FightBot.new(5)
	var bot_b := FightBot.new(5)
	for i in RESUMED_TICKS:
		w.step(SaveLab.frame(w, bot_a))
		r.step(SaveLab.frame(r, bot_b))
		if i % 60 == 59:
			assert_eq(r.state_hash(), w.state_hash(), "the same state %d ticks on" % (i + 1))
