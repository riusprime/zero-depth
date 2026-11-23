extends SceneTree
## Renders the rune-summoned Blade while the hero walks, for the owner: the real game view (WorldViewRoot, the iso
## camera following the hero) of a real World with the Blade build, the hero walking right and swinging, stepped one
## tick per frame. A sequence of stills across one swing (its rune flash, mid-arc, the arc's end, the recovery, the
## motes as it breaks and a moment later) shows the flash and the motes staying with the hero; then a close still of
## the blade's size against the hero, standing, mid-arc.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/summoned_blade_walk.gd
## Writes build/shots/<version>/blade_walk/ (or out=<folder>) and prints each path.

const SIZE := Vector2i(1600, 900)
const AIM := 0
const WALK := Vector2i(127, 0)
## Ticks into the walk at which the swing is pressed, and the ticks after the press at which a still is saved.
const PRESS := 30
const AT: Array[int] = [1, 3, 6, 12, 18, 24]
## The size still: the tick after its press, and the camera's view size.
const SIZE_AT := 4
const CLOSE_VIEW := 4.5

var _vp: SubViewport
var _world: World
var _root: WorldViewRoot
var _reader: WorldReader
var _dir := ""
var _wait := 12
var _n := 0
var _walking := true
## The still to save at the start of the next frame, once the tick it names has been drawn.
var _pending := ""


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_dir = (
		(args.get("out", "res://build/shots/%s/blade_walk/" % GameVersion.label())).trim_suffix("/")
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
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"night_rocks")
	_root.stage.mood = biome.mood
	_root.stage.prop_style = biome.id
	_root.stage.look = biome.look
	_root.setup(_reader, biome.palette, 14.0)
	_root.rig.view_size = 7.0
	_root.rig.camera.size = 7.0
	_root.rig.set_process(false)
	_root.rig.set_physics_process(false)
	_root.rig.camera.current = true
	_world.actors.set_pos(0, Vector2(-4.0, 0.0))


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _pending != "":
		_save(_pending)
		_pending = ""
		if not _walking and _n > 40:
			quit(0)
			return true
	_n += 1
	if _walking:
		var press := InputFrame.PRIMARY if _n == PRESS else 0
		_step(WALK, press)
		var rel := _n - PRESS
		if AT.has(rel):
			_pending = "walk_%02d_tick_%02d" % [AT.find(rel) + 1, rel]
		if rel >= AT[AT.size() - 1]:
			_walking = false
			_n = 0
		return false
	# Standing, closer: wait out anything left, then one swing for the size still.
	if _n == 1:
		_root.rig.view_size = CLOSE_VIEW
		_root.rig.camera.size = CLOSE_VIEW
	if _n < 40:
		_step(Vector2i.ZERO, 0)
		return false
	_step(Vector2i.ZERO, InputFrame.PRIMARY if _n == 40 else 0)
	if _n - 40 == SIZE_AT:
		_pending = "size_against_hero"
	return false


func _step(move: Vector2i, pressed: int) -> void:
	_world.actors.hp[0] = _world.actors.max_hp[0]
	_world.step(InputFrame.make(move, AIM, 300, 0, pressed))
	_root.rig.snap_to(SimPlane.to_3d(_reader.player_pos()))
	_root.sync()


func _save(name: String) -> void:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + name + ".png"
	img.save_png(path)
	var b := _root.kit.summoned
	var c := SimPlane.to_3d(_reader.player_pos(), KitView.BLADE_HEIGHT)
	print(
		"summoned_blade_walk: ",
		ProjectSettings.globalize_path(path),
		(
			"  tick %d swing %d step %d shown %s hero %s hilt_from_centre %.3f span %.3f scale %.3f riders %d"
			% [
				_world.tick,
				_reader.swing_tick(),
				_reader.combo_step(),
				b.blade_visible(),
				_reader.player_pos(),
				b.hilt_point().distance_to(c),
				b.span_m(),
				b.span_m() / b.length_m(),
				b.riders()
			]
		)
	)
	for k in b.riders():
		print("  rider %d at %s (from the hero %s)" % [k, b.rider_point(k), b.rider_point(k) - c])
