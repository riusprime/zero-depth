class_name QuakeTable
extends RefCounted
## v0.11.0 O3 (owner L5, Q9 a: "boss takes more damage during the stun, this should happen at most 2 times per
## phase"; BossQuake): the Gatekeeper's quake pillars in sim units (ticks, m, per mille), compiled from
## BossDefinition.quake (QuakeRules.SPEC). From phase `from_phase` on, each phase's start raises pillars until `count`
## stand; each pulses every pulse_ticks (its ring growing over the last warn_ticks), hurting a player within ring_m
## of its centre for damage_permille of their max HP. A Shock Lanes strike through one shatters it; the first
## stuns_per_phase breaks of a phase stun the boss stun_ticks, taking stun_permille of the damage meanwhile.

var count := 3
var from_phase := 1
## Half the pillar's side (m).
var half_m := 0.6
var pulse_ticks := 180
var warn_ticks := 48
var ring_m := 2.6
var damage_permille := 30
var stun_ticks := 120
var stun_permille := 1500
var stuns_per_phase := 2
## Placement: at least gap_m between two quake pillars' centres, wall_m of clear floor round a pillar's edge, and
## boss_m between a pillar's edge and the boss's.
var gap_m := 5.0
var wall_m := 1.5
var boss_m := 2.0
var cause_key := &""
