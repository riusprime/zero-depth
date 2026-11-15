class_name WarlordCues
extends RefCounted
## The sounds of the Warlord's War Banner and Duel, from their STATUS_APPLY events (AudioEvents asks; EI-07). No sound
## was recorded for them, so each borrows a cue that exists, pitched apart from its first use:
## - the banner's cast: the Warlord's own telegraph clank, lower; planted: the boss's slam, higher; snapped by its
##   charge: the wall break; burnt down by its time: the vent's cold hiss, low (a fall at the fight's end has none);
## - the duel's cast: the glaive's throw, lower (the javelins in the air); the cage closing: the boss's floor burst;
##   the fence's touch: the guard's block, higher; the recall's warning: the pylon's lock, lower; the recall: the
##   Lance's release, lower.
## The cage's end has none of its own (the recall is it).

## effect id -> [cue, pitch, whether it sounds at the event's place].
const CUES := {
	&"warlord_banner_cast": [&"boss_telegraph_warlord", 0.85, false],
	&"warlord_banner_planted": [&"boss_slam", 1.2, true],
	&"warlord_duel_cast": [&"glaive_throw", 0.7, false],
	&"warlord_duel_start": [&"boss_floor_burst", 0.9, true],
	&"warlord_fence_touch": [&"guard_block", 1.3, true],
	&"warlord_recall_warn": [&"pylon_lock", 0.75, true],
	&"warlord_recall": [&"lance_release", 0.8, true],
}
const FALLEN := &"warlord_banner_fallen"
## The banner's fall by its reason (BossWarlord.FELL_TIME 0, FELL_CHARGE 1): [cue, pitch].
const FALLS := {0: [&"vent_cold", 0.7], 1: [&"wall_break", 1.0]}


## Appends the cue of event `e` to `out` ([cue, place or null, pitch]); false when the event is not one of these.
static func add(e: SimEvent, out: Array) -> bool:
	if e.effect_id == FALLEN:
		if FALLS.has(e.amount):
			var fall: Array = FALLS[e.amount]
			out.append([fall[0], e.pos, fall[1]])
		return true
	if not CUES.has(e.effect_id):
		return false
	var cue: Array = CUES[e.effect_id]
	out.append([cue[0], e.pos if cue[2] else null, cue[1]])
	return true
