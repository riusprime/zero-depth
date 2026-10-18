class_name BiomeLook
extends Resource
## A biome's own look beyond its palette and mood (v0.7.5 NB1), so a new biome is data plus, at most, one new edge
## builder: what stands in for the kit's square cover, which code-made pieces replace the kit's floor decoration,
## what lies beyond the floor's edge, and the cold (or other) cast its enemies' grey parts take. Presentation only:
## StageView, StageDresser and ActorViews read it, the sim never does. A biome without one (Ruins, Night Rocks,
## Red Canyon) keeps its hand-written look unchanged.

const EDGES: Array[StringName] = [&"", &"water", &"stars", &"islands"]
## v0.8.0 MI (owner O78/O79: "the ones that not fit by context like the car should not go in every biome"; "every
## biome get's their new assets generated in the way we meant to do it"): the piece roles a floor is dressed with.
## Designed rooms name these roles (data/room_layouts) and the dresser maps the kit names the generator's vignettes
## still carry onto them (StageDresser.ROLE_OF); each biome draws each role from its own pool below.
## - cover_square: a near-square cover block about 1-2 m (was a crate stack, a large rock or a dead tree);
## - cover_block: a big block, both sides 1.4 m or more (was a concrete slab);
## - cover_long: a long cover slab, 2.4-3.4 x 1.2-1.4 m, and the segments a generated long slab is tiled with;
## - cover_wall: a thin wall 0.6 m deep and 2-5 m long (was a broken wall), tiled with pieces of its own proportions;
## - cover_post: a small post 0.6-1 m square (was a wall pillar);
## - cover_deep: a deep wreck-sized footprint 1.2 m+ deep, 2.6-5 m long (was a car wreck);
## - landmark: a designed room's one set piece (its biggest block);
## - wall_prop: a tall prop set into a structural wall's niche (rule 1: inside the wall's footprint);
## - decor_grass, decor_rubble, decor_debris: the three kinds of low floor decoration;
## - void_island, void_spike: what floats in the void past the floor's edge (edge &"stars" / &"islands").
const ROLES: Array[StringName] = [
	&"cover_square",
	&"cover_block",
	&"cover_long",
	&"cover_wall",
	&"cover_post",
	&"cover_deep",
	&"landmark",
	&"wall_prop",
	&"decor_grass",
	&"decor_rubble",
	&"decor_debris",
	&"void_island",
	&"void_spike",
]

## What a square cover footprint is drawn with: kit piece id -> weight (empty: the dresser's own rule).
## v0.8.0 MI: the cover_square pool when `pools` has none.
@export var square_cover: Dictionary = {}
## Floor decoration swaps: kit decor piece id -> the piece drawn instead (a kit or a code-made piece, CodeProps).
## v0.8.0 MI: used for a decoration role `pools` has no pool for.
@export var decor_swap: Dictionary = {}
## v0.8.0 MI: role (ROLES) -> {piece id: int weight}. A role without a pool keeps the Ruins kit's piece (the old rule).
## A piece whose model is missing drops out (L15); an empty pool falls back the same way.
@export var pools: Dictionary = {}
## v0.8.0 MI (owner O79: "cap the observatory max to 1 per floor"): piece id -> the most of it one floor draws (a
## unique landmark never repeats); once reached the pool's other pieces draw. Unlisted: no cap.
@export var max_per_floor: Dictionary = {}
## v0.8.0 MI: how many wall props (pool wall_prop) a room sets into its walls at most, and the chance of each.
@export var wall_props_per_room := 0
@export var wall_prop_chance := 0.5
## What lies beyond the floor's edge: &"" the void (the mood's void colour), &"water" a frozen sea with ice floes
## and a snow bank under the floor (BiomeEdge); v0.7.5 NB2 &"stars" a starry void (Starfall: the floor a floating
## island over twinkling stars, nebula light, and drifting rock and crystal islands). v0.8.0 MI &"islands": the
## mood's void with the biome's own islands (pool void_island) drifting below the floor (Night Rocks' moss islands).
@export var edge := &""
## Enemies' grey and bone parts pulled toward this colour by its alpha (0: none). Their red, rings and bars never
## change (PRESENTATION_CONTRACTS §3).
@export var enemy_tint := Color(0, 0, 0, 0)


func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not edge in EDGES:
		out.append("edge: unknown edge '%s'" % edge)
	for k: Variant in square_cover:
		if typeof(square_cover[k]) != TYPE_INT or int(square_cover[k]) <= 0:
			out.append("square_cover: '%s' needs a positive int weight" % k)
	for k: Variant in decor_swap:
		if String(decor_swap[k]).is_empty():
			out.append("decor_swap: '%s' swaps to nothing" % k)
	for role: Variant in pools:
		if not StringName(role) in ROLES:
			out.append("pools: unknown role '%s'" % role)
			continue
		var pool: Variant = pools[role]
		if typeof(pool) != TYPE_DICTIONARY or (pool as Dictionary).is_empty():
			out.append("pools: '%s' needs {piece: weight}" % role)
			continue
		var uncapped := false
		for k: Variant in pool:
			if typeof(pool[k]) != TYPE_INT or int(pool[k]) <= 0:
				out.append("pools: '%s' piece '%s' needs a positive int weight" % [role, k])
			uncapped = uncapped or not max_per_floor.has(k)
		if not uncapped:
			out.append("pools: '%s' needs a piece without a max_per_floor cap" % role)
	for k: Variant in max_per_floor:
		if typeof(max_per_floor[k]) != TYPE_INT or int(max_per_floor[k]) < 1:
			out.append("max_per_floor: '%s' needs an int of 1 or more" % k)
	if wall_props_per_room < 0 or wall_props_per_room > 4:
		out.append("wall_props_per_room: %d is outside 0..4" % wall_props_per_room)
	if wall_prop_chance < 0.0 or wall_prop_chance > 1.0:
		out.append("wall_prop_chance: %s is outside 0..1" % wall_prop_chance)
	if enemy_tint.a < 0.0 or enemy_tint.a > 0.8:
		out.append("enemy_tint: alpha %s is outside 0..0.8" % enemy_tint.a)
	return out
