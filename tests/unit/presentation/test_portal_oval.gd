extends GutTest
## v0.9.0 PT (owner C1-C5, Q15, Q16): the oval portals. Nothing stands before the boss dies; then each gate grows from a
## point (a circle the oval's width, then stretched to its full height) as the sim forms it (the view reads
## WorldReader.portal_form_progress, so it is whole the tick the hero may walk in); the oval is taller than wide; the
## portal taken collapses into a point at the end of the way in and the other one collapses as it closes; motes in the
## portal's colour drift off the rim once formed; reduced motion fades the full oval in, with no motes. A later floor
## has the arrival portal and no receiver; floor 1 lands on the altar (v0.9.0 SA). Presentation only (EI-07).

const LONG := 1 << 24
const SEED := 20261017

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


func _view(w: World) -> WorldViewRoot:
	var v := WorldViewRoot.new()
	add_child_autofree(v)
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


## Seals the boss room (the fight), then kills the boss: the portal opens this tick.
func _fight(w: World) -> void:
	w.actors.set_pos(0, w.floor_layout.boss_door_inside(1.5))
	CombatLab.idle(w, 4)


func _kill_boss(w: World) -> void:
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 0, 0, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 1)


func test_nothing_stands_before_the_boss_dies() -> void:
	var w := _world()
	var v := _view(w)
	v.sync()
	assert_not_null(v.gate)
	assert_not_null(v.deep_gate)
	assert_false(v.gate.visible, "no gate on the floor")
	assert_false(v.deep_gate.visible, "no Deep gate")
	_fight(w)
	v.sync()
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT)
	assert_false(v.gate.visible, "nor during the fight (not a sealed veil: nothing)")
	assert_false(v.deep_gate.visible)
	assert_eq(v.gate.form(), 0.0)


func test_each_gate_grows_from_a_point_over_the_sims_form_time() -> void:
	var w := _world()
	var v := _view(w)
	var reader := WorldReader.new(w)
	_fight(w)
	_kill_boss(w)
	w.step(InputFrame.new())
	v.sync()
	assert_true(v.gate.visible, "a dot of light just after the boss died")
	var first := PortalGate.half_extents(v.gate.form())
	assert_lt(first.y, 0.2, "it starts as a point")
	var last := v.gate.form()
	var saw_circle := false
	var ticks := 1
	while reader.portal_form_progress(WorldReader.ROUTE_NORMAL) < 1.0:
		w.step(InputFrame.new())
		v.sync()
		ticks += 1
		var k := reader.portal_form_progress(WorldReader.ROUTE_NORMAL)
		assert_almost_eq(v.gate.form(), k, 1e-6, "the view draws the sim's forming")
		assert_almost_eq(v.deep_gate.form(), k, 1e-6, "both gates together")
		assert_gt(v.gate.form(), last, "it grows")
		last = v.gate.form()
		var hs := PortalGate.half_extents(last)
		if hs.x > PortalGate.OVAL_W * 0.45 and hs.y < PortalGate.OVAL_W * 0.6:
			saw_circle = true
	assert_true(saw_circle, "a circle the oval's width on the way")
	assert_almost_eq(
		ticks * 1.0, BossFlow.PORTAL_FORM_TICKS * 1.0, 2.0, "over about 1.5 s of ticks"
	)
	assert_eq(v.gate.form(), 1.0, "whole once formed")
	assert_eq(
		v.gate.portal_material.get_shader_parameter("half_now"),
		Vector2(PortalGate.OVAL_W, PortalGate.OVAL_H) * 0.5
	)
	assert_eq(v.gate.portal_material.get_shader_parameter("burn"), 0.0, "the burning edge calmed")
	assert_true(v.gate.motes.emitting, "motes drift off the rim once formed")


func test_the_burning_edge_shows_while_it_grows() -> void:
	var g := PortalGate.new()
	add_child_autofree(g)
	g.set_sealed(false)
	g.set_growth(0.3)
	assert_gt(g.portal_material.get_shader_parameter("burn"), 0.9, "the edge burns while it grows")
	assert_false(g.motes.emitting, "no motes until it is whole")
	assert_true(g.portal_material.shader.code.contains("burn"))


func test_the_oval_is_tall_and_narrow_and_grows_point_circle_oval() -> void:
	var full := PortalGate.half_extents(1.0)
	assert_eq(full, Vector2(PortalGate.OVAL_W, PortalGate.OVAL_H) * 0.5)
	assert_gt(full.y / full.x, 2.0, "taller than wide (%.2f)" % (full.y / full.x))
	assert_almost_eq(PortalGate.OVAL_W, 1.6, 1e-5, "about 1.6 m wide")
	assert_almost_eq(PortalGate.OVAL_H, 3.4, 1e-5, "about 3.4 m tall")
	assert_eq(PortalGate.half_extents(0.0), Vector2.ZERO, "a point")
	var c := PortalGate.half_extents(PortalGate.CIRCLE_AT * 0.5)
	assert_almost_eq(c.x, c.y, 0.08, "a circle at first")
	var mid := PortalGate.half_extents(PortalGate.CIRCLE_AT)
	assert_almost_eq(mid.x, full.x, 1e-5, "the circle reaches the oval's width")
	assert_lt(mid.y, full.y, "then stretches up")
	var prev := Vector2.ZERO
	for k in 21:
		var hs := PortalGate.half_extents(k / 20.0)
		assert_true(hs.x >= prev.x and hs.y >= prev.y, "it only grows (%d)" % k)
		assert_true(hs.y >= hs.x - 1e-5, "never wider than tall (%d)" % k)
		prev = hs


func test_the_portal_taken_collapses_on_the_way_in_and_the_other_closes() -> void:
	var w := _world()
	var v := _view(w)
	_fight(w)
	_kill_boss(w)
	var f := w.floor_layout
	w.actors.set_pos(0, f.portal_front_point())
	var d := -f.portal_facing()
	var frame := InputFrame.make(
		Vector2i(roundi(d.x * SimTick.MOVE_MAX), roundi(d.y * SimTick.MOVE_MAX)), 0, 0, 0, 0
	)
	for k in 240:
		w.step(frame)
		v.sync()
		if w.boss_flow.state == BossFlow.State.ENTERING:
			break
	assert_eq(w.boss_flow.state, BossFlow.State.ENTERING)
	assert_eq(v.gate.form(), 1.0, "whole as the hero goes in")
	assert_true(v.deep_gate.is_sealed(), "the Deep gate closes")
	v.deep_gate._process(PortalGate.CLOSE_SECONDS * 0.5)
	assert_gt(v.deep_gate.form(), 0.0, "collapsing")
	assert_lt(v.deep_gate.form(), 1.0)
	v.deep_gate._process(PortalGate.CLOSE_SECONDS)
	assert_false(v.deep_gate.visible, "gone into a point")
	var smallest := 1.0
	var shrank := false
	var last := 1.0
	while w.boss_flow.state == BossFlow.State.ENTERING:
		w.step(InputFrame.new())
		v.sync()
		if v.transit.phase != PortalTransitView.Phase.ENTER:
			break
		shrank = shrank or v.gate.form() < last
		last = v.gate.form()
		smallest = minf(smallest, v.gate.form())
	assert_true(shrank, "the oval shrinks")
	assert_lt(smallest, 0.02, "into a point at the end of the way in")
	assert_false(v.gate.visible)


func test_reduced_motion_fades_the_full_oval_in_without_motes() -> void:
	ViewPrefs.reduced_motion = true
	var g := PortalGate.new()
	add_child_autofree(g)
	g.set_sealed(false)
	g.set_growth(0.5)
	assert_eq(
		g.portal_material.get_shader_parameter("half_now"),
		Vector2(PortalGate.OVAL_W, PortalGate.OVAL_H) * 0.5,
		"no growth of the shape"
	)
	var fade: float = g.portal_material.get_shader_parameter("fade")
	assert_almost_eq(fade, 0.5, 1e-4, "it fades in")
	assert_eq(g.portal_material.get_shader_parameter("burn"), 0.0, "no burning edge")
	g.set_growth(1.0)
	assert_eq(g.portal_material.get_shader_parameter("fade"), 1.0)
	assert_false(g.motes.emitting, "no motes")


func test_motes_wear_the_portals_colour() -> void:
	var g := PortalGate.new()
	add_child_autofree(g)
	var d := PortalGate.new()
	add_child_autofree(d)
	d.set_deep()
	var blue := g.motes.color_ramp.get_color(1)
	var violet := d.motes.color_ramp.get_color(1)
	assert_eq(Color(blue, 1.0), PortalGate.visor_blue())
	assert_eq(Color(violet, 1.0), PortalGate.DEEP_VIOLET)
	assert_eq(g.motes.emission_points.size(), PortalGate.MOTE_POINTS, "points round the rim")


## v0.9.0 PT (Q16): a later floor's world view has the arrival portal (the Deep gate's violet on a Deep floor) and no
## receiver; floor 1 lands on the altar (v0.9.0 SA) and has no arrival portal.
func test_a_later_floor_arrives_through_the_portal_floor_one_on_the_altar() -> void:
	for c: Array in [[1, 0], [2, 0], [2, Routes.Route.DEEP]]:
		var w := SaveLab.build_floor(SaveLab.run_state(SEED, c[0], &"blade", c[1]))
		w.boss_flow.set_transit(false, true)
		var v := _view(w)
		var tag := "floor %d route %d" % c
		if c[0] == 1:
			assert_not_null(v.altar, tag)
			assert_null(v.receiver, tag)
			assert_null(v.transit.arrival_gate, tag)
			continue
		assert_null(v.receiver, "%s: no receiver" % tag)
		var a := v.transit.arrival_gate
		assert_not_null(a, tag)
		assert_true(a.arrival)
		assert_eq(a.deep, c[1] == Routes.Route.DEEP, "%s: the portal taken" % tag)
		assert_false(a.visible, "%s: hidden until the arrival plays" % tag)
