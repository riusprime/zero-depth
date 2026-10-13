extends GutTest
## Walls added and removed in play (World.add_barrier / remove_barriers / add_wall_now / remove_wall_now).


func _world() -> World:
	var w := World.new(5, PlayerTable.starting_values())
	var floor_walls: Array[Obb] = [Obb.make(Vector2(-10, 0), Vector2(0.5, 10), 0)]
	w.set_walls(floor_walls)
	return w


func test_removal_matches_the_angle_too() -> void:
	var w := _world()
	var straight := Obb.make(Vector2(4, 4), Vector2(2, 0.5), 0)
	var turned := Obb.make(Vector2(4, 4), Vector2(2, 0.5), 1024)
	w.add_wall_now(straight)
	w.add_wall_now(turned)
	# Same centre and half-extents: only the angle tells them apart, and the later one must stay.
	w.remove_wall_now(Obb.make(Vector2(4, 4), Vector2(2, 0.5), 0))
	assert_eq(w.walls.size(), 2)
	assert_eq(w.walls[1].angle, 1024)
	var barrier := Obb.make(Vector2(-4, -4), Vector2(1, 0.25), 0)
	var turned_barrier := Obb.make(Vector2(-4, -4), Vector2(1, 0.25), 2048)
	w.add_barrier(barrier)
	w.add_barrier(turned_barrier)
	var gone: Array[Obb] = [Obb.make(Vector2(-4, -4), Vector2(1, 0.25), 0)]
	w.remove_barriers(gone)
	assert_eq(w.walls.size(), 3)
	assert_eq(w.walls[2].angle, 2048)


func test_removing_every_barrier_leaves_the_grid_of_the_walls_left() -> void:
	var w := _world()
	var barriers: Array[Obb] = [
		Obb.make(Vector2(3, 0), Vector2(1, 0.25), 0),
		Obb.make(Vector2(0, 3), Vector2(0.25, 1), 0),
		Obb.make(Vector2(-3, 0), Vector2(1, 0.25), 0),
	]
	for o in barriers:
		w.add_barrier(o)
	assert_true(w.walls_near(Rect2(2.5, -0.5, 1, 1)).has(1))
	w.remove_barriers(barriers)
	assert_eq(w.walls.size(), 1)
	# The grid is the one the walls left would build from scratch.
	var fresh := _world()
	for r in [Rect2(-5, -5, 10, 10), Rect2(2.5, -0.5, 1, 1), Rect2(-11, -1, 2, 2)]:
		assert_eq(w.walls_near(r), fresh.walls_near(r))
	# A barrier that is not there any more is ignored.
	w.remove_barriers(barriers)
	assert_eq(w.walls.size(), 1)
