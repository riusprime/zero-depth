extends GutTest
## The native collision passes (NativeMove, the ZdMover class of native/zd_native.gdextension): off by default, and
## when the library is built, the same rules as the GDScript passes and the same result from the same start. Without
## the library (a checkout that hasn't run scripts/native/build.sh) only the off-by-default test runs; the others are
## pending.

## ZdMover.determinism_probe() as built by MSVC (Visual Studio 2026, /fp:precise) on the owner's PC.
const DETERMINISM_PROBE := "fc67776bc3d14796"

var _kept := Callable()


func before_all() -> void:
	_kept = World.mover_factory  # A run with the native hook keeps its factory for the files after this one


func after_all() -> void:
	World.mover_factory = _kept


func test_the_native_passes_are_off_by_default() -> void:
	assert_false(NativeSwitch.install(false))
	assert_null(
		World.new(9, PlayerTable.starting_values()).native_mover, "no factory: the GDScript passes"
	)


func test_bodies_part_half_each() -> void:
	if not _built():
		return
	var w := _dummies([Vector2(5, 0), Vector2(5.8, 0)], [])
	w._move_and_collide()
	assert_almost_eq(w.actors.pos_x[1], 4.9, 1e-5)
	assert_almost_eq(w.actors.pos_x[2], 5.9, 1e-5)
	assert_eq(w.actors.pos_y[1], 0.0)
	var same := _dummies([Vector2(5, 3), Vector2(5, 3)], [])
	same._move_and_collide()
	assert_almost_eq(same.actors.pos_x[1], 5.5, 1e-5, "coincident centres part along x")
	assert_almost_eq(same.actors.pos_x[2], 4.5, 1e-5)


func test_a_body_in_a_wall_is_pushed_clear() -> void:
	if not _built():
		return
	var wall := Obb.make(Vector2(8, 0), Vector2(1, 3), 512)  # turned 45 degrees
	var w := _dummies([Vector2(7.8, 0.3)], [wall])
	w._move_and_collide()
	assert_lt(_depth(w, wall), 1e-4, "the body is clear of the wall")


## A crowd shoved into a wall: the passes end with a pair pass, so crowded bodies may be left a little inside (the
## GDScript passes too, by rule); the native passes leave them no deeper than the GDScript ones, give or take.
func test_a_crowd_at_a_wall_ends_no_deeper_than_with_gdscript() -> void:
	if not _built():
		return
	var wall := Obb.make(Vector2(8, 0), Vector2(1, 3), 512)
	var starts: Array[Vector2] = []
	for k in 12:
		starts.append(Vector2(6.6 + 0.25 * k, -1.5 + 0.25 * k))
	var nat := _dummies(starts, [wall])
	var gd := _dummies(starts, [wall])
	gd.native_mover = null
	for t in 3:
		nat._move_and_collide()
		gd._move_and_collide()
	var dn := _depth(nat, wall)
	var dg := _depth(gd, wall)
	gut.p("deepest body in the wall after 3 ticks: native %.4f m, gdscript %.4f m" % [dn, dg])
	assert_lt(dn, dg + 0.05, "native %.4f m against gdscript %.4f m" % [dn, dg])


func test_the_same_start_gives_the_same_result() -> void:
	if not _built():
		return
	var a := _crowd_hashes()
	var b := _crowd_hashes()
	assert_eq(a, b, "native: the same hashes tick for tick")


## The extension's fixed scene through the mover gives the hash recorded on Windows (MSVC). Another compiler (gcc in
## CI), or changed float flags, that rounds one operation differently fails here, before any golden does.
func test_the_floats_match_the_recorded_compiler() -> void:
	if not _built():
		return
	var mover: Object = NativeSwitch.make()
	assert_eq(
		mover.call(&"determinism_probe"), DETERMINISM_PROBE, "native/README.md: the float rules"
	)


func _built() -> bool:
	if NativeSwitch.available():
		return true
	# CI sets this when it built the library for the job: a library that then fails to load is a failure there
	if OS.get_environment("ZD_NATIVE_REQUIRED") == "1":
		fail_test("ZD_NATIVE_REQUIRED=1, but the native library did not load")
		return false
	pending("the native library is not built (native/README.md)")
	return false


func _dummies(at: Array, walls: Array) -> World:
	NativeSwitch.install(true)
	var w := World.new(9, PlayerTable.starting_values())
	assert_not_null(w.native_mover, "the factory made a native mover")
	var list: Array[Obb] = []
	list.assign(walls)
	w.set_walls(list)
	w.dummy_speed = 0.0
	w.actors.set_pos(0, Vector2(-20, -20))
	for p: Vector2 in at:
		w.add_dummy(p, 0.5, 10)
	return w


## 60 dummies chasing the hero through a ring of walls for 240 ticks; the state hash every 30.
func _crowd_hashes() -> PackedStringArray:
	var walls: Array = []
	for k in 8:
		walls.append(Obb.make(Vector2(k * 3.0 - 10.0, 4.0), Vector2(1.0, 0.4), k * 300))
	var spots: Array = []
	for k in 60:
		spots.append(Vector2((k % 10) * 0.7 - 3.0, (k / 10) * 0.7 + 6.0))
	var w := _dummies(spots, walls)
	w.dummy_speed = 3.0 / SimTick.TICKS_PER_SECOND
	w.actors.set_pos(0, Vector2(0, -2))
	var out := PackedStringArray()
	for t in 240:
		w.step(InputFrame.new())
		if t % 30 == 29:
			out.append(w.state_hash())
	return out


## How far the deepest dummy's circle reaches into the wall (the length of the push that would clear it).
func _depth(w: World, wall: Obb) -> float:
	var deepest := 0.0
	for i in range(1, w.actors.size()):
		deepest = maxf(
			deepest, Collide.circle_vs_obb(w.actors.pos(i), w.actors.radius[i], wall).length()
		)
	return deepest
