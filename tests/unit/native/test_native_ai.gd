extends GutTest
## The enemies' thinking and steering run native (NativeAi, ZdWorld.think and ZdWorld.move): the native side reads
## the per-kind table at NativeKindTable's offsets; every kind the table runs goes through the same states at the same
## ticks as with GDScript, with one enemy and nothing else to tell the two apart; each intent reaches its GDScript
## rule; a horde run is the same twice, and a snapshot restored mid-run continues exactly (the native side keeps
## nothing between calls). Without the library the tests are pending.

const K := ActorStore.Kind
const S := EnemyAi.State
const T := preload("res://src/sim/ai/native_kind_table.gd")
const ON := NativeWorld.MOVE | NativeWorld.AI

var _kept := Callable()
var _kept_kernels := 0


func before_all() -> void:
	_kept = World.native_factory
	_kept_kernels = World.native_kernels


func after_all() -> void:
	World.native_factory = _kept
	World.native_kernels = _kept_kernels


func test_the_native_side_reads_the_table_at_its_offsets() -> void:
	if not _built():
		return
	var gd := PackedInt32Array(
		[
			T.Mode.NATIVE,
			T.Mode.HOOKED,
			T.Mode.SCRIPT,
			T.CHARGES,
			T.KEEPS_AWAY,
			T.TURNS_SLOWLY,
			T.CRITTER,
			T.FLEES_THEN_STRAFES,
			T.STATIONARY,
			T.RELOCATES,
			T.TRACKS,
			T.AIM_NO_LEAD,
			T.FACES_ON_PLAN,
			T.AIM_AT_START,
			T.SPELLS,
			T.HOVERS,
			T.NEEDS_MAY,
			T.GUARDS_FRONT,
			T.LOCKS_AHEAD,
			T.LOCKS_FACING,
			T.MELEE_STOP,
			T.HOOK_THINK_TICK,
			T.HOOK_MOVE_TICK,
			T.HOOK_WINDUP_START,
			T.HOOK_WINDUP_END,
			T.HOOK_CHARGE_STEP,
			T.HOOK_BOLT,
			T.HOOK_ACTIVE,
			T.K_MODE,
			T.K_BEHAVIOUR,
			T.K_FLAGS,
			T.K_HOOKS,
			T.K_ROLE,
			T.K_AI_FLAGS,
			T.K_COOLDOWN,
			T.K_WINDUP,
			T.K_WINDUP_MAX,
			T.K_ACTIVE,
			T.K_RECOVER,
			T.K_TURN_RATE,
			T.K_CHARGE_TURN,
			T.K_FRONT_HALF_ARC,
			T.K_LEAD_MAX,
			T.K_BURST_COUNT,
			T.K_BURST_GAP,
			T.K_BURST_SPREAD,
			T.K_SHAPE,
			T.K_DAMAGE,
			T.K_TAGS,
			T.K_CONTACT_CD,
			T.K_MAX_MINES,
			T.K_RUNE_WINDUP,
			T.K_BOLT_LIFE,
			T.K_HEAL_AMOUNT,
			T.K_HEAL_PERIOD,
			T.K_TRAIL_STEP,
			T.K_PATTERNS,
			T.K_PATTERN,
			T.PATTERN_KI,
			T.P_HAS,
			T.P_LOB,
			T.P_GAP,
			T.P_WAVES,
			T.P_DURATION,
			T.P_BURST,
			T.MAX_PATTERNS,
			T.KI,
			T.KF_RADIUS,
			T.KF_SPEED,
			T.KF_ATTACK_RANGE,
			T.KF_FLEE,
			T.KF_KEEP_DISTANCE,
			T.KF_KEEP_MIN,
			T.KF_CHARGE_SPEED,
			T.KF_CHARGE_DISTANCE,
			T.KF_REACH,
			T.KF_SLAM_RADIUS,
			T.KF_LANE_HALF,
			T.KF_RUNE_RADIUS,
			T.KF_BOLT_SPEED,
			T.KF_BOLT_RADIUS,
			T.KF_SPREAD_SPEED,
			T.KF_HEAL_RANGE,
			T.KF_STRIKE_RADIUS,
			T.KF_PATTERN,
			T.PATTERN_KF,
			T.PF_SPEED,
			T.PF_RADIUS,
			T.PF_LAND,
			T.KF,
			T.T_SPAWN_IN,
			T.T_COMMIT,
			T.T_SNIPE_COMMIT,
			T.T_STRAFE_PERMILLE,
			T.T_FLANK_MIN,
			T.T_FLANK_RANGE,
			T.T_FLANK_PERMILLE,
			T.T_SPREAD_RADIUS,
			T.T_SPREAD_WEIGHT,
			T.T_RELOCATE_SPEED_PERMILLE,
			T.T_RELOCATE_MAX,
			T.T_MEND_SCAN,
			T.T_PLAN_PERIOD,
			T.T_EGG_STATE,
			T.T_CONTACT_SLOP,
			T.T_CRITTER_TOUCH,
			T.T_RELOCATE_DONE,
			T.T_SIGHT_R,
			T.TUNING
		]
	)
	var native: PackedInt32Array = NativeSwitch.make().kind_layout()
	assert_eq(native.size(), gd.size(), "as many constants on both sides")
	for k in mini(native.size(), gd.size()):
		assert_eq(native[k], gd[k], "constant %d of the layout (zd_kinds.h LAYOUT order)" % k)
	var codes: PackedInt32Array = NativeSwitch.make().ai_hero_layout()
	var want := PackedInt32Array([NativeAi.HERO_SIZE])
	for c in NativeAi.Intent.values():
		want.append(c)
	assert_eq(codes, want, "the hero's size and the intent codes are NativeAi's")
	assert_eq(NativeAi.hero_of(CombatLab.world()).size(), NativeAi.HERO_SIZE)


## One enemy of each table kind (NATIVE or HOOKED) by a standing hero: its state and the tick it enters it, its
## windup's length, for 600 ticks, are the same native as with GDScript.
func test_every_table_kind_runs_the_gdscript_state_cycle() -> void:
	if not _built():
		return
	var probe := CombatLab.world()
	var kinds := PackedInt32Array()
	for kind in T.kind_count():
		var t := probe.enemy_table(kind)
		if t != null and T.mode_of(kind, t) != T.Mode.SCRIPT:
			kinds.append(kind)
	assert_gt(kinds.size(), 25, "the table kinds of the design (NATIVE_CORE.md §4.1)")
	var attacked := 0
	for kind in kinds:
		var gd := _cycle(kind, 0)
		var nat := _cycle(kind, ON)
		assert_eq(nat, gd, "kind %s: the same states, ticks and windups" % K.keys()[kind])
		attacked += 1 if ",".join(gd).contains(":%d:" % S.WINDUP) else 0
	assert_gt(attacked, 20, "most kinds attacked in the window (the cycle is exercised)")


## [tick:state:windup] each time the enemy's state changes.
func _cycle(kind: int, kernels: int) -> PackedStringArray:
	NativeSwitch.install(kernels)
	var w := CombatLab.world()
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	var t := w.enemy_table(kind)
	var d := clampf(t.attack_range_m * 0.7, 1.2, 6.0)
	var id := w.add_enemy(kind, Vector2(d, 0.4))
	var out := PackedStringArray()
	var last := -1
	for tick in 600:
		w.step(InputFrame.new())
		var i := w.actors.index_of(id)
		if i < 0:
			out.append("%d:gone" % tick)
			break
		if w.actors.state[i] != last:
			last = w.actors.state[i]
			out.append("%d:%d:%d" % [tick, last, w.actors.windup[i]])
	return out


func test_a_mender_heals_a_hurt_ally() -> void:
	if not _built():
		return
	var w := _world_on()
	var hurt := w.add_enemy(K.CHARGER, Vector2(9, 0))
	var mender := w.add_enemy(K.MENDER, Vector2(9.8, 0.4))
	var j := w.actors.index_of(hurt)
	w.actors.hp[j] = 1
	var healed := CombatLab.until(
		w, func(x: World) -> bool: return x.actors.hp[x.actors.index_of(hurt)] > 1, 900
	)
	assert_gt(healed, 0, "healed (MOVE_TICK: EnemyAi._mend)")
	assert_eq(w.actors.pick[w.actors.index_of(mender)], hurt, "its patient")


func test_a_rubble_warden_sheds_its_crust_at_half_hp() -> void:
	if not _built():
		return
	var w := _world_on()
	var id := w.add_enemy(K.RUBBLE_WARDEN, Vector2(8, 0))
	CombatLab.idle(w, 2)
	assert_false(w.variants.crusted.has(id))
	var i := w.actors.index_of(id)
	w.actors.hp[i] = w.actors.max_hp[i] / 2
	CombatLab.idle(w, 1)
	assert_true(w.variants.crusted.has(id), "THINK_TICK: Variants.on_think")


func test_an_ember_charger_leaves_its_trail() -> void:
	if not _built():
		return
	var w := _world_on()
	w.add_enemy(K.EMBER_CHARGER, Vector2(4, 0))
	var n := CombatLab.until(w, func(x: World) -> bool: return x.variants.trail_count() > 0, 900)
	assert_gt(n, 0, "CHARGE_STEP: Variants.on_charge_step")


func test_a_sniper_relocates_after_its_shot() -> void:
	if not _built():
		return
	var w := _world_on()
	var id := w.add_enemy(K.SNIPER, Vector2(9, 0))
	var n := CombatLab.until(
		w, func(x: World) -> bool: return x.actors.pick[x.actors.index_of(id)] == 1, 1200
	)
	assert_gt(n, 0, "RELOCATE: EnemyAi._plan_relocation")
	var i := w.actors.index_of(id)
	var spot := Vector2(w.actors.lock_x[i], w.actors.lock_y[i])
	var from := Kin.length(spot - w.actors.pos(i))
	CombatLab.idle(w, 30)
	i = w.actors.index_of(id)
	assert_lt(Kin.length(spot - w.actors.pos(i)), from, "it walks to its spot (RELOCATE_STEP)")


func test_a_wall_between_sends_the_walk_along_the_flow_field() -> void:
	if not _built():
		return
	NativeSwitch.install(ON)
	var w := CombatLab.world()
	var walls: Array[Obb] = [
		Obb.make(Vector2(5, 0), Vector2(0.4, 3.0), 0),
		Obb.make(Vector2(0, 12.5), Vector2(13, 0.5), 0),
		Obb.make(Vector2(0, -12.5), Vector2(13, 0.5), 0),
		Obb.make(Vector2(12.5, 0), Vector2(0.5, 13), 0),
		Obb.make(Vector2(-12.5, 0), Vector2(0.5, 13), 0),
	]
	w.set_walls(walls)
	var id := w.add_enemy(K.CHARGER, Vector2(9, 0))
	w.flood_nav()
	var period := EnemyAi.PLAN_PERIOD
	while posmod(w.tick, period) != posmod(id, period):
		w.step(InputFrame.new())
	var i := w.actors.index_of(id)
	var at := w.actors.pos(i)  # where it plans from (nothing moves before phase 3)
	var flow := w.nav.direction(at)
	assert_ne(flow, Vector2.ZERO, "the flow field reaches it")
	w.step(InputFrame.new())  # its plan tick
	i = w.actors.index_of(id)
	assert_eq(w.actors.plan_block[i], 1, "the wall blocks the line to the hero")
	var plan := Vector2(w.actors.plan_x[i], w.actors.plan_y[i])
	assert_almost_eq(plan.x, flow.x, 0.002, "FLOW: the flow field's way")
	assert_almost_eq(plan.y, flow.y, 0.002)


## A horde of the table kinds: two runs give one hash chain; a snapshot at tick 300 restored into a fresh world gives
## the continuous run's hash at 600.
func test_a_horde_is_the_same_twice_and_resumes_exactly() -> void:
	if not _built():
		return
	var a := _horde_hashes(ON, -1)
	var b := _horde_hashes(ON, -1)
	assert_eq(a.size(), 6)
	assert_eq(a, b, "the same seed twice")
	var c := _horde_hashes(ON, 300)
	assert_eq(c, a, "restored at 300: the same hashes on to 600")
	var off := _horde_hashes(0, -1)
	assert_ne(off[off.size() - 1], a[a.size() - 1], "native on hashes its own way (L16)")


func _horde_hashes(kernels: int, restore_at: int) -> PackedStringArray:
	NativeSwitch.install(kernels)
	var kinds := [
		K.CHARGER,
		K.SWARMER,
		K.NEEDLE,
		K.WARDEN,
		K.SPLITTER,
		K.SHIELD_BEARER,
		K.SNIPER,
		K.ARC_CASTER,
		K.BOMB_DRONE,
		K.MENDER,
		K.MINE_LAYER,
		K.DUST_MITE,
	]
	var w := SaveLab.floor_world(31, 3)
	w.spawner = null
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	var p := w.player_pos()
	for k in 60:
		var kind: int = kinds[k % kinds.size()]
		if w.enemy_table(kind) != null:
			w.add_enemy(kind, p + Kin.dir((k * 4096 / 60) & 4095) * (5.0 + float(k % 4)))
	var bot := FightBot.new(5)
	var out := PackedStringArray()
	for t in 600:
		if t == restore_at:
			var base := SaveLab.floor_world(31, 3)
			base.spawner = null
			var snap := WorldSnapshot.take(w)
			var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
			assert_not_null(restored, "the snapshot fits its base")
			if restored == null:
				return out
			assert_eq(restored.state_hash(), w.state_hash(), "restored hash at %d" % t)
			w = restored
		w.step(SaveLab.frame(w, bot))
		if t % 100 == 99:
			out.append(w.state_hash())
	return out


func _world_on() -> World:
	NativeSwitch.install(ON)
	var w := CombatLab.world()
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	assert_eq(w.native_on, ON)
	return w


func _built() -> bool:
	if NativeSwitch.available():
		return true
	if OS.get_environment("ZD_NATIVE_REQUIRED") == "1":
		fail_test("ZD_NATIVE_REQUIRED=1, but the native library did not load")
		return false
	pending("the native library is not built (native/README.md)")
	return false
