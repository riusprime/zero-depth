class_name Glaive
extends RefCounted
## v0.9.0 AF2 (owner Q7 "F5 Lance, F6 Scatter, F7 Glaive"; ATTACK_FORMS.md F7: "A spinning disc that flies out and
## returns, hitting on both ways", "7 m out, ×1.6 damage per pass, every 0.7 s", Twin yes, Spiral off, Swirl yes,
## elements all; it replaces the Boomerang card, retired through data/wand/migration.tres): the Glaive form, the Gun's
## shot as a returning disc (AttackSpec.glaive, set by the Glaive card, data/modifiers/gun_glaive.tres). It is the
## Gun's own bolt runner (Attacks._bolts) with the card's numbers and the retired Boomerang's return rule
## (AttackSpec.returns, ProjectileMoves), so every rule the orbs keep holds for the disc:
## - The flight: one disc every period_ticks (0.7 s; attack speed at half its bonus, AttackRate.form_rate) along the
##   aim at speed for life_ticks; at half its life (7 m out) it turns back and flies at the hero, ending when it reaches
##   them (or on a wall). Its life never runs out on the way home (ProjectileMoves): a pierce's push past a body near
##   the hero would otherwise end it short of that body, so a point-blank enemy took one pass, not two. Going out, a
##   pierce's push past a body spends the ticks that distance would take (ProjectileMoves.pierce), so it still turns
##   7 m out with enemies on its path (without it, three enemies in a row sent it 11.6 m).
## - Both ways: it passes through every enemy it meets (the return rule's pierce: each sweep leaves it just past the
##   body it hit), so an enemy on its path takes one hit going out and one coming back.
## - Damage: each pass's hit is share_permille of the shot's damage (1600: × 1.6 an orb hit, +5 % a level).
## - Twin's lanes throw 2 discs side by side (3 fanned at Lv 5) at its share, the ones past the primary at the
##   secondary proc; Swirl turns each throw at random. The caps hold (ShotCap: a disc is one projectile).
## Pure: no randomness, no engine calls.


## `s` throws the Glaive's discs.
static func is_glaive(s: AttackSpec) -> bool:
	return s != null and s.glaive > 0


## Player projectile `pi` is a Glaive disc (GlaiveView draws it, not the pulses).
static func is_disc(w: World, pi: int) -> bool:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or pi >= p.spec_key.size() or p.spec_key[pi] == "":
		return false
	return is_glaive(Attacks.projectile_spec(w, pi))


## Disc `pi` is on its way back (the return rule turned it).
static func coming_back(w: World, pi: int) -> bool:
	var p := w.projectiles
	return p.moves and pi < p.ret.size() and p.ret[pi] == 2


## The run's Gun shot is the Glaive now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_glaive(Modifiers.bolt(w))
