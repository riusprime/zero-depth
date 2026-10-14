extends SceneTree
## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards", F7; FINAL_BOSS.md F6-F8): renders the Nemesis for the owner in
## the real game view (WorldViewRoot drawing the final arena, the iso camera, the boss bar) of a real World built as
## the game builds it after End the run (FinalLab), on a Blade run holding three wand cards (Wave L3, Double Slash L2,
## Whirl L4: NemesisLab grants them as found cards), the fight jumped to its third body (FinalBoss.jump, as the dev
## panel and the Playground do): the Nemesis in its mirror stance across the arena, its answer to the hero's dash, a
## card's cast (its name over its head, its swing and crescents' lines on the ground), its crescents flying, its fall
## (the last body: the fight won), and the run's end panel the game shows for that win (EndPanel with the recap Main
## builds: the true ending line). Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/final_boss_3.gd -- <n>
## `-- <n>` renders shot n alone (one at a time on a shared machine). Writes build/shots/v0.8.0/fb3/<n>_<label>.jpg.

## [label, the moment (see _moment), camera size].
const PLAN := [
	["nemesis_mirroring_across_the_arena", &"mirror", 25.0],
	["nemesis_answers_the_dash", &"dash", 17.0],
	["card_cast_whirl_named_and_locked", &"cast", 15.0],
	["card_cast_wave_crescents_flying", &"crescents", 17.0],
	["nemesis_falls_the_fight_is_won", &"fall", 17.0],
	["victory_recap_true_ending", &"recap", 17.0],
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
var _hold := true


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_only = int(a) - 1
	if _only >= 0:
		_k = _only
	_dir = "res://build/shots/v0.8.0/fb3/"
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
	_world = NemesisLab.world(4343, &"blade", CARDS)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.set_pos(0, PLAYER_AT)
	_reader = WorldReader.new(_world)
	_ticks = 0
	_settle = 0
	_done = false
	_after = -1
	_limit = 1500
	_hold = true
	_quiet()
	var i := FinalLab.body(_world)
	var f := _world.final_fight
	match PLAN[k][1]:
		&"mirror":
			f.stance = BossTable.STANCE_MIRROR
			f.stance_t = 1 << 20
		&"dash":
			_world.actors.set_pos(i, PLAYER_AT + Vector2(-4.5, -1.0))
			f.stance = BossTable.STANCE_ECHO
			f.stance_t = 1 << 20
		&"cast":
			_world.actors.set_pos(i, PLAYER_AT + Vector2(-2.2, 0.4))
			_start_card(&"whirl")
		&"crescents":
			_world.actors.set_pos(i, PLAYER_AT + Vector2(-6.0, 1.0))
			_start_card(&"echo_slash")
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


## Its own picks off (each shot starts what it shows); the stance clock held.
func _quiet() -> void:
	var t := BossAi.table_of(_world, FinalLab.body(_world))
	for p in t.phase_attacks.size():
		t.phase_attacks[p] = PackedInt32Array()


func _start_card(id: StringName) -> void:
	var i := FinalLab.body(_world)
	for n in _world.final_fight.casts.size():
		if _world.final_fight.casts[n].card_id == id:
			BossAi.start_attack(
				_world,
				i,
				BossAi.table_of(_world, i).attack_index(StringName("nemesis_card_%d" % (n + 1)))
			)


## The frame the shot steps with: the hero held at PLAYER_AT, except the dash shot's dash (on tick 30).
func _input() -> InputFrame:
	if PLAN[_k][1] == &"dash" and _ticks == 30:
		_hold = false
		return NemesisLab.dash(Vector2(0, 1))
	if _hold:
		_world.actors.set_pos(0, PLAYER_AT)
	return InputFrame.new()


## How many more ticks to step once the shot's moment comes (-1 until it does).
func _moment(what: StringName) -> int:
	var i := FinalLab.body(_world)
	var n := _reader.nemesis(i) if i >= 0 else {}
	var f := _world.final_fight
	var out := -1
	match what:
		&"mirror":
			var to := f.home * 2.0 - _world.player_pos()
			if i >= 0 and _ticks > 120 and _world.actors.pos(i).distance_to(to) < 0.4:
				out = 0
		&"dash":
			if not n.is_empty() and n["dashing"] and f.dash_t <= 5:
				out = 0
		&"cast":
			if not n.is_empty() and int(n["cast_progress"]) >= 750:
				out = 0
		&"crescents":
			var flying := 0
			for p in _world.projectiles.size():
				if _world.projectiles.look[p] == NemesisCast.LOOK_CRESCENT:
					flying += 1
			if flying > 0 and i >= 0 and _world.actors.state_t[i] >= 10:
				out = 0
		&"fall", &"recap":
			if _ticks == 20 and i >= 0:
				FinalLab.hit(_world, _world.actors.hp[i] * 10)
			if f.won:
				out = 24
				if what == &"recap":
					_recap()
	return out


## The end panel the game shows for this win, with the recap Main builds (Main.run_recap's keys) from this world.
func _recap() -> void:
	var run := FinalLab.run_state(4343, &"blade")
	var names: Array[String] = []
	for idx in _reader.items_owned():
		names.append(String(_reader.item_name_key(idx)))
	var recap := {
		"floor": run.floor_index,
		"floors": run.table.floors,
		"seconds": float(run.total_ticks(_world)) / SimTick.TICKS_PER_SECOND,
		"kills": run.total_kills(_world),
		"items": names,
		"routes": run.routes.duplicate(),
		"loop": run.loop,
		"loops_cleared": run.loops_cleared(_world),
		"true_ending": run.final_fight and _reader.final_won(),
		"final_reached": run.final_fight,
		"threat": _reader.threat(),
		"threat_peak": _reader.threat_peak(),
	}
	var end := EndPanel.new(true, -1, &"", recap)
	_ui.add_child(end)


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if not _done:
		for n in TICKS_PER_FRAME:
			var frame := _input()
			_world.step(frame)
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
				push_error("final_boss_3 shot %d: its moment never came" % (_k + 1))
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
	print("final_boss_3: ", path, " (tick ", _world.tick, ")")
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
