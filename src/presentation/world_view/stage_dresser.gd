class_name StageDresser
extends RefCounted
## Builds a floor out of the owner's kit pieces (v0.5.9 Step 4, owner L2: "we use those procedurally with some
## rules"). A pure function: the floor's geometry in, a list of placed pieces out, the same for the same seed. Its
## draws come from the cosmetic stream (a RandomNumberGenerator seeded from the floor seed), never from or into
## the sim (EI-05).
##
## Rules (starting values, tuned on screenshots):
## 1. Looks solid = is solid. Anything taller than DECOR_MAX_HEIGHT sits inside a sim wall's or slab's footprint
##    and never leaves it; open floor only gets low decoration.
## 2. Structural walls are tiled along their length with wall_2m / wall_1m (about BROKEN_CHANCE of them broken),
##    with wall_pillar at both ends of a long wall. Heights jitter by ±HEIGHT_JITTER.
## 3. Cover slabs: near-square blocks become crate stacks or large rocks (Night Rocks: rocks and dead trees); long
##    thin slabs are tiled with concrete slabs. A car wreck only where a footprint is deep enough for one.
## 4. Light props: 0-2 per room (the start hall always 1), set into a structural wall on the room's side, never
##    within DOOR_CLEAR of a doorway or LIGHT_SPACING of another light.
## 5. Decoration: grass tufts along the room's walls, rubble and debris on open floor, kept KEEP_CLEAR away from
##    doorways, rewards and the portal.
## v0.8.0 N10 (owners O66, O67), a G2 prototype: rule 2 has three styles ("wall_style"), the owner picks:
## - STYLE_KIT (today's): as above.
## - STYLE_PROC (option A): ProceduralWall builds the structural walls as one modelled ruin; the dresser only keeps
##   rule 4's light props (each with a "niche": the sim-plane rect the wall leaves open for it) and sparse kit
##   accents: a wall_pillar every ACCENT_STEP m on walls at least ACCENT_MIN_WALL long and at most ACCENT_MAX_DEPTH
##   thick, drawn from its decimated copy (the corners get the builder's own quoin stones, so no pillar stacks on
##   them).
## - STYLE_FIT (option B): the kit kept, the stacking fixed: each stretch is laid edge to edge with pieces at their
##   natural length and height (FIT_LEN, the models' own proportions), in rows about FIT_DEPTH deep across a thick
##   wall (each row's depth fitted to its share of the wall), the
##   stretch's few cm of rest spread over its pieces (FIT_STRETCH at most on stretches of 2 m and more), never the
##   same piece twice in a row, each turned 180° and/or mirrored at random; pillars at both ends of a long wall; drawn
##   from the decimated kit copies (KitModels.get_lod_piece, "lod": true).

const DECOR_MAX_HEIGHT := 0.4
const BROKEN_CHANCE := 0.2
const HEIGHT_JITTER := 0.1
const PILLAR_MIN_WALL := 3.0
const LIGHT_SLOT := 0.9
const LIGHT_SPACING := 5.0
const DOOR_CLEAR := 1.8
const KEEP_CLEAR := 1.5
const GRASS_STEP := 1.1
const GRASS_CHANCE := 0.35
## Chance of each of a cover piece's 1-3 base tufts.
const BASE_GRASS_CHANCE := 0.7
## Rubble and debris pieces per square metre of room interior.
const SCATTER_DENSITY := 0.03
## Heights of the walls the sim describes (StageView's EDGE_WALL_HEIGHT and SLAB_HEIGHT).
const WALL_HEIGHT := 1.0
const SLAB_HEIGHT := 1.8
## v0.8.0 RT (owner O12): the square cover pieces a designed room names, restyled by the biome as the dresser's own
## square cover is (BiomeLook.square_cover; Night Rocks: rocks and dead trees); other pieces keep their name. And the
## decoration pieces (the biome's decor_swap, never past DECOR_MAX_HEIGHT).
const LAYOUT_SQUARE: Array[StringName] = [&"crate_stack", &"rock_large"]
const LAYOUT_DECOR: Array[StringName] = [&"grass_tuft", &"rubble_small", &"debris_low"]
## v0.8.0 N10: the wall styles.
const STYLE_KIT := &"kit"
const STYLE_PROC := &"proc"
const STYLE_FIT := &"fit"
## Option A's accents.
const ACCENT_MIN_WALL := 9.0
const ACCENT_MAX_DEPTH := 1.4
const ACCENT_STEP := Vector2(8.0, 12.0)
const ACCENT_PILLAR_W := 0.8
## Option B: each wall piece's natural length (m) at its natural height (KitModels.SPECS), from the loaded models'
## proportions (KitModels.get_piece(id)["size"].x: 0.902, 2.302, 0.954, 0.771); test_stage_dresser checks them.
const FIT_LEN := {&"wall_1m": 0.9, &"wall_2m": 2.3, &"wall_broken": 0.95, &"wall_pillar": 0.77}
const FIT_HEIGHT := {&"wall_1m": 1.0, &"wall_2m": 1.0, &"wall_broken": 0.7, &"wall_pillar": 1.3}
## The pieces a stretch is drawn from, by weight.
const FIT_PICK := {&"wall_2m": 5, &"wall_1m": 3, &"wall_broken": 2}
const FIT_STRETCH := 0.15
## A thick wall is laid in rows across its depth, each about this deep (the pieces' own depth, 0.58-0.9 m).
const FIT_DEPTH := 0.85
## How a stretch ends: the combination whose length is nearest the rest.
const FIT_ENDINGS: Array = [
	[],
	[&"wall_1m"],
	[&"wall_broken"],
	[&"wall_pillar"],
	[&"wall_2m"],
	[&"wall_1m", &"wall_broken"],
	[&"wall_broken", &"wall_1m"],
	[&"wall_2m", &"wall_1m"],
	[&"wall_1m", &"wall_2m"],
	[&"wall_2m", &"wall_broken"],
	[&"wall_broken", &"wall_2m"],
	[&"wall_1m", &"wall_pillar"],
	[&"wall_broken", &"wall_pillar"],
	[&"wall_2m", &"wall_pillar"],
]


## Places the kit over a floor. `f` keys:
## - "walls": [[center: Vector2, half: Vector2, yaw: float, kind: int, piece (optional StringName), layout height
##   (optional float)]] (kind 0 structural, 1 cover slab; a slab that names its piece is drawn with it; v0.8.0 RT: a
##   layout height >= 0 marks a designed room's blocker, drawn at that height (0: the kit's own) after the biome's
##   swap), the same order and yaw as StageView.wall_specs;
## - v0.8.0 RT, "props": the designed rooms' drawn-only pieces (WorldReader.layout_prop dictionaries);
## - "rooms": [Rect2] interiors; "start_room": int; "doors": [Rect2]; "keep_clear": [Vector2];
## - "biome": StringName; "seed": int;
## - v0.8.0 N10, "wall_style": STYLE_KIT (the default), STYLE_PROC or STYLE_FIT (see the rules above);
## - v0.7.5 NB1, a biome's look (BiomeLook; both optional, absent for the first three biomes): "square_cover"
##   {piece: int weight} draws square cover footprints with those pieces, and "decor_swap" {piece: piece} draws a
##   decoration piece as another (a kit or a code-made piece, CodeProps).
## Returns [{"piece": StringName, "xform": Transform3D (scales the unit-box piece), "wall": the wall index it
## belongs to (-1 for none), "kind": &"wall" | &"cover" | &"light" | &"decor"}] (v0.8.0 N10: STYLE_PROC's light
## props also carry "niche": Rect2; STYLE_FIT's wall pieces "lod": true).
static func dress(f: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f.get("seed", 0)) * 7919 + 4513  # the cosmetic stream: presentation only
	var out: Array = []
	var walls: Array = f.get("walls", [])
	var slots := _light_slots(f, rng)
	var style: StringName = f.get("wall_style", STYLE_KIT)
	for i in walls.size():
		var w: Array = walls[i]
		if w[3] == 0:
			if style == STYLE_PROC and ProceduralWall.handles(w):
				_dress_wall_proc(out, i, w, slots.get(i, []), rng)
			elif style == STYLE_FIT:
				_dress_wall_fit(out, i, w, slots.get(i, []), rng)
			else:
				_dress_wall(out, i, w, slots.get(i, []), rng)
		elif w.size() > 5 and float(w[5]) >= 0.0:  # v0.8.0 RT: a designed room's blocker
			_layout_named(out, i, w, f, rng)
		else:
			_dress_slab(out, i, w, f.get("biome", &""), rng, f.get("square_cover", {}))
	_layout_props(out, f, rng)
	_decorate(out, f, rng)
	return out


## The wall's long axis (unit, 3D), its length and thickness (m), and the yaw that turns a piece's +X onto it.
static func _frame(w: Array) -> Dictionary:
	var half: Vector2 = w[1]
	var yaw: float = w[2]
	if half.y > half.x:
		yaw += PI * 0.5
	var basis := Basis(Vector3.UP, yaw)
	return {
		"axis": basis * Vector3.RIGHT,
		"depth_axis": basis * Vector3.BACK,
		"length": maxf(half.x, half.y) * 2.0,
		"depth": minf(half.x, half.y) * 2.0,
		"yaw": yaw,
		"center": SimPlane.to_3d(w[0]),
	}


## A piece scaled to size (length along the frame's axis, height, depth), centred at `along` on the axis and
## `across` on the depth axis.
static func _place(fr: Dictionary, along: float, across: float, size: Vector3) -> Transform3D:
	var basis := Basis(Vector3.UP, fr["yaw"]) * Basis.from_scale(size)
	var origin: Vector3 = fr["center"] + fr["axis"] * along + fr["depth_axis"] * across
	return Transform3D(basis, origin)


static func _add(
	out: Array, piece: StringName, xform: Transform3D, wall: int, kind: StringName
) -> void:
	out.append({"piece": piece, "xform": xform, "wall": wall, "kind": kind})


static func _jitter(rng: RandomNumberGenerator, h: float) -> float:
	return h * rng.randf_range(1.0 - HEIGHT_JITTER, 1.0 + HEIGHT_JITTER)


static func _dress_wall(
	out: Array, i: int, w: Array, slots: Array, rng: RandomNumberGenerator
) -> void:
	var fr := _frame(w)
	var length: float = fr["length"]
	var depth: float = fr["depth"]
	var start := -length * 0.5
	var stop := length * 0.5
	if length >= PILLAR_MIN_WALL:
		var p := clampf(depth, 0.6, 1.4)
		for end in [start + p * 0.5, stop - p * 0.5]:
			_add(
				out,
				&"wall_pillar",
				_place(fr, end, 0.0, Vector3(p, _jitter(rng, 1.3), depth)),
				i,
				&"wall"
			)
		start += p
		stop -= p
	# Light slots cut the run into stretches; each slot holds a light prop on the room's side.
	var cuts: Array = []
	for s: Array in slots:
		cuts.append(s)
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var at := start
	for s: Array in cuts:
		var lo: float = s[0] - LIGHT_SLOT * 0.5
		_fill(out, i, fr, at, lo, rng)
		_light(out, i, fr, s[0], s[1], s[2])
		at = lo + LIGHT_SLOT
	_fill(out, i, fr, at, stop, rng)


## Wall pieces from a to b along the wall, the last one stretched to end exactly at b.
static func _fill(
	out: Array, i: int, fr: Dictionary, a: float, b: float, rng: RandomNumberGenerator
) -> void:
	var depth: float = fr["depth"]
	while b - a > 0.05:
		var rest := b - a
		var seg := 2.0 if rest >= 2.6 and rng.randf() < 0.6 else 1.0
		if rest - seg < 0.6:
			seg = rest
		var piece := &"wall_2m" if seg >= 1.6 else &"wall_1m"
		var h := _jitter(rng, WALL_HEIGHT)
		if rng.randf() < BROKEN_CHANCE:
			piece = &"wall_broken"
			h = _jitter(rng, 0.7)
		_add(out, piece, _place(fr, a + seg * 0.5, 0.0, Vector3(seg, h, depth)), i, &"wall")
		a += seg


## A light prop at `along`, on the side `side` (+1 or -1 along the depth axis), with a low broken wall behind it
## (v0.8.0 N10, `niche`: none; the procedural wall leaves the prop a niche instead, recorded on the placement).
static func _light(
	out: Array,
	i: int,
	fr: Dictionary,
	along: float,
	side: float,
	piece: StringName,
	niche: bool = false
) -> void:
	var depth: float = fr["depth"]
	var foot := minf(0.6, depth)
	var across := side * (depth - foot) * 0.5
	var h := 0.9 if piece == &"fire_barrel" else 2.0
	var w := foot if piece == &"fire_barrel" else minf(foot, 0.3)
	_add(out, piece, _place(fr, along, across, Vector3(w, h, w)), i, &"light")
	if niche:
		out[out.size() - 1]["niche"] = _niche(fr, along, side, foot, piece)
		return
	var behind := depth - foot
	if behind > 0.15:
		var back := -side * foot * 0.5
		_add(
			out,
			&"wall_broken",
			_place(fr, along, back, Vector3(LIGHT_SLOT, 0.55, behind)),
			i,
			&"wall"
		)


## v0.8.0 N10 (option A): a structural wall the procedural wall draws: its light props (in niches) and, on a long
## thin wall, a kit pillar every ACCENT_STEP m (kept 1.4 m from a light).
static func _dress_wall_proc(
	out: Array, i: int, w: Array, slots: Array, rng: RandomNumberGenerator
) -> void:
	var fr := _frame(w)
	var length: float = fr["length"]
	var depth: float = fr["depth"]
	for s: Array in slots:
		_light(out, i, fr, s[0], s[1], s[2], true)
	if depth > ACCENT_MAX_DEPTH or length < ACCENT_MIN_WALL:
		return
	var at := -length * 0.5 + rng.randf_range(4.0, 6.0)
	while at < length * 0.5 - 2.0:
		var clear := true
		for s: Array in slots:
			if absf(float(s[0]) - at) < 1.4:
				clear = false
		if clear:
			var size := Vector3(ACCENT_PILLAR_W, _jitter(rng, 1.3), depth)
			_add(out, &"wall_pillar", _place(fr, at, 0.0, size), i, &"wall")
			out[out.size() - 1]["lod"] = true  # its decimated copy
		at += rng.randf_range(ACCENT_STEP.x, ACCENT_STEP.y)


## v0.8.0 N10: the sim-plane rect a light prop's niche cuts from the procedural wall: LIGHT_SLOT wide (a brazier's
## 0.6), from the wall's face on the prop's side back over the prop's foot (leaving at least 0.12 m of wall behind).
static func _niche(
	fr: Dictionary, along: float, side: float, foot: float, piece: StringName
) -> Rect2:
	var depth: float = fr["depth"]
	var wide := LIGHT_SLOT if piece == &"fire_barrel" else 0.6
	var across := clampf(foot + 0.06, 0.0, maxf(depth - 0.12, foot * 0.5))
	var axis2 := Vector2(fr["axis"].x, -fr["axis"].z)
	var depth2 := Vector2(fr["depth_axis"].x, -fr["depth_axis"].z)
	var c := (
		SimPlane.to_sim(fr["center"])
		+ axis2 * along
		+ depth2 * side * (depth * 0.5 - across * 0.5 + 0.03)
	)
	var size := (
		Vector2(wide, across + 0.06) if absf(axis2.x) > 0.5 else Vector2(across + 0.06, wide)
	)
	return Rect2(c - size * 0.5, size)


## v0.8.0 N10: every niche the placements ask for (STYLE_PROC's light props).
static func niches(placements: Array) -> Array:
	var out: Array = []
	for p: Dictionary in placements:
		if p.has("niche"):
			out.append(p["niche"])
	return out


## v0.8.0 N10 (option B): a structural wall laid with whole kit pieces (see the rules above).
static func _dress_wall_fit(
	out: Array, i: int, w: Array, slots: Array, rng: RandomNumberGenerator
) -> void:
	var fr := _frame(w)
	var length: float = fr["length"]
	var first := out.size()
	var cuts: Array = slots.duplicate()
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var stretches: Array = []
	var at := -length * 0.5
	for s: Array in cuts:
		var lo: float = s[0] - LIGHT_SLOT * 0.5
		stretches.append(Vector2(at, lo))
		at = lo + LIGHT_SLOT
	stretches.append(Vector2(at, length * 0.5))
	var pillars := length >= PILLAR_MIN_WALL
	for k in stretches.size():
		var st: Vector2 = stretches[k]
		# Rows across a thick wall, each about FIT_DEPTH deep (its own pieces), so no piece is fattened to fill it.
		var rows := maxi(1, roundi(float(fr["depth"]) / FIT_DEPTH))
		var row_depth := float(fr["depth"]) / rows
		for r in rows:
			var across := -float(fr["depth"]) * 0.5 + (r + 0.5) * row_depth
			var ends := [pillars and k == 0, pillars and k == stretches.size() - 1]
			_fit(out, i, fr, st.x, st.y, rng, ends[0], ends[1], across, row_depth)
	for s: Array in cuts:
		_light(out, i, fr, s[0], s[1], s[2])
	for k in range(first, out.size()):
		if out[k]["kind"] == &"wall":
			out[k]["lod"] = true


## Whole pieces from a to b, edge to edge, the rest spread over them.
static func _fit(
	out: Array,
	i: int,
	fr: Dictionary,
	a: float,
	b: float,
	rng: RandomNumberGenerator,
	lead: bool,
	tail: bool,
	across: float = 0.0,
	depth: float = -1.0
) -> void:
	var length := b - a
	if length <= 0.05:
		return
	if depth < 0.0:
		depth = fr["depth"]
	var seq := fit_sequence(length, rng, lead, tail)
	var total := 0.0
	for piece: StringName in seq:
		total += float(FIT_LEN[piece])
	var k := length / total
	var prev := &""
	var prev_turn := false
	for piece: StringName in seq:
		var seg := float(FIT_LEN[piece]) * k
		var h := float(FIT_HEIGHT[piece]) * rng.randf_range(0.92, 1.08)
		var turn := rng.randf() < 0.5
		var mirror := rng.randf() < 0.5
		if piece == prev:  # the same piece again (only through a stretch's ending): never the same way round
			turn = not prev_turn
		var basis := (
			Basis(Vector3.UP, float(fr["yaw"]) + (PI if turn else 0.0))
			* Basis.from_scale(Vector3(seg * (-1.0 if mirror else 1.0), h, depth))
		)
		var origin: Vector3 = (
			fr["center"] + fr["axis"] * (a + seg * 0.5) + fr["depth_axis"] * across
		)
		_add(out, piece, Transform3D(basis, origin), i, &"wall")
		a += seg
		prev = piece
		prev_turn = turn


## v0.8.0 N10: the pieces for a stretch `length` m long: a pillar first and/or last (`lead`, `tail`), random pieces
## (never the same twice in a row) while more than 3.2 m is left, then the FIT_ENDINGS combination nearest the rest.
static func fit_sequence(
	length: float, rng: RandomNumberGenerator, lead: bool, tail: bool
) -> Array[StringName]:
	var seq: Array[StringName] = []
	var pillar: float = FIT_LEN[&"wall_pillar"]
	var used := 0.0
	if lead and length > pillar * 2.0:
		seq.append(&"wall_pillar")
		used += pillar
	var tail_len := pillar if tail and length - used > pillar * 2.0 else 0.0
	var prev: StringName = seq[seq.size() - 1] if not seq.is_empty() else &""
	while length - used - tail_len > 3.2:
		var pool := FIT_PICK.duplicate()
		pool.erase(prev)
		var pick := _pick(rng, pool)
		seq.append(pick)
		used += float(FIT_LEN[pick])
		prev = pick
	var rest := length - used - tail_len
	var best: Array = []
	var err := INF
	for combo: Array in FIT_ENDINGS:
		var sum := 0.0
		for p: StringName in combo:
			sum += float(FIT_LEN[p])
		if combo.is_empty() and seq.is_empty() and tail_len == 0.0:
			continue
		var e := absf(sum - rest)
		if not combo.is_empty() and combo[0] == prev:
			e += 0.1
		if e < err - 0.000001:
			err = e
			best = combo
	for p: StringName in best:
		seq.append(p)
	if tail_len > 0.0:
		seq.append(&"wall_pillar")
	return seq


static func _dress_slab(
	out: Array,
	i: int,
	w: Array,
	biome: StringName,
	rng: RandomNumberGenerator,
	square: Dictionary = {}
) -> void:
	var fr := _frame(w)
	var length: float = fr["length"]
	var depth: float = fr["depth"]
	if w.size() > 4 and StringName(w[4]) != &"":
		_named(out, i, fr, StringName(w[4]), rng)
		return
	if length / depth < 1.6 and not square.is_empty():  # v0.7.5 NB1: the biome's own square cover
		var choice := _pick(rng, square)
		var spec: Dictionary = KitModels.SPECS.get(
			choice, CodeProps.SPECS.get(choice, {"height": 1.2})
		)
		var size := Vector3(length, _jitter(rng, float(spec["height"])), depth)
		_add(out, choice, _place(fr, 0.0, 0.0, size), i, &"cover")
		return
	if length / depth < 1.6:
		var pick: StringName
		if biome == &"night_rocks":
			pick = &"dead_tree" if rng.randf() < 0.25 else &"rock_large"
		else:
			pick = &"crate_stack" if rng.randf() < 0.6 else &"rock_large"
		var h := _jitter(
			rng, 2.2 if pick == &"dead_tree" else (1.2 if pick != &"rock_large" else 1.1)
		)
		_add(out, pick, _place(fr, 0.0, 0.0, Vector3(length, h, depth)), i, &"cover")
		return
	if depth >= 1.2 and length >= 2.6 and length <= 5.0 and rng.randf() < 0.5:
		_add(
			out,
			&"car_wreck",
			_place(fr, 0.0, 0.0, Vector3(length, _jitter(rng, 1.4), depth)),
			i,
			&"cover"
		)
		return
	var a := -length * 0.5
	var b := length * 0.5
	while b - a > 0.05:
		var rest := b - a
		var seg := rng.randf_range(1.0, 1.6) if rest > 2.2 else rest
		var piece := &"slab_wide" if seg >= 1.3 else &"slab_concrete"
		var h := _jitter(rng, SLAB_HEIGHT)
		_add(out, piece, _place(fr, a + seg * 0.5, 0.0, Vector3(seg, h, depth)), i, &"cover")
		a += seg


static func _layout_swap(
	piece: StringName, biome: StringName, square: Dictionary, rng: RandomNumberGenerator
) -> StringName:
	if not piece in LAYOUT_SQUARE:
		return piece
	if not square.is_empty():
		return _pick(rng, square)
	if biome == &"night_rocks" and piece == &"crate_stack":
		return &"dead_tree" if rng.randf() < 0.25 else &"rock_large"
	return piece


static func _spec_of(piece: StringName) -> Dictionary:
	if KitModels.SPECS.has(piece):
		return KitModels.SPECS[piece]
	var cp: Dictionary = CodeProps.SPECS.get(piece, {})
	return {"height": float(cp.get("height", 1.2)), "role": &"cover"}


## v0.8.0 RT: a designed room's blocker, its piece swapped for the biome, filling its footprint at the layout's height
## (or the kit's own, jittered); a light piece carries its light.
static func _layout_named(
	out: Array, i: int, w: Array, f: Dictionary, rng: RandomNumberGenerator
) -> void:
	var fr := _frame(w)
	var piece := _layout_swap(StringName(w[4]), f.get("biome", &""), f.get("square_cover", {}), rng)
	var spec := _spec_of(piece)
	var kind: StringName = &"light" if spec["role"] == &"light" else &"cover"
	var h := float(w[5]) if float(w[5]) > 0.0 else _jitter(rng, float(spec["height"]))
	_add(out, piece, _place(fr, 0.0, 0.0, Vector3(fr["length"], h, fr["depth"])), i, kind)


## v0.8.0 RT: a designed room's drawn-only pieces: decoration (the biome's decor_swap; never past DECOR_MAX_HEIGHT,
## kept KEEP_CLEAR from doorways, rewards and the portal) and the pieces standing on its blockers (fading with them).
static func _layout_props(out: Array, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var swap: Dictionary = f.get("decor_swap", {})
	var keep: Array = f.get("keep_clear", [])
	var doors: Array = f.get("doors", [])
	for p: Dictionary in f.get("props", []):
		var wall: int = p["wall"]
		if wall == -2:
			continue  # its blocker was dropped (the boss door's way): it would float
		var piece: StringName = p["piece"]
		var size: Vector2 = p["size"]
		var at: Vector2 = p["pos"]
		var h := float(p["height"])
		var kind: StringName
		if piece in LAYOUT_DECOR:
			if _near_any_point(at, keep, KEEP_CLEAR) or _near_any_rect(at, doors, KEEP_CLEAR):
				continue
			piece = StringName(swap.get(piece, piece))
			if h <= 0.0:
				h = float(_spec_of(piece)["height"])
			h = minf(h, DECOR_MAX_HEIGHT)
			kind = &"decor"
		else:
			piece = _layout_swap(piece, f.get("biome", &""), f.get("square_cover", {}), rng)
			var spec := _spec_of(piece)
			if h <= 0.0:
				h = _jitter(rng, float(spec["height"]))
			kind = &"light" if spec["role"] == &"light" else &"cover"
		var basis := (
			Basis(Vector3.UP, SimPlane.yaw_of(int(p["angle"])))
			* Basis.from_scale(Vector3(size.x, h, size.y))
		)
		_add(out, piece, Transform3D(basis, SimPlane.to_3d(at)), wall, kind)


## A box that names its piece (a vignette's, PLAN L8): that piece fills the footprint at its natural height; a
## light piece (a burn barrel) also carries its light.
static func _named(
	out: Array, i: int, fr: Dictionary, piece: StringName, rng: RandomNumberGenerator
) -> void:
	var spec: Dictionary = KitModels.SPECS.get(piece, {"height": SLAB_HEIGHT, "role": &"cover"})
	var kind: StringName = &"light" if spec["role"] == &"light" else &"cover"
	var h := _jitter(rng, float(spec["height"]))
	var size := Vector3(fr["length"], h, fr["depth"])
	_add(out, piece, _place(fr, 0.0, 0.0, size), i, kind)


## {wall index: [[along, side, piece]]}: where each room's light props go.
static func _light_slots(f: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var slots := {}
	var placed: Array[Vector2] = []
	var walls: Array = f.get("walls", [])
	var rooms: Array = f.get("rooms", [])
	var doors: Array = f.get("doors", [])
	for r in rooms.size():
		var room: Rect2 = rooms[r]
		var want := 1 if r == int(f.get("start_room", -1)) else _weighted(rng, [0.15, 0.5, 0.35])
		var candidates: Array = []
		for i in walls.size():
			var w: Array = walls[i]
			if w[3] != 0:
				continue
			var fr := _frame(w)
			if fr["length"] < 2.0 or fr["depth"] < 0.5:
				continue
			if _wall_rect(w).intersects(room.grow(0.05)):
				candidates.append(i)
		for k in want:
			for attempt in 8:
				if candidates.is_empty():
					break
				var i: int = candidates[rng.randi() % candidates.size()]
				var w: Array = walls[i]
				var fr := _frame(w)
				var axis2 := Vector2(fr["axis"].x, -fr["axis"].z)
				var c: Vector2 = w[0]
				# The stretch of the wall that faces this room, inset from the room's corners.
				var lo := INF
				var hi := -INF
				for corner in [
					room.position,
					room.end,
					Vector2(room.position.x, room.end.y),
					Vector2(room.end.x, room.position.y)
				]:
					var t: float = (corner - c).dot(axis2)
					lo = minf(lo, t)
					hi = maxf(hi, t)
				lo = maxf(lo + 1.0, -fr["length"] * 0.5 + 1.2)
				hi = minf(hi - 1.0, fr["length"] * 0.5 - 1.2)
				if hi <= lo:
					continue
				var along := rng.randf_range(lo, hi)
				var depth_axis2 := Vector2(fr["depth_axis"].x, -fr["depth_axis"].z)
				var side := signf((room.get_center() - c).dot(depth_axis2))
				var p: Vector2 = c + axis2 * along + depth_axis2 * side * (float(fr["depth"]) * 0.5)
				if not room.grow(0.2).has_point(p):
					continue
				if (
					_near_any_rect(p, doors, DOOR_CLEAR)
					or _near_any_point(p, placed, LIGHT_SPACING)
				):
					continue
				var piece := (
					&"fire_barrel" if fr["depth"] >= 0.6 and rng.randf() < 0.75 else &"brazier_pole"
				)
				if not slots.has(i):
					slots[i] = []
				slots[i].append([along, side if side != 0.0 else 1.0, piece])
				placed.append(p)
				break
	return slots


static func _decorate(out: Array, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var swap: Dictionary = f.get("decor_swap", {})
	var doors: Array = f.get("doors", [])
	var keep: Array = f.get("keep_clear", [])
	# Grass at the bases of cover pieces (the reference's tufts around every block), just outside each footprint.
	for w: Array in f.get("walls", []):
		if w[3] != 1:
			continue
		var fr := _frame(w)
		var c: Vector2 = w[0]
		var axis2 := Vector2(fr["axis"].x, -fr["axis"].z)
		var depth2 := Vector2(fr["depth_axis"].x, -fr["depth_axis"].z)
		for k in rng.randi_range(1, 3):
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var along := rng.randf_range(-0.5, 0.5) * float(fr["length"])
			var p := c + axis2 * along + depth2 * side * (float(fr["depth"]) * 0.5 + 0.2)
			if _near_any_rect(p, doors, KEEP_CLEAR) or _near_any_point(p, keep, KEEP_CLEAR):
				continue
			if rng.randf() < BASE_GRASS_CHANCE:
				_decor(out, &"grass_tuft", p, rng.randf_range(0.6, 1.0), rng, swap)
	for room: Rect2 in f.get("rooms", []):
		# Grass along the room's four walls.
		var inner := room.grow(-0.3)
		if inner.size.x <= 0.0 or inner.size.y <= 0.0:
			continue
		var edges := [
			[inner.position, Vector2(inner.end.x, inner.position.y)],
			[Vector2(inner.end.x, inner.position.y), inner.end],
			[inner.end, Vector2(inner.position.x, inner.end.y)],
			[Vector2(inner.position.x, inner.end.y), inner.position],
		]
		for e: Array in edges:
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var n := int(a.distance_to(b) / GRASS_STEP)
			for k in n:
				if rng.randf() >= GRASS_CHANCE:
					continue
				var p := a.lerp(b, (k + rng.randf()) / maxf(n, 1))
				if _near_any_rect(p, doors, KEEP_CLEAR) or _near_any_point(p, keep, KEEP_CLEAR):
					continue
				_decor(out, &"grass_tuft", p, rng.randf_range(0.6, 1.0), rng, swap)
		# Rubble and debris on open floor.
		var count := int(room.get_area() * SCATTER_DENSITY)
		var open := room.grow(-1.0)
		if open.size.x <= 0.0 or open.size.y <= 0.0:
			continue
		for k in count:
			var p := Vector2(
				rng.randf_range(open.position.x, open.end.x),
				rng.randf_range(open.position.y, open.end.y)
			)
			if _near_any_rect(p, doors, KEEP_CLEAR) or _near_any_point(p, keep, KEEP_CLEAR):
				continue
			var piece := &"rubble_small" if rng.randf() < 0.65 else &"debris_low"
			_decor(out, piece, p, rng.randf_range(0.7, 1.2), rng, swap)


## A low decoration piece at its natural size × s, turned at random; its height never passes DECOR_MAX_HEIGHT.
static func _decor(
	out: Array,
	piece: StringName,
	p: Vector2,
	s: float,
	rng: RandomNumberGenerator,
	swap: Dictionary = {}
) -> void:
	piece = StringName(swap.get(piece, piece))  # v0.7.5 NB1: the biome's own decoration
	if CodeProps.has(piece):
		var cp: Dictionary = CodeProps.SPECS[piece]
		var cf: Vector2 = cp["foot"]
		var ch := minf(float(cp["height"]) * s, DECOR_MAX_HEIGHT)
		var cb := (
			Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(cf.x * s, ch, cf.y * s))
		)
		_add(out, piece, Transform3D(cb, SimPlane.to_3d(p)), -1, &"decor")
		return
	var spec: Dictionary = KitModels.SPECS[piece]
	var h := minf(float(spec["height"]) * s, DECOR_MAX_HEIGHT)
	# Footprints from KIT_REQUESTS (the loaded piece's own proportions replace these in StageView).
	var foot: Vector2 = (
		{
			&"grass_tuft": Vector2(0.5, 0.5),
			&"rubble_small": Vector2(0.6, 0.6),
			&"debris_low": Vector2(0.8, 0.4)
		}
		. get(piece, Vector2(0.5, 0.5))
	)
	var basis := (
		Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(foot.x * s, h, foot.y * s))
	)
	_add(out, piece, Transform3D(basis, SimPlane.to_3d(p)), -1, &"decor")


static func _wall_rect(w: Array) -> Rect2:
	var c: Vector2 = w[0]
	var half: Vector2 = w[1]
	var yaw: float = w[2]
	var ex := absf(half.x * cos(yaw)) + absf(half.y * sin(yaw))
	var ey := absf(half.x * sin(yaw)) + absf(half.y * cos(yaw))
	return Rect2(c - Vector2(ex, ey), Vector2(ex, ey) * 2.0)


static func _near_any_rect(p: Vector2, rects: Array, d: float) -> bool:
	for r: Rect2 in rects:
		if r.grow(d).has_point(p):
			return true
	return false


static func _near_any_point(p: Vector2, points: Array, d: float) -> bool:
	for q: Vector2 in points:
		if p.distance_to(q) < d:
			return true
	return false


## v0.7.5 NB1: a key of {key: int weight}, in proportion to its weight (one draw; keys in sorted order so the pick
## never depends on how the dictionary was written).
static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> StringName:
	var keys := weights.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	var total := 0
	for k: Variant in keys:
		total += int(weights[k])
	var x := rng.randf() * total
	for k: Variant in keys:
		x -= int(weights[k])
		if x < 0.0:
			return StringName(k)
	return StringName(keys[keys.size() - 1])


static func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var x := rng.randf()
	for k in weights.size():
		x -= weights[k]
		if x < 0.0:
			return k
	return weights.size() - 1
