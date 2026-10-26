extends SceneTree
## v0.9.5 HU: the real in-run HUD with the ability squares (design A), in English and Spanish at 1920 x 1080. A Gun run
## (World seed 11, the data's runner + Gun build, Blink granted with 2 charges, the Overclock heat at 55) on the Ruins
## stage with four Chargers; the Skill is cooling (about 3 s left) and the Dash too (7.4 s of 10), so the cover and the
## seconds show. A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --resolution 1920x1080 -s scripts/shots/hu_hud.gd
## Writes build/shots/v0.9.5/hu/<en|es>.png.

const OUT := "res://build/shots/v0.9.5/hu/"
const LANGS := ["en", "es"]
const SETTLE := 10

var _w: World
var _reader: WorldReader
var _view: WorldViewRoot
var _hud: Hud
var _frame := 0
var _at := -1
var _wait := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("hu: renderer=%s" % RenderingServer.get_current_rendering_method())
	_w = _world()
	_reader = WorldReader.new(_w)
	_view = WorldViewRoot.new()
	_view.rig.view_size = 8.0
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	var repo := ContentRepository.load_all()
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	_view.setup(_reader, biome.palette, 12.0)
	_view.rig.snap_to(SimPlane.to_3d(Vector2(2.0, 0.0), 0.6))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	InputDefaults.apply()
	_hud = Hud.new()
	layer.add_child(_hud)
	for k in 6:
		_tick()


func _world() -> World:
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"gun"))
	var w := World.new(11, t)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Abilities.grant(w, Abilities.index_of_kind(w, AbilityTable.Kind.BLINK))
	var enemies := ContentCompiler.compile_enemies(repo)
	for e in enemies:
		e.speed = 0.0
	w.set_enemy_tables(enemies)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	for at: Vector2 in [
		Vector2(4.6, 0.6), Vector2(5.0, -1.4), Vector2(2.6, -1.8), Vector2(3.0, 1.8)
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


func _tick() -> void:
	_w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))
	_w.kit.skill_cd = 190
	_w.dash_cooldown_left = 444
	_w.ab.blink_charges = 2
	_view.sync()
	_hud.sync(_reader)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 3000:
		print("hu: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_grab()
		return false
	_at += 1
	if _at >= LANGS.size():
		print("hu: done")
		quit(0)
		return true
	TranslationServer.set_locale(LANGS[_at])
	_tick()
	_wait = SETTLE
	return false


func _grab() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s.png" % LANGS[_at]
	img.save_png(path)
	print("hu: ", path, " ", img.get_size())
