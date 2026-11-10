extends SceneTree
## v0.9.5 PF1: the frame-time profiler for the PF target ("a steady 144 fps ... every frame under 6.9 ms, judged on
## the 1 % lows"). Boots the real game (main.tscn), opens the Playground (the real room, the real views, the real
## sim) with the Gun, a fixed multi-hit two-element build and 20 live enemies round the hero, then holds fire and
## strafes in a scripted pattern for SECS seconds after WARM seconds of warm-up. Per biome it times every rendered
## frame (Time.get_ticks_usec between two _process calls: CPU + GPU + the present, vsync off, no fps cap) and
## writes a plain text report to build/perf/<sha>_<biome>[_ab-<flags>].txt (never into docs) and prints it.
## Needs a renderer (NOT --headless), 1920x1080 windowed. Use a temp APPDATA so the owner's settings are never touched
## (the probe uses an in-memory profile anyway, and restores vsync / fps cap / shadow settings before it quits):
##   APPDATA=$TEMP/zd-frame godot --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd
##   ... -s scripts/checks/frame_probe.gd -- --biome=frozen_shore [--secs=30] [--warm=3] [--ab=shadows_low,no_ssil]
## --biome=<id[,id]>  default frozen_shore,red_canyon (any id of data/biomes).
## --ab=<flags>       toggles a suspected cost off for an A/B run, no code edits:
##   shadows_low      directional shadow atlas 2048, soft-shadow filter quality 1 (the project: 4096, quality 4)
##   no_ssil          the stage's screen-space indirect lighting off
##   fx_half          per-hit attack effects at the Options "Medium" density (the existing knob; "high" is the default)
##   fx_low           the same at "Low"
##   no_burn_fx       v0.9.5 PF: burning enemies keep no orange tint and no embers
##   no_rig_merge     v0.9.5 PF5: the enemies' pieces as separate meshes (RigMerge off), to compare the merged rigs
##   wildfire         v0.10.0 VX0: also grants Wildfire (a burning kill spreads fire: the fire bursts judged here)
##   no_pack_fx       v0.10.0 VX0: the fire explosion draws as sprites (the pack's PackFx off), the "before" of VX0
##   no_anim          v0.10.5 Q5: every AnimationMixer under the view inactive (re-applied once a second, so new
##                    enemies too): what the AnimationPlayers cost the frame (the models stop animating)
##   low_hp           v0.10.5 W3-O6: the hero held at 20 % HP (god mode keeps them alive), so the low-HP screen-edge
##                    warning (LowHpVignette) and the HP bar's red pulse stay on: the border's cost against a run
##                    without the flag
##   planar_floor     NOT AVAILABLE: every biome's ground is world-triplanar (StageView._ground_material) and there
##                    is no planar path to switch to; the report says whether the floor is triplanar.
## The scenario: PlaygroundScenario's fixed room (seed 4404), 20 live enemies topped up each second at 7-12 m round the
## hero (the hero can't die), Glaive + Ring + Split Shot + Ember Core + Storm Core at level 3, the right mouse held,
## the aim sweeping a circle, the hero strafing left/right/up/down in 2 s legs.
## v0.10.5 O12 (owner P9, the effect budget): --enemies=N keeps N live enemies (default ENEMIES); --heavy also grants
## HEAVY_KEYS at level 5 (Twin, Halo, Rapid Fire, Wildfire, Chain Blast, the rune explosion: the most effects a frame);
## v0.10.5 W3-V1 (the enemy VAT pilot): --only=<kind> (an ActorStore.Kind name, e.g. swarmer) makes every live enemy
## that kind; --enemy-vat=on|off sets ViewPrefs.enemy_vat (VatCrowd draws the VatCrowd.KINDS enemies):
##   ... -s scripts/checks/frame_probe.gd -- --biome=red_canyon --enemies=60 --only=swarmer --enemy-vat=on
## --fx counts, per measured frame, the hero's effect instances (the forms' meshes and particles, the effects layer's
## sprites, the hero's share of them when the layer keeps a hero budget, the pack's live instances by family) and the
## hostile threats on screen (telegraphs, enemy shots) and the hero effects' opacity, and reports avg / p95 / max.
##   ... -s scripts/checks/frame_probe.gd -- --biome=red_canyon --enemies=60 --heavy --fx --secs=20
## --spans, --redraws, --orphans, --size=WxH, --vsync=<mode> and the extra --ab switches: scripts/checks/frame_spans.gd.

const FrameSpans := preload("res://scripts/checks/frame_spans.gd")
const OUT_DIR := "res://build/perf/"
const DEFAULT_BIOMES := ["frozen_shore", "red_canyon"]
const BUDGET_MS := 1000.0 / 144.0
const ENEMIES := 20
## [name_key] of the cards granted at level 3: Gun forms and two elements (fire and lightning).
const BUILD_KEYS: Array[StringName] = [
	&"ITEM_GUN_GLAIVE",
	&"ITEM_GUN_RING",
	&"ITEM_SPLIT_SHOT",
	&"ITEM_EMBER_CORE",
	&"ITEM_STORM_CORE",
]
## v0.10.5 O12: the extra cards of --heavy, at HEAVY_LEVEL.
const HEAVY_KEYS: Array[StringName] = [
	&"ITEM_GUN_TWIN",
	&"ITEM_HALO_SHOT",
	&"ITEM_GUN_RAPID_FIRE",
	&"ITEM_WILDFIRE",
	&"ITEM_CHAIN_BLAST",
	&"ITEM_GUN_RUNE_EXPLOSION",
]
const HEAVY_LEVEL := 5
## v0.10.5 O12: the pack families the hero's own effects use (enemy_shot is the hostile one).
const HERO_PACK_FAMILIES: Array[StringName] = [
	&"hit",
	&"impact",
	&"explosion",
	&"area",
	&"beam",
	&"projectile",
	&"status",
	&"bolt",
	&"trail",
	&"mark"
]
const KNOWN_AB := [
	"wildfire",
	"no_pack_fx",
	"no_interp",
	"shadows_low",
	"no_ssil",
	"fx_half",
	"fx_low",
	"planar_floor",
	"no_rig_merge",
	"no_burn_fx",
	"no_anim",
	"low_hp"
]
## The strafe legs (move_left / move_right / move_up / move_down), each held STRAFE_S seconds.
const STRAFE: Array[StringName] = [&"move_left", &"move_up", &"move_right", &"move_down"]
const STRAFE_S := 2.0

var _biomes: Array = []
var _secs := 30.0
var _warm := 3.0
var _ab: PackedStringArray = []
## The sim's native kernels asked for with --native=move,ai,... (NativeSwitch bits; 0: the script paths).
var _native := 0
var _shadows := ""  # --enemy-shadows=proxy|blob (v0.10.5 PA)
var _vat := ""  # --enemy-vat=on|off (v0.10.5 W3-V1)
var _only := -1  # --only=<kind name> (v0.10.5 W3-V1): ActorStore.Kind, -1 the Playground's whole list
var _main: Main
var _bi := -1
var _phase := &"boot"
var _frame := 0
var _t0 := 0
var _last_us := 0
var _next_sample_us := 0
var _frames := PackedFloat64Array()
var _cpu := 0.0
var _gpu := 0.0
var _rs_n := 0
var _samples: Array = []
var _held := ""
var _out: PackedStringArray = []
var _build_names: PackedStringArray = []
var _saved_atlas := 4096
var _saved_filter := 4
var _saved_density := "high"
var _floor_triplanar := "unknown"
var _sha := "nosha"
var _api: PlaygroundApi
var _bd := false  # --breakdown
var _census := false  # --census
var _shot := ""  # --shot=<png path>: the viewport 0.5 s before the end (PF4)
var _boss := -1  # --boss=<table index>: one boss instead of the 20 enemies (PF4)
var _boss_placed := false
var _timers: Array = []
var _t_proc := 0
var _t_pre := 0
var _t_post := 0
var _proc := false  # --process
var _has_process := {}
var _stolen := {}
var _proc_total_nodes := 0
var _bk := {}  # bucket -> per-measured-frame microseconds
var _phase_timer := PerfBreakdown.PhaseTimer.new()
var _enemies := ENEMIES  # --enemies=N (O12)
var _heavy := false  # --heavy (O12)
var _fx := false  # --fx (O12)
var _fx_rows := {}  # counter name -> PackedFloat64Array, one value per measured frame
var _spans := FrameSpans.new()


func _initialize() -> void:
	var biome_arg := ",".join(DEFAULT_BIOMES)
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("biome="):
			biome_arg = s.trim_prefix("biome=")
		elif s.begins_with("secs="):
			_secs = float(s.trim_prefix("secs="))
		elif s.begins_with("warm="):
			_warm = float(s.trim_prefix("warm="))
		elif s == "breakdown":
			_bd = true
		elif s.begins_with("shot="):
			_shot = s.trim_prefix("shot=")
		elif s.begins_with("boss="):
			_boss = int(s.trim_prefix("boss="))
		elif s == "census":
			_census = true
		elif s.begins_with("enemies="):
			_enemies = int(s.trim_prefix("enemies="))
		elif s == "heavy":
			_heavy = true
		elif s == "fx":
			_fx = true
		elif s == "process":
			_bd = true
			_proc = true
		elif s.begins_with("enemy-shadows="):  # v0.10.5 PA: "proxy" or "blob"
			_shadows = s.trim_prefix("enemy-shadows=")
		elif s.begins_with("enemy-vat="):  # v0.10.5 W3-V1
			_vat = s.trim_prefix("enemy-vat=")
		elif s.begins_with("only="):  # v0.10.5 W3-V1
			_only = ActorStore.Kind.keys().find(s.trim_prefix("only=").to_upper())
		elif s.begins_with("native="):
			_native = maxi(0, NativeSwitch.parse(s.trim_prefix("native=")))
		elif s.begins_with("ab="):
			_ab = s.trim_prefix("ab=").split(",", false)
		else:
			_spans.parse(s)
	_biomes = Array(biome_arg.split(",", false))
	if _native != 0 and NativeSwitch.install(_native) != _native:
		push_error("frame_probe: the native library is not built (bash scripts/native/build.sh)")
	print("native kernels: %d" % (World.native_kernels))
	var git: Array = []
	if OS.execute("git", ["rev-parse", "--short", "HEAD"], git) == 0 and git.size() > 0:
		_sha = String(git[0]).strip_edges()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_saved_density = ViewPrefs.effects_density
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(_spans.size)
	root.size = _spans.size
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "en"
	if not _shadows.is_empty():
		profile.section("settings")["enemy_shadows"] = _shadows
	if not _vat.is_empty():
		profile.section("settings")["enemy_vat"] = _vat
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_frame += 1
	var now := Time.get_ticks_usec()
	match _phase:
		&"boot":
			if _frame == 5:
				_next_biome()
		&"settle":  # a few frames for the room's views before the scenario
			if _frame >= 10:
				_setup_scenario()
		&"warm":
			_drive(now)
			if _proc:
				_steal_and_time(delta)
			if (now - _t0) >= int(_warm * 1e6):
				_begin_measure(now)
		&"measure":
			_drive(now)
			if _proc:
				_steal_and_time(delta)
			var dt_ms := (now - _last_us) / 1000.0
			if _bd or _spans.on or _spans.redraws:
				_collect(now)
			_frames.append(dt_ms)
			if _fx:
				_count_fx()
			var vp := root.get_viewport_rid()
			_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			_rs_n += 1
			if now >= _next_sample_us:
				_next_sample_us = now + 1000000
				_samples.append(_sample())
			if not _shot.is_empty() and (now - _t0) >= int((_secs - 0.5) * 1e6):
				var img := root.get_texture().get_image()
				DirAccess.make_dir_recursive_absolute(_shot.get_base_dir())
				img.save_png(_shot)
				var w := _main.driver.world
				for i in w.actors.ids.size():
					if BossAi.is_boss_kind(w.actors.kinds[i]) and w.actors.dead[i] == 0:
						var cam: Camera3D = _main.view.rig.camera
						print(
							"shot: boss at sim ",
							w.actors.pos(i),
							" on screen ",
							cam.unproject_position(SimPlane.to_3d(w.actors.pos(i))),
							" hero ",
							w.player_pos()
						)
				_shot = ""
			if (now - _t0) >= int(_secs * 1e6):
				_finish_biome()
	_last_us = now
	return false


func _next_biome() -> void:
	_bi += 1
	if _bi >= _biomes.size():
		_restore()
		quit(0)
		return
	_main._start_playground(&"gun", StringName(_biomes[_bi]))
	_phase = &"settle"
	_frame = 0


## The build, the god mode, the A/B flags, the vsync-off / no-cap setting, and the first enemies.
func _setup_scenario() -> void:
	_api = _main.playground.api
	_api.god = true
	_build_names.clear()
	var found := {}
	for e: Dictionary in _api.catalog():
		if BUILD_KEYS.has(e["name_key"]):
			_api.grant_now(e["code"], 3)
			found[e["name_key"]] = true
	if _heavy:
		for e: Dictionary in _api.catalog():
			if HEAVY_KEYS.has(e["name_key"]):
				_api.grant_now(e["code"], HEAVY_LEVEL)
				found[e["name_key"]] = true
	var keys: Array[StringName] = BUILD_KEYS.duplicate()
	if _heavy:
		keys.append_array(HEAVY_KEYS)
	for k in keys:
		_build_names.append("%s%s" % [k, "" if found.has(k) else " (MISSING from the catalog)"])
	_saved_atlas = int(
		ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)
	)
	_saved_filter = int(
		ProjectSettings.get_setting(
			"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 4
		)
	)
	if _bd:
		PerfMarks.on = true
		RenderingServer.frame_pre_draw.connect(func() -> void: _t_pre = Time.get_ticks_usec())
		RenderingServer.frame_post_draw.connect(func() -> void: _t_post = Time.get_ticks_usec())
		_main.view.profile_sync = true
		_main.driver.world.phase_probe = _phase_timer
		_time_listeners()
	_apply_ab()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_spans.setup(self, _main, _ab)
	_floor_triplanar = _triplanar_state()
	_top_up()
	_t0 = Time.get_ticks_usec()
	_phase = &"warm"
	_frames.clear()
	_samples.clear()
	_cpu = 0.0
	_gpu = 0.0
	_rs_n = 0
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	_press_fire(true)


func _begin_measure(now: int) -> void:
	_phase = &"measure"
	_t0 = now
	_next_sample_us = now
	_last_us = now
	_frames.clear()
	_cpu = 0.0
	_gpu = 0.0
	_rs_n = 0
	_bk.clear()
	_fx_rows.clear()
	PerfMarks.clear()
	_phase_timer.reset()
	_main.view.sync_profile.clear()
	_spans.begin_measure()


## Strafe, aim and refill the enemies, once per frame (cheap: the refill runs once a second).
func _drive(now: int) -> void:
	var t := (now - _t0) / 1e6
	_spans.per_frame()
	if _ab.has("low_hp"):  # W3-O6: the probe (not the sim) holds the hero's HP at 20 %
		var a := _main.driver.world.actors
		a.hp[0] = maxi(1, a.max_hp[0] / 5)
	if _boss >= 0:  # PF4: the boss shot: stand still, the boss stays in view
		_aim(Vector2(1400, 500))
		return
	var leg := STRAFE[int(t / STRAFE_S) % STRAFE.size()]
	if String(leg) != _held:
		if _held != "":
			Input.action_release(StringName(_held))
		_held = String(leg)
		Input.action_press(leg)
	var a := t * 1.2
	var c := Vector2(960, 540) + Vector2(cos(a), sin(a)) * 320.0
	_aim(c)
	if int(t) != int(t - 0.016):
		_top_up()
		if _ab.has("no_anim"):
			_stop_mixers()


## v0.10.5 Q5 (--ab=no_anim): every AnimationMixer under the view stops processing.
func _stop_mixers() -> void:
	var stack: Array[Node] = [_main.view]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is AnimationMixer:
			(n as AnimationMixer).active = false


func _aim(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func _press_fire(on: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = on
	ev.position = Vector2(960, 540)
	ev.global_position = ev.position
	Input.parse_input_event(ev)


## Keeps ENEMIES live enemies round the hero, 7-12 m out, kinds cycling through the Playground's list.
func _top_up() -> void:
	var w := _main.driver.world
	var alive := 0
	var a := w.actors
	for i in a.ids.size():
		if a.teams[i] == ActorStore.TEAM_ENEMY and a.dead[i] == 0 and a.hp[i] > 0:
			alive += 1
	var p := w.player_pos()
	if _boss >= 0:
		if not _boss_placed:
			_boss_placed = _api.place_boss_now(_boss, p + Vector2(5.0, -2.0))
		return
	var kinds := _api.enemy_choices()
	if kinds.is_empty():
		return
	var tries := 0
	while alive < _enemies and tries < maxi(80, _enemies * 3):
		tries += 1
		var ang := float(tries * 137) * 0.0174533 + float(w.tick) * 0.01
		var dist := 7.0 + float((tries * 53) % 6)
		var kind: int = kinds[(tries + alive) % kinds.size()]["kind"] if _only < 0 else _only
		if _api.place_enemy_now(kind, p + Vector2(cos(ang), sin(ang)) * dist):
			alive += 1


func _sample() -> Array:
	var particles := 0
	var emitting := 0
	var stack: Array[Node] = [_main.view]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is GPUParticles3D:
			particles += 1
			emitting += int((n as GPUParticles3D).emitting)
		elif n is CPUParticles3D:
			particles += 1
			emitting += int((n as CPUParticles3D).emitting)
	return [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		particles,
		emitting,
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	]


## v0.10.5 W3-V1: the VAT switch, the one kind (if any) and how many bodies the VAT crowd drew on the last frame.
func _vat_line() -> String:
	var crowd := _main.view.actors.vat_crowd
	return (
		"enemy_vat: %s  only: %s  vat_bodies_last_frame: %d"
		% [
			"on" if ViewPrefs.enemy_vat else "off",
			"all" if _only < 0 else String(ActorStore.Kind.keys()[_only]).to_lower(),
			crowd.drawn if crowd != null else 0,
		]
	)


func _apply_ab() -> void:
	for f in _ab:
		match f:
			"shadows_low":
				RenderingServer.directional_shadow_atlas_set_size(2048, true)
				RenderingServer.directional_soft_shadow_filter_set_quality(1)
			"no_ssil":
				_main.view.stage.environment.ssil_enabled = false
			"no_burn_fx":  # v0.9.5 PF: the burn tint and embers off (owner: do they cost much?)
				ItemVisuals.burn_tint = false
				StatusVisuals.burn_embers = false
			"no_rig_merge":  # v0.9.5 PF5: enemy rigs as built, one node per piece (enemies spawned after this)
				RigMerge.enabled = false
			"no_interp":
				root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			"fx_half":
				ViewPrefs.effects_density = "medium"
			"fx_low":
				ViewPrefs.effects_density = "low"
			"wildfire":  # v0.10.0 VX0
				for e: Dictionary in _api.catalog():
					if e["name_key"] == &"ITEM_WILDFIRE":
						_api.grant_now(e["code"], 3)
			"no_pack_fx":  # v0.10.0 VX0
				_main.view.attack_forms.vfx.pack_fx = null


func _triplanar_state() -> String:
	var m: StandardMaterial3D = _main.view.stage._ground_material()
	if m == null:
		return "the stage builds no kit ground material"
	return (
		"kit ground uv1_triplanar=%s uv1_world_triplanar=%s"
		% [m.uv1_triplanar, m.uv1_world_triplanar]
	)


func _finish_biome() -> void:
	_press_fire(false)
	if _held != "":
		Input.action_release(StringName(_held))
		_held = ""
	var biome := String(_biomes[_bi])
	var sorted := _frames.duplicate()
	sorted.sort()
	var n := sorted.size()
	var sum := 0.0
	var over := 0
	for v in sorted:
		sum += v
		if v > BUDGET_MS:
			over += 1
	var worst_n := maxi(1, int(ceil(n * 0.01)))
	var worst := 0.0
	for k in worst_n:
		worst += sorted[n - 1 - k]
	var low_fps := 1000.0 / (worst / worst_n) if n > 0 else 0.0
	var lines: PackedStringArray = []
	lines.append(
		(
			"frame_probe  sha=%s  biome=%s  ab=%s"
			% [_sha, biome, ",".join(_ab) if not _ab.is_empty() else "none"]
		)
	)
	(
		lines
		. append(
			(
				(
					"machine: renderer=%s adapter=%s window=%s  (the report does not know whether other processes were busy: "
					+ "name the machine and check the CPU was idle before quoting it as evidence)"
				)
				% [
					RenderingServer.get_current_rendering_method(),
					RenderingServer.get_video_adapter_name(),
					root.size
				]
			)
		)
	)
	(
		lines
		. append(
			(
				"scenario: Playground room seed 4404, Gun, %d live enemies, warm-up %.1f s, measured %.1f s"
				% [_enemies, _warm, _secs]
			)
		)
	)
	lines.append(
		(
			"build: "
			+ ", ".join(_build_names)
			+ " at level 3 (Glaive, Ring, Split, fire core, lightning core)"
			+ (" + the --heavy cards at level %d" % HEAVY_LEVEL if _heavy else "")
		)
	)
	lines.append(
		"floor: " + _floor_triplanar + " (no planar path exists: planar_floor NOT AVAILABLE)"
	)
	lines.append("flags: " + _ab_status())
	lines.append("enemy_shadows: " + ViewPrefs.enemy_shadows)  # v0.10.5 PA
	lines.append(_vat_line())  # v0.10.5 W3-V1
	lines.append(
		(
			"frames=%d  avg_ms=%.3f  p50_ms=%.3f  p95_ms=%.3f  p99_ms=%.3f"
			% [n, sum / maxf(n, 1), _pct(sorted, 0.50), _pct(sorted, 0.95), _pct(sorted, 0.99)]
		)
	)
	(
		lines
		. append(
			(
				"1pct_low_fps=%.1f (1000 / mean of the slowest %d frames)  max_ms=%.3f  over_%.2fms=%d (%.2f %%)  avg_fps=%.1f"
				% [
					low_fps,
					worst_n,
					sorted[n - 1] if n > 0 else 0.0,
					BUDGET_MS,
					over,
					100.0 * over / maxf(n, 1),
					1000.0 / (sum / maxf(n, 1))
				]
			)
		)
	)
	(
		lines
		. append(
			(
				"render_cpu_ms_avg=%.3f  render_gpu_ms_avg=%.3f  (RenderingServer viewport measured time)"
				% [_cpu / maxf(_rs_n, 1), _gpu / maxf(_rs_n, 1)]
			)
		)
	)
	var pack: PackFx = _main.view.pack_fx  # v0.10.0 VX0
	if pack != null:
		lines.append(
			(
				"pack_fx: spawned=%d reused=%d (whole run, warm-up included)"
				% [pack.spawned, pack.reused]
			)
		)
	(
		lines
		. append(
			(
				"per-second samples: draw_calls, live_objects (every Object in memory, not what is drawn), primitives, "
				+ "video_mem_MB, nodes, resources, orphans, particle_nodes, emitting, drawn_objects (all passes)"
			)
		)
	)
	for s: Array in _samples:
		lines.append(
			(
				"  %d, %d, %d, %.0f, %d, %d, %d, %d, %d, %d"
				% [s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8], s[9]]
			)
		)
	if _fx:
		lines.append_array(_fx_lines())
	if _census:
		lines.append_array(_census_lines())
	if _bd:
		lines.append_array(_class_histogram())
	if _bd or _spans.on or _spans.redraws:
		lines.append_array(_breakdown_lines())
	lines.append_array(_spans.report_lines(_bk))
	var text := "\n".join(lines) + "\n"
	print(text)
	var tag := "" if _ab.is_empty() else "_ab-" + "-".join(_ab)
	if _heavy or _enemies != ENEMIES:
		tag += "_heavy%d" % _enemies
	if _only >= 0:  # v0.10.5 W3-V1
		tag += "_only-" + String(ActorStore.Kind.keys()[_only]).to_lower()
	if not _vat.is_empty():
		tag += "_vat-" + _vat
	var f := FileAccess.open(
		ProjectSettings.globalize_path(OUT_DIR + "%s_%s%s.txt" % [_sha, biome, tag]),
		FileAccess.WRITE
	)
	if f != null:
		f.store_string(text)
		f.close()
	_phase = &"between"
	_frame = 0
	_next_biome()


func _ab_status() -> String:
	if _ab.is_empty():
		return "none"
	var out: PackedStringArray = []
	for f in _ab:
		if f == "planar_floor" or not (KNOWN_AB.has(f) or FrameSpans.AB.has(f)):
			out.append("%s=NOT AVAILABLE" % f)
		else:
			out.append("%s=on" % f)
	return ", ".join(out)


## v0.10.5 O12 (--fx): the effect instances drawn this frame, one value per counter.
func _count_fx() -> void:
	var v: WorldViewRoot = _main.view
	var forms: AttackFormCanvas = v.attack_forms
	_fx_add("forms_meshes", forms.meshes_drawn())
	_fx_add("forms_particles", forms.particles_drawn())
	var layer: VfxLayer = forms.vfx
	if layer != null:
		var n := 0
		for id: StringName in layer.pools:
			n += layer.used(id)
		_fx_add("layer_sprites_all", n)
		if &"hero_budget" in layer and layer.get(&"hero_budget") != null:
			var b: Object = layer.get(&"hero_budget")
			_fx_add("hero_sprites_drawn", b.get(&"used"))
			_fx_add("hero_sprites_dimmed", b.get(&"dimmed"))
			_fx_add("hero_sprites_skipped", b.get(&"skipped"))
			_fx_add("hero_alpha_x100", float(b.get(&"alpha")) * 100.0)
			_fx_add("hostile_threats", b.get(&"threats"))
	var pack: PackFx = v.pack_fx
	if pack != null:
		var hero := 0
		for fam in HERO_PACK_FAMILIES:
			hero += pack.live_count(fam)
		_fx_add("pack_hero_live", hero)
		for fam in HERO_PACK_FAMILIES:
			_fx_add("pack_%s" % fam, pack.live_count(fam))
		_fx_add("pack_enemy_shot_live", pack.live_count(&"enemy_shot"))
	_fx_add("telegraphs_drawn", v.telegraphs.count())


func _fx_add(key: String, value: float) -> void:
	var rows: PackedFloat64Array = _fx_rows.get(key, PackedFloat64Array())
	rows.append(value)
	_fx_rows[key] = rows  # a packed array is a value: store it back


func _fx_lines() -> PackedStringArray:
	var out: PackedStringArray = ["fx counts per measured frame (avg / p50 / p95 / max):"]
	for key: String in _fx_rows:
		var rows: PackedFloat64Array = (_fx_rows[key] as PackedFloat64Array).duplicate()
		rows.sort()
		var sum := 0.0
		for x in rows:
			sum += x
		out.append(
			(
				"  %s: %.1f / %.0f / %.0f / %.0f"
				% [
					key,
					sum / maxf(rows.size(), 1),
					_pct(rows, 0.5),
					_pct(rows, 0.95),
					rows[rows.size() - 1] if rows.size() > 0 else 0.0
				]
			)
		)
	return out


static func _pct(sorted: PackedFloat64Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(ceil(q * sorted.size())) - 1, 0, sorted.size() - 1)]


func _restore() -> void:
	_spans.restore()
	RenderingServer.directional_shadow_atlas_set_size(_saved_atlas, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(_saved_filter)
	ViewPrefs.effects_density = _saved_density
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)


# --- PF2: --breakdown (the shared parts: PerfBreakdown) ----------------------------------------------------------
## Moves this frame's marks (PerfMarks, each view's sync, the sim's phases) into the per-frame series, then clears them.
func _collect(now: int) -> void:
	var n := _frames.size()
	var this := {}
	if _t_post >= _t_pre and _t_pre >= _t_proc and _t_proc > 0:
		var phys := int(PerfMarks.us.get(&"step_once", 0))
		this["frame.scene_process"] = float(_t_pre - _t_proc)
		this["frame.draw_pre_to_post"] = float(_t_post - _t_pre)
		this["frame.rest_after_draw"] = float(now - _t_post - phys)
	_t_proc = now
	PerfBreakdown.gather(_main.view, _phase_timer, this)
	_spans.gather(_last_us, now, this)
	this["count.projectiles"] = float(_main.driver.reader.projectile_count())
	this["count.actors"] = float(_main.driver.reader.actor_count())
	this["ticks"] = float(PerfMarks.calls.get(&"sim_step", 0))
	this["engine.process"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1e6
	this["engine.physics_process"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1e6
	this["frame_total"] = (Time.get_ticks_usec() - _last_us) * 1.0
	for k: String in this:
		if not _bk.has(k):
			var z := PackedFloat64Array()
			z.resize(n)
			_bk[k] = z
		var a: PackedFloat64Array = _bk[k]
		a.append(this[k])
		_bk[k] = a
	for k: String in _bk:
		if not this.has(k):
			var b: PackedFloat64Array = _bk[k]
			b.append(0.0)
			_bk[k] = b
	PerfBreakdown.clear(_main.view, _phase_timer)


## One row per bucket: mean over all frames, mean over the frames it ran in, p99 over all frames (microseconds).
func _breakdown_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	(
		out
		. append(
			"breakdown (us per frame; main-thread script time; 'ran' = mean over frames the bucket was entered):"
		)
	)
	if _proc:
		out.append(
			(
				"  (--process: %d script nodes with a _process, timed from the probe)"
				% _proc_total_nodes
			)
		)
	out.append("  %-28s %9s %9s %9s %9s" % ["bucket", "mean", "p99", "ran_mean", "ran_frames"])
	var keys: Array = _bk.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _mean(_bk[a]) > _mean(_bk[b]))
	for k: String in keys:
		var s: PackedFloat64Array = _bk[k]
		var ran := 0
		var sum := 0.0
		for v in s:
			if v > 0.0:
				ran += 1
				sum += v
		var sorted := s.duplicate()
		sorted.sort()
		out.append(
			(
				"  %-28s %9.0f %9.0f %9.0f %9d"
				% [k, _mean(s), _pct(sorted, 0.99), sum / maxf(ran, 1), ran]
			)
		)
	return out


static func _mean(s: PackedFloat64Array) -> float:
	var t := 0.0
	for v in s:
		t += v
	return t / maxf(s.size(), 1)


# --- PF2: --process ------------------------------------------------------------------------------------------------
## Splits the scene tree's own _process time by script: every processing node is taken off the engine's process list
## and its _process is called from here, timed, in tree order (the probe's _process runs before the nodes'). Nodes the
## game switches off by set_process(false) (off-screen enemy models) are still called, so those are overstated.
func _steal_and_time(delta: float) -> void:
	var t_all := Time.get_ticks_usec()
	var stack: Array[Node] = [root]
	var order: Array[Node] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == self or n is SimDriver:
			continue
		var kids := n.get_children()
		for k in range(kids.size() - 1, -1, -1):
			stack.append(kids[k])
		var sc: Script = n.get_script()
		if sc == null or n.is_queued_for_deletion():
			continue
		if not _has_process.has(sc):
			_has_process[sc] = n.has_method(&"_process")
		if not _has_process[sc]:
			continue
		if n.is_processing():
			n.set_process(false)
			_stolen[n.get_instance_id()] = true
		if _stolen.has(n.get_instance_id()):
			order.append(n)
	var per := {}
	for n in order:
		var t0 := Time.get_ticks_usec()
		n.call(&"_process", delta)
		var key := String((n.get_script() as Script).resource_path.get_file())
		per[key] = int(per.get(key, 0)) + Time.get_ticks_usec() - t0
		per["calls " + key] = int(per.get("calls " + key, 0)) + 1
	for k: String in per:
		if not k.begins_with("calls "):
			PerfMarks.us[StringName("script." + k)] = per[k]
			PerfMarks.calls[StringName("script." + k)] = per["calls " + k]
	_proc_total_nodes = order.size()
	PerfMarks.us[&"probe.steal_total"] = Time.get_ticks_usec() - t_all


## The tree's node classes, most numerous first (--breakdown), and how many of them move per frame by the engine.
func _class_histogram() -> PackedStringArray:
	var counts := {}
	var visible_mi := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var c := n.get_class()
		counts[c] = int(counts.get(c, 0)) + 1
		if n is VisualInstance3D and (n as VisualInstance3D).is_visible_in_tree():
			visible_mi += 1
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var out: PackedStringArray = []
	var parts: PackedStringArray = []
	for k: String in keys.slice(0, 18):
		parts.append("%s=%d" % [k, counts[k]])
	out.append("node classes: " + ", ".join(parts) + "; visible VisualInstance3D=%d" % visible_mi)
	return out


## --breakdown: every SimDriver.ticked listener (view sync, audio, codex, HUD, ...) called through a timer, in the
## order it was connected; v0.10.5 Q5: and every SimDriver.frame_ticked listener (the views' once-a-frame sync), as
## "frame.<script>.<method>".
func _time_listeners() -> void:
	PerfBreakdown.time_listeners(_main.driver, _timers)


## --census (PF3): what the draw calls are. Every visible GeometryInstance3D, grouped by the script that owns it (the
## nearest ancestor with a script), by mesh and by material; a MultiMeshInstance3D counts as one draw per surface.
func _census_lines() -> PackedStringArray:
	var by_owner := {}
	var by_pair := {}
	var by_mesh := {}
	var by_detail := {}
	var total := 0
	var multi := 0
	var no_shadow := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is GeometryInstance3D) or not (n as GeometryInstance3D).is_visible_in_tree():
			continue
		var g := n as GeometryInstance3D
		total += 1
		if g is MultiMeshInstance3D:
			multi += 1
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			no_shadow += 1
		var o: Node = g
		while o != null and o.get_script() == null:
			o = o.get_parent()
		var owner_name := "(no script)"
		if o != null:
			owner_name = String(o.get_script().resource_path.get_file())
		by_owner[owner_name] = int(by_owner.get(owner_name, 0)) + 1
		var mesh: Mesh = null
		var mat: Material = g.material_override
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
			if mat == null and mesh != null and mesh.get_surface_count() > 0:
				mat = (g as MeshInstance3D).get_active_material(0)
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		var mk := "none" if mesh == null else str(mesh.get_instance_id())
		var pair := "%s|%s" % [mk, "none" if mat == null else str(mat.get_instance_id())]
		by_pair[pair] = int(by_pair.get(pair, 0)) + 1
		if not by_detail.has(owner_name):
			by_detail[owner_name] = {"meshes": {}, "pairs": {}, "casters": 0}
		var det: Dictionary = by_detail[owner_name]
		det["meshes"][mk] = true
		det["pairs"][pair] = true
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			det["casters"] = int(det["casters"]) + 1
		var mname := "none"
		if mesh != null:
			mname = mesh.resource_path if mesh.resource_path != "" else mesh.get_class() + "#" + mk
		by_mesh[mname] = int(by_mesh.get(mname, 0)) + 1
	var shared := 0
	var distinct_mats := {}
	for k: String in by_pair:
		if int(by_pair[k]) > 1:
			shared += int(by_pair[k])
		distinct_mats[k.get_slice("|", 1)] = true
	var out: PackedStringArray = []
	(
		out
		. append(
			(
				(
					"census: visible GeometryInstance3D=%d (MultiMesh %d, shadow off %d); distinct mesh+material pairs=%d; "
					+ "instances sharing a pair with another=%d; distinct materials=%d"
				)
				% [total, multi, no_shadow, by_pair.size(), shared, distinct_mats.size()]
			)
		)
	)
	for title: String in ["owner script", "mesh"]:
		var d: Dictionary = by_owner if title == "owner script" else by_mesh
		var keys: Array = d.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return d[a] > d[b])
		var parts: PackedStringArray = []
		for k: String in keys.slice(0, 25):
			parts.append("%s=%d" % [k, d[k]])
		out.append("census by %s: %s" % [title, ", ".join(parts)])
	var okeys: Array = by_owner.keys()
	okeys.sort_custom(func(a: String, b: String) -> bool: return by_owner[a] > by_owner[b])
	for k: String in okeys.slice(0, 30):
		var det: Dictionary = by_detail[k]
		(
			out
			. append(
				(
					"census owner %s: instances=%d distinct_meshes=%d distinct_mesh+material=%d shadow_casters=%d"
					% [k, by_owner[k], det["meshes"].size(), det["pairs"].size(), det["casters"]]
				)
			)
		)
	return out
