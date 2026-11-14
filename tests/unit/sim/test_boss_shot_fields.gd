extends GutTest
## The discs that slow the hero's shots (BossShotFields): a hero's shot crawls through one at the field's share of its
## speed, its life running at the same share, and flies its range out afterwards; a hostile shot is not slowed; the
## slowest of two fields applies; expiry, the cap, gone with the boss and the hero; the snapshot and the seed.

const LONG := 1 << 20
## A hit pauses the world for a few ticks (the hero's hit-stop); the fight's clean-up runs on the first tick after it.
const HIT_STOP := 10
## The test shot: 0.25 m a tick for 60 ticks (15 m) along +x from x = 0.125, so it never sits on a field's edge.
const SPEED := 0.25
const LIFE := 60
const START := Vector2(0.125, 0)
## The test field: x from 4 to 6 on the shot's line.
const FIELD_AT := Vector2(5, 0)
const FIELD_R := 1.0


func _fight(seed_value := 11) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"clockwork_judge", Vector2(-30, -30))
	w.actors.set_pos(0, Vector2(30, 30))
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	# TEST HELPER: held staggered, so it never attacks.
	w.actors.state[i] = BossAi.STAGGERED
	w.bosses.stagger_t[BossAi.entry_of(w, i)] = LONG
	return [w, w.actors.ids[i]]


func _step(w: World, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())


func _field(speed := 200, life := 0, cap := 3, radius := FIELD_R) -> ShotFieldTable:
	var t := ShotFieldTable.new()
	t.radius_m = radius
	t.life_ticks = life
	t.speed_permille = speed
	t.max_count = cap
	return t


## TEST HELPER: a harmless shot of `team` put straight into the store (no weapon), flying +x.
func _shot(w: World, team: int, owner: int) -> int:
	var id := w.take_id()
	w.projectiles.add(id, owner, team, START, Vector2(SPEED, 0), 0.1, LIFE)
	return id


## Steps until shot `id` is gone: its x at the start of every tick it lived.
func _flight(w: World, id: int) -> PackedFloat32Array:
	var xs := PackedFloat32Array()
	for k in 1000:
		var i := w.projectiles.ids.find(id)
		if i < 0:
			break
		xs.append(w.projectiles.pos_x[i])
		assert_eq(w.projectiles.vel_x[i], SPEED, "between ticks the shot holds its own velocity")
		w.step(InputFrame.new())
	return xs


## How many of the flight's ticks moved the shot under half its speed.
func _crawled(xs: PackedFloat32Array) -> int:
	var n := 0
	for k in range(1, xs.size()):
		if xs[k] - xs[k - 1] < SPEED * 0.5:
			n += 1
	return n


func test_an_unslowed_shot_flies_its_life_out() -> void:
	var s := _fight()
	var w: World = s[0]
	var xs := _flight(w, _shot(w, ActorStore.TEAM_PLAYER, w.actors.ids[0]))
	assert_eq(xs.size(), LIFE, "one tick of life a tick")
	assert_eq(_crawled(xs), 0)
	assert_almost_eq(xs[-1] + SPEED - START.x, SPEED * LIFE, 0.001, "15 m")


func test_a_hero_shot_crawls_through_and_then_flies_its_range_out() -> void:
	var s := _fight()
	var w: World = s[0]
	BossShotFields.place(w, s[1], _field(200), FIELD_AT)
	var xs := _flight(w, _shot(w, ActorStore.TEAM_PLAYER, w.actors.ids[0]))
	# It is inside from x = 4.125 and leaves past 6.0 at 0.05 m a tick: 38 ticks (8 at its own speed).
	assert_eq(_crawled(xs), 38, "the ticks spent crawling")
	var first := -1
	for k in range(1, xs.size()):
		if xs[k] - xs[k - 1] < SPEED * 0.5:
			first = k - 1
			break
	assert_almost_eq(xs[first], 4.125, 0.001, "it slows from its first tick inside")
	assert_almost_eq(xs[first + 1] - xs[first], SPEED * 0.2, 0.0001, "at a fifth of its speed")
	assert_almost_eq(
		xs[first + 38] - xs[first + 37], SPEED * 0.2, 0.0001, "to its last tick inside"
	)
	assert_almost_eq(xs[first + 39] - xs[first + 38], SPEED, 0.0001, "then its own speed again")
	# 38 ticks at a fifth spend 7 or 8 ticks of life (the share is counted on the world clock).
	assert_true(BossShotFields.SLOWS_LIFE, "the decision this test pins")
	assert_between(xs.size(), LIFE + 38 - 8, LIFE + 38 - 7, "its life ran at a fifth inside")
	var flown := xs[-1] + SPEED - START.x
	assert_almost_eq(flown, SPEED * LIFE, SPEED + 0.01, "its whole range, within one tick's flight")
	assert_gt(xs[-1], 12.0, "far past the field")


func test_a_hostile_shot_is_not_slowed() -> void:
	var s := _fight()
	var w: World = s[0]
	BossShotFields.place(w, s[1], _field(200), FIELD_AT)
	var xs := _flight(w, _shot(w, ActorStore.TEAM_ENEMY, s[1]))
	assert_eq(xs.size(), LIFE)
	assert_eq(_crawled(xs), 0)
	assert_almost_eq(xs[-1] + SPEED - START.x, SPEED * LIFE, 0.001)


func test_the_slowest_of_two_fields_applies() -> void:
	var s := _fight()
	var w: World = s[0]
	BossShotFields.place(w, s[1], _field(500), FIELD_AT)
	BossShotFields.place(w, s[1], _field(200), FIELD_AT)
	assert_eq(BossShotFields.speed_at(w, FIELD_AT), 200)
	assert_eq(BossShotFields.speed_at(w, Vector2(5, 0.99)), 200, "inside the edge")
	assert_eq(BossShotFields.speed_at(w, Vector2(5, 1.01)), 1000, "outside it")
	assert_eq(WorldReader.new(w).boss_shot_fields().size(), 2, "the view's read")


func test_a_field_goes_when_its_time_is_up() -> void:
	var s := _fight()
	var w: World = s[0]
	BossShotFields.place(w, s[1], _field(200, 10), FIELD_AT)
	assert_eq(WorldReader.new(w).boss_shot_fields()[0]["left"], 10)
	_step(w, 10)
	assert_eq(w.bosses.sf_x.size(), 1, "it stays for its ten ticks")
	_step(w, 1)
	assert_eq(w.bosses.sf_x.size(), 0, "and goes on the next")
	var xs := _flight(w, _shot(w, ActorStore.TEAM_PLAYER, w.actors.ids[0]))
	assert_eq(_crawled(xs), 0, "no field, no crawl")


func test_the_cap_removes_the_oldest() -> void:
	var s := _fight()
	var w: World = s[0]
	for k in 5:
		BossShotFields.place(w, s[1], _field(200, 0, 3), Vector2(k * 3, 0))
	assert_eq(BossShotFields.count_of(w, s[1]), 3)
	assert_eq(Array(w.bosses.sf_id), [2, 3, 4], "the two oldest went")


func test_they_go_with_their_boss_and_with_the_hero() -> void:
	var s := _fight()
	var w: World = s[0]
	w.bosses.arena = Rect2(-40, -40, 80, 80)
	BossShotFields.place(w, s[1], _field(), FIELD_AT)
	BossSignatures.on_boss_gone(w, 999999)
	assert_eq(w.bosses.sf_x.size(), 1, "another boss's leaving leaves it")
	BossSignatures.on_boss_gone(w, s[1])
	assert_eq(w.bosses.sf_x.size(), 0, "its boss gone")
	BossShotFields.place(w, s[1], _field(), FIELD_AT)
	_step(w, 3)
	assert_eq(w.bosses.sf_x.size(), 1)
	w.actors.set_pos(0, Vector2(60, 0))
	_step(w, 1)
	assert_eq(w.bosses.sf_x.size(), 0, "the hero outside the arena")
	w.actors.set_pos(0, Vector2(30, 30))
	BossShotFields.place(w, s[1], _field(), FIELD_AT)
	w.actors.invuln[0] = 0
	var p := w.player_pos()
	Damage.hit(w, 0, LONG * 4, s[1], s[1], w.take_root(), 0, p, p)
	_step(w, HIT_STOP + 1)
	assert_true(w.player_dead())
	assert_eq(w.bosses.sf_x.size(), 0, "the hero dead")


func test_a_snapshot_keeps_a_shot_mid_field() -> void:
	var s := _fight()
	var w: World = s[0]
	BossShotFields.place(w, s[1], _field(200, 300), FIELD_AT)
	var id := _shot(w, ActorStore.TEAM_PLAYER, w.actors.ids[0])
	_step(w, 30)
	var i := w.projectiles.ids.find(id)
	assert_true(i >= 0 and absf(w.projectiles.pos_x[i] - FIELD_AT.x) < FIELD_R, "mid-field")
	var hash_a := w.state_hash()
	var back := World.from_snapshot(
		bytes_to_var(var_to_bytes(WorldSnapshot.take(w))), BossLab.world(11)
	)
	assert_not_null(back, "restores")
	if back == null:
		return
	assert_eq(back.state_hash(), hash_a, "the restored world hashes the same")
	assert_eq(back.bosses.sf_x, w.bosses.sf_x)
	_step(w, 80)
	_step(back, 80)
	assert_eq(back.state_hash(), w.state_hash(), "and runs on the same")


func test_same_seed_same_hash() -> void:
	var run := func(seed_value: int) -> Array:
		var s := _fight(seed_value)
		var w: World = s[0]
		BossShotFields.place(w, s[1], _field(200, 100), FIELD_AT)
		var id := _shot(w, ActorStore.TEAM_PLAYER, w.actors.ids[0])
		var xs := _flight(w, id)
		return [w.state_hash(), xs.size(), w.tick]
	var a: Array = run.call(21)
	assert_eq(a, run.call(21), "the same seed, the same flight and hash")
