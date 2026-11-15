class_name SiegeCues
extends RefCounted
## The sounds of the Siege Engine's own mechanics, from their STATUS_APPLY events (AudioEvents asks; EI-07). No sound
## was recorded for them, so each borrows a cue that exists, pitched apart from its first use:
## - the Target Lock taking the hero: the pylon's lock, lower; the shell landing: the bomb's blast, lower;
## - a boulder rising out of the floor: the boss's floor burst, lower; one shattered or crumbled: the wall break;
## - a turret the shell destroys: the barrel's blast, higher;
## - the ammo cart setting off: the barrel's fuse, lower; arriving (the Doom Shell winds up): the elite's charge,
##   lower; the Doom Shell firing: the mine's blast, low; the cart blown up: the barrel's blast, lower; the armour
##   stripped: the boss's stagger, higher.
## The Shockwave keeps its attack's own sound (none here); the cart's body arriving has none.

## effect id -> [cue, pitch, whether it sounds at the event's place].
const CUES := {
	&"siege_lock": [&"pylon_lock", 0.8, false],
	&"siege_shell": [&"bomb_blast", 0.7, true],
	&"siege_boulder": [&"boss_floor_burst", 0.85, true],
	&"siege_boulder_down": [&"wall_break", 1.0, true],
	&"siege_turret_destroyed": [&"barrel_blast", 1.15, true],
	&"siege_cart": [&"barrel_fuse", 0.8, true],
	&"siege_cart_arrived": [&"elite_charge", 0.7, false],
	&"siege_doom_shell": [&"mine_blast", 0.6, false],
	&"siege_cart_destroyed": [&"barrel_blast", 0.8, true],
	&"siege_armour_stripped": [&"boss_stagger", 1.2, false],
}


## Appends the cue of event `e` to `out` ([cue, place or null, pitch]); false when the event is not one of these.
static func add(e: SimEvent, out: Array) -> bool:
	if not CUES.has(e.effect_id):
		return false
	var cue: Array = CUES[e.effect_id]
	out.append([cue[0], e.pos if cue[2] else null, cue[1]])
	return true
