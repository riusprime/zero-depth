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


## The arena's radius (the ring's inner face) read back from a layout it built: the first wall's centre less its half.
static func radius_of(f: FloorLayout) -> float:
	if f == null or f.walls.is_empty():
		return 0.0
	return Kin.length(f.walls[0].center) - f.walls[0].half.x


## How many segments the ring has (the layout's walls; no wall stands inside).
static func segments_of(f: FloorLayout) -> int:
	return f.slab_first if f != null else 0
