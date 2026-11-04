extends GutTest
## v0.10.5 W3-O2 (owner F19, F20, 2026-11-04). F19, the Foundry: its floor lines (a flood or row_flood, telegraphed
## or burning, and the lava it leaves) and its shots never share the floor (BossLava.closes_escape), over whole
## fights on several seeds; the same fights without the rule do overlap (so the check can see it). F20, the Hive
## Lens: every Gaze opens BossGaze.LEAD behind the player in the way it turns, and so sweeps through a player who
## stands still within LEAD / speed.

const S := EnemyAi.State
const M := BossAttackTable.Move
const LONG := 1 << 20
const SEEDS := [3, 17, 41]
## The fight's length per seed (3 minutes), its HP stepped down a phase each minute.
const FIGHT_TICKS := 3 * 3600


## A boss `id` at the origin in a square room of half size 11 (as a sealed boss room's), the player at (6, 4), never
## dying.
func _fight(id: StringName, seed_value: int) -> Array:
	var w := BossLab.world(seed_value)
	var half := 11.0
	var t := 0.5
	var walls: Array[Obb] = [
		Obb.make(Vector2(half + t, 0), Vector2(t, half + 2.0 * t), 0),
		Obb.make(Vector2(-half - t, 0), Vector2(t, half + 2.0 * t), 0),
		Obb.make(Vector2(0, half + t), Vector2(half + 2.0 * t, t), 0),
		Obb.make(Vector2(0, -half - t), Vector2(half + 2.0 * t, t), 0),
	]
	w.set_walls(walls)
	w.bosses.arena = Rect2(-half, -half, half * 2.0, half * 2.0)
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, Vector2(6, 4))
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


## The player's input on tick k: walking, a new one of 8 ways every 75 ticks (seeded by the tick, no stream).
func _walk(k: int) -> InputFrame:
	var ways := [
		Vector2i(80, 0),
		Vector2i(56, 56),
		Vector2i(0, 80),
		Vector2i(-56, 56),
		Vector2i(-80, 0),
		Vector2i(-56, -56),
		Vector2i(0, -80),
		Vector2i(56, -56),
	]
	return InputFrame.make(ways[(k / 75 * 5) % 8], 0, 300, 0, 0)


## Steps one whole fight; the boss's HP drops to each next phase every minute. Returns [overlap ticks, line attacks
## started, volleys started, ticks with lava down].
func _foundry_fight(seed_value: int, rule: bool) -> Array:
	var s := _fight(&"foundry", seed_value)
	var w: World = s[0]
	var aid: int = s[1]
	BossAi.table_of(w, w.actors.index_of(aid)).lines_clear_shots = rule
	var overlap := 0
	var lines := 0
	var volleys := 0
	var lava := 0
	for k in FIGHT_TICKS:
		var i := w.actors.index_of(aid)
		if k == 3600 or k == 7200:
			w.actors.hp[i] = w.actors.max_hp[i] * (650 if k == 3600 else 320) / 1000
		w.actors.hp[0] = LONG
		w.step(_walk(k))
		i = w.actors.index_of(aid)
		var atk := BossAi.attack_of(w, i)
		var st := w.actors.state[i]
		var line_up := (
			atk != null
			and (atk.move == M.FLOOD or atk.move == M.ROW_FLOOD)
			and (st == S.WINDUP or st == S.ACTIVE)
		)
		var lava_down := BossLava.lava_out(w, i)
		if lava_down:
			lava += 1
		if (line_up or lava_down) and BossLava.shots_out(w, i):
			overlap += 1
		if st == S.WINDUP and w.actors.state_t[i] == 0 and atk != null:
			if atk.move == M.FLOOD or atk.move == M.ROW_FLOOD:
				lines += 1
			elif atk.move == M.PATTERN:
				volleys += 1
	return [overlap, lines, volleys, lava]


func test_the_foundrys_lines_and_shots_never_share_the_floor() -> void:
	var lines := 0
	var volleys := 0
	for seed_value: int in SEEDS:
		var r := _foundry_fight(seed_value, true)
		assert_eq(
			r[0], 0, "seed %d: no tick with its lines or lava down while its shots fly" % seed_value
		)
		lines += r[1]
		volleys += r[2]
		assert_gt(r[3], 0, "seed %d: lava was laid" % seed_value)
	assert_gt(lines, 6, "the lines still come (%d)" % lines)
	assert_gt(volleys, 6, "and so do the volleys (%d)" % volleys)


func test_without_the_rule_the_same_fights_overlap() -> void:
	var overlap := 0
	for seed_value: int in SEEDS:
		overlap += _foundry_fight(seed_value, false)[0]
	assert_gt(overlap, 0, "the check sees an overlap when the rule is off (%d ticks)" % overlap)


func test_a_held_line_waits_for_the_shots_then_comes() -> void:
	var s := _fight(&"foundry", 5)
	var w: World = s[0]
	var aid: int = s[1]
	var i := w.actors.index_of(aid)
	var t := BossAi.table_of(w, i)
	var flood := t.attack_index(&"molten_flood")
	w.actors.cd[i] = LONG  # it picks nothing of its own while the test sets up
	w.queue_projectile(
		aid,
		ActorStore.TEAM_ENEMY,
		Vector2(-8, -8),
		Vector2(0.01, 0),
		5,
		0.2,
		90,
		SimEvent.TAG_PROJECTILE
	)
	CombatLab.idle(w, 1)
	assert_true(BossLava.shots_out(w, i), "one of its shots flies")
	assert_true(BossLava.closes_escape(w, i, flood), "a line must wait")
	assert_false(BossLava.closes_escape(w, i, t.attack_index(&"vent_blast")), "a blast need not")
	w.bosses.entry[BossAi.entry_of(w, i)] = flood
	w.actors.cd[i] = 0
	for k in 60:
		CombatLab.idle(w, 1)
		i = w.actors.index_of(aid)
		assert_eq(
			w.bosses.attack[BossAi.entry_of(w, i)], -1, "tick %d: it waits while the shot flies" % k
		)
	CombatLab.until(
		w,
		func(x: World) -> bool:
			return x.bosses.attack[BossAi.entry_of(x, x.actors.index_of(aid))] >= 0,
		120
	)
	i = w.actors.index_of(aid)
	assert_false(BossLava.shots_out(w, i), "the shot is gone")
	assert_eq(w.bosses.attack[BossAi.entry_of(w, i)], flood, "then the held line comes")


## Every Gaze start in fights on several seeds (the player walking): its beam opens LEAD behind the player in the way
## it turns.
func test_every_gaze_opens_just_behind_you_in_its_turn() -> void:
	var gazes := 0
	var ways := {}
	for seed_value: int in SEEDS:
		var s := _fight(&"hive_lens", seed_value)
		var w: World = s[0]
		var aid: int = s[1]
		for k in FIGHT_TICKS:
			var i := w.actors.index_of(aid)
			if k == 3600 or k == 7200:
				w.actors.hp[i] = w.actors.max_hp[i] * (650 if k == 3600 else 320) / 1000
			w.actors.hp[0] = LONG
			w.step(_walk(k))
			i = w.actors.index_of(aid)
			var atk := BossAi.attack_of(w, i)
			if atk == null or atk.move != M.GAZE:
				continue
			if w.actors.state[i] != S.ACTIVE or w.actors.state_t[i] != 0:
				continue
			gazes += 1
			var way := w.bosses.span[BossAi.entry_of(w, i)]
			ways[way] = true
			var to_player := Kin.angle_of(w.player_pos() - w.actors.pos(i))
			var off := (((to_player - w.actors.lock_a[i]) & 4095) + 2048) % 4096 - 2048
			var label := "seed %d tick %d" % [seed_value, k]
			assert_gt(off * way, 0, "%s: it starts behind you in its turn (off %d)" % [label, off])
			assert_almost_eq(
				absi(off), BossGaze.LEAD, 80, "%s: about 40 degrees short of you" % label
			)
	assert_gt(gazes, 4, "the gaze came (%d)" % gazes)
	assert_eq(ways.size(), 2, "both ways")


func test_the_gaze_sweeps_through_a_player_who_stands_still() -> void:
	for seed_value: int in [1, 2, 3, 4]:
		var s := _fight(&"hive_lens", seed_value)
		var w: World = s[0]
		var aid: int = s[1]
		w.actors.set_pos(0, Vector2(-5, 2))
		BossLab.start(w, w.actors.index_of(aid), &"gaze")
		var atk := BossAi.attack_of(w, w.actors.index_of(aid))
		CombatLab.until(
			w,
			func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.ACTIVE,
			200
		)
		var before := CombatLab.player_damage(w).size()
		var reach := BossGaze.LEAD * atk.quarter_ticks / 1024
		CombatLab.idle(w, reach - 20)
		assert_eq(
			CombatLab.player_damage(w).size(),
			before,
			"seed %d: not on you as it opens" % seed_value
		)
		CombatLab.idle(w, 40)
		assert_gt(
			CombatLab.player_damage(w).size(), before, "seed %d: it sweeps through you" % seed_value
		)
