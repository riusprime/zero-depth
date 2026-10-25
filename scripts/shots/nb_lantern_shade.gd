extends SceneTree
## v0.9.0 NB4: renders the Lantern Shade's dark for the owner, in the real game view (WorldViewRoot on the Ruins
## stage, the iso camera) of a real World: Lights Out has fallen (the room dark but for the hero's 3.5 m light and the
## lit lanterns' pools); three of the four edge lanterns burn (one low, its burn ring nearly empty), the east one is
## out (its cold dashed ring on the floor); the Shade stands in the dark beyond the hero's light (its body dark, its
## held lantern glowing); a Wisp Bloom has opened toward the hero (wisps outlined within 4 m) and a Snuff's circle
## tracks the hero (markers always draw over the dark). Needs a renderer (no --headless):
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/nb_lantern_shade.gd
## Writes build/shots/v0.9.0/nb4/1_lantern_shade_dark.jpg and prints its path and the light's state.

const SIZE := Vector2i(1280, 720)
const HERO_AT := Vector2(-2.2, -1.2)
const SHADE_AT := Vector2(2.6, 2.0)
## Lights Out to its dark (240 ticks + 1), the Wisp Bloom's flight, then the Snuff's tracking.
const DARK_TICKS := 241
const BLOOM_TICKS := 95
const SNUFF_TICKS := 40

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _frames := 0
var _stage := 0
var _ticks := 0
var _boss := -1
var _t: BossTable
var _dir := "res://build/shots/v0.9.0/nb4/"


func _initialize() -> void:
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
		if _world.boss_tables[j].id == &"lantern_shade":
			bk = j
	_t = _world.boss_tables[bk]
	for p in _t.phase_attacks.size():
		_t.phase_attacks[p] = PackedInt32Array()
	_t.punish_ticks = 0
	_t.gap_ticks = 0
	_t.sig_every_ticks = 0
	_t.speed = 0.0
	_world.actors.set_pos(0, HERO_AT)
	_boss = _world.spawn_boss(bk, Vector2.ZERO)  # the lanterns stand round where it rose
	var i := _world.actors.index_of(_boss)
	_world.actors.state[i] = EnemyAi.State.MOVE
	_world.actors.invuln[i] = 0
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_world.step(InputFrame.new())
	_world.actors.set_pos(i, SHADE_AT)
	BossAi.start_attack(_world, i, _t.attack_index(&"lights_out"))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 13.0
	_view.rig.camera.size = 13.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(0.0, 0.3)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true


func _step(n: int) -> void:
	for k in n:
		_world.actors.set_pos(0, HERO_AT)
		_world.actors.set_pos(_world.actors.index_of(_boss), SHADE_AT)
		_world.step(InputFrame.make(Vector2i.ZERO, Kin.angle_of(Vector2(1, 1)), 300, 0, 0))
		_view.sync()
		_view.shades.advance(1.0 / 60.0)
		_ticks += 1


func _process(_delta: float) -> bool:
	var i := _world.actors.index_of(_boss)
	match _stage:
		0:
			_step(8)
			if _ticks >= DARK_TICKS:
				# The east lantern snuffed; the north one low; the south and west burning.
				var lt := _world.bosses.lamp_t
				lt[1] = 0
				lt[0] = 70
				_world.bosses.lamp_t = lt
				BossAi.start_attack(_world, i, _t.attack_index(&"wisp_bloom"))
				_ticks = 0
				_stage = 1
			return false
		1:
			_step(5)
			if _ticks >= BLOOM_TICKS:
				BossAi.start_attack(_world, i, _t.attack_index(&"snuff"))
				_ticks = 0
				_stage = 2
			return false
		2:
			_step(4)
			if _ticks >= SNUFF_TICKS:
				_stage = 3
			return false
	_frames += 1
	if _frames < 12:
		_view.shades.advance(1.0 / 60.0)
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "1_lantern_shade_dark.jpg"
	img.save_jpg(path, 0.9)
	var r := _view.reader
	var l := r.boss_light()
	var lit := []
	for s: Dictionary in l.get("lamps", []):
		lit.append(int(s["left"]))
	print("nb_lantern_shade: ", path)
	print(
		"nb_lantern_shade: tick ",
		_world.tick,
		" dark ",
		l.get("dark"),
		" lamps left ",
		lit,
		" boss lit ",
		l.get("boss_lit"),
		" dark strength ",
		_view.shades.dark_strength(),
		" lights ",
		_view.shades.lights_used(),
		" wisps outlined ",
		_view.shades.outlined_wisps(),
		" telegraph ",
		BossAi.telegraph(_world, i).get("shape", &""),
		" hero hp lost ",
		(1 << 20) - _world.actors.hp[0]
	)
	return true
