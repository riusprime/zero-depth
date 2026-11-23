extends SceneTree
## Every sound the audio director starts over one seeded fight, and what its per-tick sync costs, so one tree's
## sound can be compared with another's byte for byte. Floor 3 (sim_bench's floor world), N enemies of the Night
## Rocks fight kept alive round the start hall, FightBot playing, the hero's HP topped up. Every tick: the world
## steps, the director syncs on the game's own reader (as SimDriver.ticked does), then its clock moves 1/60 s (its
## own _process is off, so the clock is the tick's, not the machine's).
## Each line of the dump: the tick, the stream's file, the volume, the pitch, the bus, and the 3D place of a panned
## sound; one line per voice the director starts. The sync's µs a tick (mean, p50, p99) go to stdout, and with
## `--marks=1` every PerfMarks bucket entered meanwhile, in µs a tick (the marks cost a little themselves).
## Writes only the given file (under build/); paste the timing into evidence by hand.
##   godot --headless --path . -s scripts/checks/audio_dump.gd -- [--out=build/audio_dump.txt] [--ticks=3600] \
##     [--enemies=42]

const BENCH := preload("res://scripts/bench/sim_bench.gd")
const RUN_SEED := 20261007
const KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.SWARMER,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.ROCK_LURKER,
	ActorStore.Kind.STONE_THROWER,
	ActorStore.Kind.DIM_NEEDLE,
]

var _out := "build/audio_dump.txt"
var _ticks := 3600
var _enemies := 42
var _marks := false
var _done := false


## The director's voice pool, every start written down before it plays.
class LogPool:
	extends AudioVoicePool
	var lines: PackedStringArray = []
	var tick := 0

	func start(
		stream: AudioStream,
		volume_db: float,
		pitch: float,
		bus: StringName,
		panned: bool,
		at: Vector3,
		now: float,
		seconds: float
	) -> bool:
		(
			lines
			. append(
				(
					"%d %s v=%.9f p=%.9f %s %s"
					% [
						tick,
						stream.resource_path if stream.resource_path != "" else str(stream),
						volume_db,
						pitch,
						bus,
						("at=%.9f,%.9f,%.9f" % [at.x, at.y, at.z]) if panned else "flat",
					]
				)
			)
		)
		return super.start(stream, volume_db, pitch, bus, panned, at, now, seconds)


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_out = String(args.get("--out", _out))
	_ticks = int(args.get("--ticks", _ticks))
	_enemies = int(args.get("--enemies", _enemies))
	_marks = args.get("--marks", "0") == "1"
	if not NativeWorld.available():
		NativeWorld.report_missing()
		quit(1)
		_done = true


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true


func _run() -> void:
	var repo := ContentRepository.load_all()
	var w: World = BENCH._floor_world(repo, RUN_SEED, 3)
	w.spawner = null
	var spots: PackedVector2Array = BENCH._horde_spots(w)
	var bot := FightBot.new(RUN_SEED + 3)
	var reader := WorldReader.new(w)
	var dir := AudioDirector.new()
	var pool := LogPool.new()
	dir._pool = pool
	dir.captions_forced = 1
	root.add_child(dir)
	dir.set_process(false)
	dir.set_process_input(false)
	dir.attach(reader, &"night_rocks")
	var next := 0
	var us := PackedInt32Array()
	PerfMarks.clear()
	PerfMarks.on = _marks
	for t in _ticks:
		var alive := 0
		for i in range(1, w.actors.size()):
			if w.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(w.actors.kinds[i]):
				alive += 1
		while alive < _enemies:
			w.add_enemy(KINDS[next % KINDS.size()], spots[(next * 7) % spots.size()])
			next += 1
			alive += 1
		if not w.player_dead():
			w.actors.hp[0] = w.actors.max_hp[0]
		w.step(bot.frame(w))
		pool.tick = w.tick
		var t0 := Time.get_ticks_usec()
		dir.sync(reader)
		us.append(Time.get_ticks_usec() - t0)
		dir.advance(1.0 / 60.0)
	var sorted := us.duplicate()
	sorted.sort()
	var sum := 0
	for v in us:
		sum += v
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.get_base_dir()))
	var f := FileAccess.open(_out, FileAccess.WRITE)
	f.store_string("\n".join(pool.lines) + "\n")
	f.close()
	print(
		(
			"audio_dump: ticks=%d enemies=%d spawned=%d actors_stored=%d voices=%d logged=%d %s"
			% [
				_ticks,
				_enemies,
				next,
				w.actors.size(),
				pool.lines.size(),
				dir.played_log.size(),
				_out
			]
		)
	)
	print(
		(
			"audio_dump: sync us a tick mean=%.1f p50=%d p99=%d max=%d"
			% [
				float(sum) / maxi(us.size(), 1),
				sorted[sorted.size() / 2],
				sorted[int(sorted.size() * 0.99)],
				sorted[sorted.size() - 1]
			]
		)
	)
	PerfMarks.on = false
	var keys := PerfMarks.us.keys()
	keys.sort()
	for k: StringName in keys:
		print("audio_dump: mark %-24s %8.1f us a tick" % [k, float(PerfMarks.us[k]) / _ticks])
	dir.detach()
	dir.queue_free()
	quit(0)
