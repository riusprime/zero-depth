extends GutTest
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F5) and AF1b (owner: "a circle in front of the player that circles like a
## charging energy and then shoots"): the Lance's view. While it charges, a swirling circle in front of the hero (where
## the sim's ball sits, Lance.orb) that grows with the ball and brightens with the charge; nothing while nothing
## charges; each release bursts at the muzzle (bigger for a bigger ball) and fades; the ball in flight is the orb's
## look, drawn twice as big at full; the element sets the look; the Charge card's swelling orb is not drawn for the
## Lance.

const W := preload("res://tests/support/mx4_world.gd")

var _view: LanceView


func before_each() -> void:
	_view = add_child_autofree(LanceView.new())


func _world(items: Array = [], at: Array = [[Vector2(4.0, 0.0), 100000]]) -> World:
	var ids: Array = [&"gun_lance"]
	ids.append_array(items)
	return W.world(&"gun", ids, at)


func test_charging_shows_a_growing_circle_in_front_of_the_hero() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_view.sync(r)
	assert_eq([_view.circle, _view.bursts], [false, 0], "nothing before the trigger")
	W.run(w, 18, 0, W.S)
	_view.sync(r)
	assert_true(_view.circle, "the circle while charging")
	assert_almost_eq(_view.charge, 0.25, 1e-6)
	var small := _view.circle_size
	var at := _view._circle.position
	assert_gt(at.x, w.player.radius_m, "in front of the hero, along the aim")
	var energy := float(_view._circle_mat.get_shader_parameter(&"energy"))
	W.run(w, 54, 0, W.S)
	_view.sync(r)
	assert_almost_eq(_view.charge, 1.0, 1e-6, "full")
	assert_gt(_view.circle_size, small, "the circle grew")
	assert_gt(float(_view._circle_mat.get_shader_parameter(&"energy")), energy, "and brightened")
	assert_eq(float(_view._circle_mat.get_shader_parameter(&"full")), 1.0, "it pulses full")
	var orb := r.lance_orb()
	assert_almost_eq(
		_view.circle_size,
		2.0 * (float(orb["radius"]) * LanceView.CIRCLE_RADII + LanceView.CIRCLE_PAD_M),
		1e-4,
		"sized from the sim's ball"
	)


func test_a_release_bursts_at_the_muzzle_and_fades() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_view.sync(r)
	W.run(w, 72, 0, W.S)
	W.run(w, 1, 0, 0)
	_view.sync(r)
	assert_eq([_view.circle, _view.bursts], [false, 1], "released: the circle goes, one burst")
	assert_eq(_view.last_burst_charge, 11600, "a full charge's burst")
	var orb_r := Modifiers.bolt(W.world(&"gun")).radius_m
	assert_almost_eq(_view.last_burst_radius, orb_r * 2.0, 0.002, "a full ball: twice the orb")
	var big := _view._burst_nodes[0].scale.x
	W.run(w, 14, 0, 0)
	_view.sync(r)
	assert_eq(_view.bursts, 0, "faded")
	var t := _world()
	var tap_r := WorldReader.new(t)
	_view = add_child_autofree(LanceView.new())
	_view.sync(tap_r)
	W.run(t, 1, 0, W.S)
	W.run(t, 1, 0, 0)
	_view.sync(tap_r)
	assert_almost_eq(_view.last_burst_radius, orb_r, orb_r * 0.02, "a tap: orb-sized")
	assert_lt(_view._burst_nodes[0].scale.x, big, "a smaller burst")


func test_the_ball_in_flight_is_the_orbs_look_twice_as_big_at_full() -> void:
	var w := _world([], [])
	var r := WorldReader.new(w)
	var forms: AttackFormView = add_child_autofree(AttackFormView.new())
	W.run(w, 72, 0, W.S)
	W.run(w, 3, 0, 0)
	forms._sync_bolts(r)
	assert_eq(forms._live.size(), 1, "the ball drawn as a bolt")
	assert_almost_eq(float(forms._live[0]["scale"]), 2.0, 0.01, "× 2 at full")


func test_the_element_sets_the_look() -> void:
	var w := _world([&"gun_twin", &"ember_core"])
	var r := WorldReader.new(w)
	W.run(w, 10, 0, W.S)
	_view.sync(r)
	assert_true(_view.circle)
	assert_eq(_view.look, &"fire")


func test_the_charge_orb_of_the_old_card_is_not_drawn_for_the_lance() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var forms: AttackFormView = add_child_autofree(AttackFormView.new())
	W.run(w, 30, 0, W.S)
	forms._live.clear()
	forms._sync_charge(r)
	assert_eq(forms._live.size(), 0, "LanceView draws the Lance's charge")


## v0.9.5 FC4: Ring's lightning ring grows where a lance ended, and Split's shards are in view while they last.
func test_fc4_the_ring_is_drawn_growing_and_split_shards_are_in_view() -> void:
	var w := _world([&"gun_ring"], [])
	var r := WorldReader.new(w)
	W.run(w, 72, 0, W.S)
	var seen := 0
	for k in 120:
		W.run(w, 1, 0, 0)
		_view.sync(r)
		seen = maxi(seen, _view.arcs)
	assert_gte(seen, 1, "a lightning ring is drawn while it grows")
	assert_eq(r.lance_rings().size(), 0, "and it is gone")
	var s := _world([&"split_shot"], [[Vector2(3.0, 0.0), 100000]])
	var sr := WorldReader.new(s)
	W.run(s, 72, 0, W.S)
	var shown := 0
	for k in 40:
		W.run(s, 1, 0, 0)
		_view.sync(sr)
		shown = maxi(shown, _view.shards)
	assert_eq(shown, 2, "the pierced enemy spat two shards")
	assert_eq(sr.lance_shards().size(), 0, "and they are gone")
