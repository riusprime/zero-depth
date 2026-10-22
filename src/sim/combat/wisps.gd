class_name Wisps
extends RefCounted
## v0.9.0 AF3 (owner Q7 "F8 Seekers, F9 Wave, F10 Wisps"; ATTACK_FORMS.md F10: "Orbs circle you and fire on their own
## at the nearest enemy while you aim and fire too", "3 wisps, each a 40 % orb every 0.6 s", every pattern and
## secondary off, elements "all"): the Wisps form (AttackSpec.wisps, set by the Wisps card, data/modifiers/
## gun_wisps.tres). The hero's own shot stays the orbs; the wisps come on top.
## - The ring: `wisps` wisps evenly round the hero at ORBIT_R_M, turning once every ORBIT_TICKS. Their places are the
##   clock's (World.tick), so the form keeps no state of its own and an old save needs nothing new.
## - The shots: each wisp fires every wisp_ticks (0.6 s), the wisps staggered evenly over it, on its own (SHOOT held or
##   not): one orb of the Gun's shot (its elements, its On Hit and On Kill hooks) at wisp_permille (40 %) of its damage,
##   from the wisp toward the nearest enemy it can see within an orb's flight; no enemy in reach, no shot. Attack speed
##   doesn't change the wisps' rhythm (the clock's stagger). A wisp's orb is no root launch (no Echo, no Ascension
##   charge, no Backfire) and flies at SHOT_SIZE_PERMILLE of the orb's size, so it reads as the wisp's.
## - Caps: the wisps' orbs are extras under ShotCap's 40 a second (3 wisps: 5 a second over the orbs' 6.7).
## Pure (EI-02): integer angles through Kin's tables, no randomness (EI-05), the one clock (EI-03).

const ORBIT_R_M := 1.1
const ORBIT_TICKS := 150
## A wisp's orb is this size of the Gun's orb (per mille; a smaller dart).
const SHOT_SIZE_PERMILLE := 650
## A wisp's orb leaves this far from the wisp (m).
const MUZZLE_M := 0.12


## `s` brings the wisps.
static func is_wisps(s: AttackSpec) -> bool:
	return s != null and s.wisps > 0


## The run's Gun has the wisps now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_wisps(Modifiers.bolt(w))


## Player projectile `pi` is a wisp's orb (with the Wisps form, a repeat-marked orb: no other repeat is open to it).
static func is_wisp_shot(w: World, pi: int) -> bool:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or (p.second_of(pi) & ProjectileStore.REPEAT) == 0:
		return false
	return active(w)


## Wisp `k` of `n`'s angle round the hero now (1/4096 turns).
static func angle(w: World, k: int, n: int) -> int:
	return (
		(w.tick * SimTick.ANGLE_UNITS / ORBIT_TICKS + k * SimTick.ANGLE_UNITS / maxi(1, n)) & 4095
	)


## Wisp `k` of `n`'s place now.
static func pos(w: World, k: int, n: int) -> Vector2:
	return w.player_pos() + Kin.dir(angle(w, k, n)) * ORBIT_R_M


## Ticks until wisp `k` of `n` fires (0: this tick), with period `period`.
static func wait(w: World, k: int, n: int, period: int) -> int:
	var t := (w.tick + k * period / maxi(1, n)) % period
	return (period - t) % period


## Tick phase 6 (ModifierRuntime.advance): each wisp whose turn it is fires at the nearest enemy it can see.
static func advance(w: World) -> void:
	if w.player_dead() or not active(w):
		return
	var spec := Modifiers.bolt(w)
	var n := spec.wisps
	var period := maxi(1, spec.wisp_ticks)
	for k in n:
		if wait(w, k, n, period) != 0:
			continue
		var from := pos(w, k, n)
		var foe := target(w, from, spec)
		if foe >= 0:
			_fire(w, spec, from, w.actors.pos(foe))


## The enemy wisp shots from `from` go for: the nearest within an orb's flight with no wall between (-1: none; a tie
## keeps the lower index).
static func target(w: World, from: Vector2, spec: AttackSpec) -> int:
	var reach := spec.speed * spec.life_ticks
	var best := -1
	var best_d := 0.0
	for i in w.enemies_near(from, reach):
		if w.actors.invuln[i] > 0:
			continue
		var d := Kin.length(w.actors.pos(i) - from)
		if (best < 0 or d < best_d) and not WaveShots._walled(w, from, w.actors.pos(i)):
			best = i
			best_d = d
	return best


static func _fire(w: World, spec: AttackSpec, from: Vector2, to: Vector2) -> void:
	var dmg := PlayerBuild.bolt_damage(w, Attacks.bolt_base_damage(spec))  # Builds: the Gun's factor (L16)
	dmg = maxi(1, (dmg * spec.wisp_permille + 500) / 1000)
	var tags := SimEvent.TAG_PROJECTILE
	var ctx := AttackContext.make(from, Kin.angle_of(to - from), dmg, 0, tags, &"")
	ctx.base_damage = dmg
	ctx.repeat = true  # no root launch: no Echo, no Ascension, no Backfire
	ctx.size_permille = SHOT_SIZE_PERMILLE
	ctx.muzzle_m = MUZZLE_M
	Attacks.launch(w, spec, ctx)


## The wisps for the views: [{pos, angle (1/4096 turns), wait (ticks to its next shot), period}], one per wisp.
static func read(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not active(w):
		return out
	var spec := Modifiers.bolt(w)
	var n := spec.wisps
	var period := maxi(1, spec.wisp_ticks)
	for k in n:
		(
			out
			. append(
				{
					"pos": pos(w, k, n),
					"angle": angle(w, k, n),
					"wait": wait(w, k, n, period),
					"period": period,
				}
			)
		)
	return out
