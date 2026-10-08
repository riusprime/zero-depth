class_name RoomThemes
extends RefCounted
## Themed room interiors (v0.5.9 PLAN L8; owner, 2026-10-08: "distinct objects and combinations of them while
## keeping a logical and structured way of items to spawn … not the 9x9 diagonal wall design … like the image
## reference … saving the spacing we have now"). A room's theme lists vignettes (small authored clusters: a wreck
## and a crate, a supply pile, a burn barrel between barricades, a rock and a dead tree…), each anchored to a room
## corner, a wall, the centre, or free floor. Corners are tried first, then walls, then the centre, then free
## floor; FloorGenerator keeps a vignette only if it passes the same checks as any group (doorways, start and gate
## clear, the room one region), with one relaxation: a piece may touch a room wall exactly instead of keeping the
## slab gap from it (a flush piece makes no slit). The number of vignettes scales with the room's area; car wrecks
## are capped (owner: "max 2 per room of the size you show, if it's bigger it should increase proportionally").
## Each piece names the kit piece that draws it (presentation only; the sim never reads the name).
## Pure sim code: draws from the `map` stream, centimetres, no trig.

enum Anchor { CORNER, WALL, CENTRE, FREE }

## Room floor (m²) per vignette, and the bounds on a room's count (owner: the mockups' density "is about right").
const AREA_PER_VIGNETTE := 44.0
const MIN_VIGNETTES := 2
const MAX_VIGNETTES := 18
## Car wrecks: 2 per this much floor (the mockup rooms' 22 x 16 m), at least 1.
const CAR_AREA := 352.0
const CAR := &"car_wreck"
## The centre vignette only in a room at least this big (and never in the start hall: the start is its centre).
const CENTRE_MIN_AREA := 200.0
const ATTEMPTS := 12
const FLUSH_INSET := 0.001
## The free-floor lattice: cell pitch (a vignette plus the slab gap either side) and its inset from the walls.
const LATTICE := 7.5
const LATTICE_INSET := 4.0

## Vignettes: anchor, then pieces [piece, x0, y0, x1, y1] in the anchor's frame (metres):
## - CORNER: the corner at (0, 0), the room toward +x and +y;
## - WALL: the wall along y = 0, the room toward +y, centred on x = 0;
## - CENTRE and FREE: centred on (0, 0).
const VIGNETTES := {
	&"supply_pile":
	[
		Anchor.CORNER,
		[
			[&"crate_stack", 0.0, 0.0, 1.2, 1.2],
			[&"crate_stack", 1.2, 0.0, 2.4, 1.2],
			[&"crate_stack", 0.0, 1.2, 1.2, 2.4]
		]
	],
	&"wreck_corner":
	[Anchor.CORNER, [[CAR, 0.0, 0.0, 4.4, 2.0], [&"crate_stack", 3.2, 2.0, 4.4, 3.2]]],
	&"burn_corner":
	[Anchor.CORNER, [[&"fire_barrel", 0.0, 0.0, 0.7, 0.7], [&"crate_stack", 0.7, 0.0, 1.9, 1.2]]],
	&"outcrop_corner":
	[Anchor.CORNER, [[&"rock_large", 0.0, 0.0, 1.8, 1.8], [&"dead_tree", 1.8, 0.0, 3.0, 1.2]]],
	&"broken_corner":
	[Anchor.CORNER, [[&"wall_broken", 0.0, 0.0, 2.6, 0.6], [&"wall_broken", 0.0, 0.6, 0.6, 2.4]]],
	&"rock_and_crate":
	[Anchor.CORNER, [[&"rock_large", 0.0, 0.0, 1.6, 1.6], [&"crate_stack", 1.6, 0.0, 2.8, 1.2]]],
	&"barricade":
	[
		Anchor.WALL,
		[[&"wall_broken", -1.75, 0.0, 1.75, 0.6], [&"crate_stack", 1.75, 0.0, 2.95, 1.2]]
	],
	&"slab_pair": [Anchor.WALL, [[&"slab_wide", -1.6, 0.0, 1.6, 1.0]]],
	&"pilaster": [Anchor.WALL, [[&"wall_pillar", -0.6, 0.0, 0.6, 1.2]]],
	&"collapsed_stub":
	[Anchor.WALL, [[&"wall_1m", -0.6, 0.0, 0.6, 3.4], [&"wall_pillar", -0.8, 3.4, 0.8, 4.8]]],
	&"wreck_wall": [Anchor.WALL, [[CAR, -2.2, 0.0, 2.2, 2.0]]],
	&"mesa": [Anchor.WALL, [[&"rock_large", -0.8, 0.0, 0.8, 1.6]]],
	&"shrine":
	[
		Anchor.WALL,
		[[&"slab_concrete", -2.3, 0.0, -1.1, 1.0], [&"slab_concrete", 1.1, 0.0, 2.3, 1.0]]
	],
	&"lone_tree": [Anchor.WALL, [[&"dead_tree", -0.5, 0.0, 0.5, 1.0]]],
	&"crate": [Anchor.FREE, [[&"crate_stack", -0.6, -0.6, 0.6, 0.6]]],
	&"wreck": [Anchor.FREE, [[CAR, -2.0, -1.0, 2.0, 1.0]]],
	&"rock": [Anchor.FREE, [[&"rock_large", -0.9, -0.9, 0.9, 0.9]]],
	&"outcrop":
	[Anchor.FREE, [[&"rock_large", -1.4, -0.9, 0.4, 0.9], [&"dead_tree", 0.4, -0.5, 1.4, 0.5]]],
	&"pillar_pair":
	[
		Anchor.FREE,
		[[&"slab_concrete", -0.6, -3.7, 0.6, -2.5], [&"slab_concrete", -0.6, 2.5, 0.6, 3.7]]
	],
	&"burn_camp":
	[
		Anchor.CENTRE,
		[
			[&"fire_barrel", -0.4, -0.4, 0.4, 0.4],
			[&"wall_broken", -1.5, -4.3, 1.5, -3.7],
			[&"wall_broken", -1.5, 3.7, 1.5, 4.3]
		]
	],
}

## Themes (FloorLayout.Template values from SCRAPYARD on): per anchor, [vignette, weight] pairs.
const THEMES := {
	FloorLayout.Template.SCRAPYARD:
	{
		Anchor.CORNER: [[&"supply_pile", 3], [&"wreck_corner", 2], [&"burn_corner", 2]],
		Anchor.WALL: [[&"barricade", 3], [&"slab_pair", 2], [&"wreck_wall", 1]],
		Anchor.FREE: [[&"crate", 3], [&"wreck", 1]],
	},
	FloorLayout.Template.RUINED_HALL:
	{
		Anchor.CORNER: [[&"broken_corner", 3], [&"supply_pile", 1]],
		Anchor.WALL: [[&"pilaster", 4], [&"collapsed_stub", 2], [&"slab_pair", 1]],
		Anchor.FREE: [[&"pillar_pair", 3], [&"rock", 1]],
	},
	FloorLayout.Template.CAMP:
	{
		Anchor.CORNER: [[&"supply_pile", 3], [&"rock_and_crate", 2], [&"wreck_corner", 1]],
		Anchor.WALL: [[&"mesa", 2], [&"barricade", 2]],
		Anchor.CENTRE: [[&"burn_camp", 1]],
		Anchor.FREE: [[&"crate", 2], [&"rock", 2]],
	},
	FloorLayout.Template.OVERGROWN:
	{
		Anchor.CORNER: [[&"outcrop_corner", 4], [&"rock_and_crate", 1]],
		Anchor.WALL: [[&"lone_tree", 2], [&"mesa", 2], [&"shrine", 1]],
		Anchor.FREE: [[&"outcrop", 3], [&"rock", 2]],
	},
}


static func is_themed(template: int) -> bool:
	return THEMES.has(template)


## How many vignettes a room of area `area` (m²) gets.
static func count_for(area: float) -> int:
	return clampi(roundi(area / AREA_PER_VIGNETTE), MIN_VIGNETTES, MAX_VIGNETTES)


## How many car wrecks a room of area `area` may hold.
static func car_cap(area: float) -> int:
	return maxi(1, int(2.0 * area / CAR_AREA))


## Candidate vignettes for a room, in the order to try them, and how many of each anchor the room may keep:
## {"list": [{"pieces": Array[Obb], "tags": Array[StringName], "vignette", "anchor"}], "quota": {anchor: n}}.
## Corners first (all four, in a drawn order), then the centre, then walls, then free floor; each anchor gets a
## few times its quota in candidates, and FloorGenerator keeps one while it fits and the quota lasts.
static func candidates(template: int, r: Rect2, rng: RngStream, hall: bool) -> Dictionary:
	var theme: Dictionary = THEMES[template]
	var area := r.get_area()
	var total := count_for(area)
	var out: Array = []
	# Corners: each of the four in a drawn order.
	var corners := [0, 1, 2, 3]
	for k in range(3, 0, -1):
		var j := rng.range_int(0, k)
		var t: int = corners[k]
		corners[k] = corners[j]
		corners[j] = t
	for c: int in corners:
		var v := _pick(theme, Anchor.CORNER, rng)
		if v != &"":
			out.append(_corner(v, c, r))
	# The centre (a big room that isn't the start hall).
	if theme.has(Anchor.CENTRE) and area >= CENTRE_MIN_AREA and not hall:
		out.append(_free(_pick(theme, Anchor.CENTRE, rng), r.get_center(), false, r))
	var rest := maxi(total - 4, 0)
	var walls := (rest + 1) / 2
	for k in walls * ATTEMPTS / 4:
		var v := _pick(theme, Anchor.WALL, rng)
		if v != &"":
			out.append(_wall(v, rng.range_int(0, 3), r, rng))
	# Free floor: on a lattice of LATTICE-metre cells over the room (inset from the walls), one vignette per cell,
	# all turned the same way in a room, so the open floor reads as rows and aisles instead of a scatter.
	var cells := _lattice(r)
	for k in range(cells.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var t: Vector2 = cells[k]
		cells[k] = cells[j]
		cells[j] = t
	var turn := r.size.y > r.size.x
	for at: Vector2 in cells:
		var v := _pick(theme, Anchor.FREE, rng)
		if v != &"":
			out.append(_free(v, at, turn, r))
	return {
		"list": out,
		"quota":
		{Anchor.CORNER: 4, Anchor.CENTRE: 1, Anchor.WALL: walls, Anchor.FREE: rest - walls},
	}


## The free-floor lattice: cell centres LATTICE apart over the room inset by LATTICE_INSET, centred.
static func _lattice(r: Rect2) -> Array[Vector2]:
	var inner := r.grow(-LATTICE_INSET)
	var out: Array[Vector2] = []
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return out
	var nx := maxi(1, int(inner.size.x / LATTICE) + 1)
	var ny := maxi(1, int(inner.size.y / LATTICE) + 1)
	var span := Vector2((nx - 1) * LATTICE, (ny - 1) * LATTICE)
	var start := inner.get_center() - span * 0.5
	for i in nx:
		for j in ny:
			out.append(Vector2(_m(_cm(start.x + i * LATTICE)), _m(_cm(start.y + j * LATTICE))))
	return out


static func _pick(theme: Dictionary, anchor: int, rng: RngStream) -> StringName:
	if not theme.has(anchor):
		return &""
	var list: Array = theme[anchor]
	var w := PackedInt32Array()
	for e: Array in list:
		w.append(e[1])
	return list[rng.pick_weighted(w)][0]


static func _cm(metres: float) -> int:
	return roundi(metres * 100.0)


static func _m(cm: int) -> float:
	return cm / 100.0


## A candidate from pieces mapped by `to_world` (a corner rect in the anchor frame -> a world rect).
static func _make(v: StringName, to_world: Callable, r: Rect2) -> Dictionary:
	var pieces: Array[Obb] = []
	var tags: Array[StringName] = []
	for p: Array in VIGNETTES[v][1]:
		var a: Vector2 = to_world.call(Vector2(p[1], p[2]))
		var b: Vector2 = to_world.call(Vector2(p[3], p[4]))
		# Whole centimetres (nearest, so pieces that share an edge still share it after rounding).
		var lo := Vector2(_m(_cm(minf(a.x, b.x))), _m(_cm(minf(a.y, b.y))))
		var hi := Vector2(_m(_cm(maxf(a.x, b.x))), _m(_cm(maxf(a.y, b.y))))
		# And never past the room's own edges (which carry float noise below a centimetre): a flush piece stops
		# FLUSH_INSET inside, which still counts as touching (FloorGenerator: within 5 mm) and leaves no slit.
		lo = lo.max(r.position + Vector2(FLUSH_INSET, FLUSH_INSET))
		hi = hi.min(r.end - Vector2(FLUSH_INSET, FLUSH_INSET))
		pieces.append(Obb.make((lo + hi) * 0.5, (hi - lo) * 0.5, 0))
		tags.append(p[0])
	return {"pieces": pieces, "tags": tags, "vignette": v, "anchor": VIGNETTES[v][0]}


## Corner c (0: min x min y, 1: max x min y, 2: max x max y, 3: min x max y).
static func _corner(v: StringName, c: int, r: Rect2) -> Dictionary:
	var sx := 1.0 if c == 0 or c == 3 else -1.0
	var sy := 1.0 if c <= 1 else -1.0
	var origin := Vector2(
		r.position.x if sx > 0.0 else r.end.x, r.position.y if sy > 0.0 else r.end.y
	)
	return _make(v, func(q: Vector2) -> Vector2: return origin + Vector2(q.x * sx, q.y * sy), r)


## Wall side s (0: min y, 1: max x, 2: max y, 3: min x), at a drawn place along it.
static func _wall(v: StringName, s: int, r: Rect2, rng: RngStream) -> Dictionary:
	var along_len := r.size.x if s % 2 == 0 else r.size.y
	var t := rng.range_int(_cm(-along_len * 0.5 + 3.0), _cm(along_len * 0.5 - 3.0)) / 100.0
	var c := r.get_center()
	var map := func(q: Vector2) -> Vector2:
		match s:
			0:
				return Vector2(c.x + t + q.x, r.position.y + q.y)
			2:
				return Vector2(c.x + t + q.x, r.end.y - q.y)
			1:
				return Vector2(r.end.x - q.y, c.y + t + q.x)
		return Vector2(r.position.x + q.y, c.y + t + q.x)
	return _make(v, map, r)


## A free (or centre) vignette at `at`, turned a quarter when `turn`.
static func _free(v: StringName, at: Vector2, turn: bool, r: Rect2) -> Dictionary:
	return _make(v, func(q: Vector2) -> Vector2: return at + (Vector2(-q.y, q.x) if turn else q), r)
