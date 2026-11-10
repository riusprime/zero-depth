extends GutTest
## The flow field's flood run native (NativeNav, NativeWorld.NAV): on generated floors, from many hero cells (free
## ones, blocked ones next to a wall that seed the cells near them, one outside the field), unbounded and bounded,
## with and without the enemies' cells as targets and with extra cells blocked, the native flood gives NavField's
## GDScript flood exactly: every cell's distance, the flood's key (stopped at its targets or not) and its work. Its
## direction lookup gives NavField.direction's vectors bit for bit. A world with the kernel on floods whole on its
## period tick (no build in progress, ever), runs the same twice, and saves and resumes exactly.
## ZD_NAV_FLOORS=<n> runs the parity on n floors (the default is FLOORS).

const FLOORS := 3
const HEROES := 4
const TARGETS := 30
const DIRECTIONS := 300
const TICKS := 900


## The parity on floor after floor: seeds 11, 12, ... over floors 1 to 3.
func test_the_native_flood_equals_the_gdscript_flood_on_generated_floors() -> void:
	var m := _side()
	if m == null:
		return
	var floors := (
		int(OS.get_environment("ZD_NAV_FLOORS")) if OS.has_environment("ZD_NAV_FLOORS") else FLOORS
	)
	var kept := World.native_kernels
	World.native_kernels = 0  # The floors' own worlds run GDScript; the side under test is `m`
	var cases := 0
	var cells := 0
	var diffs := 0
	for i in floors:
		var w := SaveLab.floor_world(11 + i, 1 + i % 3)
		var r := _floor_parity(m, w.nav, 9000 + i, "floor %d (seed %d)" % [1 + i % 3, 11 + i])
		cases += r[0]
		cells += r[1]
		diffs += r[2]
	World.native_kernels = kept
	gut.p(
		(
			"nav parity: %d floors, %d floods, %d cells compared, %d differ"
			% [floors, cases, cells, diffs]
		)
	)
	assert_eq(diffs, 0, "no cell differs")
	assert_gt(cases, 0, "floods were compared")


## A field's parity: HEROES goal cells, each flooded by both sides in every configuration (and again with extra
## cells blocked round the goal). Returns [floods, cells compared, cells that differ].
func _floor_parity(m: Object, f: NavField, rng_seed: int, label: String) -> Array:
	var out := [0, 0, 0]
	var n := f.size.x * f.size.y
	assert_gt(n, 0, label + ": a field")
	if n == 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var free := PackedInt32Array()
	var edge := PackedInt32Array()  # blocked cells next to a free one: a hero against a wall
	for k in n:
		if f.blocked[k] == 0:
			free.append(k)
		elif k % f.size.x > 0 and f.blocked[k - 1] == 0:
			edge.append(k)
	var goals: Array[Vector2] = [f.center(Vector2i(-3, -3))]  # outside the field
	for h in HEROES:
		var pool := edge if h % 3 == 2 and not edge.is_empty() else free
		var k := pool[rng.randi_range(0, pool.size() - 1)]
		goals.append(f.center(Vector2i(k % f.size.x, k / f.size.x)) + Vector2(0.1, -0.05))
	for pass_extra in 2:
		for gi in goals.size():
			var goal := goals[gi]
			if pass_extra == 1:
				var boxes: Array[Obb] = [Obb.make(goal + Vector2(2.0, 0.5), Vector2(0.8, 1.2), 0)]
				f.set_extra(boxes)
			var targets := PackedInt32Array([-1])
			for t in TARGETS:
				targets.append(free[rng.randi_range(0, free.size() - 1)])
			var near := PackedInt32Array()  # targets near the goal: the flood stops a margin past them
			var g := f.cell_of(goal)
			for t in 8:
				var c := g + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
				if f.inside(c) and f.blocked[c.y * f.size.x + c.x] == 0:
					near.append(c.y * f.size.x + c.x)
			for cfg: Array in [
				[NavField.UNREACHED, PackedInt32Array()],
				[NavField.WORLD_FLOOD_STEPS, PackedInt32Array()],
				[NavField.WORLD_FLOOD_STEPS, targets],
				[NavField.WORLD_FLOOD_STEPS, near],
				[40, near],
			]:
				var what := (
					"%s goal %d extra %d max %d targets %d"
					% [label, gi, pass_extra, cfg[0], (cfg[1] as PackedInt32Array).size()]
				)
				var d := _flood_both(m, f, goal, cfg[0], cfg[1], what)
				out[0] += 1
				out[1] += n
				out[2] += d
		var none: Array[Obb] = []
		f.set_extra(none)
	# The direction lookup on the last native flood (no extra cells): the same vectors bit for bit.
	f.set(&"_flooded", Vector3i(-1, -1, -1))
	f.flood(goals[1], NavField.WORLD_FLOOD_STEPS, PackedInt32Array(), m)
	var xy := PackedFloat32Array()
	var lo := f.origin
	var span := Vector2(f.size) * NavField.CELL
	for i in DIRECTIONS:
		xy.append(lo.x + rng.randf() * span.x)
		xy.append(lo.y + rng.randf() * span.y)
	var got: PackedFloat32Array = m.nav_directions(xy)
	var bad := 0
	for i in DIRECTIONS:
		var want := f.direction(Vector2(xy[i * 2], xy[i * 2 + 1]))
		if want.x != got[i * 2] or want.y != got[i * 2 + 1]:
			bad += 1
	assert_eq(bad, 0, label + ": every direction is NavField.direction's")
	return out


## One flood from `goal` by GDScript, then by the native side, from the same start (the key cleared, so neither
## is skipped). Returns the cells that differ.
func _flood_both(
	m: Object, f: NavField, goal: Vector2, max_steps: int, targets: PackedInt32Array, what: String
) -> int:
	f.set(&"_flooded", Vector3i(-1, -1, -1))
	f.flood(goal, max_steps, targets)
	var gd_dist := f.dist.duplicate()
	var gd_key: Vector3i = f.get(&"_flooded")
	var gd_work := f.last_work
	f.set(&"_flooded", Vector3i(-1, -1, -1))
	f.dist.fill(-7)  # the native result must replace it whole
	f.flood(goal, max_steps, targets, m)
	var diff := 0
	if f.dist.size() != gd_dist.size():
		diff = gd_dist.size()
	elif f.dist != gd_dist:
		for k in gd_dist.size():
			if f.dist[k] != gd_dist[k]:
				diff += 1
	assert_eq(diff, 0, what + ": every distance")
	assert_eq(f.get(&"_flooded"), gd_key, what + ": the key")
	if f.inside(f.cell_of(goal)):
		assert_eq(f.last_work, gd_work, what + ": the work")
	var back: PackedInt32Array = m.nav_dist()
	assert_eq(back, f.dist, what + ": the native cache holds the field's distances")
	return diff


## The native flood against flood_reference (the label-correcting oracle) on a whole flood.
func test_the_native_flood_equals_the_reference_flood() -> void:
	var m := _side()
	if m == null:
		return
	var kept := World.native_kernels
	World.native_kernels = 0
	var w := SaveLab.floor_world(5, 2)
	World.native_kernels = kept
	var f := w.nav
	var goal := w.player_pos()
	f.flood_reference(goal)
	var ref := f.dist.duplicate()
	f.set(&"_flooded", Vector3i(-1, -1, -1))
	f.flood(goal, NavField.UNREACHED, PackedInt32Array(), m)
	assert_eq(f.dist, ref)


## With the kernel on, the world floods whole on its period tick: no build is ever in progress, the field is the
## flood from that tick's hero and enemies, and enemies are about.
func test_a_world_with_the_native_flood_floods_whole_on_its_tick() -> void:
	if _side() == null:
		return
	var w := _floor_world(NativeWorld.NAV, 21, 1)
	assert_eq(w.native_on, NativeWorld.NAV)
	var bot := FightBot.new(4)
	var checked := 0
	var period_ticks := 0
	for t in TICKS:
		# The period tick's flood inputs, read before the step: the hero and the enemies stand still until phase 3.
		var flood_tick := w.tick % NavField.PERIOD == 0
		var targets: PackedInt32Array = w._nav_targets()
		var goal := w.player_pos()
		var g := w.nav.cell_of(goal)
		var runs: bool = (
			flood_tick
			and not targets.is_empty()
			and not w.nav.call(&"_skips", g, NavField.WORLD_FLOOD_STEPS, targets)
		)
		w.step(SaveLab.frame(w, bot))
		assert_false(w.nav.building(), "no build in progress at tick %d" % w.tick)
		if flood_tick and not targets.is_empty():
			period_ticks += 1
		var key: Vector3i = w.nav.get(&"_flooded")
		if not runs or key.x != g.x or key.y != g.y:
			continue
		# The field the step left is the whole flood from those inputs: GDScript gives the same field and key.
		var whole := w.nav.dist.duplicate()
		var work := w.nav.last_work
		w.nav.set(&"_flooded", Vector3i(-1, -1, -1))
		w.nav.flood(goal, NavField.WORLD_FLOOD_STEPS, targets)
		assert_eq(w.nav.dist, whole, "the field at tick %d is the whole flood" % w.tick)
		assert_eq(w.nav.get(&"_flooded"), key, "its key")
		assert_eq(w.nav.last_work, work, "its work")
		checked += 1
		w.nav.dist = whole
		w.nav.last_work = work
		w.nav.set(&"_flooded", key)
		w.nav.dist_rev += 1
	gut.p(
		(
			"native flood world: %d period ticks with enemies, %d checked whole"
			% [period_ticks, checked]
		)
	)
	assert_gt(period_ticks, 0, "enemies were about")
	assert_gt(checked, 0, "floods were checked whole")


## Two worlds with the kernel on, fed the same inputs, keep the same hash chain; and one saved mid-run and resumed
## (with the kernel on) ends where the continuous run ends.
func test_the_native_flood_is_deterministic_and_resumes_exactly() -> void:
	if _side() == null:
		return
	var a := _floor_world(NativeWorld.NAV, 33, 2)
	var b := _floor_world(NativeWorld.NAV, 33, 2)
	var ba := FightBot.new(8)
	var bb := FightBot.new(8)
	for t in 300:
		a.step(SaveLab.frame(a, ba))
		b.step(SaveLab.frame(b, bb))
	assert_eq(a.state_hash(), b.state_hash(), "the same at tick 300")
	var snap := WorldSnapshot.take(a)
	var base := _floor_world(NativeWorld.NAV, 33, 2)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, "the snapshot fits")
	if restored == null:
		return
	assert_eq(restored.native_on, NativeWorld.NAV)
	var br := FightBot.new(8)
	# The resumed bot starts fresh, so the continuous run's comparison partner is `b` with a fresh bot too.
	var bc := FightBot.new(8)
	for t in 600:
		b.step(SaveLab.frame(b, bc))
		restored.step(SaveLab.frame(restored, br))
	assert_eq(
		restored.state_hash(), b.state_hash(), "resumed equals continuous at tick %d" % b.tick
	)
	assert_eq(restored.nav.dist, b.nav.dist, "the same field")


## A floor world made with these kernels on.
func _floor_world(kernels: int, run_seed: int, floor_index: int) -> World:
	var kept := World.native_factory
	var kept_kernels := World.native_kernels
	NativeSwitch.install(kernels)
	var w := SaveLab.floor_world(run_seed, floor_index)
	World.native_factory = kept
	World.native_kernels = kept_kernels
	return w


func _side() -> Object:
	if NativeSwitch.available():
		return NativeSwitch.make()
	if OS.get_environment("ZD_NATIVE_REQUIRED") == "1":
		fail_test("ZD_NATIVE_REQUIRED=1, but the native library did not load")
		return null
	pending("the native library is not built (native/README.md)")
	return null
