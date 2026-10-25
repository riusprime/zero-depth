extends GutTest
## v0.9.0 DX (owner W §4 C: "subtle visual clues"; §5; Q23: no hint text, the hidden room unseen until the wall breaks;
## Q29b hidden rune markings): the destructibles' view on a whole floor's view (WorldViewRoot, the biome's kit). The
## cracked wall stands in its doorway with faint cracks that darken with each Skill hit (code stand-ins without the
## owner's models); its room's ground, own walls and reward are out of sight and the minimap leaves it out; broken, the
## rubble shows, the room comes into sight and the wall_break sound plays; a container breaks into chips with the
## container_break sound; a lit barrel's fuse blinks faster with the barrel_fuse sound, then blows in a flash with the
## barrel_blast sound and a camera thud; a faint rune marking lies beside each secret's doorway.


func _view(w: World) -> WorldViewRoot:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


func test_the_cracked_wall_its_room_and_the_markings() -> void:
	var w := CrackLab.world(&"blade")
	assert_not_null(w, "a floor with a cracked wall")
	if w == null:
		return
	w.step(InputFrame.new())
	var v := _view(w)
	var reader := v.reader
	var bv := v.breakables
	assert_not_null(bv, "the view is built")
	assert_true(bv.wall.visible, "the wall stands")
	assert_false(bv.rubble.visible, "no rubble yet")
	assert_almost_eq(bv.crack_shade, BreakablesView.CRACK_BASE, 0.001, "the cracks are faint")
	assert_false(bv.revealed)
	var held := 0
	for n in v.stage.hidden_nodes:
		assert_false(n.visible, "%s out of sight" % n.name)
		held += 1
	assert_gt(held, 0, "its ground and walls are held back")
	var reward := v.rewards.node_of(w.breakables.crack_reward_id)
	assert_false(reward.visible, "its reward unseen")
	var st := MinimapState.new()
	st.update(reader)
	assert_true(st.hidden.has(w.floor_layout.crack_room), "the minimap leaves it out")
	assert_not_null(v.markings, "the rune markings are drawn")
	assert_eq(v.markings.spots.size(), reader.secret_doors().size(), "one by each secret's doorway")
	var door := w.floor_layout.door_centers[w.floor_layout.crack_door]
	var near := false
	for q in v.markings.spots:
		near = near or Kin.length(q - door) < 4.0
	assert_true(near, "one near the cracked wall")
	var cues := AudioEvents.new()
	cues.prime(reader)
	CrackLab.skill(w)
	v.sync()
	assert_gt(bv.crack_shade, BreakablesView.CRACK_BASE, "a Skill hit darkens the cracks")
	assert_true(bv.wall.visible, "still whole")
	CrackLab.skill(w)
	CrackLab.skill(w)
	v.sync()
	assert_true(_ids(cues.collect(reader)).has(&"wall_break"), "it breaks with a crash")
	assert_false(bv.wall.visible, "the wall is gone")
	assert_true(bv.rubble.visible, "rubble in its place")
	assert_true(bv.revealed, "the room comes into sight")
	assert_true(reward.visible, "its reward too")
	st.update(reader)
	assert_false(st.hidden.has(w.floor_layout.crack_room))


func test_containers_and_barrels() -> void:
	var w := CrackLab.world(&"blade", false)
	if w == null:
		return
	var b := w.breakables
	var at := w.floor_layout.start_pos + Vector2(0.0, 3.0)
	b.add(at, Breakables.Kind.CRATE, 0, 0, 0)
	b.add(at + Vector2(6.0, 0.0), Breakables.Kind.EXPLOSIVE, 0, 0, 0)
	var crate := b.pos.size() - 2
	var barrel := b.pos.size() - 1
	var v := _view(w)
	var reader := v.reader
	var bv := v.breakables
	assert_eq(bv.props.size(), b.pos.size(), "every prop drawn")
	assert_true(bv.props[crate].visible)
	var cues := AudioEvents.new()
	cues.prime(reader)
	Breakables.hit(w, crate)
	v.sync()
	assert_false(bv.props[crate].visible, "the crate breaks")
	assert_gt(bv.fx_count(), 0, "into chips")
	assert_true(_ids(cues.collect(reader)).has(&"container_break"), "with a crack")
	Breakables.hit(w, barrel)
	w.step(InputFrame.new())
	v.sync()
	assert_true(_ids(cues.collect(reader)).has(&"barrel_fuse"), "the fuse hisses")
	var blinks := 0
	var was := bv.fuse_glow[barrel]
	var thud := false
	var heard: Array = []
	for k in 70:
		w.step(InputFrame.new())
		v.sync()
		heard.append_array(_ids(cues.collect(reader)))
		if bv.fuse_glow[barrel] > was:
			blinks += 1
		was = bv.fuse_glow[barrel]
		thud = thud or bv.blasted
	assert_gt(blinks, 5, "the fuse light blinks while it burns")
	assert_true(heard.has(&"barrel_blast"), "the blast is heard")
	assert_true(thud, "and felt")
	assert_false(bv.props[barrel].visible, "the barrel is gone")


func _ids(reqs: Array) -> Array:
	var out: Array = []
	for q: Array in reqs:
		out.append(q[0])
	return out
