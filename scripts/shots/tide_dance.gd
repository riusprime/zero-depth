extends SceneTree
## Renders the Tidecaller's dance for the owner, in the real game view (WorldViewRoot and the HUD over TideLab's walled
## 24 m room, the iso camera) of a real World stepped tick by tick (the Tidecaller's floor look):
##   a_riptide.png    a Riptide warning: three strips filling with water, the dry one clear and edged;
##   b_high_tide.png  the High Tide flooding: the water everywhere but the dry circle, its ring of time left, the
##                    hint arrow on it, the edge glow on the hero outside it;
##   c_maelstrom.png  the Maelstrom: the whirlpool turning round the Tidecaller and its dark eye.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/tide_dance.gd
## Writes build/shots/<version>/tide_dance/ and prints each path with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const BOSS_AT := Vector2(-6.0, 6.0)
const NEVER := 9
const SETTLE := 14

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _hud: Hud
var _reader: WorldReader
var _boss := -1
var _stage := 0
var _wait := 12
var _dir := ""
var _hero := Vector2(3.0, -3.0)
var _run := 0


func _initialize() -> void:
	_dir = "res://build/shots/%s/tide_dance/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	TranslationServer.set_locale("en")
	var repo := ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var s := TideLab.fight(_hero, BOSS_AT)
	_world = s[0]
	_boss = s[1]
	TideLab.hush(_world, _boss)
	var d := TideLab.dance(_world, _boss)
	d.ht_phase = NEVER
	d.mael_phase = NEVER
	TideLab.set_phase(_world, _boss, 1)
	_world.step(InputFrame.new())
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"frozen_shore")  # floor 4, the Tidecaller's
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.stage.look = biome.look
	_view.setup(_reader, biome.palette, 14.0)
	_view.rig.view_size = 26.0
	_view.rig.camera.size = 26.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(0.0, 0.0)))
	_view.rig.set_process(false)
	_view.rig.set_physics_process(false)
	_view.rig.camera.current = true
	_view.tide_dance.set_process(false)
	_view.maelstrom.set_process(false)
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
		_world.actors.hp[0] = _world.actors.max_hp[0]
		_world.step(InputFrame.new())
		_view.sync()
		_view.tide_dance.advance(1.0 / 60.0)
		_view.maelstrom.advance(1.0 / 60.0)
		_hud.sync(_reader)


func _until(effect: StringName, limit: int) -> void:
	var seq := (
		_world.events_since(0).back().seq as int if not _world.events_since(0).is_empty() else 0
	)
	for k in limit:
		if not JudgeLab.effects(_world, effect, seq).is_empty():
			return
		_step(1)


func _save(file: String, note: String) -> void:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + file
	img.save_png(path)
	print("tide_dance: ", ProjectSettings.globalize_path(path), "  ", note)


func _process(_delta: float) -> bool:
	if _run > 0:
		_step(1)
		_run -= 1
		return false
	if _wait > 0:
		_wait -= 1
		_hud.sync(_reader)
		return false
	match _stage:
		0:
			_until(BossDance.RIP_CAST, 700)
			_run = 80
			_wait = SETTLE
		1:
			var rip: Dictionary = _reader.boss_dance()["riptide"]
			_save(
				"a_riptide.png",
				(
					"tick %d cast %d safe %d struck %s warn %d hero strip %d"
					% [
						_world.tick,
						rip["cast"],
						rip["safe"],
						rip["struck"],
						rip["warn"],
						TideLab.strip_at(_world, _hero)
					]
				)
			)
			# The High Tide next: Riptide off, phase 3's High Tide on
			var d := TideLab.dance(_world, _boss)
			d.rip_phase = NEVER
			d.ht_phase = 2
			_world.boss_fight.dance_rip_from = -1
			TideLab.set_phase(_world, _boss, 2)
			_hero = Vector2(7.0, -6.0)
			_until(BossDance.HT_FLOOD, 900)
			_run = 50
			_wait = SETTLE
		2:
			var ht: Dictionary = _reader.boss_dance()["high_tide"]
			_save(
				"b_high_tide.png",
				(
					"tick %d centre %s radius %.1f flood %d left %d inside %s hints %d edge glow %s"
					% [
						_world.tick,
						ht["centre"],
						ht["radius"],
						ht["flood"],
						ht["left"],
						ht["inside"],
						_hud.objective_hints.shown().size(),
						_hud.tide_flood.active
					]
				)
			)
			_world.boss_fight.dance_ht_from = -1
			_world.objectives.clear(ObjectiveMarkers.TIDE_DRY)
			var d := TideLab.dance(_world, _boss)
			d.ht_phase = NEVER
			d.mael_phase = 2
			_hero = BOSS_AT + Vector2(7.0, -2.0)
			_run = 90
			_wait = SETTLE
		3:
			var m: Dictionary = _reader.boss_dance()["maelstrom"]
			_save(
				"c_maelstrom.png",
				(
					"tick %d centre %s spin %d around %.2f inward %.2f eye %.2f m"
					% [_world.tick, m["centre"], m["spin"], m["around"], m["inward"], m["eye"]]
				)
			)
			quit(0)
			return true
	_stage += 1
	return false
