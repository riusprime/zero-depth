extends GutTest
## The flow field's flood runs native (NativeNav): on generated floors, from several hero cells (free ones, blocked
## ones next to a wall that seed the cells near them), with and without extra cells blocked, the whole flood gives
## NavField.flood_reference (the GDScript label-correcting oracle) cell for cell; its direction lookup gives
## NavField.direction's vectors bit for bit. A world floods whole on its period tick, runs the same twice, and saves
## and resumes exactly.
## ZD_NAV_FLOORS=<n> runs the parity on n floors (the default is FLOORS).

const FLOORS := 3
const HEROES := 4
const DIRECTIONS := 300
const TICKS := 900


## The parity on floor after floor: seeds 11, 12, ... over floors 1 to 3.
func test_the_native_flood_equals_the_reference_flood_on_generated_floors() -> void:
	var floors := (
		int(OS.get_environment("ZD_NAV_FLOORS")) if OS.has_environment("ZD_NAV_FLOORS") else FLOORS
	)
	var cases := 0
	var diffs := 0
	for i in floors:
		var w := SaveLab.floor_world(11 + i, 1 + i % 3)
		var r := _floor_parity(
			w.native, w.nav, 9000 + i, "floor %d (seed %d)" % [1 + i % 3, 11 + i]
		)
		cases += r[0]
		diffs += r[1]
	gut.p("nav parity: %d floors, %d floods, %d cells differ" % [floors, cases, diffs])
	assert_eq(diffs, 0, "no cell differs")
	assert_gt(cases, 0, "floods were compared")


## A field's parity: HEROES goal cells, each flooded whole by the native side and by flood_reference (and again with
## extra cells blocked round the goal). Returns [floods, cells that differ].
func _floor_parity(m: Object, f: NavField, rng_seed: int, label: String) -> Array:
	var out := [0, 0]
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
	var goals: Array[Vector2] = []
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
			f.flood_reference(goal)
			var ref := f.dist.duplicate()
			f.set(&"_flooded", Vector3i(-1, -1, -1))
			f.dist.fill(-7)  # the native result must replace it whole
			f.flood(goal, NavField.UNREACHED, PackedInt32Array(), m)
			var diff := 0
			for k in ref.size():
				if k >= f.dist.size() or f.dist[k] != ref[k]:
					diff += 1
			assert_eq(diff, 0, "%s goal %d extra %d: every distance" % [label, gi, pass_extra])
			var back: PackedInt32Array = m.nav_dist()
			assert_eq(
				back,
				f.dist,
				"%s goal %d: the native cache holds the field's distances" % [label, gi]
			)
			out[0] += 1
			out[1] += diff
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


## The world floods whole on its period tick: the field is the
## flood from that tick's hero and enemies, and enemies are about.
func test_a_world_with_the_native_flood_floods_whole_on_its_tick() -> void:
	var w := _floor_world(21, 1)
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
		if flood_tick and not targets.is_empty():
			period_ticks += 1
		var key: Vector3i = w.nav.get(&"_flooded")
		if not runs or key.x != g.x or key.y != g.y:
			continue
		# The field the step left is the whole flood from those inputs: a fresh flood gives the same field and key.
		var whole := w.nav.dist.duplicate()
		var work := w.nav.last_work
		w.nav.set(&"_flooded", Vector3i(-1, -1, -1))
		w.nav.flood(goal, NavField.WORLD_FLOOD_STEPS, targets, w.native)
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


## Two worlds fed the same inputs keep the same hash chain; and one saved mid-run and resumed
## ends where the continuous run ends.
func test_the_native_flood_is_deterministic_and_resumes_exactly() -> void:
	var a := _floor_world(33, 2)
	var b := _floor_world(33, 2)
	var ba := FightBot.new(8)
	var bb := FightBot.new(8)
	for t in 300:
		a.step(SaveLab.frame(a, ba))
		b.step(SaveLab.frame(b, bb))
	assert_eq(a.state_hash(), b.state_hash(), "the same at tick 300")
	var snap := WorldSnapshot.take(a)
	var base := _floor_world(33, 2)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, "the snapshot fits")
	if restored == null:
		return
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


## A floor world of the run seed's floor.
func _floor_world(run_seed: int, floor_index: int) -> World:
	return SaveLab.floor_world(run_seed, floor_index)
