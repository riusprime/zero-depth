extends GutTest
## The portal transit view (v0.3.5 PT; owner F19, F20): it reads the way in and the arrival from the sim's ticks
## (WorldReader) and poses the hero's model: drawn to the portal, spun and shrunk into light-blue motes with a flash;
## then grown back inside a light-blue column. Reduced motion: a plain fade, no motes. Presentation only (EI-07).

const LONG := 1 << 24

var _reduced := false


func before_each() -> void:
	_reduced = ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false


func after_each() -> void:
	ViewPrefs.reduced_motion = _reduced


func _world() -> World:
	var w := FightLab.floor_world(51, 1)
	w.floor_count = 3
	w.actors.invuln[0] = LONG
	return w


## [actors, gate, transit] wired as WorldViewRoot wires them.
func _views(reader: WorldReader) -> Array:
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var gate := PortalGate.new()
	add_child_autofree(gate)
	gate.setup(reader.portal_pos(), reader.portal_angle())
	var transit := PortalTransitView.new()
	add_child_autofree(transit)
	transit.setup(actors, gate)
	return [actors, gate, transit]


func _sync(reader: WorldReader, v: Array) -> void:
	(v[0] as ActorViews).sync(reader)
	(v[2] as PortalTransitView).sync(reader)


func _avatar(reader: WorldReader, v: Array) -> Node3D:
	return (v[0] as ActorViews).actor_node(reader.actor_id(0)).get_meta(&"avatar")


## Opens the portal and walks into it: the world is ENTERING after this.
func _enter(w: World) -> void:
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 4)
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 1, 1, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 1)
	w.actors.set_pos(0, f.portal_front_point())
	var d := -f.portal_facing()
	var frame := InputFrame.make(
		Vector2i(roundi(d.x * SimTick.MOVE_MAX), roundi(d.y * SimTick.MOVE_MAX)), 0, 0, 0, 0
	)
	for k in 240:
		if w.boss_flow.state == BossFlow.State.ENTERING:
			return
		w.step(frame)


func test_the_way_in_draws_spins_and_shrinks_the_hero_into_motes() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var v := _views(reader)
	var transit: PortalTransitView = v[2]
	_sync(reader, v)
	assert_eq(transit.phase, PortalTransitView.Phase.NONE)
	_enter(w)
	_sync(reader, v)
	assert_eq(transit.phase, PortalTransitView.Phase.ENTER, "the view reads the way in")
	var av := _avatar(reader, v)
	var centre := SimPlane.to_3d(
		reader.portal_pos() + Kin.dir(reader.portal_angle()) * PortalTransitView.PULL_DEPTH
	)
	var node := (v[0] as ActorViews).actor_node(reader.actor_id(0))
	var gap0 := Vector2(centre.x - node.position.x, centre.z - node.position.z).length()
	assert_gt(gap0, 0.1, "the hero starts in front of the portal")
	var flash_seen := false
	var shrank := false
	while w.boss_flow.state == BossFlow.State.ENTERING:
		w.step(InputFrame.new())
		_sync(reader, v)
		if transit.phase != PortalTransitView.Phase.ENTER:
			break
		assert_almost_eq(transit.progress, reader.portal_enter_progress(), 1e-6)
		var p := transit.progress
		var at := node.position + av.position
		var gap := Vector2(centre.x - at.x, centre.z - at.z).length()
		if p >= PortalTransitView.PULL_END:
			assert_almost_eq(gap, 0.0, 0.01, "drawn to the portal's centre by %.2f" % p)
		if p > 0.3 and p < 0.9:
			assert_ne(av.rotation.y, 0.0, "it spins")
		if p >= PortalTransitView.SHRINK_TO:
			assert_lt(av.scale.x, 0.01, "shrunk away")
			assert_false(av.visible)
			shrank = true
		if p >= PortalTransitView.BURST_AT:
			assert_true(transit.motes_out.emitting, "light-blue motes burst")
		if transit.light.light_energy > 1.0:
			flash_seen = true
	assert_true(shrank, "the hero shrank away")
	assert_true(flash_seen, "a flash of light")
	assert_true(w.boss_flow.exited(), "the sim ended the floor; the view decided nothing")


func test_the_arrival_grows_the_hero_inside_a_column_then_rests() -> void:
	var w := _world()
	w.boss_flow.set_transit(false, true)
	var reader := WorldReader.new(w)
	var v := _views(reader)
	var transit: PortalTransitView = v[2]
	_sync(reader, v)
	assert_eq(transit.phase, PortalTransitView.Phase.ARRIVE, "the floor opens on the arrival")
	var av := _avatar(reader, v)
	assert_lt(av.scale.x, 0.05, "the hero isn't there yet")
	assert_true(transit.motes_in.emitting, "motes gather")
	var column_seen := false
	var sizes: Array[float] = []
	while reader.arrival_progress() >= 0.0:
		w.step(InputFrame.new())
		_sync(reader, v)
		column_seen = column_seen or transit.column.visible
		sizes.append(av.scale.x)
	assert_true(column_seen, "a light-blue column")
	for k in range(1, sizes.size()):
		assert_gte(sizes[k], sizes[k - 1] - 1e-6, "the hero only grows")
	assert_eq(transit.phase, PortalTransitView.Phase.NONE, "control is back")
	assert_eq(av.scale, Vector3.ONE, "the model is whole")
	assert_eq(av.position, Vector3.ZERO)
	assert_true(av.visible)
	assert_false(transit.column.visible)
	var node := (v[0] as ActorViews).actor_node(reader.actor_id(0))
	for child in node.get_children():
		assert_true((child as Node3D).visible, "%s shows again" % child.name)


func test_reduced_motion_is_a_plain_fade() -> void:
	ViewPrefs.reduced_motion = true
	var w := _world()
	w.boss_flow.set_transit(true, true)
	var reader := WorldReader.new(w)
	var v := _views(reader)
	var transit: PortalTransitView = v[2]
	_sync(reader, v)
	var av := _avatar(reader, v)
	assert_true(transit.calm)
	assert_true(transit.overlay.visible, "the arrival fades in")
	var first := transit.overlay.color.a
	CombatLab.idle(w, BossFlow.ARRIVE_TICKS_CALM / 2)
	_sync(reader, v)
	assert_lt(transit.overlay.color.a, first, "fading in")
	assert_eq(av.scale, Vector3.ONE, "no growing")
	assert_false(transit.column.visible, "no column")
	assert_false(transit.motes_in.emitting, "no motes")
	CombatLab.idle(w, BossFlow.ARRIVE_TICKS_CALM)
	_sync(reader, v)
	assert_false(transit.overlay.visible)
	_enter(w)
	CombatLab.idle(w, BossFlow.ENTER_TICKS_CALM / 2)
	_sync(reader, v)
	assert_eq(transit.phase, PortalTransitView.Phase.ENTER)
	assert_gt(transit.overlay.color.a, 0.2, "the way in fades out")
	assert_eq(av.rotation, Vector3.ZERO, "no spin")
	assert_eq(av.scale, Vector3.ONE, "no shrink")
	assert_false(transit.motes_out.emitting, "no motes")


func test_materials_are_built_once() -> void:
	var transit := PortalTransitView.new()
	add_child_autofree(transit)
	var blue := ThemePalette.color(&"player_core")
	assert_eq(transit.light.light_color, blue, "the visor's light blue")
	var mote := (transit.motes_out.mesh as QuadMesh).material
	assert_same(mote, (transit.motes_in.mesh as QuadMesh).material, "one mote material")
	assert_lte(transit.motes_out.amount, 40, "cheap bursts")
