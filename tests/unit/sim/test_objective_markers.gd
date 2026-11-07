extends GutTest
## v0.11.0 O2 (owner L4, Q12 a): the objective markers (World.objectives) boss code points at for the hint arrow.
## Points and follows show through WorldReader (a followed actor moves with it and drops out when gone), clear and
## clear_all remove them, the cap holds, a world that never points hashes as before, and a world that does hashes
## apart, round-trips through a save and stays equal stepping on. An older save without the field still loads.


func test_point_follow_and_clear_show_through_the_reader() -> void:
	var w := SaveLab.floor_world(77, 1)
	var r := WorldReader.new(w)
	assert_eq(r.objectives(), [] as Array[Dictionary], "a fresh world points at nothing")
	w.objectives.point(ObjectiveMarkers.GATEKEEPER_PILLAR, Vector2(3, -2))
	w.objectives.point(ObjectiveMarkers.GATEKEEPER_PILLAR, Vector2(3, -2))  # the same place again: nothing new
	w.objectives.point(ObjectiveMarkers.GATEKEEPER_PILLAR, Vector2(-4, 1))
	var hero_id := w.actors.ids[0]
	w.objectives.follow(ObjectiveMarkers.TWINS_ACTIVE, hero_id)
	var got := r.objectives()
	assert_eq(got.size(), 3, "two pillars and one followed actor")
	assert_eq(got[0]["reason"], ObjectiveMarkers.GATEKEEPER_PILLAR)
	assert_eq(got[0]["pos"], Vector2(3, -2))
	assert_eq(got[0]["entity"], ObjectiveMarkers.NO_ENTITY)
	assert_eq(got[2]["reason"], ObjectiveMarkers.TWINS_ACTIVE)
	assert_eq(got[2]["pos"], w.actors.pos(0), "a followed marker sits on its actor")
	w.actors.set_pos(0, Vector2(1.5, 2.5))
	assert_eq(r.objectives()[2]["pos"], Vector2(1.5, 2.5), "and moves with it")
	w.objectives.follow(ObjectiveMarkers.SHADE_LANTERN, 987654)  # no such actor
	assert_eq(r.objectives().size(), 3, "a marker on an actor that is gone is left out")
	w.objectives.clear(ObjectiveMarkers.GATEKEEPER_PILLAR)
	got = r.objectives()
	assert_eq(got.size(), 1, "clear drops every marker of that reason")
	assert_eq(got[0]["reason"], ObjectiveMarkers.TWINS_ACTIVE)
	w.objectives.clear_all()
	assert_eq(r.objectives().size(), 0, "clear_all drops the rest")
	assert_eq(w.objectives.size(), 0)


func test_the_cap_holds() -> void:
	var o := ObjectiveMarkers.new()
	for i in ObjectiveMarkers.CAP + 3:
		o.point(ObjectiveMarkers.SHADE_LANTERN, Vector2(i, 0))
	assert_eq(o.size(), ObjectiveMarkers.CAP, "at most CAP markers")
	o.point(&"", Vector2.ONE)
	assert_eq(o.size(), ObjectiveMarkers.CAP, "an empty reason never joins")


func test_untouched_worlds_hash_as_before_and_markers_hash_apart() -> void:
	var a := SaveLab.floor_world(77, 1)
	var b := SaveLab.floor_world(77, 1)
	assert_eq(a.state_hash(), b.state_hash())
	b.objectives.clear_all()  # clearing nothing doesn't touch the store
	assert_eq(a.state_hash(), b.state_hash(), "a world that never pointed hashes as before")
	b.objectives.point(ObjectiveMarkers.GATEKEEPER_PILLAR, Vector2(1, 1))
	assert_ne(a.state_hash(), b.state_hash(), "a marker is in the hash")
	var c := SaveLab.floor_world(77, 1)
	c.objectives.point(ObjectiveMarkers.GATEKEEPER_PILLAR, Vector2(1, 1))
	assert_eq(b.state_hash(), c.state_hash(), "the same markers hash the same")


func test_markers_round_trip_through_a_save_and_step_on_equal() -> void:
	var w := SaveLab.floor_world(42, 2)
	SaveLab.run(w, FightBot.new(3), 120)
	w.objectives.point(ObjectiveMarkers.GATEKEEPER_PILLAR, Vector2(2, 3))
	w.objectives.follow(ObjectiveMarkers.TWINS_ACTIVE, w.actors.ids[0])
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray(), "every object is classified")
	var restored := World.from_snapshot(
		bytes_to_var(var_to_bytes(snap)), SaveLab.floor_world(42, 2)
	)
	assert_not_null(restored, "the snapshot fits its base")
	if restored == null:
		return
	assert_eq(restored.state_hash(), w.state_hash(), "restored hash equals")
	assert_eq(WorldReader.new(restored).objectives(), WorldReader.new(w).objectives())
	var b1 := FightBot.new(9)
	var b2 := FightBot.new(9)
	for i in 300:
		w.step(SaveLab.frame(w, b1))
		restored.step(SaveLab.frame(restored, b2))
	assert_eq(restored.state_hash(), w.state_hash(), "equal after 300 more ticks")


func test_an_older_save_without_the_field_still_loads() -> void:
	var w := SaveLab.floor_world(77, 1)
	var snap := WorldSnapshot.take(w)
	(snap["world"] as Dictionary).erase("objectives")
	var restored := World.from_snapshot(snap, SaveLab.floor_world(77, 1))
	assert_not_null(restored, "a save from before O2 restores")
	if restored != null:
		assert_eq(restored.objectives.size(), 0, "pointing at nothing")
		assert_eq(restored.state_hash(), w.state_hash())
