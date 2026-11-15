extends SceneTree
## Renders the Clockwork Judge's time mechanics for the owner, in the real game view (WorldViewRoot and the HUD over
## a walled 24 m room, the iso camera) of a real World stepped tick by tick (Starfall's look, the Judge's floor):
##   a_time_wave.png   the Time Wave just landed: its ring crossing the room, the three hour orbs, their arrows;
##   c_hud_slowed.png  the HUD's corner, twice its size: the slowed state with one orb's share won back;
##   b_phase_2.png     the second phase: the stopped gears, a slow field with the hero's shots inside it, the pale
##                     copy and the Bell's ring closing on it.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/judge_time.gd
## Writes build/shots/<version>/judge_time/ and prints each path with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const HERO_AT := Vector2(-5.0, -2.0)
const BOSS_AT := Vector2(5.0, 2.5)
const DT := 1.0 / 60.0
## Frames left to the renderer (and the pack's own animations) before a capture.
const SETTLE := 14

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _hud: Hud
var _reader: WorldReader
var _boss := -1
var _stage := 0
## The first frames are the view's own: its pack effects' warm-up draws and goes back to the pool.
var _wait := 12
var _dir := ""
var _hero := HERO_AT
var _shoot := false
var _run := 0


func _initialize() -> void:
	_dir = "res://build/shots/%s/judge_time/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	TranslationServer.set_locale("en")
	var repo := ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var s := JudgeLab.fight(HERO_AT, BOSS_AT)
	_world = s[0]
	_boss = s[1]
	JudgeLab.hush(_world, _boss)
	BossAi.table_of(_world, _i()).speed = 0.0
	_world.boss_fight.time_bell_due = 1 << 29
	_world.boss_fight.time_field_due = 1 << 29
	_world.step(InputFrame.new())
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"starfall")
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.stage.look = biome.look
	_view.setup(_reader, biome.palette, 14.0)
	_view.rig.view_size = 21.0
	_view.rig.camera.size = 21.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(0.0, 0.0)))
	_view.rig.set_process(false)
	_view.rig.set_physics_process(false)
	_view.rig.camera.current = true
	_view.judge_time.set_process(false)
	_view.judge_rewind.set_process(false)
	_hud = Hud.new()
	_vp.add_child(_hud)
	_hud.objective_hints.gate = _always


func _always(_reason: StringName) -> bool:
	return true


func _i() -> int:
	return _world.actors.index_of(_boss)


func _step(n: int) -> void:
	for k in n:
		_world.actors.set_pos(0, _hero)
		var aim := Kin.angle_of(_world.actors.pos(_i()) - _hero)
		var held := InputFrame.SHOOT if _shoot else 0
		_world.step(InputFrame.make(Vector2i.ZERO, aim, 600, held, 0))
		_view.sync()
		_view.judge_time.advance(DT)
		_view.judge_rewind.advance(DT)
		_hud.sync(_reader)


func _save(file: String, img: Image, note: String) -> void:
	var path := _dir + file
	img.save_png(path)
	print("judge_time: ", ProjectSettings.globalize_path(path), "  ", note)


func _frame() -> Image:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _process(_delta: float) -> bool:
	if _run > 0:  # a tick a frame, so the pack's one-shot effects play out in their own time
		_step(1)
		_run -= 1
		return false
	if _wait > 0:
		_wait -= 1
		_hud.sync(_reader)  # the camera has settled: the arrows sit where this frame draws their targets
		return false
	match _stage:
		0:
			_view.judge_time.set_process(false)  # stepped here, a tick at a time
			_view.judge_rewind.set_process(false)
			_step(20)
			BossLab.start(_world, _i(), &"time_wave")
			for k in 100:
				if not JudgeLab.effects(_world, &"time_wave").is_empty():
					break
				_step(1)
			_step(8)
			_wait = SETTLE
		1:
			var t := _reader.boss_time()
			_save(
				"a_time_wave.png",
				_frame(),
				(
					"tick %d cut %d orbs %d hints %d ring %.1f m, pack effects held %d"
					% [
						_world.tick,
						t["cut"],
						_reader.boss_pickups().size(),
						_hud.objective_hints.shown().size(),
						_view.judge_time.wave_radius(),
						_view.judge_time.hold.count()
					]
				)
			)
			_hero = _reader.boss_pickups()[0]["centre"]
			_step(2)
			_hero = HERO_AT
			_run = 60
			_wait = SETTLE
		2:
			var img := _frame()
			var corner := img.get_region(Rect2i(0, SIZE.y - 300, 560, 300))
			corner.resize(1120, 600, Image.INTERPOLATE_LANCZOS)
			_save(
				"c_hud_slowed.png",
				corner,
				(
					"cut %d line '%s' pips %d won %d"
					% [
						_reader.boss_attack_slow(),
						_hud.attack_slow.line(),
						_hud.attack_slow.pips(),
						_hud.attack_slow.pips_won()
					]
				)
			)
			# The second phase: the hero walks a line (the copy trails it), the Judge casts again as it walks.
			JudgeLab.set_phase(_world, _boss, 1)
			for k in 240:
				_hero = Vector2(-9.5 + 0.02 * k, 3.0 - 0.02 * k)
				_step(1)
			BossLab.start(_world, _i(), &"time_wave")
			var seq := _world.events_since(0).back().seq as int
			for k in 100:
				if not JudgeLab.effects(_world, &"time_wave", seq).is_empty():
					break
				_hero += Vector2(0.02, -0.02)
				_step(1)
			_world.boss_fight.time_bell_due = _world.tick
			var mid := (_hero + _world.actors.pos(_i())) * 0.5 + Vector2(0.4, 0.3)
			BossShotFields.place(_world, _boss, BossAi.table_of(_world, _i()).time.field, mid)
			_shoot = true
			_run = 75
			_wait = SETTLE
		3:
			var t := _reader.boss_time()
			var inside := 0
			var fields := _reader.boss_shot_fields()
			for p in _reader.projectile_count():
				for f: Dictionary in fields:
					if _reader.projectile_pos(p).distance_to(f["centre"]) < float(f["radius"]):
						inside += 1
			_save(
				"b_phase_2.png",
				_frame(),
				(
					"tick %d gears %d fields %d shots %d (in a field %d) rewind %s bell %d copy %s"
					% [
						_world.tick,
						(t["gears"] as Array).size(),
						fields.size(),
						_reader.projectile_count(),
						inside,
						t["rewind"],
						t.get("bell", -1),
						t.get("copy", Vector2.ZERO)
					]
				)
			)
			quit(0)
			return true
	_stage += 1
	return false
