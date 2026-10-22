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
## 2. Structural walls are ProceduralWall's (v0.8.0 N10 option A; N13, D50: every biome; N15, D53: the only style,
##    the kit's tiling and option B removed): the dresser only places rule 4's light props on them, each with a
##    "niche" (the sim-plane rect the wall leaves open for it). No kit piece on those walls (owner O71, "100% new").
##    A structural wall the builder cannot draw (not axis-aligned; the generator makes none) is dressed as cover.
## 3. Cover slabs: near-square blocks become crate stacks or large rocks (Night Rocks: rocks and dead trees); long
##    thin slabs are tiled with concrete slabs. A car wreck only where a footprint is deep enough for one.
## 4. Light props: 0-2 per room (the start hall always 1), set into a structural wall on the room's side, never
##    within DOOR_CLEAR of a doorway or LIGHT_SPACING of another light.
## 5. Decoration: grass tufts along the room's walls, rubble and debris on open floor, kept KEEP_CLEAR away from
##    doorways, rewards and the portal.
## 6. v0.8.0 MI (owner O78/O79: "the ones that not fit by context like the car should not go in every biome"; "every
##    biome get's their new assets generated in the way we meant to do it"): every footprint is dressed by its ROLE
##    (BiomeLook.ROLES: square cover, block, long slab, thin wall, post, deep wreck, landmark, wall prop, the three
##    decorations), and each biome draws a role from its own pool (BiomeLook.pools, "pools" here), so a piece only
##    shows in the biomes it fits (the car wreck only in Ruins). Designed rooms name roles; the kit names the
##    generator's vignettes still carry map onto roles (ROLE_OF). A pool's piece goes only where it fits (KitModels
##    min_foot / max_foot), at most max_per_floor times a floor (a unique landmark never repeats); a role without a
##    pool keeps the old rule (the Ruins kit's piece). A long footprint drawn with a short piece is tiled with it
##    (TILE_ASPECT), so nothing is stretched past its own proportions. Wall props (pool wall_prop: a ladder frame, a
##    skull post, a fish rack) stand in a niche the procedural wall leaves, inside the wall (rule 1).

const DECOR_MAX_HEIGHT := 0.4
const HEIGHT_JITTER := 0.1
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
## Height of the cover slabs the sim describes (StageView's SLAB_HEIGHT).
const SLAB_HEIGHT := 1.8
## v0.8.0 RT (owner O12): the square cover pieces a designed room names, restyled by the biome as the dresser's own
## square cover is (BiomeLook.square_cover; Night Rocks: rocks and dead trees); other pieces keep their name. And the
## decoration pieces (the biome's decor_swap, never past DECOR_MAX_HEIGHT).
const LAYOUT_SQUARE: Array[StringName] = [&"crate_stack", &"rock_large"]
const LAYOUT_DECOR: Array[StringName] = [&"grass_tuft", &"rubble_small", &"debris_low"]
## v0.8.0 MI: the role a kit name stands for (the generator's vignettes, RoomThemes, still name kit pieces; the sim
## never reads the name). A slab_concrete is a block when both its sides are BLOCK_MIN or more, else a long slab.
const ROLE_OF := {
	&"crate_stack": &"cover_square",
	&"rock_large": &"cover_square",
	&"dead_tree": &"cover_square",
	&"slab_concrete": &"cover_block",
	&"slab_wide": &"cover_long",
	&"wall_broken": &"cover_wall",
	&"wall_1m": &"cover_wall",
	&"wall_2m": &"cover_wall",
	&"wall_pillar": &"cover_post",
	&"car_wreck": &"cover_deep",
	&"grass_tuft": &"decor_grass",
	&"rubble_small": &"decor_rubble",
	&"debris_low": &"decor_debris",
}
## v0.8.0 MI: the piece a role draws when the biome has no pool for it (the Ruins kit's, the look before MI).
const LEGACY_PIECE := {
	&"cover_square": &"crate_stack",
	&"cover_block": &"slab_concrete",
	&"cover_long": &"slab_wide",
	&"cover_wall": &"wall_broken",
	&"cover_post": &"wall_pillar",
	&"cover_deep": &"car_wreck",
	&"landmark": &"slab_concrete",
	&"decor_grass": &"grass_tuft",
	&"decor_rubble": &"rubble_small",
	&"decor_debris": &"debris_low",
}
const BLOCK_MIN := 1.4
## v0.8.0 MI: a footprint this many times longer (for its depth) than the chosen piece's own footprint is tiled with
## the piece along its length instead of one stretched copy (at most TILE_MAX copies).
const TILE_ASPECT := 1.8
const TILE_MAX := 8
## v0.8.0 MI: a wall prop keeps this far from a doorway, a light prop and another wall prop (m), and needs a wall
## this much deeper than its own footprint (rule 1: it stands inside the wall).
const WALL_PROP_DOOR := 1.6
const WALL_PROP_SPACING := 2.5
const WALL_PROP_BACK := 0.1


## Places the kit over a floor. `f` keys:
## - "walls": [[center: Vector2, half: Vector2, yaw: float, kind: int, piece (optional StringName), layout height
##   (optional float)]] (kind 0 structural, 1 cover slab; a slab that names its piece is drawn with it; v0.8.0 RT: a
##   layout height >= 0 marks a designed room's blocker, drawn at that height (0: the kit's own) after the biome's
##   swap), the same order and yaw as StageView.wall_specs;
## - v0.8.0 RT, "props": the designed rooms' drawn-only pieces (WorldReader.layout_prop dictionaries);
## - "rooms": [Rect2] interiors; "start_room": int; "doors": [Rect2]; "keep_clear": [Vector2];
## - "biome": StringName; "seed": int;
## - v0.7.5 NB1, a biome's look (BiomeLook; both optional, absent for the first three biomes): "square_cover"
##   {piece: int weight} draws square cover footprints with those pieces, and "decor_swap" {piece: piece} draws a
##   decoration piece as another (a kit or a code-made piece, CodeProps).
## Returns [{"piece": StringName, "xform": Transform3D (scales the unit-box piece), "wall": the wall index it
## belongs to (-1 for none), "kind": &"cover" | &"light" | &"decor"}] (v0.8.0 N10: a structural wall's light props
## also carry "niche": Rect2).
## - v0.8.0 MI, a biome's piece pools (look_input(look)): "pools" {role: {piece: weight}}, "max_per_floor"
##   {piece: n}, "wall_props_per_room" and "wall_prop_chance" (BiomeLook's fields).
static func dress(f: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f.get("seed", 0)) * 7919 + 4513  # the cosmetic stream: presentation only
	var out: Array = []
	var walls: Array = f.get("walls", [])
	f["_counts"] = {}  # v0.8.0 MI: per piece, how many this floor has drawn (max_per_floor)
	var slots := _light_slots(f, rng)
	var props := _wall_prop_slots(f, slots, rng)  # v0.8.0 MI
	for i in walls.size():
		var w: Array = walls[i]
		if w[3] == 0 and ProceduralWall.handles(w):
			_dress_wall_proc(out, i, w, slots.get(i, []))
			_dress_wall_props(out, i, w, props.get(i, []))
		elif w.size() > 5 and float(w[5]) >= 0.0:  # v0.8.0 RT: a designed room's blocker
			_layout_named(out, i, w, f, rng)
		else:
			_dress_slab(out, i, w, f.get("biome", &""), rng, f.get("square_cover", {}), f)
	_layout_props(out, f, rng)
	_decorate(out, f, rng)
	f.erase("_counts")
	return out


## v0.8.0 MI: a biome's look as the dresser's input keys (main thread: it asks which pieces are installed, so a
## missing model drops out of its pools; L15). Empty for no look.
static func look_input(look: BiomeLook) -> Dictionary:
	if look == null:
		return {}
	var pools := {}
	for role: Variant in look.pools:
		var pool := {}
		var src: Dictionary = look.pools[role]
		for k: Variant in src:
			if StageKit.has_piece(StringName(str(k))):
				pool[StringName(str(k))] = int(src[k])
		if not pool.is_empty():
			pools[StringName(str(role))] = pool
	var caps := {}
	for k: Variant in look.max_per_floor:
		caps[StringName(str(k))] = int(look.max_per_floor[k])
	return {
		"square_cover": _names(look.square_cover),
		"decor_swap": _names(look.decor_swap),
		"pools": pools,
		"max_per_floor": caps,
		"wall_props_per_room": look.wall_props_per_room,
		"wall_prop_chance": look.wall_prop_chance,
	}


## A look dictionary with StringName keys (and values, when they are text), whatever the .tres wrote.
static func _names(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		var v: Variant = d[k]
		out[StringName(str(k))] = StringName(str(v)) if v is String or v is StringName else v
	return out


## v0.8.0 MI: the role a footprint named `name` takes (a role name is itself; a kit name maps by ROLE_OF; a
## slab_concrete narrower than BLOCK_MIN is a long slab; anything else: &"" and it keeps its own name).
static func role_of(name: StringName, fr: Dictionary = {}) -> StringName:
	if name in BiomeLook.ROLES:
		return name
	var role: StringName = ROLE_OF.get(name, &"")
	if role == &"cover_block" and not fr.is_empty() and float(fr["depth"]) < BLOCK_MIN:
		return &"cover_long"
	return role


## v0.8.0 MI: the piece the biome draws for `role` on a footprint whose shorter side is `depth` (m): a weighted pick
## from its pool among the pieces that fit (min_foot / max_foot) and are under their floor cap; then counted. A
## role without a pool (or nothing that fits): `fallback` (the kit name the footprint carried), else LEGACY_PIECE.
static func pick_piece(
	f: Dictionary,
	role: StringName,
	depth: float,
	rng: RandomNumberGenerator,
	fallback: StringName = &""
) -> StringName:
	var pools: Dictionary = f.get("pools", {})
	var pool: Dictionary = pools.get(role, {})
	if pool.is_empty() and role == &"cover_square":
		pool = f.get("square_cover", {})  # the pre-MI look
	var counts: Dictionary = f.get("_counts", {})
	var caps: Dictionary = f.get("max_per_floor", {})
	var fits := {}
	for relax in 2:  # the second pass lets any size fit (BiomeLook keeps an uncapped piece in every pool)
		for k: Variant in pool:
			var id := StringName(k)
			var spec: Dictionary = KitModels.SPECS.get(id, {})
			if depth > 0.0 and relax == 0:
				if depth < float(spec.get("min_foot", 0.0)) - 0.001:
					continue
				if depth > float(spec.get("max_foot", INF)) + 0.001:
					continue
			if caps.has(id) and int(counts.get(id, 0)) >= int(caps[id]):
				continue
			fits[id] = pool[k]
		if not fits.is_empty():
			break
	var piece: StringName
	if not fits.is_empty():
		piece = _pick(rng, fits)
	elif fallback != &"":
		piece = fallback
	else:
		piece = LEGACY_PIECE.get(role, &"crate_stack")
	counts[piece] = int(counts.get(piece, 0)) + 1
	return piece


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


## A light prop at `along`, on the side `side` (+1 or -1 along the depth axis); the procedural wall leaves it a niche
## (v0.8.0 N10), recorded on the placement.
static func _light(
	out: Array, i: int, fr: Dictionary, along: float, side: float, piece: StringName
) -> void:
	var depth: float = fr["depth"]
	var foot := minf(0.6, depth)
	var across := side * (depth - foot) * 0.5
	var h := 0.9 if piece == &"fire_barrel" else 2.0
	var w := foot if piece == &"fire_barrel" else minf(foot, 0.3)
	_add(out, piece, _place(fr, along, across, Vector3(w, h, w)), i, &"light")
	out[out.size() - 1]["niche"] = _niche(fr, along, side, foot, piece)


## v0.8.0 N10 (option A): a structural wall the procedural wall draws: only its light props, in niches (v0.8.0 N13:
## no kit pillar accents; ProceduralWall lays its own pillars).
static func _dress_wall_proc(out: Array, i: int, w: Array, slots: Array) -> void:
	var fr := _frame(w)
	for s: Array in slots:
		_light(out, i, fr, s[0], s[1], s[2])


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


## v0.8.0 N10: every niche the placements ask for (the structural walls' light props).
static func niches(placements: Array) -> Array:
	var out: Array = []
	for p: Dictionary in placements:
		if p.has("niche"):
			out.append(p["niche"])
	return out


static func _dress_slab(
	out: Array,
	i: int,
	w: Array,
	biome: StringName,
	rng: RandomNumberGenerator,
	square: Dictionary = {},
	f: Dictionary = {}
) -> void:
	var fr := _frame(w)
	var length: float = fr["length"]
	var depth: float = fr["depth"]
	if w.size() > 4 and StringName(w[4]) != &"":
		_named(out, i, fr, StringName(w[4]), rng, f)
		return
	var pools: Dictionary = f.get("pools", {})
	if length / depth < 1.6:
		# v0.8.0 MI: a near-square footprint: the biome's square cover (a big one, both sides BLOCK_MIN + 0.6 or
		# more, its blocks); v0.7.5 NB1 square_cover; else the old rule.
		var role := (
			&"cover_block"
			if depth >= BLOCK_MIN + 0.6 and pools.has(&"cover_block")
			else &"cover_square"
		)
		if pools.has(role) or not square.is_empty():
			var choice := pick_piece(
				f if not f.is_empty() else {"square_cover": square}, role, depth, rng
			)
			var spec := _spec_of(choice)
			var size := Vector3(length, _jitter(rng, float(spec["height"])), depth)
			_add(out, choice, _place(fr, 0.0, 0.0, size), i, &"cover")
			return
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
	# v0.8.0 MI: a biome with long cover but no wreck of its own tiles its deep footprints instead.
	var no_wreck := pools.has(&"cover_long") and not pools.has(&"cover_deep")
	if depth >= 1.2 and length >= 2.6 and length <= 5.0 and not no_wreck and rng.randf() < 0.5:
		var wreck := pick_piece(f, &"cover_deep", depth, rng)
		_fill(out, i, fr, wreck, _jitter(rng, float(_spec_of(wreck)["height"])), &"cover", rng)
		return
	var a := -length * 0.5
	var b := length * 0.5
	while b - a > 0.05:
		var rest := b - a
		var seg := rng.randf_range(1.0, 1.6) if rest > 2.2 else rest
		var piece: StringName
		var h: float
		if pools.has(&"cover_long"):  # v0.8.0 MI: the biome's own long cover, segment by segment
			piece = pick_piece(f, &"cover_long", depth, rng)
			h = _jitter(rng, maxf(float(_spec_of(piece)["height"]), 0.6))
		else:
			piece = &"slab_wide" if seg >= 1.3 else &"slab_concrete"
			h = _jitter(rng, SLAB_HEIGHT)
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


## v0.8.0 MI: the piece a footprint named `name` (a role or a kit name) is drawn with in this biome: its role's
## pool when the biome has one; else (no pool: the look before MI) the old swap and the kit name itself.
static func _resolve(
	name: StringName, fr: Dictionary, f: Dictionary, rng: RandomNumberGenerator
) -> StringName:
	var role := role_of(name, fr)
	var pools: Dictionary = f.get("pools", {})
	var depth: float = float(fr.get("depth", 0.0))
	if role != &"" and pools.has(role):
		return pick_piece(f, role, depth, rng)
	if role == &"landmark" and pools.has(&"cover_block"):
		return pick_piece(f, &"cover_block", depth, rng)
	var kit_name: StringName = name if not name in BiomeLook.ROLES else LEGACY_PIECE.get(name, name)
	return _layout_swap(kit_name, f.get("biome", &""), f.get("square_cover", {}), rng)


static func _spec_of(piece: StringName) -> Dictionary:
	if KitModels.SPECS.has(piece):
		return KitModels.SPECS[piece]
	var cp: Dictionary = CodeProps.SPECS.get(piece, {})
	return {"height": float(cp.get("height", 1.2)), "role": &"cover"}


## v0.8.0 MI: a piece's own footprint (m, long side first): its spec's "foot", or the kit's measured proportions.
static func _foot_of(piece: StringName) -> Vector2:
	var spec: Dictionary = KitModels.SPECS.get(piece, {})
	if spec.has("foot"):
		var ft: Vector2 = spec["foot"]
		return Vector2(maxf(ft.x, ft.y), minf(ft.x, ft.y))
	var cp: Dictionary = CodeProps.SPECS.get(piece, {})
	if cp.has("foot"):
		var cf: Vector2 = cp["foot"]
		return Vector2(maxf(cf.x, cf.y), minf(cf.x, cf.y))
	return Vector2.ZERO  # the kit's pieces fill any footprint (the old rule)


## v0.8.0 MI: `piece` filling the frame's footprint at height h: one copy, or (a footprint more than TILE_ASPECT times
## longer than the piece's own proportions) that many copies along it, each its share of the length.
static func _fill(
	out: Array,
	i: int,
	fr: Dictionary,
	piece: StringName,
	h: float,
	kind: StringName,
	rng: RandomNumberGenerator
) -> void:
	var length: float = fr["length"]
	var depth: float = fr["depth"]
	var ft := _foot_of(piece)
	var n := 1
	if ft.y > 0.0:
		var own := ft.x / ft.y
		var want := length / maxf(depth, 0.01)
		if want > own * TILE_ASPECT:
			n = clampi(int(round(want / own)), 2, TILE_MAX)
	if n == 1:
		_add(out, piece, _place(fr, 0.0, 0.0, Vector3(length, h, depth)), i, kind)
		return
	var seg := length / n
	for k in n:
		var hk := h if k == 0 else _jitter(rng, h)
		_add(
			out,
			piece,
			_place(fr, -length * 0.5 + seg * (k + 0.5), 0.0, Vector3(seg, hk, depth)),
			i,
			kind
		)


## v0.8.0 RT: a designed room's blocker, its piece swapped for the biome, filling its footprint at the layout's height
## (or the kit's own, jittered); a light piece carries its light. v0.8.0 MI: the layout names a role (_resolve); a
## biome piece keeps its own height (the layout's heights were set for the Ruins kit), tiled along a long footprint.
static func _layout_named(
	out: Array, i: int, w: Array, f: Dictionary, rng: RandomNumberGenerator
) -> void:
	var fr := _frame(w)
	var piece := _resolve(StringName(w[4]), fr, f, rng)
	var spec := _spec_of(piece)
	var kind: StringName = &"light" if spec["role"] == &"light" else &"cover"
	var own: bool = spec.get("role", &"") == &"biome"
	var h := float(w[5]) if float(w[5]) > 0.0 and not own else _jitter(rng, float(spec["height"]))
	_fill(out, i, fr, piece, h, kind, rng)


## v0.8.0 RT: a designed room's drawn-only pieces: decoration (the biome's decor_swap; never past DECOR_MAX_HEIGHT,
## kept KEEP_CLEAR from doorways, rewards and the portal) and the pieces standing on its blockers (fading with them).
## v0.8.0 MI: a decoration role draws from the biome's decoration pool.
static func _layout_props(out: Array, f: Dictionary, rng: RandomNumberGenerator) -> void:
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
		var role := role_of(piece)
		if piece in LAYOUT_DECOR or role in [&"decor_grass", &"decor_rubble", &"decor_debris"]:
			if _near_any_point(at, keep, KEEP_CLEAR) or _near_any_rect(at, doors, KEEP_CLEAR):
				continue
			piece = _decor_piece(f, piece, rng)
			if h <= 0.0:
				h = float(_spec_of(piece)["height"])
			h = minf(h, DECOR_MAX_HEIGHT)
			kind = &"decor"
		else:
			piece = _resolve(piece, {"depth": minf(size.x, size.y)}, f, rng)
			var spec := _spec_of(piece)
			if h <= 0.0 or spec.get("role", &"") == &"biome":
				h = _jitter(rng, float(spec["height"]))
			kind = &"light" if spec["role"] == &"light" else &"cover"
		var basis := (
			Basis(Vector3.UP, SimPlane.yaw_of(int(p["angle"])))
			* Basis.from_scale(Vector3(size.x, h, size.y))
		)
		_add(out, piece, Transform3D(basis, SimPlane.to_3d(at)), wall, kind)


## A box that names its piece (a vignette's, PLAN L8): that piece fills the footprint at its natural height; a
## light piece (a burn barrel) also carries its light. v0.8.0 MI: a cover name is a role, drawn from the biome's pool.
static func _named(
	out: Array,
	i: int,
	fr: Dictionary,
	piece: StringName,
	rng: RandomNumberGenerator,
	f: Dictionary = {}
) -> void:
	var drawn := piece
	if role_of(piece, fr) != &"" and (f.get("pools", {}) as Dictionary).has(role_of(piece, fr)):
		drawn = pick_piece(f, role_of(piece, fr), float(fr["depth"]), rng)
	var spec: Dictionary = KitModels.SPECS.get(drawn, {"height": SLAB_HEIGHT, "role": &"cover"})
	var kind: StringName = &"light" if spec["role"] == &"light" else &"cover"
	var h := _jitter(rng, float(spec["height"]))
	_fill(out, i, fr, drawn, h, kind, rng)


## v0.8.0 MI: per structural wall, the wall props its rooms set into it: [[along, side, piece]] (BiomeLook
## wall_props_per_room, wall_prop_chance, pool wall_prop). Each keeps WALL_PROP_DOOR from a doorway and
## WALL_PROP_SPACING from a light prop's slot and another prop, on a wall deep enough to hold it (rule 1).
static func _wall_prop_slots(
	f: Dictionary, lights: Dictionary, rng: RandomNumberGenerator
) -> Dictionary:
	var per_room := int(f.get("wall_props_per_room", 0))
	var pool: Dictionary = (f.get("pools", {}) as Dictionary).get(&"wall_prop", {})
	if per_room <= 0 or pool.is_empty():
		return {}
	var slots := {}
	var walls: Array = f.get("walls", [])
	var doors: Array = f.get("doors", [])
	var taken: Array[Vector2] = []
	for i: int in lights:
		var fr := _frame(walls[i])
		for s: Array in lights[i]:
			taken.append(SimPlane.to_sim(fr["center"] + fr["axis"] * float(s[0])))
	var chance := float(f.get("wall_prop_chance", 0.5))
	for room: Rect2 in f.get("rooms", []):
		var candidates: Array = []
		for i in walls.size():
			var w: Array = walls[i]
			if w[3] != 0 or not ProceduralWall.handles(w):
				continue
			var fr := _frame(w)
			if fr["length"] < 2.4 or not _wall_rect(w).intersects(room.grow(0.05)):
				continue
			candidates.append(i)
		for k in per_room:
			if candidates.is_empty() or rng.randf() >= chance:
				continue
			var piece := pick_piece(f, &"wall_prop", 0.0, rng)
			var ft := _foot_of(piece)
			for attempt in 6:
				var i: int = candidates[rng.randi() % candidates.size()]
				var fr := _frame(walls[i])
				if float(fr["depth"]) < ft.y + WALL_PROP_BACK:
					continue
				var axis2 := Vector2(fr["axis"].x, -fr["axis"].z)
				var depth2 := Vector2(fr["depth_axis"].x, -fr["depth_axis"].z)
				var c := SimPlane.to_sim(fr["center"])
				var half := float(fr["length"]) * 0.5 - ft.x * 0.5 - 0.6
				if half <= 0.0:
					continue
				var along := rng.randf_range(-half, half)
				var side := signf((room.get_center() - c).dot(depth2))
				side = side if side != 0.0 else 1.0
				var p := c + axis2 * along + depth2 * side * float(fr["depth"]) * 0.5
				if not room.grow(0.2).has_point(p):
					continue
				if _near_any_rect(p, doors, WALL_PROP_DOOR + ft.x * 0.5):
					continue
				if _near_any_point(p, taken, WALL_PROP_SPACING):
					continue
				if not slots.has(i):
					slots[i] = []
				slots[i].append([along, side, piece])
				taken.append(p)
				break
	return slots


## v0.8.0 MI: a structural wall's props, each standing in a niche the procedural wall leaves (inside the wall's
## footprint, its back WALL_PROP_BACK from the far face), its front (+Z) toward the room.
static func _dress_wall_props(out: Array, i: int, w: Array, slots: Array) -> void:
	if slots.is_empty():
		return
	var fr := _frame(w)
	var depth: float = fr["depth"]
	for s: Array in slots:
		var along: float = s[0]
		var side: float = s[1]
		var piece: StringName = s[2]
		var ft := _foot_of(piece)
		var across := side * (depth - ft.y) * 0.5
		var spec := _spec_of(piece)
		var basis := (
			Basis(Vector3.UP, float(fr["yaw"]) + (0.0 if side > 0.0 else PI))
			* Basis.from_scale(Vector3(ft.x, float(spec["height"]), ft.y))
		)
		var origin: Vector3 = fr["center"] + fr["axis"] * along + fr["depth_axis"] * across
		_add(out, piece, Transform3D(basis, origin), i, &"cover")
		var axis2 := Vector2(fr["axis"].x, -fr["axis"].z)
		var depth2 := Vector2(fr["depth_axis"].x, -fr["depth_axis"].z)
		var cut := ft.y + 0.06
		var c := (
			SimPlane.to_sim(fr["center"])
			+ axis2 * along
			+ depth2 * side * (depth * 0.5 - cut * 0.5 + 0.03)
		)
		var size := (
			Vector2(ft.x + 0.1, cut + 0.06)
			if absf(axis2.x) > 0.5
			else Vector2(cut + 0.06, ft.x + 0.1)
		)
		out[out.size() - 1]["niche"] = Rect2(c - size * 0.5, size)


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
				_decor(out, &"grass_tuft", p, rng.randf_range(0.6, 1.0), rng, f)
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
				_decor(out, &"grass_tuft", p, rng.randf_range(0.6, 1.0), rng, f)
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
			_decor(out, piece, p, rng.randf_range(0.7, 1.2), rng, f)


## v0.8.0 MI: the piece a decoration name (a kit decor name or a decor role) draws in this biome: its role's pool,
## else the biome's decor_swap (v0.7.5 NB1), else the kit's own.
static func _decor_piece(
	f: Dictionary, piece: StringName, rng: RandomNumberGenerator
) -> StringName:
	var role := role_of(piece)
	var kit_name: StringName = LEGACY_PIECE.get(role, piece) if piece in BiomeLook.ROLES else piece
	if role != &"" and (f.get("pools", {}) as Dictionary).has(role):
		return pick_piece(f, role, 0.0, rng)
	return StringName((f.get("decor_swap", {}) as Dictionary).get(kit_name, kit_name))


## A low decoration piece at its natural size × s, turned at random; its height never passes DECOR_MAX_HEIGHT.
static func _decor(
	out: Array,
	piece: StringName,
	p: Vector2,
	s: float,
	rng: RandomNumberGenerator,
	f: Dictionary = {}
) -> void:
	piece = _decor_piece(f, piece, rng)  # v0.7.5 NB1, v0.8.0 MI: the biome's own decoration
	if KitModels.SPECS.has(piece) and (KitModels.SPECS[piece] as Dictionary).has("foot"):
		var ft: Vector2 = KitModels.SPECS[piece]["foot"]
		var kh := minf(float(KitModels.SPECS[piece]["height"]) * s, DECOR_MAX_HEIGHT)
		var kb := (
			Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(ft.x * s, kh, ft.y * s))
		)
		_add(out, piece, Transform3D(kb, SimPlane.to_3d(p)), -1, &"decor")
		return
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
