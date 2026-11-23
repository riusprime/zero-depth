class_name ForgeCues
extends RefCounted
## The sounds of the Foundry's forge, from their STATUS_APPLY events (AudioEvents asks; EI-07). No sound was recorded
## for them, so each borrows a cue that exists, pitched apart from its first use; none borrows the Overclock heat's
## cues (heat_*), so the hero's weapon heat never sounds like the scald:
## - the forging cast: the shield bash's clang, lower; the plate on: the guard's block, lower; blown off: the wall
##   break, higher;
## - a pool cooled into a slab: the vent's cold hiss; a slab crumbling: the container break, lower; shattered by the
##   vent blast: the wall break; a slag drop coming: the mortar, higher;
## - the Overpressure's cast: the Foundry's own telegraph roar, lower; the floor catching: the boss's floor burst,
##   lower; its end: the cold hiss, lower;
## - the hero's scald burning: the flame trail; its end: the cold hiss, higher.
## The drone the plate calls has none of its own (its launch and its bomb keep theirs).

## effect id -> [cue, pitch, whether it sounds at the event's place].
const CUES := {
	&"forge_cast": [&"shield_bash", 0.7, true],
	&"plate_forged": [&"guard_block", 0.75, true],
	&"plate_blown": [&"wall_break", 1.25, true],
	&"slab_cooled": [&"vent_cold", 0.9, true],
	&"slab_crumbled": [&"container_break", 0.8, true],
	&"slab_shattered": [&"wall_break", 1.0, true],
	&"slag_drop": [&"boss_mortar", 1.15, true],
	&"overpressure_cast": [&"boss_telegraph_foundry", 0.85, false],
	&"overpressure": [&"boss_floor_burst", 0.7, false],
	&"overpressure_end": [&"vent_cold", 0.8, false],
	&"scald_burn": [&"flame_trail", 1.0, false],
	&"scald_burn_end": [&"vent_cold", 1.15, false],
}


## Appends the cue of event `e` to `out` ([cue, place or null, pitch]); false when the event is not one of these.
static func add(e: SimEvent, out: Array) -> bool:
	if not CUES.has(e.effect_id):
		return false
	var cue: Array = CUES[e.effect_id]
	out.append([cue[0], e.pos if cue[2] else null, cue[1]])
	return true
