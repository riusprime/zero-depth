extends SceneTree
## v0.4.0 SC: frame time of the real game view (WorldViewRoot: stage, ActorViews, telegraphs, occlusion, the iso
## camera) over the horde scene of sim_bench.gd: floor 3, 120 real enemies kept alive around the start hall and its
## neighbours, the player's bolts topped up to 200, FightBot playing, one sim tick per frame. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/bench/view_bench.gd
## In a container that is lavapipe, a CPU rasteriser: the numbers say how the view's CPU side scales with the crowd,
## not what the owner's GPU does (OWNER ONLY). Writes build/view_bench.json and prints it; paste by hand.
## `-- --enemies=N` changes the crowd (default 120), `-- --frames=N` the frames measured (default 300).

const SimBench := preload("res://scripts/bench/sim_bench.gd")
const WARM := 30

var _world: World
var _view: WorldViewRoot
var _bot: FightBot
var _spots := PackedVector2Array()
var _enemies := SimBench.HORDE_ENEMIES
var _frames := 300
var _next := 0
var _shot := 0
var _frame := 0
var _last_us := 0
var _frame_ms := PackedFloat64Array()
var _step_ms := PackedFloat64Array()
var _sync_ms := PackedFloat64Array()
var _draws := PackedFloat64Array()
var _objects := PackedFloat64Array()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemies="):
			_enemies = int(arg.trim_prefix("--enemies="))
		if arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
	Engine.max_fps = 0
	var repo := ContentRepository.load_all()
	_world = SimBench._floor_world(repo, SimBench.RUN_SEED, 3)
	_world.spawner = null
	_spots = SimBench._horde_spots(_world)
	_bot = FightBot.new(SimBench.RUN_SEED + 3)
	_top_up()
	_view = WorldViewRoot.new()
	root.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"red_canyon")
	var b := _world.floor_layout.bounds
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	_view.setup(WorldReader.new(_world), biome.palette, half + 4.0)
	_view.rig.camera.current = true


func _top_up() -> void:
	var alive := 0
	for i in range(1, _world.actors.size()):
		if _world.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(_world.actors.kinds[i]):
			alive += 1
	while alive < _enemies:
		var kind: int = SimBench.HORDE_KINDS[_next % SimBench.HORDE_KINDS.size()]
		_world.add_enemy(kind, _spots[(_next * 7) % _spots.size()])
		_next += 1
		alive += 1
	var from := _world.player_pos()
	for k in maxi(0, SimBench.HORDE_PROJECTILES - _world.projectiles.size()):
		var dir := Kin.dir((_shot * 397) & 4095)
		_shot += 1
		_world.queue_projectile(
			_world.actors.ids[0],
			ActorStore.TEAM_PLAYER,
			from + dir * 0.6,
			dir * (12.0 / SimTick.TICKS_PER_SECOND),
			1,
			0.12,
			150,
			SimEvent.TAG_PROJECTILE
		)
	_world.actors.hp[0] = _world.actors.max_hp[0]


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if _frame > WARM and _last_us > 0:
		_frame_ms.append((now - _last_us) / 1000.0)
		_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_last_us = now
	_frame += 1
	if _frame % 50 == 0:
		print("frame %d" % _frame)
	if _frame > WARM + _frames:
		_finish()
		return true
	_top_up()
	var t0 := Time.get_ticks_usec()
	_world.step(_bot.frame(_world))
	var t1 := Time.get_ticks_usec()
	_view.sync()
	var t2 := Time.get_ticks_usec()
	if _frame > WARM:
		_step_ms.append((t1 - t0) / 1000.0)
		_sync_ms.append((t2 - t1) / 1000.0)
	return false


func _finish() -> void:
	var doc := {
		"godot": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_video_adapter_vendor(),
		"enemies_target": _enemies,
		"frames": _frame_ms.size(),
		"mean_actors": _world.actors.size(),
		"frame_ms": _stats(_frame_ms),
		"fps_mean": snappedf(1000.0 / maxf(0.001, _stats(_frame_ms)["mean"]), 0.1),
		"sim_step_ms": _stats(_step_ms),
		"view_sync_ms": _stats(_sync_ms),
		"draw_calls_mean": snappedf(_stats(_draws)["mean"], 1.0),
		"objects_mean": snappedf(_stats(_objects)["mean"], 1.0),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open("res://build/view_bench.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t", true) + "\n")
	f.close()
	print(JSON.stringify(doc, "\t", true))
	quit(0)


static func _stats(a: PackedFloat64Array) -> Dictionary:
	if a.is_empty():
		return {"mean": 0.0, "p50": 0.0, "p95": 0.0}
	var s := a.duplicate()
	s.sort()
	var sum := 0.0
	for v in a:
		sum += v
	return {
		"mean": snappedf(sum / a.size(), 0.01),
		"p50": snappedf(s[s.size() / 2], 0.01),
		"p95": snappedf(s[int(s.size() * 0.95)], 0.01),
	}
