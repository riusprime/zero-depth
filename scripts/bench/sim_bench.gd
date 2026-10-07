extends SceneTree
## Sim tick cost (ARCHITECTURE §13, decided 2026-10-06):
## - stress: 60 movers, ~300 projectiles, 40 walls; mean <= 2 ms per tick, p99 <= 4 ms;
## - reference: 12 movers, ~40 projectiles, 12 walls; headless >= 15x real time.
## v0.3.0 O adds the same measures with the real game (risk 1's v0.1.0 row, "real enemy AI"):
## - stress_ai: floor 3's boss room with its boss, about 60 real enemies kept alive (Charger, Warden, Needle,
##   hatchling in turn) and a player holding the items of every named combo, so engines and combos run; FightBot
##   plays, its HP topped up between ticks. Measured against the stress band.
## - reference_floor: floor 1 as played (its own spawning), FightBot playing; reference_boss: floor 2's boss fight
##   (hatchlings included). Measured against the reference band.
## The dummy-mover scenes (stress, reference) stay for comparison with v0.0.1's evidence.
## v0.4.0 SC adds the horde target (PLAN v0.4.0 "Performance"): 120 enemies + 200 projectiles <= 4 ms mean a tick.
## - horde: floor 3's start hall and its neighbours, 120 real enemies kept alive (the five normal kinds in turn),
##   the player's bolts topped up to 200 projectiles in flight, FightBot playing, HP topped up.
## Writes build/bench.json and prints a summary; paste the output into evidence by hand.
##   godot --headless --path . -s scripts/bench/sim_bench.gd

const TICKS := 3600
const STRESS_ENEMIES := 60
const ENEMY_KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.HATCHLING
]
const RUN_SEED := 20261007
## The horde scene (v0.4.0 SC).
const HORDE_ENEMIES := 120
const HORDE_PROJECTILES := 200
const HORDE_KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE
]


## `-- --only=horde,stress_ai` runs only the named scenes (quick checks); the evidence runs them all.
func _initialize() -> void:
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	var scenes := {
		"stress": func() -> Dictionary: return _run("stress", _scene(11, 60, 5, 360, 36), null),
		"reference":
		func() -> Dictionary: return _run("reference", _scene(12, 12, 16, 140, 8), null),
		"stress_ai": _stress_ai,
		"reference_floor": _reference_floor,
		"reference_boss": _reference_boss,
		"horde": _horde,
	}
	var doc := {"godot": Engine.get_version_info()["string"]}
	for name: String in scenes:
		if only.is_empty() or only.has(name):
			doc[name] = (scenes[name] as Callable).call()
	var bands := {
		"stress": _stress_ok,
		"reference": _fast,
		"stress_ai": _stress_ok,
		"reference_floor": _fast,
		"reference_boss": _fast,
		"horde": _horde_ok,
	}
	for name: String in bands:
		if doc.has(name):
			doc[name + "_in_band"] = (bands[name] as Callable).call(doc[name])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open("res://build/bench.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t", true) + "\n")
	f.close()
	print(JSON.stringify(doc, "\t", true))
	quit(0)


static func _fast(r: Dictionary) -> bool:
	return r["realtime_x"] >= 15.0


## v0.4.0 SC: the horde band, mean <= 4 ms a tick.
static func _horde_ok(r: Dictionary) -> bool:
	return r["mean_ms"] <= 4.0


static func _stress_ok(r: Dictionary) -> bool:
	return r["mean_ms"] <= 2.0 and r["p99_ms"] <= 4.0


## Movers keep 9 m away and shots spread ±45°, so projectiles live long enough to reach the target counts.
func _scene(seed_value: int, movers: int, period: int, life: int, inner_walls: int) -> World:
	var w := KernelScenario.build(seed_value, movers, period, life, inner_walls)
	w.dummy_keep_distance = 9.0
	w.dummy_aim_spread = 512
	return w


func _stress_ai() -> Dictionary:
	var repo := ContentRepository.load_all()
	var w := _floor_world(repo, RUN_SEED, 3)
	for k in _combo_items(w):
		w.add_item(k)
	_enter_boss_room(w)
	w.step(InputFrame.new())  # seals the door and spawns the boss
	var spots := _room_spots(w, 48)
	var bot := FightBot.new(RUN_SEED)
	var state := {"next": 0}
	var keep := func(world: World) -> void:
		var alive := 0
		for i in range(1, world.actors.size()):
			if world.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(world.actors.kinds[i]):
				alive += 1
		while alive < STRESS_ENEMIES + 1 and not spots.is_empty():  # + 1: the boss is an enemy kind too
			var n: int = state["next"]
			world.add_enemy(ENEMY_KINDS[n % ENEMY_KINDS.size()], spots[n % spots.size()])
			state["next"] = n + 1
			alive += 1
		if not world.boss_alive():
			world.spawn_boss(world.boss_flow.boss_index, world.floor_layout.boss_spawn)
		_top_up(world)
	keep.call(w)
	var r := _run("stress_ai", w, bot, keep)
	r["combos_owned"] = w.combos_owned.size()
	r["items_owned"] = w.items_owned.size()
	return r


## v0.4.0 SC: floor 3 with HORDE_ENEMIES real enemies kept alive around the player's start hall and its
## neighbours, and the player's bolts topped up to HORDE_PROJECTILES (damage 1, so the crowd thins slowly).
func _horde() -> Dictionary:
	var w := _floor_world(ContentRepository.load_all(), RUN_SEED, 3)
	w.spawner = null  # the scene keeps the count itself
	var spots := _horde_spots(w)
	var state := {"next": 0, "shot": 0}
	var keep := func(world: World) -> void:
		var alive := 0
		for i in range(1, world.actors.size()):
			if world.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(world.actors.kinds[i]):
				alive += 1
		while alive < HORDE_ENEMIES:
			var n: int = state["next"]
			world.add_enemy(HORDE_KINDS[n % HORDE_KINDS.size()], spots[(n * 7) % spots.size()])
			state["next"] = n + 1
			alive += 1
		var from := world.player_pos()
		for k in maxi(0, HORDE_PROJECTILES - world.projectiles.size()):
			var shot: int = state["shot"]
			state["shot"] = shot + 1
			var dir := Kin.dir((shot * 397) & 4095)
			world.queue_projectile(
				world.actors.ids[0],
				ActorStore.TEAM_PLAYER,
				from + dir * 0.6,
				dir * (12.0 / SimTick.TICKS_PER_SECOND),
				1,
				0.12,
				150,
				SimEvent.TAG_PROJECTILE
			)
		_top_up(world)
	keep.call(w)
	return _run("horde", w, FightBot.new(RUN_SEED + 3), keep)


## Spots on a 1.4 m grid in the start room and its neighbours, 1 m clear of walls and 6 m from the start.
static func _horde_spots(w: World) -> PackedVector2Array:
	var f := w.floor_layout
	var rooms := f.neighbours(f.start_room)
	rooms.append(f.start_room)
	var out := PackedVector2Array()
	for r in rooms:
		if r == f.boss_room:
			continue
		var rect := f.rooms[r].grow(-1.0)
		var y := rect.position.y
		while y <= rect.end.y:
			var x := rect.position.x
			while x <= rect.end.x:
				var p := Vector2(x, y)
				var clear := Kin.length(p - f.start_pos) >= 6.0
				for wall in w.walls:
					if clear and Collide.circle_vs_obb(p, 1.0, wall) != Vector2.ZERO:
						clear = false
				if clear:
					out.append(p)
				x += 1.4
			y += 1.4
	return out


func _reference_floor() -> Dictionary:
	var w := _floor_world(ContentRepository.load_all(), RUN_SEED, 1)
	return _run("reference_floor", w, FightBot.new(RUN_SEED + 1), _top_up)


func _reference_boss() -> Dictionary:
	var w := _floor_world(ContentRepository.load_all(), RUN_SEED, 2)
	_enter_boss_room(w)
	w.step(InputFrame.new())
	var keep := func(world: World) -> void:
		if not world.boss_alive():
			world.spawn_boss(world.boss_flow.boss_index, world.floor_layout.boss_spawn)
		_top_up(world)
	return _run("reference_boss", w, FightBot.new(RUN_SEED + 2), keep)


## Steps TICKS ticks, timing World.step only. `bot` null = ScriptedInput; `between` runs after each tick, untimed.
func _run(label: String, w: World, bot: FightBot, between: Callable = Callable()) -> Dictionary:
	var input := ScriptedInput.new(7)
	var costs := PackedFloat64Array()
	costs.resize(TICKS)
	var live_projectiles := 0
	var live_actors := 0
	var stepped_us := 0
	var flood_tick := PackedByteArray()
	flood_tick.resize(TICKS)
	var cpu0 := _cpu_ms()
	for t in TICKS:
		var frame := bot.frame(w) if bot != null else input.frame(t)
		flood_tick[t] = 1 if w.tick % NavField.PERIOD == 0 else 0
		var t0 := Time.get_ticks_usec()
		w.step(frame)
		var us := Time.get_ticks_usec() - t0
		stepped_us += us
		costs[t] = us / 1000.0
		live_projectiles += w.projectiles.size()
		live_actors += w.actors.size()
		if between.is_valid():
			between.call(w)
	var cpu := _cpu_ms() - cpu0
	var sorted := costs.duplicate()
	sorted.sort()
	var sum := 0.0
	var over := 0
	var over_on_flood := 0
	for t in TICKS:
		sum += costs[t]
		if costs[t] > 4.0:
			over += 1
			over_on_flood += flood_tick[t]
	return {
		"scene": label,
		"mean_actors": snappedf(float(live_actors) / TICKS, 0.1),
		"walls": w.walls.size(),
		"mean_projectiles": snappedf(float(live_projectiles) / TICKS, 0.1),
		"mean_ms": snappedf(sum / TICKS, 0.001),
		"p50_ms": snappedf(sorted[TICKS / 2], 0.001),
		"p99_ms": snappedf(sorted[int(TICKS * 0.99)], 0.001),
		"max_ms": snappedf(sorted[TICKS - 1], 0.001),
		# Ticks over 4 ms, and how many of them were flow-field ticks (World.tick % NavField.PERIOD == 0).
		"ticks_over_4ms": over,
		"over_4ms_on_flow_field_ticks": over_on_flood,
		# Real-time factor of the stepping alone (the bot and the untimed top-ups are left out).
		"realtime_x": snappedf((TICKS / 60.0) / (stepped_us / 1000000.0), 0.1),
		# This process's CPU time for the whole loop (stepping, the bot, the top-ups) per tick, from
		# /proc/self/stat at 10 ms resolution: unlike the wall-clock numbers above it doesn't grow when other
		# processes share the CPU. -1 where /proc is missing.
		"cpu_ms_per_tick_all": snappedf(cpu / TICKS, 0.001) if cpu0 >= 0.0 else -1.0,
	}


## This process's user + system CPU time in ms (Linux /proc/self/stat, clock ticks of 10 ms), or -1.
static func _cpu_ms() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if f == null:
		return -1.0
	var line := f.get_line()
	var rest := line.substr(line.rfind(")") + 2).split(" ")
	# After the command name: state is field 3, so utime (14) and stime (15) are rest[11] and rest[12].
	return (int(rest[11]) + int(rest[12])) * 10.0


## Floor `floor_index` of run `run_seed`, built as FloorScenario.build does for Main (app/ is off limits to
## scripts/, ARCHITECTURE §2): the run's floor seed and scaling, the floor's boss and its arena, spawning, items,
## combos and rewards. Guard utility.
static func _floor_world(repo: ContentRepository, run_seed: int, floor_index: int) -> World:
	var run := RunState.start(
		run_seed, ContentCompiler.compile_run(repo.get_def(&"run", &"three_floors"))
	)
	run.floor_index = floor_index
	var table := ContentCompiler.apply_utility(
		ContentCompiler.compile_player(repo.get_def(&"player", &"runner")),
		repo.get_def(&"utility", &"guard")
	)
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	var boss := run.pick_boss(ContentCompiler.compile_boss_pool(repo, floor_index))
	var spec := BossArenaSpec.make(bosses[boss].arena_cells, bosses[boss].arena_template, boss)
	var layout := FloorGenerator.generate(run.floor_seed())
	BossRoomBuilder.attach(layout, spec)
	var w := World.new(run.floor_seed(), table, layout.start_pos)
	var walls: Array[Obb] = layout.walls.duplicate()
	var gate_half := Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5 + 0.35)
	walls.append(Obb.make(layout.portal_pos, gate_half, layout.portal_angle))
	w.set_walls(walls)
	w.prepare_wall(layout.boss_door_wall)
	w.floor_layout = layout
	w.set_enemy_tables(enemies)
	for pts in layout.spawn_points:
		w.spawn_points.append_array(pts)
	w.spawner = ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo)
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	w.boss_flow = BossFlow.create(spec.boss_index)
	w.reward_table = ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor"))
	w.floor_index = floor_index
	run.prepare(w)
	Rewards.place(w, layout)
	w.set_boss_tables(bosses)
	return w


## The item indices of every named combo's pair (sorted, no repeats).
static func _combo_items(w: World) -> Array[int]:
	var out: Array[int] = []
	for c in w.combo_tables:
		for k in [c.item_a, c.item_b]:
			if k >= 0 and not out.has(k):
				out.append(k)
	out.sort()
	return out


static func _enter_boss_room(w: World) -> void:
	w.actors.set_pos(0, w.floor_layout.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
	w.vel = Vector2.ZERO


## Up to n spots in the boss room, on a grid, clear of walls by 1 m.
static func _room_spots(w: World, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := w.floor_layout.boss_cells_rect.grow(-1.0)
	var step := 1.6
	var y := r.position.y
	while y <= r.end.y:
		var x := r.position.x
		while x <= r.end.x:
			var p := Vector2(x, y)
			var clear := true
			for wall in w.walls:
				if Collide.circle_vs_obb(p, 1.0, wall) != Vector2.ZERO:
					clear = false
					break
			if clear and Kin.length(p - w.player_pos()) > 4.0:
				out.append(p)
			x += step
		y += step
	# Spread the picks over the room rather than filling one corner first.
	var picked := PackedVector2Array()
	var stride := maxi(1, out.size() / maxi(1, n))
	for k in range(0, out.size(), stride):
		picked.append(out[k])
	return picked


static func _top_up(w: World) -> void:
	if not w.player_dead():
		w.actors.hp[0] = w.actors.max_hp[0]
