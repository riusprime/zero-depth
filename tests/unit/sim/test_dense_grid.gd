extends GutTest
## DenseGrid (v0.4.0 SC): the walls' and the actors' broadphase. Every query returns ascending indices without
## duplicates and never misses an entry whose box overlaps it (checked against brute force).


func _boxes(n: int, seed_value: int) -> Array[Rect2]:
	var rng := RngStream.derive(seed_value, "grid")
	var out: Array[Rect2] = []
	for k in n:
		var p := Vector2(rng.range_int(-4000, 4000), rng.range_int(-3000, 3000)) / 100.0
		var s := Vector2(rng.range_int(10, 600), rng.range_int(10, 600)) / 100.0
		out.append(Rect2(p, s))
	return out


func _check(got: PackedInt32Array, want: PackedInt32Array, tag: String) -> void:
	for k in range(1, got.size()):
		assert_gt(got[k], got[k - 1], "%s: ascending, no duplicates" % tag)
	for v in want:
		assert_true(got.has(v), "%s: finds %d" % [tag, v])


func test_box_queries_never_miss_an_overlap() -> void:
	var boxes := _boxes(150, 3)
	var g := DenseGrid.new()
	g.build(boxes)
	var rng := RngStream.derive(9, "q")
	for q in 200:
		var at := Vector2(rng.range_int(-4500, 4500), rng.range_int(-3500, 3500)) / 100.0
		var rect := Rect2(at, Vector2(rng.range_int(5, 900), rng.range_int(5, 900)) / 100.0)
		var want := PackedInt32Array()
		for k in boxes.size():
			if boxes[k].intersects(rect, true):
				want.append(k)
		_check(g.query_rect(rect), want, "rect %d" % q)


func test_a_line_of_sight_query_never_misses_a_wall_near_the_line() -> void:
	var boxes := _boxes(150, 5)
	var g := DenseGrid.new()
	g.build(boxes)
	var rng := RngStream.derive(11, "seg")
	for q in 200:
		var a := Vector2(rng.range_int(-4000, 4000), rng.range_int(-3000, 3000)) / 100.0
		var b := Vector2(rng.range_int(-4000, 4000), rng.range_int(-3000, 3000)) / 100.0
		if q % 10 == 0:
			b.x = a.x  # straight up or down
		var r := 0.6
		var want := PackedInt32Array()
		for k in boxes.size():
			# A wall whose box comes within r of the line (sampled finely).
			for s in 201:
				var p := a.lerp(b, s / 200.0)
				if boxes[k].grow(r).has_point(p):
					want.append(k)
					break
		_check(g.query_segment(a, b, r), want, "segment %d" % q)


func test_circle_queries_never_miss_an_overlap() -> void:
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var rs := PackedFloat32Array()
	var rng := RngStream.derive(17, "circles")
	for k in 160:
		xs.append(rng.range_int(-2000, 2000) / 100.0)
		ys.append(rng.range_int(-2000, 2000) / 100.0)
		rs.append(rng.range_int(20, 90) / 100.0)
	var g := DenseGrid.new()
	g.build_circles(xs, ys, rs)
	assert_eq(g.count(), 160)
	for q in 200:
		var at := Vector2(rng.range_int(-2200, 2200), rng.range_int(-2200, 2200)) / 100.0
		var rect := Rect2(at, Vector2(rng.range_int(5, 400), rng.range_int(5, 400)) / 100.0)
		var want := PackedInt32Array()
		for k in xs.size():
			var box := Rect2(xs[k] - rs[k], ys[k] - rs[k], rs[k] * 2.0, rs[k] * 2.0)
			if box.intersects(rect, true):
				want.append(k)
		_check(g.query_rect(rect), want, "circle query %d" % q)


func test_a_far_off_entry_cannot_blow_up_the_grid() -> void:
	var g := DenseGrid.new()
	var xs := PackedFloat32Array([0.0, 100000.0])
	var ys := PackedFloat32Array([0.0, -100000.0])
	var rs := PackedFloat32Array([0.5, 0.5])
	g.build_circles(xs, ys, rs)
	assert_lte(g.size.x, DenseGrid.MAX_SIDE)
	assert_lte(g.size.y, DenseGrid.MAX_SIDE)
	assert_eq(g.query_rect(Rect2(-1, -1, 2, 2)).has(0), true)
	assert_eq(g.query_rect(Rect2(99999, -100001, 2, 2)).has(1), true)


func test_empty_grids_answer_empty() -> void:
	var g := DenseGrid.new()
	assert_eq(g.query_rect(Rect2(0, 0, 5, 5)).size(), 0)
	g.build_circles(PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array())
	assert_eq(g.query_rect(Rect2(0, 0, 5, 5)).size(), 0)
	var none: Array[Rect2] = []
	g.build(none)
	assert_eq(g.query_segment(Vector2.ZERO, Vector2(5, 5), 0.5).size(), 0)


func test_adding_a_box_finds_it() -> void:
	var g := DenseGrid.new()
	g.build(_boxes(20, 2))
	g.add(Rect2(100, 100, 2, 2))
	assert_true(
		g.query_rect(Rect2(100.5, 100.5, 0.1, 0.1)).has(20), "the boss door is found once added"
	)
