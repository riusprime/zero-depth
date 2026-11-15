class_name BossForgeTable
extends RefCounted
## The Foundry's forge in sim units (ticks, m, per mille), compiled from BossDefinition.forge (ForgeRules.SPEC).
## Phases are indices (0 = the first); a phase past the boss's last means never. BossForge (the plate, the scald
## gauge) and BossSlag (the slabs, Overpressure) read it.

## The Forged Plate, from plate_phase: the first cast plate_first_ticks into that phase; plate_cast_ticks later the
## boss wears it and takes plate_taken per mille of every hit and tick from the hero. A drone's bomb landing within
## drone_blast_m of its edge blows it off: exposed_ticks at exposed_taken per mille, and the next cast is due
## plate_every_ticks after the blow. While plated and no drone of drone_kind is alive or arriving, one is launched
## drone_distance_m past its edge, no sooner than drone_gap_ticks after the last one it launched.
var plate_phase := 1
var plate_first_ticks := 480
var plate_every_ticks := 1200
var plate_cast_ticks := 90
var plate_taken := 400
var exposed_ticks := 300
var exposed_taken := 1250
var drone_blast_m := 1.5
var drone_distance_m := 3.0
var drone_gap_ticks := 120
var drone_kind := -1
## Cooling slag, from slab_phase: a pool of the boss's hazards slab_cool_ticks old becomes a slab (no damage) for
## slab_ticks, then crumbles. With no pool or slab that would serve an Overpressure on the floor the meltdown
## leaves, a pool drops where the hero stands, no sooner than drop_ticks after the last (0 = never).
var slab_phase := 2
var slab_cool_ticks := 720
var slab_ticks := 480
var drop_ticks := 360
## Overpressure, from over_phase: the first over_first_ticks into that phase, then every over_every_ticks (start to
## start). The cast (over_cast_ticks), then for over_ticks a hero off every slab loses over_hit per mille of max HP
## every over_step_ticks. over_cause: the attack the death recap names (an index into the table's attacks).
var over_phase := 2
var over_first_ticks := 600
var over_every_ticks := 1320
var over_cast_ticks := 180
var over_ticks := 240
var over_step_ticks := 30
var over_hit := 30
var over_cause := -1
## The scald gauge, from scald_phase, 0..scald_max: + scald_hit for each of the boss's shots that hurts the hero,
## + scald_lava each scald_step_ticks in lava, a pool or the melt, + scald_open each Overpressure step off a slab,
## - scald_drain each scald_step_ticks on a slab. At scald_max the hero loses scald_burn per mille of max HP each
## scald_step_ticks. scald_cause: the recap's attack.
var scald_phase := 2
var scald_max := 1000
var scald_hit := 200
var scald_lava := 60
var scald_open := 40
var scald_drain := 125
var scald_step_ticks := 30
var scald_burn := 25
var scald_cause := -1


## The first phase any part of the forge runs in.
func first_phase() -> int:
	return mini(mini(plate_phase, slab_phase), mini(over_phase, scald_phase))
