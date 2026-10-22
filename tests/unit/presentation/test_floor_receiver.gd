extends GutTest
## v0.8.0 N11 (owner O69): the receiver and the arrival on it. Every run floor (Deep floors too) has a receiver in the
## middle of its first room, at the hero's start, on open floor; the final arena and the Playground have none. It is
## low, round, pale (unlike every portal's colour) and draws its stand-in until the manifest lists `floor_receiver`.
## The arrival's view (PortalTransitView on a receiver): floor 1 charges, trembles, wobbles and zooms with no hero, then
## the hero pops in (an overshoot, a burst, a kick) and the view settles; a later floor's hero rises out of it; reduced
## motion has no shake, wobble, zoom or rise. Presentation only (EI-07): it reads the sim's arrival progress.
## v0.9.0 SA (owner Q16: "only floor 1"): floor 1 of a run lands on the arrival altar (AltarStage) instead, over 4.0 s:
## the empty altar, its runes lighting, their orbit, the buildup with the vibration climbing, the pop on the sound's
## peak, the release; its start keeps 3.3 m clear (the altar's radius) of walls, cover, spawn spots and devices.

const SEED := 20261017
const LONG := 1 << 24

var _reduced := false


func before_each() -> void:
	_reduced = ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false


func after_each() -> void:
	ViewPrefs.reduced_motion = _reduced


## Floor `floor_index` as Main builds it, with Main's arrival (floor 1 the long one); `route` into the later floors.
func _floor(floor_index: int, route: int = 0, calm: bool = false) -> World:
	var w := SaveLab.build_floor(SaveLab.run_state(SEED, floor_index, &"blade", route))
	w.tuning = RunContentCompiler.compile_sim_tuning(
		ContentRepository.load_all().get_def(&"tuning", &"sim")
	)
	w.boss_flow.set_transit(
		calm, true, BossFlow.arrival_length(w.tuning, calm, w.run_floor_index() == 1)
	)
	w.actors.invuln[0] = LONG
	return w


func test_every_run_floor_has_a_receiver_at_the_start_on_open_floor() -> void:
	for c: Array in [[1, 0], [2, 0], [3, 0], [2, Routes.Route.DEEP], [3, Routes.Route.DEEP]]:
		var w := _floor(c[0], c[1])
		var reader := WorldReader.new(w)
		var tag := "floor %d route %d" % c
		assert_true(reader.floor_receiver(), tag)
		var at := reader.floor_start_pos()
		assert_eq(at, w.player_pos(), "%s: where the hero starts" % tag)
		var room: Rect2 = w.floor_layout.rooms[w.floor_layout.start_room]
		assert_true(
			room.grow(-FloorReceiver.RADIUS).has_point(at), "%s: inside the first room" % tag
		)
		for o in w.walls:
			assert_eq(
				Collide.circle_vs_obb(at, FloorReceiver.RADIUS + 0.3, o),
				Vector2.ZERO,
				"%s: no wall on it" % tag
			)
		for i in reader.reward_count():
			assert_gt(at.distance_to(reader.reward_pos(i)), 2.0, "%s: no altar on it" % tag)
		if reader.has_gamble():
			assert_gt(at.distance_to(reader.gamble_pos()), 2.0, "%s: the shrine apart" % tag)
		assert_eq(c[1] == Routes.Route.DEEP, reader.floor_is_deep(), tag)


func test_never_in_the_final_arena_or_the_playground() -> void:
	var arena := FinalLab.arena(FinalLab.run_state(SEED))
	assert_false(WorldReader.new(arena).floor_receiver(), "the final arena has none")
	var repo := ContentRepository.load_all()
	var pg := PlaygroundScenario.build(repo, &"gun", repo.get_def(&"biomes", &"ruins"))
	assert_false(WorldReader.new(pg).floor_receiver(), "the Playground has none")


func test_it_looks_unlike_every_portal() -> void:
	var r := FloorReceiver.new()
	add_child_autofree(r)
	assert_false(r.uses_model, "no floor_receiver model listed yet: the stand-in")
	assert_eq(r.arms.size(), 4, "four arms")
	assert_lt(FloorReceiver.PALE.s, 0.25, "pale")
	for c: Color in [
		PortalGate.visor_blue(), PortalGate.DEEP_VIOLET, AscensionPortal.GOLD, LoopDevice.GREEN
	]:
		var hue := absf(c.h - FloorReceiver.PALE.h)
		hue = minf(hue, 1.0 - hue)
		assert_true(
			hue > 0.08 or c.s - FloorReceiver.PALE.s > 0.4,
			"apart from the portal's %s" % c.to_html()
		)
	var box := AABB()
	for n in r.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		box = box.merge(mi.global_transform * mi.get_aabb())
	assert_lt(box.size.y, 1.3, "low (%.2f m)" % box.size.y)
	assert_almost_eq(box.size.x, box.size.z, 0.3, "round")
	assert_lt(box.size.x, 2.4, "about 2.2 m across")
	assert_null(r.find_child("*Arch*", true, false), "no arch")


## [actors, transit, receiver (v0.9.0 SA: floor 1's altar), rig] wired as WorldViewRoot wires them.
func _views(reader: WorldReader) -> Array:
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var transit := PortalTransitView.new()
	add_child_autofree(transit)
	transit.setup(actors, null)
	transit.rig = rig
	if reader.arrival_altar():
		var altar := AltarStage.new(AltarStage.arrival())
		add_child_autofree(altar)
		altar.setup(reader.floor_start_pos())
		transit.altar = altar
		return [actors, transit, altar, rig]
	var receiver := FloorReceiver.new()
	add_child_autofree(receiver)
	receiver.setup(reader.floor_start_pos())
	transit.receiver = receiver
	return [actors, transit, receiver, rig]


func _sync(reader: WorldReader, v: Array) -> void:
	(v[0] as ActorViews).sync(reader)
	(v[1] as PortalTransitView).sync(reader)


func _avatar(reader: WorldReader, v: Array) -> Node3D:
	return (v[0] as ActorViews).actor_node(reader.actor_id(0)).get_meta(&"avatar")


func test_floor_one_lands_on_the_altar_not_a_receiver() -> void:
	var r1 := WorldReader.new(_floor(1))
	assert_true(r1.arrival_altar(), "floor 1 of a run: the altar")
	for c: Array in [[2, 0], [3, 0], [2, Routes.Route.DEEP]]:
		var r := WorldReader.new(_floor(c[0], c[1]))
		assert_false(r.arrival_altar(), "floor %d: not the altar" % c[0])
	assert_eq(r1.arrival_ticks(), 240, "Q16: 4.0 s")


## v0.9.0 SA: nothing in the sim stands on the altar (the sim has no height; the altar is walkable floor): no wall or
## cover within its radius of the start, no spawn spot, reward, shrine, shop or event on it.
func test_floor_one_keeps_the_altars_footprint_clear() -> void:
	var r := AltarStage.RADIUS
	for s in 12:
		var seed_value := SEED + s * 7919
		var w := SaveLab.build_floor(SaveLab.run_state(seed_value, 1, &"blade"))
		var reader := WorldReader.new(w)
		var at := reader.floor_start_pos()
		var tag := "seed %d" % seed_value
		var room: Rect2 = w.floor_layout.rooms[w.floor_layout.start_room]
		assert_true(room.grow(-r).has_point(at), "%s: the altar fits in the start hall" % tag)
		for o in w.walls:
			assert_eq(
				Collide.circle_vs_obb(at, r, o), Vector2.ZERO, "%s: no wall or cover on it" % tag
			)
		for p in reader.spawn_spots():
			assert_gt(at.distance_to(p), r, "%s: no spawn spot on it" % tag)
		for i in reader.reward_count():
			assert_gt(at.distance_to(reader.reward_pos(i)), r, "%s: no reward on it" % tag)
		if reader.has_gamble():
			assert_gt(at.distance_to(reader.gamble_pos()), r, "%s: no shrine on it" % tag)
		if reader.has_shop():
			assert_gt(at.distance_to(reader.shop_pos()), r, "%s: no shop on it" % tag)
		for k in reader.event_count():
			assert_gt(at.distance_to(reader.event_pos(k)), r, "%s: no event on it" % tag)


func test_floor_one_runs_the_altars_six_stages() -> void:
	var w := _floor(1)
	var reader := WorldReader.new(w)
	var v := _views(reader)
	var transit: PortalTransitView = v[1]
	var altar: AltarStage = v[2]
	var rig: IsoRig = v[3]
	var look := altar.look
	_sync(reader, v)
	assert_eq(transit.phase, PortalTransitView.Phase.ARRIVE)
	assert_true(transit.first, "floor 1's landing")
	var av := _avatar(reader, v)
	assert_false(av.visible, "no hero yet")
	assert_eq(altar.rune_glow_now(0), 0.0, "1. idle: the empty altar")
	var first_lit := -1.0
	var orbit_start := -1.0
	var last_angle := 0.0
	var last_step := 0.0
	var sped_up := true
	var vib_build := 0.0
	var vib_pop := 0.0
	var energy_peak := 0.0
	var zoomed := 1.0
	var rolled := false
	var kicked := false
	while reader.arriving():
		w.step(InputFrame.new())
		_sync(reader, v)
		var q := reader.arrival_progress()
		if q < 0.0:
			break
		if first_lit < 0.0 and altar.rune_glow_now(0) > 0.5:
			first_lit = q
		var step := altar.angle - last_angle
		if orbit_start < 0.0 and step > 0.0:
			orbit_start = q
		if q < look.pop_at:
			if step > 0.0 and last_step > 0.0 and step + 1e-6 < last_step:
				sped_up = false
			assert_false(av.visible, "no hero before the pop (%.2f)" % q)
			vib_build = maxf(vib_build, rig.vibration_level())
			energy_peak = maxf(energy_peak, altar.energy)
		else:
			assert_true(av.visible, "the hero is there after the pop (%.2f)" % q)
			vib_pop = maxf(vib_pop, rig.vibration_level())
			kicked = kicked or rig.kick_offset() != Vector2.ZERO
		last_step = step
		last_angle = altar.angle
		zoomed = maxf(zoomed, rig.flourish_zoom)
		rolled = rolled or absf(rig.flourish_roll) > 0.0001
	assert_gt(first_lit, 0.0, "2. the runes light (%.2f)" % first_lit)
	assert_gt(orbit_start, first_lit, "3. they orbit after they light (%.2f)" % orbit_start)
	assert_true(sped_up, "3. the orbit speeds up to the pop")
	assert_gt(energy_peak, 0.8, "4. the buildup")
	assert_gt(vib_build, PortalTransitView.TREMBLE, "4. the vibration climbs")
	assert_gt(vib_pop, vib_build, "5. it peaks at the pop")
	assert_gt(zoomed, 1.05, "the zoom")
	assert_false(rolled, "no roll wobble")
	assert_false(kicked, "no kick across the screen")
	assert_eq(transit.phase, PortalTransitView.Phase.NONE, "6. play is on")
	assert_eq(av.scale, Vector3.ONE, "the hero whole")
	assert_eq(rig.flourish_zoom, 1.0, "the view settled")
	assert_eq(altar.energy, 0.0, "the energy dissipated")
	assert_lt(altar.rune_glow_now(0), 0.5, "the runes rest dim")
	assert_false(altar.shock.visible)


## v0.9.0 SA: the arrival's sound (AudioEvents) starts so its peak lands on the altar's pop, once.
func test_the_altar_cue_peaks_on_the_pop() -> void:
	var w := _floor(1)
	var reader := WorldReader.new(w)
	var audio := AudioEvents.new()
	audio.prime(reader)
	var look := AltarStage.arrival()
	var cue_tick := -1
	var plays := 0
	while reader.arriving():
		w.step(InputFrame.new())
		for c: Array in audio.collect(reader):
			if c[0] == look.cue:
				plays += 1
				cue_tick = w.tick
	assert_eq(plays, 1, "one cue")
	var pop_tick := look.pop_at * reader.arrival_ticks()
	assert_almost_eq(
		cue_tick + look.cue_peak_s * SimTick.TICKS_PER_SECOND, pop_tick, 2.0, "the peak on the pop"
	)


func test_a_later_floor_steps_the_hero_out_of_the_receiver() -> void:
	var w := _floor(2)
	var reader := WorldReader.new(w)
	var v := _views(reader)
	var transit: PortalTransitView = v[1]
	var rig: IsoRig = v[3]
	_sync(reader, v)
	assert_false(transit.first, "the step-out")
	var av := _avatar(reader, v)
	var lowest := 0.0
	var burst := false
	while reader.arriving():
		w.step(InputFrame.new())
		_sync(reader, v)
		if transit.phase != PortalTransitView.Phase.ARRIVE:
			break
		if av.visible:
			lowest = minf(lowest, av.position.y)
		burst = burst or (v[2] as FloorReceiver).shock.visible
		assert_eq(rig.flourish_roll, 0.0, "no wobble on a later floor")
	assert_lt(lowest, -0.3, "it rises out of the receiver")
	assert_true(burst, "a small burst")
	assert_eq(av.position, Vector3.ZERO)
	assert_eq(av.scale, Vector3.ONE)


func test_reduced_motion_has_no_shake_wobble_zoom_or_rise() -> void:
	ViewPrefs.reduced_motion = true
	var w := _floor(1, 0, true)
	var reader := WorldReader.new(w)
	var v := _views(reader)
	var rig: IsoRig = v[3]
	_sync(reader, v)
	var av := _avatar(reader, v)
	var shown := false
	while reader.arriving():
		w.step(InputFrame.new())
		_sync(reader, v)
		assert_eq(rig.flourish_roll, 0.0)
		assert_eq(rig.flourish_zoom, 1.0)
		assert_eq(rig.shake_level(), 0.0)
		assert_eq(rig.vibration_level(), 0.0)
		assert_eq(rig.kick_offset(), Vector2.ZERO)
		if av.visible:
			shown = true
			assert_eq(av.scale, Vector3.ONE, "no pop")
			assert_eq(av.position, Vector3.ZERO, "no rise")
	assert_true(shown, "the hero appears")
	assert_eq(w.tick, 18, "the short arrival")
	var altar: AltarStage = v[2]
	assert_eq(altar.angle, 0.0, "v0.9.0 SA: no orbit")
	assert_false(altar.motes.emitting, "no particles")
	assert_gt(altar.rune_glow_now(altar.look.runes - 1), 0.0, "the runes just light")
