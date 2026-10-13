class_name BiomeSurface
extends Resource
## A biome's ground that plays differently (v0.7.5 NB1): patches of a surface laid on some rooms' open floor, and
## how the hero moves on them. Today one kind, ice: the hero takes longer to speed up and to stop, so they slide.
## Compiled into the sim's IceField (BiomeCompiler) and placed per floor from the `map:ice` sub-stream (IcePatches).
## Mild flavour, never a difficulty step (PD-04): it never hurts, the dash is unchanged, and the start hall, the
## boss room and the portal's room never get any. Starting values, tuned at the owner's playtest.
## v0.7.5 NB2: a second kind, starglow (Starfall): pools of star light where the hero runs faster (speed_scale) and
## drifts a little when stopping; the same placement rules, drawn from its own `map:starglow` sub-stream. It only
## helps (never hurts), and the dash is unchanged.

const KINDS: Array[StringName] = [&"ice", &"starglow"]

@export var kind := &"ice"
## The share of eligible rooms (not the start hall, the boss room, the portal's room or the shop's) that get
## patches, in per mille.
@export var room_share_permille := 450
## Patches per chosen room.
@export var patches_min := 1
@export var patches_max := 2
## A patch's sides, in metres (drawn in 0.5 m steps).
@export var size_min_m := 2.5
@export var size_max_m := 5.0
## How far a patch keeps from a doorway, the room's walls and the floor's spots (m).
@export var clearance_m := 1.2
## On the surface: seconds to reach 90 % of the target speed, and to lose 90 % of it (the hero's own are 0.1 and
## 0.083 s, PlayerDefinition).
@export var accel_seconds := 0.35
@export var stop_seconds := 0.6
## v0.7.5 NB2: the hero's top walking speed on the surface, times their own (1.0: unchanged, as on ice).
@export var speed_scale := 1.0


## Problems as "field: why" strings (BiomeDefinition turns them into ValidationIssues).
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not kind in KINDS:
		out.append("kind: unknown surface '%s'" % kind)
	if room_share_permille < 0 or room_share_permille > 1000:
		out.append("room_share_permille: %d is outside 0..1000" % room_share_permille)
	if patches_min < 0 or patches_max < patches_min or patches_max > 6:
		out.append("patches: %d..%d must be 0 <= min <= max <= 6" % [patches_min, patches_max])
	if size_min_m < 1.0 or size_max_m < size_min_m or size_max_m > 12.0:
		out.append("size: %s..%s must be 1 <= min <= max <= 12 m" % [size_min_m, size_max_m])
	if clearance_m < 0.0 or clearance_m > 4.0:
		out.append("clearance_m: %s is outside 0..4" % clearance_m)
	for f: Array in [["accel_seconds", accel_seconds], ["stop_seconds", stop_seconds]]:
		if f[1] < 1.0 / 60.0 or f[1] > 3.0:
			out.append("%s: %s is outside one tick..3 s" % f)
	if speed_scale < 0.5 or speed_scale > 1.5:
		out.append("speed_scale: %s is outside 0.5..1.5" % speed_scale)
	return out
