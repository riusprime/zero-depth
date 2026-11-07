class_name RuinsRocks
extends RefCounted
## v0.11.0 O13b (PLAN M3; docs/roadmap/v0.11.0/ENEMIES.md R1-R4, approved as written 2026-11-07; owner Q22, Q23): the
## Ruins' and the Night Rocks' signature enemies. Each is a small state machine on EnemyAi's states (SPAWN, MOVE,
## WINDUP, ACTIVE, RECOVER) in ActorStore's columns; the walk between attacks is EnemyAi's plan (the Weaver and the
## Thrower keep a distance band: EnemyAi.KEEP_AWAY). Numbers are each one's EnemyTable (RuinsRocksCompiler, from
## data/enemies/<id>.tres; starting values). What they leave on the floor is World.ruins_rocks (RuinsRocksState).
## Every hit's area comes from one function here, which the view also draws (EI-07): cable_lane, dart_lane,
## slam_disc, landing_disc. Pure: no stream is drawn.
## - R1 Wire Weaver (Ruins): within attack_range_m and in sight, with fewer than max_cables cables, it marks a cable
##   across your way (WINDUP: the line on the ground, the posts sparking where they go in): centred CABLE_AT_PERMILLE of
##   the way to you (at least CABLE_MIN_M from it), square to that line, up to reach_m long (each end cut short by
##   walls). Then two posts stand at its ends (actors of their own, WIRE_POST: post_hp HP, live at once) and the cable
##   between them is live: it blocks the hero's way (block_hero: pushed back to the side it came from; shots and the
##   enemies pass) and a touch hurts for its damage at most every cable_period_ticks (CABLE_EFFECT, no actor's attack:
##   the recap's CAUSE_KEY). Breaking either post (or killing the Weaver) drops the cable, and its other post goes.
## - R2 Scrap Hound (Ruins): fast; circles the hero circle_m away (its side by its id). Only while the hero attacks
##   (the primary or the shot held, or a swing running) and the hound stands within rear_half_arc of the hero's back
##   (the opposite of its aim) does it turn in (WINDUP: its eyes flash; it tracks you until HOUND_COMMIT_TICKS before),
##   then darts (charge_speed, to HOUND_PAST_M past you, at most charge_distance_m) and bites once on contact. Any hit
##   on it during the turn-in or the dart stops it (a yelp: RECOVER with YELPED, stagger_ticks long).
## - R3 Rock Lurker (Night Rocks): from its arrival it waits as a boulder (a wall of hide_half_m, inside its body, so
##   it is cover for both sides: the enemies' shots and sight stop on it, the hero's shots meet its body and hurt it).
##   Its cracks glow faintly and it rumbles when you are within rumble_m (the view's). When the hero comes within wake_m
##   of its body it bursts out with its slam (slam_disc, on the ground, windup_ticks); a hit wakes it too (it comes out
##   walking). Out, it walks in and slams within attack_range_m.
## - R4 Stone Thrower (Night Rocks): from its band, in sight and within attack_range_m, it lifts a rock (WINDUP,
##   windup_ticks, 0.8 s) and throws it at where the hero stood when it began; the landing's ring (landing_disc) shows
##   from the lift to the landing, flight_ticks after the throw. Landing, it hurts the hero in the ring, then stands as
##   a rock of cover (a wall, as the rubble) for rock_ticks, at most max_rocks on a floor (the oldest goes first); a
##   spot on the hero, in a wall or out of every room is skipped (the rock shatters).

const KINDS: Array[int] = [
	ActorStore.Kind.WIRE_WEAVER,
	ActorStore.Kind.WIRE_POST,
	ActorStore.Kind.SCRAP_HOUND,
	ActorStore.Kind.ROCK_LURKER,
	ActorStore.Kind.STONE_THROWER,
]
## A cable's touch (Damage.hit effect), its World.killer_attack and its recap line.
const CABLE_EFFECT := &"wire_cable"
const KILL_CAUSE := -7013
const CAUSE_KEY := &"CAUSE_WIRE_CABLE"
## A touch counts within this of contact (block_hero leaves the hero exactly at the cable's edge).
const CONTACT_SLOP_M := 0.05
const CABLE_AT_PERMILLE := 500
const CABLE_MIN_M := 1.5
## A cable shorter than this once walls cut its ends is not planted (the Weaver waits CABLE_RETRY_TICKS).
const CABLE_SHORTEST_M := 1.5
const CABLE_RETRY_TICKS := 30
const HOUND_COMMIT_TICKS := 12
const HOUND_PAST_M := 1.0
## Farther than circle_m + this, the hound walks the plan (the flow field round walls) instead of circling.
const HOUND_FAR_M := 3.0
## How fast the hound closes on its circle (m of distance error for a full radial step).
const HOUND_CLOSE_M := 1.5
## A hound stopped by a hit (ActorStore.fire_cd while it recovers), and a dart that bit (fire_cd).
const BIT := 1
const YELPED := 2
## ActorStore.pick of a Lurker that is out (0: still waiting as a boulder).
const OUT := 1
## A placed wall (a rock, a hide) keeps this much room from the hero's body.
const HERO_GAP_M := 0.3


static func takes(kind: int) -> bool:
	return kind in KINDS


## The Wire Weaver `weaver`'s post: its HP and radius, standing (no speed, no attack, no shards, no matchup).
static func post_table(weaver: EnemyTable) -> EnemyTable:
	var t := EnemyTable.new()
	t.kind = ActorStore.Kind.WIRE_POST
	t.name_key = &"ENEMY_WIRE_POST"
	t.hp = weaver.post_hp
	t.radius_m = weaver.post_radius_m
	t.speed = 0.0
	return t


## Phase 3 (EnemyAi.think, after its clocks ran): one signature enemy's state machine.
static func think(w: World, i: int, t: EnemyTable, planning: bool) -> void:
	var a := w.actors
	var k := a.kinds[i]
	if k == ActorStore.Kind.WIRE_POST:
		return
	if a.state[i] == EnemyAi.State.SPAWN:
		if a.state_t[i] >= w.tuning.spawn_in_ticks:
			EnemyAi.enter_state(a, i, EnemyAi.State.MOVE)
			if k == ActorStore.Kind.ROCK_LURKER:
				_hide(w, i, t)
		return
	match k:
		ActorStore.Kind.WIRE_WEAVER:
			_weaver_think(w, i, t, planning)
		ActorStore.Kind.SCRAP_HOUND:
			_hound_think(w, i, t)
		ActorStore.Kind.ROCK_LURKER:
			_lurker_think(w, i, t, planning)
		ActorStore.Kind.STONE_THROWER:
			_thrower_think(w, i, t, planning)


## The windup, active and recovery steps every signature shares (the Hound's are its own).
static func _run_attack(w: World, i: int, t: EnemyTable, active_ticks: int) -> void:
	var a := w.actors
	match a.state[i]:
		EnemyAi.State.WINDUP:
			if a.state_t[i] >= a.windup[i]:
				EnemyAi.enter_state(a, i, EnemyAi.State.ACTIVE)
				if a.kinds[i] == ActorStore.Kind.WIRE_WEAVER:
					_plant(w, i, t)
		EnemyAi.State.ACTIVE:
			if a.state_t[i] >= active_ticks:
				EnemyAi.enter_state(a, i, EnemyAi.State.RECOVER)
		EnemyAi.State.RECOVER:
			if a.state_t[i] >= t.recover_ticks:
				EnemyAi.enter_state(a, i, EnemyAi.State.MOVE)
				a.cd[i] = t.cooldown_ticks


static func _begin(w: World, i: int, t: EnemyTable, at: Vector2, aim: int) -> void:
	var a := w.actors
	EnemyAi.enter_state(a, i, EnemyAi.State.WINDUP)
	a.windup[i] = t.windup_ticks
	a.lock_x[i] = at.x
	a.lock_y[i] = at.y
	a.lock_a[i] = aim
	a.facing[i] = Kin.angle_of(w.player_pos() - a.pos(i))


static func _may_start(w: World, i: int, t: EnemyTable, dist: float) -> bool:
	return (
		not w.player_dead()
		and w.actors.cd[i] == 0
		and dist <= t.attack_range_m
		and EnemyAi.sees_player(w, w.actors.pos(i))
	)


# --- R1 Wire Weaver --------------------------------------------------------------------------------------------
static func _weaver_think(w: World, i: int, t: EnemyTable, planning: bool) -> void:
	var a := w.actors
	if a.state[i] != EnemyAi.State.MOVE:
		_run_attack(w, i, t, t.active_ticks)
		return
	var to := w.player_pos() - a.pos(i)
	if planning:
		a.facing[i] = Kin.angle_of(to)
	if not _may_start(w, i, t, Kin.length(to)) or w.ruins_rocks.cables_of(a.ids[i]) >= t.max_cables:
		return
	if not _aim_cable(w, i, t):
		a.cd[i] = CABLE_RETRY_TICKS
		return
	var at := Vector2(a.lock_x[i], a.lock_y[i])
	var half := a.lock_len[i]
	_begin(w, i, t, at, a.lock_a[i])
	a.lock_len[i] = half


## Where Weaver i's next cable goes (lock_x/lock_y its centre, lock_a its way, lock_len its half length); false when
## the walls leave too little room.
static func _aim_cable(w: World, i: int, t: EnemyTable) -> bool:
	var a := w.actors
	var e := a.pos(i)
	var to := w.player_pos() - e
	var dist := Kin.length(to)
	if dist <= 0.001:
		return false
	var u := to / dist
	var c := e + u * minf(dist, maxf(CABLE_MIN_M, dist * CABLE_AT_PERMILLE / 1000.0))
	if not EnemyAi.clear_of_walls(w, c, t.post_radius_m):
		return false
	var ang := (Kin.angle_of(u) + 1024) & 4095
	var half := t.reach_m * 0.5
	var r1 := EnemyAi.clear_run(w, c, ang, half, t.post_radius_m)
	var r2 := EnemyAi.clear_run(w, c, (ang + 2048) & 4095, half, t.post_radius_m)
	if r1 + r2 < CABLE_SHORTEST_M:
		return false
	var mid := c + Kin.dir(ang) * ((r1 - r2) * 0.5)
	a.lock_x[i] = mid.x
	a.lock_y[i] = mid.y
	a.lock_a[i] = ang
	a.lock_len[i] = (r1 + r2) * 0.5
	return true


## The line Weaver i's cable will take while it winds up (the posts at its ends).
static func cable_lane(w: World, i: int) -> Obb:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var half := a.lock_len[i]
	return Obb.make(Vector2(a.lock_x[i], a.lock_y[i]), Vector2(half, t.lane_half_m), a.lock_a[i])


## The two posts go in at the cable's ends, and the cable between them goes live.
static func _plant(w: World, i: int, t: EnemyTable) -> void:
	var a := w.actors
	if w.enemy_table(ActorStore.Kind.WIRE_POST) == null:
		w.set_enemy_tables([post_table(t)])
	var c := Vector2(a.lock_x[i], a.lock_y[i])
	var d := Kin.dir(a.lock_a[i]) * a.lock_len[i]
	var ids := PackedInt32Array()
	for q in [c + d, c - d]:
		var id := w.add_enemy(ActorStore.Kind.WIRE_POST, q)
		var j := a.size() - 1
		a.invuln[j] = 0
		a.state[j] = EnemyAi.State.MOVE
		a.power[j] = a.power[i]
		ids.append(id)
	w.ruins_rocks.add_cable(
		ids[0],
		ids[1],
		a.ids[i],
		w.tick,
		EnemyAi.powered(w, i, t.damage),
		t.cable_period_ticks,
		t.lane_half_m
	)


## Cable k's two ends (where its posts stand now), or empty while either is gone.
static func cable_ends(w: World, k: int) -> PackedVector2Array:
	var s := w.ruins_rocks
	var ja := w.actors.index_of(s.cable_a[k])
	var jb := w.actors.index_of(s.cable_b[k])
	if ja < 0 or jb < 0 or w.actors.dead[ja] == 1 or w.actors.dead[jb] == 1:
		return PackedVector2Array()
	return PackedVector2Array([w.actors.pos(ja), w.actors.pos(jb)])


## The distance from `p` to cable k's line (INF while it is down).
static func cable_distance(w: World, k: int, p: Vector2) -> float:
	var ends := cable_ends(w, k)
	if ends.is_empty():
		return INF
	var ab := ends[1] - ends[0]
	var l2 := ab.dot(ab)
	var u := 0.0 if l2 <= 0.000001 else clampf((p - ends[0]).dot(ab) / l2, 0.0, 1.0)
	return Kin.length(p - (ends[0] + ab * u))


## Phase 5 (World._move_and_collide, after the walls and bodies): a live cable is a wall to the hero alone: one it
## crosses pushes it back to the side it was on at `from` (the tick's start), then the walls near it resolve again.
## The ends are the posts' own bodies (collision as any enemy's).
static func block_hero(w: World, from: Vector2) -> void:
	var s := w.ruins_rocks
	if s.cable_count() == 0 or w.player_dead():
		return
	var p := w.player_pos()
	var r := w.player.radius_m
	var moved := false
	for k in s.cable_count():
		var ends := cable_ends(w, k)
		if ends.is_empty():
			continue
		var ab := ends[1] - ends[0]
		var l := Kin.length(ab)
		if l < 0.001:
			continue
		var u := ab / l
		var n := Vector2(-u.y, u.x)
		var along := (p - ends[0]).dot(u)
		if along <= 0.0 or along >= l:
			continue
		var sd := (p - ends[0]).dot(n)
		var reach := r + s.cable_half[k]
		if absf(sd) >= reach:
			continue
		var side := (from - ends[0]).dot(n)
		var way := 1.0 if side > 0.0 or (side == 0.0 and sd >= 0.0) else -1.0
		p += n * (way * reach - sd)
		moved = true
	if not moved:
		return
	for k in w.walls_near(Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0)):
		p += Collide.circle_vs_obb(p, r, w.walls[k])
	w.actors.set_pos(0, p)


# --- R2 Scrap Hound --------------------------------------------------------------------------------------------
## Whether the hero is attacking now: its primary or its shot held, or a swing running.
static func hero_attacking(w: World) -> bool:
	return (w.held_buttons & (InputFrame.PRIMARY | InputFrame.SHOOT)) != 0 or w.swing_t > 0


## Whether Hound i stands behind the hero: within its rear_half_arc of the way opposite the hero's aim.
static func behind_hero(w: World, i: int) -> bool:
	var t := w.enemy_table(w.actors.kinds[i])
	var back := (w.actors.facing[0] + 2048) & 4095
	var at := Kin.angle_of(w.actors.pos(i) - w.player_pos())
	return Kin.angle_diff(at, back) <= t.rear_half_arc


static func _hound_think(w: World, i: int, t: EnemyTable) -> void:
	var a := w.actors
	var to := w.player_pos() - a.pos(i)
	var dist := Kin.length(to)
	match a.state[i]:
		EnemyAi.State.MOVE:
			a.facing[i] = Kin.angle_of(to)
			if _may_start(w, i, t, dist) and hero_attacking(w) and behind_hero(w, i):
				_begin(w, i, t, a.pos(i), Kin.angle_of(to))
				a.pick[i] = a.hp[i]
				a.fire_cd[i] = 0
		EnemyAi.State.WINDUP:
			if a.hp[i] < a.pick[i]:
				_yelp(a, i)
				return
			if a.state_t[i] < a.windup[i] - HOUND_COMMIT_TICKS and not w.player_dead():
				a.lock_a[i] = Kin.angle_of(to)
				a.facing[i] = a.lock_a[i]
			if a.state_t[i] >= a.windup[i]:
				EnemyAi.enter_state(a, i, EnemyAi.State.ACTIVE)
				a.lock_len[i] = _dart_run(w, i, t)
		EnemyAi.State.ACTIVE:
			if a.hp[i] < a.pick[i]:
				_yelp(a, i)
			elif a.lock_len[i] <= 0.0 or a.fire_cd[i] == BIT:
				EnemyAi.enter_state(a, i, EnemyAi.State.RECOVER)
		EnemyAi.State.RECOVER:
			var wait := t.stagger_ticks if a.fire_cd[i] == YELPED else t.recover_ticks
			if a.state_t[i] >= wait:
				EnemyAi.enter_state(a, i, EnemyAi.State.MOVE)
				a.cd[i] = t.cooldown_ticks
				a.fire_cd[i] = 0


## A hit stops Hound i's turn-in or dart: it yelps and staggers.
static func _yelp(a: ActorStore, i: int) -> void:
	EnemyAi.enter_state(a, i, EnemyAi.State.RECOVER)
	a.fire_cd[i] = YELPED
	a.lock_len[i] = 0.0


## Whether Hound i was stopped by a hit (the view's yelp; the stagger).
static func yelped(w: World, i: int) -> bool:
	return (
		w.actors.kinds[i] == ActorStore.Kind.SCRAP_HOUND
		and w.actors.state[i] == EnemyAi.State.RECOVER
		and w.actors.fire_cd[i] == YELPED
	)


## How far Hound i's dart runs along lock_a: to HOUND_PAST_M past the hero, at most charge_distance_m, cut by walls.
static func _dart_run(w: World, i: int, t: EnemyTable) -> float:
	var a := w.actors
	var want := minf(t.charge_distance_m, Kin.length(w.player_pos() - a.pos(i)) + HOUND_PAST_M)
	return EnemyAi.clear_run(w, a.pos(i), a.lock_a[i], want, t.radius_m)


## The lane Hound i darts down: its turn-in's (from where it stands) or the dart's rest.
static func dart_lane(w: World, i: int) -> Obb:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var run := a.lock_len[i] if a.state[i] == EnemyAi.State.ACTIVE else _dart_run(w, i, t)
	return AttackShapes.lane(a.pos(i), a.lock_a[i], maxf(run, 0.01) + t.radius_m, t.radius_m)


static func _hound_move(w: World, i: int, t: EnemyTable, slow: float) -> void:
	var a := w.actors
	var at := a.pos(i)
	if a.state[i] == EnemyAi.State.ACTIVE:
		if a.lock_len[i] > 0.0:
			var step := minf(t.charge_speed * slow, a.lock_len[i])
			a.lock_len[i] -= step
			a.set_pos(i, at + Kin.dir(a.lock_a[i]) * step)
		return
	if a.state[i] != EnemyAi.State.MOVE or w.player_dead():
		return
	var to := w.player_pos() - at
	var dist := Kin.length(to)
	if dist <= 0.001:
		return
	var dir := Vector2(a.plan_x[i], a.plan_y[i])
	if dist <= t.circle_m + HOUND_FAR_M and a.plan_block[i] == 0:
		var u := to / dist
		var side := 1.0 if a.ids[i] % 2 == 0 else -1.0
		var radial := u * clampf((dist - t.circle_m) / HOUND_CLOSE_M, -1.0, 1.0)
		var turn := Vector2(-u.y, u.x) * side + radial
		var l := Kin.length(turn)
		dir = EnemyAi.steer(w, at, turn / l if l > 0.0001 else u, t.radius_m)
	if dir != Vector2.ZERO:
		a.set_pos(i, at + dir * (t.speed * slow))


# --- R3 Rock Lurker --------------------------------------------------------------------------------------------
## Whether actor i is a Rock Lurker still waiting as a boulder (its wall stands; its body passes through it).
static func hidden(w: World, i: int) -> bool:
	return (
		w.actors.kinds[i] == ActorStore.Kind.ROCK_LURKER
		and w.ruins_rocks.hide_of(w.actors.ids[i]) >= 0
	)


## Whether a waiting Lurker i hears the hero (within rumble_m of its body: the view's rumble and shake).
static func rumbling(w: World, i: int) -> bool:
	if not hidden(w, i):
		return false
	var t := w.enemy_table(w.actors.kinds[i])
	return Kin.length(w.player_pos() - w.actors.pos(i)) <= t.rumble_m + w.actors.radius[i]


## Lurker i settles as a boulder where it arrived: its wall goes up (unless the hero, a wall or a doorway is there:
## then it comes out at once).
static func _hide(w: World, i: int, t: EnemyTable) -> void:
	var a := w.actors
	var q := a.pos(i)
	if not _fits(w, q, t.hide_half_m):
		a.pick[i] = OUT
		return
	a.pick[i] = 0
	w.ruins_rocks.add_hide(a.ids[i], q, t.hide_half_m)
	w.add_barrier(w.ruins_rocks.hide_obb(w.ruins_rocks.hide_count() - 1))


static func _unhide(w: World, i: int) -> void:
	var s := w.ruins_rocks
	var k := s.hide_of(w.actors.ids[i])
	w.actors.pick[i] = OUT
	if k < 0:
		return
	w.remove_barriers([s.hide_obb(k)])
	s.remove_hide(k)


static func _lurker_think(w: World, i: int, t: EnemyTable, planning: bool) -> void:
	var a := w.actors
	if a.state[i] != EnemyAi.State.MOVE:
		_run_attack(w, i, t, t.active_ticks)
		return
	var to := w.player_pos() - a.pos(i)
	var dist := Kin.length(to)
	if hidden(w, i):
		var near := not w.player_dead() and dist - a.radius[i] - w.player.radius_m <= t.wake_m
		if near or a.hp[i] < a.max_hp[i]:
			_unhide(w, i)
			if near:
				_begin(w, i, t, a.pos(i), Kin.angle_of(to))  # it bursts out with its slam
		return
	if planning:
		a.facing[i] = Kin.angle_of(to)
	if _may_start(w, i, t, dist - a.radius[i] - w.player.radius_m):
		_begin(w, i, t, a.pos(i), Kin.angle_of(to))


## Lurker i's slam: [centre, radius], round where it stood as it began.
static func slam_disc(w: World, i: int) -> Array:
	var t := w.enemy_table(w.actors.kinds[i])
	return [Vector2(w.actors.lock_x[i], w.actors.lock_y[i]), t.slam_radius_m]


# --- R4 Stone Thrower ------------------------------------------------------------------------------------------
static func _thrower_think(w: World, i: int, t: EnemyTable, planning: bool) -> void:
	var a := w.actors
	if a.state[i] != EnemyAi.State.MOVE:
		_run_attack(w, i, t, t.flight_ticks + 1)  # it lands on the flight's last tick (resolve)
		return
	var to := w.player_pos() - a.pos(i)
	if planning:
		a.facing[i] = Kin.angle_of(to)
	if _may_start(w, i, t, Kin.length(to)):
		_begin(w, i, t, w.player_pos(), Kin.angle_of(to))


## Where Thrower i's rock lands: [centre, radius].
static func landing_disc(w: World, i: int) -> Array:
	var t := w.enemy_table(w.actors.kinds[i])
	return [Vector2(w.actors.lock_x[i], w.actors.lock_y[i]), t.slam_radius_m]


## Thrower i's rock in the air: 0..1000 of its flight while ACTIVE before it lands, else -1.
static func flight_permille(w: World, i: int) -> int:
	var a := w.actors
	if a.kinds[i] != ActorStore.Kind.STONE_THROWER or a.state[i] != EnemyAi.State.ACTIVE:
		return -1
	var t := w.enemy_table(a.kinds[i])
	if a.state_t[i] > t.flight_ticks:
		return -1
	return clampi(a.state_t[i] * 1000 / t.flight_ticks, 0, 1000)


## The rock lands: it stands where it fell, unless the spot is the hero's, a wall's or no room's.
static func _land(w: World, i: int, t: EnemyTable) -> void:
	var q := Vector2(w.actors.lock_x[i], w.actors.lock_y[i])
	if not _fits(w, q, t.rock_half_m):
		return
	var s := w.ruins_rocks
	while s.rock_count() >= maxi(1, t.max_rocks):
		w.remove_barriers([s.rock_obb(0)])
		s.remove_rock(0)
	s.add_rock(q, t.rock_half_m, w.tick + t.rock_ticks, w.actors.ids[i])
	w.add_barrier(s.rock_obb(s.rock_count() - 1))


static func _fits(w: World, q: Vector2, h: float) -> bool:
	if Kin.length(q - w.player_pos()) < w.player.radius_m + h * 1.42 + HERO_GAP_M:
		return false
	if w.floor_layout != null and w.floor_layout.room_of(q) < 0:
		return false  # never in a doorway (it would shut it)
	return EnemyAi.clear_of_walls(w, q, h * 1.42)


# --- Phases 5 and 6, and the view's telegraph --------------------------------------------------------------------
## Phase 5 (EnemyAi.move): true when it moved signature enemy i itself (the Hound, a waiting Lurker, a post); false
## leaves the walk to EnemyAi (the Weaver, the Thrower, a Lurker that is out).
static func moves(w: World, i: int, t: EnemyTable, slow: float) -> bool:
	match w.actors.kinds[i]:
		ActorStore.Kind.WIRE_POST:
			return true
		ActorStore.Kind.SCRAP_HOUND:
			_hound_move(w, i, t, slow)
			return true
		ActorStore.Kind.ROCK_LURKER:
			return w.actors.pick[i] != OUT
	return false


## Phase 6 (EnemyAi.resolve): the Hound's bite, the Lurker's slam, the Thrower's landing.
static func resolve(w: World, i: int) -> void:
	var a := w.actors
	if a.state[i] != EnemyAi.State.ACTIVE or w.player_dead() or Engines.frozen(w, i):
		return
	var t := w.enemy_table(a.kinds[i])
	var p := w.player_pos()
	var pr := w.player.radius_m
	match a.kinds[i]:
		ActorStore.Kind.SCRAP_HOUND:
			var reach := t.radius_m + pr + EnemyAi.CONTACT_SLOP_M
			if a.fire_cd[i] == 0 and Kin.length(p - a.pos(i)) <= reach:
				a.fire_cd[i] = BIT
				a.lock_len[i] = 0.0
				EnemyAi.hit_player(w, i, t.damage, SimEvent.TAG_MELEE)
		ActorStore.Kind.ROCK_LURKER:
			if a.state_t[i] == 0:
				var d := slam_disc(w, i)
				if AttackShapes.disc_touches(d[0], d[1], p, pr):
					EnemyAi.hit_player(w, i, t.damage, SimEvent.TAG_AREA, d[0])
		ActorStore.Kind.STONE_THROWER:
			if a.state_t[i] == t.flight_ticks:
				var d := landing_disc(w, i)
				if AttackShapes.disc_touches(d[0], d[1], p, pr):
					EnemyAi.hit_player(w, i, t.damage, SimEvent.TAG_AREA, d[0])
				_land(w, i, t)


## What signature enemy i shows (EnemyAi.telegraph): the cable's line, the Hound's dart (its body's tell: its eyes),
## the Lurker's slam circle, the Thrower's landing ring.
static func telegraph(w: World, i: int) -> Dictionary:
	var a := w.actors
	var st := a.state[i]
	var progress := clampi(a.state_t[i] * 1000 / maxi(1, a.windup[i]), 0, 1000)
	match a.kinds[i]:
		ActorStore.Kind.WIRE_WEAVER:
			if st == EnemyAi.State.WINDUP:
				return {"shape": &"lane", "obb": cable_lane(w, i), "progress": progress}
		ActorStore.Kind.SCRAP_HOUND:
			if st == EnemyAi.State.WINDUP or (st == EnemyAi.State.ACTIVE and a.lock_len[i] > 0.0):
				return {
					"shape": &"lane",
					"ground": false,
					"obb": dart_lane(w, i),
					"progress": progress if st == EnemyAi.State.WINDUP else 1000
				}
		ActorStore.Kind.ROCK_LURKER:
			if st == EnemyAi.State.WINDUP:
				var d := slam_disc(w, i)
				return {"shape": &"disc", "center": d[0], "radius": d[1], "progress": progress}
		ActorStore.Kind.STONE_THROWER:
			var air := flight_permille(w, i)
			if st == EnemyAi.State.WINDUP or air >= 0:
				var t := w.enemy_table(a.kinds[i])
				var run := a.state_t[i] + (t.windup_ticks if air >= 0 else 0)
				var d := landing_disc(w, i)
				return {
					"shape": &"disc",
					"center": d[0],
					"radius": d[1],
					"progress":
					clampi(run * 1000 / maxi(1, t.windup_ticks + t.flight_ticks), 0, 1000)
				}
	return {}


## Phase 6 (after the variants): a waiting Lurker holds its spot (and its wall goes with it); a cable with a post or
## its Weaver gone drops (its other post with it); a live cable touching the hero hurts it once a period; rocks past
## their time go.
static func advance(w: World) -> void:
	var s := w.ruins_rocks
	if not s.touched:
		return
	var a := w.actors
	for k in range(s.hide_count() - 1, -1, -1):
		var j := a.index_of(s.hide_id[k])
		if j < 0 or a.dead[j] == 1:
			w.remove_barriers([s.hide_obb(k)])
			s.remove_hide(k)
		else:
			a.set_pos(j, Vector2(s.hide_x[k], s.hide_y[k]))
	for k in range(s.cable_count() - 1, -1, -1):
		var o := a.index_of(s.cable_owner[k])
		if cable_ends(w, k).is_empty() or o < 0 or a.dead[o] == 1:
			_drop_cable(w, k)
	_touch_cables(w)
	for k in range(s.rock_count() - 1, -1, -1):
		if w.tick >= s.rock_until[k]:
			w.remove_barriers([s.rock_obb(k)])
			s.remove_rock(k)


## Cable k drops: its posts still standing go with it (no kill: the floor takes them back).
static func _drop_cable(w: World, k: int) -> void:
	var s := w.ruins_rocks
	for id in [s.cable_a[k], s.cable_b[k]]:
		var j := w.actors.index_of(id)
		if j >= 0 and w.actors.dead[j] == 0:
			w.actors.hp[j] = 0
			w.actors.dead[j] = 1
	s.remove_cable(k)


static func _touch_cables(w: World) -> void:
	var s := w.ruins_rocks
	if s.cable_count() == 0 or w.player_dead() or w.tick < s.cable_next:
		return
	var p := w.player_pos()
	for k in s.cable_count():
		if cable_distance(w, k, p) > w.player.radius_m + s.cable_half[k] + CONTACT_SLOP_M:
			continue
		s.cable_next = w.tick + s.cable_period[k]
		Damage.hit(
			w, 0, s.cable_damage[k], 0, 0, w.take_root(), SimEvent.TAG_AREA, p, p, CABLE_EFFECT
		)
		if w.player_dead():
			w.killer_attack = KILL_CAUSE  # the recap names the cable (BossCauses.key)
		return


## Whether actor i leaves without a kill (a Wire Weaver's post: no kill, no shards, World._remove_dead).
static func leaves(w: World, i: int) -> bool:
	return w.actors.kinds[i] == ActorStore.Kind.WIRE_POST
