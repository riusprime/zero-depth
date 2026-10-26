extends GutTest
## v0.9.0 VP (owner C §6.4: "The visual should communicate a moving gravitational anomaly, not a stationary vortex";
## PLAN C56): the Void's view. A Void shot is drawn as a travelling lensing sphere (a dark core, its lens and dust, a
## trail of dust behind it, a faint ring at its aura's reach) where the sim has it, moving with it, and not as the
## Gun's pulse; the enemies it pulls lean into it; its shot has its hum; the floor black hole's view is gone.

const W := preload("res://tests/support/mx4_world.gd")

var _view: VoidView


func before_each() -> void:
	_view = add_child_autofree(VoidView.new())


func _world(items: Array = [], at: Array = [[Vector2(4.0, 2.0), 100000]]) -> World:
	var ids: Array = [&"gun_void"]
	ids.append_array(items)
	return W.world(&"gun", ids, at)


## The first visible child of the view whose mesh is `kind` (the core is the sphere).
func _core_pos() -> Vector3:
	for c in _view.get_children():
		var m := c as MeshInstance3D
		if m != null and m.visible and m.mesh is SphereMesh:
			return m.global_position
	return Vector3.INF


func test_a_void_shot_is_a_travelling_lens_not_a_pulse() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var pulses: HeroPulseViews = add_child_autofree(HeroPulseViews.new())
	W.run(w, 4, 0, W.S)
	_view.sync(r)
	pulses.sync(r)
	assert_eq(
		[_view.voids, _view.puffs], [1, VoidView.TRAIL], "one shot in flight, its trail behind"
	)
	assert_eq(pulses.count(), 0, "not drawn as a pulse")
	assert_true(r.projectile_is_void(0))
	var shots := r.void_shots()
	var first := _core_pos()
	assert_almost_eq(
		first.x, (shots[0]["pos"] as Vector2).x, 0.001, "the core where the sim has the shot"
	)
	W.run(w, 10, 0, 0)
	_view.sync(r)
	var later := _core_pos()
	assert_gt(
		later.x - first.x, 1.0, "it moves with the shot: a moving anomaly, not a standing vortex"
	)
	W.run(w, 80, 0, 0)
	_view.sync(r)
	assert_eq([_view.voids, _view.puffs], [0, 0], "gone with the shot")


func test_twin_draws_each_void() -> void:
	var w := _world([&"gun_twin"], [])
	var r := WorldReader.new(w)
	W.run(w, 3, 0, W.S)
	_view.sync(r)
	assert_eq(_view.voids, 2)


## v0.9.5 FC3: Ring's lightning ring grows where a void ended, and an Echo's still void is drawn like any other.
func test_fc3_the_ring_is_drawn_growing_and_a_still_echo_void_is_a_void() -> void:
	var w := _world([&"gun_ring", &"gun_echo"], [])
	var r := WorldReader.new(w)
	var seen := 0
	var echoes := 0
	for k in 100:
		W.run(w, 1, 0, W.S if k == 0 else 0)
		_view.sync(r)
		seen = maxi(seen, _view.arcs)
		echoes = maxi(echoes, _view.voids if k > 68 else 0)
	assert_gte(seen, 1, "a lightning ring is drawn while it grows")
	assert_eq(r.void_rings().size(), 0, "and it is gone")
	assert_gte(echoes, 1, "the echo void is drawn")


func test_pulled_enemies_lean_into_it() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var actors: ActorViews = add_child_autofree(ActorViews.new())
	W.run(w, 16, 0, W.S)
	var leans := r.void_leans()
	var id := w.actors.ids[1]
	assert_true(leans.has(id), "the enemy beside its path is drawn")
	assert_lt((leans[id] as Vector2).y, 0.0, "toward the path")
	actors.sync(r)
	var facing: Node3D = actors.actor_node(id).get_meta(&"facing")
	var up := facing.global_transform.basis.y
	assert_gt(up.z, 0.01, "its body tilts toward the path (sim -y is world +z)")


func test_the_shot_hums_and_the_black_hole_view_is_gone() -> void:
	var audio: AudioDirector = add_child_autofree(AudioDirector.new())
	var w := _world()
	var r := WorldReader.new(w)
	audio.attach(r, &"")
	for k in 6:
		W.run(w, 1, 0, W.S if k == 0 else 0)
		audio.sync(r)
	assert_true(audio.played_log.has(&"void_hum"), "the Void's hum")
	assert_false(audio.played_log.has(&"bolt_fire"), "not the orb's shot")
	assert_not_null(audio.stream_for(&"void_hum"), "the placeholder file")
	assert_false(FileAccess.file_exists("res://src/presentation/world_view/black_hole_views.gd"))
	assert_false(r.has_method(&"black_holes"), "the reader has no floor black holes")
