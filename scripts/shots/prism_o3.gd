extends SceneTree
## v0.10.5 O3 (owner L6, 2026-11-01: "Needs something cooler while he's down and not on the dodging pattern"; "Boring
## pattern"; O3_PRISM.md): renders the Prism's last phase for the owner in the real game view (WorldViewRoot drawing
## the final arena, the iso camera, the boss bar) of a real World built as the game builds it (FinalLab), the fight
## jumped to its second body (FinalBoss.jump) and her HP under half (her last phase): the Facet Lances' telegraph
## (one lance striking, the next locked, the next ones tracking the hero) and the Shattered Kneel (her core open, the
## crack part filled, the hero inside the core's reach). Built from prism_pr.gd. Needs a renderer:
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000 -s scripts/shots/prism_o3.gd
## `-- <n>` renders shot n alone. Writes build/shots/v0.10.5/o3/<n>_<label>.jpg and prints each shot's tick and state.

## [label, the spell started (attack id), its active tick to stop on, camera size, the hero's spot, the crack's share
## to deal (per mille, the world's own hit)].
const PLAN := [
	["facet_lances_telegraph", &"facet_lances", 58, 24.0, Vector2(4.0, -4.0), 0],
	["shattered_kneel_core_open", &"prism_kneel", 70, 16.0, Vector2(2.6, -2.6), 600],
]
const SIZE := Vector2i(1280, 720)
const TICKS_PER_FRAME := 6

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _reader: WorldReader
var _view: WorldViewRoot
var _bar: BossBar
var _k := 0
var _only := -1
var _dir := ""
var _ticks := 0
var _settle := 0
var _done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_only = int(a) - 1
	if _only >= 0:
		_k = _only
	_dir = "res://build/shots/v0.10.5/o3/"
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
		_bar.get_parent().queue_free()
	_world = FinalLab.arena(FinalLab.run_state(4242))
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_world.actors.set_pos(0, PLAN[k][4])
	_reader = WorldReader.new(_world)
	_ticks = 0
	_settle = 0
	_done = false
	FinalLab.past_rise(_world)
	FinalBoss.jump(_world, 1)
	FinalLab.past_rise(_world)
	var i := FinalLab.body(_world)
	_world.actors.set_pos(i, Vector2.ZERO)
	var t := BossAi.table_of(_world, i)
	_world.actors.hp[i] = _world.actors.max_hp[i] * 45 / 100  # her last phase
	_world.step(InputFrame.new())
	BossAi.start_attack(_world, i, t.attack_index(PLAN[k][1]))
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var def: FinalArenaDefinition = _repo.get_def(&"final_arena", &"hollow_arena")
	_view.stage.mood = def.mood
	_view.setup(_reader, def.palette, _reader.final_arena_radius() + 4.0)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	var layer := CanvasLayer.new()
	_vp.add_child(layer)
	var ui := Control.new()
	ui.size = Vector2(SIZE)
	layer.add_child(ui)
	_bar = BossBar.new()
	ui.add_child(_bar)


## True once the spell is `st` ticks into its active time; the kneel's crack is dealt as it goes down.
func _come(spec: Array) -> bool:
	var i := FinalLab.body(_world)
	if i < 0 or _world.actors.state[i] != EnemyAi.State.ACTIVE:
		return false
	var st := _world.actors.state_t[i]
	if st == 2 and int(spec[5]) > 0:
		var atk := BossAi.attack_of(_world, i)
		FinalLab.hit(
			_world, _world.actors.max_hp[i] * atk.crack_permille / 1000 * int(spec[5]) / 1000
		)
	return st >= int(spec[2])


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if not _done:
		for n in TICKS_PER_FRAME:
			_world.actors.set_pos(0, spec[4])
			_world.step(InputFrame.new())
			_ticks += 1
			_view.sync()
			_bar.sync(_reader)
			if _come(spec):
				_done = true
				break
			if _ticks >= 1200:
				push_error("prism_o3 shot %d: its moment never came" % (_k + 1))
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
	var i := FinalLab.body(_world)
	var l := _reader.boss_lances(i)
	var kn := _reader.boss_kneel(i)
	print(
		(
			(
				"prism_o3: %s (tick %d, active tick %d, lances %s, kneel %s, "
				+ "drawn: lines %d strikes %d facets %d core %s crack lit %d)"
			)
			% [
				path,
				_world.tick,
				_world.actors.state_t[i],
				(l.get("lances", []) as Array).map(
					func(x: Dictionary) -> Array: return [x["k"], x["phase"]]
				),
				kn,
				_view.prism_views.last.lance_lines(),
				_view.prism_views.last.lance_strikes(),
				_view.prism_views.last.facets_drawn(),
				_view.prism_views.last.core_drawn(),
				_view.prism_views.last.crack_lit(),
			]
		)
	)
	_k += 1
	if _k >= PLAN.size() or _only >= 0:
		return true
	_build(_k)
	return false


func _frame(spec: Array) -> void:
	_view.rig.view_size = float(spec[3])
	_view.rig.camera.size = float(spec[3])
	_view.rig.snap_to(SimPlane.to_3d(_world.player_pos() * 0.2))
