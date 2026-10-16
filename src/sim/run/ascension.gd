class_name Ascension
extends RefCounted
## v0.7.5 AP (owner N4: "a feature like the blue portal but a new one … that fits the word ascension … end the run
## or you can choose to start over … the infinity loop"). On a run's last floor of a loop the boss room's gate is the
## Ascension portal (BossFlow.ascension, set by RunState.prepare). It opens with the boss's death like any gate.
## v0.8.0 P2 (owner O28: "it should be a continue flow … we separate it into two different actions from now on, not
## a menu, two different visual elements the ascension to go fight final boss or the loop element, separated"): no
## choice panel any more. The boss room holds two separate devices, both opening with the boss's death:
## - the Ascension portal (the gate's place): walking into its opening sends the hero in (Choice.ASCENSION): on to the
##   final arena and the final boss (BossFlow.final_next; RunState.finish_floor), or, in a run with no final boss,
##   the run is won (WorldReader.outcome 1);
## - the Loop device, smaller, beside it (place_loop_device: FloorLayout.loop_pos): stepping onto it sends the hero in
##   (Choice.LOOP): the floor ends (outcome 3) and RunState.finish_floor starts the next loop at its floor 1 with the
##   build carried (RunCarry), harder (RunState.loop_permille, World.loop_threat, World.loop_cap_permille).
## "End the run" as a choice is gone: the run ends by beating the final boss (the true ending) or by dying. Pure: no
## stream is drawn here (the device's spot is a pure function of the layout, so a saved floor rebuilds it).

## Appended, never inserted: BossFlow.ascend_choice is hashed and saved (an older save's END is the portal, ASCEND the
## loop: the same numbers).
enum Choice { NONE, ASCENSION, LOOP }

## The Loop device takes the hero within this far (m) of its centre.
const LOOP_RADIUS_M := 0.9
## With no spot beside the portal: this far (m) from where the boss appears, toward the portal (the boss's legendary
## altar stands at boss_spawn). Not met in 60 probed runs (docs/roadmap/v0.8.0/evidence/VOID_AND_PORTALS.md).
const FALLBACK_M := 3.0


## Places the Loop device in f's boss room (setup, on a loop's last floor): in front of the first spot where a Deep gate
## would fit beside the gate (Routes.candidates and Routes.fits, without clearing any piece), at the centre of that
## spot's clear front square, facing out of its wall. If none fits, FALLBACK_M from where the boss appears, toward the
## portal, facing as the gate. Nothing solid is added (the walls stay those of the floor the generator builds, so a
## saved floor's snapshot still fits it). Returns whether the boss room had a place.
static func place_loop_device(f: FloorLayout, params: FloorParams = null) -> bool:
	f.has_loop_device = false
	if f.boss_room < 0:
		return false
	var p := params if params != null else FloorParams.defaults()
	var r := f.rooms[f.boss_room]
	f.has_loop_device = true
	for c: Array in Routes.candidates(f):
		if Routes.fits(f, p, r, c[0], c[1], false):
			var front := FloorLayout.GATE_HALF_DEPTH + FloorLayout.GATE_FRONT * 0.5
			f.loop_pos = c[0] + Kin.dir(c[1]) * front
			f.loop_angle = c[1]
			return true
	f.loop_pos = f.boss_spawn - Kin.dir(f.portal_angle) * FALLBACK_M  # clear of the boss's altar at boss_spawn
	f.loop_angle = f.portal_angle
	return true


## p stands on the Loop device of f.
static func on_loop_device(f: FloorLayout, p: Vector2) -> bool:
	return f.has_loop_device and Kin.length(p - f.loop_pos) <= LOOP_RADIUS_M


## The floor `w` was left by the Loop device (the next floor is the next loop's first).
static func looped(w: World) -> bool:
	return (
		w.boss_flow != null and w.boss_flow.ascension and w.boss_flow.ascend_choice == Choice.LOOP
	)


## The floor `w` was left through the Ascension portal (on to the final boss; the run is won without one).
static func took_portal(w: World) -> bool:
	return (
		w.boss_flow != null
		and w.boss_flow.ascension
		and w.boss_flow.ascend_choice == Choice.ASCENSION
	)
