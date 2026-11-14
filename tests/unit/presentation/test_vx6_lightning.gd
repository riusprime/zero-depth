extends GutTest
## v0.10.0 VX6 (VFX_PACK N1): lightning in the pack style. The ZdBolt is deterministic and jagged, a bolt or chain line,
## a shock field, ring or burst and the shock on an enemy draw the pack's bolts (family bolt) and areas, held ones go
## back the frame they stop, and a full family keeps that instance's old sprite look.

const A := Vector3(0, 0.6, 0)
const B := Vector3(4, 0.6, 3)

var _layer: VfxLayer
var _fx: PackFx
var _saved := ""


func before_each() -> void:
	_saved = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	_layer = add_child_autofree(VfxLayer.new())
	_fx = add_child_autofree(PackFx.new())
	_layer.pack_fx = _fx


func after_each() -> void:
	ViewPrefs.effects_density = _saved


func _frame(now: float, draw: Callable) -> void:
	_layer.begin(now)
	draw.call()
	_layer.finish()


func _live(id: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Dictionary in _fx.get(&"_live"):
		if e["id"] == id:
			out.append(e["node"])
	return out


func _bolt() -> ZdBolt:
	var b := add_child_autofree(ZdBolt.new()) as ZdBolt
	b.visible = true
	return b


# --- The bolt ------------------------------------------------------------------------------------------------------
func test_the_table_has_the_vx6_ids_in_their_families() -> void:
	assert_true(_fx.has_id(&"vx6_bolt"))
	assert_true(_fx.has_id(&"vx6_field"))
	assert_true(_fx.has_id(&"vx6_ring"))
	assert_true(_fx.has_id(&"vx6_burst"))
	var n := _fx.spawn(&"vx6_bolt", A, 1.0, StormPack.colors(), 0.0)
	assert_not_null(n)
	assert_true(n is ZdBolt)
	assert_eq(_fx.live_count(&"bolt"), 1)
	assert_eq(_fx.cap_for(&"bolt"), 48)


func test_a_bolt_is_six_to_ten_segments_and_jitters_up_to_twelve_percent() -> void:
	var span := A.distance_to(B)
	for sd in 40:
		var b := _bolt()
		b.set_ends(A, B, sd * 17 + 3)
		var main: Array = b.lines()[0]
		assert_between(main.size() - 1, 6, 10, "segments, seed %d" % sd)
		assert_eq(main[0], A - b.position, "starts at a")
		assert_eq(main[main.size() - 1], B - b.position, "ends at b")
		for p: Vector3 in main:
			var along := (p - (A - b.position)).dot((B - A) / span)
			var off := ((p - (A - b.position)) - (B - A) / span * along).length()
			assert_lt(off, span * ZdBolt.JITTER * 1.2, "within the jitter")


func test_a_bolt_is_deterministic_and_has_up_to_two_forks() -> void:
	var one := _bolt()
	var two := _bolt()
	one.set_ends(A, B, 77)
	two.set_ends(A, B, 77)
	assert_eq(one.lines(), two.lines(), "same seed, same bolt")
	var most := 0
	var other := _bolt()
	other.set_ends(A, B, 78)
	assert_ne(one.lines(), other.lines(), "another seed, another bolt")
	for sd in 60:
		var b := _bolt()
		b.set_ends(A, B, sd)
		most = maxi(most, b.lines().size() - 1)
	assert_eq(most, 2, "no more than two forks, and some have two")


func test_a_bolt_rejitters_while_it_lives_and_fades_out() -> void:
	var b := _bolt()
	b.fade_time = 0.18
	b.set_ends(A, B, 5)
	var first: Array = b.lines()[0]
	b._process(ZdBolt.FLICKER_S + 0.001)
	assert_ne(b.lines()[0], first, "re-jittered")
	assert_gte(b.rebuilds, 2)
	var bright := b.brightness()
	b._process(0.2)
	assert_lt(b.brightness(), bright)
	assert_lt(b.brightness(), 0.05, "gone after its fade")


func test_a_bolt_draws_a_two_layer_ribbon_shell_then_core() -> void:
	var b := _bolt()
	b.set_ends(A, B, 9, 0.12)
	var shell := b.get_child(0) as MeshInstance3D
	var core := b.get_child(1) as MeshInstance3D
	assert_true(shell.get_surface_override_material(0).get_shader_parameter(&"outer"), "shell")
	assert_false(core.get_surface_override_material(0).get_shader_parameter(&"outer"), "core")
	assert_gt(core.sorting_offset, shell.sorting_offset, "the core always draws over its shell")


# --- Where bolts go ------------------------------------------------------------------------------------------------
func test_a_strike_line_is_a_held_pack_bolt_with_a_spark() -> void:
	_frame(10.0, func() -> void: _layer.line(&"storm", A, B, 0.8, 0.0, 41))
	assert_eq(_live(&"vx6_bolt").size(), 1)
	assert_eq(_layer.used(&"bolt"), 0, "no sprite bolt")
	assert_eq(_live(&"vx1_hit_storm").size(), 1, "the spark at the end")
	_frame(11.0, func() -> void: _layer.line(&"storm", A, B + Vector3(0.1, 0, 0), 0.7, 1.0, 41))
	assert_eq(_live(&"vx6_bolt").size(), 1, "the same bolt")
	assert_eq(_live(&"vx1_hit_storm").size(), 1, "one spark a strike")
	_frame(12.0, func() -> void: pass)
	assert_eq(_live(&"vx6_bolt").size(), 0, "gone the frame it is not drawn")


func test_one_seed_can_draw_several_lines() -> void:
	_frame(
		10.0,
		func() -> void:
			for k in 3:
				_layer.line(&"storm", A, B + Vector3(k, 0, 0), 1.0, 0.0, 9)
	)
	assert_eq(_live(&"vx6_bolt").size(), 3, "a discharge's chain")


func test_a_storm_field_holds_a_ripple_and_a_few_bolts() -> void:
	_frame(10.0, func() -> void: _layer.field(&"storm", Vector3(2, 0, 2), 2.0, 1.0, 10.0, 5))
	assert_eq(_live(&"vx6_field").size(), 1)
	assert_between(_live(&"vx6_bolt").size(), 2, 4)
	assert_eq(_layer.used(&"bolt"), 0)
	_frame(11.0, func() -> void: pass)
	assert_eq(_live(&"vx6_field").size(), 0)
	assert_eq(_live(&"vx6_bolt").size(), 0)


func test_a_storm_ring_holds_a_rim_and_bolts_along_it() -> void:
	_frame(10.0, func() -> void: _layer.ring(&"storm", Vector3(2, 0, 2), 3.0, 1.0, 10.0, 6))
	assert_eq(_live(&"vx6_ring").size(), 1)
	assert_gte(_live(&"vx6_bolt").size(), 3)


func test_a_travelling_ring_followed_by_its_seed_keeps_its_rim_and_bolts_as_it_flies() -> void:
	var at := func(k: int) -> Vector3: return Vector3(2 + 0.3 * k, 0, 2 + 0.2 * k)
	_frame(10.0, func() -> void: _layer.ring(&"storm", at.call(0), 3.0, 1.0, 10.0, 6, true))
	var rim := _live(&"vx6_ring")
	assert_eq(rim.size(), 1)
	var spawned := _fx.spawned
	for k in range(1, 11):
		var t := 10.0 + k
		_frame(t, func() -> void: _layer.ring(&"storm", at.call(k), 3.0, 1.0, t, 6, true))
	assert_eq(_fx.spawned, spawned, "nothing taken again from PackFx while the ring moved 3.6 m")
	assert_eq(_live(&"vx6_ring"), rim, "the same rim, following the ring")
	assert_almost_eq(rim[0].global_position.x, (at.call(10) as Vector3).x, 0.001)
	var anim := rim[0].get_node("AnimationPlayer") as AnimationPlayer
	assert_almost_eq(anim.current_animation_position, 0.0, 0.0001, "held at its animation's start")


func test_a_storm_burst_is_one_pulse_and_three_to_five_bolts() -> void:
	for u in [0.1, 0.2, 0.3]:
		_frame(10.0 + u, func() -> void: _layer.burst(&"storm", Vector3(2, 0, 2), 2.0, u, 8))
	assert_between(_live(&"vx6_bolt").size(), 3, 5)
	assert_eq(_live(&"vx6_burst").size(), 1, "spawned once")


func test_a_shocked_enemy_has_two_small_forks_round_the_body() -> void:
	_frame(10.0, func() -> void: _layer.status(Vector3(1, 0, 1), 0.4, {&"shock": 2}, 12, 0.9))
	var bolts := _live(&"vx6_bolt")
	assert_eq(bolts.size(), 2)
	for b: Node3D in bolts:
		var z := b as ZdBolt
		for poly: Array in z.lines():
			for p: Vector3 in poly:
				assert_lt(
					(p + z.position - Vector3(1, 0.45, 1)).length(),
					0.9,
					"within about 0.5 m of the body's middle"
				)


func test_a_full_bolt_family_keeps_the_old_sprites_for_that_line() -> void:
	while _fx.has_room(&"bolt"):
		_fx.spawn(&"vx6_bolt", A, 1.0, {}, 0.0)
	_frame(10.0, func() -> void: _layer.line(&"storm", A, B, 0.8, 0.0, 41))
	assert_gt(_layer.used(&"bolt"), 0, "the sprite bolt")


func test_without_a_pack_the_old_look_draws() -> void:
	_layer.pack_fx = null
	_frame(10.0, func() -> void: _layer.line(&"storm", A, B, 0.8, 0.0, 41))
	assert_gt(_layer.used(&"bolt"), 0)
	_frame(11.0, func() -> void: _layer.field(&"storm", Vector3(2, 0, 2), 2.0, 1.0, 10.0, 5))
	assert_gt(_layer.used(&"bolt"), 0)


func test_a_full_area_family_keeps_the_old_field() -> void:
	while _fx.has_room(&"area"):
		_fx.spawn(&"vx6_field", A, 1.0, {}, 0.0)
	_frame(10.0, func() -> void: _layer.field(&"storm", Vector3(2, 0, 2), 2.0, 1.0, 10.0, 5))
	assert_eq(_live(&"vx6_bolt").size(), 0)
	assert_gt(_layer.used(&"bolt"), 0, "sprite bolts")


func test_the_pack_bolts_are_in_the_storms_colours() -> void:
	var n := _fx.spawn(&"vx6_bolt", A, 1.0, StormPack.colors(), 0.0) as ZdBolt
	assert_eq(n.primary_color, ElementLooks.hot(&"storm"))
	assert_eq(n.tertiary_color, ElementLooks.deep(&"storm"))


func test_arc_field_bolts_are_pack_bolts() -> void:
	var view := add_child_autofree(ElementVisuals.new()) as ElementVisuals
	view.pack_fx = _fx
	view._bolt(Vector2(0, 0), Vector2(3, 2), Color.WHITE, 0.07, &"arc")
	assert_eq(_live(&"vx6_bolt").size(), 1)
	assert_eq(view.fx_count_of(&"arc"), 0, "no box bolt")
	view.pack_fx = null
	view._bolt(Vector2(0, 0), Vector2(3, 2), Color.WHITE, 0.07, &"arc")
	assert_gt(view.fx_count_of(&"arc"), 0, "the boxes without a pack")
