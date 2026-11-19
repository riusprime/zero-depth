extends SceneTree
## A real floor's fights, played the same way every time, for the perf log (docs/process/PERF_LOG.md): boots
## main.tscn, starts a run (seed SEED, or --seed=N) with every floor in one biome, goes through Main._next_floor (what
## the portal calls) to floor --floor, gives the Gun the frame probe's build (scripts/checks/probe_build.gd, the same
## --heavy and --cards options), and plays the floor's fights: the hero (invulnerable, as the dev panel's God) is put
## in the Overrun room first, then the Lockdown and arena rooms, then the others by hops from the start (never the
## boss room), and stays in each until its enemies are gone (a sealed room until it opens, SEALED_S at most) or ROOM_S
## seconds passed, holding fire, sweeping the aim and strafing as the frame probe does. Unlike the frame probe's
## Playground, this is the real floor: its rooms, waves, walls that fade, props, backdrop and signature enemies.
## It times nothing itself: run it with the perf log and read the log with scripts/perf/summarize_perf.py.
##   godot --path . --gpu-profile --resolution 2560x1440 --windowed --position -10000,-10000 \
##     -s scripts/checks/floor_fight_probe.gd -- --biome=night_rocks [--floor=3] [--secs=90] --perf-log
## --pipelines prints, for every frame that compiled a pipeline, what was drawn or made for the first time around it
## (scripts/checks/pipeline_watch.gd; it walks the tree every frame: never time a --pipelines run). Clear
## user://shader_cache and user://vulkan first to see what a player with stale caches compiles.
## Quits after --secs seconds of play on that floor (or when every room was visited). Writes nothing into the tracked
## tree.

const ProbeBuild := preload("res://scripts/checks/probe_build.gd")
const PipelineWatch := preload("res://scripts/checks/pipeline_watch.gd")
const SEED := 4404  # the default run seed (--seed=N)
const ROOM_S := 25.0
## A sealed room (an arena, the Overrun room, a Lockdown) is stayed in until it opens, this long at most.
const SEALED_S := 60.0
const STRAFE: Array[StringName] = [&"move_left", &"move_up", &"move_right", &"move_down"]
const STRAFE_S := 2.0
const SIZE := Vector2i(2560, 1440)

var _seed := SEED
var _biome := &"night_rocks"
var _floor := 3
var _secs := 90.0
var _build := ProbeBuild.new()
var _watch: PipelineWatch = null  # --pipelines
var _main: Node
var _phase := 0
var _frame := 0
var _floor_no := 1
var _world_was: World
var _rooms: Array[int] = []
var _room_k := -1
var _room_t0 := 0
var _t0 := 0
var _held := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("biome="):
			_biome = StringName(s.trim_prefix("biome="))
		elif s.begins_with("seed="):
			_seed = int(s.trim_prefix("seed="))
		elif s.begins_with("floor="):
			_floor = int(s.trim_prefix("floor="))
		elif s.begins_with("secs="):
			_secs = float(s.trim_prefix("secs="))
		elif s == "pipelines":
			_watch = PipelineWatch.new()
		else:
			_build.parse(s)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "en"
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _watch != null and _phase > 0:
		_watch.frame(root, "fight" if _phase == 3 else "floor%d" % _floor_no)
	match _phase:
		0:
			if _frame == 3:
				_main._stage_seed = _seed
				_main.start_stage()
				_main._run_biomes.fill(_biome)  # every floor of the run this biome, then the floor rebuilt
				_main._restart_floor()
				_phase = 1
				_frame = 0
		1:  # a floor is up: wait for its cover to open and its arrival to play
			if _ready_to_play():
				_world_was = _main.driver.world
				if _floor_no < _floor:
					_floor_no += 1
					_main.driver.world.actors.invuln[0] = 1 << 24
					_main._next_floor()
					_phase = 2
				else:
					_begin_fights()
		2:  # the next floor is loading
			if _main.driver != null and _main.driver.world != _world_was:
				_phase = 1
				_frame = 0
		3:
			_fight()
	return _phase == 99


func _ready_to_play() -> bool:
	if _main.driver == null or _main.view == null or _frame < 10:
		return false
	if _main.loads.busy() or _main.loads.cover.showing():
		return false
	return not _main.driver.reader.transit_holds()


func _begin_fights() -> void:
	var w: World = _main.driver.world
	var errors := _build.grant(PlaygroundApi.new(w))
	if not errors.is_empty():
		print("floor_fight_probe: the build did not go in (%s)" % "; ".join(errors))
		quit(2)
		_phase = 99
		return
	print(_build.describe())
	var f := w.floor_layout
	var rest: Array[int] = []
	for r in f.rooms.size():
		if r == f.boss_room or r == f.start_room:
			continue
		if r == f.overrun_room:
			_rooms.insert(0, r)
		elif f.lockdown_rooms.has(r) or f.arena_rooms.has(r):
			_rooms.append(r)
		else:
			rest.append(r)
	rest.sort_custom(
		func(a: int, b: int) -> bool:
			var ha := f.hops[a] if a < f.hops.size() else 999
			var hb := f.hops[b] if b < f.hops.size() else 999
			return ha < hb if ha != hb else a < b
	)
	_rooms.append_array(rest)
	print(
		(
			(
				"floor_fight_probe: floor %d (run floor_index %d) biome=%s, overrun room %d, lockdown"
				+ " rooms %s, arena rooms %s, %d rooms in order %s"
			)
			% [
				_floor_no,
				_main.run.floor_index,
				_biome,
				f.overrun_room,
				f.lockdown_rooms,
				f.arena_rooms,
				_rooms.size(),
				_rooms
			]
		)
	)
	_press_fire(true)
	_t0 = Time.get_ticks_usec()
	_phase = 3
	_next_room()


func _next_room() -> void:
	_room_k += 1
	if _room_k >= _rooms.size():
		_finish()
		return
	var w: World = _main.driver.world
	var p := w.floor_layout.rooms[_rooms[_room_k]].get_center()
	w.actors.set_pos(0, p)
	w.vel = Vector2.ZERO
	_main.view.rig.snap_to(SimPlane.to_3d(p))
	_room_t0 = Time.get_ticks_usec()
	print("floor_fight_probe: room %d at %.1f s" % [_rooms[_room_k], _elapsed()])


func _fight() -> void:
	var w: World = _main.driver.world
	w.actors.invuln[0] = 1 << 24
	w.actors.hp[0] = w.actors.max_hp[0]
	var t := _elapsed()
	if t >= _secs:
		_finish()
		return
	var leg := STRAFE[int(t / STRAFE_S) % STRAFE.size()]
	if String(leg) != _held:
		if _held != "":
			Input.action_release(StringName(_held))
		_held = String(leg)
		Input.action_press(leg)
	var a := t * 1.2
	_aim(Vector2(SIZE) * 0.5 + Vector2(cos(a), sin(a)) * 600.0)
	var in_room := (Time.get_ticks_usec() - _room_t0) / 1e6
	if in_room < 3.0:
		return
	var sealed := Lockdowns.holds_spawns(w) or (w.arenas != null and w.arenas.sealed())
	if sealed and in_room < SEALED_S:
		return
	if in_room >= ROOM_S or _enemies_near(w) == 0:
		_next_room()


func _enemies_near(w: World) -> int:
	var p := w.player_pos()
	var n := 0
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] != 0 or w.actors.hp[i] <= 0:
			continue
		if w.actors.teams[i] == ActorStore.TEAM_ENEMY and w.actors.pos(i).distance_to(p) < 16.0:
			n += 1
	return n


func _elapsed() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


func _finish() -> void:
	print("floor_fight_probe: done after %.1f s, %d rooms" % [_elapsed(), _room_k])
	if _watch != null:
		print(
			(
				"floor_fight_probe: pipelines compiled (canvas/mesh/surface/draw/spec) %s"
				% _watch.compiles
			)
		)
	_press_fire(false)
	if _held != "":
		Input.action_release(StringName(_held))
	_phase = 99


func _press_fire(on: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = on
	ev.position = Vector2(SIZE) * 0.5
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _aim(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)
