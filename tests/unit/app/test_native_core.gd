extends GutTest
## The native core is the game's default (NativeSwitch.install_for_game): every kernel on when nothing asks
## otherwise, given back when Main leaves; the dev panel's switch changes the kernels of the next World only; and a
## run saved under one sim resumes under the other, since the native side holds only caches and every hashed column
## is GDScript's. Without the library (a checkout that hasn't run scripts/native/build.sh) the tests that need it
## are pending.

const SAVE_TICKS := 240
const RESUMED_TICKS := 600

var _kept := Callable()
var _kept_kernels := 0
var _kept_core := 0


func before_all() -> void:
	_kept = World.native_factory
	_kept_kernels = World.native_kernels
	_kept_core = NativeSwitch.core_kernels


func after_all() -> void:
	World.native_factory = _kept
	World.native_kernels = _kept_kernels
	NativeSwitch.core_kernels = _kept_core
	DebugApi.view_switches.erase(NativeSwitch.SWITCH)


func test_the_game_asks_for_every_kernel_unless_told_otherwise() -> void:
	assert_eq(NativeSwitch.parse("none"), 0, "--native=none")
	assert_eq(NativeSwitch.parse("0"), 0, "--native=0")
	if NativeSwitch.asked():
		pending("this run's command line or environment names kernels")
		return
	assert_eq(NativeSwitch.for_game(), NativeWorld.ALL)
	assert_eq(NativeSwitch.requested(), 0, "the tools' default stays the script sim")


func test_the_game_start_installs_the_core_and_gives_back_the_switch_it_found() -> void:
	NativeSwitch.install(0)
	var main := Node.new()
	add_child(main)
	var on := NativeSwitch.install_for_game(main)
	if not NativeSwitch.available():
		assert_eq(on, 0, "no library: the script sim, silently")
		assert_false(DebugApi.view_switches.has(NativeSwitch.SWITCH), "no switch to show")
		remove_child(main)
		main.free()
		return
	if not NativeSwitch.asked():
		assert_eq(on, NativeWorld.ALL, "every kernel at the game's start")
	assert_eq(World.new(9, PlayerTable.starting_values()).native_on, on)
	assert_true(DebugApi.view_switches.has(NativeSwitch.SWITCH), "the dev panel has the switch")
	remove_child(main)
	main.free()
	assert_eq(World.native_kernels, 0, "Main gone: back to what was installed before")
	assert_false(World.native_factory.is_valid())
	assert_false(DebugApi.view_switches.has(NativeSwitch.SWITCH))
	assert_null(World.new(9, PlayerTable.starting_values()).native, "a later World: the script sim")


func test_the_dev_panel_switch_changes_the_next_world_only() -> void:
	if not _built():
		return
	NativeSwitch.core_kernels = NativeWorld.ALL
	NativeSwitch.install(NativeWorld.ALL)
	var live := World.new(9, PlayerTable.starting_values())
	assert_eq(
		DevPanel.native_text(live.native_on, World.native_kernels),
		"native core: move,ai,strike,shots,nav"
	)
	NativeSwitch.flip_core()
	assert_false(NativeSwitch.core_on(), "off")
	assert_eq(live.native_on, NativeWorld.ALL, "the live world keeps its kernels")
	assert_not_null(live.native)
	assert_eq(
		DevPanel.native_text(live.native_on, World.native_kernels),
		"native core: move,ai,strike,shots,nav  ->  off (script sim) from the next floor or run"
	)
	var next := World.new(9, PlayerTable.starting_values())
	assert_eq(next.native_on, 0, "the next world runs the script sim")
	assert_null(next.native)
	NativeSwitch.flip_core()
	assert_eq(World.native_kernels, NativeWorld.ALL, "on again: the set the game started with")
	assert_eq(World.new(9, PlayerTable.starting_values()).native_on, NativeWorld.ALL)


func test_a_save_made_native_resumes_on_the_script_sim() -> void:
	if not _built():
		return
	_cross_resume(NativeWorld.ALL, 0)


func test_a_save_made_on_the_script_sim_resumes_native() -> void:
	if not _built():
		return
	_cross_resume(0, NativeWorld.ALL)


## Plays a floor under `saved_with`, saves at a room's first entry (the game's RunSaver and store, encoded), then
## resumes it under `resumed_with`: the snapshot applies, the hashed state is the saved one, and the run goes on.
func _cross_resume(saved_with: int, resumed_with: int) -> void:
	NativeSwitch.install(saved_with)
	var run := SaveLab.run_state(31, 1)
	var w := SaveLab.build_floor(run)
	assert_eq(w.native_on, saved_with)
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
	NativeSwitch.install(resumed_with)
	var base := SaveLab.build_floor(RunSaver.run_from(saved, run.table))
	assert_eq(base.native_on, resumed_with, "the resumed world runs the other sim")
	var r := World.from_snapshot(saved["world"], base)
	assert_not_null(r, "the save applies")
	if r == null:
		return
	assert_eq(r.state_hash(), h, "the same hashed state: the native side is caches only")
	var t := r.tick
	var bot2 := FightBot.new(3)
	for i in RESUMED_TICKS:
		r.step(SaveLab.frame(r, bot2))
	assert_eq(r.tick, t + RESUMED_TICKS, "the resumed world steps")
	for i in r.actors.size():
		assert_true(
			is_finite(r.actors.pos_x[i]) and is_finite(r.actors.pos_y[i]),
			"actor %d stands somewhere real" % i
		)


func _built() -> bool:
	if NativeSwitch.available():
		return true
	if OS.get_environment("ZD_NATIVE_REQUIRED") == "1":
		fail_test("ZD_NATIVE_REQUIRED=1, but the native library did not load")
		return false
	pending("the native library is not built (native/README.md)")
	return false
