extends GutTest


func test_circle_pushed_out_of_box_face() -> void:
	var box := Obb.make(Vector2.ZERO, Vector2(1, 1), 0)
	var push := Collide.circle_vs_obb(Vector2(1.2, 0), 0.5, box)
	assert_almost_eq(push.x, 0.3, 1e-5)
	assert_almost_eq(push.y, 0.0, 1e-5)
	assert_eq(Collide.circle_vs_obb(Vector2(3, 0), 0.5, box), Vector2.ZERO)


func test_circle_inside_box_leaves_through_nearest_face() -> void:
	var box := Obb.make(Vector2.ZERO, Vector2(2, 1), 0)
	var push := Collide.circle_vs_obb(Vector2(0.5, 0.8), 0.25, box)
	assert_almost_eq(push.y, 0.45, 1e-5)
	assert_almost_eq(push.x, 0.0, 1e-5)


func test_rotated_box() -> void:
	var box := Obb.make(Vector2.ZERO, Vector2(2, 0.5), 1024)  # rotated 90°: long axis is y
	assert_ne(Collide.circle_vs_obb(Vector2(0, 1.9), 0.3, box), Vector2.ZERO)
	assert_eq(Collide.circle_vs_obb(Vector2(1.9, 0), 0.3, box), Vector2.ZERO)


func test_circles_separate_symmetrically() -> void:
	var push := Collide.circle_vs_circle(Vector2(0, 0), 0.5, Vector2(0.8, 0), 0.5)
	assert_almost_eq(push.x, -0.1, 1e-5)
	assert_eq(Collide.circle_vs_circle(Vector2(0, 0), 0.5, Vector2(2, 0), 0.5), Vector2.ZERO)


func test_sweep_hits_first_contact() -> void:
	var t := Collide.sweep_vs_circle(Vector2(-2, 0), Vector2(2, 0), 0.0, Vector2.ZERO, 1.0)
	assert_almost_eq(t, 0.25, 1e-5)
	assert_eq(
		Collide.sweep_vs_circle(Vector2(-2, 3), Vector2(2, 3), 0.0, Vector2.ZERO, 1.0),
		Collide.NO_HIT
	)
	var box := Obb.make(Vector2.ZERO, Vector2(1, 1), 0)
	assert_almost_eq(Collide.sweep_vs_obb(Vector2(-3, 0), Vector2(3, 0), 0.0, box), 1.0 / 3.0, 1e-5)


func test_projectile_stops_at_nearer_of_two_targets() -> void:
	var w := World.new(1, PlayerTable.starting_values(), Vector2(5, 0))
	w.add_dummy(Vector2(-20, -20), 0.35, 10)  # a far enemy so the actor grid is non-trivial
	w.projectiles.add(99, 2, ActorStore.TEAM_ENEMY, Vector2(4.0, 0), Vector2(1.0, 0), 0.1, 10)
	w.step(InputFrame.new())
	var hits := w.events_since(0).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.HIT
	)
	assert_eq(hits.size(), 1)
	assert_eq(w.projectiles.size(), 0, "the projectile is consumed by its hit")
