class_name SimTick
extends RefCounted
## Kernel constants (docs/architecture/SIM_CONTRACTS.md §1–§3). World.tick is the only gameplay clock.

const TICKS_PER_SECOND := 60
const INPUT_BUFFER_TICKS := 6
## Hit-stop cap in ticks (starting value).
const FREEZE_CAP_TICKS := 8
## Heavy AI passes run when (tick + id) % AI_HEAVY_PERIOD == 0 (starting value).
const AI_HEAVY_PERIOD := 6
## Aim distance clamp in centimetres (starting value).
const AIM_DIST_MAX_CM := 3000
## One turn in angle units.
const ANGLE_UNITS := 4096
const MOVE_MAX := 127
## Collision resolution passes per tick (starting value).
const COLLIDE_ITERS := 2
## Every enemy attack's windup is at least this long (0.4 s; owner, 2026-10-06).
const MIN_TELEGRAPH_TICKS := BehaviourSchemas.MIN_TELEGRAPH_TICKS
## Enemies appear with a marker and can't act or be hurt for this long (starting value, 0.6 s).
const SPAWN_IN_TICKS := 36


## Converts authored seconds to whole ticks once, at content compile time (round half away from zero).
static func seconds_to_ticks(seconds: float) -> int:
	return int(round(seconds * TICKS_PER_SECOND))
