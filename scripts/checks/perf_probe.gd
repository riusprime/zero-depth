extends SceneTree
## v0.8.0 PF (owner O9): the frame-cost probe for the Gun's Spread + Split + Explosive build. It builds the
## Playground's World (PlaygroundScenario: the one 4 x 4 room), grants gun_spread, split_shot and shared_explosive at
## level 5 (and gun_twin with --twin), places endless dummies in front of the hero, holds Shoot at them and times,
## per tick:
##   sim    World.step (with the Playground's upkeep: the dummies' HP refill);
##   sync   WorldViewRoot.sync (the views reading the tick);
##   frame  every _process of the view's nodes, called by this probe once per tick (the probe turns their own
##          processing off and calls them itself, so each is timed; --fixed-fps 60 makes one frame one tick).
## Headless has no GPU: "frame" is the CPU side only (building the MultiMesh buffers, lights and decals); the GPU's
## draw cost is not in it. It counts, per tick: live player projectiles, launches, sim events, explosion bursts drawn,
## VFX sprites asked for and drawn, light requests and lights on, floor marks.
## Writes only under build/ (build/perf/perf_probe.txt) and prints the same report.
##   godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd [-- --twin] [-- --seconds=10]
##   [-- --dummies=6] [-- --level=5] [-- --sim-only] [-- --cap=N]

const OUT_DIR := "res://build/perf"
const WARMUP_TICKS := 60
const TARGET_MS := 12.0

var _seconds := 10
var _twin := false
var _dummies := 6
var _level := 5
var _sim_only := false
## --cap=N: SimTuning.player_shots_max for this run (0: the shipped data/tuning/sim.tres).
var _cap := 0
var _world: World
var _api: PlaygroundApi
var _reader: WorldReader
var _view: WorldViewRoot
var _procs: Array[Node] = []
var _frame_in: InputFrame
var _tick_n := 0
var _total := 0
var _rows := {}  # metric -> Array of floats
var _keys := {}  # node instance id -> its report key
var _node_ms := {}  # class/name -> total ms over the measured ticks
var _report: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--twin":
			_twin = true
		elif a == "--sim-only":
			_sim_only = true
		elif a.begins_with("--seconds="):
			_seconds = int(a.get_slice("=", 1))
		elif a.begins_with("--dummies="):
			_dummies = int(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			_level = int(a.get_slice("=", 1))
		elif a.begins_with("--cap="):
			_cap = int(a.get_slice("=", 1))
	_total = WARMUP_TICKS + _seconds * 60
	var repo := ContentRepository.load_all()
	var run_def: RunDefinition = repo.get_def(&"run", &"three_floors")
	var biome: BiomeDefinition = repo.get_def(&"biomes", run_def.biomes[0])
	_world = PlaygroundScenario.build(repo, &"gun", biome)
	if _cap > 0 and &"player_shots_max" in _world.tuning:
		_world.tuning.set(&"player_shots_max", _cap)
	_api = PlaygroundApi.new(_world)
	_reader = WorldReader.new(_world)
	var cards: Array[StringName] = [&"gun_spread", &"split_shot", &"shared_explosive"]
	if _twin:
		cards.append(&"gun_twin")
	for id in cards:
		var ok := _api.grant_now(_item(id), _level)
		_line("grant %s L%d -> %s" % [id, _level, "ok" if ok else "FAILED"])
	var hero := _world.player_pos()
	for k in _dummies:
		var at := hero + Vector2(4.0 + 1.5 * (k / 3), -2.0 + 2.0 * (k % 3))
		if not _api.place_dummy_now(at):
			_line("dummy %d at %s: no room" % [k, at])
	_frame_in = InputFrame.make(Vector2i.ZERO, 0, 600, InputFrame.SHOOT, InputFrame.SHOOT)
	if not _sim_only:
		_view = WorldViewRoot.new()
		_view.name = "WorldView"
		_view.stage.prop_style = biome.id
		_view.stage.mood = biome.mood
		_view.stage.look = biome.look
		if biome.look != null:
			_view.actors.enemy_tint = biome.look.enemy_tint
		root.add_child(_view)
		var b := _reader.floor_bounds()
		var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
		_view.setup(_reader, biome.palette, half + 4.0)
	_line(
		(
			"perf_probe: gun + %s, level %d, %d dummies, %d s held Shoot (+%d warm-up ticks), %s"
			% [
				", ".join(cards),
				_level,
				_dummies,
				_seconds,
				WARMUP_TICKS,
				"sim only" if _sim_only else "sim + WorldView (headless: CPU side only)"
			]
		)
	)


func _item(id: StringName) -> int:
	for k in _world.item_tables.size():
		if _world.item_tables[k].id == id:
			return k
	return -1


func _process(delta: float) -> bool:
	if _tick_n >= _total:
		_finish()
		return true
	var measured := _tick_n >= WARMUP_TICKS
	var t0 := Time.get_ticks_usec()
	_api.apply_pending()  # the endless dummies' refill, as SimDriver runs it before every tick
	_world.step(_frame_in)
	var t1 := Time.get_ticks_usec()
	_frame_in = InputFrame.make(Vector2i.ZERO, 0, 600, InputFrame.SHOOT, 0)
	var sync_ms := 0.0
	var frame_ms := 0.0
	if _view != null:
		_view.sync()
		sync_ms = (Time.get_ticks_usec() - t1) / 1000.0
		_adopt(_view)
		for n in _procs:
			if not is_instance_valid(n) or not n.is_inside_tree():
				continue
			var a := Time.get_ticks_usec()
			n.call(&"_process", delta)
			var ms := (Time.get_ticks_usec() - a) / 1000.0
			frame_ms += ms
			if measured:
				var key := _node_key(n)
				_node_ms[key] = float(_node_ms.get(key, 0.0)) + ms
	if measured:
		_add("sim_ms", (t1 - t0) / 1000.0)
		_add("sync_ms", sync_ms)
		_add("frame_ms", frame_ms)
		_add("total_ms", (t1 - t0) / 1000.0 + sync_ms + frame_ms)
		_count_tick()
	_tick_n += 1
	return false


## Takes over the processing of every view node with a script _process (new ones too: avatars appear on a sync).
func _adopt(n: Node) -> void:
	if n.is_processing() and n.get_script() != null and n.has_method(&"_process"):
		n.set_process(false)
		_procs.append(n)
	for c in n.get_children():
		_adopt(c)


func _node_key(n: Node) -> String:
	var id := n.get_instance_id()
	if not _keys.has(id):
		_keys[id] = _key_of(n)
	return _keys[id]


static func _key_of(n: Node) -> String:
	var s: Script = n.get_script()
	var cls := s.get_global_name() if s != null else &""
	return String(cls) if cls != &"" else String(n.name)


func _count_tick() -> void:
	var live := 0
	for i in _reader.projectile_count():
		if _reader.projectile_team(i) == 0:
			live += 1
	_add("projectiles", live)
	var launches := _world.launch_count if _world.launch_tick == _world.tick - 1 else 0
	_add("launches", launches)
	_add("events", _world.last_event_seq() - _world.tick_seq0)
	if &"shot_tick" in _world:  # v0.8.0 PF's sim cap: 1 on a tick where a bolt found no room
		var capped: bool = (
			_world.get(&"shot_tick") == _world.tick - 1
			and int(_world.get(&"shot_count")) > _world.tuning.get(&"player_shots_max")
		)
		_add("shots_capped", 1.0 if capped else 0.0)
	if _view == null:
		return
	var vfx := _view.attack_forms.vfx
	if vfx == null:
		return
	for m: StringName in [&"bursts_asked", &"bursts_drawn", &"sprites_asked"]:
		if m in vfx:
			_add(String(m), vfx.get(m))
	var drawn := 0
	for id: StringName in vfx.pools:
		drawn += vfx.used(id)
	_add("sprites_drawn", drawn)
	if vfx.has_method(&"lights_asked"):
		_add("lights_asked", vfx.call(&"lights_asked"))
	_add("lights_on", vfx.lights_on())
	_add("decals", vfx.marks())
	_add("form_effects", _view.attack_forms.effect_count())
	_add("form_meshes", _view.attack_forms.meshes_drawn())


func _add(metric: String, v: float) -> void:
	if not _rows.has(metric):
		_rows[metric] = []
	(_rows[metric] as Array).append(v)


func _finish() -> void:
	_line("metric          avg       p95       max")
	for m: String in _rows:
		var a: Array = _rows[m]
		var sorted := a.duplicate()
		sorted.sort()
		var sum := 0.0
		for v: float in a:
			sum += v
		var p95: float = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]
		_line(
			(
				"%-14s %8.3f  %8.3f  %8.3f"
				% [m, sum / maxf(a.size(), 1), p95, sorted[sorted.size() - 1]]
			)
		)
	if not _node_ms.is_empty():
		var n := float((_rows["sim_ms"] as Array).size())
		var keys := _node_ms.keys()
		keys.sort_custom(func(x: String, y: String) -> bool: return _node_ms[x] > _node_ms[y])
		_line("frame cost by node (ms per tick, avg):")
		for k in keys.slice(0, 12):
			_line("  %-24s %8.3f" % [k, float(_node_ms[k]) / n])
	var total: Array = _rows["total_ms"]
	var sum := 0.0
	for v: float in total:
		sum += v
	var avg := sum / maxf(total.size(), 1)
	_line(
		(
			"verdict: avg %.2f ms per tick+frame against %.1f ms -> %s"
			% [avg, TARGET_MS, "within" if avg <= TARGET_MS else "OVER"]
		)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var tag := "twin" if _twin else "base"
	if _sim_only:
		tag += "_sim"
	var f := FileAccess.open(OUT_DIR + "/perf_probe_%s.txt" % tag, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_report) + "\n")
	if _view != null:
		_view.queue_free()
	quit(0)


func _line(s: String) -> void:
	print(s)
	_report.append(s)
