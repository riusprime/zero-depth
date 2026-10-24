extends GutTest
## v0.9.0 MP (PLAN W49-W52, Q28; owner "void unlocked when traveling through a purple portal, lance is unlocked by
## default"; PD-06): the profile's Rune Fragments (banked, spent on the robes only), the profile's migration to
## version 2 (an old profile: 0 fragments, the Void locked), the Void out of every new run's offers until the profile
## has travelled through a Purple Portal (FloorPlan -> RunState.locked_cards -> World.locked_items), and the run save
## keeping the run's tally and locks (an old save: none, so its payload reads as before).

const PROFILE := "user://test_meta_progress_profile.json"

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func after_each() -> void:
	if FileAccess.file_exists(PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))


func _write(data: Dictionary) -> void:
	var f := FileAccess.open(PROFILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func test_the_content_is_valid_and_sideways() -> void:
	var d := MetaProgress.definition(_repo)
	assert_not_null(d, "data/meta/rune_fragments.tres")
	if d == null:
		return
	assert_eq(d.validate().size(), 0, "valid")
	assert_eq(
		d.portal_unlocks, [&"gun_void"] as Array[StringName], "only the Void waits for the portal"
	)
	assert_not_null(_repo.get_def(&"modifiers", &"gun_void"), "the Void's card exists")
	var wares := MetaProgress.wares(_repo)
	var ids: Array = wares.map(func(r: RobeDefinition) -> StringName: return r.id)
	assert_eq(
		ids,
		[&"night", &"canyon", &"frost", &"moss"],
		"the station sells the four robes, nothing else"
	)
	for r: RobeDefinition in wares:
		assert_gt(r.price, 0, "%s has a price" % r.id)
		assert_eq(r.validate().size(), 0)


func test_a_fresh_profile_has_nothing_and_the_void_locked() -> void:
	var p := ProfileStore.new("")
	assert_eq(int(p.data["profile_version"]), ProfileStore.PROFILE_VERSION)  # v0.9.0 CL: 3
	assert_eq(MetaProgress.fragments(p), 0)
	assert_false(MetaProgress.portal_travelled(p))
	assert_eq(MetaProgress.locked_cards(_repo, p), [&"gun_void"] as Array[StringName])
	assert_true(MetaProgress.travel_portal(p), "the first travel unlocks")
	assert_false(MetaProgress.travel_portal(p), "once")
	assert_eq(MetaProgress.locked_cards(_repo, p).size(), 0, "nothing locked after it")


func test_banking_and_buying_a_robe() -> void:
	var p := ProfileStore.new("")
	var night: RobeDefinition = _repo.get_def(&"robe", &"night")
	var ash: RobeDefinition = _repo.get_def(&"robe", &"ash")
	assert_false(MetaProgress.buy_robe(p, night), "too dear with 0")
	assert_false(Wardrobe.robe_unlocked(p, night))
	MetaProgress.bank(p, night.price - 1)
	assert_false(MetaProgress.buy_robe(p, night), "one short")
	MetaProgress.bank(p, 0)
	MetaProgress.bank(p, -5)
	assert_eq(MetaProgress.fragments(p), night.price - 1, "0 and negatives bank nothing")
	MetaProgress.bank(p, 3)
	assert_true(MetaProgress.buy_robe(p, night), "bought")
	assert_true(Wardrobe.robe_unlocked(p, night), "through Wardrobe.unlock_robe")
	assert_eq(MetaProgress.fragments(p), 2, "the price spent")
	assert_eq(MetaProgress.earned(p), night.price + 2, "the lifetime count keeps everything banked")
	assert_false(MetaProgress.buy_robe(p, night), "never twice")
	assert_false(MetaProgress.buy_robe(p, ash), "a free robe isn't sold")
	assert_eq(MetaProgress.fragments(p), 2)


func test_a_version_1_profile_migrates_with_nothing() -> void:
	_write(
		{
			"profile_version": 1,
			"settings": {"shake": "off"},
			"loadout": {"robe": "ash"},
			"unlocks": {"robes": ["frost"]},
		}
	)
	var p := ProfileStore.open(PROFILE)
	assert_eq(int(p.data["profile_version"]), ProfileStore.PROFILE_VERSION, "now version 2")
	assert_eq(MetaProgress.fragments(p), 0, "0 Rune Fragments")
	assert_false(
		MetaProgress.portal_travelled(p), "the Void locked until a Purple Portal (default: locked)"
	)
	assert_eq(String(p.section("settings").get("shake")), "off", "the rest is kept")
	assert_eq(Wardrobe.robe_of(p), &"ash")
	assert_true(Wardrobe.robe_unlocked(p, _repo.get_def(&"robe", &"frost")), "and its unlocks")


func test_a_version_2_profile_round_trips() -> void:
	var p := ProfileStore.new(PROFILE)
	MetaProgress.bank(p, 17)
	MetaProgress.travel_portal(p)
	assert_true(p.save_file())
	var back := ProfileStore.open(PROFILE)
	assert_eq(MetaProgress.fragments(back), 17)
	assert_eq(MetaProgress.earned(back), 17)
	assert_true(MetaProgress.portal_travelled(back))


func _void_idx(w: World) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == &"gun_void":
			return k
	return -1


func _first_floor(profile: ProfileStore) -> FloorPlan:
	var plan := FloorPlan.of_profile(RunSaver.RUN_ID, 4242, profile, true)
	plan.repo = _repo
	plan.build()
	return plan


func test_a_new_run_locks_the_void_until_the_portal() -> void:
	var p := ProfileStore.new("")
	p.section("loadout")["build"] = "gun"
	var locked := _first_floor(p)
	var idx := _void_idx(locked.world)
	assert_gte(idx, 0, "the Void is compiled")
	assert_eq(
		locked.run.locked_cards, [&"gun_void"] as Array[StringName], "the run starts with it locked"
	)
	assert_eq(locked.world.locked_items, PackedInt32Array([idx]), "the floor knows its index")
	assert_false(ItemPool.usable(locked.world, idx), "no offer can draw it")
	assert_false(ItemPool.available(locked.world, true).has(idx), "out of the pool")
	assert_not_null(locked.run.fragment_table, "the run earns fragments")
	MetaProgress.travel_portal(p)
	var open := _first_floor(p)
	assert_eq(open.run.locked_cards.size(), 0, "a profile that travelled: nothing locked")
	assert_eq(open.world.locked_items.size(), 0)
	assert_true(ItemPool.usable(open.world, idx), "the Void back in the pool on a Gun run")
	# The next floor follows the run's locks (emptied by the portal: MetaHooks.travelled_portal).
	locked.run.locked_cards.clear()
	locked.run.floor_index = 2
	var next := FloorPlan.next_floor(locked.run, locked.run_biomes, {}, true)
	next.repo = _repo
	next.build()
	assert_eq(next.world.locked_items.size(), 0, "unlocked from the next floor on")


func test_a_plain_new_run_locks_nothing_so_goldens_keep_their_hash() -> void:
	var plan := FloorPlan.new_run(RunSaver.RUN_ID, 4242, &"gun", true)
	plan.repo = _repo
	plan.build()
	assert_eq(plan.world.locked_items.size(), 0, "no profile: nothing locked (goldens, sims)")


func test_the_run_save_keeps_the_tally_and_the_locks() -> void:
	var p := ProfileStore.new("")
	var plan := _first_floor(p)
	plan.run.fragments_done = 9
	var payload := RunSaver.payload_of(plan.world, plan.run, 4242, PackedByteArray())
	assert_eq(int(payload["run"]["fragments"]), 9)
	var back := SaveLab.run_from(payload)
	assert_eq(back.fragments_done, 9, "the tally")
	assert_eq(back.locked_cards, [&"gun_void"] as Array[StringName], "the locks")
	plan.run.fragments_done = 0
	plan.run.locked_cards.clear()
	var bare := RunSaver.payload_of(plan.world, plan.run, 4242, PackedByteArray())
	assert_false((bare["run"] as Dictionary).has("fragments"), "none: no key, as before MP")
	assert_false((bare["run"] as Dictionary).has("locked"), "none: no key")
	var old := SaveLab.run_from(bare)
	assert_eq(old.fragments_done, 0, "an older payload earned none")
	assert_eq(old.locked_cards.size(), 0, "and locks nothing")
