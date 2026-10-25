class_name Scatter
extends RefCounted
## v0.9.0 AF1 (owner Q7 "F5 Lance, F6 Scatter, F7 Glaive"; ATTACK_FORMS.md F6: "A short-range cone of pellets: brutal
## up close, weak at range", "6 pellets, 25°, 5 m range, every 0.55 s", elements "all: per pellet, at a lower chance";
## the old Spread's idea): the Scatter form, the Gun's shot as a cone of pellets (AttackSpec.pellets, set by the Scatter
## card, data/modifiers/gun_scatter.tres). It is the Gun's own bolt runner (Attacks._bolts) with the card's numbers, so
## every rule the orbs keep holds for the pellets:
## - The cone: count 6 bolts fanned evenly over spread (25°) centred on the aim, every period_ticks (0.55 s; attack
##   speed at half its bonus, AttackRate.form_rate), each flying speed × life_ticks (5 m) and ending on its first enemy
##   or a wall. Up close every pellet lands on one target; at range the cone opens (2.2 m wide at 5 m) and fewer do;
##   past 5 m none.
## - Damage: each pellet is share_permille of the shot's damage (1000: one orb hit, +5 % a level).
## - Elements per pellet at a lower chance: the pellets past the centre one are secondary (the share rule,
##   SecondaryProc: their statuses feed at the secondary proc), as Spread's were.
## - Twin's lanes double the cone (2 at Lv 1–4, 3 at Lv 5) at its share; Backfire fires a copy behind. The caps hold:
##   at most 12 pellets an attack (ShotCap.tree merges the rest into bigger ones), 40 projectiles a second.
## Pure: no randomness, no engine calls.


## `s` shoots the Scatter's pellets.
static func is_scatter(s: AttackSpec) -> bool:
	return s != null and s.pellets > 0


## Player projectile `pi` is a Scatter pellet (ScatterView draws it, not the pulses).
static func is_pellet(w: World, pi: int) -> bool:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or pi >= p.spec_key.size() or p.spec_key[pi] == "":
		return false
	return is_scatter(Attacks.projectile_spec(w, pi))


## The run's Gun shot is the Scatter now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_scatter(Modifiers.bolt(w))
