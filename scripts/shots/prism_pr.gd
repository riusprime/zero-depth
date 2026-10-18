extends SceneTree
## v0.8.0 PR (owner O84, 2026-10-18: "the lasers on a cross should be 15% slower, the all small balls he shoots should
## be shooted on a predictable pattern we should have 3 different patters … never make small balls and lasers at the
## same time"): renders the Prism's fairer second phase for the owner in the real game view (WorldViewRoot drawing the
## final arena, the iso camera, the boss bar) of a real World built as the game builds it (FinalLab), the fight
## jumped to its second body (FinalBoss.jump, as the dev panel and the Playground do): each of her three orb spells
## mid-flight (the ring, the spiral, the flower; no beam anywhere) and the slower Cross turning (no orb anywhere).
## Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/prism_pr.gd -- <n>
## `-- <n>` renders shot n alone (one at a time on a shared machine). Writes build/shots/v0.8.0/pr/<n>_<label>.jpg and
## prints each shot's tick, the spell's active tick and the orbs and beams in the air.

## [label, the spell started (attack id), its active tick to stop on, camera size].
const PLAN := [
	["orb_ring_mid_flight", &"crown_ring", 130, 22.0],
	["orb_spiral_mid_flight", &"crown_spiral", 120, 22.0],
	["orb_flower_mid_flight", &"crown_flower", 140, 22.0],
	["slower_cross_turning", &"cross_ring", 100, 26.0],
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
var _settle := 0
var _done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_only = int(a) - 1
	if _only >= 0:
		_k = _only
	_dir = "res://build/shots/v0.8.0/pr/"
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
	FinalLab.past_rise(_world)
	FinalBoss.jump(_world, 1)
	FinalLab.past_rise(_world)
	var i := FinalLab.body(_world)
	_world.actors.set_pos(i, Vector2.ZERO)
	var t := BossAi.table_of(_world, i)
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


## True once the spell is `st` ticks into its active time (the held hero clear of the beams, for the Cross).
func _come(st: int) -> bool:
	var i := FinalLab.body(_world)
	if i < 0 or _world.actors.state[i] != EnemyAi.State.ACTIVE or _world.actors.state_t[i] < st:
		return false
	var atk := BossAi.attack_of(_world, i)
	if atk.move != BossAttackTable.Move.CROSS:
		return true
	for o in BossPrism.beams(_world, i, _world.actors.state_t[i]):
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
			if _come(int(spec[2])):
				_done = true
				break
			if _ticks >= 1200:
				push_error("prism_pr shot %d: its moment never came" % (_k + 1))
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
	var orbs := 0
	for p in _reader.projectile_count():
		if _reader.projectile_look(p) == "crown_orb":
			orbs += 1
	var c := _reader.boss_cross(i)
	var beams: int = 0 if c.is_empty() or c["window"] else (c["arms"] as Array).size()
	print(
		(
			"prism_pr: %s (tick %d, active tick %d, orbs in the air %d, beams %d)"
			% [path, _world.tick, _world.actors.state_t[i], orbs, beams]
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
