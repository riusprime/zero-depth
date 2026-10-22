extends GutTest
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F5): the Lance's view. While it charges, an aim line per Lance line (the sim's
## own trace) and a muzzle glow that grows with the charge; nothing while nothing charges; each release flashes along
## its line (as long as the line, wider for a bigger charge) and fades; Twin shows two lines; the element sets the look;
## the Charge card's swelling orb is not drawn for the Lance.

const W := preload("res://tests/support/mx4_world.gd")

var _view: LanceView


func before_each() -> void:
	_view = add_child_autofree(LanceView.new())


func _world(items: Array = [], at: Array = [[Vector2(4.0, 0.0), 100000]]) -> World:
	var ids: Array = [&"gun_lance"]
	ids.append_array(items)
	return W.world(&"gun", ids, at)


func test_charging_shows_the_aim_line_and_a_growing_glow() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_view.sync(r)
	assert_eq([_view.aims, _view.flashes], [0, 0], "nothing before the trigger")
	W.run(w, 18, 0, W.S)
	_view.sync(r)
	assert_eq(_view.aims, 1, "one aim line while charging")
	assert_almost_eq(_view.charge, 0.25, 1e-6)
	var small := _view._muzzle.scale.x
	W.run(w, 54, 0, W.S)
	_view.sync(r)
	assert_almost_eq(_view.charge, 1.0, 1e-6, "full")
	assert_gt(_view._muzzle.scale.x, small, "the glow grew")
	var l: Dictionary = r.lance_lines()[0]
	assert_almost_eq(
		(l["to"] as Vector2).x, w.player.radius_m + 10.8, 0.05, "through the enemy, its whole reach"
	)


func test_a_release_flashes_along_the_line_and_fades() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_view.sync(r)
	W.run(w, 72, 0, W.S)
	W.run(w, 1, 0, 0)
	_view.sync(r)
	assert_eq([_view.aims, _view.flashes], [0, 1], "released: the aim line goes, one flash")
	assert_eq(_view.last_flash_charge, 5000, "a full charge's flash")
	var f: Array = _view._live[0]
	assert_almost_eq(
		((f[1] as Vector2) - (f[0] as Vector2)).length(), 10.8, 0.05, "as long as the line"
	)
	assert_almost_eq(float(f[4]), LanceView.FLASH_W.y, 1e-4, "full charge: the widest flash")
	W.run(w, 20, 0, 0)
	_view.sync(r)
	assert_eq(_view.flashes, 0, "faded")
	var t := _world()
	var tap_r := WorldReader.new(t)
	_view = add_child_autofree(LanceView.new())
	_view.sync(tap_r)
	W.run(t, 1, 0, W.S)
	W.run(t, 1, 0, 0)
	_view.sync(tap_r)
	assert_lt(float(_view._live[0][4]), LanceView.FLASH_W.x + 0.02, "a tap: the thinnest flash")


func test_twin_shows_two_lines_and_the_element_sets_the_look() -> void:
	var w := _world([&"gun_twin", &"ember_core"])
	var r := WorldReader.new(w)
	W.run(w, 10, 0, W.S)
	_view.sync(r)
	assert_eq(_view.aims, 2)
	assert_eq(_view.look, &"fire")


func test_the_charge_orb_of_the_old_card_is_not_drawn_for_the_lance() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var forms: AttackFormView = add_child_autofree(AttackFormView.new())
	W.run(w, 30, 0, W.S)
	forms._live.clear()
	forms._sync_charge(r)
	assert_eq(forms._live.size(), 0, "LanceView draws the Lance's charge")
