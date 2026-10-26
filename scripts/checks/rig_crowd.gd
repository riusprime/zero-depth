extends SceneTree
## v0.9.5 PF5: what merging the enemy rigs (RigMerge) costs and saves, on a fixed crowd. Twenty enemies (a fixed mix of
## every merged kind) walk and strike in a lit room under the game's iso camera at 1920x1080, built through the real
## ActorViews._make_actor; the same crowd is timed with RigMerge off and on, OFF ON OFF ON (so a drift or a busy machine
## shows as OFF vs OFF). Per phase: frames, mean and p99 frame ms, draw calls and objects per frame (Performance
## monitors), the renderer's CPU and GPU ms, the script process time, and how long building the crowd took.
## Needs a renderer (NOT --headless); one windowed Godot at a time; the numbers are only as good as the machine is idle:
##   APPDATA=$TEMP/zd-pf5 godot --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/rig_crowd.gd
##   ... -- [--secs=6] [--warm=2]

const MIX: Array[int] = [
	WorldReader.KIND_NEEDLE,
	WorldReader.KIND_NEEDLE,
	WorldReader.KIND_NEEDLE,
	WorldReader.KIND_CHARGER,
	WorldReader.KIND_CHARGER,
	WorldReader.KIND_HATCHLING,
	WorldReader.KIND_ARC_CASTER,
	WorldReader.KIND_ARC_CASTER,
	WorldReader.KIND_WARDEN,
	WorldReader.KIND_BOMB_DRONE,
	WorldReader.KIND_BOMB_DRONE,
	WorldReader.KIND_LENS_DRONE,
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SHIELD_BEARER,
	WorldReader.KIND_MENDER,
	WorldReader.KIND_MINE_LAYER,
	WorldReader.KIND_SNIPER,
	WorldReader.KIND_BREAKER,
	WorldReader.KIND_CONDUIT,
]
const PHASES := [false, true, false, true]

var _secs := 6.0
var _warm := 2.0
var _crowd: Node3D
var _avatars: Array[AvatarBase] = []
var _actors: Array[Node3D] = []
var _tick := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--secs="):
			_secs = float(a.substr(7))
		elif a.begins_with("--warm="):
			_warm = float(a.substr(7))
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_room()
	print("rig_crowd: 20 enemies, %d s measured after %d s warm-up, OFF ON OFF ON" % [_secs, _warm])
	for on: bool in PHASES:
		RigMerge.enabled = on
		var t0 := Time.get_ticks_usec()
		_build()
		var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
		await _measure("merge %-3s" % ("ON" if on else "OFF"), build_ms)
		_crowd.queue_free()
		await process_frame
	quit()


func _room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.2, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.65)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 135, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.4, 0.36)
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 20.0
	root.add_child(cam)
	cam.position = Vector3(11, 12, 11)
	cam.look_at(Vector3.ZERO)
	cam.current = true


func _build() -> void:
	_avatars.clear()
	_actors.clear()
	_crowd = Node3D.new()
	root.add_child(_crowd)
	var views := ActorViews.new()
	_crowd.add_child(views)
	for i in MIX.size():
		var kind := MIX[i]
		var actor: Node3D = views._make_actor(kind, false, 0.5)
		var a := TAU * float(i) / float(MIX.size())
		actor.position = Vector3(cos(a) * 6.0, 0.0, sin(a) * 6.0)
		views.add_child(actor)
		ActorViews.tint_greys(actor, views.enemy_tint)
		ActorViews.role_glow(actor, kind, ActorViews.role_glow_energy)
		_avatars.append(actor.get_meta(&"enemy_avatar") as AvatarBase)
		_actors.append(actor)
	_tick = 0


## Drives each enemy as the sim would: a state cycle (walk, wind-up, attack, recover) a tick at a time at 60 Hz.
func _drive() -> void:
	_tick += 1
	for i in _avatars.size():
		var t := (_tick + i * 17) % 240
		var state := WorldReader.STATE_MOVE
		var wind := 0.0
		if t >= 120 and t < 150:
			state = WorldReader.STATE_WINDUP
			wind = float(t - 120) / 30.0
		elif t >= 150 and t < 170:
			state = WorldReader.STATE_ACTIVE
		elif t >= 170 and t < 190:
			state = WorldReader.STATE_RECOVER
		var pos := Vector2(_actors[i].position.x, _actors[i].position.z)
		if state == WorldReader.STATE_MOVE:
			pos += Vector2(0.6, 0.0).rotated(float(i)) / 60.0 * 2.0
			_actors[i].position = Vector3(pos.x, 0.0, pos.y)
		(
			_avatars[i]
			. apply_state(
				{
					"tick": _tick,
					"pos": pos,
					"state": state,
					"windup": wind,
					"radius": 0.5,
					"pick": WorldReader.ELITE_BASIC,
					"vanished": false,
					"vulnerable": false,
					"healing": false,
				}
			)
		)


func _measure(label: String, build_ms: float) -> void:
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var frames := PackedFloat64Array()
	var draws := 0.0
	var objs := 0.0
	var cpu := 0.0
	var gpu := 0.0
	var proc := 0.0
	var n := 0
	var last := Time.get_ticks_usec()
	var t_start := last
	var next_tick := last
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		while now >= next_tick:  # the sim's 60 Hz ticks that fell due
			_drive()
			next_tick += 16667
		var elapsed := (now - t_start) / 1e6
		if elapsed >= _warm:
			frames.append((now - last) / 1000.0)
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			n += 1
		last = now
		if elapsed >= _warm + _secs:
			break
	var sorted := frames.duplicate()
	sorted.sort()
	var mean := 0.0
	for f in frames:
		mean += f
	mean /= maxf(frames.size(), 1.0)
	var p99: float = sorted[mini(int(sorted.size() * 0.99), sorted.size() - 1)]
	print(
		(
			(
				"%s frames=%d avg_ms=%.2f p99_ms=%.2f draw_calls=%.0f objects=%.0f render_cpu_ms=%.2f render_gpu_ms=%.2f "
				+ "script_process_ms=%.2f build_20_enemies_ms=%.1f"
			)
			% [label, n, mean, p99, draws / n, objs / n, cpu / n, gpu / n, proc / n, build_ms]
		)
	)
