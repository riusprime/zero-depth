extends SceneTree
## Renders the hero holding the Blade, for the owner to judge the trial: the real game view (WorldViewRoot, the iso
## camera on the hero) of a real World with the Blade build, stepped one tick per frame, close on the hero. Stills:
## each combo step mid-swing (the two slashes, the thrust, the finisher's spin), the Lunge Cleave (driving in, and as
## it lands), the arms easing down after a swing, then with the sword held between swings (the dev panel's "Blade
## held"): the guard seen from the front and from behind, walking, and a swing from behind. Each still is cropped
## round the hero; they are also laid out on one contact sheet.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/hero_arms.gd
## Writes build/shots/<version>/hero_arms/ (or out=<folder>) and prints each path.

const SIZE := Vector2i(1600, 900)
const VIEW := 4.5
const CROP := Vector2i(560, 480)
const COLS := 4
## The program: [op, args...]. "face" walks a few ticks toward an angle off the camera's (0: at the camera, 2048: away)
## and stands; "swing" presses until combo step `a` is on swing tick `b` and saves; "cleave" saves the lunge and
## the landing; "walk" walks `b` ticks toward `a` and saves on tick `c`; "shot" saves now; "wait" steps ticks.
const PROGRAM := [
	["held", false],
	["face", 400],
	["swing", 0, 3, "01_slash_one"],
	["swing", 1, 3, "02_slash_two"],
	["swing", 2, 4, "03_thrust"],
	["swing", 3, 4, "04_finisher_spin"],
	["wait", 50],
	["cleave", "05_cleave_lunge", "06_cleave_lands"],
	["wait", 60],
	["face", 400],
	["swing", 0, 13, "07_summoned_recovery"],
	["wait", 3],
	["shot", "08_summoned_arms_dropping"],
	["wait", 50],
	["held", true],
	["face", 400],
	["shot", "09_held_guard_front"],
	["face", 2448],
	["shot", "10_held_guard_behind"],
	["swing", 0, 3, "11_held_slash_from_behind"],
	["wait", 50],
	["walk", 1024, 40, 30, "12_held_walking"],
]

var _vp: SubViewport
var _world: World
var _root: WorldViewRoot
var _reader: WorldReader
var _dir := ""
var _wait := 12
var _pc := 0
var _n := 0
var _aim := 0
var _pending := ""
var _crops: Array[Image] = []


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_dir = (
		(args.get("out", "res://build/shots/%s/hero_arms/" % GameVersion.label())).trim_suffix("/")
		+ "/"
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	TranslationServer.set_locale("en")
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"blade"))
	_world = World.new(5, t)
	_world.step(InputFrame.new())
	_reader = WorldReader.new(_world)
	_root = WorldViewRoot.new()
	_vp.add_child(_root)
	var biome: BiomeDefinition = repo.get_def(&"biomes", StringName(args.get("biome", "ruins")))
	_root.stage.mood = biome.mood
	_root.stage.prop_style = biome.id
	_root.stage.look = biome.look
	_root.setup(_reader, biome.palette, 14.0)
	_root.rig.view_size = VIEW
	_root.rig.camera.size = VIEW
	_root.rig.set_process(false)
	_root.rig.set_physics_process(false)
	_root.rig.camera.current = true


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _pending != "":
		_save(_pending)
		_pending = ""
	if _pc >= PROGRAM.size():
		_sheet()
		ViewPrefs.blade_held = false
		quit(0)
		return true
	_n += 1
	if _n > 600:
		push_error("hero_arms: op %d never finished: %s" % [_pc, str(PROGRAM[_pc])])
		quit(1)
		return true
	if _run(PROGRAM[_pc]):
		_pc += 1
		_n = 0
	return false


## Runs one frame of `op`; true once it is done.
func _run(op: Array) -> bool:
	var done := false
	match String(op[0]):
		"held":
			ViewPrefs.blade_held = op[1]
			done = true
		"wait":
			_step(Vector2i.ZERO, 0)
			done = _n >= int(op[1])
		"shot":
			_step(Vector2i.ZERO, 0)
			_pending = op[1]
			done = true
		"face":
			_aim = _toward_camera(int(op[1]))
			_step(_move(_aim) if _n <= 14 else Vector2i.ZERO, 0)
			done = _n >= 50
		"walk":
			_aim = _toward_camera(int(op[1]))
			_step(_move(_aim), 0)
			if _n == int(op[3]):
				_pending = op[4]
			done = _n >= int(op[2])
		"swing":
			var idle := _reader.swing_tick() == 0
			_step(Vector2i.ZERO, InputFrame.PRIMARY if idle else 0)
			if _reader.swing_tick() == int(op[2]) and _reader.combo_step() == int(op[1]):
				_pending = op[3]
				done = true
		"cleave":
			_step(Vector2i.ZERO, InputFrame.SKILL if _n == 1 else 0)
			var s := _reader.skill_state()
			var hit := int(s.get("hit_tick", -1))
			if int(s.get("running", 0)) == 4:
				_pending = op[1]
			elif not s.is_empty() and int(s["running"]) == 0 and hit >= 0:
				if _reader.tick() - hit == 1:
					_pending = op[2]
					done = true
	return done


## The sim angle `off` (4096 a turn) round from the direction that points at the camera.
func _toward_camera(off: int) -> int:
	var z := _root.rig.camera.global_basis.z
	return (int(round(atan2(-z.z, z.x) / TAU * 4096.0)) + off) & 4095


func _move(angle: int) -> Vector2i:
	var a := TAU * float(angle) / 4096.0
	return Vector2i(int(round(cos(a) * 127.0)), int(round(sin(a) * 127.0)))


func _step(move: Vector2i, pressed: int) -> void:
	_world.actors.hp[0] = _world.actors.max_hp[0]
	_world.step(InputFrame.make(move, _aim, 300, 0, pressed))
	_root.rig.snap_to(SimPlane.to_3d(_reader.player_pos()))
	_root.sync()


func _save(name: String) -> void:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var crop := img.get_region(Rect2i((SIZE - CROP) / 2 - Vector2i(0, 40), CROP))
	var path := _dir + name + ".png"
	crop.save_png(path)
	_crops.append(crop)
	var arms: HeroArms = null
	for c in _root.actors.find_children("Arms", "HeroArms", true, false):
		arms = c
	print(
		"hero_arms: ",
		ProjectSettings.globalize_path(path),
		(
			"  tick %d swing %d step %d motion %d held %s blade %s arms %s hands_on %s/%s carried %s"
			% [
				_world.tick,
				_reader.swing_tick(),
				_reader.combo_step(),
				_reader.swing_motion(),
				ViewPrefs.blade_held,
				_root.kit.summoned.blade_visible(),
				arms != null and arms.visible,
				arms != null and arms.on_grip(0),
				arms != null and arms.on_grip(1),
				arms != null and arms.carrying(),
			]
		)
	)


func _sheet() -> void:
	if _crops.is_empty():
		return
	var rows := ceili(float(_crops.size()) / COLS)
	var sheet := Image.create(CROP.x * COLS, CROP.y * rows, false, Image.FORMAT_RGB8)
	for k in _crops.size():
		var at := Vector2i((k % COLS) * CROP.x, (k / COLS) * CROP.y)
		sheet.blit_rect(_crops[k], Rect2i(Vector2i.ZERO, CROP), at)
	var path := _dir + "contact_sheet.png"
	sheet.save_png(path)
	print("hero_arms: ", ProjectSettings.globalize_path(path), "  %d stills" % _crops.size())
