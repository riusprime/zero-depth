extends GutTest
## v0.10.5 (DRAW_CALLS.md): EmptyDrawCull keeps the empty effect pools out of the renderer without touching what the
## views set: it watches the pools under its parent (a counted MultiMesh), never the whole static ones, and leaves
## every node's `visible` alone.


func _pool(count: int, shown: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = QuadMesh.new()
	mm.instance_count = count
	mm.visible_instance_count = shown
	var n := MultiMeshInstance3D.new()
	n.multimesh = mm
	return n


func test_a_counted_multimesh_is_a_pool_and_a_whole_one_is_not() -> void:
	var pool := _pool(8, 0)
	var decor := _pool(8, -1)
	assert_true(EmptyDrawCull.is_pool(pool))
	assert_false(
		EmptyDrawCull.is_pool(decor), "the kit's decoration: all its instances, never watched"
	)
	assert_false(EmptyDrawCull.is_pool(Node3D.new()))
	pool.free()
	decor.free()


func test_empty_means_nothing_to_draw() -> void:
	var n := _pool(8, 0)
	assert_true(EmptyDrawCull.is_empty(n))
	n.multimesh.visible_instance_count = 3
	assert_false(EmptyDrawCull.is_empty(n))
	n.multimesh.visible_instance_count = -1
	assert_false(EmptyDrawCull.is_empty(n), "-1: all 8")
	n.multimesh.instance_count = 0
	assert_true(EmptyDrawCull.is_empty(n))
	n.free()


func test_it_watches_the_pools_under_its_parent_added_before_and_after_it() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var early := _pool(4, 0)
	root.add_child(early)
	var cull := EmptyDrawCull.new()
	root.add_child(cull)
	var late := _pool(4, 2)
	var holder := Node3D.new()
	root.add_child(holder)
	holder.add_child(late)
	var decor := _pool(4, -1)
	root.add_child(decor)
	var elsewhere := _pool(4, 0)
	add_child_autofree(elsewhere)
	await wait_frames(2)
	var watched := cull.pools()
	assert_true(watched.has(early), "added before the cull: found by its first scan")
	assert_true(watched.has(late), "added after: heard as it joins")
	assert_false(watched.has(decor))
	assert_false(watched.has(elsewhere), "not under the view")


func test_it_never_changes_a_nodes_visible() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(EmptyDrawCull.new())
	var empty := _pool(4, 0)
	var hidden := _pool(4, 3)
	hidden.visible = false
	root.add_child(empty)
	root.add_child(hidden)
	await wait_frames(3)
	assert_true(
		empty.visible, "an empty pool leaves the renderer, its node stays shown for the views"
	)
	assert_false(hidden.visible, "a node the view hid stays hidden")
	empty.multimesh.visible_instance_count = 2
	await wait_frames(2)
	assert_true(empty.visible)


func test_it_runs_after_the_views() -> void:
	assert_eq(EmptyDrawCull.new().process_priority, EmptyDrawCull.PROCESS_LAST)
