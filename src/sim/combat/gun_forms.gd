class_name GunForms
extends RefCounted
## v0.6.5 WN3 (docs/design/WAND.md, the Gun pool G1–G16; SIM_CONTRACTS §8f): the runner features the Gun's cards
## needed beyond v0.6.0's (count, spread, circle, back, repeat, pierce, bounces, homing, return, orbit, a hook):
## - twin (G3 Twin): every bolt of a shot fires with `twin` more beside it, side by side (parallel, TWIN_GAP_RADII
##   of its radius apart), each a full bolt;
## - spiral (G11 Spiral): a projectile's heading swings `spiral` (1/4096 turns) either side of its line as
##   spiral × cos(2π age / SPIRAL_TICKS), so it corkscrews round the line it was fired on (the swing is applied as a
##   turn of its velocity each tick, after homing, so it rides a homing or a bounced path too);
## - mine (G12 Mine): a projectile stops where its flight ends and waits `mine_ticks` more, still, until an enemy
##   touches it (its hit ends it, so its ON_END hooks fire there: the card's blast) or the wait runs out;
## - charge (G13 Charge): with a charging bolt the Gun no longer fires on its period while SHOOT is held: holding it
##   charges (World.mx.hold_t, up to hold_ticks), and the shot fires on release or at full charge, its size and
##   damage × 1000 + (hold_permille − 1000) × held / hold_ticks per mille (a tap: a plain shot).
## Pure: no randomness (EI-05), no trig (Kin's tables), one clock (ticks).

## The corkscrew's period (ticks per full swing) and a twin bolt's gap, in its own radii (starting values).
const SPIRAL_TICKS := 24
const TWIN_GAP_RADII := 2.6


# --- Twin ------------------------------------------------------------------------------------------------------
## Each bolt's sideways offsets (metres, across the aim) for a spec of radius `r`: [0], or twin + 1 lanes centred
## on the aim.
static func lanes(spec: AttackSpec, r: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := maxi(0, spec.twin) + 1
	var gap := r * TWIN_GAP_RADII
	for k in n:
		out.append((k - (n - 1) * 0.5) * gap)
	return out


# --- Charge ----------------------------------------------------------------------------------------------------
## The shot's size and damage factor (per mille) after holding `held` ticks of a spec charging over hold_ticks.
static func charge_permille(spec: AttackSpec, held: int) -> int:
	if spec.hold_ticks <= 0:
		return 1000
	var t := clampi(held, 0, spec.hold_ticks)
	return 1000 + (spec.hold_permille - 1000) * t / spec.hold_ticks


## The Gun charges (its bolt has hold_ticks).
static func charging(w: World) -> bool:
	return Modifiers.bolt(w).hold_ticks > 0


## PlayerKit's shot for a charging Gun, each tick (in place of the period's fire): holding SHOOT while it may fire
## charges; a release (or a full charge) fires the charged shot through `fire` (a Callable taking the per mille).
static func hold(w: World, can_fire: bool, fire: Callable) -> void:
	var spec := Modifiers.bolt(w)
	var held := PlayerKit.shooting(w) and can_fire and w.swing_t == 0
	if held and w.shot_cd == 0:
		w.mx.hold_t = mini(w.mx.hold_t + 1, spec.hold_ticks)
		if w.mx.hold_t < spec.hold_ticks:
			return
	elif w.mx.hold_t <= 0:
		return
	if w.player_dead() or not can_fire:
		w.mx.hold_t = 0
		return
	var pm := charge_permille(spec, w.mx.hold_t)
	w.mx.hold_t = 0
	fire.call(pm)
	w.shot_cd = ItemEffects.shot_period_ticks(w)


## 0..1: how far the shot in the barrel has charged (the view's swelling orb; 0 when not charging).
static func charge_fraction(w: World) -> float:
	var spec := Modifiers.bolt(w)
	if spec.hold_ticks <= 0 or w.mx.hold_t <= 0:
		return 0.0
	return float(w.mx.hold_t) / float(spec.hold_ticks)


# --- Spiral and mine (ProjectileMoves calls these) -------------------------------------------------------------
## Projectile `pi` just spawned with spec `s`: its corkscrew and its mine wait into the store's columns.
static func on_spawn(w: World, pi: int, s: AttackSpec) -> void:
	var p := w.projectiles
	p.spiral[pi] = s.spiral
	if s.mine_ticks > 0:
		p.mine_t[pi] = s.mine_ticks
		p.life[pi] += s.mine_ticks


## True if spec `s` gives its projectiles a Gun behaviour (on_spawn has columns to set).
static func moves(s: AttackSpec) -> bool:
	return s.spiral > 0 or s.mine_ticks > 0


## Before projectile `pi`'s sweep (ProjectileMoves.steer, first): a mine past its flight stands still (true: nothing
## else steers it).
static func mine_waits(w: World, pi: int) -> bool:
	var p := w.projectiles
	if pi >= p.mine_t.size() or p.mine_t[pi] <= 0 or p.life[pi] > p.mine_t[pi]:
		return false
	p.vel_x[pi] = 0.0
	p.vel_y[pi] = 0.0
	return true


## After the other steering (ProjectileMoves.steer, last): a corkscrewing projectile turns by this tick's change of
## its swing (age = the ticks since it left, after an orbit).
static func spiral_turn(w: World, pi: int) -> void:
	var p := w.projectiles
	if pi >= p.spiral.size() or p.spiral[pi] <= 0 or p.orbit_t[pi] > 0:
		return
	var age := p.life0[pi] - p.life[pi]
	if age < 0:
		return
	var a := p.spiral[pi]
	var now := _swing(a, age)
	var before := _swing(a, age - 1) if age > 0 else 0
	if now == before:
		return
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var sp := Kin.length(v)
	if sp <= 0.0:
		return
	var turned := Kin.dir(Kin.angle_of(v) + now - before) * sp
	p.vel_x[pi] = turned.x
	p.vel_y[pi] = turned.y


## The heading swing (1/4096 turns) at `age` ticks: a × cos(2π age / SPIRAL_TICKS), rounded.
static func _swing(a: int, age: int) -> int:
	var phase := (age * SimTick.ANGLE_UNITS / SPIRAL_TICKS) & 4095
	return roundi(a * Kin.dir(phase).x)
