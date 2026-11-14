extends GutTest
## v0.11.1 S45: a floor's build (FloorPlan) builds its flow fields once, at its end (World.defer_nav, build_nav),
## instead of at every set_walls and prepare_wall of its layout (the shop, the purposes, the curse room, the fountain).
## The fields must be exactly the ones the eager calls built: a deferred world and an eager one fed the same calls
## match field for field, and a FloorPlan floor leaves nothing pending and matches the eager SaveLab floor's fields.

## The NavField arrays a build derives from the walls (dist stays UNREACHED until a flood).
const NAV_FIELDS: Array[StringName] = [
	&"origin",
	&"size",
	&"blocked",
	&"dist",
	&"region",
	&"extra",
	&"_adj_start",
	&"_adj",
	&"_adj_w",
	&"_flooded",
	&"last_work",
]


func _box(x: float, y: float, hx: float, hy: float) -> Obb:
	return Obb.make(Vector2(x, y), Vector2(hx, hy), 0)


func _room() -> Array[Obb]:
	var walls: Array[Obb] = [
		_box(0, 8, 8, 0.4), _box(0, -8, 8, 0.4), _box(8, 0, 0.4, 8), _box(-8, 0, 0.4, 8)
	]
	return walls


func _same_field(a: NavField, b: NavField, what: String) -> void:
	assert_not_null(a, what + ": built")
	assert_not_null(b, what + ": reference built")
	if a == null or b == null:
		return
	for f in NAV_FIELDS:
		assert_eq(a.get(f), b.get(f), "%s.%s" % [what, f])
	assert_eq(_walls_key(a.get(&"_walls")), _walls_key(b.get(&"_walls")), what + "._walls")


func _walls_key(list: Array) -> String:
	var parts := PackedStringArray()
	for o: Obb in list:
		parts.append("%s %s %s" % [o.center, o.half, o.angle])
	return ";".join(parts)


## The same set_walls / prepare_wall / add_barrier calls a floor's build makes, deferred and eager.
func _feed(w: World) -> void:
	var door := _box(0, 4, 2, 0.3)
	var walls := _room()
	w.set_walls(walls)
	w.prepare_wall(door)
	w.add_barrier(_box(-4, -4, 1, 0.3))  # a slab while the build goes on: the next set_walls keeps it
	var more: Array[Obb] = w.walls.duplicate()
	more.append(_box(4, -2, 0.5, 0.5))
	w.set_walls(more)
	w.prepare_wall(door)
	w.add_barrier(_box(-2, 2, 0.5, 0.5))  # after the last set_walls: in the walls, never in the fields


func test_deferred_fields_match_the_eager_ones() -> void:
	var eager := World.new(7, PlayerTable.new(), Vector2.ZERO)
	_feed(eager)
	var lazy := World.new(7, PlayerTable.new(), Vector2.ZERO)
	lazy.defer_nav()
	_feed(lazy)
	assert_null(lazy.get(&"_nav_next"), "nothing built before build_nav")
	lazy.build_nav()
	_same_field(lazy.nav, eager.nav, "nav")
	_same_field(lazy.get(&"_nav_next"), eager.get(&"_nav_next"), "_nav_next")
	assert_eq(lazy.walls.size(), eager.walls.size(), "the same walls")


func test_the_first_tick_builds_what_build_nav_did_not() -> void:
	var eager := World.new(7, PlayerTable.new(), Vector2.ZERO)
	_feed(eager)
	var lazy := World.new(7, PlayerTable.new(), Vector2.ZERO)
	lazy.defer_nav()
	_feed(lazy)
	lazy.step(InputFrame.new())
	eager.step(InputFrame.new())
	_same_field(lazy.nav, eager.nav, "nav")
	assert_eq(lazy.state_hash(), eager.state_hash(), "the same tick")


func test_a_floor_plan_floor_has_the_eager_floors_fields() -> void:
	var plan := FloorPlan.new_run(RunSaver.RUN_ID, 4242, &"blade", false)
	plan.build()
	var w := plan.world
	assert_not_null(w, "FloorPlan builds floor 1")
	assert_false(w.get(&"_nav_deferred"), "nothing left deferred")
	assert_null(w.get(&"_nav_due"), "no field left due")
	assert_null(w.get(&"_nav_next_due"), "no door field left due")
	# the eager build of the same floor
	var lab := SaveLab.build_floor(SaveLab.run_state(4242, 1, &"blade"), &"", null, true)
	assert_eq(_walls_key(w.walls), _walls_key(lab.walls), "the same walls")
	_same_field(w.nav, lab.nav, "nav")
	_same_field(w.get(&"_nav_next"), lab.get(&"_nav_next"), "_nav_next")
