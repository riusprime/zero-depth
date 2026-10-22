extends GutTest
## v0.9.0 TD (owner W §2 presentation: "Slow beeps at first. Increasing frequency as time passes. Very fast beeping
## immediately before closure. A heavy impact when the door shuts. Include visual feedback, such as flashing runes, for
## accessibility"; Q23: the hidden room "should not appear or be visible until you open it"): the timed door's view on
## a whole floor's view (WorldViewRoot, the biome's kit). The door and both rune switches stand (code stand-ins without
## the owner's models); the secret room's ground, own walls and reward are out of sight and the minimap leaves it out;
## a switch's rune lights when pressed; both open the door, the room comes into sight; the beeps run slow to fast and
## each flashes the runes; the cues play the opening, the beeps (captioned) and the impact; the shut slams the slab.


func _view(w: World) -> WorldViewRoot:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
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
	# v0.9.0 MI2: the owner's door (a gate of iron bars, the whole of it sinks) and switches are listed.
	assert_true(t.uses_model, "the owner's timed_door")
	assert_true(t.switch_uses_model, "the owner's rune_switch")
	assert_not_null(t.slab.find_child("Model", false, false), "his gate is the slab that sinks")
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
	assert_eq(st.hidden, w.floor_layout.timed_room, "the minimap leaves it out")
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
	assert_eq(st.hidden, -1, "and the minimap may show it once you go in")
	assert_gt(t.flash, 0.5, "the beep flashes the runes")
	t._process(TimedDoorView.SINK_S + 0.1)
	assert_false(t.slab.visible, "the slab sank into the floor")
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
	assert_eq(beeps, TimedDoorView.beep_ticks(900).size(), "every beep heard")
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
	for k in 900:
		w.step(InputFrame.new())
		heard.append_array(_ids(cues.collect(reader)))
	assert_eq(reader.timed_door_state(), WorldReader.TIMED_SHUT)
	assert_eq(heard.count(&"boss_door_impact"), 1, "one heavy impact on the shut")


func _ids(reqs: Array) -> Array:
	var out: Array = []
	for r: Array in reqs:
		out.append(r[0])
	return out
