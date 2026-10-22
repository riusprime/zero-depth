extends GutTest
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F6): the Scatter's view. Each pellet in flight is a slug (ScatterView, not the
## pulses or the bolt layer); each volley opens one muzzle cone that fades; the element sets the look; nothing when no
## pellet flies.

const W := preload("res://tests/support/mx4_world.gd")

var _view: ScatterView


func before_each() -> void:
	_view = add_child_autofree(ScatterView.new())


func _world(items: Array = []) -> World:
	var ids: Array = [&"gun_scatter"]
	ids.append_array(items)
	return W.world(&"gun", ids)


func test_a_volley_shows_six_slugs_and_a_cone_that_fades() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_view.sync(r)
	assert_eq([_view.pellets, _view.cones], [0, 0])
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq([_view.pellets, _view.cones], [6, 1], "six pellets, one cone")
	W.run(w, 2, 0, 0)
	_view.sync(r)
	assert_eq(_view.cones, 1, "the same volley: no new cone")
	W.run(w, 20, 0, 0)
	_view.sync(r)
	assert_eq([_view.pellets, _view.cones], [0, 0], "gone at 5 m; the cone faded")


func test_pellets_are_not_drawn_as_pulses_or_bolt_layers() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	for i in r.projectile_count():
		assert_true(r.projectile_is_pellet(i), "every shot is a pellet")
	var forms: AttackFormView = add_child_autofree(AttackFormView.new())
	forms._sync_bolts(r)
	assert_eq(forms._live.size(), 0, "no bolt layer for a pellet")
	var orbs := W.world(&"gun")
	W.run(orbs, 1, 0, W.S)
	assert_false(WorldReader.new(orbs).projectile_is_pellet(0), "an orb is no pellet")


func test_the_element_sets_the_look() -> void:
	var w := _world([&"frost_core"])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq(_view.look, &"frost")
