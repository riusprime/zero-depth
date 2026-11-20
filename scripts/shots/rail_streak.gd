extends SceneTree
## Renders one Siege Engine rail shot for the owner, in the real game view (WorldViewRoot over SiegeLab's walled 24 m
## room, the iso camera) of a real World stepped tick by tick: the owner's streak laid down tile by tile behind the
## shot as it runs down its lane, then fading. One still per tick in TICKS (ticks after the shot's first active tick).
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/rail_streak.gd
## Writes build/shots/<version>/rail_streak/ (or out=<folder>) and prints each path with the tiles drawn.

const SIZE := Vector2i(1600, 900)
const SETTLE := 6
const TICKS: Array[int] = [2, 6, 11, 24, 34]

var _vp: SubViewport
var _world: World
var _view: RailRig
var _boss := -1
var _dir := ""
var _hero := Vector2(-7.0, 3.0)
var _active_at := -1
var _shot := 0
var _wait := 12


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_dir = (
		args.get("out", "res://build/shots/%s/rail_streak/" % GameVersion.label()).trim_suffix("/")
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
	var s := SiegeLab.only(_hero, Vector2(6.0, -2.0), 1, [])
	_world = s[0]
	_boss = s[1]
	_world.step(InputFrame.new())
	_view = RailRig.new(_vp, _world, &"night_rocks")
	BossLab.start(_world, _world.actors.index_of(_boss), &"rail")


func _step() -> void:
	_world.actors.set_pos(0, _hero)
	_world.actors.hp[0] = _world.actors.max_hp[0]
	_world.step(InputFrame.new())
	_view.frame()
	var i := _world.actors.index_of(_boss)
	if _active_at < 0 and i >= 0 and _world.actors.state[i] == EnemyAi.State.ACTIVE:
		_active_at = _world.tick


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		_view.frame(false)
		return false
	if _shot >= TICKS.size():
		quit(0)
		return true
	if _active_at < 0 or _world.tick - _active_at < TICKS[_shot]:
		_step()
		if _active_at >= 0 and _world.tick - _active_at == TICKS[_shot]:
			_wait = SETTLE
		if _world.tick > 2000:
			push_error("rail_streak: the rail never fired")
			quit(1)
			return true
		return false
	var strikes: BossStrikeViews = _view.root.strikes
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_tick_%02d.png" % [_shot + 1, TICKS[_shot]]
	img.save_png(path)
	print(
		"rail_streak: ",
		ProjectSettings.globalize_path(path),
		(
			"  tick %d (+%d) tiles drawn %d front %.2f"
			% [
				_world.tick,
				_world.tick - _active_at,
				strikes.streak.drawn(),
				_view.reader.boss_lane_front(_world.actors.index_of(_boss), 0)
			]
		)
	)
	_shot += 1
	return false


## The game view over one World, the iso camera over the whole room (as siege_fight.gd's rig, without the HUD).
class RailRig:
	extends RefCounted
	var root: WorldViewRoot
	var reader: WorldReader

	func _init(vp: SubViewport, w: World, biome_id: StringName) -> void:
		var repo := ContentRepository.load_all()
		reader = WorldReader.new(w)
		root = WorldViewRoot.new()
		vp.add_child(root)
		var biome: BiomeDefinition = repo.get_def(&"biomes", biome_id)
		root.stage.mood = biome.mood
		root.stage.prop_style = biome.id
		root.stage.look = biome.look
		root.setup(reader, biome.palette, 14.0)
		root.rig.view_size = 22.0
		root.rig.camera.size = 22.0
		root.rig.snap_to(SimPlane.to_3d(Vector2(0.0, 0.0)))
		root.rig.set_process(false)
		root.rig.set_physics_process(false)
		root.rig.camera.current = true

	## One tick's sync (`tick` false: nothing new, for the settle).
	func frame(tick := true) -> void:
		if tick:
			root.sync()
