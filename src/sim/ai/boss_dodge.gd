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
## between patterns.
static func shielded(w: World, i: int) -> bool:
	if not BossAi.is_boss_kind(w.actors.kinds[i]):
		return false
	var s := w.actors.state[i]
	if s != EnemyAi.State.WINDUP and s != EnemyAi.State.ACTIVE:
		return false
	var atk := BossAi.attack_of(w, i)
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
	BulletPatterns.fire(
		w, i, pat, k, origin, w.actors.lock_a[i], r, BossAi.powered(w, i, atk.damage)
	)


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


## v0.7.5 BF1: a pattern draws nothing on the ground but a burst's landing marker (and its flying shell).
static func pattern_telegraph(
	w: World, i: int, b: int, atk: BossAttackTable, windup: bool, progress: int
) -> Dictionary:
	var pat := atk.pattern
	if pat == null or pat.kind != BulletPatternTable.Kind.BURST:
		return {}
	var st := w.actors.state_t[i]
	if not windup and st > pat.lob_ticks:
		return {}
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
		if st != k * atk.mark_gap_ticks:
			continue
		w.bosses.hit[b] = 0
		if atk.move == BossAttackTable.Move.MARKS:
			var c := mark_of(w, i, k)
			if AttackShapes.disc_touches(c, atk.radius_m, p, pr):
				BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, c)
		else:
			for o: Obb in row_lanes_of(w, i, k):
				if Collide.circle_vs_obb(p, pr, o) != Vector2.ZERO:
					BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, o.center)
					break
