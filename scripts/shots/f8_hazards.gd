extends SceneTree
## v0.11.0 F8 (owner 4.2): one shot of a boss with its arena hazards near the cap, one still in its warning, in the real
## game view of a real World, as scripts/shots/quake_pillars.gd does. Needs a renderer (off screen on the owner's PC):
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/f8_hazards.gd -- boss=foundry
## boss=foundry|brood_mother|siege_engine. Writes build/shots/v0.11.0/f8/<boss>_hazards.jpg and prints its path.

const SIZE := Vector2i(1280, 720)
const PLAYER_AT := Vector2(5.0, 5.0)
const BOSS_AT := Vector2(0.0, 0.0)
const BIOMES := {
	&"foundry": &"red_canyon", &"brood_mother": &"ruins", &"siege_engine": &"red_canyon"
}
const SPOTS: Array[Vector2] = [
	Vector2(-7, -3),
	Vector2(-3, 5),
	Vector2(4, -5),
	Vector2(8, 1),
	Vector2(-8, 4),
	Vector2(1, 7),
	Vector2(-4, -6),
	Vector2(8, -6)
]
## Ticks after the armed ones land until the last one's warning shows.
const AFTER := 20

var _world: World
var _view: WorldViewRoot
var _vp: SubViewport
var _id := &"foundry"
var _boss := -1
var _left := 0
var _phase := 0
var _settle := 0
var _dir := "res://build/shots/v0.11.0/f8/"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("boss="):
			_id = StringName(a.substr(5))
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
		if _world.boss_tables[j].id == _id:
			bk = j
	_world.actors.set_pos(0, PLAYER_AT)
	_boss = _world.spawn_boss(bk, BOSS_AT)
	var i := _world.actors.index_of(_boss)
	_world.actors.state[i] = BossAi.STAGGERED
	_world.actors.state_t[i] = 0
	_world.actors.invuln[i] = 0
	_world.bosses.stagger_t[BossAi.entry_of(_world, i)] = 1 << 20
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	var h := BossAi.table_of(_world, i).hazard
	for k in h.max_count - 1:
		BossHazard.place(_world, i, SPOTS[k])
	_left = h.warn_ticks + 2
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", BIOMES.get(_id, &"ruins"))
	_view.stage.mood = biome.mood  # the game's lit look (and its effects layer), as main.gd sets it
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 19.0
	_view.rig.camera.size = 19.0
	_view.rig.snap_to(SimPlane.to_3d(BOSS_AT))
	_view.rig.set_process(false)
	_view.rig.camera.current = true


func _process(_delta: float) -> bool:
	if _left > 0:
		_world.actors.set_pos(0, PLAYER_AT)
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))
		_view.sync()
		_left -= 1
		if _left == 0 and _phase == 0:
			_phase = 1
			_left = AFTER
			var i := _world.actors.index_of(_boss)
			BossHazard.place(_world, i, SPOTS[BossAi.table_of(_world, i).hazard.max_count - 1])
		return false
	_settle += 1
	if _settle < 10:  # frame-time animation settles
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%s_hazards.jpg" % _id
	img.save_jpg(path, 0.85)
	print(
		"f8_hazards: ",
		ProjectSettings.globalize_path(path),
		" hazards=",
		BossHazard.count_of(_world, _boss),
		" cover=",
		BossHazard.cover_permille(_world, _boss),
		" of ",
		BossHazard.arena_cm2(_world),
		" cm2"
	)
	return true
