extends SceneTree
## The pair-separation pass alone, GDScript against the native side (ZdWorld), on the same crowd: N bodies of radius
## 0.35-0.6 m packed into a disc (60 % of its area covered, so most bodies touch a few others), the body grid built and
## one pass of pushes, each repetition from the same start. Prints ns per body per pass for:
## - gdscript: DenseGrid.build_circles and World's pair loop (the same arithmetic, no boss flags);
## - native_inside: ZdWorld.bench_pairs's own clock (the C++ work alone);
## - native_call: ZdWorld.resolve with no walls, one pass, timed from GDScript (the work plus the columns crossing);
## - touch / get_xy: a call that hands three columns over and does nothing, and reading the two result columns back.
## Needs the native library (native/README.md). Writes nothing tracked.
##   godot --headless --path . -s scripts/bench/native_pairs_bench.gd [-- --counts=120,500] [-- --reps=2000]


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var m: Object = NativeWorld.make()
	if m == null:
		push_error("native_pairs_bench: the native library is not loaded")
		quit(1)
		return
	var counts := PackedInt32Array([120, 500])
	if args.has("--counts"):
		counts = PackedInt32Array()
		for s in String(args["--counts"]).split(","):
			counts.append(int(s))
	var reps := int(args.get("--reps", 2000))
	for n in counts:
		_measure(m, n, reps)
	quit(0)


func _crowd(n: int) -> Array[PackedFloat32Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4049 + n
	var px := PackedFloat32Array()
	var py := PackedFloat32Array()
	var rad := PackedFloat32Array()
	var area := 0.0
	for i in n:
		var r := rng.randf_range(0.35, 0.6)
		rad.append(r)
		area += PI * r * r
	var disc := sqrt(area / 0.6 / PI)
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * disc
		px.append(10.0 + cos(a) * d)
		py.append(-4.0 + sin(a) * d)
	return [px, py, rad]


func _measure(m: Object, n: int, reps: int) -> void:
	var c := _crowd(n)
	var px: PackedFloat32Array = c[0]
	var py: PackedFloat32Array = c[1]
	var rad: PackedFloat32Array = c[2]
	m.set_walls(PackedFloat32Array())
	m.set_solids(PackedFloat32Array())
	var none := PackedInt32Array()
	# GDScript
	var grid := DenseGrid.new()
	var gd_us := 0
	var gd_pushes := 0
	for r in reps:
		var x := px.duplicate()
		var y := py.duplicate()
		var t0 := Time.get_ticks_usec()
		grid.build_circles(x, y, rad)
		gd_pushes = _gd_pairs(grid, x, y, rad)
		gd_us += Time.get_ticks_usec() - t0
	# Native, its own clock
	var inside_ns: int = m.bench_pairs(px, py, rad, reps)
	# Native, called from GDScript (one pass, no walls), results read back
	var call_us := 0
	var nat_pushes := 0
	for r in reps:
		var t0 := Time.get_ticks_usec()
		nat_pushes = m.resolve(px, py, rad, none, none, false, 1)
		var ox: PackedFloat32Array = m.get_x()
		var oy: PackedFloat32Array = m.get_y()
		call_us += Time.get_ticks_usec() - t0
		if ox.size() != n or oy.size() != n:
			push_error("native_pairs_bench: wrong result size")
	var touch_us := 0
	var t1 := Time.get_ticks_usec()
	for r in reps:
		m.touch(px, py, rad)
	touch_us = Time.get_ticks_usec() - t1
	var get_us := 0
	var t2 := Time.get_ticks_usec()
	for r in reps:
		var ox: PackedFloat32Array = m.get_x()
		var oy: PackedFloat32Array = m.get_y()
		if ox.size() + oy.size() < 0:
			push_error("unreachable")
	get_us = Time.get_ticks_usec() - t2
	var per := 1000.0 / (float(reps) * n)  # us total -> ns per body per pass
	print("bodies=%d reps=%d pushes gdscript=%d native=%d" % [n, reps, gd_pushes, nat_pushes])
	print("  gdscript       %8.1f ns/body  (%7.1f us/pass)" % [gd_us * per, gd_us / float(reps)])
	print(
		(
			"  native_inside  %8.1f ns/body  (%7.1f us/pass)"
			% [inside_ns / float(reps) / n, inside_ns / 1000.0 / reps]
		)
	)
	print(
		"  native_call    %8.1f ns/body  (%7.1f us/pass)" % [call_us * per, call_us / float(reps)]
	)
	print("  touch          %8.1f us/call" % [touch_us / float(reps)])
	print("  get_xy         %8.1f us/call" % [get_us / float(reps)])
	print("  speedup gdscript/native_call %.1fx" % [float(gd_us) / maxf(call_us, 1.0)])


## The pair loop the GDScript collision passes ran before the native core (a copy kept as this bench's reference), without
## the boss flags (none in this crowd).
func _gd_pairs(
	grid: DenseGrid, px: PackedFloat32Array, py: PackedFloat32Array, rad: PackedFloat32Array
) -> int:
	var pushes := 0
	for a in px.size():
		var ra := rad[a]
		var near := grid.query_rect(Rect2(px[a] - ra, py[a] - ra, ra * 2.0, ra * 2.0))
		for q in range(near.bsearch(a + 1), near.size()):
			var b := near[q]
			var rb := rad[b]
			var reach := ra + rb + 0.001
			if absf(px[b] - px[a]) >= reach or absf(py[b] - py[a]) >= reach:
				continue
			var d := Vector2(px[a], py[a]) - Vector2(px[b], py[b])
			var rr := ra + rb
			var dist2 := float(d.x) * d.x + float(d.y) * d.y
			if dist2 >= rr * rr:
				continue
			var push := Vector2(rr * 0.5, 0.0)
			if dist2 != 0.0:
				var dist := sqrt(dist2)
				push = d * ((rr - dist) * 0.5 / dist)
			var na := Vector2(px[a], py[a]) + push
			px[a] = na.x
			py[a] = na.y
			var nb := Vector2(px[b], py[b]) - push
			px[b] = nb.x
			py[b] = nb.y
			pushes += 1
	return pushes
