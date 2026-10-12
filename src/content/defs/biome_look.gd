class_name BiomeLook
extends Resource
## A biome's own look beyond its palette and mood (v0.7.5 NB1), so a new biome is data plus, at most, one new edge
## builder: what stands in for the kit's square cover, which code-made pieces replace the kit's floor decoration,
## what lies beyond the floor's edge, and the cold (or other) cast its enemies' grey parts take. Presentation only:
## StageView, StageDresser and ActorViews read it, the sim never does. A biome without one (Ruins, Night Rocks,
## Red Canyon) keeps its hand-written look unchanged.

const EDGES: Array[StringName] = [&"", &"water"]

## What a square cover footprint is drawn with: kit piece id -> weight (empty: the dresser's own rule).
@export var square_cover: Dictionary = {}
## Floor decoration swaps: kit decor piece id -> the piece drawn instead (a kit or a code-made piece, CodeProps).
@export var decor_swap: Dictionary = {}
## What lies beyond the floor's edge: &"" the void (the mood's void colour), &"water" a frozen sea with ice floes
## and a snow bank under the floor (BiomeEdge).
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
	if enemy_tint.a < 0.0 or enemy_tint.a > 0.8:
		out.append("enemy_tint: alpha %s is outside 0..0.8" % enemy_tint.a)
	return out
