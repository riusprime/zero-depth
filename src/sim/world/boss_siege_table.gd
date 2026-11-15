class_name BossSiegeTable
extends RefCounted
## The Siege Engine's siege mechanics in sim units (ticks, m, m per tick, per mille), compiled from
## BossDefinition.siege (SiegeRules.SPEC). Phases are indices (0 = the first); a phase past the boss's last means
## never. BossSiege (the Target Lock, the boulders, the Shockwave's cover) and BossDoom (the ammo cart, the Doom Shell)
## read it.

## The Target Lock, from lock_phase: the first lock_first_ticks after that phase begins, then one every
## lock_every_ticks (start to start). Its circle (lock_radius_m) follows the hero for lock_ticks at lock_follow per
## mille of the hero's run speed now, holds still for its last lock_hold_ticks, then the shell lands: lock_hit per
## mille of max HP to a hero touching it.
var lock_phase := 1
var lock_first_ticks := 360
var lock_every_ticks := 840
var lock_ticks := 240
var lock_hold_ticks := 36
var lock_radius_m := 2.2
var lock_follow := 800
var lock_hit := 350
## The boulder a shell leaves: a square of half side boulder_half (m) standing boulder_ticks, boulder_max at most.
var boulder_half := 1.5
var boulder_ticks := 1800
var boulder_max := 4
## From cover_phase the boss's `slam_ring` attacks hit a hero the boss can see, wherever it stands, at most
## shock_cap per mille of max HP.
var cover_phase := 2
var shock_cap := 400
## The Doom Shell, from doom_phase: doom_count carts a phase (doom_late_count from doom_late_phase), the first
## doom_first_ticks into the phase, then one every doom_every_ticks. A cart (cart_hp per mille of the boss's max HP,
## cart_radius_m) rolls cart_ticks to the boss; doom_ticks after it arrives the shell hits doom_hit per mille of max HP
## to a hero the boss can see. Destroyed first, it blasts cart_blast_m round itself: cart_blast_hit per mille to the
## hero, and the boss inside it takes strip_taken per mille for strip_ticks.
var doom_phase := 1
var doom_first_ticks := 840
var doom_every_ticks := 2100
var doom_count := 1
var doom_late_phase := 2
var doom_late_count := 2
var cart_hp := 60
var cart_radius_m := 1.0
var cart_ticks := 600
var doom_ticks := 60
var doom_hit := 400
var cart_blast_m := 6.0
var cart_blast_hit := 250
var strip_ticks := 480
var strip_taken := 1500
## The actor kind the cart is (ActorStore.Kind), and the kind of the boss's deployed turrets a shell destroys (-1 =
## none: the boss's first `deploy` attack's enemy).
var cart_kind := -1
var turret_kind := -1
## The attack the death recap names for a shell, the Doom Shell and the cart's blast (the boss's first `marks`
## attack, -1 none).
var shell_cause := -1


## The carts boss phase `phase` sends.
func carts_in(phase: int) -> int:
	if phase < doom_phase:
		return 0
	return doom_late_count if phase >= doom_late_phase else doom_count
