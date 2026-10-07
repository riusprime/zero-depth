extends SceneTree
## The v0.3.5 K shots: the Vent and Skill buttons through the iso camera with the real HUD (the skill pip beside the
## HP bar, the vent hint beside the heat meter), the Lunge Cleave (mid-lunge with its forecast fan, then the cleave)
## or the Scatter Blast (its tracers). Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/kit.gd -- build=blade
## (or build=gun). Every effect comes from real ticks with the Skill press. Writes build/shots/v0.3.5/kit/.

const OUT := "res://build/shots/v0.3.5/kit/"

var _build := &"blade"
var _frames := 0
var _step := 0
var _wait := 0
var _view: WorldViewRoot
var _hud: Hud
var _reader: WorldReader
var _w: World


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("build="):
			_build = StringName(a.trim_prefix("build="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_w = _world()
	_reader = WorldReader.new(_w)
	_view = WorldViewRoot.new()
	_view.rig.view_size = 8.0
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(_reader, Gallery.palette_of(&"night_rocks"), 10.0)
	_view.rig.snap_to(SimPlane.to_3d(Vector2(2.0, 0.0), 0.6))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	InputDefaults.apply()
	_hud = Hud.new()
	layer.add_child(_hud)
	_hud.sync(_reader)


func _world() -> World:
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", _build))
	var w := World.new(11, t)
	var enemies := ContentCompiler.compile_enemies(repo)
	for e in enemies:
		e.speed = 0.0
	w.set_enemy_tables(enemies)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	for at: Vector2 in [
		Vector2(4.6, 0.6), Vector2(5.0, -1.0), Vector2(2.2, 0.4), Vector2(2.6, -0.9)
	]:
		w.add_enemy(ActorStore.Kind.CHARGER, at)
	for i in range(1, w.actors.size()):
		w.actors.state[i] = EnemyAi.State.MOVE
		w.actors.cd[i] = 1 << 30
		w.actors.invuln[i] = 0
		w.actors.hp[i] = 9999
		w.actors.max_hp[i] = 9999
	w.heat.milli = 55 * HeatTable.MILLI
	return w


func _tick(pressed: int = 0) -> void:
	_w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, pressed))
	_view.sync()
	_hud.sync(_reader)


## Sets up step `_step`; returns frames to wait, or -1 when done.
func _begin() -> int:
	match _step:
		0:
			_tick()
			return 4
		1:
			_tick(InputFrame.SKILL)
			for k in 5 if _build == &"blade" else 0:
				_tick()
			return 1
		2:
			if _build != &"blade":
				return -1
			for k in 8:
				_tick()
			return 1
	return -1


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	if _wait == 0:
		var n := _begin()
		if n < 0:
			quit(0)
			return false
		_wait = _frames + n
		return false
	if _frames < _wait:
		return false
	var path := OUT + "kit_%s_%d.png" % [_build, _step]
	root.get_texture().get_image().save_png(path)
	print("kit: %s skill=%s" % [path, _reader.skill_state().get("running", -1)])
	_step += 1
	_wait = 0
	return false
