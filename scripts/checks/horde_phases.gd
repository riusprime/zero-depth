extends SceneTree
## v0.10.5 (PERF_PLAYLOG_1: hordes of 41-60 are the slow fights): the sim's phase costs against the enemy count.
## Floor 3 (sim_bench's floor world, its horde spots: the start hall and its neighbours), N real enemies kept alive
## (the horde kinds in turn), FightBot playing, the hero's HP topped up. Per tick it times World.step and its phases
## (World.phase_probe, probe-only: it changes no outcome) and prints ms mean / p99 / max per phase for each count, and
## a hash chain of World.state_hash every 60 ticks (the outcome: the same before and after a speed-up).
## Writes nothing tracked; paste the output into evidence by hand.
##   godot --headless --path . -s scripts/checks/horde_phases.gd [-- --counts=20,40,60] [-- --ticks=1800]
## `--native=move,ai,...` (or `all`; `1` is `move`): those kernels run native (NativeSwitch); it stops if the library
## is missing.

const BENCH := preload("res://scripts/bench/sim_bench.gd")
const RUN_SEED := 20261007
const FLOOD_REPS := 60
const KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE
]
const PHASES: Array[StringName] = [
	&"step",
	&"nav_flood",
	&"ai",
	&"ai.grid",
	&"ai.plan",
	&"move",
	&"move.steer",
	&"move.walls",
	&"move.grid",
	&"move.pairs",
	&"move.native",
	&"actions",
	&"resolve",
	&"proj"
]


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var counts := PackedInt32Array([20, 40, 60])
	if args.has("--counts"):
		counts = PackedInt32Array()
		for s in String(args["--counts"]).split(","):
			counts.append(int(s))
	var ticks := int(args.get("--ticks", 1800))
	var native := NativeSwitch.parse(String(args.get("--native", "0")))
	if native < 0:
		push_error(
			"horde_phases: --native names an unknown kernel (move, ai, strike, shots, nav, all)"
		)
		quit(1)
		return
	if NativeSwitch.install(native) != native:
		push_error("horde_phases: --native asks for kernels but the native library is not loaded")
		quit(1)
		return
	print("native %s" % (NativeWorld.names_of(native) if native != 0 else "off"))
	var repo := ContentRepository.load_all()
	for n in counts:
		_measure(repo, n, ticks)
	quit(0)


func _measure(repo: ContentRepository, n: int, ticks: int) -> void:
	var w: World = BENCH._floor_world(repo, RUN_SEED, 3)
	w.spawner = null
	var spots: PackedVector2Array = BENCH._horde_spots(w)
	var bot := FightBot.new(RUN_SEED + 3)
	var timer := PerfBreakdown.PhaseTimer.new()
	w.phase_probe = timer
	var samples := {}
	for k in PHASES:
		samples[k] = []
	var next := 0
	var chain := StateHasher.new()
	var alive_sum := 0
	for t in ticks:
		var alive := 0
		for i in range(1, w.actors.size()):
			if w.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(w.actors.kinds[i]):
				alive += 1
		while alive < n:
			w.add_enemy(KINDS[next % KINDS.size()], spots[(next * 7) % spots.size()])
			next += 1
			alive += 1
		alive_sum += alive
		if not w.player_dead():
			w.actors.hp[0] = w.actors.max_hp[0]
		var frame := bot.frame(w)
		timer.reset()
		var t0 := Time.get_ticks_usec()
		w.step(frame)
		var us := Time.get_ticks_usec() - t0
		(samples[&"step"] as Array).append(us / 1000.0)
		for k in PHASES:
			if k != &"step":
				(samples[k] as Array).append(int(timer.us.get(k, 0)) / 1000.0)
		if t % 60 == 59:
			chain.add_string(w.state_hash())
	print(
		(
			"enemies=%d ticks=%d mean_alive=%.1f spawned=%d"
			% [n, ticks, float(alive_sum) / ticks, next]
		)
	)
	for k in PHASES:
		var a: Array = samples[k]
		var s := a.duplicate()
		s.sort()
		var sum := 0.0
		for v in a:
			sum += v
		print(
			(
				"  %-11s mean %7.3f  p99 %7.3f  max %7.3f ms"
				% [k, sum / a.size(), s[int(a.size() * 0.99)], s[a.size() - 1]]
			)
		)
	print("  outcome_hash %s  final_tick_hash %s" % [chain.finish_hex(), w.state_hash()])
	_flood_bench(w)


## The flood alone, on the world as the run left it (its hero's cell and its enemies' cells as targets): NavField.flood
## from scratch FLOOD_REPS times; the min and median ms (the min is the least noisy on a busy machine), its work and
## the grid's cells, and a hash of the distances (the same before and after a speed-up).
## With the native flood on (NativeWorld.NAV) it prints a second line, the same flood run native.
func _flood_bench(w: World) -> void:
	_flood_line(w, "flood_alone", null)
	if (w.native_on & NativeWorld.NAV) != 0:
		_flood_line(w, "flood_native", w.native)


func _flood_line(w: World, label: String, kernel: Object) -> void:
	var targets: PackedInt32Array = w._nav_targets()
	var times := []
	for r in FLOOD_REPS:
		w.nav._flooded = Vector3i(-1, -1, -1)
		var t0 := Time.get_ticks_usec()
		w.nav.flood(w.player_pos(), NavField.WORLD_FLOOD_STEPS, targets, kernel)
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	var h := StateHasher.new()
	h.add_ints(w.nav.dist)
	print(
		(
			"  %s min %.3f  median %.3f ms  work %d  cells %d  targets %d  dist_hash %s"
			% [
				label,
				times[0],
				times[FLOOD_REPS / 2],
				w.nav.last_work,
				w.nav.size.x * w.nav.size.y,
				targets.size(),
				h.finish_hex()
			]
		)
	)
