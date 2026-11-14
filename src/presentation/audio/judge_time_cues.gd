class_name JudgeTimeCues
extends RefCounted
## The sounds of the Clockwork Judge's time mechanics, from its STATUS_APPLY events (AudioEvents asks; EI-07). No
## sound was recorded for them, so each borrows a cue that exists, pitched apart from its first use:
## - the Time Wave landing: the echo's chime, low;
## - the Bell (a cast or a later toll's wait beginning): the Tidecaller's bell, higher;
## - the hero thrown back to the copy: the blink's arrival, lower;
## - the Judge's own return: the blink's departure, lower;
## - an hour orb taken (its own event kind): the item pickup, higher.
## The cast is the Judge's telegraph cue already (its windup); a slow field and a gear have no sound.

const ORB_TAKEN := &"item_pickup"
const ORB_PITCH := 1.3
## effect id -> [cue, pitch, whether it sounds at the event's place].
const CUES := {
	&"time_wave": [&"boss_judge_echo", 0.6, false],
	&"judge_bell": [&"boss_telegraph_tidecaller", 1.25, false],
	&"judge_rewind": [&"blink_in", 0.8, true],
	&"judge_return": [&"blink_out", 0.7, true],
}


## Appends the cue of event `e` to `out` ([cue, place or null, pitch]); false when the event is not one of these.
static func add(e: SimEvent, out: Array) -> bool:
	if not CUES.has(e.effect_id):
		return false
	var cue: Array = CUES[e.effect_id]
	out.append([cue[0], e.pos if cue[2] else null, cue[1]])
	return true
