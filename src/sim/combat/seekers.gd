class_name Seekers
extends RefCounted
## v0.9.0 AF2 (owner Q7 "F8 Seekers, F9 Wave, F10 Wisps"; ATTACK_FORMS.md F8: "Three small darts that curve to the
## nearest enemies", "3 × 45 % a shot, every 0.3 s, homing 360 °/s", every pattern and motion card off, elements "all:
## lower status chance per dart"; closest existing: the Homing card): the Seekers form, the Gun's shot as three homing
## darts (AttackSpec.seekers, set by the Seekers card, data/modifiers/gun_seekers.tres). It is the Gun's own bolt runner
## (Attacks._bolts) with the card's numbers and the homing rule (AttackSpec.homing, ProjectileMoves):
## - The volley: count 3 small darts fanned over spread around the aim every period_ticks (0.3 s; attack speed at half
##   its bonus, AttackRate.form_rate), each share_permille of the shot's damage (450: 45 % an orb hit, +5 % a level).
##   They fly 10 m/s for 1 s (10 m): at the orbs' 16.2 m/s a 360 °/s turn is a 2.6 m circle, and an enemy close beside
##   the hero sat inside it (the dart circled it and never hit); at 10 m/s the circle is 1.6 m.
## - The curve: each tick a dart turns at most `homing` (360 °/s) toward its own target (target()): the darts of one
##   volley spread over the nearest enemies, so three enemies near the hero take one dart each, and fewer share them.
## - Elements per dart at a lower chance: the darts past the centre one are secondary (the share rule, SecondaryProc:
##   their statuses feed at the secondary proc), as the Scatter's pellets.
## - Caps: 3 an attack, about 10 a second at most, under ShotCap's 12 and 40.
## Pure: no randomness, no trig, one clock; a dart's target is read from the world each tick (no state of its own).

## How far from the hero the darts look for targets (m; as far as an orb flies). Starting value.
const SEEK_M := 10.8


## `s` shoots the Seekers' darts.
static func is_seekers(s: AttackSpec) -> bool:
	return s != null and s.seekers > 0


## Player projectile `pi` is a Seekers dart (SeekersView draws it, not the pulses).
static func is_dart(w: World, pi: int) -> bool:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or pi >= p.spec_key.size() or p.spec_key[pi] == "":
		return false
	return is_seekers(Attacks.projectile_spec(w, pi))


## The run's Gun shot is the Seekers now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_seekers(Modifiers.bolt(w))


## The enemy dart `pi` curves to now, or -1 for the homing rule's own (the nearest to the dart). The enemies
## within SEEK_M of the hero (not invulnerable), nearest the hero first (a tie: the lower index), and the dart takes
## the one at its rank in the volley: its id modulo the volley's count (one volley's darts get consecutive ids, so
## distinct ranks). With fewer enemies than darts the ranks wrap round them.
static func target(w: World, pi: int) -> int:
	var spec := Attacks.projectile_spec(w, pi)
	if not is_seekers(spec):
		return -1
	var n := maxi(1, spec.count)
	var rank := w.projectiles.ids[pi] % n
	var hero := w.player_pos()
	var a := w.actors
	var ds := PackedFloat32Array()
	var ids := PackedInt32Array()
	for i in w.enemies_near(hero, SEEK_M):
		if a.invuln[i] > 0:
			continue
		var d := Kin.length(a.pos(i) - hero)
		var k := ds.size()  # keep the rank + 1 nearest, sorted
		while k > 0 and (ds[k - 1] > d or (ds[k - 1] == d and ids[k - 1] > i)):
			k -= 1
		if k > rank:
			continue
		ds.insert(k, d)
		ids.insert(k, i)
		if ds.size() > rank + 1:
			ds.resize(rank + 1)
			ids.resize(rank + 1)
	if ids.is_empty():
		return -1
	return ids[rank % ids.size()]
