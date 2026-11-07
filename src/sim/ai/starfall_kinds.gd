class_name StarfallKinds
extends RefCounted
## v0.11.0 O13d (ENEMIES.md R9, R10; owner: "approved as written"): the Starfall signature enemies.
## - The Star Warper (R9, teleporter): it walks in like any melee kind; in range it marks a star on the floor
##   mark_offset_m beside the hero (square to its line to the hero: one side, or the other when a wall is there; behind
##   the hero when both are walled) and winds up for its telegraph (1 s, no random stretch). At the windup's end:
##   - the hero's centre within mark_radius_m of the star (standing on the mark) cancels the blink: it is stunned
##     stun_ticks (it stands in RECOVER, PICK_STUNNED, and attacks again only after its cooldown);
##   - else it blinks onto the star and strikes a disc of strike_radius_m round it (EnemyAi._resolve_horde). The hero
##     who stayed where the star was marked is inside it (validated: radius over the offset); stepping off dodges it.
##   The star and its disc are star_disc(), the one shape the strike hits and the telegraph draws (EI-07).
## - The Gravity Node (R10, area control, stationary, floating): it holds the spot it spawned on (anchor: lock_x/y),
##   never attacks, and floor hazards never reach it (EnemyTable.flies). Every projectile within pull_radius_m of a node
##   turns toward it each tick (bend: up to pull_accel at its centre, none at the reach, the speed kept): the hero's
##   and the enemies', the bosses' fireballs too. bend() is the one rule: World's projectile sweep calls it, and the
##   Needle's telegraph lanes walk it (bent_lanes), so the drawn path is the flown one.
##   Per Gun form (the projectile sweep runs bend after ProjectileMoves.steer, so each form's own steering comes first):
##   orbs, Twin, Spread, Seekers (they still home: the node tugs on top), Void and Wave shots (their aura and band ride
##   the bent path), Lance balls, Glaive discs (the way back still homes on the hero), Wisps' shots, Ricochet: all bend.
##   A projectile still orbiting the hero (Orbit, a Glaive's Orbit lap, a Seekers dart's lap) or waiting as a Mine (no
##   speed) is not bent until it leaves. The Laser's lance and the Sniper's line are instant paths (no flight, no tick
##   in between): they are not bent (Laser.trace, EnemyAi.snipe_lanes stay straight).
## Pure (EI-02): + - * / and sqrt only (Kin), no randomness (EI-05), the one clock (EI-03). No state of its own: the
## stars and stuns live in the actor columns (lock_x/y, pick), hashed with the AI.

## ActorStore.pick of a Star Warper stunned by a cancelled blink (0 otherwise).
const PICK_STUNNED := 2
## A projectile this near a node's centre is not turned (it passes through the middle).
const CORE_M := 0.05
## A bent telegraph path is drawn as one lane per this many ticks of flight (bent_lanes).
const SEGMENT_TICKS := 4


static func is_warper(kind: int) -> bool:
	return kind == ActorStore.Kind.STAR_WARPER


static func is_node(kind: int) -> bool:
	return kind == ActorStore.Kind.GRAVITY_NODE


# --- The Star Warper ---------------------------------------------------------------------------------------------
## Where Warper i's star lands as its windup starts: mark_offset_m beside the hero, square to the Warper's line to it,
## on the side its id picks (the other when a wall is in the way; behind the hero when both are).
static func mark_spot(w: World, i: int) -> Vector2:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var hero := w.player_pos()
	var line := Kin.angle_of(hero - a.pos(i))
	var side := 1024 if a.ids[i] % 2 == 0 else -1024
	for s: int in [side, -side]:
		var ang := (line + s) & 4095
		if EnemyAi.clear_run(w, hero, ang, t.mark_offset_m, t.radius_m) >= t.mark_offset_m - 0.001:
			return hero + Kin.dir(ang) * t.mark_offset_m
	var back := (line + 2048) & 4095
	return hero + Kin.dir(back) * EnemyAi.clear_run(w, hero, back, t.mark_offset_m, t.radius_m)


## [centre, radius] of Warper i's star strike (its star is the centre; lock_x/y while it winds up and strikes).
static func star_disc(w: World, i: int) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), w.enemy_table(a.kinds[i]).strike_radius_m]


## Whether the hero stands on Warper i's star (its centre within mark_radius_m).
static func on_star(w: World, i: int) -> bool:
	var a := w.actors
	var star := Vector2(a.lock_x[i], a.lock_y[i])
	return Kin.length(w.player_pos() - star) <= w.enemy_table(a.kinds[i]).mark_radius_m


## At the end of Warper i's windup: the hero on the star cancels the blink and stuns it (true; RECOVER for stun_ticks,
## PICK_STUNNED); false lets it blink.
static func cancel(w: World, i: int) -> bool:
	if w.player_dead() or not on_star(w, i):
		return false
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	EnemyAi.enter_state(a, i, EnemyAi.State.RECOVER)
	a.state_t[i] = t.recover_ticks - t.stun_ticks  # RECOVER ends at recover_ticks: stun_ticks from now
	a.pick[i] = PICK_STUNNED
	return true


## Whether Warper i is stunned now (a cancelled blink).
static func stunned(w: World, i: int) -> bool:
	var a := w.actors
	return (
		is_warper(a.kinds[i]) and a.pick[i] == PICK_STUNNED and a.state[i] == EnemyAi.State.RECOVER
	)


## Warper i blinks onto its star (its strike's tick): it stands there, facing the hero. Returns the star.
static func blink(w: World, i: int) -> Vector2:
	var a := w.actors
	var star := Vector2(a.lock_x[i], a.lock_y[i])
	a.set_pos(i, star)
	a.facing[i] = Kin.angle_of(w.player_pos() - star)
	return star


# --- The Gravity Node --------------------------------------------------------------------------------------------
## The live nodes now: [x, y, reach, pull] per node, in actor order (empty: none, so the sweep skips bend).
static func nodes(w: World) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var a := w.actors
	for i in range(1, a.size()):
		if a.kinds[i] != ActorStore.Kind.GRAVITY_NODE or a.dead[i] == 1:
			continue
		var t := w.enemy_table(a.kinds[i])
		if t == null:
			continue
		out.append_array(
			PackedFloat32Array([a.pos_x[i], a.pos_y[i], t.pull_radius_m, t.pull_accel])
		)
	return out


## The one rule: velocity `v` of a projectile at `p` after this tick's pull of `ns` (nodes()): each node within its
## reach adds pull × (1 − distance / reach) toward its centre, then the sum is set back to |v| (it turns, never
## speeds up or slows). Outside every reach, `v` unchanged.
static func bend(ns: PackedFloat32Array, p: Vector2, v: Vector2) -> Vector2:
	var speed := Kin.length(v)
	if speed <= 0.0:
		return v
	var out := v
	var pulled := false
	for k in range(0, ns.size(), 4):
		var to := Vector2(ns[k], ns[k + 1]) - p
		var d := Kin.length(to)
		var reach := ns[k + 2]
		if d >= reach or d <= CORE_M:
			continue
		out += to * (ns[k + 3] * (1.0 - d / reach) / d)
		pulled = true
	if not pulled:
		return v
	var n := Kin.length(out)
	return v if n <= 0.0 else out * (speed / n)


## World's projectile sweep, before projectile pi moves: the nodes `ns` bend it (the sweep skips one its form held
## itself this tick: ProjectileMoves.steer).
static func bend_projectile(w: World, pi: int, ns: PackedFloat32Array) -> void:
	var p := w.projectiles
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var b := bend(ns, Vector2(p.pos_x[pi], p.pos_y[pi]), v)
	if b != v:
		p.vel_x[pi] = b.x
		p.vel_y[pi] = b.y


## The path a shot fired at `from` with velocity `v` (per tick) flies for `life` ticks under the nodes now (bend,
## tick by tick, as the sweep moves it), as lanes of half-width `r` every SEGMENT_TICKS, cut at the first wall.
static func bent_lanes(w: World, from: Vector2, v: Vector2, life: int, r: float) -> Array[Obb]:
	var ns := nodes(w)
	var out: Array[Obb] = []
	var at := from
	var vel := v
	var left := life
	while left > 0:
		var start := at
		for _k in mini(SEGMENT_TICKS, left):
			vel = bend(ns, at, vel)
			at += vel
		left -= SEGMENT_TICKS
		var seg := at - start
		var seg_len := Kin.length(seg)
		if seg_len <= 0.0:
			break
		var ang := Kin.angle_of(seg)
		var run := EnemyAi.clear_run(w, start, ang, seg_len, r)
		out.append(AttackShapes.lane(start, ang, maxf(run, 0.01), r))
		if run < seg_len - 0.001:
			break
	return out


## Node i holds its spot (EnemyAi.move): its first move takes the spot it stands on as its anchor (lock_x/y, lock_len 1
## once taken); after that it goes back onto the anchor if the crowd pushed it.
static func hold(w: World, i: int) -> void:
	var a := w.actors
	if a.lock_len[i] <= 0.0:
		a.lock_x[i] = a.pos_x[i]
		a.lock_y[i] = a.pos_y[i]
		a.lock_len[i] = 1.0
		return
	a.set_pos(i, Vector2(a.lock_x[i], a.lock_y[i]))
