extends GutTest
## v0.6.5 WN3 (docs/design/WAND.md rule 7: "Every card is visible on the attack itself"): the Gun cards' looks come
## from the bolt's final spec through AttackFormLooks (never from the cards held), and AttackFormView draws the new
## behaviours from the sim's own numbers: a charging shot's orb swelling in the barrel, a charged bolt bigger than its
## spec, a waiting mine's ground ring. Presentation only: it reads (EI-07).

const S := InputFrame.SHOOT

var _view: AttackFormView


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_view = add_child_autofree(AttackFormView.new())


func _f(held: int = 0) -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 300, held, 0)


func _step(w: World, r: WorldReader, n: int, held: int = 0) -> void:
	for k in n:
		w.step(_f(held))
		_view.sync(r)


func test_the_new_behaviours_are_cues_on_the_spec() -> void:
	var cues := AttackFormLooks.cues_of(
		{"twin": 1, "spiral": 398, "mine_ticks": 180, "hold_ticks": 60}
	)
	assert_eq(cues, [&"twin", &"helix", &"mine", &"swell"] as Array[StringName])
	assert_eq(AttackFormLooks.cues_of({}), [] as Array[StringName], "a plain bolt has none")
	var look := AttackFormLooks.compose({"form": AttackFormLooks.BOLT, "spiral": 398})
	assert_true(AttackFormView.adds_layer(look), "a cue draws over the plain dart")


func test_a_charging_shot_swells_in_the_barrel() -> void:
	var w := Mx4World.world(&"gun", [&"gun_charge"])
	var r := WorldReader.new(w)
	_step(w, r, 10, S)
	assert_almost_eq(r.gun_charge(), 10.0 / 60.0, 1e-6)
	_view.draw_at(float(r.tick()))
	assert_eq(_view.live_count(), 1, "the orb is drawn while nothing has fired")
	var small := _view.pool(&"bolt_core").instance_transform(0).basis.x.length()
	_step(w, r, 40, S)
	_view.draw_at(float(r.tick()))
	var big := _view.pool(&"bolt_core").instance_transform(0).basis.x.length()
	assert_gt(big, small * 1.5, "it grows as the charge does")
	_step(w, r, 1)
	assert_eq(r.gun_charge(), 0.0, "released: fired")


func test_a_charged_bolt_is_drawn_bigger_than_its_spec() -> void:
	var look := AttackFormLooks.compose({"form": AttackFormLooks.BOLT, "radius_m": 0.16})
	assert_almost_eq(AttackFormView.live_scale(look, 0.32), 2.0, 1e-6)
	assert_almost_eq(AttackFormView.live_scale(look, 0.16), 1.0, 1e-6)
	assert_almost_eq(AttackFormView.live_scale({}, 0.5), 1.0, 1e-6, "no spec radius: as is")


func test_a_waiting_mine_has_a_ground_ring() -> void:
	var w := Mx4World.world(&"gun", [&"gun_mine"])
	var r := WorldReader.new(w)
	_step(w, r, 1, S)
	_step(w, r, Modifiers.bolt(w).life_ticks + 5)
	_view.draw_at(float(r.tick()))
	assert_eq(_view.live_count(), 1, "the mine is a live bolt")
	assert_gt(_view.pool(&"ring_fill").used, 0, "with its ring on the floor")
	var c := _view.pool(&"ring_fill").instance_color(0)
	assert_false(AttackFormLooks.is_hostile_hue(c), "never a telegraph hue")
