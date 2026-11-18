class_name BossWardensTable
extends RefCounted
## The Twin Wardens' own mechanics in sim units (ticks, m, m per tick, 1/4096 turns, per mille), compiled from
## BossDefinition.wardens (WardensRules.SPEC). BossWardenAmber (the sword combo's light hits, the side dash),
## BossWard (the Mirror Ward, the last phase's ward and its break), BossShadowSwords and BossRift read it. Phases are
## indices (0 = the first); a phase past the boss's last means never.

## The amber Warden's side dash between two attacks: dash_m in dash_ticks, at most one every dash_every_ticks.
var dash_m := 4.0
var dash_ticks := 15
var dash_every_ticks := 180
## The amber Warden's close and ranged attacks: one whose range band ends within ranged_beyond_m is close, picked only
## while the hero stands within it; every other one only while the hero stands beyond it (0 = no such rule).
var ranged_beyond_m := 0.0
## The charges on their own clocks (attack indices, -1 = none: the attack is picked like any other). charge_attack,
## in a phase that lists it: one every charge_min_ticks..charge_max_ticks (the ai stream's draw, from one start to the
## next), at any distance, aimed where the hero will be when it reaches them, with nothing drawn on the ground.
## ward_charge_attack, in a phase that lists it: one every ward_charge_min_ticks..ward_charge_max_ticks while the
## violet Warden's whole ward stands.
var charge_attack := -1
var charge_min_ticks := 600
var charge_max_ticks := 900
var ward_charge_attack := -1
var ward_charge_min_ticks := 600
var ward_charge_max_ticks := 720
## While the violet Warden's whole ward stands the amber Warden takes amber_warded_permille of the hero's damage.
var amber_warded_permille := 1000
## Crossfire as a shelter: attack shelter_attack's safe spot (an index, -1 = none) stands shelter_m from the hero, to
## one side of the line from the caster, so the hero walks into it.
var shelter_attack := -1
var shelter_m := 3.0
## A sword combo's hits before its last deal this share of the attack's damage.
var combo_light_permille := 750
## The longest a Sword Lane runs (its `chain_sweep` attack's line).
var lane_max_m := 9.0
## The Mirror Ward stands mirror_ticks on an arc mirror_half_arc each side of where it faces. A hero's shot it meets
## flies back for mirror_permille of its damage, at most mirror_cap_permille of the hero's max HP, mirror_range_m far,
## as a shot of look mirror_look; a melee swing it meets pushes the hero mirror_push_m back. The recap line of a
## returned shot that kills is mirror_cause_key.
var mirror_ticks := 240
var mirror_half_arc := 910
var mirror_permille := 500
var mirror_cap_permille := 200
var mirror_range_m := 16.0
var mirror_push_m := 2.0
var mirror_look := &""
var mirror_cause_key := &""
## Shadow Swords: sword_count blades on a fan sword_fan wide, sword_ring_m from the hero; each cuts a lane sword_len_m
## long and sword_half_m each side, one every sword_gap_ticks.
var sword_count := 5
var sword_ring_m := 5.0
var sword_fan := 2276
var sword_len_m := 8.0
var sword_half_m := 0.45
var sword_gap_ticks := 12
## From ward_phase the violet Warden stands under a whole ward. The amber Warden's charge through it breaks it: the
## violet one is stunned stun_ticks (taking stun_permille), the amber one staggered stagger_ticks, and the ward is
## back return_ticks after the break. With a ward_attack (the violet Warden's cast, an index; -1 = the ward stands
## from the phase's start) the ward is cast instead: the cast starts ward_first_ticks into ward_phase, and after a
## break so that the ward stands again return_ticks after it.
var ward_phase := 2
var ward_attack := -1
var ward_first_ticks := 240
var stun_ticks := 300
var stun_permille := 1500
var stagger_ticks := 120
var return_ticks := 720
## Through the Rift, once, in the last phase with rift_hp_permille of its bar left (0 = never): three rifts
## rift_gap_m apart (each rift_radius_m wide) show for rift_open_ticks, the amber Warden runs into the nearest, stays
## inside rift_inside_ticks, its exit marked for the last rift_mark_ticks, and charges out with attack rift_attack
## (an index, -1 = none).
var rift_hp_permille := 500
var rift_gap_m := 8.0
var rift_radius_m := 1.2
var rift_open_ticks := 60
var rift_inside_ticks := 90
var rift_mark_ticks := 30
var rift_attack := -1
