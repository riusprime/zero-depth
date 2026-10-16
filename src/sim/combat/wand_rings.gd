class_name WandRings
extends RefCounted
## v0.8.0 AO (owner O37: "a modifier of the basic attack makes the attack … a circle of lightning, and then 3 attacks
## make a triple circle that covers way more does just a bit less damage than 3 regular ones but it shocks … and then
## … a swirl card that makes the circle go out randomly making it a 'storm'"; docs/roadmap/v0.8.0/evidence/
## ATTACK_ORDER.md): the order rule's rings (AttackSpec.ring_layout, set by a SHAPE card: WandCompile.take_in) and
## Swirl's thrown shots. Attacks._ring hands a ring_layout spec here; Attacks._bolts asks for a swirled bolt's angle.
##
## A root launch's centre is in front of the attacker along the aim, FRONT_PERMILLE of a ring's radius out (its near
## edge just in front of the hero: "a circle of lightning" where the shot would go); a cast ring (a trigger's, a hook's)
## centres where it was cast. A launch lays `count` rings evenly round its centre, LAYOUT_PERMILLE of a ring's radius
## out (one ring: on it), the first along the aim; each ring is `ring_pulses` concentric pulses PULSE_GAP_TICKS apart
## (the first at once). With more than one ring or pulse each
## deals ring_share_permille of the hit (the card's 850: three rings deal 2.55 hits, "a bit less than 3 regular ones").
## Each ring is its own root (ModifierAbilities.add_ring: a root launch's ring takes a fresh one), so each feeds its
## shock: three rings shock three times. swirl: each ring is thrown to its own random spot round the attacker,
## SWIRL_GAP_TICKS after the one before (the storm); swirl_group: the whole group is thrown to one spot. A swirled bolt
## leaves at a random angle within SWIRL_HALF of the aim.
##
## Randomness only from a named stream (EI-05): "wand:swirl:<tick>:<launch>", derived from the run's seed for this one
## launch (so it needs no saved state and replays exactly); no draw without a swirl. Caps (owner O9's frame budget,
## evidence/PERF.md): at most RINGS_MAX rings alive (ModifierAbilities' list, every ring of every spec); a launch past
## it lays the rings that fit and leaves one LIMIT event (EFFECT_RING_CAP, amount: the cap). Starting values.

const FRONT_PERMILLE := 1100
const LAYOUT_PERMILLE := 900
const PULSE_GAP_TICKS := 6
const SWIRL_GAP_TICKS := 4
## A thrown ring lands this far from the attacker, in ring radii (per mille), at random between the two.
const SPOT_MIN_PERMILLE := 700
const SPOT_MAX_PERMILLE := 2200
## A swirled bolt's angle off the aim, at most (1/4096 turns: 60°).
const SWIRL_HALF := 683
const RINGS_MAX := 48
## A ring's pulses, at most: a count past it left of the Ring is dropped (Spread at level 5 is 11 shots).
const PULSES_MAX := 5
## A bolt child of a ring (Split's shards, a trigger's cast, built right of the Ring): at most this many alive
## (AttackSpec.alive_max, PF2's cap). Both caps from the probe (evidence/ATTACK_ORDER.md): without them a level-5
## Spread · Ring · Split kept the 256-shot cap full and went over the frame budget.
const RING_CHILD_ALIVE_MAX := 64
const EFFECT_RING_CAP := &"wand_ring_cap"
const STREAM := "wand:swirl"


## The launch's stream (class doc): one per tick and launch.
static func stream(w: World) -> RngStream:
	return RngStream.derive(w.seed_value, "%s:%d:%d" % [STREAM, w.tick, w.launch_count])


## Lays `spec`'s rings for the launch `ctx` (class doc).
static func launch(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var n := maxi(1, spec.count)
	var pulses := clampi(spec.ring_pulses, 1, PULSES_MAX)
	var r := Attacks.area_radius(w, spec)
	var dmg := ctx.damage
	if n * pulses > 1 and spec.ring_share_permille > 0:
		dmg = maxi(1, dmg * spec.ring_share_permille / 1000)
	var rng: RngStream = null
	if spec.swirl > 0 or spec.swirl_group > 0:
		rng = stream(w)
	var centre := ctx.origin
	if ctx.depth == 0:
		centre = ctx.origin + Kin.dir(ctx.angle) * (r * FRONT_PERMILLE / 1000.0)
	if spec.swirl_group > 0:
		centre = _spot(rng, ctx.origin, r)
	var c := AttackContext.make(ctx.origin, ctx.angle, dmg, ctx.root, ctx.tags, ctx.effect_id)
	c.depth = ctx.depth
	c.proc_pct = ctx.proc_pct
	for k in n:
		var at := centre
		if spec.swirl > 0:
			at = _spot(rng, ctx.origin, r)
		elif n > 1:
			at = (
				centre
				+ (
					Kin.dir((ctx.angle + k * SimTick.ANGLE_UNITS / n) & 4095)
					* (r * LAYOUT_PERMILLE / 1000.0)
				)
			)
		var delay := k * SWIRL_GAP_TICKS if spec.swirl > 0 else 0
		for p in pulses:
			if w.ab.ring_pos.size() >= RINGS_MAX:
				_capped(w)
				return
			ModifierAbilities.add_ring(w, at, r, spec, c, delay + p * PULSE_GAP_TICKS)


## A random spot round `from`, SPOT_MIN..SPOT_MAX ring radii out.
static func _spot(rng: RngStream, from: Vector2, r: float) -> Vector2:
	var ang := rng.range_int(0, SimTick.ANGLE_UNITS - 1)
	var d := r * rng.range_int(SPOT_MIN_PERMILLE, SPOT_MAX_PERMILLE) / 1000.0
	return from + Kin.dir(ang) * d


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
