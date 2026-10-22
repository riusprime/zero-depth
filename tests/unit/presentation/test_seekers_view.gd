extends GutTest
## v0.9.0 AF2 (owner Q7; ATTACK_FORMS.md F8): the Seekers' view. Each dart in flight is a needle (SeekersView, not the
## pulses or the bolt layer) trailing motes where it was; the element sets the look; nothing when no dart flies; the
## volley is heard.

const W := preload("res://tests/support/mx4_world.gd")

var _view: SeekersView


func before_each() -> void:
	_view = add_child_autofree(SeekersView.new())


func _world(items: Array = []) -> World:
	var ids: Array = [&"gun_seekers"]
	ids.append_array(items)
	return W.world(&"gun", ids)


func test_a_volley_shows_three_needles_whose_trails_grow_then_go() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_view.sync(r)
	assert_eq([_view.darts, _view.motes], [0, 0])
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq([_view.darts, _view.motes], [3, 0], "three darts, no trail yet")
	for k in 6:
		W.run(w, 1, 0, 0)
		_view.sync(r)
	assert_eq([_view.darts, _view.motes], [3, 3 * SeekersView.TRAIL], "each trails its motes")
	W.run(w, 60, 0, 0)
	_view.sync(r)
	assert_eq([_view.darts, _view.motes], [0, 0], "gone")


func test_darts_are_not_drawn_as_pulses_or_bolt_layers() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	for i in r.projectile_count():
		assert_true(r.projectile_is_dart(i), "every shot is a dart")
	var forms: AttackFormView = add_child_autofree(AttackFormView.new())
	forms._sync_bolts(r)
	assert_eq(forms._live.size(), 0, "no bolt layer for a dart")
	var orbs := W.world(&"gun")
	W.run(orbs, 1, 0, W.S)
	assert_false(WorldReader.new(orbs).projectile_is_dart(0), "an orb is no dart")


func test_the_element_sets_the_look() -> void:
	var w := _world([&"venom_core"])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq(_view.look, &"venom")


func test_the_volley_is_heard() -> void:
	var audio: AudioDirector = add_child_autofree(AudioDirector.new())
	var w := _world()
	var r := WorldReader.new(w)
	audio.attach(r, &"")
	for k in 6:
		W.run(w, 1, 0, W.S if k == 0 else 0)
		audio.sync(r)
	assert_true(audio.played_log.has(&"seekers_fire"), "the Seekers' volley")
	assert_false(audio.played_log.has(&"bolt_fire"), "not the orb's shot")
	assert_not_null(audio.stream_for(&"seekers_fire"), "the placeholder file")
