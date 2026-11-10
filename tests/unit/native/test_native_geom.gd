extends GutTest
## The native side's shared geometry (native/src/zd_geom.*): its direction tables are Kin's, sent at setup, so
## dir, angle_of and turn_toward give Kin's answers exactly; and its nav grid slot takes a world's field. Pending
## without the native library.


func test_dir_is_kin_for_every_angle() -> void:
	var m := _world_side()
	if m == null:
		return
	var angles := PackedInt32Array()
	for a in range(-4096, 8192):  # Every angle, and the wrap on both sides
		angles.append(a)
	var got: PackedFloat32Array = m.dir_of(angles)
	var off := 0
	for k in angles.size():
		var want := Kin.dir(angles[k])
		if got[k * 2] != want.x or got[k * 2 + 1] != want.y:
			off += 1
	assert_eq(off, 0, "angles whose native direction differs from Kin.dir")


func test_angle_of_is_kin_for_seeded_vectors() -> void:
	var m := _world_side()
	if m == null:
		return
	var xy := PackedFloat32Array()
	var vs: Array[Vector2] = [
		Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)
	]
	vs.append_array([Vector2(1, 1), Vector2(-3, 3), Vector2(1e-6, -2e-6), Vector2(250, -0.001)])
	var seed := 20261110
	for k in 10000:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var x := float((seed >> 4) % 20001 - 10000) / 997.0
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var y := float((seed >> 4) % 20001 - 10000) / 997.0
		vs.append(Vector2(x, y))
	for k in 4096:  # The table's own directions, and a hair either side of each
		var d := Kin.dir(k) * 3.0
		vs.append(d)
		vs.append(d + Vector2(1e-4, -1e-4))
	for v in vs:
		xy.append(v.x)
		xy.append(v.y)
	var got: PackedInt32Array = m.angles_of(xy)
	var off := 0
	var worst := 0
	for k in vs.size():
		var want := Kin.angle_of(vs[k])
		if got[k] != want:
			off += 1
			worst = maxi(worst, Kin.angle_diff(got[k], want))
	assert_eq(off, 0, "vectors whose native angle differs from Kin.angle_of (worst by %d)" % worst)


func test_turn_toward_is_kin() -> void:
	var m := _world_side()
	if m == null:
		return
	var args := PackedInt32Array()
	var seed := 7
	for k in 10000:
		for j in 3:
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			args.append((seed >> 4) % 9000 - 4500 if j < 2 else (seed >> 4) % 2100)
	var got: PackedInt32Array = m.turns_toward(args)
	var off := 0
	for k in got.size():
		if got[k] != Kin.turn_toward(args[k * 3], args[k * 3 + 1], args[k * 3 + 2]):
			off += 1
	assert_eq(off, 0)


func test_the_tables_must_be_whole() -> void:
	var m := _side()
	if m == null:
		return
	assert_false(m.has_trig())
	assert_false(m.set_trig(PackedFloat32Array([1.0]), Kin.sin_table()), "a short table is refused")
	assert_false(m.has_trig())
	assert_true(m.set_trig(Kin.cos_table(), Kin.sin_table()))


func test_the_nav_grid_slot_takes_a_world_field() -> void:
	var m := _side()
	if m == null:
		return
	var w := World.new(3, PlayerTable.starting_values())
	var walls: Array[Obb] = [
		Obb.make(Vector2(0, 0), Vector2(6, 0.5), 0), Obb.make(Vector2(0, 6), Vector2(6, 0.5), 0)
	]
	w.set_walls(walls)
	var nav := w.nav
	assert_gt(nav.size.x * nav.size.y, 0)
	m.set_nav_grid(
		nav.origin, nav.size, NavField.CELL, nav.blocked, nav._adj_start, nav._adj, nav._adj_w
	)
	assert_true(m.has_nav())
	m.set_nav_dist(nav.dist)


## A native side made the way a world makes it (World.native_factory, NativeWorld.setup).
func _world_side() -> Object:
	if _side() == null:
		return null
	var kept := World.native_factory
	var kept_kernels := World.native_kernels
	NativeSwitch.install(NativeWorld.MOVE)
	var w := World.new(1, PlayerTable.starting_values())
	World.native_factory = kept
	World.native_kernels = kept_kernels
	assert_true(w.native.has_trig())
	return w.native


func _side() -> Object:
	if NativeSwitch.available():
		return NativeSwitch.make()
	if OS.get_environment("ZD_NATIVE_REQUIRED") == "1":
		fail_test("ZD_NATIVE_REQUIRED=1, but the native library did not load")
		return null
	pending("the native library is not built (native/README.md)")
	return null
