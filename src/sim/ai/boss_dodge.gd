class_name BossDodge
extends RefCounted
## v0.7.5 BF1 (owner N15; docs/design/BOSS_FIGHTS.md; SIM_CONTRACTS §10d): the dodge-first parts of the boss framework
## (BossAi calls them). Markers that follow the player's exact position, lock and strike (`marks`, `row_lanes`: one
## shape function each, mark_of and row_lanes_of, drawn and hit alike, EI-07); the `pattern` move's waves
## (BulletPatterns) and a burst's landing; the shield of a signature pattern (shielded(), read by Damage and the
## views); and what the views and avatars read (marks_telegraph, pattern_telegraph, pattern_state).
## Pure: no stream is drawn here.


## v0.7.5 BF1: a move that lays tracked markers one after another (marks, row_lanes).
static func is_marker_move(move: int) -> bool:
	return move == BossAttackTable.Move.MARKS or move == BossAttackTable.Move.ROW_LANES


## v0.7.5 BF1: `t` ticks into a marker attack: marker k starts at k × mark_gap_ticks, follows the player's exact
## position until its windup's last lock_ticks, then holds until it strikes (at k × mark_gap_ticks + windup_ticks).
static func track_marks(w: World, b: int, atk: BossAttackTable, t: int) -> void:
	if w.player_dead():
		return
	for k in atk.count:
		if t < k * atk.mark_gap_ticks + atk.windup_ticks - atk.lock_ticks:
			w.bosses.set_pt(b, k, w.player_pos())


## v0.7.5 BF1: marker k's state `t` ticks into its attack: -1 not started, 0 tracking, 1 locked, 2 striking (this
## tick), 3 done.
static func mark_state(atk: BossAttackTable, k: int, t: int) -> int:
	var t0 := k * atk.mark_gap_ticks
	if t < t0:
		return -1
	if t < t0 + atk.windup_ticks - atk.lock_ticks:
		return 0
	if t < t0 + atk.windup_ticks:
		return 1
	return 2 if t == t0 + atk.windup_ticks else 3


## v0.7.5 BF1: ticks into boss i's attack (its windup, then its active time).
static func attack_ticks(w: World, i: int, atk: BossAttackTable) -> int:
	var st := w.actors.state_t[i]
	return st if w.actors.state[i] == EnemyAi.State.WINDUP else atk.windup_ticks + st


## v0.7.5 BF1: a shielded attack (the signature pattern) is winding up or running: hits spark off (Damage). It opens
## between patterns. v0.8.0 FB2: a shielded Cross opens only for its window (its active time after the spin).
static func shielded(w: World, i: int) -> bool:
	if not BossAi.is_boss_kind(w.actors.kinds[i]):
		return false
	var s := w.actors.state[i]
	if s != EnemyAi.State.WINDUP and s != EnemyAi.State.ACTIVE:
		return false
	var atk := BossAi.attack_of(w, i)
	if atk != null and atk.move == BossAttackTable.Move.CROSS and BossPrism.in_window(w, i):
		return false  # v0.8.0 FB2 (F7): the Cross's window, between two spins
	return atk != null and atk.shielded


## v0.7.5 BF1: a pattern attack's active tick st: a burst's shell lands (a disc that hurts, where the windup locked),
## and each wave tick fires its wave from the body (or the landing point) toward the locked aim.
static func resolve_pattern(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var pat := atk.pattern
	if pat == null:
		return
	var burst := pat.kind == BulletPatternTable.Kind.BURST
	if burst and st == pat.lob_ticks:
		var c := w.bosses.pt(b, 0)
		if AttackShapes.disc_touches(c, pat.land_radius_m, w.player_pos(), w.player.radius_m):
			BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, c)
	var k := BulletPatterns.wave_at(pat, st)
	if k < 0:
		return
	var origin := w.bosses.pt(b, 0) if burst else w.actors.pos(i)
	var r := 0.0 if burst else w.actors.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M
	var n := BulletPatterns.fire(
		w, i, pat, k, origin, w.actors.lock_a[i], r, BossAi.orb_damage(w, i, atk)
	)
	BossRicochet.arm_pattern(w, atk, n)  # v0.8.0 BS2 (S5): the Turret Cross's embers bounce once


## v0.7.5 BF1: where marker k of a `marks` attack stands (it follows the player until it locks).
static func mark_of(w: World, i: int, k: int) -> Vector2:
	return w.bosses.pt(BossAi.entry_of(w, i), k)


## v0.7.5 BF1: marker k of a `row_lanes` attack: two lanes through its point, along the row (x) and the column (y),
## each reaching length_m / 2 each way unless a wall cuts it short.
static func row_lanes_of(w: World, i: int, k: int) -> Array[Obb]:
	var atk := BossAi.attack_of(w, i)
	var c := mark_of(w, i, k)
	var out: Array[Obb] = []
	for axis in [0, 1024]:
		var fwd := EnemyAi.clear_run(w, c, axis, atk.length_m * 0.5, atk.half_width_m)
		var back := EnemyAi.clear_run(w, c, axis + 2048, atk.length_m * 0.5, atk.half_width_m)
		var start := c - Kin.dir(axis) * back
		out.append(AttackShapes.lane(start, axis, maxf(fwd + back, 0.01), atk.half_width_m))
	return out


## v0.7.5 BF1: the markers of a marks / row_lanes attack showing now (started, not yet struck).
static func marks_telegraph(w: World, i: int, atk: BossAttackTable) -> Dictionary:
	var t := attack_ticks(w, i, atk)
	var items: Array[Dictionary] = []
	var first := -1
	for k in atk.count:
		var st := mark_state(atk, k, t)
		if st < 0 or st > 2:
			continue
		var pr := clampi((t - k * atk.mark_gap_ticks) * 1000 / maxi(1, atk.windup_ticks), 0, 1000)
		if first < 0:
			first = pr
		var item := {"locked": st >= 1, "progress": pr}
		if atk.move == BossAttackTable.Move.MARKS:
			item["shape"] = &"disc"
			item["center"] = mark_of(w, i, k)
			item["radius"] = atk.radius_m
			if atk.pattern != null and st == 1:  # v0.7.5 BF2: the egg flies onto its locked circle
				var t_lock := k * atk.mark_gap_ticks + atk.windup_ticks - atk.lock_ticks
				item["lob"] = {
					"from": w.actors.pos(i),
					"to": item["center"],
					"progress": clampi((t - t_lock) * 1000 / maxi(1, atk.lock_ticks), 0, 1000)
				}
		else:
			item["shape"] = &"lanes"
			item["obbs"] = row_lanes_of(w, i, k)
		items.append(item)
	if items.is_empty():
		return {}
	return {
		"shape": &"marks",
		"items": items,
		"progress": first,
		"move": atk.move,
		"tracked": true,
		"locked": items[0]["locked"]
	}


## v0.7.5 BF2: a pattern's cast, for its windup and its whole firing: {"shape": &"cast", "ground": false, "progress",
## "move", "look"}. Nothing on the ground (owner N15/N16: no line for shots; TelegraphViews skips it); the boss's body
## winds up and holds its cast pose from it (the avatar reads the progress), so every wave's shots come from a cast
## the player saw for at least the windup (the readable-cause rule; windups are >= MIN_TELEGRAPH_TICKS).
static func cast_telegraph(atk: BossAttackTable, windup: bool, progress: int) -> Dictionary:
	return {
		"shape": &"cast",
		"ground": false,
		"progress": progress if windup else 1000,
		"move": atk.move,
		"look": atk.pattern.look
	}


## v0.7.5 BF1: a pattern draws nothing on the ground but a burst's landing marker (and its flying shell); v0.7.5 BF2:
## the rest of a pattern's time is its cast (cast_telegraph).
static func pattern_telegraph(
	w: World, i: int, b: int, atk: BossAttackTable, windup: bool, progress: int
) -> Dictionary:
	var pat := atk.pattern
	if pat == null:
		return {}
	var st := w.actors.state_t[i]
	if pat.kind != BulletPatternTable.Kind.BURST or (not windup and st > pat.lob_ticks):
		return cast_telegraph(atk, windup, progress)
	var commit := atk.lock_ticks if atk.lock_ticks > 0 else BossAi.table_of(w, i).commit_ticks
	var out := {
		"shape": &"disc",
		"center": w.bosses.pt(b, 0),
		"radius": pat.land_radius_m,
		"progress": progress if windup else 1000,
		"move": atk.move,
		"tracked": true,
		"locked": not windup or st >= atk.windup_ticks - commit
	}
	if not windup:
		out["lob"] = {
			"from": w.actors.pos(i),
			"to": w.bosses.pt(b, 0),
			"progress": clampi(st * 1000 / maxi(1, pat.lob_ticks), 0, 1000)
		}
	return out


## v0.7.5 BF1: the pattern boss i is firing now, for its avatar and the views: {} or {"id" (the pattern's), "kind"
## (BulletPatternTable.Kind), "look", "shielded", "winding" (true in the windup), "progress" (0..1000 of the windup,
## then of the active time)}.
static func pattern_state(w: World, i: int) -> Dictionary:
	var atk := BossAi.attack_of(w, i)
	var s := w.actors.state[i]
	if (
		atk == null
		or atk.pattern == null
		or (s != EnemyAi.State.WINDUP and s != EnemyAi.State.ACTIVE)
	):
		return {}
	var winding := s == EnemyAi.State.WINDUP
	var total := atk.windup_ticks if winding else atk.active_ticks
	return {
		"id": atk.pattern.id,
		"kind": atk.pattern.kind,
		"look": atk.pattern.look,
		"shielded": atk.shielded,
		"winding": winding,
		"progress": clampi(w.actors.state_t[i] * 1000 / maxi(1, total), 0, 1000)
	}


## Tick phase 6: marker k strikes on active tick k × mark_gap_ticks, once, where it locked (each marker may hit;
## the player's hurt iframes still apply).
static func resolve_marks(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var p := w.player_pos()
	var pr := w.player.radius_m
	for k in atk.count:
		if atk.pattern != null and atk.egg_ticks <= 0:  # v0.8.0 BS1: an egg bursts on its own clock
			burst_mark(w, i, atk, k, st - k * atk.mark_gap_ticks)
		if atk.pillar_ticks > 0 and st == k * atk.mark_gap_ticks + 1:
			# v0.8.0 BS1 (S1): the spikes stay as pillars, the tick after the strike (the strike's own lanes,
			# drawn and hit on its tick, are never cut short by its pillars).
			BossSignatures.raise_pillars(w, i, atk, k)
		if st != k * atk.mark_gap_ticks:
			continue
		w.bosses.hit[b] = 0
		if atk.move == BossAttackTable.Move.MARKS:
			var c := mark_of(w, i, k)
			if AttackShapes.disc_touches(c, atk.radius_m, p, pr):
				BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, c)
			BossSignatures.lay_egg(w, b, atk, c)  # v0.8.0 BS1 (S3): the egg stays, to pop or to hatch
			BossTide.undertow(w, atk, c)  # v0.9.0 NB1: the Undertow drags the player toward it
			BossShade.snuff(w, atk, c)  # v0.9.0 NB4: the Snuff puts out the lantern nearest it
		else:
			for o: Obb in row_lanes_of(w, i, k):
				if Collide.circle_vs_obb(p, pr, o) != Vector2.ZERO:
					BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, o.center)
					break


## v0.7.5 BF2 (the Brood Mother's Egg Storm): marker k of a `marks` attack with a pattern is an egg's landing; `local`
## ticks after it struck (0 = the strike) the pattern's waves burst from it (its lob was the marker's lock), aimed
## at where the player stands then (the pattern's aim offset puts the player in a gap), from egg_r out of its
## centre. BulletPatterns.fire leaves out the shots that would spawn on the player.
static func burst_mark(w: World, i: int, atk: BossAttackTable, k: int, local: int) -> void:
	var pat := atk.pattern
	if local < 0:
		return
	var kw := BulletPatterns.wave_at(pat, local + pat.lob_ticks)
	if kw < 0:
		return
	var c := mark_of(w, i, k)
	BulletPatterns.fire(
		w, i, pat, kw, c, Kin.angle_of(w.player_pos() - c), egg_r(atk), BossAi.orb_damage(w, i, atk)
	)


## v0.7.5 BF2: how far from a landing's (or an eruption's) centre its burst's shots appear: half its circle.
static func egg_r(atk: BossAttackTable) -> float:
	return atk.radius_m * 0.5


## v0.7.5 BF2: a burrow with a lock (the Brood Mother's): its eruption circle follows the player's exact position
## while the ripple tracks (BossStore point 0); it locks there for the lock.
static func tracked_burrow(atk: BossAttackTable) -> bool:
	return atk.move == BossAttackTable.Move.BURROW and atk.lock_ticks > 0


## v0.7.5 BF2: a burrow's eruption burst (its pattern, a ring), `st` ticks after it erupted at `c`, aimed at the
## player (a ring's gap is centred on its aim).
static func burst_eruption(w: World, i: int, atk: BossAttackTable, c: Vector2, st: int) -> void:
	var pat := atk.pattern
	if pat == null:
		return
	var kw := BulletPatterns.wave_at(pat, st + pat.lob_ticks)
	if kw < 0:
		return
	BulletPatterns.fire(
		w, i, pat, kw, c, Kin.angle_of(w.player_pos() - c), egg_r(atk), BossAi.orb_damage(w, i, atk)
	)


## v0.7.5 BF2: ticks a burrow's eruption lasts (its burst's waves; 1 without a pattern).
static func eruption_ticks(atk: BossAttackTable) -> int:
	if atk.pattern == null:
		return 1
	return atk.pattern.duration_ticks() - atk.pattern.lob_ticks


## v0.7.5 BF3: the circles of volley k of a `grid` attack: the cells of the count × count board (cell_m apart,
## centred where the windup locked, on the player) whose colour is k's (even volleys hold the centre cell, the
## player's), leaving out a cell whose centre is in a wall. Drawn and struck alike (EI-07).
static func grid_discs(w: World, i: int, k: int) -> PackedVector2Array:
	var atk := BossAi.attack_of(w, i)
	var c := mark_of(w, i, 0)
	var h := atk.count / 2
	var out := PackedVector2Array()
	for y in range(-h, h + 1):
		for x in range(-h, h + 1):
			if absi(x + y) % 2 != k % 2:
				continue
			var at := c + Vector2(x, y) * atk.cell_m
			if EnemyAi.clear_of_walls(w, at, 0.05):
				out.append(at)
	return out


## v0.7.5 BF3: volley k's state `t` ticks into a grid attack (mark_state's codes): the first volley's board tracks the
## player until the lock; each later volley (the board stays where it locked) shows only for its own lock_ticks
## before it strikes, so one colour flashes at a time.
static func grid_state(atk: BossAttackTable, k: int, t: int) -> int:
	var strike := k * atk.mark_gap_ticks + atk.windup_ticks
	if k > 0 and t < strike - atk.lock_ticks:
		return -1
	if t < atk.windup_ticks - atk.lock_ticks:
		return 0
	if t < strike:
		return 1
	return 2 if t == strike else 3


## v0.7.5 BF3: a grid's telegraph: &"marks" with one disc item per circle of each volley showing now (its progress
## over its own showing time: the whole windup for the first, the lock for the later ones).
static func grid_telegraph(w: World, i: int, atk: BossAttackTable) -> Dictionary:
	var t := attack_ticks(w, i, atk)
	var items: Array[Dictionary] = []
	var first := -1
	var locked := false
	for k in atk.volleys:
		var st := grid_state(atk, k, t)
		if st < 0 or st > 2:
			continue
		var span := atk.windup_ticks if k == 0 else atk.lock_ticks
		var t0 := k * atk.mark_gap_ticks + atk.windup_ticks - span
		var pr := clampi((t - t0) * 1000 / maxi(1, span), 0, 1000)
		if first < 0:
			first = pr
			locked = st >= 1
		for c: Vector2 in grid_discs(w, i, k):
			items.append(
				{
					"shape": &"disc",
					"center": c,
					"radius": atk.radius_m,
					"locked": st >= 1,
					"progress": pr
				}
			)
	if items.is_empty():
		return {}
	return {
		"shape": &"marks",
		"items": items,
		"progress": first,
		"move": atk.move,
		"tracked": true,
		"locked": locked
	}


## Tick phase 6 (v0.7.5 BF3): volley k of a grid strikes on active tick k × mark_gap_ticks, once, on its colour's
## circles (each volley may hit; the hurt iframes still apply).
static func resolve_grid(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var gap := maxi(1, atk.mark_gap_ticks)
	if st % gap != 0 or st / gap >= atk.volleys:
		return
	w.bosses.hit[b] = 0
	var p := w.player_pos()
	for c: Vector2 in grid_discs(w, i, st / gap):
		if AttackShapes.disc_touches(c, atk.radius_m, p, w.player.radius_m):
			BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, c)
			return


## v0.7.5 BF3: molten flood lane k of a `row_flood` attack: along the row (x) through the tracked point, offset
## gap_m × (k - (count - 1) / 2) in y, reaching length_m / 2 each way from the player's x unless a wall cuts it
## short.
static func row_flood_of(w: World, i: int, k: int) -> Obb:
	var atk := BossAi.attack_of(w, i)
	var c := mark_of(w, i, 0) + Vector2(0.0, atk.gap_m * (k - (atk.count - 1) * 0.5))
	var fwd := EnemyAi.clear_run(w, c, 0, atk.length_m * 0.5, atk.half_width_m)
	var back := EnemyAi.clear_run(w, c, 2048, atk.length_m * 0.5, atk.half_width_m)
	return AttackShapes.lane(c - Vector2(back, 0.0), 0, maxf(fwd + back, 0.01), atk.half_width_m)


## v0.7.5 BF3: a raining pattern's drops in the air now (a FLOWER with rain_ticks: each wave is thrown up from the
## body as the wave starts and lands, as a shot, rain_ticks later): [from, to, progress 0..1, progress a tick] per
## drop, where wave_shots puts it. Pure; for the views only (a drop hurts once it has landed).
static func rain_drops(w: World, i: int) -> Array:
	var out := []
	var atk := BossAi.attack_of(w, i)
	if atk == null or atk.pattern == null or w.actors.state[i] != EnemyAi.State.ACTIVE:
		return out
	var pat := atk.pattern
	if pat.rain_ticks <= 0:
		return out
	var st := w.actors.state_t[i]
	var from := w.actors.pos(i)
	var r := w.actors.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M
	var step := 1.0 / pat.rain_ticks
	for k in pat.waves:
		var t := st - k * pat.wave_gap_ticks
		if t < 0 or t >= pat.rain_ticks:
			continue
		var shots := BulletPatterns.wave_shots(pat, k, from, w.actors.lock_a[i], r)
		for to: Vector2 in shots[0]:
			out.append([from, to, float(t) / pat.rain_ticks, step])
	return out
