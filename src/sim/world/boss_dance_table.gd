class_name BossDanceTable
extends RefCounted
## The Tidecaller's dance in sim units (ticks, m, per mille), compiled from BossDefinition.dance (DanceRules.SPEC).
## Phases are indices (0 = the first); a phase past the boss's last means never. BossTide (the Pull's strength),
## BossDance (Riptide, High Tide), BossMaelstrom and BossTideBeats (when each big mechanic comes) read it.

## The strips Riptide cuts the room into, and the safe strip of each cast in a row (its mirror: STRIPS - 1 - s). The
## order is written: two neighbours, one a strip away, then the far side of the room.
const STRIPS := 4
const SAFE_ORDER: Array[int] = [1, 2, 0, 3]

## The Pull: its strength as a share of the hero's own run speed now (pull_late from pull_late_phase; 0 = the
## attack's own metres a second), and the push as a throw of push_m over the attack's push time (0 = the attack's own).
## Where the push sets the hero down, every hostile shot within push_clear_m pops, so a throw never lands in a ring.
var pull := 750
var pull_late := 850
var pull_late_phase := 2
var push_m := 4.0
var push_clear_m := 3.0
## The rhythm (BossTideBeats): one big mechanic at a time, calm_ticks at least between the end of one and the start
## of the next, the stream and the attacks held from a big mechanic's start until resume_ticks after its end. In
## phase k the first beat comes beat_first_ticks[k] after the phase begins (after its gate), and each next one
## beat_gap_ticks[k] after the calm that follows the last (a phase past the arrays' end uses their last entry).
var calm_ticks := 180
var resume_ticks := 90
var beat_first_ticks := PackedInt32Array([360, 360, 480])
var beat_gap_ticks := PackedInt32Array([720, 480, 600])
## Riptide, from rip_phase. A row is rip_casts casts: each warns three strips for rip_warn_ticks (the last cast
## rip_last_warn_ticks), and never for less than the hero's walk to its safe strip (BossDance.warn_of: the gap plus a
## metre, at the hero's run speed, times rip_run_margin per mille), then a wave runs down them in rip_wave_ticks and
## takes rip_hit per mille of the hero's max HP, once a cast. rip_cause: the attack the death recap names (an index
## into the table's attacks, -1 none).
var rip_phase := 1
var rip_casts := 4
var rip_warn_ticks := 150
var rip_last_warn_ticks := 180
var rip_run_margin := 1300
var rip_wave_ticks := 36
var rip_hit := 350
var rip_cause := -1
## High Tide, from ht_phase. Its cast
## (ht_cast_ticks) shows one dry circle of ht_radius_m at least ht_gap_m from the hero; then for ht_flood_ticks a hero
## outside it loses ht_hit per mille of max HP every ht_step_ticks. tide_cause: the recap's attack for it and for the
## Maelstrom's eye.
var ht_phase := 2
var ht_cast_ticks := 150
var ht_flood_ticks := 360
var ht_step_ticks := 30
var ht_radius_m := 4.0
var ht_gap_m := 12.0
var ht_hit := 30
var tide_cause := -1
## The Maelstrom, from mael_phase to the end of the fight (and no Pull is cast): each tick the hero is carried
## mael_spin per mille of its run speed round the boss and mael_in per mille toward it. Within mael_eye_m of the
## boss's edge it loses mael_hit per mille of max HP and is thrown mael_throw_m outward over mael_throw_ticks; then
## the eye leaves it alone for mael_grace_ticks.
var mael_phase := 2
var mael_spin := 450
var mael_in := 250
var mael_eye_m := 1.5
var mael_hit := 400
var mael_throw_m := 10.0
var mael_throw_ticks := 30
var mael_grace_ticks := 180


## The Pull's share of the hero's run speed in `phase`, per mille.
func pull_share(phase: int) -> int:
	return pull_late if phase >= pull_late_phase else pull


## The first beat's delay in `phase`, ticks (beat_first_ticks).
func first_ticks(phase: int) -> int:
	return _of(beat_first_ticks, phase)


## The gap after the calm before the next beat in `phase`, ticks (beat_gap_ticks).
func gap_ticks(phase: int) -> int:
	return _of(beat_gap_ticks, phase)


static func _of(a: PackedInt32Array, phase: int) -> int:
	return a[clampi(phase, 0, a.size() - 1)] if not a.is_empty() else 0


## The safe strip of cast n in a row (mirrored when `mirror` is 1).
func safe_strip(n: int, mirror: int) -> int:
	var s := SAFE_ORDER[clampi(n, 0, SAFE_ORDER.size() - 1)]
	return STRIPS - 1 - s if mirror == 1 else s


## The written warning's ticks of cast n in a row (the last one's is its own), before the walk's minimum.
func warn_ticks(n: int) -> int:
	return rip_last_warn_ticks if n >= rip_casts - 1 else rip_warn_ticks
