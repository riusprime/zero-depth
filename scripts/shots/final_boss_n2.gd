extends SceneTree
## v0.8.0 N2 (owner O41 "we have to have the really hard to dodge spells"; O42, O52 The Fallen "on and off";
## FINAL_BOSS.md "N2"): renders the new attacks and The Fallen's mimic window for the owner in the real game view
## (WorldViewRoot drawing the final arena, the iso camera, the boss bar) of a real World built as the game builds it
## (FinalLab; NemesisLab for The Fallen, on a Blade run holding three wand cards): the Colossus's double quake ring
## and its fast double spike chase, the Prism's crossing weave with its bolt fans, The Fallen's crescent storm, the
## window's warning (the rings at both feet, the boss bar's line) and the window (the rings, the thread, the line).
## Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/final_boss_n2.gd -- <n>
## `-- <n>` renders shot n alone. Writes build/shots/v0.8.0/n2/<n>_<label>.jpg.

## [label, the moment (see _moment), camera size].
const PLAN := [
	["colossus_double_quake_ring", &"quake", 22.0],
	["colossus_double_spike_chase", &"chase", 20.0],
	["prism_cross_weave_and_bolt_fans", &"weave", 26.0],
	["fallen_crescent_storm", &"storm", 18.0],
	["fallen_window_warning", &"warn", 17.0],
	["fallen_window_open", &"open", 17.0],
]
const CARDS := [[&"echo_slash", 3], [&"double_slash", 2], [&"whirl", 4]]
const SIZE := Vector2i(1280, 720)
const TICKS_PER_FRAME := 3
const PLAYER_AT := Vector2(5.0, -2.0)

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _reader: WorldReader
var _view: WorldViewRoot
var _bar: BossBar
var _ui: Control
var _k := 0
var _only := -1
var _dir := ""
var _ticks := 0
var _limit := 0
var _settle := 0
var _done := false
var _after := -1
var _mark := -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_only = int(a) - 1
	if _only >= 0:
		_k = _only
	_dir = "res://build/shots/v0.8.0/n2/"
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
		_bar.get_parent().get_parent().queue_free()
	var what: StringName = PLAN[k][1]
	if what in [&"storm", &"warn", &"open"]:
		_world = NemesisLab.world(4545, &"blade", CARDS, true, false)
	else:
		_world = FinalLab.arena(FinalLab.run_state(4545, &"blade"))
		_world.actors.invuln[0] = NemesisLab.LONG
		FinalLab.past_rise(_world)
		if what == &"weave":
			FinalBoss.jump(_world, 1)
			FinalLab.past_rise(_world)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.set_pos(0, PLAYER_AT)
	_reader = WorldReader.new(_world)
	_ticks = 0
	_settle = 0
	_done = false
	_after = -1
	_mark = -1
	_limit = 2400
	_quiet()
	var i := FinalLab.body(_world)
	match what:
		&"quake":
			_world.actors.set_pos(i, PLAYER_AT + Vector2(-6.0, 0.0))
			_start(&"leap_slam_3")
		&"chase":
			_world.actors.set_pos(i, PLAYER_AT + Vector2(-7.0, 1.0))
			_start(&"spike_chase_3")
		&"weave":
			_start(&"cross_weave")
		&"storm":
			_world.actors.set_pos(i, PLAYER_AT + Vector2(-6.5, 0.5))
			_start(&"fallen_storm")
		&"warn", &"open":
			_world.actors.set_pos(i, PLAYER_AT + Vector2(-4.0, 1.0))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var def: FinalArenaDefinition = _repo.get_def(&"final_arena", &"hollow_arena")
	_view.stage.mood = def.mood
	_view.setup(_reader, def.palette, _reader.final_arena_radius() + 4.0)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	var layer := CanvasLayer.new()
	_vp.add_child(layer)
	_ui = Control.new()
	_ui.size = Vector2(SIZE)
	layer.add_child(_ui)
	_bar = BossBar.new()
	_ui.add_child(_bar)


## Its own picks off (each shot starts what it shows).
func _quiet() -> void:
	var t := BossAi.table_of(_world, FinalLab.body(_world))
	for p in t.phase_attacks.size():
		t.phase_attacks[p] = PackedInt32Array()


func _start(id: StringName) -> void:
	var i := FinalLab.body(_world)
	BossAi.start_attack(_world, i, BossAi.table_of(_world, i).attack_index(id))


## How many more ticks to step once the shot's moment comes (-1 until it does).
func _moment(what: StringName) -> int:
	var i := FinalLab.body(_world)
	if i < 0:
		return -1
	var st := _world.actors.state[i]
	var t := _world.actors.state_t[i]
	var out := -1
	match what:
		&"quake":  # landed: the second ring out (more than one ring's stones flying), the first one past it
			out = 8 if _hostile() > 30 else -1
		&"chase":
			out = 0 if st == EnemyAi.State.WINDUP and t >= 50 else -1
		&"weave":
			out = 0 if st == EnemyAi.State.ACTIVE and t >= 200 else -1
		&"storm":
			out = 0 if st == EnemyAi.State.ACTIVE and t >= 22 else -1
		&"warn":
			out = 40 if _reader.fallen_window() == WorldReader.FALLEN_WARN else -1
		&"open":
			out = 45 if _reader.fallen_window() == WorldReader.FALLEN_ON else -1
	return out


## Where the hero stands: PLAYER_AT, but out of the leap's landing once it flies (a ring landing on the hero is left
## out: the slam itself is the hit), as a dodging hero would.
func _hold_at() -> Vector2:
	var i := FinalLab.body(_world)
	if PLAN[_k][1] == &"quake" and i >= 0 and _world.actors.state[i] != EnemyAi.State.WINDUP:
		return PLAYER_AT + Vector2(5.0, 2.0)
	return PLAYER_AT


func _hostile() -> int:
	var n := 0
	for p in _world.projectiles.size():
		if _world.projectiles.team[p] != ActorStore.TEAM_PLAYER:
			n += 1
	return n


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if not _done:
		for n in TICKS_PER_FRAME:
			_world.actors.set_pos(0, _hold_at())
			_world.step(InputFrame.new())
			_ticks += 1
			_view.sync()
			_bar.sync(_reader)
			if _after < 0:
				_after = _moment(spec[1])
			if _after == 0:
				_done = true
				break
			if _after > 0:
				_after -= 1
			if _ticks >= _limit:
				push_error("final_boss_n2 shot %d: its moment never came" % (_k + 1))
				_done = true
				break
		_frame(spec)
		return false
	_settle += 1
	_frame(spec)
	if _settle < 10:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[0]]
	img.save_jpg(path, 0.85)
	print("final_boss_n2: ", path, " (tick ", _world.tick, ")")
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
	_view.rig.snap_to(SimPlane.to_3d(b * 0.5 + _world.player_pos() * 0.5))
