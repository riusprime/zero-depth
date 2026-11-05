class_name Starfall
extends RefCounted
## v0.10.5 W3-P10e (owner W7: "Starfall ... evolves into a every 5 attack a meteor falls from the sky into the
## enemies"; Q5 "fire lv3 ok"; docs/roadmap/v0.10.5/W3_W7_LOOP_POWER_G1.md rows C4, C4b, V1, V2): the Starfall
## Constellation (Constellations.STARFALL). The numbers are the constants below, in one place.
## - Starfall: every STAR_EVERY-th crit of the hero drops a star on the nearest other living enemy (not the crit's
##   target; ties: lowest index) for STAR_PERMILLE of the amount that crit dealt (W3-P10k: before its target's own
##   multipliers, Damage.hit). The star is a player hit that was
##   already scaled (Damage.hit's splash path): it never rolls a crit and never counts toward the five (no recursion).
##   No other enemy: nothing. World.starfall_crits counts the crits.
## - Meteor (Starfall held AND the Fire card, ember_core, at Lv >= METEOR_FIRE_LEVEL): the star is replaced. Every
##   METEOR_EVERY-th root attack the hero launches (a Blade swing's start, a Gun shot's release: PlayerKit; never a
##   repeat, a child or a hook) calls a meteor on the enemy within METEOR_RANGE_M of the hero that has the most other
##   enemies within METEOR_RADIUS_M (ties: lowest index). It lands METEOR_DELAY_TICKS later where that enemy stood at
##   launch and hits every enemy within METEOR_RADIUS_M for METEOR_PERMILLE of the attack's base hit (a normal player
##   hit each: its own crit roll, the damage stat), and burns what it hit. World.meteor_attacks counts the attacks;
##   World.meteors lists the pending ones, METEOR_FIELDS ints each: [land tick, base hit, x mm, y mm].
## Events for the view (it reads, never writes): STAR (pos = the target, target_id), METEOR_LAUNCH (pos = where it
## lands, amount = ticks to land), METEOR_LAND (pos, amount = radius mm). Integer maths and the sim clock only; the
## counters and the pending list are saved, and hashed once any leaves 0 / empty.

const STAR_EVERY := 5
const STAR_PERMILLE := 1000
const METEOR_EVERY := 5
const METEOR_RANGE_M := 8.0
const METEOR_RADIUS_M := 2.5
const METEOR_PERMILLE := 3000
const METEOR_DELAY_TICKS := 24
const METEOR_FIELDS := 4
const METEOR_FIRE_LEVEL := 3


## The run holds Starfall.
static func held(w: World) -> bool:
	return Constellations.has(w, Constellations.STARFALL)


## Starfall's star is Meteor now: Fire (ember_core) held at Lv >= METEOR_FIRE_LEVEL.
static func meteor_on(w: World) -> bool:
	return (
		held(w)
		and ElementLevelsFsf.held(w, ElementLevelsFsf.FIRE)
		and ElementLevelsFsf.level(w, ElementLevelsFsf.FIRE) >= METEOR_FIRE_LEVEL
	)


## The hero's crit of `dealt` on actor `target` landed (Damage.hit): every STAR_EVERY-th calls a star.
static func on_crit(w: World, target: int, dealt: int, root: int) -> void:
	if not held(w) or meteor_on(w):
		return
	w.starfall_crits += 1
	if w.starfall_crits % STAR_EVERY != 0:
		return
	var a := w.actors
	var from := a.pos(target)
	var best := -1
	var best_d := INF
	for i in range(1, a.size()):
		if i == target or a.dead[i] == 1 or a.teams[i] == ActorStore.TEAM_PLAYER:
			continue
		var d := (a.pos(i) - from).length_squared()
		if d < best_d:  # ascending index, strict: a tie keeps the lowest
			best_d = d
			best = i
	if best < 0:
		return
	var pid := a.ids[0]
	var e := w.emit_event(SimEvent.Kind.STAR, pid, pid, a.ids[best], a.pos(best))
	e.root_id = root
	e.amount = dealt
	Damage.hit(
		w,
		best,
		dealt * STAR_PERMILLE / 1000,
		pid,
		pid,
		root,
		SimEvent.TAG_AREA,
		from,
		a.pos(best),
		SimEvent.EFFECT_STAR
	)


## The hero launched a root attack whose base hit is `base` (PlayerKit): every METEOR_EVERY-th calls a meteor.
static func on_root_attack(w: World, base: int) -> void:
	if not meteor_on(w):
		return
	w.meteor_attacks += 1
	if w.meteor_attacks % METEOR_EVERY != 0:
		return
	var a := w.actors
	var me := w.player_pos()
	var near := w.enemies_near(me, METEOR_RANGE_M)
	near.sort()
	var best := -1
	var best_n := -1
	for i in near:
		if Kin.length(a.pos(i) - me) > METEOR_RANGE_M:
			continue
		var n := w.enemies_near(a.pos(i), METEOR_RADIUS_M).size() - 1
		if n > best_n:  # ascending index, strict: a tie keeps the lowest
			best_n = n
			best = i
	if best < 0:
		return
	var at := a.pos(best)
	w.meteors.append(w.tick + METEOR_DELAY_TICKS)
	w.meteors.append(base)
	w.meteors.append(int(round(at.x * 1000.0)))
	w.meteors.append(int(round(at.y * 1000.0)))
	var pid := a.ids[0]
	var e := w.emit_event(SimEvent.Kind.METEOR_LAUNCH, pid, pid, pid, at)
	e.amount = METEOR_DELAY_TICKS


## Lands the meteors due this tick (World.step, after the hero's abilities).
static func advance(w: World) -> void:
	if w.meteors.is_empty():
		return
	var keep := PackedInt32Array()
	var due: Array[PackedInt32Array] = []
	for k in range(0, w.meteors.size(), METEOR_FIELDS):
		var row := w.meteors.slice(k, k + METEOR_FIELDS)
		if row[0] <= w.tick:
			due.append(row)
		else:
			keep.append_array(row)
	w.meteors = keep
	for row in due:
		_land(w, row[1], Vector2(row[2] / 1000.0, row[3] / 1000.0))


static func _land(w: World, base: int, at: Vector2) -> void:
	var a := w.actors
	var pid := a.ids[0]
	var root := w.take_root()
	var e := w.emit_event(SimEvent.Kind.METEOR_LAND, pid, pid, pid, at)
	e.root_id = root
	e.amount = int(round(METEOR_RADIUS_M * 1000.0))
	var hit := w.enemies_near(at, METEOR_RADIUS_M)
	hit.sort()
	for i in hit:
		if a.dead[i] == 1:
			continue
		Damage.hit(
			w,
			i,
			base * METEOR_PERMILLE / 1000,
			pid,
			pid,
			root,
			SimEvent.TAG_AREA,
			at,
			a.pos(i),
			SimEvent.EFFECT_METEOR
		)
		Engines.add_burn(w, i, 1, root, SimEvent.EFFECT_METEOR)
