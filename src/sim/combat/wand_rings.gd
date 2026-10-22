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
## - a Swirl RIGHT of the Ring (Ring · Swirl): the ring flies off in its own random direction (the only randomness:
##   the named stream below);
## - a Swirl LEFT of the Ring (Swirl · Ring): it flies along the aim, wobbling round its line WOBBLE_PERMILLE of its
##   radius out, SPIN_PER_TICK a tick. No draw: the spin is fixed.
## v0.9.0 AS (owner Q3 "Spiral/Swirl ride along": Twin, Halo, Ring and Backfire are Patterns, one at a time; "D45's
## Ring · Spread · Swirl storm goes"): no legal wand holds a count beside the Ring any more, so v0.8.0 AO's several
## ring shots, the pulses of a count left of the Ring (Spread · Ring), the storm's one-after-another rings and the
## spinning group are gone. A ring spec with a count (a lab's) still lays that many rings round the aim.
## Every ring deals the card's ring_share_permille of the shot's hit (the retune: a ring hits everything it passes, so
## it hits for less than the bolt it replaces), and hits each enemy once (ModifierAbilities._travel_step).
## The rings of one launch share one root (N3 retune; AO gave each its own), so a launch feeds an enemy's shock once
## and discharges it once, however many of its rings pass over it. A cast ring (a trigger's, a hook's: depth > 0)
## leaves from where it was cast, in its cast's root.
##
## Randomness only from a named stream (EI-05): "wand:swirl:<tick>:<launch>", derived from the run's seed for this one
## launch (no saved state; replays exactly); drawn only for a Swirl right of the rings and a swirled bolt. Caps (owner
## O9's frame budget, evidence/PERF.md): at most RINGS_MAX rings alive (every ring of every spec); a launch past it lays
## the rings that fit and leaves one LIMIT event (EFFECT_RING_CAP, amount: the cap); a bolt child of a ring at most
## RING_CHILD_ALIVE_MAX alive. Starting values.

## A ring's start size and growth (N3): START_PERMILLE of its radius, the whole after GROW_TICKS.
const START_PERMILLE := 450
const GROW_TICKS := 10
## Swirl left of the Ring: the ring wobbles round its line this far out (ring radii, per mille); the spin (1/4096
## turns a tick: a full turn in ~0.7 s).
const WOBBLE_PERMILLE := 500
const SPIN_PER_TICK := 96.0
## A swirled bolt's angle off the aim, at most (1/4096 turns: 60°).
const SWIRL_HALF := 683
const RINGS_MAX := 48
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


## Fires `spec`'s ring shots for the launch `ctx` (class doc). v0.9.0 AS: within the Gun's per-second shot budget
## (ShotCap.room: rings that don't fit merge into the ones that do, their damage kept).
static func launch(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var r := Attacks.area_radius(w, spec)
	var offsets := Attacks.shot_offsets(spec)
	var n := offsets.size()
	var own := ctx.depth == 0 and not ctx.repeat and not ctx.back  # the player's own shot (ShotCap)
	var fit := ShotCap.room(w, n, own)
	if fit <= 0:
		return
	var dmg := ring_damage(spec, ctx.damage)
	if fit < n:
		dmg = maxi(1, (dmg * n + fit / 2) / fit)
	var speed := spec.speed if spec.speed > 0.0 else SpecForms.BOLT_SPEED
	var flight := spec.ring_flight if spec.ring_flight > 0 else SpecForms.BOLT_TICKS
	var rng: RngStream = stream(w) if spec.swirl > 0 else null
	var root := ctx.root if ctx.root != 0 else w.take_root()  # one root for the launch's rings (class doc)
	var c := AttackContext.make(ctx.origin, ctx.angle, dmg, root, ctx.tags, ctx.effect_id)
	c.depth = ctx.depth
	c.proc_pct = ctx.proc_pct
	var edge := w.player.radius_m if ctx.depth == 0 else 0.0
	for j in fit:
		if not _room(w):
			return
		var k := (2 * j + 1) * n / (2 * fit)  # evenly picked, the centre first (all of them when they fit)
		var ang := (ctx.angle + offsets[k]) & 4095
		var orb := 0.0
		var a0 := 0
		if spec.swirl_group > 0:  # Swirl left of the Ring: it flies the aim, wobbling round its line
			ang = ctx.angle & 4095
			orb = r * WOBBLE_PERMILLE / 1000.0
			a0 = (ctx.angle + j * SimTick.ANGLE_UNITS / fit) & 4095
		elif rng != null:  # Swirl right of the Ring: it flies off its own random way
			ang = rng.range_int(0, SimTick.ANGLE_UNITS - 1)
		var dir := Kin.dir(ang)
		var from := ctx.origin + dir * edge
		var ticks := _clear_ticks(w, from, dir, speed, flight)
		ModifierAbilities.add_ring(w, from, r, spec, c, 0, [dir * speed, orb, a0, 1, ticks, j])
		if not own or j > 0:
			ShotCap.spend(w, 1)  # an extra (ShotCap)


## Each ring's hit from the shot's `hit` (class doc): the card's share of it. At least 1.
static func ring_damage(spec: AttackSpec, hit: int) -> int:
	var d := hit
	if spec.ring_share_permille > 0:
		d = d * spec.ring_share_permille / 1000
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
