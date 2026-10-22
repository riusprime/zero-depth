extends SceneTree
## v0.8.0 N4 (owner O56, O57): renders the health bars for the owner in the real game view (WorldViewRoot drawing the
## final arena, the iso camera, the boss bar over it) of a real World built as the game builds it (FinalLab): a damage
## chunk mid-hold (a burst of small hits on the Colossus), a big crit's chunk, a refill mid-way (the Colossus's phase
## gate: its second phase's bar growing back, Invulnerable), the Prism's shielded Cross (the invulnerable bar and the
## shields left), and enemy bars with their chunks (one MultiMesh). The bars run on a fixed 1/60 s a tick here (their
## own processing off, advanced by the script), so each shot lands at the same moment of its motion.
## Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/health_bars_n4.gd -- <n>
## `-- <n>` renders shot n alone. Writes build/shots/v0.8.0/n4/<n>_<label>.jpg and prints the bar's numbers and the
## frame's draw calls (RenderingServer's total in the frame).

## [label, the moment, camera size].
const PLAN := [
	["chunk_mid_hold", &"hold", 18.0],
	["big_crit_chunk", &"crit", 18.0],
	["refill_mid_way", &"refill", 18.0],
	["invulnerable_bar", &"shield", 22.0],
	["enemy_bars", &"enemies", 6.0],
	["enemy_bars_chunk_layer_hidden", &"enemies_off", 6.0],
]
const SIZE := Vector2i(1280, 720)
const DT := 1.0 / 60.0
const PLAYER_AT := Vector2(5.0, -2.0)

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _reader: WorldReader
var _view: WorldViewRoot
var _bar: BossBar
var _layer: CanvasLayer
var _k := 0
var _only := -1
var _dir := ""
var _ticks := 0
var _settle := 0
var _done := false
var _enemies: Array[int] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_only = int(a) - 1
	if _only >= 0:
		_k = _only
	_dir = "res://build/shots/v0.8.0/n4/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build(_k)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
		_layer.queue_free()
	var what: StringName = PLAN[k][1]
	_world = FinalLab.arena(FinalLab.run_state(4646, &"blade"))
	FinalLab.past_rise(_world)
	if what == &"shield":
		FinalBoss.jump(_world, 1)
		FinalLab.past_rise(_world)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_world.actors.set_pos(0, PLAYER_AT)
	var i := FinalLab.body(_world)
	_world.actors.cd[i] = 1 << 20  # its own picks wait: each shot starts what it shows
	_world.actors.set_pos(i, PLAYER_AT + Vector2(-5.0, 0.5))
	_reader = WorldReader.new(_world)
	_ticks = 0
	_settle = 0
	_done = false
	_enemies.clear()
	if what == &"shield":
		BossAi.start_attack(_world, i, BossAi.table_of(_world, i).attack_index(&"cross_ring"))
	if what in [&"enemies", &"enemies_off"]:
		_world.actors.set_pos(i, PLAYER_AT + Vector2(-14.0, 6.0))
		for n in 6:
			_enemies.append(
				_world.add_enemy(
					WorldReader.KIND_CHARGER,
					PLAYER_AT + Vector2(2.2 + (n % 3) * 1.6, -1.6 + (n / 3) * 2.4)
				)
			)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var def: FinalArenaDefinition = _repo.get_def(&"final_arena", &"hollow_arena")
	_view.stage.mood = def.mood
	_view.setup(_reader, def.palette, _reader.final_arena_radius() + 4.0)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_layer = CanvasLayer.new()
	_vp.add_child(_layer)
	var ui := Control.new()
	ui.size = Vector2(SIZE)
	_layer.add_child(ui)
	_bar = BossBar.new()
	ui.add_child(_bar)


func _enemy_at(n: int) -> Vector2:
	return PLAYER_AT + Vector2(2.0 + (n % 3) * 1.5, -1.5 + (n / 3) * 2.2)


## The script's own hits at tick `t` of the shot (the world's own hits, owner 0, as the dev panel's).
func _script(what: StringName, t: int) -> void:
	var i := FinalLab.body(_world)
	var mx := _world.actors.max_hp[i]
	match what:
		&"hold":  # a burst: a small hit every 6 ticks from tick 30
			if t >= 30 and t <= 48 and t % 6 == 0:
				FinalLab.hit(_world, mx / 40)
		&"crit":  # a hit, then a huge crit
			if t == 30:
				FinalLab.hit(_world, mx / 60)
			if t == 34:
				FinalLab.hit(_world, mx * 18 / 100)
		&"refill":  # down to the Colossus's 50 % gate: its second phase starts
			if t == 30:
				FinalLab.hit(_world, _world.actors.hp[i] - mx * 500 / 1000)
		&"enemies", &"enemies_off":  # past their spawn-in
			if t == 100:
				for n in _enemies.size():
					var e := _world.actors.index_of(_enemies[n])
					if e >= 0:
						var at := _world.actors.pos(e)
						var amount := _world.actors.max_hp[e] * (20 + 12 * n) / 100
						Damage.hit(_world, e, amount, 0, 0, _world.take_root(), 0, at, at)


## The tick the shot is taken at.
func _moment(what: StringName) -> bool:
	match what:
		&"hold":
			return _ticks == 30 + 24  # 0.4 s after the burst's first hit: still holding all of it
		&"crit":
			return _ticks == 34 + 10
		&"refill":
			return _ticks > 31 and _bar.shown_fraction() >= 0.45
		&"shield":
			return (
				_ticks > 20 and _bar.invulnerable() and _reader.boss_shielded(FinalLab.body(_world))
			)
		&"enemies", &"enemies_off":
			return _ticks == 100 + 20
	return false


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	# their own frame-time processing off (ready turns it on as they enter the tree): the script advances them
	_bar.hp_bar().set_process(false)
	_view.actors.bar_chunks.set_process(false)
	if not _done:
		_world.actors.set_pos(0, PLAYER_AT)
		for n in _enemies.size():  # they stand where they rose (a row to read)
			var e := _world.actors.index_of(_enemies[n])
			if e >= 0:
				_world.actors.set_pos(e, _enemy_at(n))
		_script(spec[1], _ticks)
		_world.step(InputFrame.new())
		_ticks += 1
		_view.sync()
		_bar.sync(_reader)
		_bar.hp_bar()._process(DT)
		_view.actors.bar_chunks.advance(DT)
		if _moment(spec[1]):
			_done = true
		elif _ticks >= 900:
			push_error("health_bars_n4 shot %d: its moment never came" % (_k + 1))
			_done = true
		_frame(spec)
		return false
	_settle += 1
	_view.actors.bar_chunks.advance(0.0)
	if spec[1] == &"enemies_off":
		_view.actors.bar_chunks.visible = false
	_frame(spec)
	if _settle < 10:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[0]]
	img.save_jpg(path, 0.88)
	var t := _bar.hp_bar().trail
	print(
		(
			(
				"health_bars_n4: %s (tick %d) bar: target %.3f fill %.3f chunk %.3f big %s invulnerable %s"
				+ " line '%s' phase '%s' | enemy chunk strips %d | draw calls %d"
			)
			% [
				path,
				_world.tick,
				t.target,
				t.fill,
				t.chunk_size(),
				t.big > 0.0,
				_bar.invulnerable(),
				_bar.shield_text(),
				_bar.phase_text(),
				_view.actors.bar_chunks.drawn(),
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
				),
			]
		)
	)
	_k += 1
	if _k >= PLAN.size() or _only >= 0:
		return true
	_build(_k)
	return false


func _frame(spec: Array) -> void:
	_view.rig.view_size = float(spec[2])
	_view.rig.camera.size = float(spec[2])
	var i := FinalLab.body(_world)
	var b := _world.actors.pos(i) if i >= 0 else _world.final_fight.home
	var focus := _world.player_pos() + Vector2(3.5, -0.4)
	if not (spec[1] in [&"enemies", &"enemies_off"]):
		focus = b * 0.5 + _world.player_pos() * 0.5
	_view.rig.snap_to(SimPlane.to_3d(focus))
