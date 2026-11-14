class_name BossTimeTable
extends RefCounted
## The Clockwork Judge's time mechanics in sim units (ticks, m, m per tick, per mille), compiled from
## BossDefinition.time (TimeRules.SPEC). Phases are indices (0 = the first); a phase past the boss's last means never.
## BossTime (the Time Wave, the hour orbs, the slow fields), BossGears (the stopped gears) and BossRewind (the pale
## copy, the Bell, the Judge's own return) read it.

## The Time Wave: the first one wave_first_ticks after the Judge may first attack, then one every wave_every_ticks
## from one cast's start to the next; it takes wave_cut per mille of the hero's weapon rate (BossSlow).
var wave_first_ticks := 480
var wave_every_ticks := 1500
var wave_cut := 750
## The hour orbs a wave places: orb_count of them, orb_gap_m from each other and from the hero. `orb` is the pickup
## before orb_late_phase (it stays until taken or the next wave), `orb_late` from that phase on (it runs out).
var orb_count := 3
var orb_gap_m := 8.0
var orb_late_phase := 2
var orb: BossPickupTable = null
var orb_late: BossPickupTable = null
## The stopped gears, from gear_phase: with each wave up to gear_count walls (gear_half: half its length, half its
## width) stand gear_ticks across the lines from the hero to the orbs.
var gear_phase := 1
var gear_count := 4
var gear_half := Vector2(2.5, 0.4)
var gear_ticks := 720
## The slow fields, from field_phase: one every field_every_ticks half-way between the hero and the Judge (`field`,
## null = none). While a hero's shot crawls through one toward it the Judge steps out of its line at `dodge`.
var field_phase := 1
var field_every_ticks := 420
var field: ShotFieldTable = null
var dodge := 0.0
## The Rewind, from rewind_phase. Both trails keep a point every step_ticks, `points` of them. The pale copy stands
## where the hero stood trail_ticks ago (late_trail_ticks from late_phase). The Bell: the first cast bell_first_ticks
## into rewind_phase, then every bell_every_ticks (start to start); bell_cast_ticks later it tolls and the hero is
## thrown to the copy; from late_phase it tolls late_tolls times, toll_gap_ticks apart.
var rewind_phase := 1
var step_ticks := 15
var points := 26
var trail_ticks := 240
var late_phase := 2
var late_trail_ticks := 360
var late_tolls := 2
var toll_gap_ticks := 180
var bell_first_ticks := 900
var bell_every_ticks := 1200
var bell_cast_ticks := 120
## The Judge's own return, once, in return_phase: with return_hp_permille of that phase's bar left it goes back to
## where it stood return_ticks ago and recovers return_heal_permille of the bar, unless the hero is within
## return_near_m of its edge (0 return_hp_permille = never).
var return_phase := 2
var return_hp_permille := 150
var return_ticks := 300
var return_heal_permille := 50
var return_near_m := 4.0
