extends GutTest
## v0.7.5 AP: saves and the Ascension loop. A run in loop 2 round-trips through the payload (`loop`, `loop_floors`)
## and its floor resumes to the same state hash; a payload recorded before AP (tests/fixtures/saves/, v0.6.1's own
## code, payload 3, no loop keys) loads as loop 1, and its world snapshot (no loop or Ascension fields) restores with
## the base world's values.

const DIR := "res://tests/fixtures/saves/"


func _run_table() -> RunTable:
	return ContentCompiler.compile_run(ContentRepository.load_all().get_def(&"run", SaveLab.RUN_ID))


## A run moved into loop 2's floor 1 the way finish_floor moves it (an Ascend from floor 3).
func _loop_two_run(run_seed: int) -> RunState:
	var run := SaveLab.run_state(run_seed, 3)
	var w := SaveLab.build_floor(run)
	w.boss_flow.ascend_choice = Ascension.Choice.ASCEND
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
	assert_eq(int(p["version"]), RunSaver.PAYLOAD_VERSION, "no version bump")
	var back := RunSaver.run_from(p, _run_table())
	assert_eq(back.loop, 2, "the loop comes back")
	assert_eq(back.loop_floors, 3)
	assert_eq(back.floor_index, 1)
	assert_eq(back.run_floor(), 4)
	assert_eq(back.biome_order, run.biome_order, "with the loop's biomes")
	assert_eq(back.floor_seed(), run.floor_seed())
	var w2 := SaveLab.build_floor(back)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "the snapshot fits the rebuilt floor")
	assert_eq(w2.loop, 2)
	assert_eq(w2.state_hash(), w.state_hash(), "Continue resumes the same loop-2 state")


func test_an_older_payload_is_loop_one() -> void:
	var r := RunSaveStore.decode(FileAccess.get_file_as_bytes(DIR + "v061_gun_floor2.save"))
	assert_eq(r[1], "")
	var p: Dictionary = (r[0] as Dictionary)["payload"]
	assert_false((p["run"] as Dictionary).has("loop"), "recorded before AP")
	var run := RunSaver.run_from(p, _run_table())
	assert_eq(run.loop, 1, "an older save is loop 1")
	assert_eq(run.loop_floors, 0)
	assert_eq(run.run_floor(), run.floor_index)
	var w := SaveLab.build_floor(run)
	assert_eq(WorldSnapshot.apply(w, p["world"]), "", "its snapshot still restores")
	assert_eq(w.loop, 1, "the world keeps the base's loop")
	assert_false(w.boss_flow.ascension, "floor 2 has the gate")


func test_an_older_last_floor_save_resumes_with_the_ascension_portal() -> void:
	var run := SaveLab.run_state(77, 3)
	var w := SaveLab.build_floor(run)
	CombatLab.idle(w, 20)
	var p := RunSaver.payload_of(w, run, 77, PackedByteArray())
	(p["run"] as Dictionary).erase("loop")  # as a payload written before AP
	(p["run"] as Dictionary).erase("loop_floors")
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
	assert_eq(w2.state_hash(), w.state_hash(), "and the same state")
