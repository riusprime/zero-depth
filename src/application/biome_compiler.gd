class_name BiomeCompiler
extends RefCounted
## v0.7.5 NB1: a biome's gameplay data in sim units. Today only its surface (BiomeSurface -> IceField); the look and
## mood stay in presentation. v0.7.5 NB2: any surface kind (Frozen Shore's ice, Starfall's starglow) via
## compile_surface; compile_ice stays the ice-only question.


## The biome's ice, ready for IcePatches.place; null when the biome has no surface.
static func compile_ice(def: BiomeDefinition) -> IceField:
	if def == null or def.surface == null or def.surface.kind != &"ice":
		return null
	return compile_surface(def)


## v0.7.5 NB2: the biome's surface of any kind (ice or starglow), ready for IcePatches.place; null when it has none.
static func compile_surface(def: BiomeDefinition) -> IceField:
	if def == null or def.surface == null:
		return null
	var s := def.surface
	var f := IceField.new()
	f.kind = s.kind
	f.speed_permille = int(round(s.speed_scale * 1000.0))
	f.room_share_permille = s.room_share_permille
	f.patches_min = s.patches_min
	f.patches_max = s.patches_max
	f.size_min_dm = int(round(s.size_min_m * 10.0))
	f.size_max_dm = int(round(s.size_max_m * 10.0))
	f.clearance_m = s.clearance_m
	f.accel_permille = ContentCompiler.ease_permille(s.accel_seconds)
	f.decel_permille = ContentCompiler.ease_permille(s.stop_seconds)
	return f
