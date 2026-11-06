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
	W.run(w, 3, 0, W.S)
	_view.sync(r)  # (v0.10.5 W3-O8: the trail shows once the view has seen the shot move: a tick later)
	W.run(w, 1, 0, W.S)
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


## v0.10.5 W3-O8 (owner F11: Void "has some visual bugs, with split and mine"): Split's minis draw at their own
## (smaller) aura's size, stand without a dust trail, and the one that ends at once collapses from the size it was
## drawn at.
func test_w3o8_split_minis_are_smaller_still_and_collapse_from_their_size() -> void:
	var w := _world([&"split_shot"], [])
	var r := WorldReader.new(w)
	var mini_size := 0.0
	var mini_puffs := -1
	for k in 70:
		W.run(w, 1, 0, W.S if k == 0 else 0)
		_view.sync(r)
		for j in _view.voids:
			if _view.sizes[j] != 1.0 and not _view.moving[j]:
				mini_size = _view.sizes[j]
				mini_puffs = _view.puffs
		for c in _view.collapse_sizes:
			assert_lte(c, VoidView.SIZE_MAX, "a collapse never outgrows the body it was drawn at")
	# W3-P5 (ee6cf2ce): Split minis open with a 1.5 m aura (was 0.6 m), so they draw larger than the plain Void.
	assert_almost_eq(mini_size, VoidView.body_size(1.5), 0.001, "a mini (1.5 m aura) at its size")
	assert_gt(mini_size, 1.0, "sized by its own aura, not by the void it came from")
	assert_eq(mini_puffs, 0, "a still mini has no dust trail")
	assert_eq(VoidView.body_size(1.0), 1.0, "the plain Void keeps its look")
	assert_eq(
		[VoidView.body_size(0.1), VoidView.body_size(9.0)], [VoidView.SIZE_MIN, VoidView.SIZE_MAX]
	)


## W3-O8: a held Mine stands still (no trail, its way reads as +x in the sim) and its lens and dust draw in front of the
## enemies it pulls into its middle.
func test_w3o8_a_held_mine_has_no_trail_and_draws_in_front_of_its_catch() -> void:
	var w := _world([&"gun_mine"], [])
	var r := WorldReader.new(w)
	var flying := false
	var held := false
	for k in 90:
		W.run(w, 1, 0, W.S if k == 0 else 0, 0)
		_view.sync(r)
		if _view.voids == 1 and _view.moving[0]:
			flying = flying or _view.puffs == VoidView.TRAIL
		if _view.voids == 1 and k > 40 and not _view.moving[0]:
			held = _view.puffs == 0
	assert_true(flying, "in flight it trails dust")
	assert_true(held, "held, it has none")
	var lens_mat: ShaderMaterial = _view.get("_lens_mat")
	assert_eq(lens_mat.get_shader_parameter(&"to_cam"), VoidView.TO_CAMERA_M, "the lens: nearer")
	var dust: Array = _view.get("_dust_mats")
	assert_eq((dust[0] as ShaderMaterial).get_shader_parameter(&"to_cam"), VoidView.TO_CAMERA_M)
	var ring: ShaderMaterial = _view.get("_ring_mat")
	assert_eq(ring.get_shader_parameter(&"to_cam"), 0.0, "the ground ring stays on the ground")
