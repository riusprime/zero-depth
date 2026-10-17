extends SceneTree
## v0.8.0 P3 (owner O29): the per-biome frame probe. One real generated floor (SaveLab.floor_world: the same run seed
## and floor index every time) is drawn by the game's own WorldViewRoot in one biome (its mood, look, kit, shards,
## surface and edge), and the camera stops at the same spots (the start room, then the next rooms by index) at the
## game's view size. At each spot, after `settle` frames, it times `frames` rendered frames:
##   frame_ms   the wall-clock time between two frames (vsync off, no fps cap): CPU + the renderer;
##   cpu_ms     the CPU time the whole process (every thread: the software renderer's too) spent over that frame,
##              from /proc/self/stat (10 ms steps; Linux only, -1 elsewhere): unlike frame_ms it doesn't grow when
##              other processes share the machine's cores;
##   render_cpu RenderingServer's measured CPU time of the viewport's render (ms);
##   render_gpu RenderingServer's measured GPU time of the viewport's render (ms; a software Vulkan device here);
##   draws      draw calls in the frame; objects: objects drawn; prims: primitives drawn;
##   omni_all / omni_shadow / omni_visible: OmniLight3D nodes in the view, shadow-casting ones, and the ones whose
##              energy is above 0 and are visible.
## With cpu=1 (headless is fine) it also times, per frame:
##   sync_ms    WorldViewRoot.sync() called once per frame by the probe (what the game runs every tick: every view
##              reading the world, the walls' occlusion test over the floor's walls); kit_ms: StageKit's own frame
##              work (its lights' flicker, fades and picks), called by the probe; sprites: effect sprites asked for
##              (the fire props' flames among them). These three are CPU only, so they also mean something headless.
## The world is never stepped (a still floor). Needs a renderer (Forward+; in a container: xvfb-run with a software
## Vulkan device):
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/checks/biome_probe.gd \
##     -- biome=ruins [seed=20261008] [floor=1] [frames=120] [settle=20] [spots=5] [tag=before]
##     [lighting=high|low] [shot=1] [light_spot=1] [off=fog,glow,…] [cpu=1] [walls=auto|old|a|b]
## v0.8.0 N10: walls= sets ViewPrefs.wall_style before the floor is built, and a "walls:" line reports the style, the
## structural walls' wall meshes and full-detail triangles, and the procedural walls' build time; build_ms is the
## whole view's setup (the floor's stage, kit and walls).
## Writes only under build/ (build/perf/biome_probe_<biome>[_<tag>].txt) and prints the same report. Quits on every
## path.

const OUT_DIR := "res://build/perf"

var _biome_id := &"ruins"
var _seed := 20261008
var _floor := 1
var _frames := 120
var _settle := 20
var _spots_max := 5
var _tag := ""
var _lighting := "high"
## shot=1: also saves the first measured frame of each spot (build/perf/shots/<tag>/<biome>_<spot>.png).
var _shot := false
## light_spot=1: one more spot, on the fire prop nearest the hero's start (the glow of a barrel or a torch).
var _light_spot := false
## off=a,b,…: diagnosis only, turns these off after the view is built (fog, glow, ssao, ssil, kit_shadows: the fire
## props' shadows, sun_shadow, adjust: the colour grade, decor: the scattered decoration) to find what a biome's
## frame costs.
var _off: PackedStringArray = []
var _view: WorldViewRoot
var _reader: WorldReader
var _spots: Array = []
var _spot := -1
var _wait := 0
var _left := 0
var _last_us := 0
var _last_cpu := -1.0
var _cpu := false
var _rows := {}
var _report: PackedStringArray = []
var _guard := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("biome="):
			_biome_id = StringName(a.trim_prefix("biome="))
		elif a.begins_with("seed="):
			_seed = int(a.trim_prefix("seed="))
		elif a.begins_with("floor="):
			_floor = int(a.trim_prefix("floor="))
		elif a.begins_with("frames="):
			_frames = int(a.trim_prefix("frames="))
		elif a.begins_with("settle="):
			_settle = int(a.trim_prefix("settle="))
		elif a.begins_with("spots="):
			_spots_max = int(a.trim_prefix("spots="))
		elif a.begins_with("tag="):
			_tag = a.trim_prefix("tag=")
		elif a.begins_with("off="):
			_off = a.trim_prefix("off=").split(",", false)
		elif a == "light_spot=1":
			_light_spot = true
		elif a == "cpu=1":
			_cpu = true
		elif a == "shot=1":
			_shot = true
		elif a.begins_with("lighting="):
			_lighting = a.trim_prefix("lighting=")
		elif a.begins_with("walls="):
			ViewPrefs.wall_style = StringName(a.trim_prefix("walls="))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", _biome_id)
	if biome == null:
		push_error("biome_probe: no biome %s" % _biome_id)
		quit(1)
		return
	var w := SaveLab.floor_world(_seed, _floor)
	IcePatches.place(w, BiomeCompiler.compile_surface(biome))  # as Main
	_reader = WorldReader.new(w)
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.stage.look = biome.look
	_view.stage.lighting = _lighting
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	var b := _reader.floor_bounds()
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	var t_setup := Time.get_ticks_usec()
	_view.setup(_reader, biome.palette, half + 4.0)
	var setup_ms := (Time.get_ticks_usec() - t_setup) / 1000.0
	_view.sync()
	if _cpu and _view.stage.kit != null:  # its frame work is called (and timed) by the probe
		_view.stage.kit.set_process(false)
	_apply_off()
	var start := _reader.floor_start_room()
	_spots.append(_reader.floor_room(start).get_center())
	for i in _reader.floor_room_count():
		if _spots.size() >= _spots_max:
			break
		if i != start:
			_spots.append(_reader.floor_room(i).get_center())
	if _light_spot and _view.stage.kit != null and not _view.stage.kit.lights.is_empty():
		var hero := _reader.player_pos()
		var best := Vector2.INF
		for l: OmniLight3D in _view.stage.kit.lights:
			var p := SimPlane.to_sim(l.position)
			if (p - hero).length() < (best - hero).length():
				best = p
		_spots.append(best.lerp(hero, 0.25))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var env := _view.stage.environment
	_line(
		(
			"biome_probe: biome=%s seed=%d floor=%d spots=%d frames=%d lighting=%s renderer=%s device=%s"
			% [
				_biome_id,
				_seed,
				_floor,
				_spots.size(),
				_frames,
				_lighting,
				ProjectSettings.get_setting("rendering/renderer/rendering_method"),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	_line(
		(
			"env: fog=%s fog_density=%.4f glow=%s glow_intensity=%.2f glow_bloom=%.2f ssao=%s ssil=%s"
			% [
				env.fog_enabled,
				env.fog_density,
				env.glow_enabled,
				env.glow_intensity,
				env.glow_bloom,
				env.ssao_enabled,
				env.ssil_enabled
			]
		)
	)
	var ws := _view.stage.structural_wall_stats()
	_line(
		(
			"walls: style=%s (pref %s) wall_meshes=%d wall_tris=%d proc_build_ms=%.1f build_ms=%.1f"
			% [
				_view.stage.wall_style,
				ViewPrefs.wall_style,
				ws["nodes"],
				ws["tris"],
				_view.stage.wall_build_ms,
				setup_ms
			]
		)
	)
	var lights := _lights(_view)
	var kit_lights := _view.stage.kit.lights.size() if _view.stage.kit != null else 0
	_line(
		(
			"scene: nodes=%d omni_lights=%d (kit fire lights %d) spot_lights=%d particles=%d"
			% [
				_count(_view, "Node"),
				lights.size(),
				kit_lights,
				_count(_view, "SpotLight3D"),
				_count(_view, "GPUParticles3D") + _count(_view, "CPUParticles3D")
			]
		)
	)


func _process(_delta: float) -> bool:
	_guard += 1
	if _view == null or _guard > 20000:
		quit(1)
		return false
	var now := Time.get_ticks_usec()
	if _left > 0:
		var vp := root.get_viewport_rid()
		if _shot and _left == _frames:
			_save_shot()
		_add("frame_ms", (now - _last_us) / 1000.0)
		if _cpu:
			_time_views()
		var cpu := _cpu_ms()
		_add("cpu_ms", cpu - _last_cpu if cpu >= 0.0 and _last_cpu >= 0.0 else -1.0)
		_add("render_cpu", RenderingServer.viewport_get_measured_render_time_cpu(vp))
		_add("render_gpu", RenderingServer.viewport_get_measured_render_time_gpu(vp))
		_add(
			"draws",
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			)
		)
		_add(
			"objects",
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME
			)
		)
		_add(
			"prims",
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
			)
		)
		var lights := _lights(_view)
		var shadow := 0
		var lit := 0
		for l: OmniLight3D in lights:
			if l.shadow_enabled and l.is_visible_in_tree():
				shadow += 1
			if l.is_visible_in_tree() and l.light_energy > 0.0:
				lit += 1
		_add("omni_all", lights.size())
		_add("omni_shadow", shadow)
		_add("omni_visible", lit)
		_left -= 1
	elif _wait > 0:
		_wait -= 1
		if _wait == 0:
			_left = _frames
	else:
		_spot += 1
		if _spot >= _spots.size():
			_finish()
			return false
		_view.rig.view_size = 17.0  # IsoRig's default: the game's own view
		_view.rig.snap_to(SimPlane.to_3d(_spots[_spot]))
		_wait = _settle
	_last_us = now
	_last_cpu = _cpu_ms()
	return false


## cpu=1: the views' tick work and StageKit's frame work, timed (CPU only).
func _time_views() -> void:
	var t0 := Time.get_ticks_usec()
	_view.sync()
	var t1 := Time.get_ticks_usec()
	if _view.stage.kit != null:
		_view.stage.kit.call(&"_process", 1.0 / 60.0)
	_add("sync_ms", (t1 - t0) / 1000.0)
	_add("kit_ms", (Time.get_ticks_usec() - t1) / 1000.0)
	var vfx := _view.attack_forms.vfx
	_add("sprites", vfx.sprites_asked if vfx != null else 0)


func _apply_off() -> void:
	var env := _view.stage.environment
	for o in _off:
		match o:
			"fog":
				env.fog_enabled = false
			"glow":
				env.glow_enabled = false
			"ssao":
				env.ssao_enabled = false
			"ssil":
				env.ssil_enabled = false
			"adjust":
				env.adjustment_enabled = false
			"kit_shadows":
				if _view.stage.kit != null:
					_view.stage.kit.set_shadows(false)
			"sun_shadow":
				_view.stage.sun.shadow_enabled = false
			"decor":  # the kit's scattered decoration (StageKit's Decor_ nodes)
				if _view.stage.kit != null:
					for c in _view.stage.kit.get_children():
						if String(c.name).begins_with("Decor_"):
							(c as Node3D).visible = false
	if not _off.is_empty():
		_line("off: " + ",".join(_off))


func _save_shot() -> void:
	var dir := OUT_DIR + "/shots/%s" % (_tag if _tag != "" else "untagged")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var img := root.get_texture().get_image()
	var path := dir + "/%s_%d.png" % [_biome_id, _spot]
	if img == null or img.save_png(path) != OK:
		push_error("biome_probe: could not save %s" % path)
	else:
		_line("shot: " + path)


## The process's user + system CPU time so far (ms), every thread; -1 without /proc.
static func _cpu_ms() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if f == null:
		return -1.0
	var line := f.get_line()  # /proc files report no length: read the line
	var fields := line.substr(line.rfind(")") + 2).split(" ")
	if fields.size() < 13:
		return -1.0
	return (float(fields[11]) + float(fields[12])) * 10.0  # utime, stime in 100 Hz clock ticks


static func _lights(n: Node) -> Array:
	var out: Array = []
	_collect(n, out)
	return out


static func _collect(n: Node, out: Array) -> void:
	if n is OmniLight3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


static func _count(n: Node, cls: String) -> int:
	var k := 1 if n.is_class(cls) else 0
	for c in n.get_children():
		k += _count(c, cls)
	return k


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var name := "biome_probe_%s%s.txt" % [_biome_id, "_" + _tag if _tag != "" else ""]
	var f := FileAccess.open(OUT_DIR + "/" + name, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_report) + "\n")
	_view.queue_free()
	_view = null
	quit(0)


func _line(s: String) -> void:
	print(s)
	_report.append(s)
