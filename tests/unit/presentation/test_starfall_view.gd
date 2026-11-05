extends GutTest
## v0.10.5 W3-P10e (owner: "don't get crazy with visuals for explosions"; G1 V1, V2): the Starfall view. A star is a
## thin moon-blue line for 12 ticks, a meteor a falling streak for its 24 ticks, then the small blast ring; at most 8
## of each drawn; nothing without the sim's events.

const W := preload("res://tests/support/mx4_world.gd")

var _view: StarfallView


func before_each() -> void:
	_view = add_child_autofree(StarfallView.new())


func _world() -> World:
	var w := W.world(
		&"gun", [&"ember_core"], [[Vector2(5, 5), 9000000], [Vector2(5.5, 5), 9000000]]
	)
	w.constellations = PackedInt32Array([Constellations.STARFALL])
	CardLevels.set_level(w, W.item(w, &"ember_core"), 3)
	return w


func test_nothing_without_events() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	W.run(w, 5)
	_view.sync(r)
	assert_eq([_view.stars, _view.meteors, _view.blasts], [0, 0, 0])


func test_a_star_is_a_moon_blue_line_for_twelve_ticks() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_view.sync(r)
	var e := w.emit_event(SimEvent.Kind.STAR, 1, 1, 2, Vector2(5, 5))
	e.amount = 10
	_view.sync(r)
	assert_eq(_view.stars, 1)
	assert_true(_view._star_nodes[0].visible)
	var mat := _view._star_nodes[0].material_override as StandardMaterial3D
	assert_eq(mat.albedo_color, Color("#8FB8E8"))
	W.run(w, StarfallView.STAR_TICKS + 1)
	_view.sync(r)
	assert_eq(_view.stars, 0, "gone after 0.2 s")
	assert_false(_view._star_nodes[0].visible)


func test_a_meteor_falls_then_blasts_and_the_draw_is_capped() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_view.sync(r)
	W.run(w, 1)
	for k in 5:
		Starfall.on_root_attack(w, 100)
	_view.sync(r)
	assert_eq(_view.meteors, 1, "the streak while it falls")
	W.run(w, Starfall.METEOR_DELAY_TICKS + 2)
	_view.sync(r)
	assert_eq(_view.meteors, 0)
	assert_eq(_view.blasts, 1, "then the small blast ring")
	for k in 20:
		w.emit_event(SimEvent.Kind.STAR, 1, 1, 2, Vector2(5, 5))
	_view.sync(r)
	assert_eq(_view.stars, StarfallView.MAX_DRAWN, "at most 8 drawn")
