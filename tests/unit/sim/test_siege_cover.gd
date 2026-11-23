# gdlint: disable=max-public-methods
extends GutTest
## The Siege Engine's siege (BossSiege, BossDoom), in SiegeLab's walled 24 m room: the Target Lock that follows,
## lags, locks and lands; the boulders it leaves (their cap, their time, never on a body, never sealing anyone in,
## the hero pushed out); the turrets a shell destroys; the Shockwave that needs cover from the last phase (behind a
## boulder safe, beside it hit, hugging the Engine no longer safe), its cap and its wait for cover; the Doom Shell's
## cart (it arrives and the shell fires; destroyed far away; destroyed against the Engine, which strips its armour);
## what ends with the fight; determinism and a save.

const S := EnemyAi.State
const NEVER := SiegeLab.NEVER


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _fx(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	return JudgeLab.effects(w, effect, seq)


func _state(w: World) -> Dictionary:
	return WorldReader.new(w).boss_siege()


## Steps `n` ticks, the hero idle and refilled each tick. Returns the HP it lost.
func _idle(w: World, n: int) -> int:
	var lost := 0
	for k in n:
		w.step(InputFrame.new())
		lost += SiegeLab.take_lost(w)
	return lost


## Steps until an event with `effect` (after `seq`) exists, the hero idle and refilled. Returns it, or null.
func _until(w: World, effect: StringName, limit: int, seq: int = 0) -> SimEvent:
	for k in limit:
		var found := _fx(w, effect, seq)
		if not found.is_empty():
			return found[0]
		w.step(InputFrame.new())
		SiegeLab.take_lost(w)
	var last := _fx(w, effect, seq)
	return last[0] if not last.is_empty() else null


# --- content --------------------------------------------------------------------------------------------------


func test_the_data_is_valid_and_compiles_to_the_brief() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"siege_engine")
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	var st := t.siege
	assert_not_null(st)
	assert_eq(
		[
			st.lock_phase,
			st.lock_first_ticks,
			st.lock_every_ticks,
			st.lock_ticks,
			st.lock_hold_ticks
		],
		[1, 360, 840, 240, 36],
		"the Target Lock: from phase 2, 6 s in, every 14 s, 4 s long, locked for the last 0.6 s"
	)
	assert_almost_eq(st.lock_radius_m, 2.2, 0.0001)
	assert_eq([st.lock_follow, st.lock_hit], [800, 350])
	assert_almost_eq(st.boulder_half, 1.5, 0.0001, "3 m across")
	assert_eq([st.boulder_ticks, st.boulder_max], [1800, 4])
	assert_eq([st.cover_phase, st.shock_cap], [2, 400])
	assert_eq(
		[st.doom_phase, st.doom_first_ticks, st.doom_every_ticks, st.carts_in(1), st.carts_in(2)],
		[1, 840, 2100, 1, 2],
		"once in phase 2, twice in phase 3"
	)
	assert_eq([st.cart_hp, st.cart_ticks, st.doom_ticks, st.doom_hit], [60, 600, 60, 400])
	assert_almost_eq(st.cart_radius_m, 1.0, 0.0001)
	assert_almost_eq(st.cart_blast_m, 6.0, 0.0001)
	assert_eq([st.cart_blast_hit, st.strip_ticks, st.strip_taken], [250, 480, 1500])
	assert_eq(st.carts_in(0), 0, "none in phase 1")
	assert_eq(st.cart_kind, ActorStore.Kind.WARDEN)
	assert_eq(st.turret_kind, ActorStore.Kind.NEEDLE, "the deployed turrets")
	assert_eq(t.attacks[st.shell_cause].move, BossAttackTable.Move.MARKS, "the recap's shells")
	assert_eq(t.attacks[st.shell_cause].cause_key, &"CAUSE_SIEGE_BARRAGE")
	var shock := t.attacks[t.attack_index(&"shockwave")]
	assert_eq(shock.windup_ticks, 120, "the Shockwave's telegraph is 2 s")
	for hit in [st.lock_hit, st.shock_cap, st.doom_hit, st.cart_blast_hit]:
		assert_lte(hit, SiegeRules.MAX_HIT, "no single hit over 40 % of max HP")


func test_the_rules_refuse_a_bad_siege() -> void:
	var repo := ContentRepository.load_all()
	var base: BossDefinition = repo.get_def(&"bosses", &"siege_engine")
	var bad := {
		"an unknown key": {"lock_strength": 3},
		"a shell over 40 %": {"lock_permille": 401},
		"a Doom Shell over 40 %": {"doom_permille": 500},
		"a hold longer than the lock": {"lock_hold_seconds": 4.0},
		"locks closer than their length": {"lock_every_seconds": 4.0},
		"carts closer than their roll": {"doom_every_seconds": 10.5},
		"a lock under the telegraph minimum": {"lock_seconds": 0.2},
	}
	for why: String in bad:
		var def: BossDefinition = base.duplicate(true)
		var sg: Dictionary = base.siege.duplicate()
		sg.merge(bad[why], true)
		def.siege = sg
		assert_gt(def.validate().size(), 0, why)


# --- the Target Lock ------------------------------------------------------------------------------------------


func test_the_lock_starts_on_the_hero_follows_lagging_then_holds_and_lands_tick_exact() -> void:
	var s := SiegeLab.only(Vector2(-6, 0), Vector2(6, 0), 1, ["lock"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	var t0 := w.tick
	var lock := _until(w, BossSiege.LOCK, 400)
	assert_not_null(lock)
	assert_eq(lock.tick, t0 + st.lock_first_ticks, "6 s into phase 2")
	assert_eq(lock.amount, st.lock_ticks)
	assert_eq(BossSiege.lock_centre(w), w.player_pos(), "it starts on the hero")
	var c0 := BossSiege.lock_centre(w)
	w.actors.set_pos(0, Vector2(-6, 6))
	_idle(w, 30)
	var step := w.player.move_speed * 0.8
	var c1 := BossSiege.lock_centre(w)
	assert_almost_eq(c1.distance_to(c0), 30 * step, 0.001, "80 % of the hero's run speed: it lags")
	assert_almost_eq(c1.x, -6.0, 0.001, "straight toward the hero")
	var st0: Dictionary = _state(w)["lock"]
	assert_false(st0["locked"])
	assert_eq(st0["left"], st.lock_ticks - 31, "a read describes the tick about to run")
	_idle(w, st.lock_ticks - st.lock_hold_ticks - 30)
	assert_true(_state(w)["lock"]["locked"], "locked for its last 0.6 s")
	var held := BossSiege.lock_centre(w)
	w.actors.set_pos(0, Vector2(-6, -6))
	_idle(w, st.lock_hold_ticks - 1)
	assert_eq(BossSiege.lock_centre(w), held, "it holds still")
	assert_eq(_fx(w, BossSiege.SHELL).size(), 0)
	_idle(w, 1)
	var shell := _fx(w, BossSiege.SHELL)
	assert_eq(shell.size(), 1)
	assert_eq(shell[0].tick, lock.tick + st.lock_ticks, "it lands 4 s after it began")
	assert_eq(shell[0].amount, 0, "the hero walked out of it")
	assert_eq(_state(w)["lock"], {})
	assert_eq(
		_state(w)["lock_in"], lock.tick + st.lock_every_ticks - w.tick, "the next one 14 s on"
	)


func test_a_shell_hurts_a_hero_inside_and_leaves_a_boulder_it_is_pushed_out_of() -> void:
	var s := SiegeLab.only(Vector2(-6, 2), Vector2(6, 0), 1, ["lock"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	var lock := _until(w, BossSiege.LOCK, 400)
	var lost := 0
	for k in st.lock_ticks:
		w.step(InputFrame.new())
		lost += SiegeLab.take_lost(w)
	var shell := _fx(w, BossSiege.SHELL)
	assert_eq(shell.size(), 1)
	assert_eq(shell[0].amount, SafeArea.cost(w, st.lock_hit), "35 % of max HP")
	assert_eq(lost, shell[0].amount)
	var up := _fx(w, BossSiege.BOULDER_UP)
	assert_eq(up.size(), 1, "a boulder stands")
	assert_eq(up[0].pos, lock.pos, "on the circle (the hero stood still under it)")
	assert_eq(up[0].amount_applied, 1, "the hero was pushed out")
	var box := BossSiege.boulder_obb(w.boss_fight, 0)
	assert_eq(Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, box), Vector2.ZERO)
	assert_true(EnemyAi.clear_of_walls(w, w.player_pos(), w.player.radius_m), "on free floor")
	var rows: Array = _state(w)["boulders"]
	assert_eq(rows.size(), 1)
	assert_almost_eq(float(rows[0]["size"]), 3.0, 0.0001)
	assert_eq(rows[0]["left"], st.boulder_ticks - 1, "a read describes the tick about to run")
	var shot := Vector2(lock.pos.x - 4.0, lock.pos.y)
	w.actors.set_pos(0, Vector2(lock.pos.x + 3.0, lock.pos.y))
	assert_false(EnemyAi.sees_player(w, shot), "a wall: nothing sees through it")
	assert_true(EnemyAi.sees_player(w, Vector2(lock.pos.x + 6.0, lock.pos.y)), "from its side")


func test_boulders_are_capped_at_four_and_crumble_after_their_time() -> void:
	var s := SiegeLab.only(Vector2(-8, -8), Vector2(8, 0), 1, ["lock"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	st.lock_first_ticks = 1
	st.lock_every_ticks = st.lock_ticks + 10
	var spots: Array[Vector2] = [
		Vector2(-8, -8), Vector2(-8, 0), Vector2(-8, 8), Vector2(0, -8), Vector2(0, 8)
	]
	var seq := 0
	for k in spots.size():
		w.actors.set_pos(0, spots[k])
		var lock := _until(w, BossSiege.LOCK, st.lock_every_ticks + 5, seq)
		assert_not_null(lock)
		seq = lock.seq
		_until(w, BossSiege.SHELL, st.lock_ticks + 2, seq)
	assert_eq(_fx(w, BossSiege.BOULDER_UP).size(), 5, "five shells, five boulders")
	assert_eq(w.boss_fight.sg_b_x.size(), st.boulder_max, "four at most")
	var down := _fx(w, BossSiege.BOULDER_DOWN)
	assert_eq(down.size(), 1)
	assert_eq([down[0].amount, down[0].amount_applied], [0, BossSiege.END_CAP], "the oldest went")
	# Its time
	var walls := w.walls.size()
	var left := w.boss_fight.sg_b_until[0] - w.tick
	st.lock_phase = NEVER
	_idle(w, left)
	assert_eq(w.boss_fight.sg_b_x.size(), 4)
	_idle(w, 1)
	assert_eq(w.boss_fight.sg_b_x.size(), 3, "30 s after it landed")
	assert_eq(_fx(w, BossSiege.BOULDER_DOWN).back().amount_applied, BossSiege.END_EXPIRED)
	assert_eq(w.walls.size(), walls - 1, "its wall goes with it")


func test_a_shell_destroys_the_engines_turrets_under_it_without_a_kill() -> void:
	var s := SiegeLab.only(Vector2(-6, 0), Vector2(6, 0), 1, ["lock"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	var near := w.add_enemy(st.turret_kind, Vector2(-6, 1.6))
	var far := w.add_enemy(st.turret_kind, Vector2(-6, -6))
	var lock := _until(w, BossSiege.LOCK, 400)
	var tn := w.actors.index_of(near)
	assert_gt(tn, 0)
	# The turrets stand where they were put
	_idle(w, st.lock_ticks - 1)
	w.actors.set_pos(w.actors.index_of(near), Vector2(-6, 1.6))
	w.actors.set_pos(w.actors.index_of(far), Vector2(-6, -6))
	w.actors.set_pos(0, Vector2(-6, 0))
	var kills := w.kills
	_idle(w, 1)
	assert_eq(_fx(w, BossSiege.SHELL)[0].tick, lock.tick + st.lock_ticks)
	var gone := _fx(w, BossSiege.TURRET)
	assert_eq(gone.size(), 1, "one turret under the circle")
	assert_eq(gone[0].target_id, near)
	assert_eq(_fx(w, BossSiege.SHELL)[0].amount_applied, 1)
	assert_eq(w.actors.index_of(near), -1, "it is gone")
	assert_gt(w.actors.index_of(far), 0, "the other stands")
	assert_eq(w.kills, kills, "no kill for the hero")


## Steps a lock in `w` to the tick before its shell lands, puts the hero 0.9 m off the circle's centre and an enemy of
## `kind` at `offset` from it (on the floor the boulder will stand on). Returns [the lock's event, the enemy's id].
func _to_landing(w: World, st: BossSiegeTable, kind: int, offset: Vector2) -> Array:
	var lock := _until(w, BossSiege.LOCK, 400)
	_idle(w, st.lock_ticks - 1)
	var c := BossSiege.lock_centre(w)
	w.actors.set_pos(0, c + Vector2(0, -0.9))
	var id := w.add_enemy(kind, c + offset)
	w.actors.invuln[w.actors.index_of(id)] = 0  # Past its spawn-in, as one that walked there
	return [lock, id]


func test_an_enemy_by_the_hero_no_longer_denies_a_boulder_the_shell_kills_it() -> void:
	var s := SiegeLab.only(Vector2(-6, 0), Vector2(6, 0), 1, ["lock"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	var r := _to_landing(w, st, ActorStore.Kind.CHARGER, Vector2(0, 0.6))
	var lock: SimEvent = r[0]
	var add: int = r[1]
	var j := w.actors.index_of(add)
	w.actors.hp[j] = SafeArea.cost(w, st.lock_hit)  # An ordinary add: the shell's hit is all its HP
	_idle(w, 1)
	assert_eq(_fx(w, BossSiege.SHELL)[0].tick, lock.tick + st.lock_ticks, "it lands on time")
	j = w.actors.index_of(add)
	assert_true(j < 0 or w.actors.dead[j] == 1, "the add hugging the hero died under the shell")
	var up := _fx(w, BossSiege.BOULDER_UP)
	assert_eq(up.size(), 1, "and the boulder stands")
	assert_eq(up[0].tick, lock.tick + st.lock_ticks)
	assert_eq(up[0].amount_applied, 1, "the hero under it is still pushed out")
	var box := BossSiege.boulder_obb(w.boss_fight, 0)
	assert_eq(Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, box), Vector2.ZERO)
	var hits: Array[SimEvent] = []
	for e in w.events_since(lock.seq):
		if e.kind == SimEvent.Kind.DAMAGE and e.target_id == add:
			hits.append(e)
	assert_eq(hits.size(), 1, "the shell's hit")
	assert_eq(
		[hits[0].source_id, hits[0].effect_id], [s[1], BossSiege.SHELL_EFFECT], "the Engine's"
	)


func test_a_tough_enemy_under_a_shell_is_hurt_and_pushed_out_beside_the_boulder() -> void:
	var s := SiegeLab.only(Vector2(-6, 0), Vector2(6, 0), 1, ["lock"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	var r := _to_landing(w, st, ActorStore.Kind.CHARGER, Vector2(0.6, 0))
	var lock: SimEvent = r[0]
	var add: int = r[1]
	var j := w.actors.index_of(add)
	var hp := SafeArea.cost(w, st.lock_hit) * 10
	w.actors.max_hp[j] = hp
	w.actors.hp[j] = hp
	_idle(w, 1)
	j = w.actors.index_of(add)
	assert_gt(j, 0, "it lives")
	assert_eq(w.actors.dead[j], 0)
	assert_lt(w.actors.hp[j], hp, "hurt by the shell")
	var up := _fx(w, BossSiege.BOULDER_UP)
	assert_eq(up.size(), 1, "the boulder stands")
	assert_eq(up[0].tick, lock.tick + st.lock_ticks)
	var box := BossSiege.boulder_obb(w.boss_fight, 0)
	assert_eq(
		Collide.circle_vs_obb(w.actors.pos(j), w.actors.radius[j], box),
		Vector2.ZERO,
		"pushed out beside it"
	)
	assert_lt(w.actors.pos(j).distance_to(box.center), 3.5, "to the nearest free spot")
	assert_eq(Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, box), Vector2.ZERO)


func test_the_ammo_cart_and_the_engine_still_deny_a_boulder() -> void:
	var s := SiegeLab.only(Vector2(-6, 0), Vector2(6, 0), 1, ["lock"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	var r := _to_landing(w, st, st.cart_kind, Vector2(0, 0.6))
	var lock: SimEvent = r[0]
	var cart: int = r[1]
	w.actors.state[w.actors.index_of(cart)] = BossDoom.CART
	_idle(w, 1)
	assert_eq(_fx(w, BossSiege.SHELL)[0].tick, lock.tick + st.lock_ticks, "it lands")
	assert_eq(_fx(w, BossSiege.BOULDER_UP).size(), 0, "but the cart under it denies the boulder")
	var k := w.actors.index_of(cart)
	assert_eq(w.actors.dead[k], 0, "and the cart takes no hit")
	var at := w.actors.pos(k)
	var i := _i(w, s[1])
	assert_false(BossSiege.fits(w, i, at, st.boulder_half), "the cart")
	w.actors.state[k] = S.MOVE
	assert_true(BossSiege.fits(w, i, at, st.boulder_half), "the same body as an add does not deny")
	assert_false(BossSiege.fits(w, i, w.actors.pos(i), st.boulder_half), "the Engine's body")


func test_a_shell_by_a_wall_leaves_no_boulder() -> void:
	var s := SiegeLab.only(Vector2(-11.4, 0), Vector2(6, 0), 1, ["lock"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	_until(w, BossSiege.LOCK, 400)
	_until(w, BossSiege.SHELL, st.lock_ticks + 2)
	assert_eq(_fx(w, BossSiege.SHELL).size(), 1, "it still lands")
	assert_eq(_fx(w, BossSiege.BOULDER_UP).size(), 0, "but too near the wall for a boulder")
	assert_true(BossSiege.fits(w, _i(w, s[1]), Vector2(-4, 0), st.boulder_half), "open floor fits")
	assert_false(
		BossSiege.fits(w, _i(w, s[1]), Vector2(4, 0), st.boulder_half), "the Engine's body"
	)


func test_boulders_never_trap_or_seal_anyone_in() -> void:
	var seeds := Seeds.count(400)
	var raised := 0
	var pushed := 0
	for sv in seeds:
		var rng := RngStream.derive(sv, "siege_boulders_test")
		var boss := Vector2(rng.range_int(-800, 800), rng.range_int(-800, 800)) * 0.01
		var s := SiegeLab.only(Vector2(-10, -10), boss, 1 + sv % 2, ["lock"], sv + 1)
		var w: World = s[0]
		var i := _i(w, s[1])
		var st := SiegeLab.siege(w, s[1])
		st.lock_first_ticks = 1
		st.lock_ticks = 12
		st.lock_hold_ticks = 2
		st.lock_every_ticks = 14
		for k in 6:
			var p := Vector2(rng.range_int(-1150, 1150), rng.range_int(-1150, 1150)) * 0.01
			if p.distance_to(boss) < w.actors.radius[i] + 1.0:
				p = boss + Vector2(w.actors.radius[i] + 1.0, 0.0)
			if EnemyAi.clear_of_walls(w, p, w.player.radius_m + 0.05):  # Never into a boulder
				w.actors.set_pos(0, p)
			_idle(w, st.lock_every_ticks)
		raised += _fx(w, BossSiege.BOULDER_UP).size()
		for e in _fx(w, BossSiege.BOULDER_UP):
			pushed += e.amount_applied
		var hero := w.player_pos()
		var pr := w.player.radius_m
		for k in w.boss_fight.sg_b_x.size():
			var o := BossSiege.boulder_obb(w.boss_fight, k)
			for j in w.actors.size():
				if w.actors.dead[j] == 0:
					var hit := Collide.circle_vs_obb(w.actors.pos(j), w.actors.radius[j], o)
					if hit != Vector2.ZERO:
						assert_true(false, "seed %d: a boulder stands on body %d" % [sv, j])
		var f := SiegeLab.flood(w, hero, pr - 0.1, 0.2)
		if f[1] != f[0]:
			assert_true(false, "seed %d: %d of %d free cells sealed off" % [sv, f[0] - f[1], f[0]])
	gut.p("boulders: %d seeds, %d raised, %d pushed the hero out" % [seeds, raised, pushed])
	assert_gt(raised, seeds * 2, "most seeds raise two or more")
	assert_gt(pushed, 0, "and some landed on the hero")


# --- the Shockwave's cover ------------------------------------------------------------------------------------


## The Engine at the origin in phase index `phase`, one boulder at (5, 0) when `rock`; the hero at `hero` takes one
## Shockwave. Returns [the HP it lost, the world].
func _shockwave(hero: Vector2, phase: int, rock: bool, max_hp: int = SiegeLab.LONG) -> Array:
	var s := SiegeLab.only(hero, Vector2.ZERO, phase, [])
	var w: World = s[0]
	w.actors.max_hp[0] = max_hp
	w.actors.hp[0] = max_hp
	if rock:
		SiegeLab.boulder(w, s[1], Vector2(5, 0))
	var i := _i(w, s[1])
	BossLab.start(w, i, &"shockwave")
	var lost := 0
	for k in 125:
		w.step(InputFrame.new())
		w.actors.set_pos(0, hero)
		lost += SiegeLab.take_lost(w)
	return [lost, w]


func test_behind_a_boulder_is_safe_beside_it_is_hit_and_hugging_the_engine_no_longer_is() -> void:
	var behind: Array = _shockwave(Vector2(9, 0), 2, true)
	var w: World = behind[1]
	assert_eq(behind[0], 0, "behind the boulder: covered")
	var blast := _fx(w, BossSiege.SHOCKWAVE)
	assert_eq(blast.size(), 1)
	assert_eq([blast[0].amount, blast[0].amount_applied], [0, 1], "and the boulder that saved it")
	assert_eq(w.boss_fight.sg_b_x.size(), 0, "shattered")
	assert_eq(_fx(w, BossSiege.BOULDER_DOWN)[0].amount_applied, BossSiege.END_SHATTERED)
	var beside: Array = _shockwave(Vector2(5, 4), 2, true)
	assert_gt(beside[0], 0, "beside it: hit")
	assert_eq((beside[1] as World).boss_fight.sg_b_x.size(), 1, "a boulder off the line stands")
	var hug: Array = _shockwave(Vector2(0, 3.4), 2, false)
	assert_gt(hug[0], 0, "hugging the Engine is no longer safe")
	var old: Array = _shockwave(Vector2(0, 3.4), 1, false)
	assert_eq(old[0], 0, "before the last phase it keeps its safe ring")
	var far: Array = _shockwave(Vector2(9, 0), 1, true)
	assert_gt(far[0], 0, "and it hits the ring wherever the boulders are")


func test_one_shockwave_takes_at_most_40_percent_and_the_reader_shows_the_cover() -> void:
	var r: Array = _shockwave(Vector2(5, 4), 2, true, 100)
	assert_eq(r[0], 40, "capped at 40 % of max HP")
	var s := SiegeLab.only(Vector2(9, 0), Vector2.ZERO, 2, [])
	var w: World = s[0]
	SiegeLab.boulder(w, s[1], Vector2(5, 0))
	w.step(InputFrame.new())
	var st := _state(w)
	assert_true(st["cover_rule"])
	assert_true(st["covered"], "behind it")
	w.actors.set_pos(0, Vector2(5, 4))
	assert_false(_state(w)["covered"], "beside it")
	BossLab.start(w, _i(w, s[1]), &"shockwave")
	assert_eq(BossAi.ring_of(w, _i(w, s[1]))[1], 0.0, "its ring shows no safe inside")


func test_a_shockwave_waits_for_cover_or_a_landed_shell() -> void:
	var s := SiegeLab.only(Vector2(-11.4, 0), Vector2(6, 0), 2, [])
	var w: World = s[0]
	var aid: int = s[1]
	var t := SiegeLab.table(w, aid)
	var k := t.attack_index(&"shockwave")
	t.phase_attacks[2] = PackedInt32Array([k])
	var b := BossAi.entry_of(w, _i(w, aid))
	_idle(w, 300)
	assert_eq(w.bosses.last_attack[b], -1, "no boulder, no Shockwave")
	assert_gte(w.boss_fight.sg_held, 0, "held since then")
	# A lock lands by the wall: no boulder, but a shell has landed since
	var st := SiegeLab.siege(w, aid)
	st.lock_phase = 2
	st.lock_first_ticks = 1
	_until(w, BossSiege.SHELL, st.lock_ticks + 5)
	assert_eq(w.boss_fight.sg_b_x.size(), 0)
	CombatLab.until(w, func(x: World) -> bool: return x.bosses.last_attack[b] == k, 30)
	assert_eq(w.bosses.last_attack[b], k, "then it may come")
	# With a boulder it comes at once
	var s2 := SiegeLab.only(Vector2(-6, 0), Vector2(6, 0), 2, [])
	var w2: World = s2[0]
	SiegeLab.table(w2, s2[1]).phase_attacks[2] = PackedInt32Array([k])
	SiegeLab.boulder(w2, s2[1], Vector2(-2, 0))
	var b2 := BossAi.entry_of(w2, _i(w2, s2[1]))
	CombatLab.until(w2, func(x: World) -> bool: return x.bosses.last_attack[b2] == k, 30)
	assert_eq(w2.bosses.last_attack[b2], k, "a boulder stands: it comes")


func test_the_markers_point_at_the_boulders_while_it_winds_up() -> void:
	var s := SiegeLab.only(Vector2(-6, 0), Vector2(6, 0), 2, [])
	var w: World = s[0]
	SiegeLab.boulder(w, s[1], Vector2(-2, 0))
	SiegeLab.boulder(w, s[1], Vector2(0, 6))
	w.step(InputFrame.new())
	assert_false(w.objectives.has(ObjectiveMarkers.SIEGE_BOULDER), "none while nothing comes")
	BossLab.start(w, _i(w, s[1]), &"shockwave")
	w.step(InputFrame.new())
	assert_eq(w.objectives.reasons.count(String(ObjectiveMarkers.SIEGE_BOULDER)), 2, "each boulder")
	_idle(w, 125)
	assert_false(w.objectives.has(ObjectiveMarkers.SIEGE_BOULDER), "gone once it struck")


# --- the Doom Shell -------------------------------------------------------------------------------------------


func test_the_cart_rolls_from_the_far_wall_and_the_doom_shell_fires_tick_exact() -> void:
	var s := SiegeLab.only(Vector2(-6, 6), Vector2(6, 0), 1, ["doom"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	var i := _i(w, s[1])
	var t0 := w.tick
	var sent := _until(w, BossDoom.SENT, 900)
	assert_not_null(sent)
	assert_eq(sent.tick, t0 + st.doom_first_ticks, "14 s into phase 2")
	assert_eq(sent.pos, Vector2(-SiegeLab.HALF_M + 1.5, 0.0), "the wall farthest from the Engine")
	w.step(InputFrame.new())
	var ci := SiegeLab.cart(w)
	assert_gt(ci, 0, "its body is in the world")
	assert_eq(w.actors.state[ci], BossDoom.CART)
	assert_eq(w.actors.max_hp[ci], w.actors.max_hp[i] * 60 / 1000, "6 % of the Engine's HP")
	assert_almost_eq(w.actors.radius[ci], 1.0, 0.0001)
	_idle(w, st.cart_ticks / 2 - 1)
	var cart: Dictionary = _state(w)["cart"]
	assert_eq(cart["progress"], (w.tick - sent.tick) * 1000 / st.cart_ticks, "the next tick's")
	var to: Vector2 = cart["to"]
	assert_almost_eq(to.x, 6.0 - w.actors.radius[i] - 1.0 - BossDoom.ARRIVE_GAP_M, 0.001)
	assert_almost_eq(
		w.actors.pos(SiegeLab.cart(w)).x, (sent.pos.x + to.x) * 0.5, 0.001, "half-way at 5 s"
	)
	var arrived := _until(w, BossDoom.ARRIVED, st.cart_ticks)
	assert_eq(arrived.tick, sent.tick + st.cart_ticks, "10 s to roll home")
	assert_eq(SiegeLab.cart(w), -1, "it is gone")
	assert_eq(_state(w)["doom"], st.doom_ticks - 1)
	var doom := _until(w, BossDoom.DOOM, st.doom_ticks + 2)
	assert_eq(doom.tick, arrived.tick + st.doom_ticks, "1 s later")
	assert_eq(doom.amount, SafeArea.cost(w, st.doom_hit), "40 % in the open")
	assert_eq(doom.amount_applied, -1)
	assert_eq(_fx(w, BossDoom.DESTROYED).size(), 0)


func test_behind_a_boulder_the_doom_shell_misses_and_breaks_it() -> void:
	var s := SiegeLab.only(Vector2(6, -10), Vector2(6, 0), 1, ["doom"])
	var w: World = s[0]
	SiegeLab.boulder(w, s[1], Vector2(6, -6))
	var doom := _until(w, BossDoom.DOOM, 900 + 700)
	assert_not_null(doom)
	assert_eq([doom.amount, doom.amount_applied], [0, 1], "covered; the boulder breaks")
	assert_eq(w.boss_fight.sg_b_x.size(), 0)


func test_a_boulder_on_the_carts_way_is_shattered() -> void:
	var s := SiegeLab.only(Vector2(-6, 6), Vector2(6, 0), 1, ["doom"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	SiegeLab.boulder(w, s[1], Vector2(-3, 0))
	var sent := _until(w, BossDoom.SENT, 900)
	var arrived := _until(w, BossDoom.ARRIVED, st.cart_ticks + 2)
	assert_not_null(arrived)
	assert_eq(arrived.tick, sent.tick + st.cart_ticks, "it was not held up")
	var down := _fx(w, BossSiege.BOULDER_DOWN)
	assert_eq(down.size(), 1)
	assert_eq(down[0].amount_applied, BossSiege.END_SHATTERED)


func test_a_cart_destroyed_far_from_the_engine_blasts_round_itself_only() -> void:
	var s := SiegeLab.only(Vector2(-8, 3), Vector2(6, 0), 1, ["doom"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	_until(w, BossDoom.SENT, 900)
	_idle(w, 60)
	var at := w.actors.pos(SiegeLab.cart(w))
	SiegeLab.break_cart(w)
	var blast := _until(w, BossDoom.DESTROYED, 3)
	assert_not_null(blast)
	assert_almost_eq(blast.pos.x, at.x, 0.2, "where it was")
	assert_eq(blast.amount, SafeArea.cost(w, st.cart_blast_hit), "25 % to a hero within 6 m")
	assert_eq(blast.amount_applied, 0, "the Engine is far: its armour stays")
	assert_eq(_state(w)["stripped"], 0)
	_idle(w, st.cart_ticks + st.doom_ticks)
	assert_eq(_fx(w, BossDoom.DOOM).size(), 0, "no Doom Shell")


func test_a_cart_blown_up_against_the_engine_strips_its_armour_for_8_s() -> void:
	var s := SiegeLab.only(Vector2(-8, 8), Vector2(6, 0), 1, ["doom"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	var i := _i(w, s[1])
	_until(w, BossDoom.SENT, 900)
	_idle(w, st.cart_ticks * 9 / 10)
	var before := BossChallenge.hit_mult(w, i)[0]
	SiegeLab.break_cart(w)
	var blast := _until(w, BossDoom.DESTROYED, 3)
	assert_eq(blast.amount, 0, "the hero stood far from it")
	assert_eq(blast.amount_applied, 1, "the Engine was inside the blast")
	var strip := _fx(w, BossDoom.STRIPPED)
	assert_eq(strip.size(), 1)
	assert_eq(strip[0].amount, st.strip_ticks)
	assert_eq(BossSiege.taken_permille(w, i), 1500)
	assert_eq(BossChallenge.hit_mult(w, i)[0], before * 1500 / 1000, "it takes 150 %")
	assert_eq(_state(w)["stripped"], st.strip_ticks - (w.tick - strip[0].tick))
	_idle(w, st.strip_ticks)
	assert_eq(BossSiege.taken_permille(w, i), 1000, "8 s later it is back")


func test_carts_come_once_in_phase_2_and_twice_in_phase_3_never_with_a_shockwave() -> void:
	var s := SiegeLab.only(Vector2(-6, 6), Vector2(6, 0), 1, ["doom"])
	var w: World = s[0]
	var st := SiegeLab.siege(w, s[1])
	_idle(w, st.doom_first_ticks + st.doom_every_ticks * 2)
	assert_eq(_fx(w, BossDoom.SENT).size(), 1, "one in phase 2")
	var seq: int = w.events_since(0).back().seq if not w.events_since(0).is_empty() else 0
	JudgeLab.set_phase(w, s[1], 2)
	var t := SiegeLab.table(w, s[1])
	t.phase_attacks[2] = PackedInt32Array([t.attack_index(&"shockwave")])
	SiegeLab.boulder(w, s[1], Vector2(-2, 6))
	var i := _i(w, s[1])
	var b := BossAi.entry_of(w, i)
	var shock := t.attack_index(&"shockwave")
	for k in st.doom_first_ticks + st.doom_every_ticks * 2:
		w.step(InputFrame.new())
		SiegeLab.take_lost(w)
		if BossDoom.busy(w) and w.bosses.attack[b] == shock and w.actors.state[i] == S.WINDUP:
			assert_true(false, "a Shockwave wound up while a cart was out")
			break
		if w.boss_fight.sg_b_x.is_empty():
			SiegeLab.boulder(w, s[1], Vector2(-2, 6))
	assert_eq(_fx(w, BossDoom.SENT, seq).size(), 2, "two in phase 3")


# --- the end of a fight, determinism, a save --------------------------------------------------------------------


func test_everything_clears_when_the_hero_dies_and_when_the_engine_dies() -> void:
	var s := SiegeLab.only(Vector2(-6, 6), Vector2(6, 0), 1, ["doom", "lock"])
	var w: World = s[0]
	SiegeLab.boulder(w, s[1], Vector2(-2, 6))
	_until(w, BossDoom.SENT, 900)
	_idle(w, 2)
	var walls := w.walls.size() - w.boss_fight.sg_b_x.size()
	assert_gt(SiegeLab.cart(w), 0)
	w.actors.dead[0] = 1
	w.actors.hp[0] = 0
	w.step(InputFrame.new())
	assert_eq(w.boss_fight.sg_b_x.size(), 0, "the boulders crumble")
	assert_eq(w.walls.size(), walls, "their walls too")
	assert_eq(w.boss_fight.sg_cart_from, -1, "the cart goes")
	assert_eq(_fx(w, BossDoom.DESTROYED).size(), 0, "without a blast")
	# The Engine dies mid-siege
	var s2 := SiegeLab.only(Vector2(-6, 6), Vector2(6, 0), 1, ["doom", "lock"])
	var w2: World = s2[0]
	SiegeLab.boulder(w2, s2[1], Vector2(-2, 6))
	_until(w2, BossDoom.SENT, 900)
	_idle(w2, 2)
	var cart_id := w2.boss_fight.sg_cart
	assert_gte(cart_id, 0)
	var i := _i(w2, s2[1])
	w2.actors.dead[i] = 1
	w2.actors.hp[i] = 0
	w2.step(InputFrame.new())
	w2.step(InputFrame.new())
	assert_eq(_state(w2), {}, "the siege goes with it")
	assert_eq(w2.boss_fight.sg_boss, -1)
	assert_eq(w2.boss_fight.sg_b_x.size(), 0)
	assert_eq(w2.actors.index_of(cart_id), -1, "the cart crumbles")
	assert_false(w2.objectives.has(ObjectiveMarkers.SIEGE_BOULDER))


func test_a_world_without_a_siege_keeps_no_siege_state() -> void:
	var s := JudgeLab.fight(Vector2(-6, 0), Vector2(6, 0))
	var w: World = s[0]
	CombatLab.idle(w, 120)
	assert_eq(w.boss_fight.sg_boss, -1)
	assert_eq(WorldReader.new(w).boss_siege(), {})


## A fight with the real data from phase 2 on, the hero walking a slow circle (too tough to die).
func _mid_fight(seed_value: int, ticks: int = 60 * 20) -> World:
	var s := SiegeLab.fight(Vector2(-6, 6), Vector2(6, 0), seed_value)
	var w: World = s[0]
	JudgeLab.set_phase(w, s[1], 1)
	for k in ticks:
		var dir := Kin.dir((k * 16) & 4095)
		var f := InputFrame.make(Vector2i(roundi(dir.x * 60.0), roundi(dir.y * 60.0)), 0, 300, 0, 0)
		w.step(f)
		w.actors.hp[0] = SiegeLab.LONG
	return w


func test_deterministic_hashed_and_a_save_mid_fight_restores() -> void:
	var a := _mid_fight(7)
	var b := _mid_fight(7)
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	assert_gt(_fx(a, BossSiege.LOCK).size(), 0, "a lock began")
	assert_gt(_fx(a, BossDoom.SENT).size(), 0, "a cart rolled")
	var before := a.state_hash()
	a.boss_fight.sg_doom_n += 1
	assert_ne(a.state_hash(), before, "the clocks are hashed")
	a.boss_fight.sg_doom_n -= 1
	a.boss_fight.sg_lock_x += 0.5
	assert_ne(a.state_hash(), before, "and the lock")
	a.boss_fight.sg_lock_x -= 0.5
	assert_gt(a.boss_fight.sg_b_x.size(), 0, "a boulder stands at 20 s")
	assert_gte(a.boss_fight.sg_cart_from, 0, "and a cart rolls")
	var snap := WorldSnapshot.take(a)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), JudgeLab.world(7))
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "same hash restored")
	assert_eq(WorldReader.new(restored).boss_siege(), WorldReader.new(a).boss_siege())
	assert_eq(restored.walls.size(), a.walls.size(), "the boulders are walls again")
	for k in 900:
		var f := InputFrame.make(Vector2i(60, -40), 0, 300, InputFrame.SHOOT, 0)
		a.step(f)
		restored.step(f)
		a.actors.hp[0] = SiegeLab.LONG
		restored.actors.hp[0] = SiegeLab.LONG
	assert_eq(restored.state_hash(), a.state_hash(), "same hash 900 ticks on")
