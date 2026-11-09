extends SceneTree
## v0.11.0 F9 (owner): one shot of the Warlord's great javelin embedded in the floor with its quake ring's warning
## growing, in the real game view (WorldViewRoot on the Ruins stage, the iso camera) of a real World, as
## scripts/shots/quake_pillars.gd does. Needs a renderer (off screen on the owner's PC):
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/great_javelin.gd
## Writes build/shots/v0.11.0/f9/great_javelin.jpg and prints its path. Frames are grabbed in _process.

const SIZE := Vector2i(1280, 720)
const PLAYER_AT := Vector2(5.0, -6.0)
const BOSS_AT := Vector2(-4.0, -7.0)
## Ticks after it embeds: the ring is most of the way through its warning (the first pulse comes at 75).
const EMBED_TICKS := 66

var _world: World
var _view: WorldViewRoot
var _vp: SubViewport
var _boss := -1
var _since := -1
var _embed_ticks := EMBED_TICKS
var _settle := 0
var _acc := 0.0
var _dir := "res://build/shots/v0.11.0/f9/"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():  # (-- embed=12 : a closer look at the impact)
		if a.begins_with("embed="):
			_embed_ticks = int(a.substr(6))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var repo := ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_world = StageScenario.build(
		9, PlayerTable.starting_values(), ContentCompiler.compile_enemies(repo)
	)
	_world.set_boss_tables(ContentCompiler.compile_bosses(repo))
	var bk := -1
	for j in _world.boss_tables.size():
		if _world.boss_tables[j].id == &"warlord":
			bk = j
	_world.actors.set_pos(0, PLAYER_AT)
	_boss = _world.spawn_boss(bk, BOSS_AT)
	var i := _world.actors.index_of(_boss)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	BossAi.start_attack(_world, i, _world.boss_tables[bk].attack_index(&"great_javelin"))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood  # the mood turns the effects layer and the pack on (PD-13: its rims and dust)
	_view.stage.prop_style = biome.id
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 19.0
	_view.rig.camera.size = 19.0
	_view.rig.snap_to(SimPlane.to_3d((BOSS_AT + PLAYER_AT) * 0.5))
	_view.rig.set_process(false)
	_view.rig.camera.current = true


func _process(delta: float) -> bool:
	_acc += delta
	if _acc < 1.0 / 60.0 and _since < _embed_ticks:  # ticks at the game's pace: the effects run on frame time
		return false
	_acc = 0.0
	if _since < _embed_ticks:
		var bs := _world.bosses
		if _since < 0 and bs.gj_phase.size() > 0 and bs.gj_phase[0] == BossGreatJavelin.EMBEDDED:
			_since = 0
		elif _since >= 0:
			_since += 1
		_world.actors.set_pos(0, PLAYER_AT + Vector2(1.0, 2.0) if _since >= 0 else PLAYER_AT)
		var i := _world.actors.index_of(_boss)
		_world.actors.cd[i] = 1 << 10  # it stands off for the picture
		var aim := Kin.angle_of(_world.actors.pos(i) - _world.player_pos())
		_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, 0, 0))
		_view.sync()
		return false
	_settle += 1
	if _settle < 10:  # frame-time animation settles
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "great_javelin_%d.jpg" % _embed_ticks
	img.save_jpg(path, 0.85)
	var bi := _world.actors.index_of(_boss)
	print("great_javelin: ", path, " state=", WorldReader.new(_world).boss_great_javelin(bi))
	return true
