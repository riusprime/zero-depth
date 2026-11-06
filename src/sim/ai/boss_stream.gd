class_name BossStream
extends RefCounted
## v0.9.5 BH4 (owner, 2026-10-25: "tidescaller tides shouuld be stronger and keep the ball patter all times, we should
## add spawning waves crossing the room, small like 2-4 meters that the player has to dodge during all fight";
## docs/roadmap/v0.9.5/BOSSES_HARD.md rows T2, T3): the Tidecaller's two streams, which run the whole fight beside its
## attack rotation (BossTable.streams; the phase's stream_attack / wave_attack):
## - The ring stream: every stream_every ticks a ring of bubbles (a `pattern` attack's pattern, one wave of it)
##   leaves the boss. Ring n is turned on from ring n - 1 by the pattern's turn (alternating sides with `alternate`).
##   It aims at nothing: a fixed heading, so the gaps are read, not chased. None while the boss rises or kneels at a
##   phase change (the gate), the next a full period after.
## - The crossing waves: every wave_every ticks, wave_n short waves form, each at a wall of the boss room
##   (BossStore.arena; without one, round where the boss stands), the walls and the lengths drawn from the `ai`
##   stream (two waves at once come from different walls, opposite or adjacent). A wave is shown as a foam line on
##   the floor at its wall for the attack's telegraph, then crosses the room perpendicular to that wall at wave_speed
##   to the opposite wall: once per wave it hits the player for the attack's damage and shoves them wave_shove_m
##   along its travel (BossTide.shift: never into a wall). Its place along the wall is drawn so that it never lies
##   within wave_clear_m of the player's projection on that wall as it forms. A dash passes through it. Waves ignore
##   bodies, props and shots. A boss gone, its waves go.
## Pure: integer-valued draws from the `ai` stream (wall, length, place), no trig.

## The room's half-size round the boss when there is no sealed boss room (a test world).
const FALLBACK_HALF_M := 7.0
## The walls, and the way a wave travels away from each (1/4096 turns): north (travels +y), east (-x), south (-y), west
## (+x). The wall index is also the wave's "wall" in the reader.
const NORTH := 0
const EAST := 1
const SOUTH := 2
const WEST := 3
const WALL_DIR: Array[int] = [1024, 2048, 3072, 0]
## The place along a wall is drawn in this many steps a metre.
const STEPS_PER_M := 1000

# --- the tick -----------------------------------------------------------------------


## Tick phase 6 (BossSignatures.advance): each boss with streams rings and forms waves when due; each wave moves, hits.
static func advance(w: World) -> void:
	var bs := w.bosses
	for b in bs.size():
		var i := w.actors.index_of(bs.ids[b])
		if i < 0 or w.actors.dead[i] == 1:
			continue
		var t: BossTable = w.boss_tables[bs.table[b]]
		if t.streams:
			_boss(w, i, b, t)
	if not bs.wv_boss.is_empty():
		_waves(w)


## World._remove_dead (BossSignatures.on_boss_gone): its streams and its waves go with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var bs := w.bosses
	var k := bs.str_of(boss_id)
	if k >= 0:
		bs.remove_stream(k)
	for j in range(bs.wv_boss.size() - 1, -1, -1):
		if bs.wv_boss[j] == boss_id:
			bs.remove_wave(j)


static func _boss(w: World, i: int, b: int, t: BossTable) -> void:
	var bs := w.bosses
	var a := w.actors
	var ph := bs.phase[b]
	var rk := t.phase_ring_atk[ph]
	var wk := t.phase_wave_atk[ph]
	var rising := a.state[i] == EnemyAi.State.SPAWN
	var kneeling := a.state[i] == BossAi.GATE or a.state[i] == BossAi.STAGGERED
	var k := bs.str_of(bs.ids[b])
	if k < 0:
		if rising:
			return
		k = bs.add_stream(
			bs.ids[b], w.tick + t.phase_ring_ticks[ph], w.tick + t.phase_wave_ticks[ph]
		)
	if w.player_dead():
		return
	if rk >= 0:
		if rising or kneeling:  # none while it rises or kneels: the next a full period after
			bs.str_ring_due[k] = w.tick + t.phase_ring_ticks[ph]
		elif w.tick >= bs.str_ring_due[k]:
			ring(w, i, t.attacks[rk], rk, bs.str_ring_n[k])
			bs.str_ring_n[k] += 1
			bs.str_ring_due[k] = w.tick + t.phase_ring_ticks[ph]
	if wk >= 0:
		if rising:
			bs.str_wave_due[k] = w.tick + t.phase_wave_ticks[ph]
		elif w.tick >= bs.str_wave_due[k]:
			form(w, i, b, wk, t.phase_wave_n[ph])
			bs.str_wave_due[k] = w.tick + t.phase_wave_ticks[ph]


# --- the rings -----------------------------------------------------------------------


## Ring n of `atk`'s pattern leaves boss i (attack index `rk` is the cause the recap names). Returns the bubbles queued.
static func ring(w: World, i: int, atk: BossAttackTable, rk: int, n: int) -> int:
	var pat := atk.pattern
	if pat == null:
		return 0
	var r := w.actors.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M
	return BulletPatterns.fire(
		w, i, pat, n, w.actors.pos(i), 0, r, BossAi.orb_damage(w, i, atk), rk
	)


# --- the waves ------------------------------------------------------------------------


## The room waves form in: the boss room's interior, or a square round boss i when there is none.
static func room_of(w: World, i: int) -> Rect2:
	if w.bosses.arena.has_area():
		return w.bosses.arena
	var half := Vector2(FALLBACK_HALF_M, FALLBACK_HALF_M)
	return Rect2(w.actors.pos(i) - half, half * 2.0)


## Forms `n` waves of attack `wk` at once for boss i (entry b): the first wall drawn, each other one of the rest.
## Returns how many formed (a wave is left out when no place along its wall is clear of the player).
static func form(w: World, i: int, b: int, wk: int, n: int) -> int:
	var t: BossTable = w.boss_tables[w.bosses.table[b]]
	var atk := t.attacks[wk]
	var room := room_of(w, i)
	var first := w.rng_ai.range_int(0, 3)
	var walls: Array[int] = [first]
	if n >= 2:
		walls.append((first + 1 + w.rng_ai.range_int(0, 2)) % 4)
	var made := 0
	for wall in walls:
		if _add(w, w.bosses.ids[b], wk, atk, room, wall):
			made += 1
	return made


## One wave at `wall` of `room`: its length drawn, its place drawn among those at least wave_clear_m (and half
## its length) from the player's projection on that wall. False when there is none.
static func _add(
	w: World, boss_id: int, wk: int, atk: BossAttackTable, room: Rect2, wall: int
) -> bool:
	var length := atk.wave_lengths[w.rng_ai.range_int(0, atk.wave_lengths.size() - 1)]
	var along_x := wall == NORTH or wall == SOUTH  # the wall runs along x
	var lo := room.position.x if along_x else room.position.y
	var hi := room.end.x if along_x else room.end.y
	var proj := w.player_pos().x if along_x else w.player_pos().y
	var half := length * 0.5
	var spans: Array[Vector2] = []
	for s: Vector2 in [
		Vector2(lo + half, proj - atk.wave_clear_m - half),
		Vector2(proj + atk.wave_clear_m + half, hi - half)
	]:
		if s.y >= s.x:
			spans.append(s)
	var total := 0
	for s in spans:
		total += int((s.y - s.x) * STEPS_PER_M)
	if spans.is_empty():
		return false
	var u := w.rng_ai.range_int(0, total)
	var c := spans[spans.size() - 1].y
	for s in spans:
		var span := int((s.y - s.x) * STEPS_PER_M)
		if u <= span:
			c = s.x + float(u) / STEPS_PER_M
			break
		u -= span
	var at := Vector2.ZERO
	match wall:
		NORTH:
			at = Vector2(c, room.position.y)
		EAST:
			at = Vector2(room.end.x, c)
		SOUTH:
			at = Vector2(c, room.end.y)
		_:
			at = Vector2(room.position.x, c)
	var bs := w.bosses
	bs.wv_boss.append(boss_id)
	bs.wv_atk.append(wk)
	bs.wv_from.append(w.tick)
	bs.wv_dir.append(WALL_DIR[wall])
	bs.wv_hit.append(0)
	bs.wv_x.append(at.x)
	bs.wv_y.append(at.y)
	bs.wv_len.append(length)
	var across := room.size.y if along_x else room.size.x
	bs.wv_run.append(maxf(across - atk.wave_thick_m, 0.0))
	return true


## The attack table of wave k's wave attack, or null when its boss is gone.
static func atk_of(w: World, k: int) -> BossAttackTable:
	var b := w.bosses.index_of(w.bosses.wv_boss[k])
	if b < 0:
		return null
	var t: BossTable = w.boss_tables[w.bosses.table[b]]
	return t.attacks[w.bosses.wv_atk[k]]


## How far wave k's middle has travelled from its first place on tick `tick`: -1 while it is only a foam line (the
## telegraph), else metres from 0 (just in from the wall) up to its run.
static func travelled(w: World, k: int, tick: int = -1) -> float:
	var atk := atk_of(w, k)
	var t := (w.tick if tick < 0 else tick) - w.bosses.wv_from[k] - atk.windup_ticks
	return -1.0 if t < 0 else minf(atk.wave_speed * t, w.bosses.wv_run[k])


## Wave k's box on its way, `d` metres on (the box is the wave's length across, thick along its travel).
static func box_of(w: World, k: int, d: float) -> Obb:
	var bs := w.bosses
	var atk := atk_of(w, k)
	var dir := bs.wv_dir[k]
	var mid := Vector2(bs.wv_x[k], bs.wv_y[k]) + Kin.dir(dir) * (atk.wave_thick_m * 0.5 + d)
	return Obb.make(mid, Vector2(atk.wave_thick_m * 0.5, bs.wv_len[k] * 0.5), dir)


## Every wave: past its telegraph it moves, hits (once each) and is gone at the far wall.
static func _waves(w: World) -> void:
	var bs := w.bosses
	for k in range(bs.wv_boss.size() - 1, -1, -1):
		var atk := atk_of(w, k)
		if atk == null:
			bs.remove_wave(k)
			continue
		var d := travelled(w, k)
		if d < 0.0:
			continue
		if bs.wv_hit[k] == 0 and not w.player_dead() and not w.is_dashing():
			var box := box_of(w, k, d)
			if Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, box) != Vector2.ZERO:
				bs.wv_hit[k] = 1
				_hit(w, k, atk, box.center)
		if d >= bs.wv_run[k]:
			bs.remove_wave(k)


## Wave k hits the player: the attack's damage (under the boss's catch-up), then the shove along its travel.
static func _hit(w: World, k: int, atk: BossAttackTable, from: Vector2) -> void:
	var bs := w.bosses
	var i := w.actors.index_of(bs.wv_boss[k])
	if i < 0:
		return
	var dmg := BossAi.powered(w, i, atk.damage)
	var id := w.actors.ids[i]
	Damage.hit(w, 0, dmg, id, id, w.take_root(), SimEvent.TAG_AREA, from, w.player_pos())
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = bs.wv_atk[k]
	BossTide.shift(w, Kin.dir(bs.wv_dir[k]) * atk.wave_shove_m)


# --- the view's read (WorldReader.boss_waves) ------------------------------------------------


## Every wave: [{"boss" (actor id), "wall" (0..3), "dir" (1/4096 turns), "start" (the middle of its line on the wall),
## "pos" (its middle now), "length", "thick", "telegraph" (0..1000 while a foam line, -1 once it moves), "progress"
## (0..1000 of its run), "hit", "formed" (tick)}].
static func state(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bs := w.bosses
	for k in bs.wv_boss.size():
		var atk := atk_of(w, k)
		if atk == null:
			continue
		var d := travelled(w, k)
		var at := Vector2(bs.wv_x[k], bs.wv_y[k])
		(
			out
			. append(
				{
					"boss": bs.wv_boss[k],
					"wall": WALL_DIR.find(bs.wv_dir[k]),
					"dir": bs.wv_dir[k],
					"start": at,
					"pos": at + Kin.dir(bs.wv_dir[k]) * (atk.wave_thick_m * 0.5 + maxf(d, 0.0)),
					"length": bs.wv_len[k],
					"thick": atk.wave_thick_m,
					"telegraph":
					(
						clampi((w.tick - bs.wv_from[k]) * 1000 / maxi(1, atk.windup_ticks), 0, 1000)
						if d < 0.0
						else -1
					),
					"progress":
					clampi(int(d * 1000.0 / maxf(bs.wv_run[k], 0.001)), 0, 1000) if d >= 0.0 else 0,
					"hit": bs.wv_hit[k] == 1,
					"formed": bs.wv_from[k],
				}
			)
		)
	return out
