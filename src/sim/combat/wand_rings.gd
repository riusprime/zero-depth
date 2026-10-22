class_name WandRings
extends RefCounted
## v0.8.0 AO (owner O37: "a modifier of the basic attack makes the attack … a circle of lightning, and then 3 attacks
## make a triple circle … and then … a swirl card that makes the circle go out randomly making it a 'storm'"):
## the order rule's rings (AttackSpec.ring_layout, set by a SHAPE card: WandCompile.take_in) and Swirl's thrown shots.
## Attacks._ring hands a ring_layout spec here; Attacks._bolts asks for a swirled bolt's angle.
##
## v0.8.0 N3 (owner O47: "the circle should substitute the fireball not be a circle that spawns where you aim"; "maybe
## substituting the fireball for a shooting ring is better balanced"; docs/roadmap/v0.8.0/evidence/
## N3_RING_AND_LOADING.md): the Ring is the shot itself. Each ring leaves the hero's edge along its aim at the bolt's
## speed for the bolt's flight (AttackSpec.ring_flight; cut short by the first wall on its line), expanding from
## START_PERMILLE of its radius to the whole over GROW_TICKS, and hits every enemy its disc passes over (once per pass:
## ModifierAbilities._travel_step) and shocks (the card's status). The order rule:
## - a count RIGHT of the Ring (Ring · Spread, Ring · Halo) makes more ring shots, laid as that count lays bolts
##   (Attacks.shot_offsets: Spread's fan, Halo's circle), each MULTI_PERMILLE of the ring's hit;
## - a count LEFT of the Ring (Spread · Ring) is taken in as pulses: ONE ring shot, PULSE_GROW_PERMILLE bigger per
##   extra pulse, whose flight is split into `ring_pulses` pulses that each grow out again from START_PERMILLE (so its
##   edge passes over what it carries up to that many times), each pulse's hit MULTI_PERMILLE of the ring's;
## - a Swirl RIGHT of the rings (Ring · Spread · Swirl, the storm): each ring flies off in its own random direction,
##   one every SWIRL_GAP_TICKS (the only randomness: the named stream below);
## - a Swirl LEFT of the Ring (Swirl · Ring · Spread): the group flies along the aim as one, its rings circling the
##   group's travelling centre GROUP_ORBIT_PERMILLE of a ring's radius out, SPIN_PER_TICK a tick (one ring alone
##   wobbles round its line WOBBLE_PERMILLE out). No draw: the spin is fixed.
## Every ring deals the card's ring_share_permille of the shot's hit (the retune: a ring hits everything it passes, so
## it hits for less than the bolt it replaces), and hits each enemy once per pulse (ModifierAbilities._travel_step).
## The rings of one launch share one root (N3 retune; AO gave each its own), so a launch feeds an enemy's shock once
## and discharges it once, however many of its rings pass over it. A cast ring (a trigger's, a hook's: depth > 0)
## leaves from where it was cast, in its cast's root.
##
## Randomness only from a named stream (EI-05): "wand:swirl:<tick>:<launch>", derived from the run's seed for this one
## launch (no saved state; replays exactly); drawn only for a Swirl right of the rings and a swirled bolt. Caps (owner
## O9's frame budget, evidence/PERF.md): at most RINGS_MAX rings alive (every ring of every spec); a launch past it lays
## the rings that fit and leaves one LIMIT event (EFFECT_RING_CAP, amount: the cap); at most PULSES_MAX pulses; a bolt
## child of a ring at most RING_CHILD_ALIVE_MAX alive. Starting values.

## A ring's start size and growth (N3): START_PERMILLE of its radius, the whole after GROW_TICKS (or its pulse).
const START_PERMILLE := 450
const GROW_TICKS := 10
## Each ring of several (or pulse of several) hits for this share of the ring's hit.
const MULTI_PERMILLE := 400
## A pulsing ring (a count left of the Ring) is this much bigger per extra pulse (per mille of its radius).
const PULSE_GROW_PERMILLE := 150
## The storm's rings leave one after another, this many ticks apart.
const SWIRL_GAP_TICKS := 4
## Swirl left of the Ring: the group's rings circle its centre this far out (ring radii, per mille); one ring
## wobbles round its line this far out; the spin (1/4096 turns a tick: a full turn in ~0.7 s).
const GROUP_ORBIT_PERMILLE := 700
const WOBBLE_PERMILLE := 500
const SPIN_PER_TICK := 96.0
## A swirled bolt's angle off the aim, at most (1/4096 turns: 60°).
const SWIRL_HALF := 683
const RINGS_MAX := 48
## A ring's pulses, at most: a count past it left of the Ring is dropped (Spread at level 5 is 11 shots).
const PULSES_MAX := 5
## A bolt child of a ring (Split's shards, a trigger's cast, built right of the Ring): at most this many alive
## (AttackSpec.alive_max, PF2's cap).
const RING_CHILD_ALIVE_MAX := 64
## A ring's centre stops this far short of a wall it flies at (metres), so it ends against it.
const WALL_GAP_M := 0.1
const EFFECT_RING_CAP := &"wand_ring_cap"
const STREAM := "wand:swirl"


## The launch's stream (class doc): one per tick and launch.
static func stream(w: World) -> RngStream:
	return RngStream.derive(w.seed_value, "%s:%d:%d" % [STREAM, w.tick, w.launch_count])


## Fires `spec`'s ring shots for the launch `ctx` (class doc).
static func launch(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var pulses := clampi(spec.ring_pulses, 1, PULSES_MAX)
	var r := Attacks.area_radius(w, spec) * (1000 + PULSE_GROW_PERMILLE * (pulses - 1)) / 1000.0
	var offsets := Attacks.shot_offsets(spec)
	var n := offsets.size()
	var dmg := ring_damage(spec, ctx.damage, n, pulses)
	var speed := spec.speed if spec.speed > 0.0 else SpecForms.BOLT_SPEED
	var flight := spec.ring_flight if spec.ring_flight > 0 else SpecForms.BOLT_TICKS
	var rng: RngStream = stream(w) if spec.swirl > 0 else null
	var root := ctx.root if ctx.root != 0 else w.take_root()  # one root for the launch's rings (class doc)
	var c := AttackContext.make(ctx.origin, ctx.angle, dmg, root, ctx.tags, ctx.effect_id)
	c.depth = ctx.depth
	c.proc_pct = ctx.proc_pct
	var edge := w.player.radius_m if ctx.depth == 0 else 0.0
	if spec.swirl_group > 0:  # Swirl left of the Ring: the group flies the aim, spinning
		var dir := Kin.dir(ctx.angle)
		var from := ctx.origin + dir * edge
		var ticks := _clear_ticks(w, from, dir, speed, flight)
		var orb := r * (GROUP_ORBIT_PERMILLE if n > 1 else WOBBLE_PERMILLE) / 1000.0
		for k in n:
			if not _room(w):
				return
			var a0 := (ctx.angle + k * SimTick.ANGLE_UNITS / n) & 4095
			ModifierAbilities.add_ring(
				w, from, r, spec, c, 0, [dir * speed, orb, a0, pulses, ticks, k]
			)
		return
	for k in n:
		if not _room(w):
			return
		var ang := (ctx.angle + offsets[k]) & 4095
		var delay := 0
		if rng != null:  # Swirl right of the rings: the storm
			ang = rng.range_int(0, SimTick.ANGLE_UNITS - 1)
			delay = k * SWIRL_GAP_TICKS
		var dir := Kin.dir(ang)
		var from := ctx.origin + dir * edge
		var ticks := _clear_ticks(w, from, dir, speed, flight)
		ModifierAbilities.add_ring(
			w, from, r, spec, c, delay, [dir * speed, 0.0, 0, pulses, ticks, k]
		)


## Each ring's hit from the shot's `hit` (class doc): the card's share, and MULTI_PERMILLE of that when the launch is
## more than one ring or pulse. At least 1.
static func ring_damage(spec: AttackSpec, hit: int, rings: int, pulses: int) -> int:
	var d := hit
	if spec.ring_share_permille > 0:
		d = d * spec.ring_share_permille / 1000
	if rings * pulses > 1:
		d = d * MULTI_PERMILLE / 1000
	return maxi(1, d)


## The ticks a ring may fly from `from` along `dir` before its centre meets a wall (at most `flight`; at least 1).
static func _clear_ticks(w: World, from: Vector2, dir: Vector2, speed: float, flight: int) -> int:
	var to := from + dir * (speed * flight)
	var best := 1.0
	for k in w.walls_along(from, to, WALL_GAP_M):
		var s := Collide.sweep_vs_obb(from, to, WALL_GAP_M, w.walls[k])
		if s >= 0.0 and s < best:
			best = s
	return maxi(1, int(flight * best))


## One more ring fits under RINGS_MAX; the first that doesn't leaves the LIMIT event.
static func _room(w: World) -> bool:
	if w.ab.ring_pos.size() < RINGS_MAX:
		return true
	_capped(w)
	return false


## A swirled bolt's angle offsets (Attacks._bolts): each of `offsets` turned by a random angle within SWIRL_HALF.
static func swirl_offsets(w: World, offsets: PackedInt32Array) -> PackedInt32Array:
	var rng := stream(w)
	var out := PackedInt32Array()
	for off in offsets:
		out.append(off + rng.range_int(-SWIRL_HALF, SWIRL_HALF))
	return out


## `child`, a hook's or a cast's child built on `parent` (WandCompile), capped when `parent` is an order-rule ring and
## `child` a bolt with no cap of its own (RING_CHILD_ALIVE_MAX). Compile-time; returns `child`.
static func cap_child(parent: AttackSpec, child: AttackSpec) -> AttackSpec:
	if parent.ring_layout > 0 and child.form == AttackSpec.Form.BOLT and child.alive_max <= 0:
		child.alive_max = RING_CHILD_ALIVE_MAX
	return child


## The ring cap held a launch back: one LIMIT event for the launch.
static func _capped(w: World) -> void:
	var pid := w.actors.ids[0]
	var lim := w.emit_event(SimEvent.Kind.LIMIT, pid, pid, pid, w.player_pos())
	lim.effect_id = EFFECT_RING_CAP
	lim.amount = RINGS_MAX
	lim.ancestry = w.hook_chain.duplicate()
