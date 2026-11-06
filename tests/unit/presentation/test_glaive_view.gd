extends GutTest
## v0.9.0 AF2 (owner Q7; ATTACK_FORMS.md F7): the Glaive's view. Each disc in flight is a spinning disc (GlaiveView,
## not the pulses or the bolt layer) with its afterimages; on the way back it reads as coming back; the element sets
## the look; nothing when no disc flies; the throw is heard.

const W := preload("res://tests/support/mx4_world.gd")

var _view: GlaiveView


func before_each() -> void:
	_view = add_child_autofree(GlaiveView.new())


func _world(items: Array = []) -> World:
	var ids: Array = [&"gun_glaive"]
	ids.append_array(items)
	return W.world(&"gun", ids)


func test_a_throw_shows_one_disc_that_comes_back_and_is_gone() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_view.sync(r)
	assert_eq(_view.discs, 0)
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq([_view.discs, _view.returning], [1, 0], "one disc going out")
	W.run(w, 40, 0, 0)
	_view.sync(r)
	assert_eq([_view.discs, _view.returning], [1, 1], "on its way back")
	W.run(w, 40, 0, 0)
	_view.sync(r)
	assert_eq(_view.discs, 0, "caught")


func test_discs_are_not_drawn_as_pulses_or_bolt_layers() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	for i in r.projectile_count():
		assert_true(r.projectile_is_disc(i), "every shot is a disc")
	var forms: AttackFormView = add_child_autofree(AttackFormView.new())
	forms._sync_bolts(r)
	assert_eq(forms._live.size(), 0, "no bolt layer for a disc")
	var orbs := W.world(&"gun")
	W.run(orbs, 1, 0, W.S)
	assert_false(WorldReader.new(orbs).projectile_is_disc(0), "an orb is no disc")


func test_the_element_sets_the_look() -> void:
	var w := _world([&"storm_core"])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq(_view.look, &"lightning")


func test_the_throw_is_heard() -> void:
	var audio: AudioDirector = add_child_autofree(AudioDirector.new())
	var w := _world()
	var r := WorldReader.new(w)
	audio.attach(r, &"")
	for k in 6:
		W.run(w, 1, 0, W.S if k == 0 else 0)
		audio.sync(r)
	assert_true(audio.played_log.has(&"glaive_throw"), "the Glaive's throw")
	assert_false(audio.played_log.has(&"bolt_fire"), "not the orb's shot")
	assert_not_null(audio.stream_for(&"glaive_throw"), "the placeholder file")


func test_the_ring_card_draws_a_lightning_ring_round_each_disc() -> void:
	var w := _world([&"gun_ring"])
	var r := WorldReader.new(w)
	_view.sync(r)
	assert_eq(_view.arcs, 0, "no disc, no ring")
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq([_view.discs, _view.arcs], [1, 1], "a ring round the disc")
	var rings := r.glaive_rings()
	assert_almost_eq(float(rings[0]["r"]), 1.0, 0.001, "1 m")
	var plain := _world()
	W.run(plain, 1, 0, W.S)
	_view.sync(WorldReader.new(plain))
	assert_eq(_view.arcs, 0, "a plain disc has none")
