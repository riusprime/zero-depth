extends GutTest
## The sim's designer numbers as content (docs/tools/DEV_PANEL.md Step 6): the shipped data/tuning/sim.tres compiles to
## exactly the old constants (so the game and its goldens are unchanged).


func test_the_shipped_file_is_the_old_constants() -> void:
	var repo := ContentRepository.load_all()
	var def: SimTuningDefinition = repo.get_def(&"tuning", &"sim")
	assert_not_null(def, "data/tuning/sim.tres is content")
	var got := RunContentCompiler.compile_sim_tuning(def)
	var want := SimTuning.new()
	for p: Dictionary in want.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_eq(got.get(p["name"]), want.get(p["name"]), p["name"])
