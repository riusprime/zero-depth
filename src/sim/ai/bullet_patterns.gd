class_name BulletPatterns
extends RefCounted
## v0.7.5 BF1 (owner N15; docs/design/BOSS_FIGHTS.md; SIM_CONTRACTS §10d): the bullet pattern engine. A pattern
## (BulletPatternTable, from data/bullet_patterns) is fired over time by whoever runs it (BossAi's `pattern` move;
## from EF, enemies): on each of its wave ticks, wave_shots() gives the wave's spawn points and velocities, a pure
## function of the pattern, the wave, the origin and the aim (no stream is drawn, so a pattern never moves another
## roll), and fire() queues them as slow hostile projectiles that carry the pattern's look key.
## Angles are 1/4096 turns through Kin (no trig); the rose of a flower is a Kin.dir lookup.
## Fair (BOSS_FIGHTS.md rule 5): a shot whose spawn point is within the pattern's safe radius of the player (plus the
## player's radius) or touches a wall is left out; shots stop at walls (World's projectile sweep, no bounces); at
## most MAX_SHOTS_PER_TICK hostile shots are queued in a tick and MAX_ALIVE live at once, past which a wave's
## remaining shots are dropped with one LIMIT event (effect EFFECT_CAP, amount = the cap). The gaps every kind
## keeps are checked by the content validation (BulletPatternDefinition) and the tests.

## Hostile pattern shots queued in one tick, and alive at once (all projectiles counted), at most.
const MAX_SHOTS_PER_TICK := 160
const MAX_ALIVE := 900
const EFFECT_CAP := &"bullet_cap"
## Where the shots of a pattern fired by a body appear: this far past the body's edge.
const MUZZLE_M := 0.05

const K := BulletPatternTable.Kind


## The wave pattern p fires on its tick st (ticks since the pattern began, the lob included), or -1.
static func wave_at(p: BulletPatternTable, st: int) -> int:
	var t := st - p.lob_ticks
	if t < 0 or t % maxi(1, p.wave_gap_ticks) != 0:
		return -1
	var k := t / maxi(1, p.wave_gap_ticks)
	return k if k < p.waves else -1


## The base angle of wave k: the aim, the offset, and the turn per wave (every other wave with `alternate`).
static func base_angle(p: BulletPatternTable, k: int, aim: int) -> int:
	var steps := (k % 2) if p.alternate else k
	return (aim + p.aim_offset + p.turn_per_wave * steps) & 4095


## Wave k's shots: [spawn points, velocities (metres per tick)], from `origin` (a body's centre, `origin_r` out; a
## burst's landing point with origin_r 0) toward `aim` (1/4096 turns). Pure: the shapes drawn and fired are these.
static func wave_shots(
	p: BulletPatternTable, k: int, origin: Vector2, aim: int, origin_r: float
) -> Array[PackedVector2Array]:
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	var base := base_angle(p, k, aim)
	match p.kind:
		K.RING:
			for j in p.count:
				if not _in_ring_gap(p, j):
					_radial(pos, vel, origin, origin_r, base + j * 4096 / p.count, p.speed)
		K.FAN:
			for j in p.count:
				var ang := base
				if p.count > 1:
					ang = base - p.spread / 2 + j * p.spread / (p.count - 1)
				_radial(pos, vel, origin, origin_r, ang, p.speed)
		K.SPIRAL, K.CROSS:
			var turn := spin_at(p, k * p.wave_gap_ticks)
			for arm in p.arms:
				_radial(pos, vel, origin, origin_r, base + turn + arm * 4096 / p.arms, p.speed)
		K.WALL:
			_wall(pos, vel, p, k, origin, base, origin_r)
			if p.crossing:
				_wall(pos, vel, p, k + 1, origin, base + 1024, origin_r)
		K.FLOWER:
			for j in p.count:
				var rel := j * 4096 / p.count
				var c := absf(Kin.dir(p.petals * rel / 2).x)
				if int(c * 1000.0) < p.petal_cut_permille:
					continue
				var f := (p.petal_min_permille + (1000 - p.petal_min_permille) * c) / 1000.0
				_radial(pos, vel, origin, origin_r, base + rel, p.speed * f)
		K.BURST:
			for j in p.count:
				_radial(pos, vel, origin, origin_r, base + j * 4096 / p.count, p.speed)
	return [pos, vel]


## A spiral's or cross's turn (1/4096 turns) `t` ticks after its first wave; a spiral turns back after
## reverse_ticks.
static func spin_at(p: BulletPatternTable, t: int) -> int:
	if p.kind == K.SPIRAL and p.reverse_ticks > 0 and t > p.reverse_ticks:
		return p.spin_milli * (2 * p.reverse_ticks - t) / 1000
	return p.spin_milli * t / 1000


## Fires wave k of pattern p for actor `owner` (its id is the shots' owner): the shots that are fair and fit under
## the caps are queued for this tick's spawn phase. Returns how many were queued.
static func fire(
	w: World,
	owner_i: int,
	p: BulletPatternTable,
	k: int,
	origin: Vector2,
	aim: int,
	origin_r: float,
	damage: int
) -> int:
	var shots := wave_shots(p, k, origin, aim, origin_r)
	var pos: PackedVector2Array = shots[0]
	var vel: PackedVector2Array = shots[1]
	var safe := p.safe_radius_m + w.player.radius_m
	var player := w.player_pos()
	var n := 0
	for j in pos.size():
		var d := pos[j] - player
		if d.x * d.x + d.y * d.y < safe * safe:
			continue  # no shot spawns on top of the player
		if not EnemyAi.clear_of_walls(w, pos[j], p.radius_m):
			continue  # nor inside a wall
		if not room(w):
			_limit(w, owner_i)
			break
		w.queue_projectile(
			w.actors.ids[owner_i],
			ActorStore.TEAM_ENEMY,
			pos[j],
			vel[j],
			damage,
			p.radius_m,
			p.life_ticks,
			SimEvent.TAG_PROJECTILE
		)
		w.set_pending_look(p.look)
		n += 1
	return n


## True while one more hostile shot fits under the per-tick and alive caps.
static func room(w: World) -> bool:
	var pending := w.pending_projectiles()
	return pending < MAX_SHOTS_PER_TICK and w.projectiles.size() + pending < MAX_ALIVE


static func _limit(w: World, owner_i: int) -> void:
	var id := w.actors.ids[owner_i]
	var e := w.emit_event(SimEvent.Kind.LIMIT, id, id, id, w.actors.pos(owner_i))
	e.effect_id = EFFECT_CAP
	e.amount = MAX_SHOTS_PER_TICK


## True when ring shot j falls in one of the ring's gaps (gap_count gaps evenly round, each gap_width shots, the
## first centred on the base angle).
static func _in_ring_gap(p: BulletPatternTable, j: int) -> bool:
	for g in p.gap_count:
		var centre := g * p.count / p.gap_count
		var lo := centre - p.gap_width / 2
		var off := (j - lo + p.count) % p.count
		if off < p.gap_width:
			return true
	return false


static func _radial(
	pos: PackedVector2Array,
	vel: PackedVector2Array,
	origin: Vector2,
	origin_r: float,
	angle: int,
	speed: float
) -> void:
	var d := Kin.dir(angle)
	pos.append(origin + d * origin_r)
	vel.append(d * speed)


## One wall: shots spacing_m apart across `angle`, centred origin_r ahead of the origin, marching along `angle`, with
## the wave's gap left out.
static func _wall(
	pos: PackedVector2Array,
	vel: PackedVector2Array,
	p: BulletPatternTable,
	k: int,
	origin: Vector2,
	angle: int,
	origin_r: float
) -> void:
	var d := Kin.dir(angle)
	var side := Vector2(-d.y, d.x)
	var centre := origin + d * origin_r
	var g := wall_gap(p, k)
	var n := int(p.wall_length_m / p.spacing_m) + 1
	var half := p.spacing_m * (n - 1) * 0.5
	for j in n:
		var x := -half + p.spacing_m * j
		if absf(x - g) < p.gap_m * 0.5 + p.radius_m:
			continue
		pos.append(centre + side * x)
		vel.append(d * p.speed)


## Where wave k's wall gap is centred, sideways from the aim line (metres): gap_offset_m plus gap_shift_m a wave,
## bouncing between the wall's ends so the gap always fits.
static func wall_gap(p: BulletPatternTable, k: int) -> float:
	var half := maxf(0.0, (p.wall_length_m - p.gap_m) * 0.5)
	if half <= 0.0:
		return 0.0
	var span := half * 2.0
	var u := fposmod(p.gap_offset_m + p.gap_shift_m * k + half, span * 2.0)
	return (u if u <= span else span * 2.0 - u) - half
