extends GutTest
## v0.9.5 FC1 (owner: "homing + laser would make the laser follow the neares enemy making a smooth curve, and with
## pierce it would make a smooth curve trying to hit the closest 5 enemies"; FORM_COMBOS.md L1-L11): what the eleven
## cards do to the Laser's beam (LaserMods), one test a row, with the numbers of the table. The tick damage of the
## plain Laser on the dummies is 4 (800 per mille of the orb's 5).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 100000
const AIM_NORTH := 1024
const AIM_WEST := 2048


func _world(cards: Array, at: Array) -> World:
	var ids: Array = [&"gun_laser"]
	ids.append_array(cards)
	var enemies := []
	for p: Vector2 in at:
		enemies.append([p, HP])
	return W.world(&"gun", ids, enemies)


func _trace(w: World) -> Array[Dictionary]:
	return Laser.trace(w, Modifiers.bolt(w), w.player_pos(), w.aim_angle)


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


func _total(w: World, idx: int) -> int:
	var t := 0
	for h: Dictionary in _hits(w, idx):
		t += int(h["amount"])
	return t


func _angle(b: Dictionary) -> int:
	return Kin.angle_of((b["to"] as Vector2) - (b["from"] as Vector2))


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
	assert_eq(s.form, AttackSpec.Form.BEAM, "Ring's form op didn't turn the beam into a ring")
	assert_almost_eq(s.radius_m, 0.15, 0.001, "Ring's 2 m radius didn't widen the beam")
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
func test_l1_halo_fans_three_short_beams_where_the_beam_ends() -> void:
	var w := _world([&"halo_shot"], [Vector2(4.0, 0.0)])
	W.run(w, 2, 0, W.S)
	var main: Dictionary = _kind(_trace(w), &"main")[0]
	var fan := _kind(_trace(w), &"halo")
	assert_eq(fan.size(), 3, "three beams")
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
	var w2 := _world([&"halo_shot"], [Vector2(4.0, 0.0), Vector2(4.8, 0.75)])
	W.run(w2, 60, 0, W.S)
	assert_gt(_total(w2, 2), 0, "a fan beam reaches the enemy beside the tip")
	for h: Dictionary in _hits(w2, 2):
		assert_eq(h["amount"], 1, "40 % of 4, at least 1")


# --- L2 Ring ---------------------------------------------------------------------------------------------------------
func test_l2_ring_hits_what_stands_in_a_1_4_m_ring_at_the_tip() -> void:
	var w := _world([&"gun_ring"], [Vector2(4.0, 0.0), Vector2(4.5, 1.0), Vector2(4.5, 3.0)])
	W.run(w, 2, 0, W.S)
	var rings := _kind(_trace(w), &"ring")
	assert_eq(rings.size(), 1)
	assert_almost_eq(float(rings[0]["circle"]), 1.4, 0.001, "1.4 m")
	assert_eq(rings[0]["share"], 500, "50 %")
	W.run(w, 58, 0, W.S)
	assert_gt(_total(w, 2), 0, "the one inside the ring burns")
	assert_eq(_total(w, 3), 0, "the one outside doesn't")
	for h: Dictionary in _hits(w, 2):
		assert_eq(h["amount"], 2, "50 % of a tick's 4")
		assert_ne(int(h["tags"]) & SimEvent.TAG_AREA, 0, "an area hit")


# --- L3 Backfire -----------------------------------------------------------------------------------------------------
func test_l3_backfire_is_a_half_length_beam_behind_the_hero() -> void:
	var w := _world([&"gun_backfire"], [Vector2(-3.0, 0.0), Vector2(-6.0, 0.0)])
	W.run(w, 2, 0, W.S)
	var back := _kind(_trace(w), &"back")
	assert_eq(back.size(), 1)
	assert_eq(back[0]["share"], 1000, "100 % of the damage")
	W.run(w, 58, 0, W.S)
	assert_gt(_total(w, 1), 0, "the enemy 3 m behind is hit")
	assert_eq(_total(w, 2), 0, "the one 6 m behind is past the 4.5 m beam")
	var w2 := _world([&"gun_backfire"], [])
	W.run(w2, 2, 0, W.S)
	var b2: Dictionary = _kind(_trace(w2), &"back")[0]
	assert_almost_eq(_len(b2), 4.5, 0.01, "4.5 m")
	assert_almost_eq(float(_angle(b2)), 2048.0, 2.0, "behind")


# --- L4 Homing -------------------------------------------------------------------------------------------------------
func test_l4_homing_turns_the_beams_aim_at_most_120_degrees_a_second() -> void:
	var w := _world([&"gun_homing"], [Vector2(-3.5, 3.5)])
	W.run(w, 1, 0, W.S)
	var first := w.mx.lz_aim
	assert_gte(first, 0)
	var steps := 0
	var worst := 0
	var prev := first
	var at_60 := -1
	for k in 70:
		W.run(w, 1, 0, W.S)
		steps = Kin.angle_diff(w.mx.lz_aim, prev)
		prev = w.mx.lz_aim
		worst = maxi(worst, steps)
		if k == 58:
			at_60 = w.mx.lz_aim
	assert_lte(worst, 23, "at most 2 degrees a tick (22.8 units)")
	assert_lte(Kin.angle_diff(at_60, first), 1366, "at most 120 degrees over one second")
	assert_gt(Kin.angle_diff(at_60, first), 1300, "and it does turn that fast toward the enemy")
	W.run(w, 40, 0, W.S)
	assert_eq(w.mx.lz_aim, 1536, "it settles on the enemy (135 degrees)")
	assert_gt(_total(w, 1), 0, "and burns it")


func test_l4_homing_bends_the_path_toward_the_nearest_enemy() -> void:
	var w := _world([&"gun_homing"], [Vector2(3.0, 3.0)])
	W.run(w, 2, 0, W.S)
	var main := _kind(_trace(w), &"main")
	assert_gt(main.size(), 1, "a curve of short legs")
	var a0 := _angle(main[0])
	var a1 := _angle(main[main.size() - 1])
	assert_ne(a0, a1, "its heading changes along the path")
	assert_lte(Kin.angle_diff(a0, a1), 25 * 12 * 3, "smooth")
	var total := 0.0
	for b in main:
		total += _len(b)
	assert_lte(total, 9.01, "within the 9 m reach")


func test_l4_homing_with_pierce_threads_five_enemies_nearest_first() -> void:
	var at := [
		Vector2(2.0, 0.3),
		Vector2(3.5, 1.2),
		Vector2(4.5, 2.6),
		Vector2(5.0, 4.2),
		Vector2(4.8, 5.8),
		Vector2(-8.5, 0.0),
	]
	var w := _world([&"gun_homing", &"gun_pierce"], at)
	W.run(w, 2, 0, W.S)
	assert_eq(w.mx.lz_targets.size(), 5, "up to 5 targets")
	assert_eq(Array(w.mx.lz_targets), [1, 2, 3, 4, 5], "nearest first")
	W.run(w, 118, 0, W.S)
	for k in [1, 2, 3, 4, 5]:
		assert_gt(_total(w, k), 0, "enemy %d is hit by the curve" % k)
	assert_eq(_total(w, 6), 0, "the far one on the other side isn't")
	var plain := _world([&"gun_pierce"], at)
	W.run(plain, 120, 0, W.S)
	var hit := 0
	for k in [2, 3, 4, 5]:
		hit += 1 if _total(plain, k) > 0 else 0
	assert_lte(hit, 1, "a straight Pierce beam misses most of that arc")


func test_l4_homing_picks_again_when_a_target_dies() -> void:
	var w := _world([&"gun_homing"], [Vector2(2.0, 2.0), Vector2(0.0, 6.0)])
	W.run(w, 2, 0, W.S)
	assert_eq(Array(w.mx.lz_targets), [1], "the nearest alone without Pierce")
	w.actors.dead[1] = 1
	W.run(w, 1, 0, W.S)
	assert_eq(Array(w.mx.lz_targets), [2], "it moves on")


# --- L5 Ricochet -----------------------------------------------------------------------------------------------------
func test_l5_ricochet_reflects_once_and_keeps_its_nine_metres() -> void:
	var w := _world([&"gun_ricochet"], [Vector2(-3.0, 0.0)])
	w.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 3.0), 0))
	W.run(w, 2, 0, W.S)
	var main := _kind(_trace(w), &"main")
	assert_eq(main.size(), 2, "one reflection")
	assert_true(bool(main[0]["wall"]))
	assert_lt((main[1]["to"] as Vector2).x, (main[1]["from"] as Vector2).x, "back toward the hero")
	W.run(w, 58, 0, W.S)
	assert_gt(_total(w, 1), 0, "the enemy behind the hero is hit by the return leg")
	var bare := _world([&"gun_ricochet"], [])
	bare.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 3.0), 0))
	W.run(bare, 2, 0, W.S)
	var legs := _kind(_trace(bare), &"main")
	assert_eq(legs.size(), 2)
	assert_almost_eq(_len(legs[0]) + _len(legs[1]), 9.0, 0.1, "the full 9 m reach")
	var w2 := _world([&"gun_ricochet"], [])
	w2.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 3.0), 0))
	w2.add_wall_now(Obb.make(Vector2(-3.0, 0.0), Vector2(0.2, 3.0), 0))
	W.run(w2, 2, 0, W.S)
	assert_eq(_kind(_trace(w2), &"main").size(), 2, "only once: the second wall stops it")


# --- L6 Echo ---------------------------------------------------------------------------------------------------------
func test_l6_echo_strikes_the_swept_path_again_0_4_s_later_at_half() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	W.run(w, 90, 0, W.S)
	var hits := _hits(w, 1)
	var first_main: int = hits[0]["tick"]
	var echoes := hits.filter(func(h: Dictionary) -> bool: return h["amount"] == 2)
	assert_gt(echoes.size(), 0, "echo strikes of 50 % (2 of 4)")
	var delay: int = echoes[0]["tick"] - first_main
	assert_between(delay, 24, 25, "0.4 s later")
	assert_lte(_distinct_dues(w), 8, "at most 8 ticks live")
	assert_eq(_kind(Laser.trace(w, Modifiers.bolt(w), w.player_pos(), 0), &"main").size(), 1)
	assert_gt(WorldReader.new(w).laser_ghosts().size(), 0, "the view has ghosts to draw")


func _distinct_dues(w: World) -> int:
	var seen := {}
	for d in w.mx.lz_echo_due:
		seen[d] = true
	return seen.size()


# --- L7 Big Shot -----------------------------------------------------------------------------------------------------
func test_l7_big_shot_is_twice_as_wide_hits_60_percent_harder_and_turns_slower() -> void:
	var w := _world([&"gun_big_shot"], [Vector2(4.0, 0.0)])
	W.run(w, 2, 0, W.S)
	var b: Dictionary = _trace(w)[0]
	assert_eq(b["wmul"], 2000, "twice as wide")
	W.run(w, 598, 0, W.S)
	var plain := _world([], [Vector2(4.0, 0.0)])
	W.run(plain, 600, 0, W.S)
	assert_eq(_total(plain, 1), 400, "the plain beam: 4 a tick, 100 ticks")
	assert_eq(_total(w, 1), 640, "+60 %: 6.4 a tick")
	# turning: 70 % of follow_dps (720 degrees a second) -> 504
	var t := _world([&"gun_big_shot"], [])
	W.run(t, 1, 0, W.S, 0)
	var start := t.mx.lz_aim
	W.run(t, 10, 0, W.S, AIM_NORTH)
	var turned := Kin.angle_diff(t.mx.lz_aim, start)
	var expect := 0
	for k in 10:
		expect += LaserMods.turn_step(504, t.tick - 10 + k)
	assert_between(turned, expect - 25, expect + 25, "10 ticks at 504 degrees a second")
	W.run(t, 20, 0, W.S, AIM_NORTH)
	assert_eq(t.mx.lz_aim, AIM_NORTH, "it arrives")


# --- L8 Rapid Fire ---------------------------------------------------------------------------------------------------
func test_l8_rapid_fire_quickens_from_0_1_s_to_0_05_s_over_2_s_and_thins() -> void:
	var w := _world([&"gun_rapid_fire"], [Vector2(4.0, 0.0)])
	var s := Modifiers.bolt(w)
	var got := []
	for h in [0, 60, 119, 120, 500]:
		w.mx.lz_hold = h
		got.append(LaserMods.rapid_period(w, s, 6))
	assert_eq(got, [6, 5, 4, 3, 3], "6 ticks down to 3 across 120 ticks of holding")
	w.mx.lz_hold = 0
	assert_eq(LaserMods.width_permille(w, LaserMods.RAPID), 1000)
	w.mx.lz_hold = 120
	assert_eq(LaserMods.width_permille(w, LaserMods.RAPID), 500, "half as wide at the top")
	w.mx.lz_hold = 0
	W.run(w, 260, 0, W.S)
	var late := _hits(w, 1).filter(
		func(h: Dictionary) -> bool: return h["tick"] >= 150 and h["tick"] < 210
	)
	assert_between(late.size(), 19, 21, "20 ticks a second once ramped")
	var early := _hits(w, 1).filter(func(h: Dictionary) -> bool: return h["tick"] < 30)
	assert_lte(early.size(), 5, "10 a second at the start")
	W.run(w, 2, 0, 0)
	assert_eq(w.mx.lz_hold, 0, "the ramp resets when the trigger is let go")


# --- L9 Split --------------------------------------------------------------------------------------------------------
func test_l9_split_forks_in_two_beyond_the_first_enemy() -> void:
	var w := _world([&"split_shot"], [Vector2(4.0, 0.0), Vector2(5.5, 1.0)])
	W.run(w, 2, 0, W.S)
	var forks := _kind(_trace(w), &"split")
	assert_eq(forks.size(), 2)
	for b in forks:
		assert_eq(b["share"], 500, "50 %")
	var angles := [_angle(forks[0]), _angle(forks[1])]
	angles.sort()
	assert_almost_eq(float(angles[0]), 284.0, 3.0, "+25 degrees")
	assert_almost_eq(float(angles[1]), 4096.0 - 284.0, 3.0, "-25 degrees")
	W.run(w, 58, 0, W.S)
	assert_gt(_total(w, 2), 0, "a fork reaches the second enemy")
	for h: Dictionary in _hits(w, 2):
		assert_eq(h["amount"], 2, "50 % of a tick's 4")
	var w2 := _world([&"split_shot"], [Vector2(4.0, 0.0)])
	W.run(w2, 2, 0, W.S)
	for b in _kind(_trace(w2), &"split"):
		assert_almost_eq(_len(b), 4.0, 0.01, "4 m")
	var none := _world([&"split_shot"], [])
	W.run(none, 2, 0, W.S)
	assert_eq(_kind(_trace(none), &"split").size(), 0, "no enemy hit, no fork")


# --- L10 Mine --------------------------------------------------------------------------------------------------------
func test_l10_mine_drops_one_a_second_at_the_tip_and_keeps_at_most_four() -> void:
	var w := _world([&"gun_mine"], [])
	var most := 0
	for k in 420:
		W.run(w, 1, 0, W.S)
		most = maxi(most, w.mx.lz_mine_at.size())
	assert_eq(most, 4, "never more than 4 alive")
	assert_gt(w.mx.lz_mine_at.size(), 0)
	var at: Vector2 = w.mx.lz_mine_at[0]
	assert_gt(at.x, 8.0, "at the beam's tip (9 m)")
	assert_eq(WorldReader.new(w).laser_mines().size(), w.mx.lz_mine_at.size())
	# an enemy stepping on one sets it off: a 1.5 m burst of five ticks (20)
	W.run(w, 2, 0, 0)
	assert_gt(w.mx.lz_mine_at.size(), 0, "mines stay after the trigger is let go")
	var target: Vector2 = w.mx.lz_mine_at[w.mx.lz_mine_at.size() - 1]
	var near := w.add_dummy(target + Vector2(0.9, 0.0), 0.35, HP)
	W.run(w, 2, 0, 0)
	var dealt := _hits_id(w, near)
	assert_gt(dealt.size(), 0, "the burst hit it")
	for h: Dictionary in dealt:
		assert_eq(h["amount"], 20, "100 % of a tick x 5")
	assert_lt(w.mx.lz_mine_at.size(), 4, "the mines that went off are gone")


# --- L11 Spiral ------------------------------------------------------------------------------------------------------
func test_l11_spiral_wiggles_12_degrees_twice_a_second_on_the_sim_clock() -> void:
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
	w.tick = 8
	var b := _trace(w)[0]
	assert_gt(_angle(b), 100, "the drawn beam is turned by the wiggle")


# --- Caps, determinism, snapshots -----------------------------------------------------------------------------------
func test_extra_beams_launch_no_projectiles_and_each_kind_hits_once_a_tick() -> void:
	var w := _world(
		[&"halo_shot", &"gun_ring", &"gun_backfire", &"gun_pierce", &"split_shot"],
		[Vector2(2.0, 0.0), Vector2(3.0, 0.5), Vector2(4.0, -0.5), Vector2(-2.0, 0.0)]
	)
	var s := Modifiers.bolt(w)
	assert_eq(LaserMods.mask(s) & (LaserMods.HALO | LaserMods.RING | LaserMods.BACKFIRE), 7)
	W.run(w, 120, 0, W.S)
	assert_eq(w.projectiles.ids.size(), 0, "a beam is no projectile, forks included")
	assert_gt(_total(w, 1), 0, "the main beam")
	assert_gt(_total(w, 4), 0, "Backfire")
	var per := {}
	for h: Dictionary in _hits(w, 1):
		if h["amount"] == 4:
			per[h["tick"]] = int(per.get(h["tick"], 0)) + 1
	assert_lte(per.values().max(), 1, "the main beam hits an enemy once a tick")
	var most := 0
	for b in _trace(w):
		most += 1
	assert_lte(most, LaserMods.MAX_LEGS * 3, "the path is bounded")


func _all_cards() -> Array:
	return [
		&"gun_homing",
		&"gun_echo",
		&"gun_mine",
		&"gun_pierce",
		&"halo_shot",
		&"gun_backfire",
		&"gun_ring",
	]


func test_a_card_laser_is_deterministic_and_its_state_round_trips_a_snapshot() -> void:
	var at := [Vector2(2.0, 1.0), Vector2(3.5, -1.0), Vector2(-3.0, 2.0), Vector2(5.0, 3.0)]
	var a := _world([&"gun_homing", &"gun_echo", &"gun_mine", &"gun_ring"], at)
	var b := _world([&"gun_homing", &"gun_echo", &"gun_mine", &"gun_ring"], at)
	W.run(a, 150, 0, W.S, 700)
	W.run(b, 150, 0, W.S, 700)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.lz_touched(), "the Laser state is set")
	assert_gt(a.mx.lz_echo_due.size(), 0)
	var snap := WorldSnapshot.take(a)
	var c := _world([&"gun_homing", &"gun_echo", &"gun_mine", &"gun_ring"], at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.lz_echo_due, a.mx.lz_echo_due)
	assert_eq(c.mx.lz_mine_at, a.mx.lz_mine_at)
	assert_eq(c.mx.lz_aim, a.mx.lz_aim)
	W.run(a, 60, 0, W.S, 700)
	W.run(c, 60, 0, W.S, 700)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_without_a_card_the_laser_state_stays_unset() -> void:
	var w := _world([&"gun_pierce"], [Vector2(3.0, 0.0)])
	W.run(w, 120, 0, W.S)
	assert_false(w.mx.lz_touched(), "a plain Laser leaves the new state alone (older digests hold)")
