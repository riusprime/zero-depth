extends GutTest
## v0.11.0 O13a (ENEMIES.md V1-V5; owner Q23): the five biome variants. Each runs its base's behaviour with its own
## twist (Variants): the Rubble Warden's crust falls at half HP and leaves a slowing patch; the Dim Needle's
## shots are dark
## beyond 4 m and lit within; the Ember Charger's fire trail burns (only once shown for the telegraph minimum) and goes
## after 2 s; on the Frost Charger's slick the hero slides and enemies don't; the Split Sniper's shot splits into 3 at
## half range, and the telegraph is the very lanes the hit uses.

const KIND := ActorStore.Kind
const LONG := 1 << 24

var _tables: Array[EnemyTable] = []


func before_all() -> void:
	_tables = CombatLab.tables()


## A wall-less world, the hero at the origin (invulnerable unless `hurt`).
func _world(hurt := false) -> World:
	var w := World.new(11, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	if not hurt:
		w.actors.invuln[0] = LONG
	return w


func _enemy(w: World, kind: int, at: Vector2) -> int:
	w.add_enemy(kind, at)
	var i := w.actors.size() - 1
	w.actors.invuln[i] = 0
	return i


func _steps(w: World, n: int, f: InputFrame = InputFrame.new()) -> void:
	for _k in n:
		w.step(f)


# --- V1 Rubble Warden -------------------------------------------------------------------------------------------
func test_the_rubble_wardens_crust_falls_at_half_hp_as_one_patch() -> void:
	var w := _world()
	var i := _enemy(w, KIND.RUBBLE_WARDEN, Vector2(6, 0))
	var t := w.enemy_table(KIND.RUBBLE_WARDEN)
	assert_eq(t.hp, 130, "the Warden's 100 plus a 30 HP crust")
	assert_eq(w.actors.max_hp[i], 130)
	var walls := w.walls.size()
	w.actors.hp[i] = 66  # just over half
	_steps(w, 2)
	assert_true(Variants.crust_on(w, i), "over half HP: the crust holds")
	assert_eq(w.variants.trail_count(), 0)
	w.actors.hp[i] = 65
	_steps(w, 1)
	assert_false(Variants.crust_on(w, i), "at half: the crust is off")
	assert_eq(w.variants.trail_count(), 1, "it falls as one patch")
	assert_eq(w.variants.trail_kind[0], Variants.TRAIL_RUBBLE)
	assert_eq(w.walls.size(), walls, "never solid: no barrier added")
	assert_almost_eq(w.variants.trail_r[0], 1.6, 0.001, "1.6 m")
	assert_eq(w.variants.trail_until[0] - w.variants.trail_born[0], 300, "5 s")
	assert_eq(w.variants.trail_value[0], 600, "the hero at 0.6 of its speed")
	assert_lt(w.variants.trail_pos(0).distance_to(w.actors.pos(i)), 0.5, "where the Warden stands")
	w.actors.hp[i] = 10
	_steps(w, 2)
	assert_eq(w.variants.trail_count(), 1, "it falls once")


func test_the_rubble_patch_expires_at_5_s() -> void:
	var w := _world()
	var i := _enemy(w, KIND.RUBBLE_WARDEN, Vector2(6, 0))
	w.actors.hp[i] = 40
	_steps(w, 1)
	assert_eq(w.variants.trail_count(), 1)
	var until := w.variants.trail_until[0]
	while w.tick < until - 1:
		w.step(InputFrame.new())
	assert_eq(w.variants.trail_count(), 1, "still there a tick before")
	_steps(w, 2)
	assert_eq(w.variants.trail_count(), 0, "gone at 5 s")


func test_the_rubble_patch_blocks_nothing_for_enemies() -> void:
	var runs := []
	for patch in [false, true]:
		var w := _world()
		var walls := w.walls.size()
		if patch:
			w.variants.add_trail(Variants.TRAIL_RUBBLE, Vector2(4, 0), 3.0, 0, 100000, 0, 600, 0, 0)
		var i := _enemy(w, KIND.WARDEN, Vector2(8, 0))
		_steps(w, 90)
		runs.append(w.actors.pos(i))
		assert_eq(w.walls.size(), walls, "no barrier")
	assert_eq(runs[0], runs[1], "an enemy walks through the patch as if it weren't there")


func test_the_rubble_patch_slows_the_hero_only_inside_it() -> void:
	var run := InputFrame.make(Vector2i(SimTick.MOVE_MAX, 0), 0, 0, 0, 0)
	var speeds := []
	for r in [30.0, 1.6]:  # a wide patch round the whole run / a small one the hero never stands in
		var w := _world()
		w.variants.add_trail(
			Variants.TRAIL_RUBBLE,
			Vector2(0, 20) if r < 2.0 else Vector2.ZERO,
			r,
			0,
			99999,
			0,
			600,
			0,
			0
		)
		_steps(w, 60, run)
		speeds.append(w.vel.x)
	assert_gt(speeds[1], 0.0)
	assert_almost_eq(speeds[0] / speeds[1], 0.6, 0.01, "x0.6 inside, full speed outside")


func test_the_crust_round_trips_a_snapshot() -> void:
	var w := _world()
	var i := _enemy(w, KIND.RUBBLE_WARDEN, Vector2(6, 0))
	w.actors.hp[i] = 40
	_steps(w, 2)
	var snap := WorldSnapshot.take(w)
	var copy := _world()
	assert_eq(WorldSnapshot.apply(copy, snap), "")
	assert_eq(copy.variants.trail_count(), w.variants.trail_count())
	assert_eq(copy.walls.size(), w.walls.size())
	assert_eq(copy.state_hash(), w.state_hash(), "the same world")
	_steps(w, 30)
	_steps(copy, 30)
	assert_eq(copy.state_hash(), w.state_hash(), "and the same after")


# --- V2 Dim Needle ----------------------------------------------------------------------------------------------
func test_the_dim_needles_shots_are_dark_beyond_4_m_and_lit_within() -> void:
	var w := _world()
	_enemy(w, KIND.DIM_NEEDLE, Vector2(9, 0))
	var k := -1
	for _t in 600:
		w.step(InputFrame.new())
		for j in w.projectiles.size():
			if w.projectiles.team[j] == ActorStore.TEAM_ENEMY:
				k = j
		if k >= 0:
			break
	assert_gt(k, -1, "it fires")
	assert_eq(w.projectiles.look_of(k), String(Variants.DIM_LOOK), "its shot is marked dim")
	assert_true(WorldReader.new(w).projectile_dark(k), "far from the hero: dark")
	for d in [6.0, 4.5, 4.01]:
		w.projectiles.pos_x[k] = d
		w.projectiles.pos_y[k] = 0.0
		assert_true(Variants.shot_dark(w, k), "%.2f m: dark" % d)
	for d in [4.0, 3.0, 1.0, 0.0]:
		w.projectiles.pos_x[k] = d
		w.projectiles.pos_y[k] = 0.0
		assert_false(Variants.shot_dark(w, k), "%.2f m: lit (never hidden inside 4 m)" % d)


func test_a_plain_needles_shots_are_never_dark() -> void:
	var w := _world()
	_enemy(w, KIND.NEEDLE, Vector2(9, 0))
	var seen := 0
	for _t in 600:
		w.step(InputFrame.new())
		for j in w.projectiles.size():
			seen += 1
			assert_false(Variants.shot_dark(w, j))
		if seen > 0:
			break
	assert_gt(seen, 0)


# --- V3 Ember Charger -------------------------------------------------------------------------------------------
## Steps until charger i is charging, then through its charge; returns the trails it left.
func _charge(w: World, i: int) -> void:
	for _t in 600:
		w.step(InputFrame.new())
		if w.actors.state[i] == EnemyAi.State.RECOVER:
			return


func test_the_ember_chargers_charge_leaves_a_fire_trail_that_burns() -> void:
	var w := _world()
	var i := _enemy(w, KIND.EMBER_CHARGER, Vector2(5.5, 0))
	var t := w.enemy_table(KIND.EMBER_CHARGER)
	_charge(w, i)
	var v := w.variants
	assert_gt(v.trail_count(), 2, "a trail of patches along the charge")
	for k in v.trail_count():
		assert_eq(v.trail_kind[k], Variants.TRAIL_FIRE)
		assert_eq(v.trail_until[k] - v.trail_born[k], 120, "2 s")
	# The charger dies; the hero steps into its trail and burns.
	Damage.hit(w, i, 99999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))
	var at := v.trail_pos(0)
	w.actors.set_pos(0, at)
	w.actors.invuln[0] = 0
	var hp := w.actors.hp[0]
	assert_eq(_burns(w, at, 20), 1, "standing in the fire burns, once a period")
	assert_lt(w.actors.hp[0], hp)
	assert_eq(t.burn_period_ticks, 30)
	_steps(w, 130)
	assert_eq(v.trail_count(), 0, "the fire goes after 2 s")


## Steps n ticks with the hero held at `at`; how many fire burns it took.
func _burns(w: World, at: Vector2, n: int) -> int:
	var out := 0
	for _t in n:
		var seq := w.last_event_seq()
		w.step(InputFrame.new())
		w.actors.set_pos(0, at)
		w.vel = Vector2.ZERO
		for e in w.events_since(seq):
			if e.kind == SimEvent.Kind.DAMAGE and e.effect_id == Variants.FIRE_EFFECT:
				out += 1
	return out


func test_a_fresh_patch_burns_only_once_shown_for_the_telegraph_minimum() -> void:
	var w := _world(true)
	var t := w.enemy_table(KIND.EMBER_CHARGER)
	w.variants.add_trail(
		Variants.TRAIL_FIRE,
		Vector2.ZERO,
		0.6,
		w.tick,
		w.tick + t.trail_ticks,
		t.trail_arm_ticks,
		5,
		30,
		999
	)
	assert_gte(t.trail_arm_ticks, SimTick.MIN_TELEGRAPH_TICKS)
	assert_eq(_burns(w, Vector2.ZERO, t.trail_arm_ticks - 1), 0, "not while it is fresh")
	assert_eq(_burns(w, Vector2.ZERO, 3), 1, "then it burns")
	assert_eq(_burns(w, Vector2(3, 0), 40), 0, "off the patch: no burn")


func test_a_death_by_the_fire_names_it() -> void:
	var w := _world(true)
	w.variants.add_trail(Variants.TRAIL_FIRE, Vector2.ZERO, 0.6, 0, 120, 24, 50, 30, 999)
	w.actors.hp[0] = 1
	_steps(w, 30)
	assert_true(w.player_dead())
	assert_eq(w.killer_attack, Variants.KILL_CAUSE)
	assert_eq(BossCauses.key(w), Variants.CAUSE_KEY)
	assert_ne(tr(Variants.CAUSE_KEY), String(Variants.CAUSE_KEY), "its recap line exists")


# --- V4 Frost Charger -------------------------------------------------------------------------------------------
func test_the_frost_chargers_charge_leaves_a_slick() -> void:
	var w := _world()
	var i := _enemy(w, KIND.FROST_CHARGER, Vector2(5.5, 0))
	_charge(w, i)
	assert_gt(w.variants.trail_count(), 2)
	for k in w.variants.trail_count():
		assert_eq(w.variants.trail_kind[k], Variants.TRAIL_SLICK)
		assert_eq(w.variants.trail_until[k] - w.variants.trail_born[k], 360, "6 s")
	assert_eq(w.actors.hp[0], w.player.hp, "a slick never hurts")


## The hero runs right at full speed for 40 ticks, then pushes left for `n`: its x velocity then.
func _turn_velocity(slick: bool, n: int) -> float:
	var w := _world()
	if slick:
		var p := w.enemy_table(KIND.FROST_CHARGER).slick_permille
		w.variants.add_trail(Variants.TRAIL_SLICK, Vector2(1, 0), 30.0, 0, 100000, 0, p, 0, 0)
	_steps(w, 40, InputFrame.make(Vector2i(SimTick.MOVE_MAX, 0), 0, 0, 0, 0))
	_steps(w, n, InputFrame.make(Vector2i(-SimTick.MOVE_MAX, 0), 0, 0, 0, 0))
	return w.vel.x


func test_on_a_slick_the_hero_slides_and_turns_slowly() -> void:
	var dry := _turn_velocity(false, 10)
	var slick := _turn_velocity(true, 10)
	assert_lt(dry, 0.0, "on dry ground the hero has turned round in 10 ticks")
	assert_gt(slick, 0.0, "on the slick it still slides the old way")
	var w := _world()
	var p := w.enemy_table(KIND.FROST_CHARGER).slick_permille
	w.variants.add_trail(Variants.TRAIL_SLICK, Vector2.ZERO, 30.0, 0, 100000, 0, p, 0, 0)
	_steps(w, 40, InputFrame.make(Vector2i(SimTick.MOVE_MAX, 0), 0, 0, 0, 0))
	var top := w.vel.x
	_steps(w, 20)
	assert_gt(w.vel.x, top * 0.4, "letting go, it keeps much of its speed")


func test_enemies_walk_a_slick_as_ground() -> void:
	var runs := []
	for slick in [false, true]:
		var w := _world()
		if slick:
			w.variants.add_trail(Variants.TRAIL_SLICK, Vector2(4, 0), 30.0, 0, 100000, 0, 40, 0, 0)
		var i := _enemy(w, KIND.WARDEN, Vector2(8, 0))
		_steps(w, 90)
		runs.append(w.actors.pos(i))
	assert_eq(runs[0], runs[1], "the same walk on and off the slick")


# --- V5 Split Sniper --------------------------------------------------------------------------------------------
func _aimed_sniper(w: World, aim: int) -> int:
	var i := _enemy(w, KIND.SPLIT_SNIPER, Vector2.ZERO)
	w.actors.set_pos(0, Vector2(0, 30))  # the hero off the lanes while they are built
	w.actors.lock_x[i] = 0.0
	w.actors.lock_y[i] = 0.0
	w.actors.lock_a[i] = aim
	return i


func test_the_split_snipers_shot_splits_into_3_at_half_range() -> void:
	var w := _world()
	var i := _aimed_sniper(w, 0)
	var t := w.enemy_table(KIND.SPLIT_SNIPER)
	var lanes := Variants.split_lanes(w, i)
	assert_eq(lanes.size(), 4, "the line to the split, then three")
	var half := t.reach_m * 0.5
	assert_almost_eq(lanes[0].half.x * 2.0, half, 0.01, "the first line runs to half range")
	var mid := lanes[0].center + Kin.dir(lanes[0].angle) * lanes[0].half.x
	assert_almost_eq(mid.x, w.actors.radius[i] + half, 0.01)
	var angles := []
	for k in range(1, 4):
		var start: Vector2 = lanes[k].center - Kin.dir(lanes[k].angle) * lanes[k].half.x
		assert_almost_eq(start.distance_to(mid), 0.0, 0.01, "branch %d starts at the split" % k)
		assert_almost_eq(lanes[k].half.x * 2.0, t.reach_m - half, 0.01, "to the full reach")
		angles.append(lanes[k].angle)
	assert_eq(
		angles, [(4096 - t.split_turn) & 4095, 0, t.split_turn], "straight on and either side"
	)
	w.actors.state[i] = EnemyAi.State.WINDUP
	w.actors.windup[i] = 60
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg["shape"], &"lanes")
	assert_eq(tg["obbs"].size(), 4, "the forecast is the very lanes the hit uses (EI-07)")


func test_an_outer_branch_hits_where_the_straight_line_misses() -> void:
	var w := _world(true)
	var i := _aimed_sniper(w, 0)
	var t := w.enemy_table(KIND.SPLIT_SNIPER)
	var lanes := Variants.split_lanes(w, i)
	var far: Obb = lanes[3]
	var target := far.center + Kin.dir(far.angle) * (far.half.x * 0.6)  # well past the split, on the outer branch
	assert_gt(absf(target.y), 0.5, "off the straight line")
	w.actors.set_pos(0, target)
	w.actors.state[i] = EnemyAi.State.ACTIVE
	w.actors.state_t[i] = 0
	var hp := w.actors.hp[0]
	EnemyAi.resolve(w, i)
	assert_eq(w.actors.hp[0], hp - t.damage, "one hit")
	# a plain Sniper's line misses the same spot
	var v := _world(true)
	var j := _enemy(v, KIND.SNIPER, Vector2.ZERO)
	v.actors.lock_x[j] = 0.0
	v.actors.lock_y[j] = 0.0
	v.actors.lock_a[j] = 0
	v.actors.set_pos(0, target)
	v.actors.state[j] = EnemyAi.State.ACTIVE
	v.actors.state_t[j] = 0
	var hp2 := v.actors.hp[0]
	EnemyAi.resolve(v, j)
	assert_eq(v.actors.hp[0], hp2, "the plain Sniper's line misses there")


func test_a_wall_before_the_split_stops_it() -> void:
	var w := _world()
	var walls: Array[Obb] = [Obb.make(Vector2(5, 0), Vector2(0.5, 3), 0)]
	w.set_walls(walls)
	var i := _aimed_sniper(w, 0)
	assert_eq(Variants.split_lanes(w, i).size(), 1, "cut short before half range: no split")
