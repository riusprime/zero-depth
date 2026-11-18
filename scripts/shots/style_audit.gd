extends SceneTree
## Renders one boss's ordinary attacks for a style review, one still each at its most visible moment, in the real game
## view (WorldViewRoot and the HUD over JudgeLab's walled 24 m room, the iso camera at the game's own 17 m size) of a
## real World stepped a tick a frame, so the pack effects play out in their own time. The boss is hushed (it starts
## nothing on its own and stands still): each still starts one attack by hand (SHOT HELPER) on a fresh world. The
## boss's own fight mechanics (the Judge's time, the siege, the forge, the banner, the lattice) have their own scripts.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/style_audit.gd -- boss=siege_engine biome=night_rocks out=<folder> [sheet=<folder>]
## Writes <out>/<nn>_<label>.png (default build/style_audit/<boss>/) and, with `sheet`, 2 x 2 contact sheets at half
## size there; prints each path with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const SETTLE := 4
const HERO_AT := Vector2(-4.0, 2.5)
const BOSS_AT := Vector2(3.0, -1.5)
const LONG := 1 << 20
## Per boss: [label, attack id ("" for the boss standing), ticks after it starts, phase index, and optionally the
## ticks the hero walks a line before it starts (the echo replays the path it walked)].
const PLAN := {
	&"clockwork_judge":
	[
		["model", "", 30, 0],
		["the_echo", "the_echo", 70, 0, 200],
		["gear_spiral", "gear_spiral", 75, 0],
		["gear_spiral_3", "gear_spiral_3", 75, 2],
		["verdict_telegraph", "verdict", 80, 0],
		["verdict_strike", "verdict", 100, 0],
		["gavel_slam_telegraph", "gavel_slam", 34, 0],
		["gavel_slam_hit", "gavel_slam", 47, 0],
		["time_wave_cast", "time_wave", 70, 0],
	],
	&"siege_engine":
	[
		["model", "", 30, 0],
		["turret_cross", "turret_cross", 72, 0],
		["mortar_grid_telegraph", "mortar_grid", 80, 0],
		["mortar_grid_rocks", "mortar_grid", 150, 0],
		["barrage_telegraph", "barrage", 80, 0],
		["barrage_impact", "barrage", 100, 0],
		["rail_telegraph", "rail", 55, 0],
		["rail_fire", "rail", 72, 0],
		["deploy", "deploy", 80, 0],
		["lock_shell_lands", "@shell", 5, 1],
		["lock_boulder_risen", "@shell", 60, 1],
		["shockwave_telegraph", "shockwave", 100, 0],
		["shockwave_hit", "shockwave", 123, 0],
	],
	&"foundry":
	[
		["model", "", 30, 0],
		["slag_fountain", "slag_fountain", 85, 0],
		["furnace_waves", "furnace_waves", 75, 0],
		["molten_flood_telegraph", "molten_flood", 80, 0],
		["molten_flood_active", "molten_flood", 130, 0],
		["vent_blast_telegraph", "vent_blast", 30, 0],
		["vent_blast_hit", "vent_blast", 39, 0],
		["bomb_launch", "bomb_launch", 75, 0],
		["firestorm_telegraph", "firestorm", 80, 2],
		["firestorm_active", "firestorm", 120, 2],
		["meltdown_telegraph", "meltdown", 100, 2],
		["meltdown_active", "meltdown", 128, 2],
	],
	&"warlord":
	[
		["model", "", 30, 0],
		["shield_wall", "shield_wall", 70, 0],
		["javelin_fan", "javelin_fan", 60, 0],
		["great_javelin_telegraph", "great_javelin", 40, 0],
		["great_javelin_thrown", "great_javelin", 70, 0],
		["shield_bash", "shield_bash", 38, 0],
		["spear_lines_telegraph", "spear_lines", 80, 0],
		["spear_lines_active", "spear_lines", 110, 0],
		["lunge_dash_windup", "lunge_dash", 30, 0],
		["lunge_dash_burst", "lunge_dash", 70, 0],
	],
	&"hive_lens":
	[
		["model", "", 30, 0],
		["prism_spiral", "prism_spiral", 75, 0],
		["petal_bloom", "petal_bloom", 60, 0],
		["gaze_windup", "gaze", 40, 0],
		["gaze_sweep", "gaze", 150, 0],
		["focus_beam_telegraph", "focus_beam", 80, 0],
		["focus_beam_fire", "focus_beam", 105, 0],
		["lens_flare", "lens_flare", 45, 0],
		["dive", "dive", 75, 0],
		["split", "split", 90, 1],
	],
}

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _hud: Hud
var _reader: WorldReader
var _repo: ContentRepository
var _biome: BiomeDefinition
var _boss_id := &""
var _boss := -1
var _jobs: Array = []
var _job := -1
var _run := 0
## Ticks left of the walk before the job's attack starts, and where the hero stands.
var _walk := 0
var _hero := HERO_AT
## True while an "@shell" job waits for its shell to land.
var _landing := false
var _wait := 12
var _out := ""
var _sheet := ""
var _shots: Array[Image] = []
var _labels: Array[String] = []


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_boss_id = StringName(args.get("boss", "siege_engine"))
	_jobs = PLAN.get(_boss_id, [])
	_out = args.get("out", ProjectSettings.globalize_path("res://build/style_audit/%s" % _boss_id))
	_sheet = args.get("sheet", "")
	DirAccess.make_dir_recursive_absolute(_out)
	if _sheet != "":
		DirAccess.make_dir_recursive_absolute(_sheet)
	TranslationServer.set_locale("en")
	_repo = ContentRepository.load_all()
	_biome = _repo.get_def(&"biomes", StringName(args.get("biome", "ruins")))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_next()


func _i() -> int:
	return _world.actors.index_of(_boss)


## A fresh world with the boss hushed and still, the view and HUD over it, and the job's attack started.
func _next() -> void:
	_job += 1
	if _job >= _jobs.size():
		return
	var job: Array = _jobs[_job]
	_world = JudgeLab.world(11)
	var i := BossLab.ready_boss(_world, _boss_id, BOSS_AT)
	_boss = _world.actors.ids[i]
	_world.actors.set_pos(0, HERO_AT)
	_world.actors.hp[0] = LONG
	_world.actors.max_hp[0] = LONG
	JudgeLab.hush(_world, _boss)
	BossAi.table_of(_world, i).speed = 0.0
	if int(job[3]) > 0:
		JudgeLab.set_phase(_world, _boss, int(job[3]))
	_world.step(InputFrame.new())
	_world.boss_fight.time_wave_due = 1 << 29
	_world.boss_fight.time_bell_due = 1 << 29
	_world.boss_fight.time_field_due = 1 << 29
	if _view != null:
		_view.queue_free()
		_hud.queue_free()
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	_view.stage.mood = _biome.mood
	_view.stage.prop_style = _biome.id
	_view.stage.look = _biome.look
	_view.setup(_reader, _biome.palette, 14.0)
	_view.rig.snap_to(SimPlane.to_3d((HERO_AT + BOSS_AT) * 0.5))
	_view.rig.set_process(false)
	_view.rig.set_physics_process(false)
	_view.rig.camera.current = true
	_hud = Hud.new()
	_vp.add_child(_hud)
	_hero = HERO_AT
	_walk = int(job[4]) if job.size() > 4 else 0
	if _walk == 0:
		_start(job)
	_wait = SETTLE


## Starts the job's attack (if any) and runs it the job's ticks. "@shell" (the Siege Engine) starts none: its
## Target Lock runs on its own clock (its Doom Shell off) and the still is the job's ticks after the shell lands.
func _start(job: Array) -> void:
	if String(job[1]) == "@shell":
		SiegeLab.siege(_world, _boss).doom_phase = SiegeLab.NEVER
		_landing = true
		_run = 1500
		return
	if String(job[1]) != "":
		BossLab.start(_world, _world.actors.index_of(_boss), StringName(job[1]))
	_run = int(job[2])


func _step() -> void:
	_world.actors.set_pos(0, _hero)
	_world.actors.hp[0] = LONG
	var aim := Kin.angle_of(_world.actors.pos(_i()) - _hero)
	_world.step(InputFrame.make(Vector2i.ZERO, aim, 600, 0, 0))
	_view.sync()
	_hud.sync(_reader)


func _process(_delta: float) -> bool:
	if _job >= _jobs.size():
		_write_sheets()
		quit(0)
		return true
	if _walk > 0:  # the hero walks a short line back and forth, then the attack starts
		_hero = HERO_AT + Vector2(0.06, -0.04) * float(absi(_walk % 120 - 60))
		_step()
		_walk -= 1
		if _walk == 0:
			_start(_jobs[_job])
		return false
	if _landing and not (_reader.boss_siege().get("boulders", []) as Array).is_empty():
		_landing = false
		_run = int(_jobs[_job][2])
	if _run > 0:
		_step()
		_run -= 1
		return false
	if _wait > 0:
		_wait -= 1
		_hud.sync(_reader)
		return false
	var job: Array = _jobs[_job]
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var label := "%02d_%s" % [_job, job[0]]
	var path := _out.path_join(label + ".png")
	img.save_png(path)
	_shots.append(img)
	_labels.append(label)
	var i := _i()
	print(
		(
			"style_audit: %s  tick %d state %d attack %d projectiles %d"
			% [
				path,
				_world.tick,
				_world.actors.state[i],
				_world.bosses.attack[BossAi.entry_of(_world, i)],
				_reader.projectile_count()
			]
		)
	)
	_next()
	return false


## 2 x 2 sheets of the stills at half size, in order, for a quick read.
func _write_sheets() -> void:
	if _sheet == "":
		return
	var half := SIZE / 2
	var n := 0
	while n * 4 < _shots.size():
		var sheet := Image.create(half.x * 2, half.y * 2, false, Image.FORMAT_RGB8)
		for k in 4:
			var at := n * 4 + k
			if at >= _shots.size():
				break
			var s: Image = _shots[at].duplicate()
			s.resize(half.x, half.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(
				s, Rect2i(Vector2i.ZERO, half), Vector2i((k % 2) * half.x, (k / 2) * half.y)
			)
		var path := _sheet.path_join("%s_sheet_%d.png" % [_boss_id, n])
		sheet.save_png(path)
		print("style_audit: sheet ", path, "  ", _labels.slice(n * 4, n * 4 + 4))
		n += 1
