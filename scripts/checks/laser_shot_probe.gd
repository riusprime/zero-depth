extends SceneTree
## v0.11.0 O1d (owner, 2026-11-08: "every time it shoots the game lags a bit"): what one Laser shot costs, in the real
## game view (WorldViewRoot on the Ruins stage, the iso camera; no HUD, no audio). The hero holds SHOOT with Homing and
## Twin against a room of standing dummies; each firing tick is timed (Laser.trace alone, the whole sim step, the view's
## sync) and so are the frames around it, against the quiet frames between shots. The first shot (first-use shaders and
## scene set-up) is printed apart. Prints only; copy the numbers into evidence by hand, naming the machine and how busy
## it was. Needs a renderer (no --headless), runs uncapped:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1280x720
##   -s scripts/checks/laser_shot_probe.gd -- enemies=12 twin=3 element=ember_core shots=5

const SIZE := Vector2i(1280, 720)
const SHOT_TICKS := 180
## How many frames after a shot count as "around it" (the lance's half second of glow).
const GLOW_FRAMES := 30

var _repo: ContentRepository
var _tables: Array[ItemTable] = []
var _world: World
var _view: WorldViewRoot
var _reader: WorldReader
var _aim := 0
var _ticks := 0
var _shots := 5
var _tubes := 0
var _idle := 40
var _last_us := 0
var _frame_ms: Array[float] = []
var _step_ms: Array[float] = []
var _sync_ms: Array[float] = []
var _fired: Array[Dictionary] = []
var _opts := {"enemies": "12", "twin": "3", "element": "ember_core", "shots": "5", "homing": "1"}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			_opts[kv[0]] = kv[1]
	_shots = int(_opts["shots"])
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_repo = ContentRepository.load_all()
	_tables = ContentCompiler.compile_items(_repo)
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	t.crit_chance_permille = 0
	_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.set_item_tables(_tables)
	var cards: Array[StringName] = [&"gun_laser"]
	if _opts["homing"] == "1":
		cards.append(&"gun_homing")
	if int(_opts["twin"]) > 0:
		cards.append(&"gun_twin")
	if _opts["element"] != "none":
		cards.append(StringName(_opts["element"]))
	for id: StringName in cards:
		_world.add_item(_item(id))
	if int(_opts["twin"]) > 0:
		CardLevels.set_level(_world, _item(&"gun_twin"), int(_opts["twin"]))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	var at := _pack(_world, int(_opts["enemies"]))
	for p: Vector2 in at:
		_world.add_dummy(p, 0.35, 1 << 20)
	var mid := Vector2.ZERO
	for p: Vector2 in at:
		mid += p
	mid /= maxf(1.0, float(at.size()))
	_aim = Kin.angle_of(mid - _world.player_pos())
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	root.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood  # the effects layer and the pack, as the game has them
	_view.setup(_reader, biome.palette, 14.0)
	_view.rig.view_size = 12.0
	_view.rig.camera.size = 12.0
	_view.rig.snap_to(SimPlane.to_3d(mid * 0.5))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_view.sync()
	print("laser_shot_probe: ", _opts, " cards=", cards, " placed ", at.size())


func _item(id: StringName) -> int:
	for k in _tables.size():
		if _tables[k].id == id:
			return k
	assert(false, "no card %s" % id)
	return -1


## `n` spots in the clear in front of the hero, a loose pack (no randomness: a fixed spiral), best side first.
func _pack(w: World, n: int) -> Array[Vector2]:
	var p := w.player_pos()
	var best: Array[Vector2] = []
	for k in 24:
		var fwd := Vector2.from_angle(TAU * k / 24.0)
		var left := fwd.orthogonal()
		var got: Array[Vector2] = []
		for i in n * 3:
			if got.size() >= n:
				break
			var a := 2.4 * sqrt(float(i) + 0.5)
			var ang := float(i) * 2.399963
			var at: Vector2 = p + fwd * (5.5 + cos(ang) * a * 0.55) + left * (sin(ang) * a * 0.85)
			var ok := (at - p).dot(fwd) > 1.2
			for wk in w.walls.size():
				if Collide.circle_vs_obb(at, 0.8, w.walls[wk]) != Vector2.ZERO:
					ok = false
			if ok:
				got.append(at)
		if got.size() > best.size():
			best = got
	return best


func _process(_delta: float) -> bool:
	if _idle > 0:  # the load's warm-up draws first (the game does it behind the loading cover)
		_idle -= 1
		_view.sync()
		return false
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_frame_ms.append((now - _last_us) / 1000.0)
	_last_us = now
	var pressed := InputFrame.SHOOT if _ticks == 0 else 0
	var s := Modifiers.bolt(_world)
	var due := _world.tick
	var before := _world.mx.lz_shot_tick
	var input := InputFrame.make(Vector2i.ZERO, _aim, 500, InputFrame.SHOOT, pressed)
	var a := Time.get_ticks_usec()
	_world.step(input)
	var b := Time.get_ticks_usec()
	_view.sync()
	var c := Time.get_ticks_usec()
	_step_ms.append((b - a) / 1000.0)
	_sync_ms.append((c - b) / 1000.0)
	_ticks += 1
	if _world.mx.lz_shot_tick != before:
		var t0 := Time.get_ticks_usec()
		var paths := Laser.trace(_world, s, _world.player_pos(), _aim)
		_tubes = maxi(_tubes, _view.laser.tubes_shown)
		var t1 := Time.get_ticks_usec()
		_last_us += t1 - t0  # (this measuring trace is not part of the frame)
		_fired.append(
			{
				"tick": due,
				"frame": _ticks - 1,
				"trace_ms": (t1 - t0) / 1000.0,
				"legs": paths.size(),
				"step_ms": (b - a) / 1000.0,
				"sync_ms": (c - b) / 1000.0
			}
		)
	if _fired.size() >= _shots and _ticks > int(_fired[_shots - 1]["frame"]) + GLOW_FRAMES + 10:
		_report()
		return true
	return false


func _median(v: Array[float]) -> float:
	var s := v.duplicate()
	s.sort()
	return float(s[s.size() / 2]) if not s.is_empty() else 0.0


func _report() -> void:
	var quiet_f: Array[float] = []
	var quiet_s: Array[float] = []
	var near := {}
	for f: Dictionary in _fired:
		for k in range(int(f["frame"]) - 2, int(f["frame"]) + GLOW_FRAMES + 3):
			near[k] = true
	for k in _frame_ms.size():
		if not near.has(k) and k > 10:
			quiet_f.append(_frame_ms[k])
			quiet_s.append(_step_ms[k])
	var base := _median(quiet_f)
	print(
		(
			"quiet frames (no lance on screen): median %.2f ms over %d frames; sim step median %.3f ms"
			% [base, quiet_f.size(), _median(quiet_s)]
		)
	)
	var rest_peak: Array[float] = []
	var rest_excess: Array[float] = []
	var rest_step: Array[float] = []
	var rest_trace: Array[float] = []
	for n in _fired.size():
		var f: Dictionary = _fired[n]
		var at := int(f["frame"])
		var peak := 0.0
		var over := 0.0
		var line := ""
		for k in range(at, at + GLOW_FRAMES):
			if k >= _frame_ms.size():
				break
			peak = maxf(peak, _frame_ms[k])
			over += _frame_ms[k] - base
			if k < at + 5:
				line += " %.1f" % _frame_ms[k]
		var text := (
			"shot %d (tick %d, %d path pieces): trace %.2f ms, sim step %.2f ms, view sync %.2f ms; "
			+ "frames:%s; peak %.1f ms; %.0f ms over the quiet median across the glow"
		)
		var vals := [
			n + 1, f["tick"], f["legs"], f["trace_ms"], f["step_ms"], f["sync_ms"], line, peak, over
		]
		print(text % vals)
		if n > 0:
			rest_peak.append(peak)
			rest_excess.append(over)
			rest_step.append(float(f["step_ms"]))
			rest_trace.append(float(f["trace_ms"]))
	print(
		(
			"shots 2+ median: trace %.2f ms, sim step %.2f ms, peak frame %.1f ms, excess over the glow %.0f ms"
			% [_median(rest_trace), _median(rest_step), _median(rest_peak), _median(rest_excess)]
		)
	)
	print(
		"pack tubes drawn at most: ",
		_tubes,
		"; build ",
		ProjectSettings.get_setting("application/config/version")
	)
