extends SceneTree
## Renders the end of the amber Warden's charge for the owner, in the real game view (WorldViewRoot over TwinsLab's
## walled 24 m room, the iso camera) of a real World stepped one tick per frame: the run stopping, the armed circle,
## then the burst's ground impact. Both charges (phase 1's flash charge, then the long charge); for each, a sheet of
## frames from two ticks before the burst to a second after it, the burst's own frame alone, and the whole frame at the
## game's own camera size as the thrown stone peaks (GAME_AT).
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --fixed-fps 60 -s scripts/shots/amber_impact.gd
##   -- out=<folder>
## Writes <folder> (default build/shots/<version>/amber_impact/) and prints each path with the burst's tick and spot.

const SIZE := Vector2i(960, 540)
const CROP := Vector2i(480, 300)
## Frames on the sheet: ticks after the burst (negative: before it).
const SHEET_AT: Array[int] = [-2, 1, 3, 6, 10, 16, 24, 40]
const ATTACKS: Array[StringName] = [&"warden_charge", &"warden_charge_long"]
## The tick after the burst the whole game frame is saved.
const GAME_AT := 10

var _vp: SubViewport
var _world: World
var _root: WorldViewRoot
var _amber := -1
var _dir := ""
var _which := 0
var _burst_tick := -1
var _armed_seq := 0
var _frames: Array[Image] = []
var _settle := 10


func _initialize() -> void:
	_dir = "res://build/shots/%s/amber_impact/" % GameVersion.label()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_dir = a.substr(4).trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_begin()


func _begin() -> void:
	var hero := Vector2(7.0, 0.0)
	var s := TwinsLab.fight(hero, Vector2(-7.0, 0.0))
	_world = s[0]
	_amber = s[1]
	TwinsLab.hush(_world, _amber)
	_world.actors.set_pos(_i(s[2]), Vector2(-9.0, 9.0))
	_world.step(InputFrame.new())
	if _root != null:
		_root.queue_free()
	_root = WorldViewRoot.new()
	_vp.add_child(_root)
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"frozen_shore")
	_root.stage.mood = biome.mood
	_root.stage.prop_style = biome.id
	_root.stage.look = biome.look
	_root.setup(WorldReader.new(_world), biome.palette, 14.0)
	_root.rig.camera.size = _root.rig.view_size  # the game's own camera size
	_root.rig.snap_to(SimPlane.to_3d(Vector2(3.0, 0.0)))
	_root.rig.set_process(false)
	_root.rig.set_physics_process(false)
	_root.rig.camera.current = true
	_burst_tick = -1
	_frames = []
	_armed_seq = TwinsLab.mark(_world)
	BossLab.start(_world, _i(_amber), ATTACKS[_which])


func _i(aid: int) -> int:
	return _world.actors.index_of(aid)


func _process(_delta: float) -> bool:
	if _settle > 0:
		_settle -= 1
		return false
	if _burst_tick >= 0:
		var at := _world.tick - _burst_tick
		if SHEET_AT.has(at):
			_frames.append(_crop())
			if at == 1:
				_save(_crop(), "%d_burst.png" % (_which + 1))
			if at == GAME_AT:
				var img := _vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				_save(img, "%d_game.png" % (_which + 1))
		if at >= SHEET_AT[SHEET_AT.size() - 1]:
			_sheet()
			_which += 1
			if _which >= ATTACKS.size():
				quit(0)
				return true
			_settle = 10
			_begin()
			return false
	_world.actors.hp[0] = _world.actors.max_hp[0]
	_world.step(InputFrame.new())
	_root.sync()
	var armed := TwinsLab.effects(_world, BossChargeBurst.ARMED, _armed_seq)
	if _burst_tick < 0 and not armed.is_empty():
		var atk := BossAi.attack_of(_world, _i(_amber))
		_burst_tick = _world.tick + atk.burst_ticks
		_root.rig.snap_to(SimPlane.to_3d(armed[0].pos))
		print(
			(
				"amber_impact: charge %d armed at %s, bursts at tick %d"
				% [_which + 1, armed[0].pos, _burst_tick]
			)
		)
	return false


func _crop() -> Image:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var o := (SIZE - CROP) / 2
	return img.get_region(Rect2i(o, CROP))


func _sheet() -> void:
	var cols := 4
	var rows := ceili(float(_frames.size()) / cols)
	var sheet := Image.create(CROP.x * cols, CROP.y * rows, false, Image.FORMAT_RGB8)
	for k in _frames.size():
		sheet.blit_rect(
			_frames[k], Rect2i(Vector2i.ZERO, CROP), Vector2i(k % cols, k / cols) * CROP
		)
	_save(sheet, "%d_sheet.png" % (_which + 1))


func _save(img: Image, file: String) -> void:
	var path := _dir + file
	img.save_png(path)
	print("amber_impact: ", ProjectSettings.globalize_path(path))
