extends GutTest
## v0.8.0 N11 (owner O69): the receiver and the arrival on it. Every run floor (Deep floors too) has a receiver in the
## middle of its first room, at the hero's start, on open floor; the final arena and the Playground have none. It is
## low, round, pale (unlike every portal's colour) and draws its stand-in until the manifest lists `floor_receiver`.
## The arrival's view (PortalTransitView on a receiver): floor 1 charges, trembles, wobbles and zooms with no hero, then
## the hero pops in (an overshoot, a burst, a kick) and the view settles; a later floor's hero steps out of the portal
## taken (v0.9.0 PT); reduced motion has no shake, wobble, zoom or rise. Presentation only (EI-07): it reads the
## sim's arrival progress.

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


## [actors, transit, receiver, rig] wired as WorldViewRoot wires them.
func _views(reader: WorldReader) -> Array:
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var receiver := FloorReceiver.new()
	add_child_autofree(receiver)
	receiver.setup(reader.floor_start_pos())
	var transit := PortalTransitView.new()
	add_child_autofree(transit)
	transit.setup(actors, null)
	transit.receiver = receiver
	transit.rig = rig
	return [actors, transit, receiver, rig]


func _sync(reader: WorldReader, v: Array) -> void:
	(v[0] as ActorViews).sync(reader)
	(v[1] as PortalTransitView).sync(reader)


func _avatar(reader: WorldReader, v: Array) -> Node3D:
	return (v[0] as ActorViews).actor_node(reader.actor_id(0)).get_meta(&"avatar")


func test_floor_one_charges_trembles_zooms_then_pops_the_hero_in() -> void:
	var w := _floor(1)
	var reader := WorldReader.new(w)
	var v := _views(reader)
	var transit: PortalTransitView = v[1]
	var receiver: FloorReceiver = v[2]
	var rig: IsoRig = v[3]
	_sync(reader, v)
	assert_eq(transit.phase, PortalTransitView.Phase.ARRIVE)
	assert_true(transit.first, "floor 1's landing")
	var av := _avatar(reader, v)
	assert_false(av.visible, "no hero yet")
	var rolled := false
	var zoomed := 1.0
	var shook := false
	var peak := 0.0
	var charge_peak := 0.0
	var kicked := false
	var thudded := false
	while reader.arriving():
		w.step(InputFrame.new())
		_sync(reader, v)
		var q := reader.arrival_progress()
		if q < 0.0:
			break
		if q < PortalTransitView.POP_AT:
			assert_false(av.visible, "no hero before the pop (%.2f)" % q)
			rolled = rolled or absf(rig.flourish_roll) > 0.001
			shook = shook or rig.vibration_level() > 0.05
			charge_peak = maxf(charge_peak, receiver.charge)
		else:
			assert_true(av.visible, "the hero is there after the pop (%.2f)" % q)
			assert_true(transit.landed)
			peak = maxf(peak, av.scale.x)
			kicked = kicked or rig.kick_offset() != Vector2.ZERO
			thudded = thudded or rig.vibration_level() > PortalTransitView.TREMBLE_PEAK
		zoomed = maxf(zoomed, rig.flourish_zoom)
	assert_true(rolled, "the view wobbles")
	assert_true(shook, "the view vibrates while it charges (v0.9.0 CV)")
	assert_gt(zoomed, 1.05, "a quick zoom in")
	assert_gt(charge_peak, 0.8, "the receiver charged")
	assert_gt(peak, 1.05, "the pop overshoots")
	assert_false(kicked, "no kick across the screen (v0.9.0 CV)")
	assert_true(thudded, "a thud on the landing")
	assert_eq(transit.phase, PortalTransitView.Phase.NONE, "play is on")
	assert_eq(av.scale, Vector3.ONE, "the hero whole")
	assert_true(av.visible)
	assert_eq(rig.flourish_roll, 0.0, "the view settled")
	assert_eq(rig.flourish_zoom, 1.0)
	assert_eq(receiver.charge, 0.0, "the receiver at rest")
	assert_false(receiver.shock.visible)


## v0.9.0 PT (owner Q16: "the rest of the floor spawn the same portal that you take at the end of the floor, character
## comes out of it and then it vanishes"): a later floor has no receiver; the portal taken (the Deep gate's violet on
## a Deep floor) grows behind the hero's spot, the hero steps out of it with a thud, and it collapses into a point.
func test_a_later_floor_steps_the_hero_out_of_the_portal_taken() -> void:
	for route in [0, Routes.Route.DEEP]:
		var w := _floor(2, route)
		var reader := WorldReader.new(w)
		var v := _views(reader)
		var transit: PortalTransitView = v[1]
		var rig: IsoRig = v[3]
		transit.receiver = null
		var gate := PortalGate.new()
		if reader.floor_is_deep():
			gate.set_deep()
		gate.set_arrival()
		add_child_autofree(gate)
		transit.arrival_gate = gate
		_sync(reader, v)
		assert_false(transit.first, "the step-out")
		var want := (
			PortalGate.DEEP_VIOLET if route == Routes.Route.DEEP else PortalGate.visor_blue()
		)
		assert_eq(gate.portal_color(), want, "the portal taken (route %d)" % route)
		var av := _avatar(reader, v)
		var farthest := 0.0
		var grown := 0.0
		var thudded := false
		while reader.arriving():
			w.step(InputFrame.new())
			_sync(reader, v)
			if transit.phase != PortalTransitView.Phase.ARRIVE:
				break
			grown = maxf(grown, gate.form())
			if av.visible:
				farthest = maxf(farthest, av.position.length())
			thudded = thudded or rig.vibration_level() > 0.0
			assert_eq(rig.flourish_roll, 0.0, "no wobble on a later floor")
		assert_gt(grown, 0.99, "the portal grew whole")
		assert_gt(farthest, 0.4, "the hero stepped out of it")
		assert_true(thudded, "a thud as the hero comes through")
		assert_false(gate.visible, "it collapsed into a point")
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
