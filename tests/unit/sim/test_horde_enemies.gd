# gdlint: disable=max-public-methods
extends GutTest
## The six horde kinds (PLAN v0.4.0 EN): Swarmer, Splitter (and its Splitlings), Shield Bearer, Mender, Mine Layer and
## Sniper. Every world is seeded, so each behaviour is the same on every run. The drawn shapes are the hit areas
## (EI-07): the parity tests at the end move the player after the attack has committed and compare.

const S := EnemyAi.State
const K := ActorStore.Kind
const EPS := 0.03


func _i(w: World, id: int) -> int:
	return w.actors.index_of(id)


func _state(w: World, id: int) -> int:
	return w.actors.state[_i(w, id)]


func _tough(w: World) -> void:
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000


func _until_state(w: World, id: int, state: int, limit := 900) -> int:
	for t in limit:
		if _i(w, id) >= 0 and _state(w, id) == state:
			return t
		w.step(InputFrame.new())
	return -1


func _ids_of(w: World, kind: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(1, w.actors.size()):
		if w.actors.kinds[i] == kind and w.actors.dead[i] == 0:
			out.append(w.actors.ids[i])
	return out


func _hit(w: World, id: int, amount: int, from: Vector2) -> void:
	var i := _i(w, id)
	w.actors.invuln[i] = 0
	var p := w.actors.ids[0]
	Damage.hit(w, i, amount, p, p, w.take_root(), SimEvent.TAG_MELEE, from, w.actors.pos(i))


func _damage_from(w: World, owner_id: int) -> Array:
	var out := []
	for e in w.events_since(0):
		if (
			e.kind == SimEvent.Kind.DAMAGE
			and e.target_id == w.actors.ids[0]
			and e.owner_id == owner_id
		):
			out.append(e.amount_applied)
	return out


# --- Swarmer ------------------------------------------------------------------------------------------------------


func test_a_swarmer_is_fast_and_bites_after_a_lunge_telegraph() -> void:
	var w := CombatLab.world()
	_tough(w)
	var t := w.enemy_table(K.SWARMER)
	assert_gt(t.speed, w.enemy_table(K.CHARGER).speed * 1.4, "much faster than a Charger")
	var id := w.add_enemy(K.SWARMER, Vector2(6, 0))
	assert_gte(_until_state(w, id, S.WINDUP), 0)
	var i := _i(w, id)
	assert_between(w.actors.windup[i], SimTick.MIN_TELEGRAPH_TICKS, 30, "a 24-30 tick telegraph")
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg["shape"], &"lane", "its lunge's lane is drawn")
	var lane: Obb = tg["obb"]
	assert_lt(lane.half.x * 2.0, 2.8, "a short lunge")
	assert_gte(_until_state(w, id, S.RECOVER), 0)
	assert_eq(_damage_from(w, id), [5], "the bite lands for 5")


func test_one_sword_slash_kills_a_swarmer() -> void:
	var w := CombatLab.world()
	var id := w.add_enemy(K.SWARMER, Vector2(4, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	var slash: int = PlayerTable.starting_values().combo[0].damage
	assert_gte(slash, w.enemy_table(K.SWARMER).hp, "the first slash outdamages its HP")
	_hit(w, id, slash, w.player_pos())
	assert_eq(w.actors.dead[_i(w, id)], 1)


func test_swarmers_arrive_in_a_pack_of_eight_within_the_cap() -> void:
	for cap in [20, 5]:
		var w := CombatLab.world()
		var t := SpawnTable.new()
		t.kinds = PackedInt32Array([K.SWARMER])
		t.weights = PackedInt32Array([1])
		t.unlock_tiers = PackedInt32Array([0])
		t.packs = PackedInt32Array([8])
		t.cap_by_floor = PackedInt32Array([cap])
		t.cap_max = cap
		t.interval_start_ticks = 2
		t.interval_min_ticks = 1
		t.min_distance_m = 4.0
		w.spawner = t
		w.spawn_points = PackedVector2Array([Vector2(10, 0)])
		CombatLab.idle(w, 3)
		var ids := _ids_of(w, K.SWARMER)
		assert_eq(ids.size(), mini(8, cap), "cap %d: one pack" % cap)
		for id in ids:
			var d := Kin.length(w.actors.pos(_i(w, id)) - Vector2(10, 0))
			assert_lt(
				d,
				2.0 * SpawnDirector.PACK_STEP_M + 0.01,
				"around the spawn point (v0.4.0 SC rings)"
			)


# --- Splitter -----------------------------------------------------------------------------------------------------


func test_a_splitter_splits_into_two_splitlings_once() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.SPLITTER, Vector2(8, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	var at := w.actors.pos(_i(w, id))
	_hit(w, id, 1000, w.player_pos())
	CombatLab.idle(w, 1)
	assert_eq(_ids_of(w, K.SPLITTER).size(), 0, "the Splitter is gone")
	var lings := _ids_of(w, K.SPLITLING)
	assert_eq(lings.size(), 2, "two Splitlings")
	var p0 := w.actors.pos(_i(w, lings[0]))
	var p1 := w.actors.pos(_i(w, lings[1]))
	assert_gt(Kin.length(p0 - p1), 0.5, "side by side")
	assert_lt(Kin.length((p0 + p1) * 0.5 - at), 0.2, "where it fell")
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	for l in lings:
		_hit(w, l, 1000, w.player_pos())
	CombatLab.idle(w, 2)
	assert_eq(_ids_of(w, K.SPLITLING).size(), 0, "a Splitling never splits")
	assert_eq(w.kills, 3)


func test_the_splitter_swipes_a_disc_ahead_of_it() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.SPLITTER, Vector2(1.7, 0))
	assert_gte(_until_state(w, id, S.WINDUP), 0)
	var i := _i(w, id)
	var t := w.enemy_table(K.SPLITTER)
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg["shape"], &"disc")
	var ahead := (
		w.actors.pos(i) + Kin.dir(Kin.angle_of(w.player_pos() - w.actors.pos(i))) * t.reach_m
	)
	assert_almost_eq(Kin.length(tg["center"] - ahead), 0.0, 0.01, "reach_m ahead of it")
	assert_gte(_until_state(w, id, S.RECOVER), 0)
	assert_eq(_damage_from(w, id), [12])


# --- Shield Bearer ------------------------------------------------------------------------------------------------


func test_the_shield_blocks_from_the_front_but_not_the_sides_or_back() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.SHIELD_BEARER, Vector2(6, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	var i := _i(w, id)
	var at := w.actors.pos(i)
	var f := w.actors.facing[i]
	var hp := w.actors.hp[i]
	var seq := w.last_event_seq()
	_hit(w, id, 10, at + Kin.dir(f) * 2.0)
	assert_eq(w.actors.hp[i], hp, "a hit from the front is blocked")
	var blocked := false
	for e in w.events_since(seq):
		blocked = blocked or (e.kind == SimEvent.Kind.HIT and e.tags & SimEvent.TAG_BLOCKED != 0)
	assert_true(blocked, "tagged BLOCKED (the block spark and clank)")
	_hit(w, id, 10, at + Kin.dir((f + 1024) & 4095) * 2.0)
	assert_eq(w.actors.hp[i], hp - 10, "the side takes full damage")
	_hit(w, id, 10, at - Kin.dir(f) * 2.0)
	assert_eq(w.actors.hp[i], hp - 20, "the back takes full damage")


func test_a_bolt_into_the_shield_is_stopped() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.SHIELD_BEARER, Vector2(6, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	var i := _i(w, id)
	var hp := w.actors.hp[i]
	var at := w.actors.pos(i)
	var dir := Kin.dir(w.actors.facing[i])
	w.queue_projectile(
		w.actors.ids[0], ActorStore.TEAM_PLAYER, at + dir * 2.0, -dir * 0.3, 4, 0.1, 60, 2
	)
	CombatLab.idle(w, 10)
	assert_eq(w.actors.hp[_i(w, id)], hp, "no damage through the shield")
	assert_eq(w.projectiles.size(), 0, "the bolt ended on it")


func test_it_turns_slowly_and_bashes_only_a_player_in_front() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.SHIELD_BEARER, Vector2(1.4, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS)
	var i := _i(w, id)
	w.actors.facing[i] = 0  # facing away from the player (who is at -x)
	var rate := w.enemy_table(K.SHIELD_BEARER).turn_rate
	w.step(InputFrame.new())
	i = _i(w, id)
	assert_lte(Kin.angle_diff(w.actors.facing[i], 0), rate, "turns at most turn_rate a tick")
	for k in 40:
		w.step(InputFrame.new())
		assert_ne(_state(w, id), S.WINDUP, "no bash at a player behind it (tick %d)" % k)
	assert_gte(_until_state(w, id, S.WINDUP), 0, "it comes round")
	var tg := EnemyAi.telegraph(w, _i(w, id))
	assert_eq([tg["shape"], tg["style"]], [&"lane", &"bash"])
	assert_gte(_until_state(w, id, S.RECOVER), 0)
	assert_eq(_damage_from(w, id), [18], "the bash lands")


# --- Mender -------------------------------------------------------------------------------------------------------


func test_a_mender_heals_a_hurt_ally_through_its_beam() -> void:
	var w := CombatLab.world()
	_tough(w)
	var mender := w.add_enemy(K.MENDER, Vector2(7, 0))
	var ally := w.add_enemy(K.WARDEN, Vector2(7, 3))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	w.actors.hp[_i(w, ally)] = 40
	var reader := WorldReader.new(w)
	var beam := false
	for k in 120:
		w.step(InputFrame.new())
		beam = beam or reader.actor_heal_target(_i(w, mender)) == ally
	assert_true(beam, "its beam reaches the Warden (WorldReader.actor_heal_target)")
	var healed := 0
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.HEAL and e.owner_id == mender:
			assert_eq(e.target_id, ally)
			healed += e.amount_applied
	assert_gt(healed, 0, "HEAL events")
	assert_eq(w.actors.hp[_i(w, ally)], 40 + healed, "the HP it healed")
	assert_true(EnemyAi.is_priority(K.MENDER), "marked as the target to kill first")
	assert_eq(_damage_from(w, mender), [], "it never hurts the player")


func test_a_mender_ignores_allies_out_of_range_and_unhurt_ones() -> void:
	var w := CombatLab.world()
	var mender := w.add_enemy(K.MENDER, Vector2(0, 8))
	var far := w.add_enemy(K.CHARGER, Vector2(0, 16))
	var whole := w.add_enemy(K.CHARGER, Vector2(2, 8))
	w.actors.hp[_i(w, far)] = 5
	var r := w.enemy_table(K.MENDER).heal_range_m
	assert_eq(EnemyAi._patient(w, _i(w, mender), r), -1, "one out of range, one unhurt")
	w.actors.hp[_i(w, whole)] = 20
	assert_eq(EnemyAi._patient(w, _i(w, mender), r), _i(w, whole))


func test_a_mender_keeps_its_distance() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.MENDER, Vector2(3, 0))
	var t := w.enemy_table(K.MENDER)
	CombatLab.idle(w, 300)
	var d := Kin.length(w.actors.pos(_i(w, id)) - w.player_pos())
	assert_between(d, t.keep_min_m - 0.5, t.keep_distance_m + 0.5, "it backed off to its band")


# --- Mine Layer ---------------------------------------------------------------------------------------------------


func _layer_with_a_mine(w: World) -> int:
	var id := w.add_enemy(K.MINE_LAYER, Vector2(6, 0))
	assert_gte(_until_state(w, id, S.RECOVER), 0)
	assert_eq(w.mines.size(), 1, "it dropped a mine")
	return id


func test_a_mine_arms_when_stepped_in_and_blows_after_its_fuse() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := _layer_with_a_mine(w)
	var at := w.mines.pos(0)
	assert_eq(w.mines.fuse[0], -1, "idle while the player is away")
	assert_true(EnemyAi.telegraph(w, _i(w, id)).is_empty(), "an idle mine is no telegraph")
	var fuse := w.enemy_table(K.MINE_LAYER).fuse_ticks
	var armed_at := -1
	var blown := -1
	for k in 200:
		w.actors.set_pos(0, at + Vector2(0.5, 0))
		w.step(InputFrame.new())
		var i := _i(w, id)
		if armed_at < 0 and w.mines.size() > 0 and w.mines.fuse[0] >= 0:
			armed_at = w.tick
			var tg := EnemyAi.telegraph(w, i)
			assert_eq([tg["shape"], tg["style"]], [&"discs", &"mine"], "the armed mine is drawn")
		if _damage_from(w, id).size() > 0:
			blown = w.tick
			break
	assert_gte(armed_at, 0, "it armed")
	assert_eq(blown - armed_at, fuse, "it blew %d ticks after arming" % fuse)
	assert_gte(fuse, SimTick.MIN_TELEGRAPH_TICKS)
	assert_eq(_damage_from(w, id), [18])
	assert_eq(w.mines.size(), 0, "spent")


func test_walking_out_of_an_armed_mine_dodges_it() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := _layer_with_a_mine(w)
	var at := w.mines.pos(0)
	w.actors.set_pos(0, at)
	w.step(InputFrame.new())
	assert_gte(w.mines.fuse[0], 0, "armed")
	for k in 60:
		w.actors.set_pos(0, at + Vector2(0, 4))
		w.step(InputFrame.new())
	assert_eq(_damage_from(w, id), [], "out of the circle when it blew")


func test_a_layer_keeps_at_most_three_mines_and_takes_them_when_it_dies() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.MINE_LAYER, Vector2(6, 0))
	var most := 0
	for k in 1200:
		w.step(InputFrame.new())
		most = maxi(most, w.mines.size())
	assert_eq(most, 3, "its max on the floor")
	_hit(w, id, 1000, w.actors.pos(_i(w, id)) + Vector2(1, 0))
	CombatLab.idle(w, 1)
	assert_eq(w.mines.size(), 0, "its mines go with it")


# --- Sniper -------------------------------------------------------------------------------------------------------


func test_the_sniper_draws_its_line_for_60_ticks_then_shoots_down_it() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.SNIPER, Vector2(12, 0))
	assert_gte(_until_state(w, id, S.WINDUP), 0)
	var i := _i(w, id)
	assert_eq(w.actors.windup[i], 60, "a one-second line")
	var tg := EnemyAi.telegraph(w, i)
	assert_eq([tg["shape"], tg["style"]], [&"lane", &"snipe"])
	assert_ne(
		Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, tg["obb"]),
		Vector2.ZERO,
		"the line runs through the player"
	)
	assert_eq(_until_state(w, id, S.ACTIVE), 60, "it fires when the line has shown 60 ticks")
	CombatLab.idle(w, 2)
	assert_eq(_damage_from(w, id), [28])


func test_the_sniper_line_follows_then_commits_24_ticks_before_the_shot() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.SNIPER, Vector2(12, 0))
	assert_gte(_until_state(w, id, S.WINDUP), 0)
	var run := InputFrame.make(Vector2i(0, 127), 0, 0, 0, 0)
	var angles := []
	var i := _i(w, id)
	while _state(w, id) == S.WINDUP:
		angles.append([w.actors.state_t[i], w.actors.lock_a[i]])
		w.step(run)
		i = _i(w, id)
	var commit := 60 - EnemyAi.SNIPE_COMMIT_TICKS
	var last := -1
	for pair: Array in angles:
		if pair[0] > commit:
			if last < 0:
				last = pair[1]
			assert_eq(pair[1], last, "fixed for the last %d ticks" % EnemyAi.SNIPE_COMMIT_TICKS)
	assert_ne(angles[0][1], angles[angles.size() - 1][1], "it followed before")


func test_the_sniper_relocates_after_each_shot() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.SNIPER, Vector2(12, 0))
	assert_gte(_until_state(w, id, S.RECOVER), 0)
	assert_gte(_until_state(w, id, S.MOVE), 0)
	var i := _i(w, id)
	assert_eq(w.actors.pick[i], 1, "relocating")
	var from := w.actors.pos(i)
	var spot := Vector2(w.actors.lock_x[i], w.actors.lock_y[i])
	var turn := Kin.angle_diff(Kin.angle_of(spot), Kin.angle_of(from))
	assert_between(
		turn, EnemyAi.RELOCATE_MIN_TURN - 8, EnemyAi.RELOCATE_MAX_TURN + 8, "45-90 degrees round"
	)
	for k in EnemyAi.RELOCATE_MAX_TICKS:
		if w.actors.pick[_i(w, id)] == 0:
			break
		assert_ne(_state(w, id), S.WINDUP, "no shot while it walks")
		w.step(InputFrame.new())
	assert_gt(Kin.length(w.actors.pos(_i(w, id)) - from), 2.0, "it moved to a new spot")
	assert_gte(_until_state(w, id, S.WINDUP), 0, "and fires again from there")


# --- parity (EI-07): the drawn shape is the hit ---------------------------------------------------------------


## Spawns `kind` at `from`, lets it wind up at a player standing at `aim_at`; once the windup has committed (its last
## SNIPE_COMMIT_TICKS), the player steps to `stand`. Returns [player damage, the last drawn telegraph].
func _committed(kind: int, from: Vector2, aim_at: Vector2, stand: Vector2) -> Array:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(kind, from)
	var tg := {}
	for k in 600:
		var i := _i(w, id)
		if i < 0 or w.actors.state[i] == S.RECOVER:
			break
		var late := (
			w.actors.state[i] == S.ACTIVE
			or (
				w.actors.state[i] == S.WINDUP
				and w.actors.state_t[i] >= w.actors.windup[i] - EnemyAi.SNIPE_COMMIT_TICKS
			)
		)
		w.actors.set_pos(0, stand if late else aim_at)
		w.actors.set_pos(i, from)  # it holds its spot, so the lane is where it was drawn
		if w.actors.state[i] == S.WINDUP:
			tg = EnemyAi.telegraph(w, i)
		w.step(InputFrame.new())
	return [_damage_from(w, w.actors.ids[1]), tg]


func test_parity_sniper_line() -> void:
	var pr := PlayerTable.starting_values().radius_m
	var half := CombatLab.world().enemy_table(K.SNIPER).lane_half_m
	for d in [0.0, half + pr - EPS, half + pr + EPS, 2.0]:
		var got := _committed(K.SNIPER, Vector2(12, 0), Vector2.ZERO, Vector2(0, d))
		var drawn := (
			Collide.circle_vs_obb(Vector2(0, d), pr - 0.0001, got[1]["obb"]) != Vector2.ZERO
		)
		assert_eq(got[0].size() > 0, drawn, "lateral %.2f: hit iff inside the drawn line" % d)


func test_parity_shield_bash() -> void:
	var pr := PlayerTable.starting_values().radius_m
	var half := CombatLab.world().enemy_table(K.SHIELD_BEARER).lane_half_m
	for d in [0.0, half + pr - EPS, half + pr + EPS]:
		var got := _committed(K.SHIELD_BEARER, Vector2(1.5, 0), Vector2.ZERO, Vector2(0.2, d))
		var drawn := (
			Collide.circle_vs_obb(Vector2(0.2, d), pr - 0.0001, got[1]["obb"]) != Vector2.ZERO
		)
		assert_eq(got[0].size() > 0, drawn, "lateral %.2f: hit iff inside the drawn bash" % d)


func test_parity_splitter_swipe() -> void:
	var pr := PlayerTable.starting_values().radius_m
	var probe := _committed(K.SPLITTER, Vector2(1.7, 0), Vector2.ZERO, Vector2.ZERO)
	var c: Vector2 = probe[1]["center"]
	var r: float = probe[1]["radius"]
	for d in [0.0, r + pr - EPS, r + pr + EPS]:
		var stand := c + Vector2(0, d)
		var got := _committed(K.SPLITTER, Vector2(1.7, 0), Vector2.ZERO, stand)
		assert_eq(got[0].size() > 0, d <= r + pr, "offset %.2f: hit iff inside the drawn disc" % d)


func test_parity_mine_disc() -> void:
	var pr := PlayerTable.starting_values().radius_m
	for d in [0.0, 1.5 + pr - EPS, 1.5 + pr + EPS]:
		var w := CombatLab.world()
		_tough(w)
		var id := _layer_with_a_mine(w)
		var at := w.mines.pos(0)
		var r := w.mines.radius[0]
		assert_eq(r, 1.5)
		w.actors.set_pos(0, at)
		w.step(InputFrame.new())
		var tg := EnemyAi.telegraph(w, _i(w, id))
		for k in 60:
			w.actors.set_pos(0, at + Vector2(0, d))
			w.step(InputFrame.new())
		var c: Vector2 = tg["centers"][0]
		var inside: bool = Kin.length(at + Vector2(0, d) - c) <= tg["radius"] + pr
		assert_eq(
			_damage_from(w, id).size() > 0, inside, "offset %.2f: hit iff inside the drawn disc" % d
		)


# --- determinism and the readable-cause rule ----------------------------------------------------------------------


func _horde(seed_value: int) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	for spec in [
		[K.SWARMER, Vector2(8, 2)],
		[K.SWARMER, Vector2(8, 3)],
		[K.SPLITTER, Vector2(-7, 3)],
		[K.SHIELD_BEARER, Vector2(0, 9)],
		[K.MENDER, Vector2(6, -6)],
		[K.MINE_LAYER, Vector2(-6, -5)],
		[K.SNIPER, Vector2(-12, 0)],
	]:
		w.add_enemy(spec[0], spec[1])
	return w


func test_the_horde_ai_is_deterministic() -> void:
	var hashes := []
	for r in 2:
		var w := _horde(91)
		var bot := FightBot.new(7)
		for k in 900:
			w.step(bot.frame(w))
			w.actors.hp[0] = w.actors.max_hp[0]
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_every_hit_from_the_horde_has_a_readable_cause() -> void:
	var damage := 0
	var causes := {}
	var refill := [
		K.SWARMER,
		K.SWARMER,
		K.SPLITTER,
		K.SHIELD_BEARER,
		K.SWARMER,
		K.MINE_LAYER,
		K.SNIPER,
		K.MENDER
	]
	for s in [3, 4, 5, 6, 7, 8]:
		var w := _horde(s)
		var bot := FightBot.new(s)
		var check := ReadableCause.new(w)
		for k in 2400:
			w.step(bot.frame(w))
			check.observe(w)
			w.actors.hp[0] = w.actors.max_hp[0]
			if w.actors.size() < 9:
				w.add_enemy(refill[k % refill.size()], Vector2(10, 0))
		damage += check.damage_count
		for key: String in check.by_cause:
			causes[key] = int(causes.get(key, 0)) + int(check.by_cause[key])
		for v: Dictionary in check.violations:
			fail_test("unreadable hit: %s" % JSON.stringify(v))
	gut.p("HORDE_CAUSES %s" % [causes])
	assert_gt(damage, 20, "hit often enough to mean something (%d)" % damage)
	for key in [
		"CAUSE_SWARMER", "CAUSE_SPLITTER", "CAUSE_SHIELD_BEARER", "CAUSE_MINE_LAYER", "CAUSE_SNIPER"
	]:
		assert_true(causes.has(key), "%s landed hits: %s" % [key, causes])
