extends GutTest
## Guard and blink (PLAN v0.1.0 Step 3). Aim angle 0 = +x.

const U := InputFrame.UTILITY
const BLINK_STEP := PlayerKit.BLINK_STEP_M


func _world(kind: int) -> World:
	var t := PlayerTable.starting_values()
	t.utility = kind
	return World.new(5, t)


func _f(held: int = 0, pressed: int = 0, dist_cm: int = 1000, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, 0, dist_cm, held, pressed)


func test_guard_cuts_hits_from_the_front_only() -> void:
	var w := _world(PlayerTable.Utility.GUARD)
	w.step(_f(U, U))
	assert_true(w.guarding())
	assert_eq(Damage.hit(w, 0, 50, 9, 9, 9, 0, Vector2(3, 0), Vector2.ZERO), 10, "front: a fifth")
	w.actors.invuln[0] = 0
	assert_eq(Damage.hit(w, 0, 50, 9, 9, 9, 0, Vector2(-3, 0), Vector2.ZERO), 50, "behind: full")


func test_guard_slows_and_stops_attacks() -> void:
	var w := _world(PlayerTable.Utility.GUARD)
	var free := _world(PlayerTable.Utility.GUARD)
	for i in 30:
		w.step(_f(U, InputFrame.PRIMARY if i == 5 else 0, 1000, Vector2i(127, 0)))
		free.step(_f(0, 0, 1000, Vector2i(127, 0)))
	assert_almost_eq(w.player_pos().x, free.player_pos().x * 0.4, 0.05)
	assert_eq(w.swing_t, 0, "no swing while guarding")


func test_blink_follows_movement_not_the_aim() -> void:
	var w := _world(PlayerTable.Utility.BLINK)
	# Moving +x while aiming -x (angle 2048): the blink goes +x, its full 5 m.
	w.step(InputFrame.make(Vector2i(127, 0), 2048, 300, 0, U))
	assert_almost_eq(w.player_pos().x, 5.0, 0.1, "5 m the way you're moving")
	assert_true(w.actors.invuln[0] > 0, "briefly invulnerable")


func test_standing_still_blinks_toward_the_aim_with_a_cooldown() -> void:
	var w := _world(PlayerTable.Utility.BLINK)
	w.step(_f(0, U, 300))
	assert_almost_eq(w.player_pos().x, 5.0, 0.01, "the full range, whatever the aim distance")
	w.step(_f(0, U))
	assert_almost_eq(w.player_pos().x, 5.0, 0.01, "still on cooldown")
	for i in w.player.blink_cooldown_ticks:
		w.step(_f())
	w.step(_f(0, U))
	assert_almost_eq(w.player_pos().x, 10.0, 0.01)


func test_blink_teleports_through_a_wall() -> void:
	var w := _world(PlayerTable.Utility.BLINK)
	var walls: Array[Obb] = [Obb.make(Vector2(2.5, 0), Vector2(0.2, 3), 0)]
	w.set_walls(walls)
	w.step(_f(0, U, 500))
	assert_almost_eq(w.player_pos().x, 5.0, 0.01, "landed on the far side")


func test_blink_into_a_wall_lands_just_before_it() -> void:
	var w := _world(PlayerTable.Utility.BLINK)
	var walls: Array[Obb] = [Obb.make(Vector2(5.0, 0), Vector2(1.0, 3), 0)]
	w.set_walls(walls)
	w.step(_f(0, U, 500))
	assert_lt(w.player_pos().x, 4.0 - w.player.radius_m + 0.01)
	assert_gt(w.player_pos().x, 4.0 - w.player.radius_m - 0.15)


func test_blink_never_lands_in_the_void() -> void:
	# Beyond the arena's 0.8 m outer wall is void (another NavField region): the blink would end there, so it
	# stops before the wall.
	var t := PlayerTable.starting_values()
	t.utility = PlayerTable.Utility.BLINK
	var w := StageScenario.build(1, t)
	w.actors.set_pos(0, Vector2(7.5, 0))
	w.step(_f(0, U, 500))
	assert_lt(w.player_pos().x, 9.1 - t.radius_m, "the outer wall stops it")
	assert_gt(w.player_pos().x, 7.5, "but it still blinked as far as it could")


## v0.3.0 L1 "By thickness vs range": a walled room split by a wall from x = wall_lo to wall_hi, with a 2.5 m way
## round it at each end, so both sides are walkable (one NavField region).
func _two_rooms(wall_lo: float, wall_hi: float) -> World:
	var w := _world(PlayerTable.Utility.BLINK)
	var walls: Array[Obb] = [
		Obb.make(Vector2((wall_lo + wall_hi) * 0.5, 0), Vector2((wall_hi - wall_lo) * 0.5, 3.5), 0),
		Obb.make(Vector2(4, -6.5), Vector2(14, 0.5), 0),
		Obb.make(Vector2(4, 6.5), Vector2(14, 0.5), 0),
		Obb.make(Vector2(-9.5, 0), Vector2(0.5, 7), 0),
		Obb.make(Vector2(17.5, 0), Vector2(0.5, 7), 0),
	]
	w.set_walls(walls)
	return w


func test_blink_crosses_thin_cover_at_normal_range() -> void:
	# A 0.5 m slab 2 m ahead: the far side is well within the 5 m range, so the blink goes its full range.
	var w := _two_rooms(1.75, 2.25)
	w.step(_f(0, U, 500))
	assert_almost_eq(w.player_pos().x, 5.0, 0.01, "crossed the slab")


func test_blink_stops_at_a_thick_wall_out_of_range() -> void:
	# A 2.8 m wall from x = 2.0 to 4.8: the first free spot beyond it is at 4.8 + 0.35 > 5 m, out of range, so
	# the blink ends at the last free spot before the wall.
	var w := _two_rooms(2.0, 4.8)
	w.step(_f(0, U, 500))
	var r := w.player.radius_m
	assert_lte(w.player_pos().x, 2.0 - r + 0.001, "stopped before the wall")
	assert_gt(w.player_pos().x, 2.0 - r - BLINK_STEP, "as close as it could get")


func test_blink_crosses_a_thick_wall_only_from_close_up() -> void:
	# The same rule pressed against a 3.0 m wall: the far side (3.0 + 2 radii = 3.7 m away) is within range.
	var w := _two_rooms(0.36, 3.36)
	w.step(_f(0, U, 500))
	assert_almost_eq(w.player_pos().x, 5.0, 0.01, "within range: through it")
	# The same 3.0 m wall 1.8 m ahead: its far side (5.15 m) is out of range, so the blink stops short.
	var far := _two_rooms(1.8, 4.8)
	far.step(_f(0, U, 500))
	assert_lte(
		far.player_pos().x, 1.8 - far.player.radius_m + 0.001, "out of range: stops before it"
	)
	assert_gt(far.player_pos().x, 1.0)


func test_blink_by_thickness_and_distance() -> void:
	# The rule as a table: for each wall thickness, the farthest the wall's near face may be (from the player's
	# centre) for a blink to cross it. It crosses exactly when the free spot beyond (face + thickness + radius) is
	# within range, to the 0.1 m blink step.
	var t := PlayerTable.starting_values()
	var lines := PackedStringArray()
	for thick: float in [0.5, 0.6, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]:
		var reach := -1.0
		for g in range(4, 50):
			var gap := g * 0.1
			var w := _two_rooms(gap, gap + thick)
			w.step(_f(0, U, 500))
			var crossed := w.player_pos().x > gap + thick
			var expect := gap + thick + t.radius_m <= t.blink_range_m + 0.001
			if absf(gap + thick + t.radius_m - t.blink_range_m) > BLINK_STEP:
				assert_eq(crossed, expect, "thickness %.1f, face %.1f m away" % [thick, gap])
			if crossed:
				reach = gap
		lines.append("%.1f m: %s" % [thick, "never" if reach < 0.0 else "face <= %.1f m" % reach])
	gut.p("blink %.1f m crosses a wall of thickness: %s" % [t.blink_range_m, "; ".join(lines)])


## Owner, 2026-10-07, "Thicker room walls": room walls reach 5.0 m (2 x FloorParams.wall_half_max), and the
## thickest can't be crossed with the 5 m blink even pressed against them.
func test_the_thickest_room_wall_holds_even_from_point_blank() -> void:
	var thickest := FloorParams.defaults().wall_half_max * 2.0
	assert_almost_eq(thickest, 5.0, 0.001)
	var w := _two_rooms(0.36, 0.36 + thickest)
	w.step(_f(0, U, 500))
	assert_lt(w.player_pos().x, 0.36, "pressed against a 5 m wall, the blink stays on this side")


func test_blink_never_lands_where_you_cannot_walk() -> void:
	# A thin wall that seals the room's far part off (no way round): beyond it is not reachable on foot, so the
	# blink stops before it although the far side is within range.
	var w := _world(PlayerTable.Utility.BLINK)
	var walls: Array[Obb] = [
		Obb.make(Vector2(2.0, 0), Vector2(0.25, 7), 0),
		Obb.make(Vector2(4, -6.5), Vector2(14, 0.5), 0),
		Obb.make(Vector2(4, 6.5), Vector2(14, 0.5), 0),
		Obb.make(Vector2(-9.5, 0), Vector2(0.5, 7), 0),
		Obb.make(Vector2(17.5, 0), Vector2(0.5, 7), 0),
	]
	w.set_walls(walls)
	w.step(_f(0, U, 500))
	assert_lte(
		w.player_pos().x, 1.75 - w.player.radius_m + 0.001, "the sealed side is out of bounds"
	)
	assert_gt(w.player_pos().x, 1.0)


func test_blinks_on_generated_floors_land_only_on_walkable_floor() -> void:
	# From every spawn point of three floors, a blink each of 8 ways: it ends clear of every wall (the gate
	# included), in the start's NavField region, inside a room or a doorway (never the void), within range and
	# on the line it was aimed along; one that ended beyond a wall had that wall's far side within range.
	var t := PlayerTable.starting_values()
	t.utility = PlayerTable.Utility.BLINK
	var crossed := 0
	var crossed_walls := 0
	var stopped := 0
	var blinks := 0
	for s in [3, 41, 2026]:
		var f := FloorGenerator.generate(s)
		var w := World.new(s, t, f.start_pos)
		var walls: Array[Obb] = f.walls.duplicate()
		walls.append(FloorScenario.gate_collider(f))
		w.set_walls(walls)
		var home := w.nav.region_near(f.start_pos)
		for room in f.room_count():
			for from in f.spawn_points[room]:
				for k in 8:
					w.actors.set_pos(0, from)
					w.move_intent = Vector2i.ZERO
					w.aim_angle = k * 512
					var to := PlayerKit.blink_target(w)
					blinks += 1
					var tag := "seed %d from %s angle %d -> %s" % [s, from, k * 512, to]
					for wall in walls:
						if Collide.circle_vs_obb(to, t.radius_m, wall) != Vector2.ZERO:
							assert_true(false, tag + ": in a wall")
					assert_eq(w.nav.region_near(to), home, tag)
					assert_true(_on_floor(f, to), tag + ": in the void")
					assert_lte(Kin.length(to - from), t.blink_range_m + 0.001, tag)
					var dir := Kin.dir(k * 512)
					var off := (to - from) - dir * (to - from).dot(dir)
					assert_lt(Kin.length(off), 0.001, tag + ": off its line")
					var hit := _wall_between(walls, from, to)
					if hit >= 0 and hit < f.slab_first:
						crossed_walls += 1
					elif hit >= 0:
						crossed += 1
					elif Kin.length(to - from) < t.blink_range_m - 0.05:
						stopped += 1
	gut.p(
		(
			"blinks on floors: %d, through a room wall %d, through cover only %d, stopped short %d"
			% [blinks, crossed_walls, crossed, stopped]
		)
	)
	assert_gt(crossed, 0, "some blinks cross cover")
	assert_gt(crossed_walls, 0, "some blinks cross a room wall")
	assert_gt(stopped, 0, "some blinks stop at a wall")


func _on_floor(f: FloorLayout, p: Vector2) -> bool:
	if f.room_of(p) >= 0:
		return true
	for i in f.door_centers.size():
		if f.door_rect(i).has_point(p):
			return true
	return false


## The lowest index of a wall on the segment between two points (sampled every 5 cm), or -1.
func _wall_between(walls: Array[Obb], a: Vector2, b: Vector2) -> int:
	var n := int(Kin.length(b - a) / 0.05)
	var best := -1
	for i in range(1, n):
		var q := a + (b - a) * (float(i) / n)
		for k in walls.size():
			if Collide.circle_vs_obb(q, 0.01, walls[k]) != Vector2.ZERO and (best < 0 or k < best):
				best = k
	return best


func test_blink_is_deterministic() -> void:
	var t := PlayerTable.starting_values()
	t.utility = PlayerTable.Utility.BLINK
	var hashes := []
	for run in 2:
		var f := FloorGenerator.generate(77)
		var w := World.new(77, t, f.start_pos)
		var walls: Array[Obb] = f.walls.duplicate()
		walls.append(FloorScenario.gate_collider(f))
		w.set_walls(walls)
		var path := PackedVector2Array()
		for i in 600:
			var pressed := U if i % (t.blink_cooldown_ticks + 1) == 0 else 0
			var move := Vector2i(127, 0) if (i / 90) % 2 == 0 else Vector2i(0, 127)
			w.step(InputFrame.make(move, (i * 37) % 4096, 300, 0, pressed))
			path.append(w.player_pos())
		hashes.append([w.state_hash(), path])
	assert_eq(hashes[0], hashes[1], "same floor, same input: same blinks")


func test_a_guard_player_cannot_blink() -> void:
	var w := _world(PlayerTable.Utility.GUARD)
	w.step(_f(0, U, 300))
	assert_eq(w.player_pos(), Vector2.ZERO)
