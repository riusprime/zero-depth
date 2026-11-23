extends SceneTree
## Renders the rune-summoned Blade for the owner, in the real game view (WorldViewRoot, the iso camera close on the
## hero) of a real World with the Blade build, stepped tick by tick: one combo swing in five stills (the blade forming
## in its rune flash, mid-arc, at the arc's end, in the recovery, broken into motes), the finisher's spin and the Lunge
## Cleave mid-sweep; then a close-up of the model alone (its matte steel and glowing edge, lit by one sun).
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/summoned_blade.gd
## Writes build/shots/<version>/blade/ (or out=<folder>) and prints each path.

const SIZE := Vector2i(1600, 900)
const SETTLE := 3
const AIM := 3600
## A swing's last tick (its recovery's end), whatever its length.
const LAST := 1000
## [name, combo step (-1 the cleave), the tick of the move to shoot at: swing tick, or the cleave's running tick
## (negative: ticks after the move ended)].
const SHOTS: Array = [
	["1_combo_forming", 0, 1],
	["2_combo_mid_arc", 0, 4],
	["3_combo_arc_end", 0, 9],
	["4_combo_recovery", 0, LAST],
	["5_combo_motes", 0, -2],
	["6_finisher_spin", 3, 7],
	["7_lunge_cleave", -1, 0],
]

var _vp: SubViewport
var _world: World
var _root: WorldViewRoot
var _reader: WorldReader
var _dir := ""
var _shot := 0
var _wait := 12
var _since_end := -1
var _started := false
var _ready_to_save := false
var _close: SubViewport


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_dir = (
		args.get("out", "res://build/shots/%s/blade/" % GameVersion.label()).trim_suffix("/") + "/"
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
	_world.dummy_speed = 0.0
	_world.add_dummy(Vector2(6.5, -3.0), 0.35, 50000)
	_world.step(InputFrame.new())
	_reader = WorldReader.new(_world)
	_root = WorldViewRoot.new()
	_vp.add_child(_root)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"night_rocks")
	_root.stage.mood = biome.mood
	_root.stage.prop_style = biome.id
	_root.stage.look = biome.look
	_root.setup(_reader, biome.palette, 14.0)
	_root.rig.view_size = 9.0
	_root.rig.camera.size = 9.0
	_root.rig.snap_to(SimPlane.to_3d(Vector2.ZERO))
	_root.rig.set_process(false)
	_root.rig.set_physics_process(false)
	_root.rig.camera.current = true


## Steps the world one tick (pressing `pressed` this tick) and syncs the view.
func _tick(pressed := 0) -> void:
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = _world.actors.max_hp[0]
	_world.step(InputFrame.make(Vector2i.ZERO, AIM, 300, 0, pressed))
	_root.sync()


## True once the world stands at this shot's moment (it steps toward it otherwise).
func _advance(s: Array) -> bool:
	if int(s[1]) < 0:
		return _advance_cleave()
	if not _started:
		_start_swing(int(s[1]))
		return false
	var at: int = s[2]
	if at == LAST:
		at = _reader.swing_ticks()
	var there := false
	if at > 0:
		there = _reader.swing_tick() >= at
	elif _reader.swing_tick() == 0:
		_since_end += 1
		there = _since_end >= -at
	if not there:
		_tick()
	return there


## Waits out the current swing, swings on to combo step `step` (each earlier step swung whole), and presses it.
func _start_swing(step: int) -> void:
	while _world.swing_t > 0:
		_tick()
	while _reader.combo_step() != step and step > 0:
		_tick(InputFrame.PRIMARY)
		while _world.swing_t > 0:
			_tick()
	_tick(InputFrame.PRIMARY)
	_started = true
	_since_end = -1


## The Lunge Cleave: pressed once it is ready, then stepped until its sweep is half across the arc.
func _advance_cleave() -> bool:
	if not _started:
		while _world.swing_t > 0 or not bool(_reader.skill_state()["ready"]):
			_tick()
		_tick(InputFrame.SKILL)
		_started = true
		return false
	var sweep: Array = _root.skill_fx.cleave_sweep()
	if float(sweep[0]) >= 0.5:
		return true
	_tick()
	return false


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _shot >= SHOTS.size():
		if _close == null:
			_close = _close_up()
			_wait = 8
			return false
		_save_vp(_close, "8_model_close_up")
		quit(0)
		return true
	var s: Array = SHOTS[_shot]
	if not _ready_to_save:
		if _advance(s):
			_ready_to_save = true
			_wait = SETTLE
		elif _world.tick > 3000:
			push_error("summoned_blade: never reached " + String(s[0]))
			quit(1)
			return true
		return false
	_save(String(s[0]))
	_ready_to_save = false
	_shot += 1
	_started = s[1] == 0 and _shot < SHOTS.size() and SHOTS[_shot][1] == 0
	return false


func _save_vp(vp: SubViewport, name: String) -> String:
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + name + ".png"
	img.save_png(path)
	return path


func _save(name: String) -> void:
	var path := _save_vp(_vp, name)
	var b := _root.kit.summoned
	print(
		"summoned_blade: ",
		ProjectSettings.globalize_path(path),
		(
			"  tick %d swing %d shown %s yaw %.2f forms %d flashes %d motes %d"
			% [
				_world.tick,
				_reader.swing_tick(),
				b.blade_visible(),
				b.yaw(),
				b.forms,
				b.flashes,
				b.motes
			]
		)
	)


## The model alone, close, on a dark ground under one sun (the same matte steel and glowing edge as in the game).
func _close_up() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 700)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.14, 0.17)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	vp.add_child(sun)
	var blade := SummonedBlade.new()
	vp.add_child(blade)
	(blade.get_child(0) as Node3D).visible = true
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.75
	cam.position = Vector3(0.55, 1.4, 0.9)
	vp.add_child(cam)
	cam.look_at(Vector3(0.55, 0, 0))
	cam.current = true
	print("summoned_blade: close-up of the model, %d nodes" % blade.node_count())
	return vp
