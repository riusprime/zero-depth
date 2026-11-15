class_name WardenCues
extends RefCounted
## The sounds of the Twin Wardens' own mechanics and of any charge's burst, from their STATUS_APPLY events
## (AudioEvents asks; EI-07). No sound was recorded for them, so each borrows a cue that exists, pitched apart from its
## first use:
## - a charge's burst arming where the run stopped: the mine's arming click; the burst: the bomb's blast, lower;
## - the amber Warden's side dash: the hero's dash cue, lower;
## - a ward going up: the rune burst, lower (the Mirror Ward) and the same for the whole ward; the whole ward breaking
##   under his charge: the stress break;
## - a shot the Mirror Ward turns back: the guard block, higher; a swing it blocks and pushes back: the shield bash;
## - a shadow sword cutting: the elite's slash, higher;
## - the rifts opening: the portal opening; him going in: the blink out; the exit marked: the timer beep; him coming
##   out: the blink in.
## The ward fading and the rifts closing have no sound.

## effect id -> [cue, pitch, whether it sounds at the event's place].
const CUES := {
	&"charge_burst_armed": [&"mine_arm", 0.9, true],
	&"charge_burst": [&"bomb_blast", 0.85, true],
	&"warden_dash": [&"dash", 0.75, false],
	&"warden_ward_up": [&"rune_burst", 0.8, false],
	&"warden_ward_break": [&"stress_break", 1.0, false],
	&"warden_reflect": [&"guard_block", 1.3, true],
	&"warden_block": [&"shield_bash", 1.1, false],
	&"warden_sword_cut": [&"elite_slash", 1.2, true],
	&"warden_rift_open": [&"portal_open", 0.9, false],
	&"warden_rift_enter": [&"blink_out", 0.8, false],
	&"warden_rift_mark": [&"timer_beep", 0.9, true],
	&"warden_rift_exit": [&"blink_in", 0.8, true],
}


## Appends the cue of event `e` to `out` ([cue, place or null, pitch]); false when the event is not one of these.
static func add(e: SimEvent, out: Array) -> bool:
	if not CUES.has(e.effect_id):
		return false
	var cue: Array = CUES[e.effect_id]
	out.append([cue[0], e.pos if cue[2] else null, cue[1]])
	return true
