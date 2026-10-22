extends GutTest
## v0.8.0 FB1 (FINAL_BOSS.md F8): the final boss's three achievements, recorded by the AchievementTracker from a real
## final arena (FinalLab): Crown Breaker (beat it), Untouched (a body beaten without being hit), Beyond the Loop (beat
## it after an Ascension loop). The arena's win doesn't count its floor cleared a second time.

const LONG := 1 << 24


func _parts() -> Dictionary:
	var profile := ProfileStore.new("")
	var codex := CodexStore.new(profile)
	var store := AchievementStore.new(profile)
	var repo := ContentRepository.load_all()
	var book := AchievementBook.build(repo, store, codex, CodexCatalog.build(repo))
	var tracker := AchievementTracker.new(book)
	var got: Array[StringName] = []
	tracker.achieved.connect(func(a: Dictionary) -> void: got.append(a["id"]))
	return {"store": store, "tracker": tracker, "got": got, "codex": codex}


func _arena(loop: int) -> World:
	var w := FinalLab.arena(FinalLab.run_state(131, &"blade", loop))
	w.actors.invuln[0] = LONG
	return w


## Steps `w` once and lets the tracker read it.
func _step(t: AchievementTracker, w: World, r: WorldReader) -> void:
	w.step(InputFrame.new())
	t.observe(r)


func _beat_body(t: AchievementTracker, w: World, r: WorldReader) -> void:
	FinalLab.past_rise(w)
	t.observe(r)
	FinalLab.hit(w, w.actors.hp[FinalLab.body(w)] * 10)
	for k in 200:
		_step(t, w, r)
		if not FinalBoss.shattering(w):
			break
	for k in 4:
		_step(t, w, r)


func test_the_three_are_defined() -> void:
	var repo := ContentRepository.load_all()
	for id: StringName in [&"final_boss", &"final_no_hit", &"final_looped"]:
		var d := repo.get_def(&"achievements", id) as AchievementDefinition
		assert_not_null(d, "%s is in the data" % id)
		assert_eq(d.problems().size(), 0, "%s is valid" % id)
		assert_eq(d.group, &"bosses")
	assert_eq(
		(repo.get_def(&"achievements", &"final_boss") as AchievementDefinition).stat, &"final:won"
	)


func test_beating_it_unlocks_crown_breaker_and_an_untouched_body() -> void:
	var p := _parts()
	var t: AchievementTracker = p["tracker"]
	var w := _arena(1)
	var r := WorldReader.new(w)
	t.attach(r)
	_beat_body(t, w, r)
	var store: AchievementStore = p["store"]
	assert_eq(store.stat(&"final:no_hit_phase"), 1, "the Colossus beaten without a hit")
	assert_true((p["got"] as Array).has(&"final_no_hit"), "Untouched")
	_beat_body(t, w, r)
	FinalLab.past_rise(w)
	FinalLab.hit(w, w.actors.hp[FinalLab.body(w)] * 10)
	_step(t, w, r)
	_step(t, w, r)
	assert_eq(r.outcome(), 1)
	assert_eq(store.stat(&"final:won"), 1)
	assert_eq(store.stat(&"runs:won"), 1, "a won run")
	assert_eq(store.stat(&"floors:cleared_3"), 0, "the floor isn't counted again")
	assert_eq(store.stat(&"final:no_hit_phase"), 3, "every body beaten clean")
	assert_true((p["got"] as Array).has(&"final_boss"), "Crown Breaker")
	assert_false((p["got"] as Array).has(&"final_looped"), "loop 1")


func test_a_hit_spoils_untouched_for_that_body() -> void:
	var p := _parts()
	var t: AchievementTracker = p["tracker"]
	var w := _arena(1)
	var r := WorldReader.new(w)
	t.attach(r)
	FinalLab.past_rise(w)
	w.actors.invuln[0] = 0
	var bid := w.actors.ids[FinalLab.body(w)]
	Damage.hit(w, 0, 5, bid, bid, w.take_root(), 0, Vector2.ZERO, w.player_pos())
	t.observe(r)
	w.actors.invuln[0] = LONG
	_beat_body(t, w, r)
	assert_eq(
		(p["store"] as AchievementStore).stat(&"final:no_hit_phase"),
		0,
		"hit in the Colossus's segment"
	)


func test_beating_it_after_a_loop_unlocks_beyond_the_loop() -> void:
	var p := _parts()
	var t: AchievementTracker = p["tracker"]
	var w := _arena(2)
	var r := WorldReader.new(w)
	t.attach(r)
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 2)
	FinalLab.past_rise(w)
	FinalLab.hit(w, w.actors.hp[FinalLab.body(w)] * 10)
	_step(t, w, r)
	_step(t, w, r)
	assert_eq((p["store"] as AchievementStore).stat(&"final:won_looped"), 1)
	assert_true((p["got"] as Array).has(&"final_looped"), "Beyond the Loop")
