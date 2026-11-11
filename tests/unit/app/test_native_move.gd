extends GutTest
## The native side (NativeWorld, the ZdWorld class of native/zd_native.gdextension), the only sim: the collision
## passes (NativeMove) part bodies and clear walls by their rules and give the same result from the same start; the
## fixed scene of the collision kernel gives the value recorded with MSVC; the per-kind table the enemy kernels read
## agrees with EnemyAi for every kind, and the native side holds what was sent.

## ZdWorld.determinism_probe() as built by MSVC (Visual Studio 2026, /fp:precise) on the owner's PC.
const DETERMINISM_PROBE := "fc67776bc3d14796"
## The deepest body after the crowd test's 3 ticks with the GDScript passes, the last time they ran (v0.11.1 step
## 54b's comparison): the native passes must leave the crowd no deeper, give or take 0.05 m.
const GDSCRIPT_CROWD_DEPTH_M := -1.0
const K := ActorStore.Kind
const T := preload("res://src/sim/ai/native_kind_table.gd")


func test_bodies_part_half_each() -> void:
	var w := _dummies([Vector2(5, 0), Vector2(5.8, 0)], [])
	w._move_and_collide()
	assert_almost_eq(w.actors.pos_x[1], 4.9, 1e-5)
	assert_almost_eq(w.actors.pos_x[2], 5.9, 1e-5)
	assert_eq(w.actors.pos_y[1], 0.0)
	var same := _dummies([Vector2(5, 3), Vector2(5, 3)], [])
	same._move_and_collide()
	assert_almost_eq(same.actors.pos_x[1], 5.5, 1e-5, "coincident centres part along x")
	assert_almost_eq(same.actors.pos_x[2], 4.5, 1e-5)


## The kernel reads the columns by name and sets new arrays: an array read before the call keeps its old values.
func test_the_columns_come_back_as_new_arrays() -> void:
	var w := _dummies([Vector2(5, 0), Vector2(5.8, 0)], [])
	var before := w.actors.pos_x
	w._move_and_collide()
	assert_almost_eq(w.actors.pos_x[1], 4.9, 1e-5)
	assert_eq(before[1], 5.0, "the array read before the call is untouched")


func test_a_body_in_a_wall_is_pushed_clear() -> void:
	var wall := Obb.make(Vector2(8, 0), Vector2(1, 3), 512)  # turned 45 degrees
	var w := _dummies([Vector2(7.8, 0.3)], [wall])
	w._move_and_collide()
	assert_lt(_depth(w, wall), 1e-4, "the body is clear of the wall")


## A crowd shoved into a wall: the passes end with a pair pass, so crowded bodies may be left a little inside (by
## rule); the native passes leave them no deeper than the GDScript passes did (GDSCRIPT_CROWD_DEPTH_M), give or take.
func test_a_crowd_at_a_wall_ends_no_deeper_than_the_gdscript_passes_did() -> void:
	var wall := Obb.make(Vector2(8, 0), Vector2(1, 3), 512)
	var starts: Array[Vector2] = []
	for k in 12:
		starts.append(Vector2(6.6 + 0.25 * k, -1.5 + 0.25 * k))
	var w := _dummies(starts, [wall])
	for t in 3:
		w._move_and_collide()
	var d := _depth(w, wall)
	gut.p("deepest body in the wall after 3 ticks: %.4f m" % d)
	assert_lt(d, GDSCRIPT_CROWD_DEPTH_M + 0.05, "%.4f m against %.4f m" % [d, GDSCRIPT_CROWD_DEPTH_M])


func test_the_same_start_gives_the_same_result() -> void:
	var a := _crowd_hashes()
	var b := _crowd_hashes()
	assert_eq(a, b, "native: the same hashes tick for tick")


## The extension's fixed scene through the collision kernel gives the hash recorded on Windows (MSVC). Another
## compiler (gcc in CI), or changed float flags, that rounds one operation differently fails here, before any golden.
func test_the_floats_match_the_recorded_compiler() -> void:
	var m: Object = NativeWorld.make()
	assert_eq(m.call(&"determinism_probe"), DETERMINISM_PROBE, "native/README.md: the float rules")


# --- The per-kind table (NativeKindTable) ------------------------------------------------------------------------


func test_the_kind_table_agrees_with_enemy_ai_for_every_kind() -> void:
	var w := CombatLab.world()
	var built := T.build(w)
	var ints: PackedInt32Array = built[0]
	assert_eq(ints.size(), T.kind_count() * T.KI)
	assert_eq((built[1] as PackedFloat32Array).size(), T.kind_count() * T.KF)
	assert_eq(T.kind_count(), 54, "every ActorStore.Kind, PLAYER to GRAVITY_NODE")
	for kind in T.kind_count():
		var r := kind * T.KI
		var name: String = K.keys()[kind]
		assert_eq(ints[r + T.K_BEHAVIOUR], EnemyAi.behaviour_of(kind), name)
		assert_eq(ints[r + T.K_AI_FLAGS], EnemyAi.flags_of(kind), name)
		assert_eq(ints[r + T.K_ROLE], EnemyAi.role_of(kind), name)
		var f := ints[r + T.K_FLAGS]
		assert_eq((f & T.CHARGES) != 0, EnemyAi._charges(kind), name + " charges")
		assert_eq((f & T.KEEPS_AWAY) != 0, EnemyAi._keeps_away(kind), name + " keeps away")
		assert_eq((f & T.TURNS_SLOWLY) != 0, EnemyAi._turns_slowly(kind), name + " turns slowly")
		assert_eq((f & T.TURNS_SLOWLY) != 0, EnemyAi.armoured(kind), name + " armoured")
		assert_eq((f & T.CRITTER) != 0, EnemyAi.is_critter(kind), name + " critter")
		assert_eq((f & T.FACES_ON_PLAN) == 0, (f & T.TURNS_SLOWLY) != 0, name + " faces on plan")


func test_the_kinds_run_in_the_modes_of_the_design() -> void:
	var w := CombatLab.world()
	var native := [
		K.CHARGER,
		K.HATCHLING,
		K.SWARMER,
		K.WARDEN,
		K.NEEDLE,
		K.LENS_DRONE,
		K.SPLITTER,
		K.SPLITLING,
		K.SHIELD_BEARER,
		K.SNIPER,
		K.ARC_CASTER,
		K.BOMB_DRONE,
		K.GRAVITY_NODE,
		K.DUST_MITE,
		K.CAVE_BAT,
		K.EMBER_FLEA,
		K.ICE_CRAB,
		K.STAR_MOTE,
		K.KILN_BEETLE,
		K.GLACIER_TURTLE
	]
	var hooked := [
		K.MENDER,
		K.MINE_LAYER,
		K.RUBBLE_WARDEN,
		K.DIM_NEEDLE,
		K.EMBER_CHARGER,
		K.FROST_CHARGER,
		K.SPLIT_SNIPER,
		K.FROST_SPITTER,
		K.STAR_WARPER
	]
	for kind in T.kind_count():
		var want := T.Mode.SCRIPT
		if kind in native:
			want = T.Mode.NATIVE
		elif kind in hooked:
			want = T.Mode.HOOKED
		if want != T.Mode.SCRIPT:
			assert_not_null(w.enemy_table(kind), "a table for %s" % K.keys()[kind])
		assert_eq(T.mode_of(kind, w.enemy_table(kind)), want, K.keys()[kind])
	assert_eq(T.mode_of(K.CHARGER, null), T.Mode.SCRIPT, "a kind without a table in this world")


func test_the_hooks_and_shapes_follow_enemy_ai() -> void:
	var w := CombatLab.world()
	var hook := func(kind: int) -> int: return T.hooks_of(kind, w.enemy_table(kind))
	var shape := func(kind: int) -> int: return T.shape_of(kind, w.enemy_table(kind))[0]
	assert_eq(hook.call(K.MENDER), T.HOOK_MOVE_TICK)
	assert_eq(hook.call(K.RUBBLE_WARDEN), T.HOOK_THINK_TICK)
	assert_eq(hook.call(K.STAR_WARPER), T.HOOK_WINDUP_START | T.HOOK_WINDUP_END | T.HOOK_ACTIVE)
	assert_eq(hook.call(K.EMBER_CHARGER), T.HOOK_CHARGE_STEP)
	assert_eq(hook.call(K.FROST_CHARGER), T.HOOK_CHARGE_STEP)
	assert_eq(hook.call(K.CHARGER), 0, "no trail")
	assert_eq(hook.call(K.DIM_NEEDLE), T.HOOK_BOLT)
	assert_eq(hook.call(K.MINE_LAYER), T.HOOK_ACTIVE)
	assert_eq(hook.call(K.SPLIT_SNIPER), T.HOOK_ACTIVE)
	assert_eq(shape.call(K.CHARGER), T.Shape.CONTACT)
	assert_eq(shape.call(K.DUST_MITE), T.Shape.CONTACT)
	assert_eq(shape.call(K.WARDEN), T.Shape.LOCKED_DISC)
	assert_eq(shape.call(K.SPLITTER), T.Shape.LOCKED_DISC)
	assert_eq(shape.call(K.NEEDLE), T.Shape.BURST)
	assert_eq(shape.call(K.SHIELD_BEARER), T.Shape.BASH_LANE)
	assert_eq(shape.call(K.SNIPER), T.Shape.SNIPE_LANE)
	for kind in [K.ARC_CASTER, K.BOMB_DRONE, K.LENS_DRONE]:  # EnemyAi.pattern_of comes first in resolve
		assert_eq(shape.call(kind), T.Shape.PATTERN, K.keys()[kind])
	assert_eq(shape.call(K.MENDER), T.Shape.NONE)
	assert_eq(shape.call(K.GRAVITY_NODE), T.Shape.NONE)


func test_the_table_numbers_are_the_enemy_tables() -> void:
	var w := CombatLab.world()
	var built := T.build(w)
	var ints: PackedInt32Array = built[0]
	var floats: PackedFloat32Array = built[1]
	var checked := 0
	for kind in T.kind_count():
		var t := w.enemy_table(kind)
		if t == null:
			continue
		checked += 1
		var r := kind * T.KI
		var f := kind * T.KF
		var name: String = K.keys()[kind]
		assert_eq(ints[r + T.K_COOLDOWN], t.cooldown_ticks, name)
		assert_eq(ints[r + T.K_WINDUP], t.windup_ticks, name)
		assert_eq(ints[r + T.K_WINDUP_MAX], t.windup_max_ticks, name)
		assert_eq(ints[r + T.K_ACTIVE], t.active_ticks, name)
		assert_eq(ints[r + T.K_RECOVER], t.recover_ticks, name)
		assert_eq(ints[r + T.K_TURN_RATE], t.turn_rate, name)
		assert_eq(ints[r + T.K_BURST_COUNT], t.burst_count, name)
		assert_eq(ints[r + T.K_DAMAGE], t.damage, name)
		assert_eq(ints[r + T.K_PATTERNS], t.patterns.size(), name)
		assert_eq(floats[f + T.KF_RADIUS], _f32(t.radius_m), name)
		assert_eq(floats[f + T.KF_SPEED], _f32(t.speed), name)
		assert_eq(floats[f + T.KF_ATTACK_RANGE], _f32(t.attack_range_m), name)
		assert_eq(floats[f + T.KF_CHARGE_SPEED], _f32(t.charge_speed), name)
		assert_eq(floats[f + T.KF_REACH], _f32(t.reach_m), name)
		assert_eq(floats[f + T.KF_SLAM_RADIUS], _f32(t.slam_radius_m), name)
		for k in mini(t.patterns.size(), T.MAX_PATTERNS):
			var p: BulletPatternTable = t.patterns[k]
			var pi := r + T.K_PATTERN + k * T.PATTERN_KI
			assert_eq(ints[pi + T.P_HAS], 0 if p == null else 1, name)
			if p != null:
				assert_eq(ints[pi + T.P_DURATION], p.duration_ticks(), name)
				assert_eq(
					floats[f + T.KF_PATTERN + k * T.PATTERN_KF + T.PF_SPEED], _f32(p.speed), name
				)
	assert_gte(checked, 29, "the compiled tables cover the native and hooked kinds")
	var tun: PackedFloat32Array = built[2]
	assert_eq(tun.size(), T.TUNING)
	assert_eq(tun[T.T_SPAWN_IN], float(w.tuning.spawn_in_ticks))
	assert_eq(tun[T.T_SPREAD_RADIUS], _f32(w.tuning.ai_spread_radius_m))
	assert_eq(tun[T.T_PLAN_PERIOD], float(EnemyAi.PLAN_PERIOD))
	assert_eq(tun[T.T_EGG_STATE], float(BossSignatures.EGG))


## The table goes to the native side before a kernel reads it, and again for a new tuning; the native side
## gives back what it holds, and lists the rows GDScript runs itself.
func test_the_native_side_holds_the_kind_table() -> void:
	var w := CombatLab.world()
	var m: Object = w.native
	NativeWorld.sync_kinds(w)  # sent before the first kernel that reads it
	assert_eq(m.kind_count(), T.kind_count())
	var built := T.build(w)
	var ints: PackedInt32Array = built[0]
	var floats: PackedFloat32Array = built[1]
	for kind in T.kind_count():
		var row: PackedFloat32Array = m.kind_row(kind)
		var want := PackedFloat32Array()
		for k in T.KI:
			want.append(ints[kind * T.KI + k])
		for k in T.KF:
			want.append(floats[kind * T.KF + k])
		assert_eq(row, want, K.keys()[kind])
	var charger := w.add_enemy(K.CHARGER, Vector2(5, 0))
	var elite := w.add_enemy(K.BREAKER, Vector2(-5, 0))
	var dummy := w.add_dummy(Vector2(0, 5), 0.5, 10)
	var mender := w.add_enemy(K.MENDER, Vector2(0, -5))
	var rows: PackedInt32Array = m.rows_for_script(w.actors)
	var want := PackedInt32Array([w.actors.index_of(elite), w.actors.index_of(dummy)])
	assert_eq(rows, want, "the elite and the dummy")
	assert_false(w.actors.index_of(charger) in rows)
	assert_false(w.actors.index_of(mender) in rows, "hooked: the native side runs it")
	w.actors.state[w.actors.index_of(charger)] = BossSignatures.EGG
	assert_true(w.actors.index_of(charger) in m.rows_for_script(w.actors), "an egg is GDScript's")
	# A new tuning (the dev panel, a restore) goes again before a kernel reads the table
	w.tuning = SimTuning.new()
	w.tuning.ai_spread_radius_m = 2.5
	NativeWorld.sync_kinds(w)
	assert_eq(m.kind_row(K.CHARGER).size(), T.KI + T.KF)
	assert_true(is_same(m.get_meta(&"kinds_for"), w.tuning))


func _f32(v: float) -> float:
	return PackedFloat32Array([v])[0]


func _dummies(at: Array, walls: Array) -> World:
	var w := World.new(9, PlayerTable.starting_values())
	assert_not_null(w.native, "every World has its native side")
	var list: Array[Obb] = []
	list.assign(walls)
	w.set_walls(list)
	w.dummy_speed = 0.0
	w.actors.set_pos(0, Vector2(-20, -20))
	for p: Vector2 in at:
		w.add_dummy(p, 0.5, 10)
	return w


## 60 dummies chasing the hero through a ring of walls for 240 ticks; the state hash every 30.
func _crowd_hashes() -> PackedStringArray:
	var walls: Array = []
	for k in 8:
		walls.append(Obb.make(Vector2(k * 3.0 - 10.0, 4.0), Vector2(1.0, 0.4), k * 300))
	var spots: Array = []
	for k in 60:
		spots.append(Vector2((k % 10) * 0.7 - 3.0, (k / 10) * 0.7 + 6.0))
	var w := _dummies(spots, walls)
	w.dummy_speed = 3.0 / SimTick.TICKS_PER_SECOND
	w.actors.set_pos(0, Vector2(0, -2))
	var out := PackedStringArray()
	for t in 240:
		w.step(InputFrame.new())
		if t % 30 == 29:
			out.append(w.state_hash())
	return out


## How far the deepest dummy's circle reaches into the wall (the length of the push that would clear it).
func _depth(w: World, wall: Obb) -> float:
	var deepest := 0.0
	for i in range(1, w.actors.size()):
		deepest = maxf(
			deepest, Collide.circle_vs_obb(w.actors.pos(i), w.actors.radius[i], wall).length()
		)
	return deepest
