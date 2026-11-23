class_name BossLensTable
extends RefCounted
## The Hive Lens's lattice in sim units (ticks, m, per mille), compiled from BossDefinition.lattice
## (LatticeRules.SPEC). Phases are indices (0 = the first); a phase past the boss's last means never. BossLens (the
## feeding, the cuts, the drones sent again, the rhythm), BossGlass (the burnt glass) and BossLattice read it.

## Feeding, from feed_phase: each living drone of drone_kind cuts feed_cut per mille off every hit and tick from the
## hero, at most feed_cap. resend_ticks after the last drone is gone (none alive or arriving, no split under way) the
## boss casts split_attack (an index into the table's attacks) again.
var feed_phase := 1
var feed_cut := 150
var feed_cap := 450
var resend_ticks := 720
var drone_kind := -1
var split_attack := -1
## The boss's Focus Beams (attack indices): a drone in one of their lanes while it burns is cut down, and from
## strip_phase the far strip_len_m of each lane stays as burnt glass when its burn ends.
var beams := PackedInt32Array()
## The burnt glass: a strip strip_half_m each side of the lane's line for strip_ticks; the hero in one loses
## strip_damage HP (the boss's power applies) every strip_step_ticks; at most strip_max, the oldest goes first.
## strip_cause: the attack the death recap names.
var strip_phase := 2
var strip_len_m := 8.0
var strip_half_m := 0.5
var strip_ticks := 360
var strip_damage := 6
var strip_step_ticks := 30
var strip_max := 3
var strip_cause := -1
## The Lattice, from lat_phase: due lat_first_ticks into each phase (its first standing tick), then lat_every_ticks
## after each cast began. It needs lat_min living drones (fewer: the split first); a lat_cast_ticks cast, then for
## lat_ticks strands strand_half_m each side join the boss, its drones in turn and the boss again. A strand costs
## strand_hit per mille of the hero's max HP, then none for strand_lock_ticks; strand_cause is the recap's attack.
## The drones orbit the boss at orbit_step thousandths of 1/4096 turn a tick, eased toward their distance held to
## orbit_min_m..orbit_max_m. While a Lattice is cast or runs the boss starts none of `holds`; the Gaze and the
## Lattice keep calm_ticks apart.
var lat_phase := 1
var lat_first_ticks := 600
var lat_every_ticks := 2700
var lat_cast_ticks := 120
var lat_ticks := 600
var lat_min := 2
var strand_half_m := 0.3
var strand_hit := 200
var strand_lock_ticks := 30
var strand_cause := -1
var orbit_step := 3793
var orbit_min_m := 6.0
var orbit_max_m := 12.0
var calm_ticks := 180
var holds := PackedInt32Array()


## The first phase any part of the lattice runs in.
func first_phase() -> int:
	return mini(mini(feed_phase, strip_phase), lat_phase)
