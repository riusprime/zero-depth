extends GutTest
## v0.9.0 RA (owner W §4 A; Q22: "the pillar turns with a grind; a correct face glows; solved: all three flare"; Q23:
## the hidden room "should not appear or be visible until you open it"): the rune puzzle's view on a whole floor's view
## (WorldViewRoot, the biome's kit). Three pillars and the carved slab stand (code stand-ins without the owner's
## models); the carving shows the three target symbols; the hidden room's ground, own walls and reward are out of
## sight and the minimap leaves it out; a press grinds a pillar a quarter round (the pillar_turn sound) and the face
## it shows is the one toward the camera; a matching face glows; the last match flares all three, sinks the slab and
## shows the room.


func _view(w: World) -> WorldViewRoot:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


func test_the_pillars_the_carving_and_the_hidden_room() -> void:
	var w := RuneLab.world()
	assert_not_null(w, "a floor with a rune puzzle")
	if w == null:
		return
	w.step(InputFrame.new())
	var v := _view(w)
	var reader := v.reader
	var r := v.rune_view
	assert_not_null(r, "the view is built")
	assert_eq(r.pillar_count(), 3, "three pillars")
	assert_false(r.uses_model, "the code stand-in until the owner's model is listed")
	assert_true(r.slab.visible, "the slab seals the doorway")
	assert_not_null(r.slab.find_child("Mural", true, false), "the carving is on it")
	for k in 3:
		assert_not_null(
			r.slab.find_child("Glyph%d" % reader.rune_target(k), true, false),
			"the carving shows pillar %d's symbol" % k
		)
	assert_false(r.revealed, "the hidden room unseen")
	assert_gt(v.stage.hidden_nodes.size(), 0, "its ground and walls are held back")
	for n in v.stage.hidden_nodes:
		assert_false(n.visible, "%s out of sight" % n.name)
	var reward := v.rewards.node_of(w.runes.reward_id)
	assert_not_null(reward)
	assert_false(reward.visible, "its reward unseen")
	var st := MinimapState.new()
	st.update(reader)
	assert_true(st.hidden.has(w.floor_layout.rune_room), "the minimap leaves it out")
	assert_false(st.door_known(reader, w.floor_layout.rune_door), "no doorway drawn into it")
	var cues := AudioEvents.new()
	cues.prime(reader)
	var k0 := 0
	var before := reader.rune_face(k0)
	RuneLab.turn(w, k0)
	v.sync()
	assert_true(_ids(cues.collect(reader)).has(&"pillar_turn"), "the turn grinds")
	assert_eq(r.shown[k0], (before + 1) % 4, "the view follows the face")
	r._process(RuneAlignmentView.TURN_S + 0.05)
	assert_almost_eq(
		wrapf(r.drum(k0).rotation.y - RuneAlignmentView._face_yaw(r.shown[k0]), -PI, PI),
		0.0,
		0.01,
		"the drum turned that face to the front"
	)
	for k in 3:
		var matched := reader.rune_face(k) == reader.rune_target(k)
		assert_almost_eq(
			r.glow[k], 1.0 if matched else 0.35, 0.001, "pillar %d glows only when it matches" % k
		)
	RuneLab.solve(w)
	v.sync()
	var heard := _ids(cues.collect(reader))
	assert_true(heard.has(&"boss_door_opening"), "the slab grinds open")
	for k in 3:
		assert_eq(r.glow[k], 1.0, "every face matches and glows")
	r._process(RuneAlignmentView.FLARE_S * 0.5)
	v.sync()
	assert_gt(r.flare, 0.9, "solved: all three flare")
	assert_true(r.revealed, "the room comes into sight")
	assert_eq(v.stage.hidden_nodes.size(), 0, "nothing held back now")
	assert_true(reward.visible, "its reward too")
	st.update(reader)
	assert_false(st.hidden.has(w.floor_layout.rune_room), "the minimap may show it once you go in")
	r._process(RuneAlignmentView.SINK_S + 0.1)
	assert_false(r.slab.visible, "the slab sank into the floor")


func test_beside_a_timed_door_each_room_shows_on_its_own() -> void:
	var w := RuneLab.world(1, true)
	if w == null:
		return
	w.step(InputFrame.new())
	var v := _view(w)
	RuneLab.solve(w)
	v.sync()
	assert_true(v.rune_view.revealed, "the rune room shows")
	assert_false(v.timed_door.revealed, "the timed door's stays unseen")
	assert_gt(v.stage.hidden_nodes.size(), 0, "its pieces still held back")
	for n in v.stage.hidden_nodes:
		assert_false(n.visible)


func _ids(reqs: Array) -> Array:
	var out: Array = []
	for q: Array in reqs:
		out.append(q[0])
	return out
