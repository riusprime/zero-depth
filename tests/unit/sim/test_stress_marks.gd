extends GutTest
## v0.9.5 SM (owner Q14 a: "per enemy within 6 m, a random screen side, x2 once from within 45 degrees, 8 s per
## enemy, bosses carry 4 marks; no levels"): the Stress Mark's weak sides (StressMarks) on dummies and a boss.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 100000
const RIGHT := StressMarks.RIGHT
const LEFT := StressMarks.LEFT


func _world(
	enemies: Array = [[Vector2(3.0, 0.0), HP]], items: Array = [&"shared_stress_mark"]
) -> World:
	var w := W.world(&"blade", items, enemies)
	return w


func _mask(w: World, i: int = 1) -> int:
	return StressMarks.mask_of(w, i)


func _side(w: World, i: int = 1) -> int:
	var m := _mask(w, i)
	for s in 4:
		if m & (1 << s):
			return s
	return -1


## One hero hit on actor 1 arriving FROM `dir` (a unit vector from the enemy toward the attacker), as a bolt.
func _bolt(w: World, dir: Vector2, amount: int = 100) -> int:
	var a := w.actors
	var at := a.pos(1)
	var from := at + dir * 2.0
	var before := a.hp[1]
	Damage.hit(w, 1, amount, a.ids[0], a.ids[0], w.take_root(), SimEvent.TAG_PROJECTILE, from, at)
	return before - a.hp[1]


func _deg(d: float) -> Vector2:
	return Kin.dir(int(d * 4096.0 / 360.0 + 0.5))


func test_the_sides_match_the_iso_camera() -> void:
	var rig := IsoRig.new()
	var toward := rig.toward_camera_on_plane()
	rig.free()
	assert_lt(
		StressMarks.side_dir(StressMarks.DOWN).distance_to(toward), 0.01, "down = toward the camera"
	)
	assert_lt(StressMarks.side_dir(StressMarks.UP).distance_to(-toward), 0.01, "up = away")
	var yaw := deg_to_rad(IsoRig.YAW_DEG)
	var right := SimPlane.to_sim(Vector3(cos(yaw), 0.0, -sin(yaw)))
	assert_lt(
		StressMarks.side_dir(StressMarks.RIGHT).distance_to(right), 0.01, "right = screen right"
	)
	assert_lt(StressMarks.side_dir(StressMarks.LEFT).distance_to(-right), 0.01, "left")


func test_a_mark_appears_only_within_six_metres() -> void:
	var w := _world([[Vector2(7.0, 0.0), HP], [Vector2(5.5, 0.0), HP]])
	W.run(w, 2)
	assert_eq(_mask(w, 1), 0, "7 m: none")
	assert_ne(_mask(w, 2), 0, "5.5 m: one")
	assert_eq(w.stress.rng.state, w.stress.rng.state)
	var ones := 0
	for s in 4:
		ones += 1 if _mask(w, 2) & (1 << s) else 0
	assert_eq(ones, 1, "a non-boss has one side")
	var none := _world([[Vector2(3.0, 0.0), HP]], [])
	W.run(none, 2)
	assert_null(none.stress, "no card, no state")


func test_the_side_comes_from_the_named_stream_by_seed() -> void:
	var seen := {}
	for sd in 12:
		var w := W.world(
			&"blade", [&"shared_stress_mark"], [[Vector2(3.0, 0.0), HP]], [], false, sd
		)
		W.run(w, 2)
		seen[_side(w)] = true
		var again := W.world(
			&"blade", [&"shared_stress_mark"], [[Vector2(3.0, 0.0), HP]], [], false, sd
		)
		W.run(again, 2)
		assert_eq(_side(again), _side(w), "the same seed, the same side")
		assert_eq(again.state_hash(), w.state_hash())
	assert_gt(seen.size(), 1, "other seeds draw other sides")


func test_a_hit_from_the_marked_side_deals_double_once() -> void:
	var w := _world()
	W.run(w, 2)
	var side := _side(w)
	var dir := StressMarks.side_dir(side)
	assert_eq(_bolt(w, dir), 200, "x2 from the marked side")
	assert_eq(_mask(w), 0, "and it breaks")
	assert_eq(_bolt(w, dir), 100, "once")
	assert_eq(W.events(w, SimEvent.Kind.STRESS_BREAK).size(), 1, "one break event")
	assert_eq(W.events(w, SimEvent.Kind.STRESS_BREAK)[0].amount, 100, "carrying the extra")


func test_a_hit_from_the_opposite_side_is_plain() -> void:
	var w := _world()
	W.run(w, 2)
	var side := _side(w)
	assert_eq(_bolt(w, -StressMarks.side_dir(side)), 100)
	assert_eq(_mask(w), 1 << side, "the mark stands")


func test_forty_four_degrees_counts_and_forty_six_does_not() -> void:
	var w := _world()
	W.run(w, 2)
	var side := _side(w)
	var base := float(StressMarks.SIDE_ANGLES[side]) * 360.0 / 4096.0
	assert_eq(_bolt(w, _deg(base + 46.0)), 100, "46 degrees: no")
	assert_eq(_bolt(w, _deg(base - 46.0)), 100, "-46 degrees: no")
	assert_eq(_bolt(w, _deg(base - 44.0)), 200, "44 degrees: yes")


func test_melee_and_area_use_the_enemy_to_origin_direction() -> void:
	var w := _world()
	W.run(w, 2)
	var side := _side(w)
	var a := w.actors
	var origin := a.pos(1) + StressMarks.side_dir(side) * 1.5
	var before := a.hp[1]
	Damage.hit(w, 1, 100, a.ids[0], a.ids[0], w.take_root(), SimEvent.TAG_MELEE, origin, a.pos(1))
	assert_eq(before - a.hp[1], 200, "melee from the marked side")
	W.run(w, 481)
	side = _side(w)
	assert_ne(side, -1, "marked again")
	before = a.hp[1]
	var far := a.pos(1) - StressMarks.side_dir(side) * 1.5
	Damage.hit(w, 1, 100, a.ids[0], a.ids[0], w.take_root(), SimEvent.TAG_AREA, far, a.pos(1))
	assert_eq(before - a.hp[1], 100, "a blast centred on the far side")
	Damage.hit(
		w,
		1,
		100,
		a.ids[0],
		a.ids[0],
		w.take_root(),
		SimEvent.TAG_AREA,
		a.pos(1) + StressMarks.side_dir(side),
		a.pos(1)
	)
	assert_eq(before - a.hp[1], 100 + 200, "and one centred on the marked side")


func test_dot_ticks_and_chains_never_break_it() -> void:
	var w := _world()
	W.run(w, 2)
	var dir := StressMarks.side_dir(_side(w))
	var a := w.actors
	var before := a.hp[1]
	Damage.tick_dot(w, 1, 50, a.ids[0], a.ids[0], &"test")
	Damage.hit(
		w, 1, 100, a.ids[0], a.ids[0], w.take_root(), SimEvent.TAG_CHAIN, a.pos(1) + dir, a.pos(1)
	)
	assert_ne(_mask(w), 0, "still marked")
	assert_lt(before - a.hp[1], 200)


func test_eight_seconds_then_a_new_mark() -> void:
	var w := _world()
	W.run(w, 2)
	_bolt(w, StressMarks.side_dir(_side(w)))
	W.run(w, 470)
	assert_eq(_mask(w), 0, "still waiting at about 7.8 s")
	W.run(w, 20)
	assert_ne(_mask(w), 0, "marked again after 8 s")


func test_marks_clear_on_death_and_when_the_card_is_lost() -> void:
	var w := _world([[Vector2(3.0, 0.0), 50], [Vector2(-3.0, 0.0), HP]])
	W.run(w, 2)
	assert_eq(w.stress.ids.size(), 2)
	w.actors.dead[1] = 1
	W.run(w, 2)
	assert_eq(w.stress.ids.size(), 1, "the dead one's entry goes")
	w.items_owned.clear()
	W.run(w, 2)
	assert_eq(w.stress.ids.size(), 0, "the card is gone: so are the marks")


func test_a_boss_carries_four_marks_each_with_its_own_cooldown() -> void:
	var w := _world([])
	var id := w.take_id()
	w.actors.add(
		id, ActorStore.Kind.GATEKEEPER, ActorStore.TEAM_ENEMY, Vector2(3.0, 0.0), 1.0, HP, 1000000
	)
	_adv(w, 2)
	assert_eq(_mask(w, 1), 15, "all four sides")
	assert_eq(_strike(w, RIGHT), 200)
	assert_eq(_mask(w, 1), 15 & ~(1 << RIGHT), "only that side breaks")
	_adv(w, 240)
	assert_eq(_strike(w, LEFT), 200)
	assert_eq(_mask(w, 1), 15 & ~(1 << RIGHT) & ~(1 << LEFT))
	_adv(w, 250)
	assert_eq(_mask(w, 1) & (1 << RIGHT), 1 << RIGHT, "right is back after its 8 s")
	assert_eq(_mask(w, 1) & (1 << LEFT), 0, "left is still cooling")


## A bare boss body is not stepped; StressMarks is called on it directly.
func _adv(w: World, n: int) -> void:
	for _k in n:
		w.tick += 1
		StressMarks.advance(w)


func _strike(w: World, side: int) -> int:
	var at := w.actors.pos(1)
	var from := at + StressMarks.side_dir(side) * 2.0
	return StressMarks.on_hit(w, 1, 100, SimEvent.TAG_PROJECTILE, from, at, &"")


func test_a_snapshot_round_trips() -> void:
	var w := _world([[Vector2(3.0, 0.0), HP], [Vector2(-3.0, 1.0), HP]])
	W.run(w, 5)
	_bolt(w, StressMarks.side_dir(_side(w)))
	var snap := WorldSnapshot.take(w)
	var base := _world([[Vector2(3.0, 0.0), HP], [Vector2(-3.0, 1.0), HP]])
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.state_hash(), w.state_hash(), "the same hash")
	W.run(w, 600)
	W.run(base, 600)
	assert_eq(base.state_hash(), w.state_hash(), "and on the same")
