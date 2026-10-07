extends SceneTree
## Renders the boss challenge (v0.3.0 BX) for the owner. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/boss_challenge.gd
## Writes build/shots/<version>/bosses/boss_challenge.png and prints its path. Each cell is the real game view
## (WorldViewRoot on the Ruins stage) of a real World stepped one tick per frame, grabbed in _process:
## the Gatekeeper's vortex pulling the hero in, its weak point open after a slam with the hero striking it, the
## Brood Mother's pounce chain marked, the Siege Engine's shockwave sparing the ring near it, far bolts deflected
## off the Siege Engine, the closing band with its next step marked, and the floor's enemies dissolving at the summon.

const CELL := Vector2i(480, 340)
const COLS := 4
## [label, boss id, setup key, ticks to step before the grab].
const PLAN := [
	["vortex pull", &"gatekeeper", &"vortex", 50],
	["weak point open", &"gatekeeper", &"weak", 0],
	["pounce chain", &"brood_mother", &"pounce", 20],
	["shockwave", &"siege_engine", &"shockwave", 50],
	["far bolts deflected", &"siege_engine", &"deflect", 40],
	["closing arena", &"gatekeeper", &"arena", 0],
	["enemies dissolve", &"", &"dissolve", 10],
	["boss rising (bar fills)", &"brood_mother", &"rise", 30],
]

var _dir := ""
var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _cells: Array[Image] = []
var _step := 0
var _boss := -1
var _hold := Vector2.ZERO
var _held := 0
var _bar: BossBar


func _initialize() -> void:
	_dir = "res://build/shots/%s/bosses/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build(0)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	_world = StageScenario.build(
		9, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_world.set_boss_tables(ContentCompiler.compile_bosses(_repo))
	_world.actors.hp[0] = 100000
	_held = 0
	_hold = Vector2(5.5, -3.5)
	_boss = -1
	if spec[1] != &"":
		var bk := -1
		for j in _world.boss_tables.size():
			if _world.boss_tables[j].id == spec[1]:
				bk = j
		_boss = _world.spawn_boss(bk, Vector2(-1.0, 1.0))
		var i := _world.actors.index_of(_boss)
		if spec[2] != &"rise":
			_world.actors.state[i] = EnemyAi.State.MOVE
			_world.actors.invuln[i] = 0
		_world.actors.cd[i] = 100000
	_world.actors.set_pos(0, _hold)
	_setup(spec[2])
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	var size := 19.0 if spec[2] == &"arena" or spec[2] == &"dissolve" else 13.5
	_view.rig.view_size = size
	_view.rig.camera.size = size
	_view.rig.snap_to(SimPlane.to_3d(Vector2(1.0, -0.8)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	if _bar != null:
		_bar.queue_free()
		_bar = null
	if spec[2] == &"rise":
		_bar = BossBar.new()
		_vp.add_child(_bar)
		_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_bar.scale = Vector2(0.66, 0.66)
		_bar.position = Vector2(29, 6)
	_step = 0


func _setup(key: StringName) -> void:
	var w := _world
	var i := w.actors.index_of(_boss) if _boss > 0 else -1
	var t := BossAi.table_of(w, i) if i >= 0 else null
	match key:
		&"vortex":
			_hold = Vector2(7.5, -4.0)
			w.actors.set_pos(0, _hold)
			_start_alone(w, i, &"vortex_slam")
			_hold = Vector2.INF  # let the vortex drag the hero
		&"weak":
			w.bosses.exposed_t[BossAi.entry_of(w, i)] = t.weak_ticks
			w.actors.state[i] = EnemyAi.State.RECOVER
			w.bosses.attack[BossAi.entry_of(w, i)] = t.attack_index(&"fist_slam")
			_hold = Vector2(1.6, -0.6)
			w.actors.set_pos(0, _hold)
		&"pounce":
			_hold = Vector2(7.0, -5.0)
			w.actors.set_pos(0, _hold)
			_start_alone(w, i, &"pounce_chain")
		&"shockwave":
			_hold = Vector2(6.5, -5.5)
			w.actors.set_pos(0, _hold)
			_start_alone(w, i, &"shockwave")
		&"deflect":
			_hold = Vector2(6.6, -1.2)
			w.actors.set_pos(0, _hold)
		&"arena":
			w.bosses.arena = Rect2(-9.1, -9.1, 18.2, 18.2)
			w.bosses.close_t[BossAi.entry_of(w, i)] = (
				t.close_step_ticks * 3 - t.close_warn_ticks / 3
			)
			w.actors.state[i] = BossAi.STAGGERED  # stands still for the picture
			w.bosses.stagger_t[BossAi.entry_of(w, i)] = 99999
			_hold = Vector2(4.0, -3.0)
			w.actors.set_pos(0, _hold)
		&"dissolve":
			for p: Vector2 in [
				Vector2(-4, 3), Vector2(3, 4), Vector2(-3, -4), Vector2(5, -1), Vector2(0, 6)
			]:
				w.add_enemy(ActorStore.Kind.CHARGER, p)
			w.add_enemy(ActorStore.Kind.WARDEN, Vector2(-6, -1))
			for k in 40:
				w.step(InputFrame.new())
			BossChallenge.dissolve_floor(w)
			var bk := 0
			for j in w.boss_tables.size():
				if w.boss_tables[j].id == &"gatekeeper":
					bk = j
			_boss = w.spawn_boss(bk, Vector2(-1.0, 1.0))
		&"rise":
			_hold = Vector2(5.0, -3.0)


## As BossLab.start (tests/support): the attack alone, never chaining.
func _start_alone(w: World, i: int, attack_id: StringName) -> void:
	BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(attack_id))
	w.bosses.chained[BossAi.entry_of(w, i)] = 1


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_cells.size()]
	var want: int = spec[3]
	if _step < want:
		if _hold != Vector2.INF:
			_world.actors.set_pos(0, _hold)
		var held := 0
		var pressed := 0
		var aim := 2048 + 300
		var i := _world.actors.index_of(_boss) if _boss > 0 else -1
		if i >= 0:
			aim = Kin.angle_of(_world.actors.pos(i) - _world.player_pos())
		if spec[2] == &"deflect":
			held = InputFrame.SHOOT
		if spec[2] == &"weak":
			pressed = InputFrame.PRIMARY if _step % 8 == 0 else 0
		_world.step(InputFrame.make(Vector2i.ZERO, aim, 300, held, pressed))
		_view.sync()
		if _bar != null:
			_bar.sync(_view.reader)
		_step += 1
		return false
	if spec[2] == &"weak" and _held < 26:
		# Swing at the open weak point until a hit lands, so its spark is in the picture.
		_world.actors.set_pos(0, _hold)
		var i := _world.actors.index_of(_boss)
		var aim := Kin.angle_of(_world.actors.pos(i) - _world.player_pos())
		_world.step(
			InputFrame.make(Vector2i.ZERO, aim, 300, 0, InputFrame.PRIMARY if _held == 0 else 0)
		)
		_view.sync()
		_held += 1
		return false
	_step += 1
	if _step < want + 10:  # let frame-time animation settle
		return false
	_cells.append(_grab(_vp, spec[0]))
	if _cells.size() == PLAN.size():
		_write()
		return true
	_build(_cells.size())
	return false


func _grab(vp: SubViewport, _label: String) -> Image:
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _write() -> void:
	var rows := ceili(float(_cells.size()) / COLS)
	var out := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for k in _cells.size():
		out.blit_rect(
			_cells[k], Rect2i(Vector2i.ZERO, CELL), Vector2i(k % COLS * CELL.x, k / COLS * CELL.y)
		)
	var path := _dir + "boss_challenge.png"
	out.save_png(path)
	var labels: Array[String] = []
	for s: Array in PLAN:
		labels.append(s[0])
	print("boss_challenge: ", path, " cells=", ", ".join(labels))
