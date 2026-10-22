extends SceneTree
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F2-F4): renders the final boss for the owner in the real game view
## (WorldViewRoot drawing the final arena, the iso camera, the boss bar) of a real World built as the game builds it
## after End the run (FinalLab: the run's last floor, the bodies scaled, FinalArenaScenario): the round arena from
## above and from the hero's place, the Colossus rising, its hooks wound up and landing, the two-fisted slam, the leap's
## landing and shockwave ring, the chasing spike lines, the radial burst, a boulder in the air, the shatter, the Prism
## rising from the shards, and the Nemesis stand-in. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/final_boss.gd -- <n>
## `-- <n>` renders shot n alone (one at a time on a shared machine). Writes build/shots/v0.8.0/fb1/<n>_<label>.jpg.

## [label, what happens (see _begin), camera size, the camera's centre: &"origin", &"fight" or &"start"].
const PLAN := [
	["arena_overview", &"idle", 44.0, &"origin"],
	["arena_at_play_zoom", &"idle", 21.0, &"start"],
	["colossus_rising", &"rise", 17.0, &"fight"],
	["combo_hook_wound_up", &"combo_windup", 15.0, &"fight"],
	["combo_hook_lands", &"combo_strike", 15.0, &"fight"],
	["combo_two_fisted_slam", &"combo_slam", 15.0, &"fight"],
	["leap_slam_landing_shockwave", &"leap", 21.0, &"fight"],
	["spike_lines_chasing", &"chase", 21.0, &"fight"],
	["spike_burst_radial", &"burst", 21.0, &"fight"],
	["boulder_in_the_air", &"boulder", 21.0, &"fight"],
	["colossus_shatters", &"shatter", 17.0, &"fight"],
	["prism_rises_from_the_shards", &"prism_rise", 17.0, &"fight"],
	["nemesis_stand_in", &"nemesis", 15.0, &"fight"],
]
const SIZE := Vector2i(1280, 720)
const TICKS_PER_FRAME := 6
const PLAYER_AT := Vector2(3.0, -3.0)  # toward the camera from the centre

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
var _after := -1  # ticks still to step once the shot's moment came
var _player_at := PLAYER_AT
var _active_ticks := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_only = int(a) - 1
	if _only >= 0:
		_k = _only
	_dir = "res://build/shots/v0.8.0/fb1/"
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
	_player_at = PLAYER_AT
	_world.actors.set_pos(0, _player_at)
	_reader = WorldReader.new(_world)
	_ticks = 0
	_settle = 0
	_done = false
	_after = -1
	_active_ticks = 0
	_limit = 900
	_begin(PLAN[k][1])  # before the view: it first sees the world as the shot starts
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


## Readies the world for the shot: the Colossus past its rise and quiet (its own picks off), then the move shown.
func _begin(what: StringName) -> void:
	if what == &"rise":
		_after = 50
		return
	FinalLab.past_rise(_world)
	if what == &"nemesis":
		FinalBoss.jump(_world, 2)
		FinalLab.past_rise(_world)
	_quiet()
	var i := FinalLab.body(_world)
	_world.actors.set_pos(i, Vector2.ZERO)
	match what:
		&"idle":
			_after = 60
		&"combo_windup", &"combo_strike", &"combo_slam":
			_attack(&"fist_combo")
		&"leap":
			_world.actors.set_pos(i, Vector2(-4.0, 3.0))
			_attack(&"leap_slam")
		&"chase":
			_world.actors.set_pos(i, Vector2(-3.0, 3.0))
			_attack(&"spike_chase_2")
		&"burst":
			_attack(&"spike_burst")
		&"boulder":
			_world.actors.set_pos(i, Vector2(-4.0, 4.0))
			_attack(&"boulder_throw_3")
		&"shatter":
			FinalLab.end_segment(_world)
			_after = 12
		&"prism_rise":
			FinalLab.end_segment(_world)
		&"nemesis":
			_attack(&"nemesis_combo")  # v0.8.0 FB3: the Nemesis's own combo (the stand-in's slash is gone)


func _quiet() -> void:
	var i := FinalLab.body(_world)
	var t := BossAi.table_of(_world, i)
	for p in t.phase_attacks.size():
		t.phase_attacks[p] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0


func _attack(id: StringName) -> void:
	var i := FinalLab.body(_world)
	_world.actors.state[i] = EnemyAi.State.MOVE
	BossAi.start_attack(_world, i, BossAi.table_of(_world, i).attack_index(id))
	_world.bosses.chained[BossAi.entry_of(_world, i)] = 1


## How many more ticks to step once the shot's moment comes (-1 until it does).
func _moment(what: StringName) -> int:
	var i := FinalLab.body(_world)
	var tg := _reader.telegraph(i) if i >= 0 else {}
	var striking := bool(tg.get("striking", false))
	var windup := i >= 0 and _reader.actor_state(i) == WorldReader.STATE_WINDUP
	var come := false
	var after := 0
	match what:
		&"combo_windup":
			come = windup and _ticks > 20
			after = 10
		&"combo_strike":
			come = striking and tg.get("shape", &"") == &"arc"
			after = 2
		&"combo_slam":
			come = striking and tg.get("shape", &"") == &"disc"
			after = 2
		&"leap":
			if i >= 0 and _reader.actor_state(i) == WorldReader.STATE_ACTIVE:
				_player_at = PLAYER_AT + Vector2(3.0, 2.0)  # the hero steps off the locked circle
			come = _hostile_shots() > 8
			after = 6
		&"chase":
			come = _active_for(i) >= 22
		&"burst":
			come = _active_for(i) >= 10
		&"boulder":
			come = _lob(tg) >= 450
		&"prism_rise":
			come = _world.final_fight.phase == 1
			after = 30
		&"nemesis":
			come = windup
			after = 12
	return after if come else -1


## Ticks the body has spent in its active state (0 outside it).
func _active_for(i: int) -> int:
	if i < 0 or _reader.actor_state(i) != WorldReader.STATE_ACTIVE:
		_active_ticks = 0
	else:
		_active_ticks += 1
	return _active_ticks


func _hostile_shots() -> int:
	var n := 0
	for k in _world.projectiles.size():
		if _world.projectiles.team[k] != ActorStore.TEAM_PLAYER:
			n += 1
	return n


func _lob(tg: Dictionary) -> int:
	var most := 0
	for item: Dictionary in tg.get("items", []):
		most = maxi(most, int((item.get("lob", {}) as Dictionary).get("progress", 0)))
	return most


func _camera(where: StringName) -> Vector2:
	match where:
		&"origin":
			return Vector2.ZERO
		&"start":
			return _world.floor_layout.start_pos * 0.55
	var i := FinalLab.body(_world)
	var b := _world.actors.pos(i) if i >= 0 else Vector2.ZERO
	return b * 0.75 + _world.player_pos() * 0.25


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if not _done:
		for n in TICKS_PER_FRAME:
			_world.actors.set_pos(0, _player_at)
			_world.step(InputFrame.new())
			_ticks += 1
			_view.sync()
			_bar.sync(_reader)
			if _after < 0:
				_after = _moment(spec[1])
			elif _after == 0:
				_done = true
				break
			else:
				_after -= 1
			if _ticks >= _limit:
				push_error("final_boss shot %d: its moment never came" % (_k + 1))
				_done = true
				break
			if _after >= 0 and _after < 12:
				break  # one tick a frame near the moment: the frame-time animation keeps up
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
	print("final_boss: ", path, " (tick ", _world.tick, ")")
	_k += 1
	if _k >= PLAN.size() or _only >= 0:
		return true
	_build(_k)
	return false


func _frame(spec: Array) -> void:
	_view.rig.view_size = float(spec[2])
	_view.rig.camera.size = float(spec[2])
	_view.rig.snap_to(SimPlane.to_3d(_camera(spec[3])))
