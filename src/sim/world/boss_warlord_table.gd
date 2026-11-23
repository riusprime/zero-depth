class_name BossWarlordTable
extends RefCounted
## The Warlord's own mechanics in sim units (ticks, m, per mille), compiled from BossDefinition.warlord
## (WarlordRules.SPEC). Phases are indices (0 = the first); a phase past the boss's last means never. BossWarlord (the
## rhythm, the banner) and BossDuel (the cage) read it.

## The War Banner, in banner_phase: the first cast banner_first_ticks after that phase's gate, then each one
## banner_gap_ticks after the last is gone. The cast lasts banner_cast_ticks; then a circle of banner_radius_m stands
## where the boss stood for banner_ticks, or until a charge's lane passes within banner_pole_m of its pole. Inside it
## the boss's attack cooldowns run at banner_cooldown per mille of their length, and the hero's damage to the boss is
## banner_damage per mille.
var banner_phase := 1
var banner_first_ticks := 480
var banner_gap_ticks := 720
var banner_cast_ticks := 60
var banner_radius_m := 6.0
var banner_ticks := 1200
var banner_cooldown := 700
var banner_damage := 1400
var banner_pole_m := 0.8
## The Duel, in duel_phase: the first cast duel_first_ticks after that phase's gate, then each one duel_gap_ticks
## after the last ended. The cast lasts duel_cast_ticks; then the cage stands duel_ticks, its fence closing from
## duel_radius_m to duel_end_radius_m; a hero within fence_touch_m of it loses fence_hit per mille of its max HP, at
## most once every fence_every_ticks. Then recall_warn_ticks of warning on the centre's recall_radius_m, and the recall
## takes recall_hit per mille from a hero in it. Inside the cage the boss starts only duel_attacks (attack indices).
## fence_cause and recall_cause: what the death recap names (World.killer_attack values).
var duel_phase := 2
var duel_first_ticks := 480
var duel_gap_ticks := 1500
var duel_cast_ticks := 72
var duel_radius_m := 9.0
var duel_end_radius_m := 5.0
var duel_ticks := 720
var fence_touch_m := 0.3
var fence_hit := 100
var fence_every_ticks := 36
var recall_warn_ticks := 60
var recall_radius_m := 2.5
var recall_hit := 400
var duel_attacks := PackedInt32Array()
var fence_cause := -1
var recall_cause := -1


## The first phase either runs in.
func first_phase() -> int:
	return mini(banner_phase, duel_phase)
