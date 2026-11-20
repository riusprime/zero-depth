extends GutTest
## v0.9.0 TD (owner W §2 presentation: "Slow beeps at first. Increasing frequency as time passes. Very fast beeping
## immediately before closure. A heavy impact when the door shuts. Include visual feedback, such as flashing runes, for
## accessibility"; Q23: the hidden room "should not appear or be visible until you open it"): the timed door's view on
## a whole floor's view (WorldViewRoot, the biome's kit). The door (a frame of the walls' own blocks, in the walls'
## material, a gate a little over the walls; the owner's slab filling its opening) and both rune switches stand; the
## secret room's ground, own walls and reward are out of sight and the minimap leaves it out; a switch's rune lights
## when pressed; both open the door, the room comes into sight; the beeps run slow to fast and
## each flashes the runes; the cues play the opening, the beeps (captioned) and the impact; the shut slams the slab.


func _view(w: World) -> WorldViewRoot:
	var biome: BiomeDefinition = SharedContent.repo().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


func test_the_beeps_run_slow_to_very_fast() -> void:
	var b := TimedDoorView.beep_ticks(900)
	assert_eq(b[0], 0, "a beep as it opens")
	assert_eq(b[1] - b[0], TimedDoorView.BEEP_SLOW, "slow at first (1 s)")
	var last_gap := b[b.size() - 1] - b[b.size() - 2]
	assert_lte(last_gap, TimedDoorView.BEEP_FAST + 1, "very fast just before the shut")
	for k in range(2, b.size()):
		assert_lte(b[k] - b[k - 1], b[k - 1] - b[k - 2], "never slower than the beep before")
	assert_lt(b[b.size() - 1], 900, "all before the timer runs out")
	gut.p("TIMED_BEEPS| count=%d first_gap=%d last_gap=%d" % [b.size(), b[1] - b[0], last_gap])


func test_the_door_the_switches_and_the_hidden_room() -> void:
	var w := TimedLab.world()
	assert_not_null(w, "a floor with a timed door")
	if w == null:
		return
	w.step(InputFrame.new())
	var v := _view(w)
	var reader := v.reader
	var t := v.timed_door
	assert_not_null(t, "the view is built")
	assert_eq(t.switch_count(), 2, "two rune switches")
	# The frame is the walls' blocks; the slab with its carved seal is the owner's.
	assert_true(t.uses_model, "the owner's timed_door")
	for n in ["Frame/Blocks", "Frame/Notch", "Slab/Model", "Slab/Seal"]:
		assert_true(t.has_node("Door/" + n), "the door's %s" % n)
	for n in ["Frame/JambLeft", "Frame/JambRight", "Frame/Middle"]:
		assert_false(t.has_node("Door/" + n), "his rounded %s not drawn" % n)
	_frame_is_the_walls(v, t, reader)
	var top := _slab_top(t)
	assert_gte(top, TimedDoorFrame.OPEN_H, "the slab fills the opening")
	assert_lte(top, TimedDoorFrame.TOP, "its top hidden in the lintel")
	assert_true(t.switch_uses_model, "the owner's rune_switch")
	assert_true(t.slab.visible, "shut: the slab stands")
	assert_false(t.revealed, "the secret room unseen")
	assert_gt(v.stage.hidden_nodes.size(), 0, "its ground and walls are held back")
	for n in v.stage.hidden_nodes:
		assert_false(n.visible, "%s out of sight" % n.name)
	var i := w.rewards.index_of(w.timed.reward_id)
	var reward := v.rewards.node_of(w.timed.reward_id)
	assert_not_null(reward)
	assert_false(reward.visible, "its reward unseen")
	var st := MinimapState.new()
	st.update(reader)
	assert_true(st.hidden.has(w.floor_layout.timed_room), "the minimap leaves it out")
	assert_false(st.door_known(reader, w.floor_layout.timed_door), "no doorway drawn into it")
	var cues := AudioEvents.new()
	cues.prime(reader)
	TimedLab.switch(w, 0)
	v.sync()
	assert_eq(t.switch_glow[0], 1.0, "the pressed switch's rune is lit")
	assert_eq(t.switch_glow[1], 0.0, "the other still dark")
	TimedLab.switch(w, 1)
	v.sync()
	var heard := _ids(cues.collect(reader))
	assert_true(heard.has(&"pylon_lock"), "a switch locks in with a sound")
	assert_true(
		heard.has(&"boss_door_opening"), "the door opens with the boss door's opening sound"
	)
	assert_true(heard.has(&"timer_beep"), "the first beep")
	assert_true(t.revealed, "the room comes into sight as it opens")
	for n in v.stage.hidden_nodes:
		assert_true(n.visible)
	assert_eq(v.stage.hidden_nodes.size(), 0, "nothing held back now")
	assert_true(reward.visible, "its reward too")
	assert_false(reader.reward_hidden(i))
	st.update(reader)
	assert_false(
		st.hidden.has(w.floor_layout.timed_room), "and the minimap may show it once you go in"
	)
	assert_gt(t.flash, 0.5, "the beep flashes the runes")
	for n in ["Door/Frame/Notch", "Door/Slab/Seal"]:
		var lit := (t.get_node(n) as MeshInstance3D).material_override as StandardMaterial3D
		assert_gt(lit.emission_energy_multiplier, 2.0, "%s flashes with the beep" % n)
	t._process(TimedDoorView.SINK_S + 0.1)
	assert_false(t.slab.visible, "the slab sank into the floor")
	assert_lte(t.slab.position.y + top, 0.001, "all of it, its top to the floor")
	var beeps := 1
	var flashes := 0
	var was := t.flash
	w.actors.set_pos(0, w.floor_layout.timed_switches[0])
	while reader.timed_door_state() == WorldReader.TIMED_OPEN:
		w.step(InputFrame.new())
		v.sync()
		beeps += _ids(cues.collect(reader)).count(&"timer_beep")
		if t.flash > was:
			flashes += 1
		was = t.flash
	assert_eq(beeps, TimedDoorView.beep_ticks(1200).size(), "every beep heard")
	assert_eq(flashes, beeps - 1, "and each one seen")
	assert_true(t.slammed, "the shut slams the slab")
	t._process(TimedDoorView.SLAM_S + 0.05)
	assert_true(t.slab.visible, "back up")
	var shut := _ids(cues.collect(reader))
	assert_eq(shut, [], "the shut's impact was asked on the tick it shut")
	assert_true(
		TranslationServer.translate(&"CAPTION_TIMER_BEEP") != "CAPTION_TIMER_BEEP",
		"the beep is captioned"
	)


func test_the_shut_plays_the_impact() -> void:
	var w := TimedLab.world()
	if w == null:
		return
	var reader := WorldReader.new(w)
	w.step(InputFrame.new())
	TimedLab.switch(w, 0)
	TimedLab.switch(w, 1)
	var cues := AudioEvents.new()
	cues.prime(reader)
	w.actors.set_pos(0, w.floor_layout.timed_switches[0])
	var heard: Array = []
	for k in 1200:
		w.step(InputFrame.new())
		heard.append_array(_ids(cues.collect(reader)))
	assert_eq(reader.timed_door_state(), WorldReader.TIMED_SHUT)
	assert_eq(heard.count(&"boss_door_impact"), 1, "one heavy impact on the shut")


## The frame: one mesh in the walls' material (on this floor the procedural ruin's: its shader, the biome's wall
## textures, what the kit draws the walls with), squared off, its foot as deep as the doorway, a gate a little over the
## walls.
func _frame_is_the_walls(v: WorldViewRoot, t: TimedDoorView, reader: WorldReader) -> void:
	var mat := t.frame_material as ShaderMaterial
	assert_not_null(mat, "the frame in the walls' shader")
	if mat == null:
		return
	var tex := StageView.wall_textures(v.stage.prop_style)
	assert_eq(mat.get_shader_parameter(&"face_tex"), tex["face"], "the walls' face texture")
	assert_eq(mat.get_shader_parameter(&"top_tex"), tex["top"], "and their top texture")
	var wall: MeshInstance3D = null
	if v.stage.kit != null:
		for n in v.stage.kit.get_children():
			if n.get_meta(&"piece", &"") == &"proc_wall":
				wall = n
				break
	assert_not_null(wall, "the floor's walls are the procedural ruin")
	if wall != null:
		var theirs := wall.get_surface_override_material(0) as ShaderMaterial
		assert_eq(mat.shader.code, theirs.shader.code, "the same shader as the walls")
		assert_eq(mat.get_shader_parameter(&"face_tex"), theirs.get_shader_parameter(&"face_tex"))
	var blocks := t.get_node("Door/Frame/Blocks") as MeshInstance3D
	assert_eq(blocks.get_surface_override_material(0), mat)
	var box := blocks.mesh.get_aabb()
	assert_almost_eq(box.size.y, TimedDoorFrame.TOP, 0.01, "the lintel's top")
	assert_lt(box.size.y, ProceduralWall.MAX_H * 2.0, "a gate in the wall, not a tower over it")
	var depth := reader.timed_door_depth()
	var gate := TimedDoorFrame.gate_depth(depth) + 2.0 * TimedDoorFrame.KEY_OUT
	var deep := maxf(depth, gate) + 2.0 * TimedDoorFrame.PROUD
	assert_almost_eq(box.size.x, deep, 0.01, "its foot as deep as the doorway")
	assert_lte(gate, depth + 2.0 * TimedDoorFrame.KEY_OUT, "the gate over it no deeper")
	var wide := reader.timed_door_width() + 2.0 * TimedDoorFrame.JAMB
	assert_almost_eq(box.size.z, wide, 0.01, "the jambs over the wall's ends")


## The owner's slab's top in the door's frame (m), from its own triangles.
func _slab_top(t: TimedDoorView) -> float:
	var body := t.get_node("Door/Slab/Model") as MeshInstance3D
	var arr := body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var top := -INF
	for k: int in arr[Mesh.ARRAY_INDEX]:  # its own triangles' corners (the parts share one vertex list)
		top = maxf(top, verts[k].y)
	return t.slab.position.y + body.position.y + top * body.scale.y


func _ids(reqs: Array) -> Array:
	var out: Array = []
	for r: Array in reqs:
		out.append(r[0])
	return out


func test_the_lever_inside_swings_down_while_the_door_stands_open() -> void:
	var w := TimedLab.world()
	if w == null:
		return
	w.step(InputFrame.new())
	var v := _view(w)
	var t := v.timed_door
	assert_true(t.has_lever, "v0.9.5 TS: a lever stands inside the secret room")
	var lever := t.get_node_or_null("Lever") as Node3D
	assert_not_null(lever)
	assert_eq(lever.position, SimPlane.to_3d(w.floor_layout.timed_lever), "on its spot")
	assert_eq(t.lever_pull, 0.0, "shut: the handle stands up")
	TimedLab.switch(w, 0)
	TimedLab.switch(w, 1)
	v.sync()
	t._process(TimedDoorView.PULL_S + 0.05)
	assert_eq(t.lever_pull, 1.0, "open: the handle is down")
	assert_eq(
		TranslationServer.translate(&"TIMED_LEVER_PROMPT").begins_with("Pull"),
		true,
		"the lever has its own prompt: a short verb"
	)
