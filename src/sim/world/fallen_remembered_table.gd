class_name FallenRememberedTable
extends RefCounted
## The Fallen's remembered mechanics in sim units (ticks, m, m a tick, per mille), compiled from
## FinalBossDefinition.remembered (FallenRules.SPEC). BossRemembered runs them; each mechanic calls the source boss's
## own piece with these numbers: the Time Wave's orbs through BossTime.place_orbs (`time`), Riptide through BossDance
## (`dance`), the quake pillars through BossQuake (the body's BossTable.quake), the ward's shade through
## BossRemembered's own charge (FallenWard).

## The rhythm: a mechanic at each HP gate (per mille of max HP, highest first) and every every_ticks counted from the
## end of the last; the first no sooner than first_ticks after the body may act; calm_ticks clear of a mimic window
## on each side and between two mechanics; each opens with a cast_ticks cast.
var gates := PackedInt32Array([660, 330])
var every_ticks := 1800
var first_ticks := 720
var calm_ticks := 180
var cast_ticks := 90
## Time Wave: the weapon loses time_cut per mille; `time` holds its hour orbs (orb, orb_count, orb_gap_m), which
## last time_ticks; it ends when none lies.
var time_cut := 750
var time_ticks := 720
var time: BossTimeTable = null
## Riptide: one row of `dance`'s rip_* numbers (its rip_cause names the recap's carrier attack).
var dance: BossDanceTable = null
## Quake pillars: they stand pillar_ticks, clear of the hero by pillar_hero_m; during them the body dashes at the
## hero every pillar_dash_ticks (a dash whose lane runs into a pillar shatters it and stuns, BossQuake).
var pillar_ticks := 900
var pillar_hero_m := 3.0
var pillar_dash_ticks := 180
## The ward: the body takes nothing for at most ward_ticks. The shade (ward_radius_m) stands ward_edge_m in from the
## room's edge farthest from the hero and charges ward_charges times, ward_gap_ticks after the last one's end: a
## wind-up of ward_windup_ticks whose aim follows the hero until ward_lock_ticks before its end, then a run at
## ward_speed (m a tick) to ward_overshoot_m past where the hero stood when it locked. Its touch costs ward_hit;
## where it ends a burst of ward_burst_m costs ward_burst_hit after ward_burst_ticks. A lane through the body breaks
## the ward: the body is stunned ward_stun_ticks (taking the quake table's stun_permille). ward_cause names the
## recap's carrier attack.
var ward_ticks := 720
var ward_windup_ticks := 84
var ward_lock_ticks := 30
var ward_speed := 26.0 / 60.0
var ward_overshoot_m := 3.0
var ward_charges := 2
var ward_gap_ticks := 180
var ward_radius_m := 0.9
var ward_edge_m := 1.5
var ward_hit := 250
var ward_burst_m := 3.5
var ward_burst_ticks := 15
var ward_burst_hit := 300
var ward_stun_ticks := 240
var ward_cause := -1
## The theft (FallenTheft): at each theft gate (per mille of max HP, highest first) a theft_cast_ticks cast, then the
## hero's strongest card goes dark, at most theft_held at once; theft_hits hits landing in the rear arc of half width
## theft_half_arc (1/4096 turns) give the oldest one back.
var theft_gates := PackedInt32Array([660, 330])
var theft_cast_ticks := 90
var theft_held := 2
var theft_hits := 8
var theft_half_arc := 683
