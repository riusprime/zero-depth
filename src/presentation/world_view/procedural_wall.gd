class_name ProceduralWall
extends RefCounted
## v0.8.0 N10, option A (owners O66, O67): the floor's structural walls built as one modelled ruin instead of stacked
## kit pieces. O66: "a model that uses procedural generation of the walls, so we don't have to stack a model so many
## times … reduce the … number of triangles"; O67: "I don't want to lose the ruin texture … add some variance to it and
## don't make it a block with a texture". A pure function: the walls' footprints (StageView.wall_specs, axis-aligned
## structural walls only), the light props' niches, the rooms and doorways, and the floor seed in; mesh arrays out, one
## surface per sim wall (so occlusion still fades a wall on its own), the same for the same seed. Its draws come from
## the cosmetic stream (a RandomNumberGenerator seeded from the floor seed, and integer hashes salted from it), never
## from or into the sim (EI-05). Presentation only.
##
## Rules (starting values, tuned on screenshots):
## 1. Looks solid = is solid. The walls' union is cut on a grid (WallGrid) of every footprint's edges (so doorways,
##    T-joins and corners fall on grid lines), refined to STEP. The core is that union, its faces set INSET back
##    from the footprint (corners mitred: a corner vertex moves back along both faces), from BASE_Y to a ruined top.
##    Every face of the core is shared by exactly the cells beside it: no overlap, no gap, no z-fighting where walls
##    meet.
## 2. The top is laid stones: rows STONE deep, stones STONE_LONG long, each flat at its own height (_stone_h), with a
##    step face down to a lower neighbour, so joined walls agree and the top reads as stacked, broken masonry. The
##    height: height_at(x, y) at the stone (BASE_H, lowered in slumps (4 m noise) and collapsed stretches (7 m noise,
##    down to MIN_H), notched (1.5 m lattice: breaks through the top), a few tall remnants (3 m lattice)), jittered
##    per stone, STONE_MISSING of the stones gone from the top course; never below MIN_H (walls still read as walls),
##    never above MAX_H. v0.8.0 N13 (the N10 note: a thick wall's top read from above as a laid-stone platform): only
##    the rim is laid stones, the cells within RIM of the union's edge (each face's skin); deeper in, a thick wall's
##    top is its rubble fill: FILL_LUMP lumps (bigger than the rim's stones) sunk FILL_DROP below the top there, down
##    to FILL_MIN, darker (FILL_COL), so from above a thick wall reads as two ruined skins with broken fill between,
##    a wall top and not a floor. Thin walls (no cell that deep) are all rim, as before.
## 3. The face (O67, "blocks … with depth"): in front of the core, between it and the footprint, each straight face
##    run is laid in stone courses (COURSES, the same heights everywhere so corners line up), staggered blocks
##    BLOCK_MIN-BLOCK_MAX long with GAP joints. Per block, from the stream: flush with the footprint, recessed, or
##    missing (the core shows behind, darker); its front corners jittered; some with a chipped top corner; the upper
##    courses a little further back (a lean); never above the top. Pilasters every PILASTER_STEP on long runs; quoin
##    stones at outer corners (missing ones read as chipped corners); bent rebar out of the top on some stretches.
## 3b. v0.8.0 N13 (owner O71, "100% new": no kit pieces on the exterior walls): pillars, WallPillars' rules, where
##    N10's kit pillar accents stood: piers through a long thin wall's depth, flush with its faces, standing over its
##    top, in the same textures. The faces' courses, pilasters and rebar stop at them.
## 4. Fallen chunks: a few low stones (CHUNK_MAX_H, the decoration limit's rule) on the floor at a face's base, only
##    inside a room and DOOR_CLEAR from doorways.
## 5. The look: the owner's textures (tex_wall_<biome> on the faces, mapped once from the top down and repeating along
##    the wall; tex_wall_top_<biome> on everything that looks up), UVs in world metres at the biome's tile size so
##    nothing stretches (O68: about 4 m a tile, so the painted blocks read at the game's camera), mipmapped and
##    anisotropic (no shimmer); the face offset and flipped per SEGMENT_M stretch, the tops per stone, a
##    low-frequency brightness over stones and blocks (no visible tiling); vertex colour darkens the base (grime)
##    and the recesses; flat-shaded facets.
## 6. v0.8.0 N15 (owner O73, "Night biome textures look busy … less busy keeping this model?"): each biome calms its
##    walls without changing the model (WallCalm: its BiomeMood's wall_* values; the defaults are N13's look, the
##    stream's draws the same whatever the values, so a biome at the defaults builds exactly N13's walls).

## Grid refinement (m).
const STEP := 0.6
## The core's faces stand this far behind the footprint; the blocks fill the space in front.
const INSET := 0.12
## Blocks reach this far into the core (hidden), so a lean or jitter never opens a slit behind them.
const EMBED := 0.04
const BASE_Y := -0.02
const BASE_H := 1.0
const MIN_H := 0.55
const MAX_H := 1.4
## The top's stones (m), their height steps (m) and the share missing from the top course.
const STONE := 0.6
const STONE_LONG := Vector2(0.45, 1.05)
const STONE_STEP := 0.07
const STONE_MISSING := 0.15
## Course lines (m).
const COURSES: Array[float] = [0.0, 0.36, 0.7, 1.02, 1.4]
const GAP := 0.025
const BLOCK_MIN := 0.5
const BLOCK_MAX := 1.15
## Per block: missing, recessed (else flush).
const MISSING_CHANCE := 0.1
const RECESS_CHANCE := 0.25
const CHIP_CHANCE := 0.22
## Each course up sits this much further back (m).
const LEAN := 0.006
const QUOIN := 0.3
const QUOIN_CHANCE := 0.8
const PILASTER_MIN_RUN := 3.0
const PILASTER_STEP := Vector2(3.5, 6.0)
const REBAR_PER_M := 0.12
const CHUNK_PER_M := 0.3
const CHUNK_MAX_H := 0.25
const DOOR_CLEAR := 1.0
## v0.8.0 N13: the top's rim and fill (rule 2).
const RIM := 0.75
const FILL_LUMP := 1.2
const FILL_DROP := Vector2(0.36, 0.6)
const FILL_MIN := 0.25
const FILL_COL := Color(0.66, 0.64, 0.62)
## v0.8.0 N10 (owner O68, "too grained … make it bigger"): one tile of the face texture (3:2, the owner's
## tex_wall_<biome>) covers FACE_M_DEFAULT metres along the wall (its height follows the aspect), its top at
## FACE_TOP_Y; one tile of the top texture (tex_wall_top_<biome>) TOP_M_DEFAULT metres. Each biome sets its own
## (BiomeMood.wall_texture_m, wall_top_texture_m; build()'s "face_m", "top_m").
const FACE_M_DEFAULT := 4.0
const TOP_M_DEFAULT := 4.5
const TEX_ASPECT := 1.5
const FACE_TOP_Y := 1.45
## Along a face run the texture is offset and flipped per stretch of SEGMENT_M metres (the seams fall on block
## joints), so a long wall never shows the same tile twice in a row; and stones and blocks take a low-frequency
## brightness (VARIATION_M noise, VARIATION_LO..1) so long runs don't read as tiled.
const SEGMENT_M := Vector2(3.5, 5.0)
const VARIATION_M := 7.0
const VARIATION_LO := 0.8
const RUST := Color(0.42, 0.26, 0.17)
const FADED_ALPHA := 0.3
## Vertex colours: a step between stones, the core's face behind the blocks.
const STEP_FACE := Color(0.86, 0.84, 0.82)
const TOP_COL := Color(0.97, 0.96, 0.94)
const RECESS := Color(0.7, 0.68, 0.66)
## Evidence only (scripts/shots/walls_n10.gd grain=old): the look before O68's fix, to compare: 2.4 m and 3 m tiles,
## no mipmaps (the textures were first installed without them), no offsets, no variation.
static var legacy_look := false


## True for a wall this builder draws: structural (kind 0) and axis-aligned.
static func handles(w: Array) -> bool:
	return int(w[3]) == 0 and absf(sin(2.0 * float(w[2]))) < 0.001


## A wall's footprint on the sim plane (axis-aligned walls only).
static func footprint(w: Array) -> Rect2:
	var c: Vector2 = w[0]
	var half: Vector2 = w[1]
	if absf(cos(float(w[2]))) < 0.5:
		half = Vector2(half.y, half.x)
	return Rect2(c - half, half * 2.0)


## Builds the walls. `f` keys: "walls" (StageDresser's: [[center, half, yaw, kind, …]]), "cuts": [Rect2] (the
## light props' niches: the wall is open there), "rooms": [Rect2], "doors": [Rect2], "seed": int; v0.8.0 O68,
## "face_m", "top_m": the texture tiles' size (m; FACE_M_DEFAULT, TOP_M_DEFAULT); v0.8.0 N15, "calm": rule 6's
## builder values (WallCalm.calm_of; missing keys: WallCalm.BUILDER).
## Returns {"surfaces": {wall index: [its mesh arrays (one surface)]}, "tris": int, "face_m":
## float (the faces' length along the ground), "blocks": int, "walls": [the wall indices drawn], v0.8.0 N13
## "pillars": int, "pillar_rects": [Rect2] (their sim-plane footprints), and the top's rim and fill (rule 2):
## "top_rim_m2", "top_fill_m2" (their areas), "top_rim_h", "top_fill_h" (their mean heights, m)}.
static func build(f: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f.get("seed", 0)) * 7919 + 9241  # the cosmetic stream: presentation only
	var salt := rng.randi() & 0xFFFFF
	var walls: Array = f.get("walls", [])
	var rects: Array = []
	var owners := PackedInt32Array()
	for i in walls.size():
		if handles(walls[i]):
			rects.append(footprint(walls[i]))
			owners.append(i)
	var out := {"surfaces": {}, "tris": 0, "face_m": 0.0, "blocks": 0, "walls": Array(owners)}
	if rects.is_empty():
		return out
	var g := WallGrid.new(rects, owners, f.get("cuts", []))
	var calm := WallCalm.BUILDER.duplicate()
	calm.merge(f.get("calm", {}), true)
	var ctx := {
		"calm": calm,
		"g": g,
		"salt": salt,
		"rng": rng,
		"bufs": {},
		"rooms": f.get("rooms", []),
		"doors": f.get("doors", []),
		"blocks": 0,
		"stones": {},
		"face_m": float(f.get("face_m", FACE_M_DEFAULT)) if not legacy_look else 2.4,
		"top_m": float(f.get("top_m", TOP_M_DEFAULT)) if not legacy_look else 3.0,
		"fill": {},
		"pillars": [],
		"top_rim": Vector2.ZERO,
		"top_fill": Vector2.ZERO,
	}
	_core(ctx)
	ctx["pillars"] = WallPillars.spots(ctx, rects, owners, f.get("cuts", []))
	for p: Dictionary in ctx["pillars"]:
		WallPillars.build_one(ctx, p)
	var runs := _runs(g)
	for run: Dictionary in runs:
		out["face_m"] = float(out["face_m"]) + float(run["b"]) - float(run["a"])
		_face(ctx, run)
	var tris := 0
	for owner: int in ctx["bufs"]:
		var b: Buf = ctx["bufs"][owner]
		out["surfaces"][owner] = [b.arrays()]
		tris += b.v.size() / 3
	out["tris"] = tris
	out["blocks"] = ctx["blocks"]
	out["pillars"] = (ctx["pillars"] as Array).size()
	out["pillar_rects"] = (ctx["pillars"] as Array).map(
		func(p: Dictionary) -> Rect2: return p["rect"]
	)
	for k: String in ["top_rim", "top_fill"]:
		var t: Vector2 = ctx[k]
		out[k + "_m2"] = t.y
		out[k + "_h"] = t.x / t.y if t.y > 0.0 else 0.0
	return out


## The top's height (m) at a sim-plane point (rule 2): the same everywhere for a salt.
static func height_at(x: float, y: float, salt: int) -> float:
	var h := BASE_H
	var n4 := _value(x, y, 4.0, salt + 11)
	if n4 < 0.45:
		h -= (0.45 - n4) / 0.45 * 0.32
	var n7 := _value(x, y, 7.0, salt + 23)
	if n7 < 0.22:
		h = lerpf(h, MIN_H, clampf((0.22 - n7) / 0.12, 0.0, 1.0))
	h -= _feature(x, y, 1.5, salt + 37, 0.3, true)
	h += _feature(x, y, 3.0, salt + 51, 0.1, false)
	h += (_hash(roundi(x * 100.0), roundi(y * 100.0), salt + 67) - 0.5) * 0.1
	return clampf(h, MIN_H, MAX_H)


# --- the core (rule 1) ------------------------------------------------------------------------------------------


static func _core(ctx: Dictionary) -> void:
	var g: WallGrid = ctx["g"]
	var fill_col := FILL_COL * (float(ctx["calm"]["fill_shade"]) / 0.66)
	fill_col.a = 1.0
	var depth := g.edge_dist()
	var fill := PackedByteArray()
	fill.resize(g.nx * g.ny)
	for j in g.ny:
		for i in g.nx:
			if g.cells[j * g.nx + i] >= 0:
				var deep := depth[j * g.nx + i] >= RIM and not legacy_look
				fill[j * g.nx + i] = 1 if deep else 0
				g.cell_h[j * g.nx + i] = _fill_h(ctx, i, j) if deep else _stone_h(ctx, i, j)
				var area := (g.xs[i + 1] - g.xs[i]) * (g.ys[j + 1] - g.ys[j])
				var tally: Vector2 = ctx["top_fill" if deep else "top_rim"]
				ctx["top_fill" if deep else "top_rim"] = (
					tally + Vector2(area * g.cell_h[j * g.nx + i], area)
				)
	for j in g.ny:
		for i in g.nx:
			var owner := g.cells[j * g.nx + i]
			if owner < 0:
				continue
			var b := _buf(ctx, owner)
			var h := g.cell_h[j * g.nx + i]
			var k := g.cell_off[j * g.nx + i]
			b.top_off = Vector2(k, fposmod(k * 7.31, 1.0)) if not legacy_look else Vector2.ZERO
			b.u_off = 0.0
			b.u_flip = 1.0
			var x0 := (g.xs[i] + g.xs[i + 1]) * 0.5
			var y0 := (g.ys[j] + g.ys[j + 1]) * 0.5
			var top := (fill_col if fill[j * g.nx + i] == 1 else TOP_COL) * _variation(ctx, x0, y0)
			var p00 := _top(ctx, i, j, h)
			var p10 := _top(ctx, i + 1, j, h)
			var p11 := _top(ctx, i + 1, j + 1, h)
			var p01 := _top(ctx, i, j + 1, h)
			_tri(b, p00, p10, p11, Vector3.UP, top)
			_tri(b, p00, p11, p01, Vector3.UP, top)
			# Where the cell meets open ground: a face from the ground (darker: the recess behind the stones); where
			# it meets a lower stone: the step down to it.
			_edge(ctx, b, i + 1, j, h, p10, p11, Vector3.RIGHT)
			_edge(ctx, b, i - 1, j, h, p00, p01, Vector3.LEFT)
			_edge(ctx, b, i, j + 1, h, p01, p11, Vector3.FORWARD)
			_edge(ctx, b, i, j - 1, h, p00, p10, Vector3.BACK)


## A cell's edge toward cell (ni, nj): open ground gets a face from the ground (darker: the recess behind the
## stones), a lower stone the step down to it, a stone as high or higher nothing.
static func _edge(
	ctx: Dictionary, b: Buf, ni: int, nj: int, h: float, pa: Vector3, pc: Vector3, out: Vector3
) -> void:
	var g: WallGrid = ctx["g"]
	if g.at(ni, nj) < 0:
		_side(b, pa, pc, BASE_Y, out, RECESS)
		return
	var nh := g.cell_h[nj * g.nx + ni]
	if nh < h - 0.001:
		_side(b, pa, pc, nh, out, STEP_FACE)


## A face under the top edge ta-tc, down to height `low`.
static func _side(b: Buf, ta: Vector3, tc: Vector3, low: float, out: Vector3, col: Color) -> void:
	var ba := Vector3(ta.x, low, ta.z)
	var bc := Vector3(tc.x, low, tc.z)
	_tri(b, ba, bc, tc, out, col)
	_tri(b, ba, tc, ta, out, col)


## A grid vertex at height h, set back from the footprint where it lies on the union's edge (3D; the set-back cached).
static func _top(ctx: Dictionary, i: int, j: int, h: float) -> Vector3:
	var g: WallGrid = ctx["g"]
	var k := j * (g.nx + 1) + i
	if g.top_done[k] == 0:
		var off := _offset(g, i, j)
		g.tops[k] = Vector3(g.xs[i] + off.x, 0.0, -(g.ys[j] + off.y))
		g.top_done[k] = 1
	var p := g.tops[k]
	p.y = h
	return p


## A cell's top (rule 2): the stone it lies in (rows STONE m deep, each row's stones STONE_LONG long and shifted at
## random, so the top reads as laid stones of mixed sizes) at height_at(the stone's centre), jittered per stone, a
## few stones missing from the top course, snapped to STONE_STEP; within MIN_H..MAX_H.
static func _stone_h(ctx: Dictionary, i: int, j: int) -> float:
	var g: WallGrid = ctx["g"]
	var salt: int = ctx["salt"]
	var cx := (g.xs[i] + g.xs[i + 1]) * 0.5
	var cy := (g.ys[j] + g.ys[j + 1]) * 0.5
	var calm: Dictionary = ctx["calm"]
	var deep := STONE * float(calm["stone"])
	var row := floori(cy / deep)
	var wide := lerpf(STONE_LONG.x, STONE_LONG.y, _hash(row, 0, salt + 75)) * float(calm["stone"])
	var off := _hash(row, 1, salt + 76) * wide
	var col := floori((cx + off) / wide)
	var key := Vector2i(col, row)
	g.cell_off[j * g.nx + i] = _hash(col, row, salt + 77)  # its top texture's offset
	var cache: Dictionary = ctx["stones"]
	if cache.has(key):
		return cache[key]
	var h := height_at((col + 0.5) * wide - off, (row + 0.5) * deep, salt)
	h += -0.05 + (_hash(col, row, salt + 71) - 0.5) * 0.34 * float(calm["jitter"])  # -0.22..0.12 at 1
	if _hash(col, row, salt + 73) < STONE_MISSING * float(calm["breaks"]):
		h -= lerpf(0.2, 0.35, _hash(col, row, salt + 74))
	h = clampf(snappedf(h, STONE_STEP), MIN_H, MAX_H)
	cache[key] = h
	return h


## v0.8.0 N13: a thick wall's fill cell (rule 2): the lump (FILL_LUMP square) it lies in, sunk FILL_DROP under the
## top there, a few lumps fallen further; within FILL_MIN..MAX_H, snapped to STONE_STEP.
static func _fill_h(ctx: Dictionary, i: int, j: int) -> float:
	var g: WallGrid = ctx["g"]
	var salt: int = ctx["salt"]
	var cx := (g.xs[i] + g.xs[i + 1]) * 0.5
	var cy := (g.ys[j] + g.ys[j + 1]) * 0.5
	var calm: Dictionary = ctx["calm"]
	var lump := float(calm["fill_lump"])
	var noise := float(calm["fill_noise"])
	var key := Vector2i(floori(cx / lump), floori(cy / lump))
	g.cell_off[j * g.nx + i] = _hash(key.x, key.y, salt + 101)
	var cache: Dictionary = ctx["fill"]
	if cache.has(key):
		return cache[key]
	var h := height_at((key.x + 0.5) * lump, (key.y + 0.5) * lump, salt)
	var mid := (FILL_DROP.x + FILL_DROP.y) * 0.5
	h -= mid + (_hash(key.x, key.y, salt + 103) - 0.5) * (FILL_DROP.y - FILL_DROP.x) * noise
	if _hash(key.x, key.y, salt + 105) < STONE_MISSING * float(calm["breaks"]):
		h -= 0.15 * noise
	h = clampf(snappedf(h, STONE_STEP), FILL_MIN, MAX_H)
	cache[key] = h
	return h


## How far a grid vertex moves back from the footprint (sim plane): into the solid along each face it lies on,
## INSET (less beside a thin cell); none inside the union or off it.
static func _offset(g: WallGrid, i: int, j: int) -> Vector2:
	var sx := 0
	var sy := 0
	var n := 0
	for dj in range(-1, 1):
		for di in range(-1, 1):
			if g.at(i + di, j + dj) >= 0:
				n += 1
				sx += 1 if di == 0 else -1
				sy += 1 if dj == 0 else -1
	if n == 0 or n == 4:
		return Vector2.ZERO
	var ox := signf(sx)
	var oy := signf(sy)
	var mx := INSET
	var my := INSET
	if ox > 0.0:
		mx = minf(mx, (g.xs[i + 1] - g.xs[i]) * 0.45)
	elif ox < 0.0:
		mx = minf(mx, (g.xs[i] - g.xs[i - 1]) * 0.45)
	if oy > 0.0:
		my = minf(my, (g.ys[j + 1] - g.ys[j]) * 0.45)
	elif oy < 0.0:
		my = minf(my, (g.ys[j] - g.ys[j - 1]) * 0.45)
	return Vector2(ox * mx, oy * my)


# --- the face runs (rule 3) -------------------------------------------------------------------------------------


## Every straight stretch of the union's edge: {"axis": 0 (along x) | 1 (along y), "c": its line, "a", "b": its
## ends, "n": +1 | -1 (the open side along the other axis), "end_a", "end_b": &"convex" | &"concave"}.
static func _runs(g: WallGrid) -> Array:
	var out: Array = []
	for j in g.ny + 1:  # faces along x, on grid line y = ys[j]
		var prev := 0
		var start := 0
		for i in g.nx + 1:
			var t := 0
			if i < g.nx:
				var above := j < g.ny and g.cells[j * g.nx + i] >= 0
				var below := j > 0 and g.cells[(j - 1) * g.nx + i] >= 0
				if above != below:
					t = -1 if above else 1
			if t != prev:
				if prev != 0:
					out.append(_run(g, 0, j, start, i, prev))
				start = i
				prev = t
	for i in g.nx + 1:  # faces along y, on grid line x = xs[i]
		var prev := 0
		var start := 0
		for j in g.ny + 1:
			var t := 0
			if j < g.ny:
				var right := i < g.nx and g.cells[j * g.nx + i] >= 0
				var left := i > 0 and g.cells[j * g.nx + i - 1] >= 0
				if right != left:
					t = -1 if right else 1
			if t != prev:
				if prev != 0:
					out.append(_run(g, 1, i, start, j, prev))
				start = j
				prev = t
	return out


## A run on grid line `line` of `axis`, over cells k0..k1-1, its open side toward n; its ends' corner kinds.
static func _run(g: WallGrid, axis: int, line: int, k0: int, k1: int, n: int) -> Dictionary:
	var open := line - 1 if n < 0 else line  # the open row (axis 0) or column (axis 1)
	var end_a: bool
	var end_b: bool
	if axis == 0:
		end_a = g.at(k0 - 1, open) >= 0
		end_b = g.at(k1, open) >= 0
	else:
		end_a = g.at(open, k0 - 1) >= 0
		end_b = g.at(open, k1) >= 0
	var along := g.xs if axis == 0 else g.ys
	var across := g.ys if axis == 0 else g.xs
	return {
		"axis": axis,
		"line": line,
		"c": across[line],
		"a": along[k0],
		"b": along[k1],
		"n": n,
		"solid": line if n < 0 else line - 1,
		"end_a": &"concave" if end_a else &"convex",
		"end_b": &"concave" if end_b else &"convex",
	}


## A point in a run's frame (s along it, o out of the footprint (<= 0 inside), y up), in 3D.
static func _at(run: Dictionary, s: float, o: float, y: float) -> Vector3:
	var c: float = run["c"] + float(run["n"]) * o
	if run["axis"] == 0:
		return Vector3(s, y, -c)
	return Vector3(c, y, -s)


static func _sim(run: Dictionary, s: float, o: float) -> Vector2:
	var c: float = run["c"] + float(run["n"]) * o
	return Vector2(s, c) if run["axis"] == 0 else Vector2(c, s)


static func _out3(run: Dictionary) -> Vector3:
	return Vector3(0, 0, -float(run["n"])) if run["axis"] == 0 else Vector3(float(run["n"]), 0, 0)


static func _along3(run: Dictionary) -> Vector3:
	return Vector3.RIGHT if run["axis"] == 0 else Vector3.FORWARD


static func _face(ctx: Dictionary, run: Dictionary) -> void:
	var g: WallGrid = ctx["g"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var a: float = run["a"]
	var b: float = run["b"]
	run["seg_len"] = rng.randf_range(SEGMENT_M.x, SEGMENT_M.y)
	run["seg_key"] = roundi(float(run["c"]) * 100.0) * 7 + roundi(a * 100.0) * 3 + int(run["axis"])
	var inward := Vector2(0, -float(run["n"])) if run["axis"] == 0 else Vector2(-float(run["n"]), 0)
	var along := Vector2(1, 0) if run["axis"] == 0 else Vector2(0, 1)
	# Corners: an outer corner gets quoin stones (the x run lays them), both runs start past them; at an inner corner
	# the x run reaches over the core's corner, the y run stops at it.
	for k in 2:
		var end: StringName = run["end_a"] if k == 0 else run["end_b"]
		var corner_s := a if k == 0 else b
		var dir := 1.0 if k == 0 else -1.0  # into the run from this end
		if end == &"convex":
			var p := _sim(run, corner_s, 0.0)
			var q := minf(_extent(g, p, inward, along * dir), _extent(g, p, along * dir, inward))
			q = minf(minf(q, QUOIN), (b - a) * 0.5)
			if run["axis"] == 0 and q > 0.08:
				_quoins(ctx, run, corner_s, dir, q)
			if k == 0:
				a += maxf(q, 0.0)
			else:
				b -= maxf(q, 0.0)
		elif run["axis"] == 0:
			if k == 0:
				a -= INSET
			else:
				b += INSET
		else:
			if k == 0:
				a += GAP * 0.5
			else:
				b -= GAP * 0.5
	if b - a < 0.15:
		return
	# v0.8.0 N13: the pillars on this face, then the pilasters clear of them, then the courses between them.
	var spans := WallPillars.spans(ctx, run, a, b)
	var pillars := spans.duplicate()
	if b - a >= PILASTER_MIN_RUN:
		var s := a + rng.randf_range(1.5, 3.0)
		while s < b - 1.0:
			var w := rng.randf_range(0.36, 0.5)
			var sp := Vector2(s - w * 0.5, s + w * 0.5)
			if not WallPillars.near_any(sp, pillars, WallPillars.OTHER):
				spans.append(sp)
				_pilaster(ctx, run, sp.x, sp.y)
			s += rng.randf_range(PILASTER_STEP.x, PILASTER_STEP.y)
	spans.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var zones: Array = []
	var at := a
	for sp: Vector2 in spans:
		zones.append(Vector2(at, sp.x - GAP))
		at = sp.y + GAP
	zones.append(Vector2(at, b))
	for z: Vector2 in zones:
		if z.y - z.x < 0.12:
			continue
		for k in COURSES.size() - 1:
			_course(ctx, run, z.x, z.y, k)
	run["pillar_spans"] = pillars
	_rebar(ctx, run, a, b)
	_chunks(ctx, run, a, b)


## The face texture's offset and flip for what is drawn at s on a run: one per stretch of the run's seg_len metres.
static func _segment(ctx: Dictionary, run: Dictionary, b: Buf, s: float) -> void:
	if legacy_look:
		return
	var seg := floori((s - float(run["a"])) / float(run.get("seg_len", SEGMENT_M.x)))
	var key: int = run.get("seg_key", 0)
	var salt: int = ctx["salt"]
	b.u_off = _hash(seg, key, salt + 81)
	b.u_flip = -1.0 if _hash(seg, key, salt + 82) < 0.5 else 1.0


## The low-frequency brightness at a point (VARIATION_LO..1).
static func _variation(ctx: Dictionary, x: float, y: float) -> float:
	if legacy_look:
		return 1.0
	var lo := 1.0 - (1.0 - VARIATION_LO) * float(ctx.get("calm", WallCalm.BUILDER)["tint"])
	return lerpf(lo, 1.0, _value(x, y, VARIATION_M, int(ctx["salt"]) + 91))


## How far the union is solid from corner p along d (sampled just inside along e), up to QUOIN.
static func _extent(g: WallGrid, p: Vector2, d: Vector2, e: Vector2) -> float:
	var s := 0.05
	while s <= QUOIN + 0.001:
		if g.owner_at(p + d * s + e * 0.02) < 0:
			return s - 0.05
		s += 0.05
	return QUOIN


## The wall a run's point belongs to (just inside the footprint).
static func _owner(ctx: Dictionary, run: Dictionary, s: float) -> int:
	var g: WallGrid = ctx["g"]
	var w := g.owner_at(_sim(run, s, -0.05))
	if w < 0:
		w = g.owner_at(_sim(run, s, -INSET - 0.02))
	if w < 0:
		w = g.owner_at(_sim(run, clampf(s, run["a"] + 0.01, run["b"] - 0.01), -0.05))
	return w


## The lowest top over [s0, s1] at the footprint (the core's own top along the run's grid line).
static func _top_over(ctx: Dictionary, run: Dictionary, s0: float, s1: float) -> float:
	return minf(
		minf(_line_h(ctx, run, s0), _line_h(ctx, run, (s0 + s1) * 0.5)), _line_h(ctx, run, s1)
	)


## The core's top at s on a run: the height of the cell on its solid side there.
static func _line_h(ctx: Dictionary, run: Dictionary, s: float) -> float:
	var g: WallGrid = ctx["g"]
	var row: int = run["solid"]
	var i: int
	var j: int
	if run["axis"] == 0:
		i = clampi(g.xs.bsearch(s) - 1, 0, g.nx - 1)
		j = row
	else:
		i = row
		j = clampi(g.ys.bsearch(s) - 1, 0, g.ny - 1)
	if g.at(i, j) < 0:
		return MIN_H
	return g.cell_h[j * g.nx + i]


## One course of staggered blocks over [a, b].
static func _course(ctx: Dictionary, run: Dictionary, a: float, b: float, k: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var y0 := COURSES[k] + (0.0 if k == 0 else GAP * 0.5)
	var y1 := COURSES[k + 1] - GAP * 0.5
	var s := a
	var first := rng.randf_range(BLOCK_MIN * 0.5, BLOCK_MAX)
	var length := first
	while b - s > 0.06:
		if b - s - length < BLOCK_MIN * 0.6:
			length = b - s
		var s0 := s + GAP * 0.5
		var s1 := s + length - GAP * 0.5
		s += length
		length = rng.randf_range(BLOCK_MIN, BLOCK_MAX)
		if s1 - s0 < 0.08:
			continue
		var roll := rng.randf()
		var breaks := float(ctx["calm"]["breaks"])
		if roll < MISSING_CHANCE * breaks:
			continue
		var recess := rng.randf_range(0.0, 0.015)
		if roll < (MISSING_CHANCE + RECESS_CHANCE) * breaks:
			recess = rng.randf_range(0.04, 0.08)
		recess += LEAN * k
		var top := minf(y1, _top_over(ctx, run, s0, s1) - 0.03)
		if top - y0 < 0.1:
			continue
		_block(ctx, run, s0, s1, y0, top, -recess, k == 0, top < y1 - 0.01)


## A stone: a box in the run's frame from s0 to s1, y0 to y1, its front at o_front, its back inside the core. Its
## front corners jittered, one top corner chipped now and then; `broken`: its top edge ragged.
static func _block(
	ctx: Dictionary,
	run: Dictionary,
	s0: float,
	s1: float,
	y0: float,
	y1: float,
	o_front: float,
	on_ground: bool,
	broken: bool
) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var back := -(INSET + EMBED)
	var calm: Dictionary = ctx["calm"]
	var jit := float(calm["jitter"])
	var j := 0.008 * jit
	var d := 0.012 * jit
	# Front corners: bottom-left, bottom-right, top-right, top-left as [s, y, o].
	var fr: Array[Vector3] = [
		Vector3(s0 + rng.randf_range(-j, j), y0, o_front - rng.randf() * d),
		Vector3(s1 + rng.randf_range(-j, j), y0, o_front - rng.randf() * d),
		Vector3(
			s1 + rng.randf_range(-j, j), y1 + rng.randf_range(-j, j), o_front - rng.randf() * d
		),
		Vector3(
			s0 + rng.randf_range(-j, j), y1 + rng.randf_range(-j, j), o_front - rng.randf() * d
		),
	]
	if broken:
		fr[2].y -= rng.randf_range(0.0, 0.06) * jit
		fr[3].y -= rng.randf_range(0.0, 0.06) * jit
	if rng.randf() < CHIP_CHANCE * float(calm["breaks"]):
		var c := 2 if rng.randf() < 0.5 else 3
		var w := minf(rng.randf_range(0.05, 0.1), (s1 - s0) * 0.4)
		fr[c].x += -w if c == 2 else w
		fr[c].y -= minf(rng.randf_range(0.05, 0.1), (y1 - y0) * 0.5)
		fr[c].z -= rng.randf_range(0.02, 0.05)
	var bk: Array[Vector3] = [
		Vector3(s0, y0, back), Vector3(s1, y0, back), Vector3(s1, y1, back), Vector3(s0, y1, back)
	]
	var mid := (s0 + s1) * 0.5
	var c2 := _sim(run, mid, 0.0)
	var tint := (
		lerpf(1.0, rng.randf_range(0.82, 1.0), float(calm["tint"])) * _variation(ctx, c2.x, c2.y)
	)
	var col := Color(tint, tint, tint)
	var owner := _owner(ctx, run, mid)
	if owner < 0:
		return
	var b := _buf(ctx, owner)
	_segment(ctx, run, b, mid)
	var f3: Array[Vector3] = []
	var b3: Array[Vector3] = []
	for p in fr:
		f3.append(_at(run, p.x, minf(p.z, 0.0), p.y))
	for p in bk:
		b3.append(_at(run, p.x, p.z, p.y))
	var out := _out3(run)
	var al := _along3(run)
	_quad(b, f3[0], f3[1], f3[2], f3[3], out, col)
	_quad(b, f3[3], f3[2], b3[2], b3[3], Vector3.UP, col)
	_quad(b, f3[0], f3[3], b3[3], b3[0], -al, col)
	_quad(b, f3[1], b3[1], b3[2], f3[2], al, col)
	if not on_ground:
		_quad(b, f3[0], b3[0], b3[1], f3[1], Vector3.DOWN, col)
	ctx["blocks"] = int(ctx["blocks"]) + 1


## A stack of corner stones at an outer corner: q x q, one per course (some missing: a chipped corner).
static func _quoins(
	ctx: Dictionary, run: Dictionary, corner_s: float, dir: float, q: float
) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var s0 := corner_s if dir > 0.0 else corner_s - q
	var s1 := corner_s + q if dir > 0.0 else corner_s
	var top_h := _top_over(ctx, run, s0, s1)
	for k in COURSES.size() - 1:
		var y0 := COURSES[k] + (0.0 if k == 0 else GAP * 0.5)
		var y1 := minf(COURSES[k + 1] - GAP * 0.5, top_h - 0.02)
		if y1 - y0 < 0.1:
			break
		if rng.randf() >= 1.0 - (1.0 - QUOIN_CHANCE) * float(ctx["calm"]["breaks"]):
			continue
		# A corner stone is a box over the corner square: built as a block of depth q (its front on this face).
		var sub := run.duplicate()
		var back := -q
		_corner_block(ctx, sub, s0, s1, y0, y1, back, k == 0)


static func _corner_block(
	ctx: Dictionary,
	run: Dictionary,
	s0: float,
	s1: float,
	y0: float,
	y1: float,
	back: float,
	on_ground: bool
) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var owner := _owner(ctx, run, (s0 + s1) * 0.5)
	if owner < 0:
		return
	var b := _buf(ctx, owner)
	_segment(ctx, run, b, (s0 + s1) * 0.5)
	var dy := rng.randf_range(0.0, 0.05)
	var lo := [
		_at(run, s0, 0.0, y0), _at(run, s1, 0.0, y0), _at(run, s1, back, y0), _at(run, s0, back, y0)
	]
	var hi := [
		_at(run, s0, 0.0, y1 - dy),
		_at(run, s1, 0.0, y1 - rng.randf_range(0.0, 0.05)),
		_at(run, s1, back, y1),
		_at(run, s0, back, y1 - rng.randf_range(0.0, 0.03)),
	]
	var t := lerpf(1.0, rng.randf_range(0.86, 1.0), float(ctx["calm"]["tint"]))
	var col := Color(t, t, t)
	var out := _out3(run)
	var al := _along3(run)
	_quad(b, lo[0], lo[1], hi[1], hi[0], out, col)
	_quad(b, lo[2], lo[3], hi[3], hi[2], -out, col)
	_quad(b, lo[3], lo[0], hi[0], hi[3], -al, col)
	_quad(b, lo[1], lo[2], hi[2], hi[1], al, col)
	_quad(b, hi[0], hi[1], hi[2], hi[3], Vector3.UP, col)
	if not on_ground:
		_quad(b, lo[0], lo[3], lo[2], lo[1], Vector3.DOWN, col)
	ctx["blocks"] = int(ctx["blocks"]) + 1


## A pilaster over [s0, s1]: a full-height pier flush with the footprint, and a cap stone wider along the run.
static func _pilaster(ctx: Dictionary, run: Dictionary, s0: float, s1: float) -> void:
	var top := _top_over(ctx, run, s0 - 0.04, s1 + 0.04) - 0.02
	if top < 0.3:
		return
	_block(ctx, run, s0, s1, 0.0, top - 0.1, 0.0, true, false)
	_block(ctx, run, s0 - 0.04, s1 + 0.04, top - 0.1 + GAP * 0.5, top, 0.0, false, true)


## Bent rebar out of the top on some stretches (inside the footprint, bent along the run).
static func _rebar(ctx: Dictionary, run: Dictionary, a: float, b: float) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var n := int((b - a) * REBAR_PER_M + rng.randf())
	for k in n:
		if b - a < 0.8:
			return
		var s := rng.randf_range(a + 0.3, b - 0.3)
		if WallPillars.near_any(Vector2(s, s), run.get("pillar_spans", []), 0.1):
			continue
		var owner := _owner(ctx, run, s)
		if owner < 0:
			continue
		var buf := _buf(ctx, owner)
		var base := _at(run, s, -INSET - 0.06, _line_h(ctx, run, s) - 0.08)
		var up := rng.randf_range(0.22, 0.4)
		var lean := _along3(run) * rng.randf_range(-0.05, 0.05)
		var mid := base + Vector3.UP * up + lean
		var bend := _along3(run) * (1.0 if rng.randf() < 0.5 else -1.0)
		var tip := mid + (bend * rng.randf_range(0.08, 0.15) + Vector3.UP * 0.05)
		_rod(buf, base, mid, 0.025)
		_rod(buf, mid, tip, 0.022)


## A thin square rod from p to q (its four sides and its end), rust coloured.
static func _rod(b: Buf, p: Vector3, q: Vector3, w: float) -> void:
	var d := (q - p).normalized()
	var side := (
		d.cross(Vector3.FORWARD if absf(d.z) < 0.9 else Vector3.RIGHT).normalized() * w * 0.5
	)
	var up := d.cross(side).normalized() * w * 0.5
	var ring := [side + up, -side + up, -side - up, side - up]
	for k in 4:
		var r0: Vector3 = ring[k]
		var r1: Vector3 = ring[(k + 1) % 4]
		_quad(b, p + r0, p + r1, q + r1, q + r0, (r0 + r1).normalized(), RUST)
	_quad(b, q + ring[0], q + ring[1], q + ring[2], q + ring[3], d, RUST)


## Fallen chunks at a face's base (rule 4).
static func _chunks(ctx: Dictionary, run: Dictionary, a: float, b: float) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var s := a + 0.3
	while s < b - 0.3:
		var here := s
		s += 1.0
		if rng.randf() >= CHUNK_PER_M:
			continue
		var o := rng.randf_range(0.12, 0.4)
		var p := _sim(run, here, o)
		if not _in_any(p, ctx["rooms"], -0.2) or _in_any(p, ctx["doors"], DOOR_CLEAR):
			continue
		var owner := _owner(ctx, run, here)
		if owner < 0:
			continue
		var buf := _buf(ctx, owner)
		var sx := rng.randf_range(0.12, 0.3)
		var sz := rng.randf_range(0.1, 0.25)
		var h := rng.randf_range(0.08, CHUNK_MAX_H)
		var yaw := rng.randf() * TAU
		var basis := Basis(Vector3.UP, yaw)
		var c := SimPlane.to_3d(p)
		var lo: Array[Vector3] = []
		var hi: Array[Vector3] = []
		for k in 4:
			var corner := Vector3(
				sx * (0.5 if k in [1, 2] else -0.5), 0, sz * (0.5 if k >= 2 else -0.5)
			)
			lo.append(c + basis * corner + Vector3(0, BASE_Y, 0))
			var top := corner * rng.randf_range(0.5, 0.85)
			hi.append(c + basis * top + Vector3(0, h * rng.randf_range(0.6, 1.0), 0))
		var col := Color(0.8, 0.79, 0.77)
		_quad(buf, hi[0], hi[1], hi[2], hi[3], Vector3.UP, col)
		for k in 4:
			var k1 := (k + 1) % 4
			var mid := (lo[k] + lo[k1]) * 0.5 - c
			mid.y = 0.0
			_quad(buf, lo[k], lo[k1], hi[k1], hi[k], mid.normalized(), col)


static func _in_any(p: Vector2, rects: Array, grow: float) -> bool:
	for r: Rect2 in rects:
		if r.grow(grow).has_point(p):
			return true
	return false


# --- the mesh -------------------------------------------------------------------------------------------------


## One wall's surface (its vertex colour's alpha says which texture: 1 the top's, 0 the face's).
class Buf:
	## The texture tiles' size (m) and, for what is drawn next, the face's u offset (tiles) and flip (+1 / -1) and
	## the top's offset (tiles).
	var face_w := 4.0
	var top_w := 4.5
	var u_off := 0.0
	var u_flip := 1.0
	var top_off := Vector2.ZERO
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = c
		return arr


static func _buf(ctx: Dictionary, owner: int) -> Buf:
	var bufs: Dictionary = ctx["bufs"]
	if not bufs.has(owner):
		var b := Buf.new()
		b.face_w = ctx.get("face_m", FACE_M_DEFAULT)
		b.top_w = ctx.get("top_m", TOP_M_DEFAULT)
		bufs[owner] = b
	return bufs[owner]


static func _quad(
	b: Buf, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, hint: Vector3, col: Color
) -> void:
	_tri(b, p0, p1, p2, hint, col)
	_tri(b, p0, p2, p3, hint, col)


## One flat-shaded triangle facing `hint` (Godot's front faces wind clockwise), its colour darkened toward the
## ground (grime). One that looks up takes the top texture (alpha 1; UVs: x and z over the top tile, offset per
## stone); the rest the face texture (alpha 0; u along the wall over the face tile, offset and flipped per segment, v
## from FACE_TOP_Y down: the texture's top at the
## walls' top). SHADER picks the texture by that alpha, so a wall is one surface, one material, one draw.
static func _tri(b: Buf, p0: Vector3, p1: Vector3, p2: Vector3, hint: Vector3, col: Color) -> void:
	var cr := (p1 - p0).cross(p2 - p0)
	if cr.length_squared() < 1e-12:
		return
	if cr.dot(hint) > 0.0:
		var t := p1
		p1 = p2
		p2 = t
		cr = -cr
	var n := -cr.normalized()
	var up := n.y > 0.6
	var along_z := absf(n.x) >= absf(n.z)
	_vert(b, p0, n, up, along_z, col)
	_vert(b, p1, n, up, along_z, col)
	_vert(b, p2, n, up, along_z, col)


static func _vert(part: Buf, p: Vector3, n: Vector3, up: bool, along_z: bool, col: Color) -> void:
	part.v.append(p)
	part.n.append(n)
	if up:
		part.uv.append(Vector2(p.x / part.top_w, p.z * TEX_ASPECT / part.top_w) + part.top_off)
	else:
		var u: float = (p.z if along_z else p.x) * part.u_flip / part.face_w + part.u_off
		part.uv.append(Vector2(u, (FACE_TOP_Y - p.y) * TEX_ASPECT / part.face_w))
	var grime := lerpf(0.6, 1.0, smoothstep(0.0, 0.55, p.y))
	part.c.append(Color(col.r * grime, col.g * grime, col.b * grime, 1.0 if up else 0.0))


## The walls' material (one per floor; `faded`: the occlusion's dithered see-through copy; v0.8.0 N15, `look`: rule
## 6's shader values, WallCalm.look_of's keys; missing: N13's look).
static func material(
	face: Texture2D, top: Texture2D, faded: bool = false, look: Dictionary = {}
) -> ShaderMaterial:
	var sh := Shader.new()
	var code := WallCalm.SHADER.replace("//BIAS", str(WallCalm.SOFT_BIAS))
	if legacy_look:
		code = code.replace("filter_linear_mipmap_anisotropic", "filter_linear")
	sh.code = code.replace(
		"//FADE", "ALPHA = %s;\n\tALPHA_HASH_SCALE = 1.0;" % FADED_ALPHA if faded else ""
	)
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"face_tex", face)
	m.set_shader_parameter(&"top_tex", top if top != null else face)
	for k: String in ["detail", "face_contrast", "top_contrast"]:
		m.set_shader_parameter(StringName(k), float(look.get(k, 1.0)))
	return m


# --- the cosmetic noise ---------------------------------------------------------------------------------------


## A hash of a lattice point in [0, 1).
static func _hash(ix: int, iy: int, salt: int) -> float:
	var h := (ix * 374761393 + iy * 668265263 + salt * 982451653) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0


## Smooth value noise with lattice `cell` (m), in [0, 1].
static func _value(x: float, y: float, cell: float, salt: int) -> float:
	var gx := x / cell
	var gy := y / cell
	var ix := floori(gx)
	var iy := floori(gy)
	var fx := gx - ix
	var fy := gy - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(_hash(ix, iy, salt), _hash(ix + 1, iy, salt), fx)
	var b := lerpf(_hash(ix, iy + 1, salt), _hash(ix + 1, iy + 1, salt), fx)
	return lerpf(a, b, fy)


## The deepest notch (or highest remnant) at a point: square features on a `cell` lattice, one in a cell with
## `chance`, flat in their middle and sloping to nothing at their edge (at most 0.5 m across its centre, so only the
## lattice cells within 0.5 m of the point are looked at).
static func _feature(
	x: float, y: float, cell: float, salt: int, chance: float, notch: bool
) -> float:
	var best := 0.0
	var reach := 0.5
	for ix in range(floori((x - reach) / cell), floori((x + reach) / cell) + 1):
		for iy in range(floori((y - reach) / cell), floori((y + reach) / cell) + 1):
			if _hash(ix, iy, salt) >= chance:
				continue
			var px := (ix + _hash(ix, iy, salt + 1)) * cell
			var py := (iy + _hash(ix, iy, salt + 2)) * cell
			var d := maxf(absf(x - px), absf(y - py))
			var k3 := _hash(ix, iy, salt + 3)
			var r := lerpf(0.25, 0.5, k3) if notch else lerpf(0.3, 0.45, k3)
			if d >= r:
				continue
			var k4 := _hash(ix, iy, salt + 4)
			var depth := lerpf(0.2, 0.42, k4) if notch else lerpf(0.22, 0.4, k4)
			best = maxf(best, depth * clampf((r - d) / (r * 0.5), 0.0, 1.0))
	return best
