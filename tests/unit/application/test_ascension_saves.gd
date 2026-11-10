extends GutTest
## Saves and the Ascension loop. A run in loop 2 round-trips through the payload (`loop`, `loop_floors`) and its floor
## resumes to the same state hash; a world snapshot without the loop or Ascension fields restores with the base world's
## values.


func _run_table() -> RunTable:
	return ContentCompiler.compile_run(SharedContent.repo().get_def(&"run", SaveLab.RUN_ID))


## A run moved into loop 2's floor 1 the way finish_floor moves it (the Loop device from the last floor, v0.9.0 FV:
## floor 5; Ascend before P2).
func _loop_two_run(run_seed: int) -> RunState:
	var run := SaveLab.run_state(run_seed, SaveLab.floors())
	var w := SaveLab.build_floor(run)
	w.boss_flow.ascend_choice = Ascension.Choice.LOOP
	run.finish_floor(w)
	return run


func test_a_loop_two_run_round_trips_through_the_payload() -> void:
	var run := _loop_two_run(321)
	assert_eq(run.loop, 2)
	var w := SaveLab.build_floor(run)
	CombatLab.idle(w, 30)
	var bytes := RunSaveStore.encode(RunSaver.payload_of(w, run, 99, PackedByteArray([1])))
	var got := RunSaveStore.decode(bytes)
	assert_eq(got[1], "", "it decodes")
	var p: Dictionary = (got[0] as Dictionary)["payload"]
	assert_true(RunSaver.is_usable(p))
	assert_eq(int(p["version"]), RunSaver.PAYLOAD_VERSION)
	var back := RunSaver.run_from(p, _run_table())
	assert_eq(back.loop, 2, "the loop comes back")
	assert_eq(back.loop_floors, 5)
	assert_eq(back.floor_index, 1)
	assert_eq(back.run_floor(), 6)
	assert_eq(back.biome_order, run.biome_order, "with the loop's biomes")
	assert_eq(back.floor_seed(), run.floor_seed())
	var w2 := SaveLab.build_floor(back)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "the snapshot fits the rebuilt floor")
	assert_eq(w2.loop, 2)
	assert_eq(w2.state_hash(), w.state_hash(), "Continue resumes the same loop-2 state")


func test_an_older_last_floor_save_resumes_with_the_ascension_portal() -> void:
	var run := SaveLab.run_state(77, SaveLab.floors())
	var w := SaveLab.build_floor(run)
	CombatLab.idle(w, 20)
	var p := RunSaver.payload_of(w, run, 77, PackedByteArray())
	var snap: Dictionary = p["world"]["world"]
	for f in [&"loop", &"run_floor", &"loop_threat", &"loop_cap_permille"]:
		snap.erase(f)
	var flow: Dictionary = snap[&"boss_flow"]
	for f in [&"ascension", &"ascend_open", &"ascend_declined", &"ascend_choice"]:
		flow.erase(f)
	var back := RunSaver.run_from(p, _run_table())
	var w2 := SaveLab.build_floor(back)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "a snapshot without the AP fields restores")
	assert_true(w2.boss_flow.ascension, "the last floor gets the Ascension portal")
	assert_true(w2.floor_layout.has_loop_device, "v0.8.0 P2: and the Loop device beside it")
	assert_eq(w2.state_hash(), w.state_hash(), "and the same state")


## v0.8.0 P2 (owner O28): a last-floor save made before P2 (its snapshot holds the retired choice's fields, and the
## device taken in the old numbers) restores onto the rebuilt floor, Loop device and all; Ascend's old number is the
## Loop device's.
func test_p2_a_last_floor_save_from_before_p2_restores_with_the_two_devices() -> void:
	var run := SaveLab.run_state(78, SaveLab.floors())
	var w := SaveLab.build_floor(run)
	CombatLab.idle(w, 20)
	var p := RunSaver.payload_of(w, run, 78, PackedByteArray())
	var flow: Dictionary = p["world"]["world"][&"boss_flow"]
	assert_true(flow.has(&"ascend_open"), "the retired fields are still saved")
	flow[&"ascend_choice"] = 2  # v0.7.5's Ascend
	var back := RunSaver.run_from(p, _run_table())
	var w2 := SaveLab.build_floor(back)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "it restores")
	assert_true(w2.floor_layout.has_loop_device)
	assert_eq(
		WorldReader.new(w2).ascension_choice(),
		WorldReader.ASCEND_LOOP,
		"Ascend reads as the Loop device"
	)
