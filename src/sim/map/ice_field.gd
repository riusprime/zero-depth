class_name IceField
extends RefCounted
## v0.7.5 NB1: a floor's ice (Frozen Shore): the compiled numbers (BiomeCompiler, from BiomeSurface) and the patches
## IcePatches laid from the floor seed. Set up with the floor and never written in play, so a save keeps it as
## loadout (WorldSnapshot.LOADOUT_CLASSES) and a resumed floor lays the same patches again. Like the floor layout it
## comes from, it is not hashed: it is a pure function of the floor seed and the biome, and what it does (the hero's
## slide) shows in the hashed position and velocity. World.ice is null on every other biome: nothing is placed or
## drawn there.

## Placement (per mille, counts, decimetres).
var room_share_permille := 0
var patches_min := 0
var patches_max := 0
var size_min_dm := 25
var size_max_dm := 50
var clearance_m := 1.2
## The hero's easing on ice (PlayerTable.accel_permille / decel_permille's meaning).
var accel_permille := 1000
var decel_permille := 1000
## The patches, axis-aligned on the sim plane.
var rects: Array[Rect2] = []


## True when p stands on a patch.
func covers(p: Vector2) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	return false
