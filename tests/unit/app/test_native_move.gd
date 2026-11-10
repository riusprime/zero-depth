extends GutTest
## The native side (NativeWorld, the ZdWorld class of native/zd_native.gdextension): every kernel off by default,
## each switched on by its own name; the collision passes (NativeMove) give the same rules as the GDScript passes
## and the same result from the same start; the per-kind table the enemy kernels read agrees with EnemyAi for every
## kind, and the native side holds what was sent. Without the library (a checkout that hasn't run
## scripts/native/build.sh) the tests that need it are pending.

## ZdWorld.determinism_probe() as built by MSVC (Visual Studio 2026, /fp:precise) on the owner's PC.
const DETERMINISM_PROBE := "fc67776bc3d14796"
const K := ActorStore.Kind
const T := preload("res://src/sim/ai/native_kind_table.gd")

var _kept := Callable()
var _kept_kernels := 0


func before_all() -> void:
	# A run with the native hook keeps its factory and kernels for the files after this one
	_kept = World.native_factory
	_kept_kernels = World.native_kernels


func after_all() -> void:
	World.native_factory = _kept
	World.native_kernels = _kept_kernels


func test_the_native_kernels_are_off_by_default() -> void:
	assert_eq(NativeSwitch.install(0), 0)
	var w := World.new(9, PlayerTable.starting_values())
	assert_null(w.native, "no factory: GDScript")
	assert_eq(w.native_on, 0)


func test_the_switch_takes_each_kernel_by_name() -> void:
	assert_eq(NativeSwitch.parse("move"), NativeWorld.MOVE)
	assert_eq(NativeSwitch.parse("ai,move"), NativeWorld.MOVE | NativeWorld.AI)
	assert_eq(
		NativeSwitch.parse(" strike , shots,nav "),
		NativeWorld.STRIKE | NativeWorld.SHOTS | NativeWorld.NAV
	)
	assert_eq(NativeSwitch.parse("all"), NativeWorld.ALL)
	assert_eq(NativeSwitch.parse("1"), NativeWorld.MOVE, "the older --native=1")
	assert_eq(NativeSwitch.parse("0"), 0)
	assert_eq(NativeSwitch.parse(""), 0)
	assert_eq(NativeSwitch.parse("move,warp"), -1, "an unknown kernel")
	assert_eq(NativeWorld.names_of(NativeWorld.ALL), "move,ai,strike,shots,nav")
	assert_eq(NativeWorld.names_of(NativeWorld.AI | NativeWorld.NAV), "ai,nav")


func test_one_kernel_on_leaves_the_others_off() -> void:
	if not _built():
		return
	assert_eq(NativeSwitch.install(NativeWorld.AI), NativeWorld.AI)
	var w := World.new(9, PlayerTable.starting_values())
	assert_not_null(w.native, "a kernel on: the world has a native side")
	assert_eq(w.native_on, NativeWorld.AI)
	assert_true(w.native.has_trig(), "the direction tables went at the world's start")
	# The move kernel is off: the GDScript passes run, so the result is GDScript's to the bit
	var nat := _dummies([Vector2(5, 0), Vector2(5.8, 0.1)], [], NativeWorld.AI)
	var gd := _dummies([Vector2(5, 0), Vector2(5.8, 0.1)], [], 0)
	nat._move_and_collide()
	gd._move_and_collide()
	assert_eq(nat.actors.pos_x, gd.actors.pos_x)
	assert_eq(nat.actors.pos_y, gd.actors.pos_y)
	assert_eq(NativeSwitch.install(NativeWorld.ALL), NativeWorld.ALL)
	assert_eq(World.new(9, PlayerTable.starting_values()).native_on, NativeWorld.ALL)


func test_bodies_part_half_each() -> void:
	if not _built():
		return
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
	if not _built():
		return
	var w := _dummies([Vector2(5, 0), Vector2(5.8, 0)], [])
	var before := w.actors.pos_x
	w._move_and_collide()
	assert_almost_eq(w.actors.pos_x[1], 4.9, 1e-5)
	assert_eq(before[1], 5.0, "the array read before the call is untouched")


func test_a_body_in_a_wall_is_pushed_clear() -> void:
	if not _built():
		return
	var wall := Obb.make(Vector2(8, 0), Vector2(1, 3), 512)  # turned 45 degrees
	var w := _dummies([Vector2(7.8, 0.3)], [wall])
	w._move_and_collide()
	assert_lt(_depth(w, wall), 1e-4, "the body is clear of the wall")


## A crowd shoved into a wall: the passes end with a pair pass, so crowded bodies may be left a little inside (the
## GDScript passes too, by rule); the native passes leave them no deeper than the GDScript ones, give or take.
func test_a_crowd_at_a_wall_ends_no_deeper_than_with_gdscript() -> void:
	if not _built():
		return
	var wall := Obb.make(Vector2(8, 0), Vector2(1, 3), 512)
	var starts: Array[Vector2] = []
	for k in 12:
		starts.append(Vector2(6.6 + 0.25 * k, -1.5 + 0.25 * k))
	var nat := _dummies(starts, [wall])
	var gd := _dummies(starts, [wall])
	gd.native_on = 0
	for t in 3:
		nat._move_and_collide()
		gd._move_and_collide()
	var dn := _depth(nat, wall)
	var dg := _depth(gd, wall)
	gut.p("deepest body in the wall after 3 ticks: native %.4f m, gdscript %.4f m" % [dn, dg])
	assert_lt(dn, dg + 0.05, "native %.4f m against gdscript %.4f m" % [dn, dg])


func test_the_same_start_gives_the_same_result() -> void:
	if not _built():
		return
	var a := _crowd_hashes()
	var b := _crowd_hashes()
	assert_eq(a, b, "native: the same hashes tick for tick")


## The extension's fixed scene through the collision kernel gives the hash recorded on Windows (MSVC). Another
## compiler (gcc in CI), or changed float flags, that rounds one operation differently fails here, before any golden.
func test_the_floats_match_the_recorded_compiler() -> void:
	if not _built():
		return
	var m: Object = NativeSwitch.make()
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


## The table goes to the native side when a kernel that reads it is on, and again for a new tuning; the native side
## gives back what it holds, and lists the rows GDScript runs itself.
func test_the_native_side_holds_the_kind_table() -> void:
	if not _built():
		return
	NativeSwitch.install(NativeWorld.AI)
	var w := CombatLab.world()
	var m: Object = w.native
	assert_eq(m.kind_count(), T.kind_count(), "sent by set_enemy_tables")
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


## Only the kernels that read the table pay for building it.
func test_the_move_kernel_alone_sends_no_kind_table() -> void:
	if not _built():
		return
	NativeSwitch.install(NativeWorld.MOVE)
	var w := CombatLab.world()
	assert_eq(w.native.kind_count(), 0)
	NativeWorld.sync_kinds(w)
	assert_eq(w.native.kind_count(), T.kind_count())


func _built() -> bool:
	if NativeSwitch.available():
		return true
	# CI sets this when it built the library for the job: a library that then fails to load is a failure there
	if OS.get_environment("ZD_NATIVE_REQUIRED") == "1":
		fail_test("ZD_NATIVE_REQUIRED=1, but the native library did not load")
		return false
	pending("the native library is not built (native/README.md)")
	return false


func _f32(v: float) -> float:
	return PackedFloat32Array([v])[0]


func _dummies(at: Array, walls: Array, kernels := NativeWorld.MOVE) -> World:
	NativeSwitch.install(kernels)
	var w := World.new(9, PlayerTable.starting_values())
	if kernels != 0:
		assert_not_null(w.native, "the factory made a native side")
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
