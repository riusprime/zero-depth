extends GutTest
## v0.9.0 RB (owner, PLAN "Owner decisions" RB): the Wardrobe's choices in the profile (an old profile reads as Cream
## and None; locked robes stay locked until MP's hook unlocks them), the run locking its affinity (FloorPlan: the
## state on every floor, Storm's slower dash, Guardian's ward full again), and the run save keeping it (an old save:
## None; None writes no key, so a None run's payload is the payload before RB).

const PROFILE := "user://test_wardrobe_profile.json"

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func after_each() -> void:
	if FileAccess.file_exists(PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))


func test_an_old_profile_reads_as_cream_and_none() -> void:
	var f := FileAccess.open(PROFILE, FileAccess.WRITE)
	f.store_string(
		JSON.stringify(
			{"profile_version": 1, "settings": {}, "loadout": {"build": "gun"}, "unlocks": {}}
		)
	)
	f.close()
	var p := ProfileStore.open(PROFILE)
	assert_eq(Wardrobe.build_of(p), &"gun", "the build is kept")
	assert_eq(Wardrobe.robe_of(p), &"cream", "no robe yet: Cream")
	assert_eq(Wardrobe.affinity_of(p), &"none", "no affinity yet: None")
	assert_eq(Wardrobe.worn_robe(_repo, p).id, &"cream")
	assert_eq(Wardrobe.chosen_affinity(_repo, p), &"none")
	assert_eq(int(p.data["profile_version"]), ProfileStore.PROFILE_VERSION, "no version change")


func test_choices_survive_a_save_and_load() -> void:
	var p := ProfileStore.new(PROFILE)
	Wardrobe.set_robe(p, &"ash")
	Wardrobe.set_affinity(p, &"storm")
	assert_true(p.save_file())
	var q := ProfileStore.open(PROFILE)
	assert_eq(Wardrobe.worn_robe(_repo, q).id, &"ash")
	assert_eq(Wardrobe.chosen_affinity(_repo, q), &"storm")


func test_bought_robes_stay_locked_until_mp_unlocks_them() -> void:
	var p := ProfileStore.new("")
	var free := []
	for r: RobeDefinition in Wardrobe.robes(_repo):
		if Wardrobe.robe_unlocked(p, r):
			free.append(r.id)
	assert_eq(free, [&"cream", &"ash"], "Cream and Ash are free")
	Wardrobe.set_robe(p, &"night")
	assert_eq(Wardrobe.worn_robe(_repo, p).id, &"cream", "a locked robe isn't worn")
	Wardrobe.unlock_robe(p, &"night")
	assert_eq(Wardrobe.worn_robe(_repo, p).id, &"night", "MP's hook unlocks it")
	assert_eq(p.section("unlocks")["robes"], ["night"])


func test_an_unknown_affinity_reads_as_none() -> void:
	var p := ProfileStore.new("")
	Wardrobe.set_affinity(p, &"thunder")
	assert_eq(Wardrobe.chosen_affinity(_repo, p), &"none")


func _first_floor(aff: StringName) -> FloorPlan:
	var plan := FloorPlan.new_run(RunSaver.RUN_ID, 4242, &"gun", true, aff)
	plan.repo = _repo
	plan.build()
	return plan


func test_the_run_locks_its_affinity_and_builds_it_on_the_floor() -> void:
	var none := _first_floor(&"none")
	assert_null(none.world.affinity, "None: no state")
	var storm := _first_floor(&"storm")
	assert_eq(storm.run.affinity, &"storm", "locked into the run")
	assert_eq(storm.world.affinity.table.id, &"storm")
	assert_eq(
		none.world.player.dash_cooldown_ticks, SimTick.seconds_to_ticks(1.4), "the plain dash"
	)
	assert_eq(
		storm.world.player.dash_cooldown_ticks, SimTick.seconds_to_ticks(1.7), "Storm: 1.4 -> 1.7 s"
	)
	var guard := _first_floor(&"guardian")
	assert_eq(guard.world.affinity.ward, 1, "Guardian's ward up on floor 1")
	var next := FloorPlan.next_floor(guard.run, guard.run_biomes, {}, true)
	next.repo = _repo
	guard.run.floor_index = 2
	next.build()
	assert_eq(next.world.affinity.ward, 1, "and full again on the next floor")


func test_none_keeps_the_hash_of_a_run_without_rb() -> void:
	var before := _first_floor(&"")
	var none := _first_floor(&"none")
	assert_eq(none.world.state_hash(), before.world.state_hash(), "None is the game before RB")


func test_the_save_keeps_the_affinity_and_an_old_save_is_none() -> void:
	var plan := _first_floor(&"venom")
	var payload := RunSaver.payload_of(plan.world, plan.run, plan.stage_seed, PackedByteArray())
	assert_eq(payload["run"]["affinity"], "venom", "saved")
	var back := RunSaver.run_from(payload, plan.run.table)
	assert_eq(back.affinity, &"venom", "loaded back")
	var none := _first_floor(&"none")
	var p2 := RunSaver.payload_of(none.world, none.run, none.stage_seed, PackedByteArray())
	assert_false(
		(p2["run"] as Dictionary).has("affinity"), "None writes no key (the payload before RB)"
	)
	assert_eq(RunSaver.run_from(p2, none.run.table).affinity, &"", "an old payload: None")


func test_continue_rebuilds_the_saved_affinity() -> void:
	var plan := _first_floor(&"guardian")
	plan.world.affinity.ward = 0
	plan.world.affinity.ward_tick = 77
	var payload := RunSaver.payload_of(plan.world, plan.run, plan.stage_seed, PackedByteArray())
	payload["rooms"] = PackedByteArray()
	var cont := FloorPlan.continued(RunSaver.RUN_ID, payload, true)
	cont.repo = _repo
	cont.build()
	assert_eq(cont.err, "")
	assert_eq(cont.run.affinity, &"guardian", "Continue keeps the run's affinity")
	assert_eq(cont.world.affinity.ward, 0, "and the ward as it was saved")
	assert_eq(cont.world.affinity.ward_tick, 77)
	assert_eq(cont.world.state_hash(), plan.world.state_hash(), "the saved floor, exactly")
