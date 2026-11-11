class_name NativeFixtures
extends RefCounted
## The cross-compiler fixtures of the native core (NATIVE_CORE.md §6): what every kernel of the C++ library gives on
## fixed, seeded inputs, as hashes of the float and int bits, and a seeded world's state hash after SCENE_TICKS. The
## values are recorded once from the owner's Windows build (MSVC) into tests/golden/fixtures/native_kernels_hash.txt
## and native_horde_hash.txt (tests/golden/generate_native_fixtures.gd, on purpose only); Linux CI (gcc) and a release
## build (scripts/native/check_release.sh) must give the same. A compiler, a flag or an optimisation level that rounds
## one operation differently changes a hash here before it changes any golden.
## Checked by tests/golden/test_native_fixtures.gd and scripts/checks/native_fixtures.gd.

const KERNELS_FILE := "res://tests/golden/fixtures/native_kernels_hash.txt"
const SCENE_FILE := "res://tests/golden/fixtures/native_horde_hash.txt"
## The kernels in the order they are checked (and the first one that differs is named).
const ORDER: Array[StringName] = [
	&"probe", &"nav", &"think", &"move", &"collide", &"strike", &"shots"
]
const RUN_SEED := 31
const FLOOR := 3
const ENEMIES := 60
const WARM_TICKS := 120
const SCENE_TICKS := 600
const SHOTS := 80
const KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.SWARMER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.SPLITTER,
	ActorStore.Kind.SHIELD_BEARER,
	ActorStore.Kind.SNIPER,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE,
	ActorStore.Kind.MENDER,
	ActorStore.Kind.MINE_LAYER,
	ActorStore.Kind.DUST_MITE,
]


## The horde world every fixture starts from: floor FLOOR of run RUN_SEED, ENEMIES of the table kinds in a ring round
## the hero (too tough to die), no spawner.
static func horde_world() -> World:
	var w := SaveLab.floor_world(RUN_SEED, FLOOR)
	w.spawner = null
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	var p := w.player_pos()
	for k in ENEMIES:
		var kind: int = KINDS[k % KINDS.size()]
		if w.enemy_table(kind) != null:
			w.add_enemy(kind, p + Kin.dir((k * 4096 / ENEMIES) & 4095) * (3.0 + float(k % 4)))
	return w


## The scene fixture: the horde world played by FightBot for SCENE_TICKS; its final state hash.
static func scene_hash() -> String:
	var w := horde_world()
	var bot := FightBot.new(5)
	for t in SCENE_TICKS:
		w.step(SaveLab.frame(w, bot))
	return w.state_hash()


## Each kernel's hash, by name (ORDER): the horde world warmed up WARM_TICKS, then each kernel called once, directly,
## in tick order, each on the state the one before left; each hash covers the kernel's own outputs and the columns
## it writes back.
static func kernel_hashes() -> Dictionary:
	var out := {}
	var probe: Object = ClassDB.instantiate(NativeWorld.CLASS)
	out[&"probe"] = String(probe.determinism_probe())
	var w := horde_world()
	var bot := FightBot.new(5)
	for t in WARM_TICKS:
		w.step(SaveLab.frame(w, bot))
	var m: Object = w.native
	var a := w.actors
	NativeWorld.sync_walls(w)
	NativeWorld.sync_kinds(w)
	# nav: the whole flood from the hero, the enemies' cells as targets, and its direction lookups
	w.nav.set(&"_flooded", Vector3i(-1, -1, -1))
	w.nav.flood(w.player_pos(), NavField.WORLD_FLOOD_STEPS, w._nav_targets(), m)
	var h := StateHasher.new()
	h.add_ints(w.nav.dist)
	h.add_int(w.nav.last_work)
	var xy := PackedFloat32Array()
	for i in a.size():
		xy.append(a.pos_x[i] + 0.13)
		xy.append(a.pos_y[i] - 0.07)
	h.add_f32s(m.nav_directions(xy))
	out[&"nav"] = h.finish_hex()
	# think (phase 3)
	var hero := NativeAi.hero_of(w)
	h = StateHasher.new()
	h.add_int(m.think(a, hero, w.tick, PackedByteArray(), w.mines.owner))
	h.add_ints(m.ai_intents_i())
	h.add_f32s(m.ai_intents_f())
	_hash_actors(h, a)
	out[&"think"] = h.finish_hex()
	# move (phase 5's steering)
	h = StateHasher.new()
	h.add_int(m.move(a, hero, PackedFloat32Array(), float(w.item_mods.slow_permille)))
	h.add_ints(m.ai_intents_i())
	_hash_actors(h, a)
	out[&"move"] = h.finish_hex()
	# collide (phase 5's passes), with a few bodies marked through and heavy
	var through := PackedInt32Array()
	var heavy := PackedInt32Array()
	for i in a.size():
		through.append(1 if i % 17 == 5 else 0)
		heavy.append(1 if i % 13 == 7 else 0)
	h = StateHasher.new()
	h.add_int(m.resolve_actors(a, through, heavy, false, SimTick.COLLIDE_ITERS))
	h.add_f32s(a.pos_x)
	h.add_f32s(a.pos_y)
	out[&"collide"] = h.finish_hex()
	# strike (phase 6): every row's state put to ACTIVE at its first tick, so each shape is tested once
	for i in range(1, a.size()):
		a.state[i] = EnemyAi.State.ACTIVE
		a.state_t[i] = 0
		a.fire_cd[i] = 0
	h = StateHasher.new()
	h.add_int(m.strike(a, NativeAi.hero_of(w)))
	h.add_ints(m.strike_out_i())
	h.add_f32s(m.strike_out_f())
	out[&"strike"] = h.finish_hex()
	# shots: SHOTS seeded projectiles of both teams through the walls and the bodies
	var rng := RngStream.derive(RUN_SEED, "native_fixtures")
	var p := w.player_pos()
	for k in SHOTS:
		var at := p + Vector2(rng.range_int(-800, 800), rng.range_int(-800, 800)) / 100.0
		var vel := Vector2(rng.range_int(-60, 60), rng.range_int(-60, 60)) / 100.0
		var team := ActorStore.TEAM_PLAYER if k % 2 == 0 else ActorStore.TEAM_ENEMY
		w.queue_projectile(a.ids[0], team, at, vel, 1, 0.1, 1 + k % 4, SimEvent.TAG_PROJECTILE)
	w._apply_spawns()
	h = StateHasher.new()
	h.add_int(m.sweep_shots(w.projectiles, a, PackedByteArray(), PackedByteArray()))
	h.add_ints(m.shot_events())
	h.add_f32s(m.shot_t())
	h.add_f32s(w.projectiles.pos_x)
	h.add_f32s(w.projectiles.pos_y)
	h.add_ints(w.projectiles.life)
	out[&"shots"] = h.finish_hex()
	return out


## The columns the enemy kernels write.
static func _hash_actors(h: StateHasher, a: ActorStore) -> void:
	for col: PackedInt32Array in [
		a.state, a.state_t, a.cd, a.fire_cd, a.facing, a.lock_a, a.windup, a.pick
	]:
		h.add_ints(col)
	h.add_ints(a.plan_block)
	for col: PackedFloat32Array in [
		a.pos_x, a.pos_y, a.lock_x, a.lock_y, a.lock_len, a.plan_x, a.plan_y
	]:
		h.add_f32s(col)


## The kernels file as written: one "name hash" a line, in ORDER.
static func kernels_text(hashes: Dictionary) -> String:
	var lines := PackedStringArray()
	for k in ORDER:
		lines.append("%s %s" % [k, hashes.get(k, "")])
	return "\n".join(lines) + "\n"


## A kernels file read back: name -> hash ({} when missing).
static func read_kernels() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(KERNELS_FILE):
		return out
	for line in FileAccess.get_file_as_string(KERNELS_FILE).split("\n", false):
		var parts := line.strip_edges().split(" ", false)
		if parts.size() == 2:
			out[StringName(parts[0])] = parts[1]
	return out


## The recorded scene hash ("" when missing).
static func read_scene() -> String:
	if not FileAccess.file_exists(SCENE_FILE):
		return ""
	return FileAccess.get_file_as_string(SCENE_FILE).strip_edges()


## Every difference between what this build gives and the recorded fixtures, first kernel first: [] when they agree.
## Each line says plainly that the native core gives different results on this compiler or platform.
static func differences() -> PackedStringArray:
	var out := PackedStringArray()
	var want := read_kernels()
	var got := kernel_hashes()
	var target := OS.get_environment("ZD_NATIVE_TARGET")  # scripts/native/check_release.sh sets template_release
	var where := "%s, %s library" % [OS.get_name(), target if target != "" else "template_debug"]
	for k in ORDER:
		if String(want.get(k, "")) != String(got.get(k, "")):
			(
				out
				. append(
					(
						(
							"the native core gives different results on this compiler/platform (%s): kernel %s gives %s, the"
							+ " recorded fixture is %s (tests/golden/fixtures/native_kernels_hash.txt)"
						)
						% [where, k, got.get(k, ""), want.get(k, "(missing)")]
					)
				)
			)
	var scene := scene_hash()
	if scene != read_scene():
		(
			out
			. append(
				(
					(
						"the native core gives different results on this compiler/platform (%s): the horde scene ends on %s,"
						+ " the recorded fixture is %s (tests/golden/fixtures/native_horde_hash.txt)"
					)
					% [where, scene, read_scene()]
				)
			)
		)
	return out
