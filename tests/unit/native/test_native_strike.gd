extends GutTest
## The enemies' strikes run native (NativeStrike, ZdWorld.strike): the list codes and the shapes are the GDScript ones;
## every kind the table runs lands the same hits on the same ticks for the same damage, and fires the same shots, as
## with GDScript, by a hero standing in its reach; a wall raised after the windup began stops the hit on both sides;
## a horde run is the same twice, and a snapshot restored mid-run continues exactly (the native side keeps nothing
## between calls). Without the library the tests are pending.

const K := ActorStore.Kind
const S := EnemyAi.State
const T := preload("res://src/sim/ai/native_kind_table.gd")
const BASE := NativeWorld.MOVE | NativeWorld.AI
const ON := BASE | NativeWorld.STRIKE

var _kept := Callable()
var _kept_kernels := 0


func before_all() -> void:
	_kept = World.native_factory
	_kept_kernels = World.native_kernels


func after_all() -> void:
	World.native_factory = _kept
	World.native_kernels = _kept_kernels


func test_the_codes_and_shapes_are_the_gdscript_ones() -> void:
	if not _built():
		return
	var want := PackedInt32Array()
	for c in NativeStrike.Out.values():
		want.append(c)
	for c in T.Shape.values():
		want.append(c)
	assert_eq(NativeSwitch.make().strike_layout(), want, "zd_strike.h StrikeOut, then StrikeShape")


## One enemy of each table kind by a hero standing in its reach, 600 ticks: the hero's damage taken each tick and the
## shots fired each tick are the same with the strike native as with it in GDScript (think and move native on both).
func test_every_table_kind_lands_the_same_hits_and_shots() -> void:
	if not _built():
		return
	var probe := CombatLab.world()
	var kinds := PackedInt32Array()
	for kind in T.kind_count():
		var t := probe.enemy_table(kind)
		if t != null and T.mode_of(kind, t) != T.Mode.SCRIPT:
			kinds.append(kind)
	assert_gt(kinds.size(), 25, "the table kinds of the design (NATIVE_CORE.md §4.1)")
	var struck := 0
	var shot := 0
	for kind in kinds:
		var gd := _trace(kind, BASE)
		var nat := _trace(kind, ON)
		assert_eq(nat, gd, "kind %s: the same hits and shots on the same ticks" % K.keys()[kind])
		var joined := ",".join(gd)
		struck += 1 if joined.contains("hit") else 0
		shot += 1 if joined.contains("shot") else 0
	gut.p("%d table kinds: %d hurt the hero, %d fired shots" % [kinds.size(), struck, shot])
	assert_gt(struck, 15, "most kinds hurt the hero in the window (the shapes are exercised)")
	assert_gt(shot, 3, "the shooters fired (the bolts and the waves are exercised)")


## tick:hit:<damage> and tick:shot:<count> each tick the hero lost hp or an enemy projectile appeared.
func _trace(kind: int, kernels: int) -> PackedStringArray:
	NativeSwitch.install(kernels)
	var w := CombatLab.world()
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	var t := w.enemy_table(kind)
	var d := clampf(t.attack_range_m * 0.7, 1.2, 6.0)
	w.add_enemy(kind, Vector2(d, 0.4))
	var out := PackedStringArray()
	var seen := {}
	var hp := w.actors.hp[0]
	for tick in 600:
		w.step(InputFrame.new())
		if w.actors.hp[0] != hp:
			out.append("%d:hit:%d" % [tick, hp - w.actors.hp[0]])
			hp = w.actors.hp[0]
		var fresh := 0
		var p := w.projectiles
		for k in p.ids.size():
			if p.team[k] == ActorStore.TEAM_ENEMY and not seen.has(p.ids[k]):
				seen[p.ids[k]] = true
				fresh += 1
		if fresh > 0:
			out.append("%d:shot:%d" % [tick, fresh])
	return out


## A wall raised between a winding-up Warden and the hero stops its slam (EnemyAi._hit_player's sight test), native
## as in GDScript.
func test_a_wall_raised_during_the_windup_stops_the_hit() -> void:
	if not _built():
		return
	for kernels in [BASE, ON]:
		NativeSwitch.install(kernels)
		var w := CombatLab.world()
		w.actors.hp[0] = 1000000
		w.actors.max_hp[0] = 1000000
		var id := w.add_enemy(K.WARDEN, Vector2(1.6, 0))
		var n := CombatLab.until(
			w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(id)] == S.WINDUP, 900
		)
		assert_gt(n, 0, "it winds up")
		var walls: Array[Obb] = [Obb.make(Vector2(0.8, 0), Vector2(0.05, 3.0), 0)]
		w.set_walls(walls)
		var hp := w.actors.hp[0]
		CombatLab.until(
			w,
			func(x: World) -> bool: return x.actors.state[x.actors.index_of(id)] == S.RECOVER,
			300
		)
		assert_eq(w.actors.hp[0], hp, "kernels %d: the wall stops the slam" % kernels)


## A horde of the table kinds: two runs give one hash chain; a snapshot at tick 300 restored into a fresh world gives
## the continuous run's hashes on to 600.
func test_a_horde_is_the_same_twice_and_resumes_exactly() -> void:
	if not _built():
		return
	var a := _horde_hashes(-1)
	var b := _horde_hashes(-1)
	assert_eq(a.size(), 6)
	assert_eq(a, b, "the same seed twice")
	var c := _horde_hashes(300)
	assert_eq(c, a, "restored at 300: the same hashes on to 600")


func _horde_hashes(restore_at: int) -> PackedStringArray:
	NativeSwitch.install(ON)
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
			w.add_enemy(kind, p + Kin.dir((k * 4096 / 60) & 4095) * (3.0 + float(k % 4)))
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


func _built() -> bool:
	if NativeSwitch.available():
		return true
	if OS.get_environment("ZD_NATIVE_REQUIRED") == "1":
		fail_test("ZD_NATIVE_REQUIRED=1, but the native library did not load")
		return false
	pending("the native library is not built (native/README.md)")
	return false
