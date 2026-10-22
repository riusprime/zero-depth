class_name FinalArena
extends RefCounted
## v0.8.0 FB1 (owner, F1/F2 decisions: "a new, not yet designed biome, exclusive to this fight, wih unique looking,
## rounded big room like a gladiator arena, but cosmic like"; FINAL_BOSS.md F2): the final arena's floor, a dedicated
## one-room FloorLayout (as FloorGenerator.one_room is the Playground's). The room is round: a regular polygon of
## `segments` wall segments whose inner faces stand radius_m from the centre (each a box WALL_HALF × 2 thick, long
## enough to close the corners, so the ring has no gap), nothing inside (no cover: the fight is the dodge). The room's
## interior rect is the circle's bounding square (room_of reads it; the corners past the ring are wall). The hero
## arrives START_FRACTION of the radius from the centre toward START_ANGLE (the iso camera's side, so the fight opens
## facing up the screen); the boss rises at the centre; the sealed great gate stands in the ring across from the hero
## (portal_pos, facing in: drawn only, the ring is its wall).
## Pure and deterministic: no stream is drawn (the seed is kept for the views' cosmetic stream).

## Half a wall segment's thickness (m).
const WALL_HALF := 0.6
## Segments must divide 2048 (half a segment's angle is then whole 1/4096 turns): 32 as shipped.
const SEGMENTS := 32
## Where the hero arrives: this share of the radius from the centre, toward START_ANGLE (1/4096 turns: -45°, the
## camera's side of the sim plane); the gate stands opposite.
const START_FRACTION := 0.72
const START_ANGLE := 3584
## v0.9.0 FA (owner C §3; Q18 "Stair causeway": "you arrive at the foot of a broad stair causeway (~25 m) up to a
## plateau"): the causeway's length (m), the ring segments on the hero's side left open for it (the walls of light),
## how far up from its foot the hero arrives (m), and the pylons' distance from the centre (a share of the radius).
const CAUSEWAY_M := 25.0
const GAP_SEGMENTS := 3
const FOOT_IN := 2.5
const PYLON_FRACTION := 0.62


## The arena's layout: radius_m from the centre to the ring's inner face, `segments` wall segments.
static func layout(seed_value: int, radius_m: float, segments: int = SEGMENTS) -> FloorLayout:
	var n := segments if segments >= 8 and 2048 % segments == 0 else SEGMENTS
	var r := maxf(radius_m, 6.0)
	var f := FloorLayout.new()
	f.seed_value = seed_value
	f.cols = 1
	f.rows = 1
	f.cell_size = Vector2(r * 2.0, r * 2.0)
	f.cell_pitch = f.cell_size
	f.grid_origin = Vector2(-r, -r)
	f.rooms.append(Rect2(-r, -r, r * 2.0, r * 2.0))
	f.room_cells.append(Rect2i(0, 0, 1, 1))
	for side in 4:
		f.room_halves.append(WALL_HALF)
	f.room_template.append(FloorLayout.Template.OPEN)
	f.room_layout.append(&"")
	f.room_turn.append(0)
	f.room_mirror.append(0)
	var half := Kin.dir(2048 / n)  # half a segment's angle: its tangent is y / x
	var half_len := (r + WALL_HALF * 2.0) * half.y / half.x + 0.05
	for k in n:
		var ang := k * 4096 / n
		f.walls.append(Obb.make(Kin.dir(ang) * (r + WALL_HALF), Vector2(WALL_HALF, half_len), ang))
	f.slab_first = f.walls.size()
	f.start_room = 0
	f.portal_room = 0
	f.start_pos = Kin.dir(START_ANGLE) * (r * START_FRACTION)
	f.hops = PackedInt32Array([0])
	f.spawn_points.resize(1)
	f.spawn_points[0] = PackedVector2Array()
	f.portal_pos = Kin.dir((START_ANGLE + 2048) & 4095) * (r + WALL_HALF)
	f.portal_angle = START_ANGLE
	f.boss_spawn = Vector2.ZERO
	var outer := r + WALL_HALF * 2.0
	f.ground.append(Rect2(-outer, -outer, outer * 2.0, outer * 2.0))
	f.bounds = Rect2(-outer - 1.0, -outer - 1.0, (outer + 1.0) * 2.0, (outer + 1.0) * 2.0)
	return f


## v0.9.0 FA (owner C §3: "a separate, quieter environment … stairs and a clear path leading toward a large altar";
## Q18: "the plateau is the arena: when the buildup ends, walls of light rise around it … No second load"): the final
## approach's floor. The plateau is layout()'s ring with GAP_SEGMENTS segments on the hero's side (round START_ANGLE)
## left open: those are the light walls (FloorLayout.light_walls), which the world adds when the buildup ends
## (FinalApproach). From the gap a causeway CAUSEWAY_M long runs out toward START_ANGLE, as wide as the gap, walled on
## both sides and at its foot; the hero arrives FOOT_IN up from its foot. The two pylons stand PYLON_FRACTION of the
## radius from the centre across the causeway's axis (the plateau's sides), the altar at the centre, where the boss
## rises. The sim is flat (the steps are drawn). The one room is the box round the plateau and the causeway.
static func approach_layout(
	seed_value: int, radius_m: float, segments: int = SEGMENTS
) -> FloorLayout:
	var f := layout(seed_value, radius_m, segments)
	var n := f.slab_first
	var r := radius_of(f)
	var step := 4096 / n
	var mid := ((START_ANGLE + step / 2) / step) % n
	var ring: Array[Obb] = []
	for k in n:
		var off := (k - mid + n) % n
		if mini(off, n - off) <= GAP_SEGMENTS / 2:
			f.light_walls.append(f.walls[k])
		else:
			ring.append(f.walls[k])
	var axis := Kin.dir(START_ANGLE)
	var side := Vector2(-axis.y, axis.x)
	var edge := Kin.dir(step * (GAP_SEGMENTS / 2) + step / 2)  # the gap's half angle: x its cosine, y its sine
	var half_w := r * edge.y
	var a0 := r * edge.x
	var a1 := r + CAUSEWAY_M + WALL_HALF * 2.0
	f.walls = ring
	for s in [-1.0, 1.0]:
		f.walls.append(
			Obb.make(
				axis * ((a0 + a1) * 0.5) + side * (s * (half_w + WALL_HALF)),
				Vector2((a1 - a0) * 0.5, WALL_HALF),
				START_ANGLE
			)
		)
	f.walls.append(
		Obb.make(axis * (a1 - WALL_HALF), Vector2(WALL_HALF, half_w + WALL_HALF * 2.0), START_ANGLE)
	)
	f.slab_first = f.walls.size()
	f.start_pos = axis * (r + CAUSEWAY_M - FOOT_IN)
	f.causeway_foot = f.start_pos
	f.causeway_top = axis * r
	f.causeway_half_w = half_w
	f.altar_pos = Vector2.ZERO
	f.pylons = PackedVector2Array([side * (r * PYLON_FRACTION), side * (-r * PYLON_FRACTION)])
	var reach := Rect2(f.rooms[0])
	for o in f.walls:
		reach = reach.merge(o.bounds())
	f.rooms[0] = reach
	f.ground.append(reach)
	f.bounds = reach.grow(1.0)
	return f


## The arena's radius (the ring's inner face) read back from a layout it built: the first wall's centre less its half.
static func radius_of(f: FloorLayout) -> float:
	if f == null or f.walls.is_empty():
		return 0.0
	return Kin.length(f.walls[0].center) - f.walls[0].half.x


## How many segments the ring has (the layout's walls; no wall stands inside).
static func segments_of(f: FloorLayout) -> int:
	return f.slab_first if f != null else 0
