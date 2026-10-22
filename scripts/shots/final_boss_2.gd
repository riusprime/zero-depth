extends SceneTree
## v0.8.0 FB2 (owner O17; FINAL_BOSS.md F5, F7): renders the Prism for the owner in the real game view (WorldViewRoot
## drawing the final arena, the iso camera, the boss bar) of a real World built as the game builds it after End the run
## (FinalLab), the fight jumped to its second body (FinalBoss.jump, as the dev panel and the Playground do): her float
## with the shards orbiting, the Cross's spin-up (its aim lines), the Cross turning, orbs between the beams, a fast
## bolt's aim line, and the window (the beams out, the ring). Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/final_boss_2.gd -- <n>
## `-- <n>` renders shot n alone (one at a time on a shared machine). Writes build/shots/v0.8.0/fb2/<n>_<label>.jpg.
## v0.8.0 PR (O84): the Cross no longer fires orbs and its bolts fire only in the window, so shots 4-5 reproduce only
## at FB2's commit; the PR look is scripts/shots/prism_pr.gd.

## [label, the Cross started (attack id, or &"" none), the moment (see _moment), camera size].
const PLAN := [
	["prism_floating_shards_orbiting", &"", &"idle", 15.0],
	["cross_spin_up_aim_lines", &"cross_ring", &"windup", 21.0],
	["cross_turning", &"cross_ring", &"spin", 25.0],
	["orbs_between_the_beams", &"cross_spiral", &"orbs", 25.0],
	["fast_bolt_aim_line", &"cross_flower", &"bolt", 21.0],
	["window_beams_out_strike_now", &"cross_ring", &"window", 21.0],
]
const SIZE := Vector2i(1280, 720)
const TICKS_PER_FRAME := 6
const PLAYER_AT := Vector2(4.0, -4.0)  # toward the camera from the centre

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
var _limit := 0
var _settle := 0
var _done := false
var _after := -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_only = int(a) - 1
	if _only >= 0:
		_k = _only
	_dir = "res://build/shots/v0.8.0/fb2/"
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
	_world.actors.set_pos(0, PLAYER_AT)
	_reader = WorldReader.new(_world)
	_ticks = 0
	_settle = 0
	_done = false
	_after = -1
	_limit = 1200
	FinalLab.past_rise(_world)
	FinalBoss.jump(_world, 1)
	FinalLab.past_rise(_world)
	_quiet()
	var i := FinalLab.body(_world)
	_world.actors.set_pos(i, Vector2.ZERO)
	var id: StringName = PLAN[k][1]
	if id != &"":
		BossAi.start_attack(_world, i, BossAi.table_of(_world, i).attack_index(id))
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


## Her own picks off: each shot starts the Cross it shows.
func _quiet() -> void:
	var t := BossAi.table_of(_world, FinalLab.body(_world))
	for p in t.phase_attacks.size():
		t.phase_attacks[p] = PackedInt32Array()


## How many more ticks to step once the shot's moment comes (-1 until it does).
func _moment(what: StringName) -> int:
	var i := FinalLab.body(_world)
	var c := _reader.boss_cross(i) if i >= 0 else {}
	var st := _world.actors.state_t[i] if i >= 0 else 0
	var come := false
	var after := 0
	match what:
		&"idle":
			come = _ticks >= 90
		&"windup":
			come = not c.is_empty() and c["winding"] and int(c["progress"]) >= 700
		&"spin":
			come = _turning(c) and st >= 70 and _clear_of_beams(i, st)
		&"orbs":
			come = _turning(c) and st >= 150 and _clear_of_beams(i, st)
		&"bolt":
			var b: Dictionary = c.get("bolt", {}) if not c.is_empty() else {}
			come = not b.is_empty() and int(b["progress"]) >= 600
		&"window":
			come = not c.is_empty() and c["window"] and int(c["progress"]) >= 150
	return after if come else -1


func _turning(c: Dictionary) -> bool:
	return not c.is_empty() and not c["winding"] and not c["window"]


## The held hero stands between two arms (the shot doesn't show a beam through them).
func _clear_of_beams(i: int, st: int) -> bool:
	for o in BossPrism.beams(_world, i, st):
		if (
			Collide.circle_vs_obb(_world.player_pos(), _world.player.radius_m + 0.6, o)
			!= Vector2.ZERO
		):
			return false
	return true


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if not _done:
		for n in TICKS_PER_FRAME:
			_world.actors.set_pos(0, PLAYER_AT)
			_world.step(InputFrame.new())
			_ticks += 1
			_view.sync()
			_bar.sync(_reader)
			if _after < 0:
				_after = _moment(spec[2])
			if _after == 0:
				_done = true
				break
			if _after > 0:
				_after -= 1
			if _ticks >= _limit:
				push_error("final_boss_2 shot %d: its moment never came" % (_k + 1))
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
	print("final_boss_2: ", path, " (tick ", _world.tick, ")")
	_k += 1
	if _k >= PLAN.size() or _only >= 0:
		return true
	_build(_k)
	return false


func _frame(spec: Array) -> void:
	_view.rig.view_size = float(spec[3])
	_view.rig.camera.size = float(spec[3])
	var i := FinalLab.body(_world)
	var b := _world.actors.pos(i) if i >= 0 else Vector2.ZERO
	_view.rig.snap_to(SimPlane.to_3d(b * 0.7 + _world.player_pos() * 0.3))
