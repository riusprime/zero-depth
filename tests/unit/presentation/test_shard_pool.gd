extends GutTest
## A dead enemy's cubes are instances of one multimesh per look, and last half a second of real time.


func _setup() -> Array:
	var w := World.new(3, PlayerTable.starting_values())
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	views.set_process(false)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var feel := HitFeel.new(views, rig)
	add_child_autofree(feel)
	views.sync(reader)
	return [w, reader, feel]


func _kill(w: World, n: int) -> void:
	for i in n:
		w.add_dummy(Vector2(2.0 + i * 0.1, 0), 0.35, 10)
		Damage.hit(w, w.actors.ids.size() - 1, 9999, 2, 2, 2, 0, Vector2.ZERO, Vector2(2.0, 0))


func _pool(feel: HitFeel) -> ShardPool:
	return feel.get_child(0) as ShardPool


func test_a_kill_throws_pieces_of_one_multimesh_not_nodes() -> void:
	var s := _setup()
	var feel: HitFeel = s[2]
	_kill(s[0], 1)
	feel.sync(s[1])
	assert_eq(feel.spark_count(), HitFeel.SHARDS)
	assert_eq(feel.get_child_count(), 1, "one pool node, no node per cube")
	assert_true(_pool(feel) is MultiMeshInstance3D)
	assert_eq(_pool(feel).count(), HitFeel.SHARDS)


func test_forty_kills_make_no_node_after_the_first() -> void:
	var s := _setup()
	var feel: HitFeel = s[2]
	_kill(s[0], 1)
	feel.sync(s[1])
	var children := feel.get_child_count()
	_kill(s[0], 40)
	feel.sync(s[1])
	assert_eq(feel.get_child_count(), children, "no node per kill")
	assert_eq(feel.spark_count(), HitFeel.SHARDS * 41)


func test_the_pop_lasts_half_a_second_at_any_frame_rate() -> void:
	for rate in [60, 144]:
		var s := _setup()
		var feel: HitFeel = s[2]
		_kill(s[0], 1)
		feel.sync(s[1])
		var frames := int(rate / 2.0)
		for i in frames - 2:
			feel._process(1.0 / rate)
		assert_gt(feel.spark_count(), 0, "still flying just before 0.5 s at %d fps" % rate)
		for i in 4:
			feel._process(1.0 / rate)
		assert_eq(feel.spark_count(), 0, "gone just after 0.5 s at %d fps" % rate)


func test_nothing_is_drawn_or_moved_with_no_piece_alive() -> void:
	var s := _setup()
	var feel: HitFeel = s[2]
	_kill(s[0], 1)
	feel.sync(s[1])
	var pool := _pool(feel)
	feel._process(1.0 / 60.0)
	assert_true(pool.visible)
	assert_eq(pool.multimesh.visible_instance_count, HitFeel.SHARDS)
	for i in 40:
		feel._process(1.0 / 60.0)
	assert_eq(pool.multimesh.visible_instance_count, 0)
	assert_false(pool.visible, "not drawn when empty")
	pool.step(1.0)
	assert_eq(pool.count(), 0)


func test_the_pool_cap_holds_and_the_oldest_give_way() -> void:
	var pool := ShardPool.new(StandardMaterial3D.new())
	add_child_autofree(pool)
	for i in ShardPool.CAPACITY + 50:
		pool.throw(Vector3(i, 5, 0), Vector3.ZERO, 0.1)
		if i == ShardPool.CAPACITY - 1:
			pool.step(0.001)  # the first 1,024 age a little
	assert_eq(pool.count(), ShardPool.CAPACITY, "capped")
	var xs := {}
	for k in pool.count():
		xs[roundi(pool.piece_position(k).x)] = true
	assert_false(xs.has(0), "the oldest piece gave way")
	assert_true(xs.has(ShardPool.CAPACITY + 49), "the newest is kept")
