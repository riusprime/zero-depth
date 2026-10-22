extends GutTest
## v0.9.0 BM (owner C §6.3; PLAN C51): the Bomb's view. A thrown bomb is drawn as a faceted bomb with a fuse spark (and
## not as the Gun's pulse); its blast draws a ring at its radius in its element's look; the throw and the blast have
## their sounds.

const W := preload("res://tests/support/mx4_world.gd")

var _view: BombView


func before_each() -> void:
	_view = add_child_autofree(BombView.new())


func _world(items: Array = []) -> World:
	var ids: Array = [&"gun_bomb"]
	ids.append_array(items)
	return W.world(&"gun", ids, [[Vector2(4.0, 0.0), 100000]])


func test_a_bomb_flies_as_a_bomb_then_its_blast_rings_out() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var pulses: HeroPulseViews = add_child_autofree(HeroPulseViews.new())
	W.run(w, 4, 0, W.S)
	_view.sync(r)
	pulses.sync(r)
	assert_eq(_view.bombs, 1, "the bomb in flight")
	assert_eq(pulses.count(), 0, "not drawn as a pulse")
	assert_true(r.projectile_is_bomb(0))
	W.run(w, 20, 0, 0)
	_view.sync(r)
	assert_eq(
		[_view.bombs, _view.blasts, _view.last_look], [0, 1, &"default"], "it burst: one blast ring"
	)
	W.run(w, 30, 0, 0)
	_view.sync(r)
	assert_eq(_view.blasts, 0, "the ring fades")


func test_the_blast_takes_its_elements_look() -> void:
	for pair: Array in [
		[&"ember_core", &"fire"], [&"storm_core", &"lightning"], [&"venom_core", &"venom"]
	]:
		_view = add_child_autofree(BombView.new())  # a view per world, as each floor has its own
		var w := _world([pair[0]])
		var r := WorldReader.new(w)
		_view.sync(r)
		W.run(w, 24, 0, W.S)
		_view.sync(r)
		assert_eq(_view.last_look, pair[1], "%s's blast" % pair[0])


func test_the_throw_and_the_blast_sound() -> void:
	var audio: AudioDirector = add_child_autofree(AudioDirector.new())
	var w := _world()
	var r := WorldReader.new(w)
	audio.attach(r, &"")
	for k in 24:
		W.run(w, 1, 0, W.S if k == 0 else 0)
		audio.sync(r)
	assert_true(audio.played_log.has(&"bomb_throw"), "the toss")
	assert_false(audio.played_log.has(&"bolt_fire"), "not the orb's shot")
	assert_true(audio.played_log.has(&"bomb_blast"), "the blast")
	assert_not_null(audio.stream_for(&"bomb_throw"), "the placeholder file")
