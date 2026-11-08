# gdlint: disable=max-public-methods
extends GutTest
## v0.9.5 FC1 (owner: "homing + laser would make the laser follow the neares enemy making a smooth curve, and with
## pierce it would make a smooth curve trying to hit the closest 5 enemies"; FORM_COMBOS.md L1-L11): what the cards do
## to the Laser (LaserMods), one test a row, with the numbers of the table. v0.11.0 O1 (owner, PLAN L1, L2; Q6, Q8,
## Q28): the Laser is a lance, one instant shot every 3 s that passes every enemy on its path; a plain shot deals 95 on
## the dummies (O1d: 19 old ticks of 5). Homing plans one smooth path through up to 5 targets at each shot.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 100000
const AIM_NORTH := 1024
const AIM_WEST := 2048
const SHOT := 95
## The smoothness bound the Homing tests hold: no leg turns more than home_bend_deg (6 degrees, 68 units) from the
## one before, plus 2 units for Kin.angle_of's rounding of a leg's direction.
const BEND_MAX := 68 + 2
## Up to 8 targets in a loose ring ahead (the search's cap).
const CAP_AT: Array[Vector2] = [
	Vector2(2.5, 1.5),
	Vector2(3.5, -1.5),
	Vector2(4.5, 2.5),
	Vector2(5.0, -0.5),
	Vector2(5.5, 3.5),
	Vector2(6.0, -2.5),
	Vector2(7.0, 1.0),
	Vector2(7.5, -1.0),
]


func _world(cards: Array, at: Array) -> World:
	var ids: Array = [&"gun_laser"]
	ids.append_array(cards)
	var enemies := []
	for p: Vector2 in at:
		enemies.append([p, HP])
	return W.world(&"gun", ids, enemies)


func _trace(w: World, aim: int = -1) -> Array[Dictionary]:
	return Laser.trace(w, Modifiers.bolt(w), w.player_pos(), w.aim_angle if aim < 0 else aim)


func _kind(beams: Array[Dictionary], kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in beams:
		if b["kind"] == kind:
			out.append(b)
	return out


func _len(b: Dictionary) -> float:
	return (b["to"] as Vector2).distance_to(b["from"])


## The damage events the player dealt to actor `idx`: [{tick, amount}], in order.
func _hits(w: World, idx: int) -> Array:
	return _hits_id(w, w.actors.ids[idx])


func _hits_id(w: World, id: int) -> Array:
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			out.append({"tick": e.tick, "amount": e.amount, "tags": e.tags})
	return out


## The damage the enemy at rank `k` (0 first) of a path takes of a `first` hit: 850 per mille of the one before, never
## under 400 (v0.11.0 O1c).
func _fall(first: int, k: int) -> int:
	var f := 1000
	for _j in k:
		f = maxi(400, f * 850 / 1000)
	return maxi(1, first * f / 1000)


func _total(w: World, idx: int) -> int:
	var t := 0
	for h: Dictionary in _hits(w, idx):
		t += int(h["amount"])
	return t


func _angle(b: Dictionary) -> int:
	return Kin.angle_of((b["to"] as Vector2) - (b["from"] as Vector2))


## The distance from `p` to the polyline of `legs` (each leg a segment).
func _dist_to_path(legs: Array[Dictionary], p: Vector2) -> float:
	var best := 1.0e9
	for b in legs:
		var a: Vector2 = b["from"]
		var c: Vector2 = b["to"]
		var ab := c - a
		var t := (
			0.0
			if ab.length_squared() < 1.0e-9
			else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## The largest turn (1/4096 turns) from one leg to the next of `legs`.
func _most_turn(legs: Array[Dictionary]) -> int:
	var most := 0
	for k in range(1, legs.size()):
		if _len(legs[k]) < 0.01 or _len(legs[k - 1]) < 0.01:
			continue
		most = maxi(most, Kin.angle_diff(_angle(legs[k]), _angle(legs[k - 1])))
	return most


func test_the_eleven_cards_compile_into_the_masks_and_leave_the_generic_ops_off() -> void:
	var w := _world(
		[&"halo_shot", &"gun_ring", &"gun_backfire", &"gun_homing", &"gun_ricochet"], []
	)
	var s := Modifiers.bolt(w)
	assert_true(Laser.held(s))
	assert_eq(
		LaserMods.mask(s),
		LaserMods.HALO | LaserMods.RING | LaserMods.BACKFIRE | LaserMods.HOMING | LaserMods.RICOCHET
	)
	assert_eq(s.form, AttackSpec.Form.BEAM, "Ring's form op didn't turn the lance into a ring")
	assert_almost_eq(s.radius_m, 0.15, 0.001, "Ring's 2 m radius didn't widen the lance")
	assert_eq([s.directions, s.back_permille, s.bounces, s.homing], [0, 0, 0, 0], "no generic ops")
	assert_eq(LaserMods.mask(Modifiers.bolt(_world([], []))), 0, "a plain Laser has no mask")


func test_the_data_row_holds_every_number_the_code_reads() -> void:
	var w := _world([], [])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	for k: String in LaserMods.DEFAULTS:
		assert_eq(LaserMods.param(w, k), int(LaserMods.DEFAULTS[k]), "%s: data = default" % k)
	assert_true(w.slot_table.params.has(&"laser"))
	var keys := LaserMods.DEFAULTS.keys()
	keys.sort()
	var content_keys := AttackFormRow.LASER_KEYS.duplicate()
	content_keys.sort()
	assert_eq(content_keys, keys, "the validator's key list and the code's agree")


# --- L1 Halo ---------------------------------------------------------------------------------------------------------
func test_l1_halo_fans_three_short_lances_where_the_lance_ends() -> void:
	var w := _world([&"halo_shot"], [Vector2(4.0, 0.0)])
	var main: Dictionary = _kind(_trace(w), &"main")[0]
	var fan := _kind(_trace(w), &"halo")
	assert_eq(fan.size(), 3, "three lances")
	var turns := []
	for b in fan:
		assert_eq(b["share"], 400, "40 %")
		assert_almost_eq((b["from"] as Vector2).x, (main["to"] as Vector2).x, 0.001, "from the tip")
		assert_almost_eq(_len(b), 3.0, 0.01, "3 m")
		turns.append(_angle(b))
	turns.sort()
	assert_almost_eq(float(turns[0]), 0.0, 2.0, "0 degrees (straight on)")
	assert_almost_eq(float(turns[1]), 341.0, 2.0, "+30 degrees")
	assert_almost_eq(float(turns[2]), 4096.0 - 341.0, 2.0, "-30 degrees")
	var tip: Vector2 = main["to"]
	var w2 := _world([&"halo_shot"], [Vector2(4.0, 0.0), tip + Kin.dir(341) * 1.5])
	W.run(w2, 2, 0, W.S)
	assert_eq(_total(w2, 1), SHOT, "the main lance passes the first")
	assert_eq(
		_total(w2, 2), SHOT * 400 / 1000, "a fan lance hits the one beside the tip: 40 % of 150"
	)


# --- L2 Ring ---------------------------------------------------------------------------------------------------------
func test_l2_ring_hits_what_stands_in_a_1_4_m_ring_at_the_tip() -> void:
	var w := _world([&"gun_ring"], [Vector2(9.0, 1.0), Vector2(9.0, 3.0)])
	var rings := _kind(_trace(w), &"ring")
	assert_eq(rings.size(), 1)
	assert_almost_eq(float(rings[0]["circle"]), 1.4, 0.001, "1.4 m")
	assert_eq(rings[0]["share"], 500, "50 %")
	W.run(w, 2, 0, W.S)
	assert_eq(_hits(w, 1).size(), 1, "the one inside the ring is hit once")
	assert_eq(_total(w, 2), 0, "the one outside isn't")
	for h: Dictionary in _hits(w, 1):
		assert_eq(h["amount"], SHOT / 2, "50 % of a shot's 150")
		assert_ne(int(h["tags"]) & SimEvent.TAG_AREA, 0, "an area hit")


# --- L3 Backfire -----------------------------------------------------------------------------------------------------
func test_l3_backfire_is_a_half_length_lance_behind_the_hero() -> void:
	var w := _world([&"gun_backfire"], [Vector2(-3.0, 0.0), Vector2(-6.0, 0.0)])
	var back := _kind(_trace(w), &"back")
	assert_eq(back.size(), 1)
	assert_eq(back[0]["share"], 1000, "100 % of the damage")
	W.run(w, 2, 0, W.S)
	assert_eq(_total(w, 1), SHOT, "the enemy 3 m behind is hit")
	assert_eq(_total(w, 2), 0, "the one 6 m behind is past the 4.5 m lance")
	var w2 := _world([&"gun_backfire"], [])
	var b2: Dictionary = _kind(_trace(w2), &"back")[0]
	assert_almost_eq(_len(b2), 4.5, 0.01, "4.5 m")
	assert_almost_eq(float(_angle(b2)), 2048.0, 2.0, "behind")


# --- L4 Homing -------------------------------------------------------------------------------------------------------
## Q8: without Homing the lance is straight; v0.10.0 FX: it leaves along the player's aim, and an enemy behind the aim
## is no target.
func test_l4_homing_keeps_the_players_aim_and_skips_enemies_behind_it() -> void:
	var w := _world([&"gun_homing"], [Vector2(-3.5, 3.5)])
	var s := Modifiers.bolt(w)
	assert_eq(
		LaserMods.pick(w, s, w.player_pos(), 0).size(), 0, "135 degrees off the aim: not a target"
	)
	var main := _kind(_trace(w, 0), &"main")
	assert_eq(main.size(), 1, "a straight lance")
	assert_almost_eq(float(_angle(main[0])), 0.0, 2.0, "along the aim")
	assert_eq(
		Array(LaserMods.pick(w, s, w.player_pos(), AIM_NORTH)), [1], "aimed north it is in front"
	)
	var bent := _kind(_trace(w, AIM_NORTH), &"main")
	assert_almost_eq(
		float(Kin.angle_diff(_angle(bent[0]), AIM_NORTH)), 0.0, BEND_MAX, "it leaves along the aim"
	)
	W.run(w, 2, 0, W.S, AIM_NORTH)
	assert_eq(_total(w, 1), SHOT, "and the curve hits it")
	var plain := _world([], [Vector2(3.0, 3.0)])
	assert_eq(_kind(_trace(plain, 0), &"main").size(), 1, "no Homing: straight (Q8)")


## v0.10.0 FX (owner: "homing must respect walls"): an enemy behind a wall is no target.
## v0.10.0 FX (owner: "homing must respect walls"): an enemy behind a wall is no first target; v0.11.0 O1: the chain may
## reach it round the wall through one in sight, and no leg of the path crosses the wall.
func test_l4_homing_respects_walls() -> void:
	var w := _world([&"gun_homing"], [Vector2(3.0, 0.0), Vector2(4.0, 3.0)])
	w.add_wall_now(Obb.make(Vector2(2.0, 0.0), Vector2(0.2, 1.0), 0))
	var p := LaserMods.pick(w, Modifiers.bolt(w), w.player_pos(), 421)  # aimed at the one in sight
	assert_eq(Array(p), [2, 1], "the one in sight first, then the one behind the wall from it")
	for b in _kind(_trace(w, 421), &"main"):
		if b != _kind(_trace(w, 421), &"main").back():
			assert_false(bool(b["wall"]), "no leg runs into the wall")
	W.run(w, 2, 0, W.S, 421)
	assert_eq(_total(w, 2), SHOT, "the one in sight is hit")
	assert_eq(
		_total(w, 1),
		_fall(SHOT, 1),
		"and the one behind the wall, round it (O1c: second, 15 % less)"
	)
	var alone := _world([&"gun_homing"], [Vector2(3.0, 0.0)])
	alone.add_wall_now(Obb.make(Vector2(2.0, 0.0), Vector2(0.2, 1.0), 0))
	assert_eq(
		LaserMods.pick(alone, Modifiers.bolt(alone), alone.player_pos(), 0).size(),
		0,
		"alone behind it: none"
	)


func test_l4_homing_bends_one_smooth_path_through_the_nearest_enemy() -> void:
	var w := _world([&"gun_homing"], [Vector2(3.0, 3.0)])
	var main := _kind(_trace(w, 0), &"main")
	assert_gt(main.size(), 3, "a curve of short legs")
	assert_lt(_dist_to_path(main, Vector2(3.0, 3.0)), 0.35, "it passes within the target's radius")
	assert_lte(_most_turn(main), BEND_MAX, "no leg turns more than 6 degrees from the one before")
	for k in main.size() - 1:
		assert_lte(_len(main[k]), 0.451, "short legs on the arc (home_step_mm)")
	assert_almost_eq(
		_len(main[main.size() - 1]),
		LaserMods.TAIL_MAX_M,
		0.05,
		"then straight on, TAIL_MAX_M with no wall (v0.11.0 O1c; was the 9 m range)"
	)
	var last := main[main.size() - 1]
	assert_almost_eq(
		float(Kin.angle_diff(_angle(last), _angle(main[main.size() - 2]))),
		0.0,
		float(BEND_MAX),
		"then straight on from the curve's end tangent (v0.11.0 O1d: its arrival heading, no kink)"
	)


func test_l4_homing_threads_five_enemies_nearest_first_in_one_shot() -> void:
	var at := [
		Vector2(2.0, 0.3),
		Vector2(3.3, 1.0),
		Vector2(4.2, 2.1),
		Vector2(4.7, 3.4),
		Vector2(4.8, 4.8),
		Vector2(-8.5, 0.0),
	]
	var w := _world([&"gun_homing"], at)
	var s := Modifiers.bolt(w)
	assert_eq(
		Array(LaserMods.pick(w, s, w.player_pos(), 0)),
		[1, 2, 3, 4, 5],
		"all five in range, nearest first"
	)
	var main := _kind(_trace(w, 0), &"main")
	for k in 5:
		var d := _dist_to_path(main, at[k])
		assert_lt(d, 0.35, "the path passes within target %d's radius (%.3f m)" % [k + 1, d])
	assert_lte(_most_turn(main), BEND_MAX, "one smooth path: no leg turns more than 6 degrees")
	gut.p("O1 homing chain: %d legs, the most turn %d units" % [main.size(), _most_turn(main)])
	W.run(w, 2, 0, W.S)
	for k in [1, 2, 3, 4, 5]:
		assert_eq(_total(w, k), _fall(SHOT, k - 1), "enemy %d is hit once by the shot" % k)
	assert_eq(_total(w, 6), 0, "the far one behind isn't")
	var plain := _world([], at)
	W.run(plain, 2, 0, W.S)
	var hit := 0
	for k in [2, 3, 4, 5]:
		hit += 1 if _total(plain, k) > 0 else 0
	assert_lte(hit, 1, "a straight lance misses most of that arc")


func test_l4_homing_skips_a_dead_target_at_the_next_shot() -> void:
	var w := _world([&"gun_homing"], [Vector2(2.0, 2.0), Vector2(1.0, 6.0)])
	var s := Modifiers.bolt(w)
	assert_eq(Array(LaserMods.pick(w, s, w.player_pos(), 0)), [1, 2])
	w.actors.dead[1] = 1
	assert_eq(Array(LaserMods.pick(w, s, w.player_pos(), 0)), [2], "the dead one is no target")


# --- L5 Ricochet -----------------------------------------------------------------------------------------------------
func test_l5_ricochet_reflects_once_and_keeps_its_nine_metres() -> void:
	var w := _world([&"gun_ricochet"], [Vector2(-3.0, 0.0)])
	w.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 3.0), 0))
	var main := _kind(_trace(w), &"main")
	assert_eq(main.size(), 2, "one reflection")
	assert_true(bool(main[0]["wall"]))
	assert_lt((main[1]["to"] as Vector2).x, (main[1]["from"] as Vector2).x, "back toward the hero")
	W.run(w, 2, 0, W.S)
	assert_eq(_total(w, 1), SHOT, "the enemy behind the hero is hit by the return leg")
	var bare := _world([&"gun_ricochet"], [])
	bare.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 3.0), 0))
	var legs := _kind(_trace(bare), &"main")
	assert_eq(legs.size(), 2)
	assert_almost_eq(_len(legs[0]) + _len(legs[1]), 9.0, 0.1, "the full 9 m reach")
	var w2 := _world([&"gun_ricochet"], [])
	w2.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 3.0), 0))
	w2.add_wall_now(Obb.make(Vector2(-3.0, 0.0), Vector2(0.2, 3.0), 0))
	assert_eq(_kind(_trace(w2), &"main").size(), 2, "only once: the second wall stops it")


# --- L6 Echo ---------------------------------------------------------------------------------------------------------
func test_l6_echo_strikes_the_same_path_again_0_4_s_later_at_half() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0), Vector2(6.0, 0.0)])
	W.run(w, 90, 0, W.S)
	for idx in [1, 2]:
		var hits := _hits(w, idx)
		assert_eq(hits.size(), 2, "enemy %d: the shot, then its echo" % idx)
		var rank: int = idx - 1  # O1c: the second enemy takes 15 % less, in the shot and the echo
		assert_eq(hits[0]["amount"], _fall(SHOT, rank), "the shot")
		assert_eq(hits[1]["amount"], _fall(SHOT / 2, rank), "the echo at 50 % (Q6)")
		assert_eq(int(hits[1]["tick"]) - int(hits[0]["tick"]), 24, "0.4 s later")
	assert_eq(w.mx.lz_echo_due.size(), 0, "the strike is spent")
	var v := _world([&"gun_echo"], [])
	W.run(v, 2, 0, W.S)
	assert_gt(WorldReader.new(v).laser_ghosts().size(), 0, "the view has a ghost to draw")


# --- L7 Big Shot -----------------------------------------------------------------------------------------------------
func test_l7_big_shot_is_twice_as_wide_hits_60_percent_harder_and_has_no_aim_lag() -> void:
	var w := _world([&"gun_big_shot"], [Vector2(4.0, 0.0)])
	var b: Dictionary = _trace(w)[0]
	assert_eq(b["wmul"], 2000, "twice as wide")
	W.run(w, 2, 0, W.S)
	assert_eq(_total(w, 1), SHOT * 1600 / 1000, "x1.6: 240 a shot (Q6)")
	var t := _world([&"gun_big_shot"], [])
	W.run(t, 1, 0, W.S, 0)
	var north := _kind(_trace(t, AIM_NORTH), &"main")[0]
	assert_almost_eq(
		float(_angle(north)), float(AIM_NORTH), 2.0, "along the aim at once: no lag (Q6)"
	)


# --- L8 Rapid Fire ---------------------------------------------------------------------------------------------------
func test_l8_rapid_fire_fires_30_percent_more_often_at_20_percent_less_a_shot() -> void:
	var w := _world([&"gun_rapid_fire"], [Vector2(4.0, 0.0)])
	var s := Modifiers.bolt(w)
	assert_eq(ItemEffects.shot_period_ticks(w), 126, "3 s x 0.7 = 2.1 s")
	assert_eq(LaserMods.rapid_period(w, s, 180), 126)
	assert_eq(LaserMods.damage_permille(w, LaserMods.RAPID), 800)
	assert_eq(LaserMods.width_permille(w, LaserMods.RAPID), 1000, "no thinning")
	W.run(w, 200, 0, W.S)
	var hits := _hits(w, 1)
	assert_eq(hits.size(), 2)
	assert_eq(int(hits[1]["tick"]) - int(hits[0]["tick"]), 126, "2.1 s apart")
	for h: Dictionary in hits:
		assert_eq(h["amount"], SHOT * 800 / 1000, "-20 %: 120 a shot")


# --- L9 Split --------------------------------------------------------------------------------------------------------
func test_l9_split_forks_in_two_beyond_the_first_enemy() -> void:
	var w := _world([&"split_shot"], [Vector2(4.0, 0.0), Vector2(5.5, 1.0)])
	var forks := _kind(_trace(w), &"split")
	assert_eq(forks.size(), 2)
	for b in forks:
		assert_eq(b["share"], 500, "50 %")
	var angles := [_angle(forks[0]), _angle(forks[1])]
	angles.sort()
	assert_almost_eq(float(angles[0]), 284.0, 3.0, "+25 degrees")
	assert_almost_eq(float(angles[1]), 4096.0 - 284.0, 3.0, "-25 degrees")
	W.run(w, 2, 0, W.S)
	assert_eq(_total(w, 2), SHOT / 2, "a fork reaches the second enemy: 50 % of 150")
	var w2 := _world([&"split_shot"], [Vector2(4.0, 0.0)])
	for b in _kind(_trace(w2), &"split"):
		assert_almost_eq(_len(b), 4.0, 0.01, "4 m")
	var none := _world([&"split_shot"], [])
	assert_eq(_kind(_trace(none), &"split").size(), 0, "no enemy hit, no fork")


# --- L10 Mine (Q6: not offered with the Laser, test_laser) -----------------------------------------------------------
func test_l10_a_held_mine_from_a_lab_still_drops_one_at_the_tip_each_shot() -> void:
	var w := _world([&"gun_mine"], [])
	W.run(w, 2, 0, W.S)
	assert_eq(w.mx.lz_mine_at.size(), 1, "one mine with the shot")
	var at: Vector2 = w.mx.lz_mine_at[0]
	assert_gt(at.x, 8.0, "at the lance's tip (9 m)")
	assert_eq(WorldReader.new(w).laser_mines().size(), 1)
	var near := w.add_dummy(at + Vector2(0.4, 0.0), 0.35, HP)
	W.run(w, 2, 0, 0)
	var dealt := _hits_id(w, near)
	assert_eq(dealt.size(), 1, "the burst hit it")
	assert_eq(dealt[0]["amount"], 25, "five old ticks (5.0) x 5")
	assert_eq(w.mx.lz_mine_at.size(), 0, "the mine that went off is gone")


# --- L11 Spiral ------------------------------------------------------------------------------------------------------
func test_l11_spiral_swings_each_shot_12_degrees_on_the_sim_clock() -> void:
	var w := _world([&"gun_spiral"], [])
	var offs := []
	for t in 60:
		w.tick = t
		offs.append(LaserMods.spiral_offset(w))
	assert_eq(offs.max(), 136, "+12 degrees")
	assert_eq(offs.min(), -136, "-12 degrees")
	for t in 30:
		assert_eq(offs[t], offs[t + 30], "a period is 30 ticks: 2 times a second")
	assert_lt(absi(offs[0]), 10, "it starts near the middle")
	assert_gt(offs[7], 120)
	assert_lt(offs[22], -120)
	w.tick = 7
	W.run(w, 1, 0, W.S)
	var b: Dictionary = WorldReader.new(w).beams()[0]
	assert_gt(_angle(b), 100, "the shot fired at tick 7 is turned by the swing")


# --- Caps, determinism, snapshots -----------------------------------------------------------------------------------
func test_extra_paths_launch_no_projectiles_and_each_kind_hits_once_a_shot() -> void:
	var w := _world(
		[&"halo_shot", &"gun_ring", &"gun_backfire", &"split_shot"],
		[Vector2(2.0, 0.0), Vector2(3.0, 0.5), Vector2(4.0, -0.5), Vector2(-2.0, 0.0)]
	)
	var s := Modifiers.bolt(w)
	assert_eq(LaserMods.mask(s) & (LaserMods.HALO | LaserMods.RING | LaserMods.BACKFIRE), 7)
	W.run(w, 2, 0, W.S)
	assert_eq(w.projectiles.ids.size(), 0, "a lance is no projectile, forks included")
	assert_gt(_total(w, 1), 0, "the main lance")
	assert_gt(_total(w, 4), 0, "Backfire")
	var mains := _hits(w, 1).filter(func(h: Dictionary) -> bool: return h["amount"] == SHOT)
	assert_eq(mains.size(), 1, "the main lance hits an enemy once a shot")
	assert_lte(_trace(w).size(), LaserMods.MAX_LEGS * 3, "the path is bounded")


func _all_cards() -> Array:
	return [&"gun_homing", &"gun_echo", &"gun_mine", &"gun_ring"]


func test_a_card_laser_is_deterministic_and_its_state_round_trips_a_snapshot() -> void:
	var at := [Vector2(2.0, 1.0), Vector2(3.5, -1.0), Vector2(-3.0, 2.0), Vector2(5.0, 3.0)]
	var a := _world(_all_cards(), at)
	var b := _world(_all_cards(), at)
	W.run(a, 190, 0, W.S, 700)
	W.run(b, 190, 0, W.S, 700)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.lz_touched(), "the Laser state is set")
	assert_gt(a.mx.lz_echo_due.size(), 0, "the second shot's echo waits")
	var snap := WorldSnapshot.take(a)
	var c := _world(_all_cards(), at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.lz_echo_due, a.mx.lz_echo_due)
	assert_eq(c.mx.lz_mine_at, a.mx.lz_mine_at)
	assert_eq(c.mx.lz_shot_from, a.mx.lz_shot_from, "the view's record too")
	W.run(a, 60, 0, W.S, 700)
	W.run(c, 60, 0, W.S, 700)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_without_a_card_the_laser_state_stays_unset() -> void:
	var w := _world([], [Vector2(3.0, 0.0)])
	W.run(w, 120, 0, W.S)
	assert_false(
		w.mx.lz_touched(), "a plain Laser leaves the hashed state alone (older digests hold)"
	)
	assert_eq(w.mx.lz_shot_tick, 0, "only the view's record of its shot")
	var h := w.state_hash()
	w.mx.lz_shot_from = PackedVector2Array()
	assert_eq(w.state_hash(), h, "the record is not hashed: it decides nothing")


## L2 (owner: "connect multiple enemies through a single smooth, curved trajectory"): five enemies on a 3 m arc at 4 m
## (forms_dps' pack): the chain runs along the pack, one smooth path through all five.
func test_l4_homing_runs_along_a_pack_in_one_smooth_path() -> void:
	var at := []
	for k in 5:
		var a := -0.75 + 0.375 * k
		at.append(Vector2(cos(a), sin(a)) * 4.0)
	var w := _world([&"gun_homing"], at)
	var main := _kind(_trace(w, 0), &"main")
	for k in 5:
		assert_lt(_dist_to_path(main, at[k]), 0.35, "the path passes target %d" % (k + 1))
	assert_lte(_most_turn(main), BEND_MAX, "no leg turns more than 6 degrees from the one before")
	gut.p("O1 homing pack: %d legs, the most turn %d units" % [main.size(), _most_turn(main)])
	W.run(w, 2, 0, W.S)
	for k in range(1, 6):
		assert_eq(_total(w, k), _fall(SHOT, k - 1), "enemy %d is hit once" % k)


## v0.11.0 O1c (owner): after Homing's last target the lance runs straight on to the first wall, not to the 9 m reach.
func test_o1c_homing_tail_runs_on_to_a_wall_20_m_away() -> void:
	var w := _world([&"gun_homing"], [Vector2(3.0, 0.0)])
	w.add_wall_now(Obb.make(Vector2(20.0, 0.0), Vector2(0.2, 6.0), 0))
	var main := _kind(_trace(w, 0), &"main")
	var last := main[main.size() - 1]
	assert_true(bool(last["wall"]), "the tail ends on the wall")
	assert_almost_eq((last["to"] as Vector2).x, 19.8, 0.5, "within 0.5 m of the wall's face")
	assert_gt((last["to"] as Vector2).distance_to(w.player_pos()), 15.0, "far past the 9 m reach")


func test_o1c_homing_tail_without_a_wall_stops_at_the_cap() -> void:
	var w := _world([&"gun_homing"], [Vector2(3.0, 0.0)])
	var main := _kind(_trace(w, 0), &"main")
	var last := main[main.size() - 1]
	assert_false(bool(last["wall"]))
	assert_almost_eq(_len(last), LaserMods.TAIL_MAX_M, 0.05, "TAIL_MAX_M (40 m) of straight run")


func test_o1c_without_homing_the_lance_still_ends_at_9_m() -> void:
	var w := _world([&"gun_ricochet"], [Vector2(3.0, 0.0)])
	var main := _kind(_trace(w, 0), &"main")
	var tip: Vector2 = main[main.size() - 1]["to"]
	assert_lt(tip.distance_to(w.player_pos()), 9.5, "the reach (from the hero's edge), no farther")
	var plain := W.world(&"gun", [&"gun_laser"], [[Vector2(3.0, 0.0), HP]])
	var b := Laser.trace(plain, Modifiers.bolt(plain), plain.player_pos(), 0)[0]
	assert_almost_eq(_len(b), 9.0, 0.001, "a plain lance: 9 m")


# --- v0.11.0 O1d (owner, 2026-11-08): the order search, the smoother curve and Twin's own enemies ---------------------
func _pool_of(w: World) -> Array[int]:
	var out: Array[int] = []
	for i in range(1, w.actors.size()):
		out.append(i)
	return out


func test_o1d_homing_takes_up_to_eight_and_the_search_is_bounded() -> void:
	var w := _world([&"gun_homing"], CAP_AT)
	var s := Modifiers.bolt(w)
	var p := LaserMods.pick(w, s, w.player_pos(), 0)
	assert_eq(p.size(), 8, "up to 8 (home_chain 8): %s" % str(Array(p)))
	var sight := {}
	var order := LaserHoming.order(w, w.player_pos(), 0, _pool_of(w), sight)
	assert_eq(order.size(), 8)
	assert_lte(sight.size(), 8 * (8 + 1), "one look per pair: at most n x (n + 1) sight checks")
	var nine: Array = CAP_AT.duplicate()
	nine.append(Vector2(8.0, 0.5))
	var w9 := _world([&"gun_homing"], nine)
	assert_eq(LaserMods.pick(w9, Modifiers.bolt(w9), w9.player_pos(), 0).size(), 8, "never more")


func test_o1d_the_order_runs_round_a_pack_not_across_it() -> void:
	var at := [
		Vector2(2.0, 0.0),
		Vector2(5.0, 0.3),
		Vector2(3.0, 0.1),
		Vector2(6.5, 0.0),
		Vector2(4.0, -0.2),
	]
	var w := _world([&"gun_homing"], at)
	assert_eq(
		Array(LaserMods.pick(w, Modifiers.bolt(w), w.player_pos(), 0)),
		[1, 3, 5, 2, 4],
		"down the line, nearest first (found by the shortest chain, not the input's order)"
	)


func test_o1d_the_curve_never_kinks_through_eight_targets_under_the_leg_cap() -> void:
	var w := _world([&"gun_homing"], CAP_AT)
	var main := _kind(_trace(w, 0), &"main")
	assert_lte(main.size(), LaserMods.MAX_LEGS, "the leg cap holds")
	for k in 8:
		assert_lt(_dist_to_path(main, CAP_AT[k]), 0.35, "target %d is on the path" % (k + 1))
	assert_lte(_most_turn(main), BEND_MAX, "no leg-to-leg kink: at most 6 degrees")
	var tail := main[main.size() - 1]
	assert_almost_eq(_len(tail), LaserMods.TAIL_MAX_M, 0.05, "the tail is still there at the end")


func _twin_lens(aim: int = 0) -> Dictionary:
	var w := _world([&"gun_twin", &"gun_homing"], [Vector2(6.0, 0.0)])
	var by: Array = [[], []]
	for b in _kind(_trace(w, aim), &"main"):
		by[int(b["lane"])].append(b)
	return {"w": w, "a": by[0], "b": by[1]}


func test_o1d_twin_homing_on_one_enemy_bows_out_and_meets_on_it() -> void:
	var l := _twin_lens()
	var a: Array = l["a"]
	var b: Array = l["b"]
	assert_gt(a.size(), 3, "lane 0 is a curve")
	assert_gt(b.size(), 3, "lane 1 is a curve")
	var target := Vector2(6.0, 0.0)
	assert_lt(_dist_to_path_any(a, target), 0.35, "lane 0 reaches the enemy")
	assert_lt(_dist_to_path_any(b, target), 0.35, "lane 1 reaches the enemy")
	var widest := 0.0
	for leg: Dictionary in a:
		var p: Vector2 = leg["to"]
		if p.x > 0.8 and p.x < 5.2:
			var q := _nearest_on(b, p)
			widest = maxf(widest, p.distance_to(q))
			assert_gt(
				p.distance_to(q), 0.4, "the two rays never lie on top of each other, x %.2f" % p.x
			)
	assert_gt(widest, 1.5, "a wide lens")
	assert_lt(float(a[0]["to"].y), 0.0, "lane 0 leaves on its own side (clockwise)")
	assert_gt(float(b[0]["to"].y), 0.0, "lane 1 leaves on the other")
	var ta: Dictionary = a[a.size() - 1]
	var tb: Dictionary = b[b.size() - 1]
	assert_gt(Kin.angle_diff(_angle(ta), _angle(tb)), 200, "the tails fan apart past the enemy")


func test_o1d_without_homing_twin_stays_straight_and_side_by_side() -> void:
	var w := _world([&"gun_twin"], [Vector2(6.0, 0.0)])
	var main := _kind(_trace(w, 0), &"main")
	assert_eq(main.size(), 2, "two straight lances (Q8)")
	assert_almost_eq(float(_angle(main[0])), 0.0, 2.0, "along the aim")
	assert_almost_eq(float(_angle(main[1])), 0.0, 2.0, "along the aim")
	assert_gt(absf((main[0]["from"] as Vector2).y - (main[1]["from"] as Vector2).y), 0.3)


func _lane_hits(beams: Array[Dictionary], lane: int) -> Dictionary:
	var ids := {}
	for b in beams:
		if b["kind"] == LaserMods.K_MAIN and int(b["lane"]) == lane:
			for i in b["hits"]:
				ids[i] = true
	return ids


func test_o1d_twin_homing_on_a_pack_gives_each_ray_its_own_enemies() -> void:
	var at := [Vector2(4.0, 2.5), Vector2(5.0, 3.5), Vector2(4.0, -2.5), Vector2(5.0, -3.5)]
	var w := _world([&"gun_twin", &"gun_homing"], at)
	var beams := _trace(w, 0)
	var a := _lane_hits(beams, 0)
	var b := _lane_hits(beams, 1)
	assert_true(
		a.has(3) and a.has(4),
		"lane 0 (clockwise) takes the enemies on its side: %s" % str(a.keys())
	)
	assert_true(b.has(1) and b.has(2), "lane 1 takes the other side: %s" % str(b.keys()))
	assert_false(a.has(1) or a.has(2), "not the other lane's")
	assert_false(b.has(3) or b.has(4), "not the other lane's")


func test_o1d_three_rays_share_two_enemies_without_overlapping() -> void:
	var w := _world([&"gun_twin", &"gun_homing"], [Vector2(5.0, 1.5), Vector2(5.0, -1.5)])
	CardLevels.set_level(w, W.item(w, &"gun_twin"), 3)
	var beams := _trace(w, 0)
	var lanes := {}
	for b in beams:
		if b["kind"] == LaserMods.K_MAIN:
			lanes[int(b["lane"])] = true
	assert_eq(lanes.size(), 3, "three rays (Lv 3 and up)")
	for li: int in lanes:
		assert_gt(_lane_hits(beams, li).size(), 0, "ray %d meets a target" % li)


func test_o1d_a_bow_flattens_for_a_wall_and_still_reaches_its_target() -> void:
	var target := Vector2(6.0, 0.0)
	var clear := _world([&"gun_twin", &"gun_homing"], [target])
	var free_a: Array = []
	for b in _kind(_trace(clear, 0), &"main"):
		if int(b["lane"]) == 1:
			free_a.append(b)
	var widest_free := 0.0
	for leg: Dictionary in free_a:
		if (leg["to"] as Vector2).x < 5.5:
			widest_free = maxf(widest_free, absf((leg["to"] as Vector2).y))
	var w := _world([&"gun_twin", &"gun_homing"], [target])
	w.add_wall_now(Obb.make(Vector2(3.0, 1.2), Vector2(2.0, 0.2), 0))  # just inside the left bow
	var left: Array = []
	for b in _kind(_trace(w, 0), &"main"):
		if int(b["lane"]) == 1:
			left.append(b)
	var widest := 0.0
	for leg: Dictionary in left:
		if (leg["to"] as Vector2).x < 5.5:
			widest = maxf(widest, absf((leg["to"] as Vector2).y))
		assert_false(
			bool(leg["wall"]) and (leg["to"] as Vector2).x < 5.5,
			"no leg ends on the wall before the target"
		)
	assert_lt(widest, widest_free - 0.2, "a flatter bow (%.2f, free %.2f)" % [widest, widest_free])
	assert_lt(_dist_to_path_any(left, target), 0.35, "it still reaches the enemy")


func test_o1d_twin_on_one_enemy_deals_two_shares_with_homing() -> void:
	var w := _world([&"gun_twin", &"gun_homing"], [Vector2(5.0, 0.0)])
	W.run(w, 2, 0, W.S)
	var hits := _hits(w, 1)
	assert_eq(hits.size(), 2, "both rays hit it once")
	assert_eq(
		int(hits[0]["amount"]) + int(hits[1]["amount"]),
		2 * (19 * 3500 / 1000),
		"2 x 19 x (5.0 x 70 %)"
	)


## v0.11.0 O1f (owner, 2026-11-08: "split rays at full damage").
func test_o1f_a_ray_with_its_own_enemies_deals_its_full_share() -> void:
	var at := [Vector2(4.0, 2.5), Vector2(5.0, 3.5), Vector2(4.0, -2.5), Vector2(5.0, -3.5)]
	var w := _world([&"gun_twin", &"gun_homing"], at)
	W.run(w, 2, 0, W.S)
	for k in [1, 3]:
		assert_eq(_total(w, k), SHOT, "enemy %d: the first of its ray, the lance's full 95" % k)
	for k in [2, 4]:
		assert_eq(_total(w, k), _fall(SHOT, 1), "enemy %d: the falloff stays per ray" % k)


func test_o1f_rays_that_share_a_target_keep_twins_share() -> void:
	var share := 19 * 3500 / 1000
	var w := _world([&"gun_twin", &"gun_homing"], [Vector2(5.0, 0.0)])
	W.run(w, 2, 0, W.S)
	var hits := _hits(w, 1)
	assert_eq(hits.size(), 2, "both rays meet on it")
	for h: Dictionary in hits:
		assert_eq(h["amount"], share, "each deals 70 % (Twin Lv 1)")
	var three := _world([&"gun_twin", &"gun_homing"], [Vector2(5.0, 1.5), Vector2(5.0, -1.5)])
	CardLevels.set_level(three, W.item(three, &"gun_twin"), 3)
	var own := {}
	for b in _kind(_trace(three, 0), &"main"):
		own[int(b["lane"])] = bool(b["own"])
	assert_eq(own[0], true, "three rays, two enemies: the ray alone on its enemy has it to itself")
	assert_eq(own[1], false, "the two that share the other keep Twin's share")
	assert_eq(own[2], false, "the two that share the other keep Twin's share")


func test_o1f_twin_homing_on_a_pack_is_at_least_homing_alone() -> void:
	for at: Array in [
		[
			Vector2(3.0, 2.0),
			Vector2(3.5, 1.0),
			Vector2(4.0, 0.0),
			Vector2(3.5, -1.0),
			Vector2(3.0, -2.0)
		],
		CAP_AT,
	]:
		var alone := _world([&"gun_homing"], at)
		W.run(alone, 2, 0, W.S)
		var twin := _world([&"gun_twin", &"gun_homing"], at)
		W.run(twin, 2, 0, W.S)
		var three := _world([&"gun_twin", &"gun_homing"], at)
		CardLevels.set_level(three, W.item(three, &"gun_twin"), 3)
		W.run(three, 2, 0, W.S)
		var d := [0, 0, 0]
		for k in range(1, at.size() + 1):
			d[0] += _total(alone, k)
			d[1] += _total(twin, k)
			d[2] += _total(three, k)
		assert_gte(d[1], d[0], "Twin Lv 1 %d vs Homing alone %d" % [d[1], d[0]])
		assert_gte(d[2], d[0], "Twin Lv 3 %d vs Homing alone %d" % [d[2], d[0]])


func test_o1f_echo_strikes_an_own_ray_at_half_of_its_full_damage() -> void:
	var at := [Vector2(4.0, 2.5), Vector2(4.0, -2.5)]
	var w := _world([&"gun_twin", &"gun_homing", &"gun_echo"], at)
	W.run(w, 40, 0, W.S)
	var hits := _hits(w, 1)
	assert_eq(hits.size(), 2, "the shot, then its echo")
	assert_eq(hits[0]["amount"], SHOT, "full")
	assert_eq(hits[1]["amount"], SHOT / 2, "the echo at 50 % of it")


func _dist_to_path_any(legs: Array, p: Vector2) -> float:
	var t: Array[Dictionary] = []
	t.assign(legs)
	return _dist_to_path(t, p)


func _nearest_on(legs: Array, p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var d := 1.0e9
	for leg: Dictionary in legs:
		var a: Vector2 = leg["from"]
		var ab: Vector2 = (leg["to"] as Vector2) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0e-9), 0.0, 1.0)
		var q := a + ab * t
		if p.distance_to(q) < d:
			d = p.distance_to(q)
			best = q
	return best
