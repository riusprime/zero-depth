extends SceneTree
## The projectile phase's cost in the scenes with the most projectiles (sim_bench's): `horde` (floor 3, 120 real
## enemies kept alive, the hero's bolts topped up to 200 in flight, FightBot playing) and `stress` (60 firing dummies,
## about 300 projectiles, 36 inner walls). Per tick it times World.step and the projectile phase with its parts
## (World.phase_probe, probe-only: it changes no outcome), prints the ms mean / p99 per phase and the mean live
## projectiles, and a hash chain of World.state_hash every 60 ticks (the outcome, to compare a build against itself).
## Needs the native library (it stops with the one error without it).
## Writes nothing tracked; paste the output into evidence by hand.
##   godot --headless --path . -s scripts/checks/shot_phases.gd [-- --scenes=horde,stress] [-- --ticks=1800]

const BENCH := preload("res://scripts/bench/sim_bench.gd")
const PHASES: Array[StringName] = [
	&"step",
	&"proj",
	&"proj.steer",
	&"proj.sweep",
	&"proj.damage",
	&"proj.procs",
	&"proj.end",
	&"proj.remove"
]


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var scenes := String(args.get("--scenes", "horde,stress")).split(",")
	var ticks := int(args.get("--ticks", 1800))
	if not NativeWorld.available():
		NativeWorld.report_missing()
		quit(1)
		return
	for s in scenes:
		match s:
			"horde":
				_horde(ticks)
			"stress":
				_stress(ticks)
			_:
				push_error("shot_phases: unknown scene %s" % s)
				quit(1)
				return
	quit(0)


func _horde(ticks: int) -> void:
	var w: World = BENCH._floor_world(ContentRepository.load_all(), BENCH.RUN_SEED, 3)
	w.spawner = null
	var spots: PackedVector2Array = BENCH._horde_spots(w)
	var state := {"next": 0, "shot": 0}
	var keep := func(world: World) -> void:
		var alive := 0
		for i in range(1, world.actors.size()):
			if world.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(world.actors.kinds[i]):
				alive += 1
		while alive < BENCH.HORDE_ENEMIES:
			var n: int = state["next"]
			world.add_enemy(
				BENCH.HORDE_KINDS[n % BENCH.HORDE_KINDS.size()], spots[(n * 7) % spots.size()]
			)
			state["next"] = n + 1
			alive += 1
		var from := world.player_pos()
		for k in maxi(0, BENCH.HORDE_PROJECTILES - world.projectiles.size()):
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
		BENCH._top_up(world)
	keep.call(w)
	_run("horde", w, FightBot.new(BENCH.RUN_SEED + 3), keep, ticks)


func _stress(ticks: int) -> void:
	var w := KernelScenario.build(11, 60, 5, 360, 36)
	w.dummy_keep_distance = 9.0
	w.dummy_aim_spread = 512
	_run("stress", w, null, Callable(), ticks)


func _run(label: String, w: World, bot: FightBot, between: Callable, ticks: int) -> void:
	var input := ScriptedInput.new(7)
	var timer := PerfBreakdown.PhaseTimer.new()
	w.phase_probe = timer
	var samples := {}
	for k in PHASES:
		samples[k] = []
	var chain := StateHasher.new()
	var live := 0
	for t in ticks:
		var frame := bot.frame(w) if bot != null else input.frame(t)
		timer.reset()
		var t0 := Time.get_ticks_usec()
		w.step(frame)
		var us := Time.get_ticks_usec() - t0
		(samples[&"step"] as Array).append(us / 1000.0)
		for k in PHASES:
			if k != &"step":
				(samples[k] as Array).append(int(timer.us.get(k, 0)) / 1000.0)
		live += w.projectiles.size()
		if between.is_valid():
			between.call(w)
		if t % 60 == 59:
			chain.add_string(w.state_hash())
	print("%s ticks=%d mean_projectiles=%.1f" % [label, ticks, float(live) / ticks])
	for k in PHASES:
		var a: Array = samples[k]
		var s := a.duplicate()
		s.sort()
		var sum := 0.0
		for v in a:
			sum += v
		print("  %-12s mean %7.3f  p99 %7.3f ms" % [k, sum / a.size(), s[int(a.size() * 0.99)]])
	print("  outcome_hash %s  final_tick_hash %s" % [chain.finish_hex(), w.state_hash()])
