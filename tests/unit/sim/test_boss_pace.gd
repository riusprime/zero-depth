extends GutTest
## v0.8.0 BP (owner O27, O38; PLAN step BP): the sped-up boss attacks stay dashable, a big attack is followed by a
## still punish window, and the Blade at the base build kills every boss. Scripted players, not the bot balance suite:
## - the dodge: the hero stands at a distance in the attack's range band; 0.3 s after the telegraph appears (a human
##   reaction), or when its aim stops following if that is later, it dashes (data/player/runner.tres: 4 m in 0.15 s,
##   i-frames 0.15 s) and keeps running the same way; the attack must not touch it, for at least one of left, right,
##   away from or toward the boss (into a ring's safe middle), at a near and a far distance;
## - the kill: BladeRun below (the hero's HP is set out of reach: this proves the windows give the Blade the time to
##   kill, not that a script survives; the hits it took are printed for the evidence).

const S := EnemyAi.State
## The hero reacts this long after a telegraph appears (ticks).
const REACT_TICKS := 18
## The sped-up attacks (tests/content/test_boss_pace.gd SPED_UP).
const SPED_UP := {
	&"gatekeeper": [&"fist_slam", &"fist_slam_2", &"fist_slam_3"],
	&"warlord": [&"javelin_fan", &"javelin_fan_fast", &"lunge_dash"],
	&"brood_mother": [&"leap", &"leap_chain", &"pounce_chain"],
	&"hive_lens": [&"dive", &"focus_beam", &"focus_beam_3"],
	&"siege_engine": [&"rail", &"rail_3", &"shockwave"],
	&"foundry": [&"vent_blast", &"bomb_launch", &"bomb_launch_3"],
	&"colossus": [&"leap_slam", &"leap_slam_2", &"boulder_throw", &"boulder_throw_3"],
}
## The six floor bosses.
const BOSSES: Array[StringName] = [
	&"gatekeeper", &"warlord", &"brood_mother", &"hive_lens", &"siege_engine", &"foundry"
]
## The Blade must kill each of the six within this (ticks: 3 minutes of fight at the data's HP, loop 1).
const KILL_LIMIT := 10800
## The final boss's three bodies within this (ticks: 10 minutes; v0.8.0 N2, owner O41: each body 1-3 min, the base build
## about 2 min each).
const FINAL_LIMIT := 36000


static func _repo() -> ContentRepository:
	return ContentRepository.load_all()


## An open-plane world with the base Blade build (data/player/runner.tres + data/builds/blade.tres, the heat on), the
## real enemies and bosses, unscaled (the data's numbers).
static func _world(seed_value: int = 5) -> World:
	var repo := _repo()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"blade"))
	var w := World.new(seed_value, t)
	w.set_enemy_tables(ContentCompiler.compile_enemies(repo))
	var bosses := ContentCompiler.compile_bosses(repo)
	var run := ContentCompiler.compile_run(repo.get_def(&"run", RunSaver.RUN_ID))
	bosses.append_array(ContentCompiler.compile_final_bosses(repo, run))  # the Colossus's moves on an open plane
	w.set_boss_tables(bosses)
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.wand_table = WandCompiler.from_repo(repo)
	w.blade_table = BladeCompiler.from_repo(repo)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	w.tuning = RunContentCompiler.compile_sim_tuning(repo.get_def(&"tuning", &"sim"))
	return w


static func _frame(dir: Vector2, aim: Vector2, pressed: int) -> InputFrame:
	return BladeRun.frame_of(dir, aim, pressed)


## Runs attack `attack_id` of boss `id` at the hero `dist` m away, the hero dashing `way` (0 left, 1 right, 2 away,
## 3 toward) at its reaction tick and running on. Returns [the damage it took, the dash tick].
func _dodge(id: StringName, attack_id: StringName, dist: float, way: int) -> Array:
	var w := _world()
	var i := BossLab.ready_boss(w, id)
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(dist, 0))
	var t := BossAi.table_of(w, i)
	var atk := t.attacks[t.attack_index(attack_id)]
	BossLab.start(w, i, attack_id)
	var hp0 := w.actors.hp[0]
	var dir := [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)][way] as Vector2
	var commit := atk.lock_ticks if atk.lock_ticks > 0 else t.commit_ticks
	var at := REACT_TICKS
	if BossAi.TRACKING_MOVES.has(atk.move):
		at = maxi(at, atk.windup_ticks - commit)
	var running := false
	var dashed := -1
	for n in 900:
		i = w.actors.index_of(aid)
		if i < 0 or w.player_dead():
			break
		var b := BossAi.entry_of(w, i)
		if w.bosses.attack[b] < 0 or w.actors.state[i] == S.MOVE:
			break
		var pressed := 0
		if w.actors.state[i] == S.WINDUP and w.actors.state_t[i] == at:
			running = true
			if w.dash_cooldown_left == 0:
				pressed = InputFrame.DASH
				dashed = n if dashed < 0 else dashed
		w.step(_frame(dir if running else Vector2.ZERO, dir, pressed))
	return [hp0 - w.actors.hp[0], dashed]


func test_each_sped_up_attack_is_dashable_after_its_telegraph() -> void:
	for id: StringName in SPED_UP:
		var w0 := _world()
		var t := w0.boss_tables[BossLab.table_index(w0, id)]
		for attack_id: StringName in SPED_UP[id]:
			var atk := t.attacks[t.attack_index(attack_id)]
			var near := maxf(atk.min_range_m + 0.5, t.radius_m + 1.2)
			var far := minf(atk.max_range_m - 0.5, 8.0)
			for dist: float in [near, far]:
				var ways := []
				for way in 4:
					var r := _dodge(id, attack_id, dist, way)
					assert_gte(r[1], 0, "%s %s: the hero dashed" % [id, attack_id])
					if r[0] == 0:
						ways.append(["left", "right", "away", "toward"][way])
				gut.p("BP dodge %s %s at %.1f m: clean by %s" % [id, attack_id, dist, ways])
				assert_false(ways.is_empty(), "%s %s at %.1f m is dashable" % [id, attack_id, dist])


## v0.8.0 BP: after a big attack the boss holds still in its recovery for its whole window, attacking nothing, its weak
## point open.
func test_a_big_attack_is_followed_by_a_still_punish_window() -> void:
	var bigs := {}
	for def: BossDefinition in _repo().all_of(&"bosses"):
		for a in def.attacks:
			if a.hit_class == &"big":
				bigs[[def.id, a.id]] = true
	assert_eq(bigs.size(), 12, "v0.9.0 NB1: the Tidecaller's Shell Slam")
	for key: Array in bigs:
		var w := _world()
		var i := BossLab.ready_boss(w, key[0])
		var aid := w.actors.ids[i]
		var t := BossAi.table_of(w, i)
		var atk := t.attacks[t.attack_index(key[1])]
		w.actors.set_pos(0, Vector2(maxf(atk.min_range_m + 0.5, t.radius_m + 2.5), 0))
		w.actors.hp[0] = 1000000
		w.actors.max_hp[0] = 1000000
		BossLab.start(w, i, key[1])
		var n := CombatLab.until(
			w,
			func(_w: World) -> bool: return w.actors.state[w.actors.index_of(aid)] == S.RECOVER,
			900
		)
		assert_lt(n, 900, "%s %s recovers" % key)
		i = w.actors.index_of(aid)
		var at := w.actors.pos(i)
		var b := BossAi.entry_of(w, i)
		assert_gt(w.bosses.exposed_t[b], 0, "%s %s: its weak point opens" % key)
		var still := 0
		for k in atk.recover_ticks:
			i = w.actors.index_of(aid)
			if w.actors.state[i] != S.RECOVER or w.actors.pos(i) != at:
				break
			still += 1
			w.step(InputFrame.new())
		assert_eq(still, atk.recover_ticks, "%s %s: still for its whole window" % key)
		assert_between(still, BossSchemas.PUNISH_MIN_TICKS, BossSchemas.PUNISH_MAX_TICKS)


func test_the_blade_kills_every_boss_in_its_windows() -> void:
	var bigs := {}
	for def: BossDefinition in _repo().all_of(&"bosses"):
		for a in def.attacks:
			if a.hit_class == &"big":
				bigs[a.id] = true
	for id: StringName in BOSSES:
		var w := _world(9)
		var i := BossLab.ready_boss(w, id)
		var aid := w.actors.ids[i]
		w.actors.set_pos(0, Vector2(6, 0))
		var bot := BladeRun.new(aid, bigs)
		var n := bot.fight(w, KILL_LIMIT, func(_w: World) -> bool: return bot.boss_dead(w))
		gut.p(
			(
				"BP blade %s: killed=%s in %.1f s, %d swings, %d dashes, hits taken %d (%d damage)"
				% [id, bot.boss_dead(w), n / 60.0, bot.swings, bot.dashes, bot.hits, bot.taken]
			)
		)
		assert_true(bot.boss_dead(w), "%s: the Blade kills it within %d s" % [id, KILL_LIMIT / 60])


## The final boss (FinalLab's arena: the run's last floor at loop 1, scaled as a run scales it, the Blade build): the
## same hero beats the Colossus, the Prism and the Nemesis one after the other.
func test_the_blade_beats_the_final_boss() -> void:
	var bigs := {}
	for id: StringName in [&"colossus", &"prism", &"nemesis"]:
		for a in (_repo().get_def(&"final_bosses", id) as BossDefinition).attacks:
			if a.hit_class == &"big":
				bigs[a.id] = true
	assert_eq(bigs.size(), 6, "the Colossus's three leap slams, The Fallen's three cards (N2)")
	var w := FinalLab.arena(FinalLab.run_state(21, &"blade"))
	FinalLab.past_rise(w)
	var bot := BladeRun.new(-1, bigs)
	var bodies := []
	var n := bot.fight(
		w,
		FINAL_LIMIT,
		func(_w: World) -> bool:
			var i := FinalLab.body(w)
			if i >= 0 and w.actors.ids[i] != bot.aid:
				bot.aid = w.actors.ids[i]
				bodies.append([w.actors.kinds[i], w.tick])
			return w.final_fight.won
	)
	(
		gut
		. p(
			(
				"BP blade final: won=%s in %.1f s, bodies %s, %d swings, %d dashes, hits taken %d (%d damage)"
				% [w.final_fight.won, n / 60.0, bodies, bot.swings, bot.dashes, bot.hits, bot.taken]
			)
		)
	)
	assert_true(
		w.final_fight.won, "the Blade beats the final boss within %d s" % (FINAL_LIMIT / 60)
	)


## The scripted Blade-only hero: it stands at the boss's side in melee reach and swings while the boss can be hurt; when
## a big attack is LATE_TICKS from striking (and its aim has stopped following), it dashes and runs on for FLEE_TICKS
## (a slam's ring: out of it, or into its safe middle; anything else: across; a leap: until it lands), then comes back.
## It never shoots, uses no skill or utility. fight() heals it to full before every tick (its own max HP stays, which
## the Nemesis reads), so it never dies; the hits and damage it took are counted.
class BladeRun:
	extends RefCounted
	## It dashes this long before the strike (or at the lock, if later), and runs on this long after the dash.
	const LATE_TICKS := 12
	const FLEE_TICKS := 16
	var aid := 0
	var bigs := {}
	var swings := 0
	var dashes := 0
	var hits := 0
	var taken := 0
	var _flee := Vector2.ZERO
	var _flee_attack := -1
	var _flee_t := 0

	func _init(p_aid: int, p_bigs: Dictionary) -> void:
		aid = p_aid
		bigs = p_bigs

	static func frame_of(dir: Vector2, aim: Vector2, pressed: int) -> InputFrame:
		var mv := Vector2i(int(round(dir.x * 127.0)), int(round(dir.y * 127.0)))
		return InputFrame.make(mv, Kin.angle_of(aim), 300, 0, pressed)

	func boss_dead(w: World) -> bool:
		var i := w.actors.index_of(aid)
		return i < 0 or w.actors.dead[i] == 1

	## Steps w with this hero until `done` (called before each tick) or `limit` ticks; returns the ticks run.
	func fight(w: World, limit: int, done: Callable) -> int:
		var n := 0
		while n < limit and not done.call(w):
			w.actors.hp[0] = w.actors.max_hp[0]
			var i := w.actors.index_of(aid)
			var f := frame(w) if i >= 0 and w.actors.dead[i] == 0 else InputFrame.new()
			w.step(f)
			var lost := w.actors.max_hp[0] - w.actors.hp[0]
			if lost > 0:
				hits += 1
				taken += lost
			n += 1
		return n

	func frame(w: World) -> InputFrame:
		var i := w.actors.index_of(aid)
		var p := w.player_pos()
		var at := w.actors.pos(i)
		var to := at - p
		var dist := Kin.length(to)
		var b := BossAi.entry_of(w, i)
		var atk := BossAi.attack_of(w, i)
		var st := w.actors.state[i]
		var pressed := 0
		if atk != null and (st == S.WINDUP or st == S.ACTIVE) and bigs.has(atk.id):
			var t := BossAi.table_of(w, i)
			var commit := atk.lock_ticks if atk.lock_ticks > 0 else t.commit_ticks
			var lock_at := maxi(REACT_TICKS, atk.windup_ticks - mini(commit, LATE_TICKS))
			var key := w.bosses.step[b] * 1000 + w.bosses.attack[b]
			if st == S.WINDUP and w.actors.state_t[i] >= lock_at and _flee_attack != key:
				_flee_attack = key
				_flee_t = 0
				var away := -to / maxf(dist, 0.001)
				_flee = Vector2(-away.y, away.x)
				if atk.move == BossAttackTable.Move.SLAM_RING:  # a ring with a safe middle: in; else out
					_flee = -away if atk.inner_radius_m > 0.0 else away
				if w.dash_cooldown_left == 0:
					pressed = InputFrame.DASH
					dashes += 1
			_flee_t += 1
			var landing := atk.move == BossAttackTable.Move.LEAP and st == S.ACTIVE  # it lands at the end
			if _flee != Vector2.ZERO and (_flee_t <= FLEE_TICKS or landing):
				return frame_of(_flee, to, pressed)
		else:
			_flee_attack = -1
		_flee = Vector2.ZERO
		var r := w.actors.radius[i]
		var side := Kin.dir(w.actors.facing[i] + 1024)
		var spot_a := at + side * (r + 0.8)
		var spot_b := at - side * (r + 0.8)
		var spot := spot_a if Kin.length(spot_a - p) <= Kin.length(spot_b - p) else spot_b
		var go := spot - p
		var mv := go / Kin.length(go) if Kin.length(go) > 0.25 else Vector2.ZERO
		var hurtable := not BossDodge.shielded(w, i) and st != BossAi.GATE and st != S.SPAWN
		if hurtable and dist <= r + 1.5 and w.tick % 4 == 0:
			pressed |= InputFrame.PRIMARY
			swings += 1
		return frame_of(mv, to, pressed)
