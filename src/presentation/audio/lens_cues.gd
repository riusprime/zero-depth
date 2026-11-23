class_name LensCues
extends RefCounted
## The sounds of the Hive Lens's drones, Lattice and burnt glass, from their STATUS_APPLY events (AudioEvents asks;
## EI-07). No sound was recorded for them, so each borrows a cue that exists, pitched apart from its first use:
## - a drone cut down by the Lens's own beam: the stress break's crack, higher;
## - the Lattice's cast: the Lance's charge, lower; the web rising: the boss laser, lower; the web gone: the arc
##   field's crackle, lower; a strand touching the hero: the arc bolt, higher (the hero's own hurt cue plays too);
## - burnt glass laid: the flame trail's hiss, higher; gone: the vent's cold hiss, higher.
## The feeding itself has none (a sound that never stops would bury the fight).

## effect id -> [cue, pitch, whether it sounds at the event's place].
const CUES := {
	&"lens_drone_cut": [&"stress_break", 1.2, true],
	&"lattice_cast": [&"lance_charge", 0.8, false],
	&"lattice_start": [&"boss_laser", 0.85, false],
	&"lattice_end": [&"arc_field", 0.75, false],
	&"lattice_strand_hit": [&"arc_bolt", 1.2, true],
	&"lens_glass_laid": [&"flame_trail", 1.35, true],
	&"lens_glass_gone": [&"vent_cold", 1.25, true],
}


## Appends the cue of event `e` to `out` ([cue, place or null, pitch]); false when the event is not one of these.
static func add(e: SimEvent, out: Array) -> bool:
	if not CUES.has(e.effect_id):
		return false
	var cue: Array = CUES[e.effect_id]
	out.append([cue[0], e.pos if cue[2] else null, cue[1]])
	return true
