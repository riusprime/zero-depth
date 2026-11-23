class_name FallenCues
extends RefCounted
## The sounds of The Fallen remembering a boss the run killed, from its STATUS_APPLY events (AudioEvents asks; EI-07).
## No sound was recorded for them, so each borrows one that exists:
## - the cast: the remembered boss's own telegraph (the Judge's clock, the Tidecaller's bell, the Gatekeeper's
##   rumble, the Wardens' chain), so the ear hears whose mechanic comes;
## - the ward going up and breaking: the Twin Wardens' own (WardenCues' ward up and break);
## - the shade winding a charge up: the Wardens' chain, where it stands.
## The mechanics' own pieces sound as on their bosses: the Time Wave (JudgeTimeCues), the Riptide (TideDanceCues), the
## burst (WardenCues), the pillar's stun (the boss's stagger) and every hit (the hero's hurt cue).

## The cast's cue by the remembered boss (WorldReader.FALLEN_SOURCES' ids).
const CAST_CUES := {
	&"clockwork_judge": &"boss_telegraph_clockwork_judge",
	&"tidecaller": &"boss_telegraph_tidecaller",
	&"gatekeeper": &"boss_telegraph_gatekeeper",
	&"twin_wardens": &"boss_telegraph_twin_wardens",
}
## effect id -> [cue, pitch, whether it sounds at the event's place].
const CUES := {
	&"fallen_ward_up": [&"rune_burst", 0.8, false],
	&"fallen_ward_break": [&"stress_break", 1.0, false],
	&"fallen_shade_charge": [&"boss_telegraph_twin_wardens", 0.85, true],
}


## Appends the cue of event `e` to `out` ([cue, place or null, pitch]); false when the event is not one of these.
static func add(e: SimEvent, out: Array) -> bool:
	if e.effect_id == WorldReader.EFFECT_FALLEN_CAST:
		var source: StringName = WorldReader.FALLEN_SOURCES.get(e.amount_applied, &"")
		out.append([CAST_CUES.get(source, &"boss_phase"), e.pos, 1.0])
		return true
	if not CUES.has(e.effect_id):
		return false
	var cue: Array = CUES[e.effect_id]
	out.append([cue[0], e.pos if cue[2] else null, cue[1]])
	return true
