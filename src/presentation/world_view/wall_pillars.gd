class_name WallPillars
extends RefCounted
## v0.8.0 N13 (owner O71, "Walls should be 100% new with the textures"): ProceduralWall's pillars (its rule 3b), where
## N10's decimated kit pillar accents stood. On a wall at least MIN_WALL long and at most MAX_DEPTH thick, one every
## STEP (from FIRST in, never within END of the wall's ends), kept CLEAR from a light's niche, and only where a face
## is open ground OTHER along either side (no join): a pier through the wall's whole depth, flush with its faces
## (inside the footprint: looks solid = is solid), standing at least RISE over the wall's top round it, laid in
## courses (a plinth and a cap LIP wider along the wall, the shaft's courses alternately STEP_IN narrower), drawn into
## its wall's surface in the same textures, so it no longer clashes with it. The cosmetic stream only (its own
## RandomNumberGenerator from the builder's salt, and the builder's), never the sim (EI-05). Presentation only.

const MIN_WALL := 9.0
const MAX_DEPTH := 1.4
const STEP := Vector2(8.0, 12.0)
const FIRST := Vector2(4.0, 6.0)
const END := 2.0
const W := Vector2(0.62, 0.78)
const H := Vector2(1.3, 1.55)
const RISE := 0.2
const CLEAR := 1.4
const OTHER := 0.8
const LIP := 0.06
const STEP_IN := 0.07


## v0.8.0 N13 (rule 3b): where the pillars stand: [{"rect": Rect2 (sim plane, the wall's whole depth), "owner":
## int, "axis": 0 (the wall runs along x) | 1}], on long thin walls, clear of lights' niches and other walls.
static func spots(ctx: Dictionary, rects: Array, owners: PackedInt32Array, cuts: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ctx["salt"]) * 31 + 4057  # the cosmetic stream, its own draws
	var out: Array = []
	for k in rects.size():
		var r: Rect2 = rects[k]
		var axis := 0 if r.size.x >= r.size.y else 1
		var length := r.size[axis]
		var depth := r.size[1 - axis]
		if length < MIN_WALL or depth > MAX_DEPTH:
			continue
		var lo := r.position[axis]
		var at := lo + rng.randf_range(FIRST.x, FIRST.y)
		while at < lo + length - END:
			var w := rng.randf_range(W.x, W.y)
			var top := rng.randf_range(H.x, H.y)
			var spot := _span_of(r, axis, at - w * 0.5, at + w * 0.5)
			at += rng.randf_range(STEP.x, STEP.y)
			if _blocked(ctx["g"], spot, axis, cuts):
				continue
			top = maxf(top, _highest(ctx["g"], spot.grow(LIP)) + RISE)
			out.append({"rect": spot, "owner": owners[k], "axis": axis, "top": top})
	return out


## Rect r with its extent along `axis` set to s0..s1.
static func _span_of(r: Rect2, axis: int, s0: float, s1: float) -> Rect2:
	if axis == 0:
		return Rect2(s0, r.position.y, s1 - s0, r.size.y)
	return Rect2(r.position.x, s0, r.size.x, s1 - s0)


## A pillar spot is blocked near a light's niche, or where neither of the wall's faces is open ground all along the
## pillar and OTHER either side of it (a join, or a wall against both faces). A wall backed by another (two
## room frames back to back) keeps its pillar on its open face; its back stands into the other wall.
static func _blocked(g: WallGrid, spot: Rect2, axis: int, cuts: Array) -> bool:
	for c: Rect2 in cuts:
		if c.intersects(spot.grow(CLEAR)):
			return true
	for out: float in [spot.position[1 - axis] - 0.05, spot.end[1 - axis] + 0.05]:
		var open := true
		var s := spot.position[axis] - OTHER
		while open and s <= spot.end[axis] + OTHER + 0.001:
			if g.owner_at(Vector2(s, out) if axis == 0 else Vector2(out, s)) >= 0:
				open = false
			s += 0.2
		if open:
			return false
	return true


## The highest top of the cells a sim-plane rect touches.
static func _highest(g: WallGrid, r: Rect2) -> float:
	var top := ProceduralWall.MIN_H
	var i0 := clampi(g.xs.bsearch(r.position.x) - 1, 0, g.nx - 1)
	var i1 := clampi(g.xs.bsearch(r.end.x), 0, g.nx)
	var j0 := clampi(g.ys.bsearch(r.position.y) - 1, 0, g.ny - 1)
	var j1 := clampi(g.ys.bsearch(r.end.y), 0, g.ny)
	for j in range(j0, j1):
		for i in range(i0, i1):
			if g.cells[j * g.nx + i] >= 0:
				top = maxf(top, g.cell_h[j * g.nx + i])
	return top


## A pillar (rule 3b): its courses from the ground, each a stone box over the wall's depth: the plinth and the cap
## LIP wider along the wall, the shaft's courses alternately STEP_IN narrower; its top slightly broken.
static func build_one(ctx: Dictionary, p: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var r: Rect2 = p["rect"]
	var axis: int = p["axis"]
	var top: float = p["top"]
	var b := ProceduralWall._buf(ctx, p["owner"])
	b.u_off = rng.randf()
	b.u_flip = 1.0
	b.top_off = Vector2(rng.randf(), rng.randf())
	var lines: Array[float] = []
	for y in ProceduralWall.COURSES:
		if y < top - 0.3:
			lines.append(y)
	lines.append(top - 0.12)
	lines.append(top)
	var c := r.get_center()
	var noise := float(ctx.get("calm", WallCalm.BUILDER)["tint"])  # v0.8.0 N15: its tint noise
	var tint := (
		lerpf(1.0, rng.randf_range(0.86, 1.0), noise) * ProceduralWall._variation(ctx, c.x, c.y)
	)
	for k in lines.size() - 1:
		var y0 := lines[k] + (0.0 if k == 0 else ProceduralWall.GAP * 0.5)
		var y1 := lines[k + 1] - ProceduralWall.GAP * 0.5
		var along := 0.0
		if k == 0 or k == lines.size() - 2:
			along = LIP
		elif k % 2 == 0:
			along = -STEP_IN
		var box := _span_of(r, axis, r.position[axis] - along, r.end[axis] + along)
		var t := tint * lerpf(1.0, rng.randf_range(0.9, 1.0), noise)
		var dy := rng.randf_range(0.0, 0.05) if k == lines.size() - 2 else 0.0
		_box(b, box, y0, y1, dy, k == 0, Color(t, t, t))
		ctx["blocks"] = int(ctx["blocks"]) + 1


## A stone box over a sim-plane rect from y0 to y1 (its top's far edge `dy` lower: a worn cap); no bottom on the
## ground.
static func _box(
	b: ProceduralWall.Buf, r: Rect2, y0: float, y1: float, dy: float, on_ground: bool, col: Color
) -> void:
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	var corners: Array[Vector2] = [
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)
	]
	for k in 4:
		lo.append(SimPlane.to_3d(corners[k], y0))
		hi.append(SimPlane.to_3d(corners[k], y1 - (dy if k >= 2 else 0.0)))
	ProceduralWall._quad(b, hi[0], hi[1], hi[2], hi[3], Vector3.UP, col)
	for k in 4:
		var k1 := (k + 1) % 4
		var mid := (lo[k] + lo[k1]) * 0.5 - (lo[0] + lo[2]) * 0.5
		mid.y = 0.0
		ProceduralWall._quad(b, lo[k], lo[k1], hi[k1], hi[k], mid.normalized(), col)
	if not on_ground:
		ProceduralWall._quad(b, lo[0], lo[1], lo[2], lo[3], Vector3.DOWN, col)


## v0.8.0 N13: the pillars standing on a run's face, as spans along it (their lips and a joint included).
static func spans(ctx: Dictionary, run: Dictionary, a: float, b: float) -> Array:
	var out: Array = []
	var axis: int = run["axis"]
	var c: float = run["c"]
	for p: Dictionary in ctx["pillars"]:
		if int(p["axis"]) != axis:
			continue
		var r: Rect2 = p["rect"]
		var across0 := r.position[1 - axis]
		var across1 := r.end[1 - axis]
		if absf(c - across0) > 0.01 and absf(c - across1) > 0.01:
			continue
		var s0 := r.position[axis] - LIP - ProceduralWall.GAP
		var s1 := r.end[axis] + LIP + ProceduralWall.GAP
		if s1 > a and s0 < b:
			out.append(Vector2(maxf(s0, a), minf(s1, b)))
	return out


static func near_any(sp: Vector2, spans: Array, clear: float) -> bool:
	for o: Vector2 in spans:
		if sp.x < o.y + clear and sp.y > o.x - clear:
			return true
	return false
