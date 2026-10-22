class_name Lance
extends RefCounted
## v0.9.0 AF1 (owner Q7 "F5 Lance, F6 Scatter, F7 Glaive"; ATTACK_FORMS.md F5; it replaces the Charge card, retired
## through data/wand/migration.tres) and v0.9.0 AF1b (owner, PLAN "Owner decisions" AF1b: "could the charge attack be
## the same as the original ball but it creates a circle in front of the player that circles like a charging energy
## and then shoots a bit, moves the player back like a cadence weapon, the feel should be like a lowkey haduoken";
## "Pierces all", "A small step", "Grows with charge"): the Lance form, the Gun's shot as a charged energy ball
## (AttackSpec.lance, set by the Lance card, data/modifiers/gun_lance.tres).
## - The charge: GunForms' hold (the Charge card's rule, World.mx.hold_t): while SHOOT is held and the shot is ready
##   the charge grows one tick a tick up to hold_ticks (1.2 s); it stays full until SHOOT is let go. Releasing fires
##   at × 1000 + (hold_permille − 1000) × held / hold_ticks per mille of the shot's damage (× 1 for a tap, × 11.6 at
##   full: the AF1 row, a full charge about 1.0× the orbs on one target). The Gun then waits its period (0.4 s; attack
##   speed at half its bonus, AttackRate.form_rate) before the next charge starts. A dash, a guard or a stun while
##   charging drops the charge (GunForms.hold).
## - The ball: the Gun's own bolt (Attacks._bolts: the orb's speed, life and look), `pierce` PIERCE_ALL so it passes
##   every enemy (each hit once: ProjectileMoves.pierce leaves it past the body), ended only by a wall or its range.
##   Its radius grows with the charge: × 1 on a tap to × GROW_PERMILLE at full (size_permille), the hit as wide.
## - Elements: each enemy the ball crosses takes a full hit of its spec (statuses, On Hit, On Kill), as a piercing
##   bolt's; On End where it stops. Twin: GunForms' lanes (2 side by side at Lv 1–4, 3 fanned at Lv 5), at Twin's share.
## - Caps: the balls are projectiles (ShotCap's 12 a volley and 40 a second hold as for any shot).
## - The recoil: the release pushes the hero RECOIL_M back from the aim over RECOIL_TICKS ticks at full charge, scaled
##   by the charge (a tap: almost none); World._move_and_collide adds it to the walk, so walls stop it
##   (World.mx.recoil_t, recoil_step; hashed and saved while one runs).
## - One LANCE event a release (the view's muzzle burst, the sound): pos = the ball's muzzle, amount = its radius (mm),
##   amount_applied = the aim (1/4096 turns), proc_pct = the charge (per mille of the shot's damage), effect_id = the
##   spec's key.
## Pure: integer maths and Kin, no randomness, one clock.

## The ball's radius at full charge, per mille of a tap's (the owner: "about 2× wider at full").
const GROW_PERMILLE := 2000
## The release's push back at full charge (m) and the ticks it is spread over (the owner: "a small step"; about
## 0.5 m over a few ticks). Starting values.
const RECOIL_M := 0.5
const RECOIL_TICKS := 6
## "Pierces all": more pierces than a ball can meet in its flight.
const PIERCE_ALL := 999


## `s` is the Lance (its shot charges and releases a ball).
static func is_lance(s: AttackSpec) -> bool:
	return s != null and s.lance > 0


## The run's Gun shot is the Lance now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_lance(Modifiers.bolt(w))


## 0..1: how far the Lance in hand has charged (0 when it isn't charging).
static func charge(w: World) -> float:
	return GunForms.charge_fraction(w) if active(w) else 0.0


## 0..1: how far a release at `pm` (per mille of the damage, GunForms.charge_permille) was charged.
static func fraction(spec: AttackSpec, pm: int) -> float:
	var span := spec.hold_permille - 1000
	return clampf(float(pm - 1000) / float(span), 0.0, 1.0) if span > 0 else 1.0


## The ball's size (per mille of the bolt's radius) for a release at `pm`: × 1 on a tap up to × GROW_PERMILLE.
static func size_permille(spec: AttackSpec, pm: int) -> int:
	var span := spec.hold_permille - 1000
	if span <= 0:
		return GROW_PERMILLE
	return 1000 + (GROW_PERMILLE - 1000) * clampi(pm - 1000, 0, span) / span


## Where the charging ball sits now and how big it is (the view's circle; the ball a release now would launch, its
## centre lane): {pos, radius}. Empty while it isn't charging.
static func orb(w: World) -> Dictionary:
	var c := charge(w)
	if c <= 0.0:
		return {}
	var spec := Modifiers.bolt(w)
	var pm := GunForms.charge_permille(spec, w.mx.hold_t)
	var r := spec.radius_m * size_permille(spec, pm) / 1000.0
	var dir := Kin.dir(w.aim_angle)
	return {
		"pos": w.player_pos() + dir * (w.player.radius_m + r + Attacks.MUZZLE_GAP_M), "radius": r
	}


## A release (PlayerKit._fire_bolt, after the launch): one LANCE event and the hero's push back.
static func on_release(w: World, spec: AttackSpec, pm: int, radius: float) -> void:
	var pid := w.actors.ids[0]
	var dir := Kin.dir(w.aim_angle)
	var at := w.player_pos() + dir * (w.player.radius_m + radius + Attacks.MUZZLE_GAP_M)
	var e := w.emit_event(SimEvent.Kind.LANCE, pid, pid, pid, at)
	e.amount = int(round(radius * 1000.0))
	e.amount_applied = w.aim_angle & 4095
	e.proc_pct = pm
	e.effect_id = StringName(spec.key)
	var push := RECOIL_M * fraction(spec, pm)
	if push <= 0.0:
		return
	w.mx.recoil_t = RECOIL_TICKS
	w.mx.recoil_step = -dir * (push / RECOIL_TICKS)


## This tick's push back (World._move_and_collide, once a tick): the step, and one tick of it spent.
static func recoil(w: World) -> Vector2:
	if w.mx.recoil_t <= 0:
		return Vector2.ZERO
	var step := w.mx.recoil_step
	w.mx.recoil_t -= 1
	if w.mx.recoil_t == 0:
		w.mx.recoil_step = Vector2.ZERO
	return step
