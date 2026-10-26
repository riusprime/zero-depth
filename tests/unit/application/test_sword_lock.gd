extends GutTest
## v0.9.5 SL (G11, owner Q15 a): the Blade is locked for every profile until the "Sword Unbound" achievement (the
## Hollow Crown beaten with the Gun). Locked on a new profile, unlocked by the achievement, kept through save and load,
## locked on an old profile, and earned only by a Gun win.

const LONG := 1 << 24


func _parts() -> Dictionary:
	var profile := ProfileStore.new("")
	var codex := CodexStore.new(profile)
	var store := AchievementStore.new(profile)
	var repo := ContentRepository.load_all()
	var book := AchievementBook.build(repo, store, codex, CodexCatalog.build(repo))
	return {"profile": profile, "tracker": AchievementTracker.new(book), "store": store}


func _beat_body(t: AchievementTracker, w: World, r: WorldReader) -> void:
	FinalLab.past_rise(w)
	t.observe(r)
	FinalLab.hit(w, w.actors.hp[FinalLab.body(w)] * 10)
	for k in 200:
		w.step(InputFrame.new())
		t.observe(r)
		if not FinalBoss.shattering(w):
			break
	for k in 4:
		w.step(InputFrame.new())
		t.observe(r)


func _win(p: Dictionary, build: StringName) -> void:
	var t: AchievementTracker = p["tracker"]
	var w := FinalLab.arena(FinalLab.run_state(131, build, 1))
	w.actors.invuln[0] = LONG
	var r := WorldReader.new(w)
	t.attach(r)
	_beat_body(t, w, r)
	_beat_body(t, w, r)
	FinalLab.past_rise(w)
	FinalLab.hit(w, w.actors.hp[FinalLab.body(w)] * 10)
	for k in 2:
		w.step(InputFrame.new())
		t.observe(r)
	assert_eq(r.outcome(), 1, "the run was won")


func test_a_new_profile_has_the_blade_locked() -> void:
	var profile := ProfileStore.new("")
	assert_false(SwordLock.is_unlocked(profile))
	assert_eq(SwordLock.locked_builds(profile), {&"blade": SwordLock.CONDITION_KEY})
	assert_eq(Wardrobe.build_of(profile), &"gun", "the default falls back to the Gun")


func test_the_remembered_blade_falls_back_to_the_gun_while_locked() -> void:
	var profile := ProfileStore.new("")
	profile.section("loadout")["build"] = "blade"
	assert_eq(Wardrobe.build_of(profile), &"gun")
	SwordLock.grant(profile)
	assert_eq(Wardrobe.build_of(profile), &"blade", "unlocked: the remembered pick holds")
	assert_true(SwordLock.locked_builds(profile).is_empty())


func test_the_achievement_is_defined_and_valid() -> void:
	var d := ContentRepository.load_all().get_def(&"achievements", &"sword_unbound")
	assert_not_null(d)
	assert_eq((d as AchievementDefinition).problems().size(), 0)
	assert_eq((d as AchievementDefinition).stat, &"final:won_gun")


func test_a_gun_win_over_the_hollow_crown_unlocks_the_blade() -> void:
	var p := _parts()
	_win(p, &"gun")
	assert_true((p["store"] as AchievementStore).is_unlocked(&"sword_unbound"))
	assert_true(SwordLock.is_unlocked(p["profile"]))


func test_a_blade_win_does_not_unlock_it() -> void:
	var p := _parts()
	_win(p, &"blade")
	assert_eq((p["store"] as AchievementStore).stat(&"final:won"), 1)
	assert_false(SwordLock.is_unlocked(p["profile"]), "only a Gun win counts")


func test_dying_in_the_arena_does_not_unlock_it() -> void:
	var p := _parts()
	var t: AchievementTracker = p["tracker"]
	var w := FinalLab.arena(FinalLab.run_state(131, &"gun", 1))
	var r := WorldReader.new(w)
	t.attach(r)
	FinalLab.past_rise(w)
	w.actors.hp[0] = 0
	for k in 10:
		w.step(InputFrame.new())
		t.observe(r)
	assert_false(SwordLock.is_unlocked(p["profile"]))


func test_the_unlock_survives_save_and_load() -> void:
	var path := "user://sword_lock_test.json"
	var profile := ProfileStore.new(path)
	SwordLock.grant(profile)
	assert_true(profile.save_file())
	var again := ProfileStore.new(path)
	assert_true(again.load_file())
	assert_true(SwordLock.is_unlocked(again))
	DirAccess.remove_absolute(path)


func test_an_old_profile_without_the_section_loads_locked() -> void:
	var path := "user://sword_lock_old.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"version": 1, "settings": {}, "loadout": {"build": "blade"}}')
	f.close()
	var old := ProfileStore.new(path)
	old.load_file()
	assert_false(SwordLock.is_unlocked(old))
	assert_eq(Wardrobe.build_of(old), &"gun")
	DirAccess.remove_absolute(path)
