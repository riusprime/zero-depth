class_name TideDanceCues
extends RefCounted
## The sounds of the Tidecaller's dance, from its STATUS_APPLY events (AudioEvents asks; EI-07). No sound was recorded
## for them, so each borrows a cue that exists, pitched apart from its first use:
## - a Riptide warning beginning: the Tidecaller's bell (its telegraph), lower;
## - its wave running: the Pull's surge of water, higher and quicker;
## - a High Tide cast beginning: the Pull's surge, low (the water rising);
## - the High Tide's water up: the Tidecaller's bell, low;
## - the Maelstrom beginning: the Pull's surge, lowest;
## - the eye's throw: the boss slam, where the hero stood.
## A Riptide hit and each High Tide step are the hero's own hurt cue already; the water draining has no sound.

## effect id -> [cue, pitch, whether it sounds at the event's place].
const CUES := {
	&"riptide_cast": [&"boss_telegraph_tidecaller", 0.85, false],
	&"riptide_wave": [&"boss_tide_pull", 1.35, false],
	&"high_tide_cast": [&"boss_tide_pull", 0.75, false],
	&"high_tide": [&"boss_telegraph_tidecaller", 0.7, false],
	&"maelstrom": [&"boss_tide_pull", 0.6, false],
	&"maelstrom_throw": [&"boss_slam", 1.15, true],
}


## Appends the cue of event `e` to `out` ([cue, place or null, pitch]); false when the event is not one of these.
static func add(e: SimEvent, out: Array) -> bool:
	if not CUES.has(e.effect_id):
		return false
	var cue: Array = CUES[e.effect_id]
	out.append([cue[0], e.pos if cue[2] else null, cue[1]])
	return true
