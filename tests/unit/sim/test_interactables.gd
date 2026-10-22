extends GutTest
## v0.9.0 IX (owner W34: "Build reusable Godot components so the same interaction logic can support different visual
## models and room layouts"): the shared interactable registry (Interactables). The press goes to the nearest enabled
## entry in its reach (the lowest id on a tie), disabled and far ones take none, the final approach's pylons run on it
## (one press each, the prompt key the shared HUD shows), and its state rides the snapshot (a save from before IX, with
## no registry, still resumes with its lit pylons).

const SEED := 20261022


func _press() -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT)


func test_the_nearest_enabled_entry_in_reach_lowest_id_on_a_tie() -> void:
	var r := Interactables.new()
	var a := r.add(Interactables.Kind.PYLON, Vector2(2, 0), 2.0, 0)
	var b := r.add(Interactables.Kind.PYLON, Vector2(-2, 0), 2.0, 1)
	var c := r.add(Interactables.Kind.PYLON, Vector2(0, 1), 2.0, 2)
	assert_eq(r.ids, PackedInt32Array([1, 2, 3]), "ids ascend")
	assert_eq(r.in_reach(Vector2.ZERO), c, "the nearest")
	r.enabled[c] = 0
	assert_eq(r.in_reach(Vector2.ZERO), a, "a tie: the lowest id")
	r.enabled[a] = 0
	assert_eq(r.in_reach(Vector2.ZERO), b, "disabled ones take none")
	assert_eq(r.in_reach(Vector2(10, 0)), -1, "out of reach: none")
	assert_eq(r.find(Interactables.Kind.PYLON, 1), b)
	assert_eq(r.find(Interactables.Kind.PYLON, 9), -1)


func test_a_world_without_interactables_hashes_as_before() -> void:
	var w := FinalLab.approach(FinalLab.run_state(SEED))
	var h := w.state_hash()
	w.interactables.press_tick[0] = 99
	assert_ne(w.state_hash(), h, "a world holding entries hashes them")
	var empty := Interactables.new()
	assert_true(empty.is_empty(), "an empty registry is left out of the hash")


func test_the_pylons_run_on_the_registry() -> void:
	var w := FinalLab.approach(FinalLab.run_state(SEED))
	w.actors.invuln[0] = 1 << 24
	var reader := WorldReader.new(w)
	assert_eq(w.interactables.size(), 2, "both pylons registered")
	assert_eq(reader.interact_prompt_key(), &"", "far from both: no prompt")
	w.actors.set_pos(0, w.floor_layout.pylons[1] + Vector2(0.5, 0))
	CombatLab.idle(w, 2)
	assert_eq(
		reader.interact_prompt_key(), &"APPROACH_PYLON_PROMPT", "the shared prompt by pylon B"
	)
	assert_eq(reader.approach_pylon_in_reach(), 1)
	w.step(_press())
	assert_true(reader.approach_pylon_lit(1), "the press lit it")
	var i := w.interactables.find(Interactables.Kind.PYLON, 1)
	assert_false(reader.interactable_enabled(i), "a lit one takes no more presses")
	assert_eq(reader.interactable_state(i), 1)
	assert_eq(reader.interactable_press_tick(i), w.tick - 1)
	assert_eq(reader.interact_prompt_key(), &"", "no prompt by a lit pylon")


func test_the_registry_rides_the_snapshot_and_an_old_save_resyncs() -> void:
	var w := FinalLab.approach(FinalLab.run_state(SEED))
	w.actors.invuln[0] = 1 << 24
	w.actors.set_pos(0, w.floor_layout.pylons[0] + Vector2(0.5, 0))
	CombatLab.idle(w, 2)
	w.step(_press())
	assert_true(w.approach.lit[0] == 1)
	var snap := WorldSnapshot.take(w)
	var base := FinalLab.approach(FinalLab.run_state(SEED))
	assert_eq(WorldSnapshot.apply(base, snap), "", "fits")
	assert_eq(base.state_hash(), w.state_hash(), "resumes exactly")
	var old := WorldSnapshot.take(w)
	(old["world"] as Dictionary).erase(&"interactables")  # a save from before IX
	var base2 := FinalLab.approach(FinalLab.run_state(SEED))
	assert_eq(WorldSnapshot.apply(base2, old), "", "an old save still resumes")
	var k := base2.interactables.find(Interactables.Kind.PYLON, 0)
	assert_eq(base2.interactables.enabled[k], 0, "its lit pylon takes no press")
	assert_eq(base2.interactables.enabled[1 - k], 1, "the other still does")
