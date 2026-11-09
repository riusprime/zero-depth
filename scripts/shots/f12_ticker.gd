extends SceneTree
## v0.11.0 F12: one in-combat frame with the depths skull and two notice-ticker lines (an item and an element pair)
## under the top plate, English and Spanish, 1920 x 1080. main.tscn's dev stage run, enemies around the hero, a real
## phase announcement. A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --resolution 1920x1080 --position -10000,-10000 -s scripts/shots/f12_ticker.gd
## Writes build/shots/v0.11.0/f12/ticker_<en|es>.png.

const OUT := "res://build/shots/v0.11.0/f12/"
const MAX_FRAMES := 12000
const MIN_ENEMIES := 14
const CLOSE_IN := 400
const M := 1410
const ITEM := &"gun_homing"
const PAIR := 0

var _main: Main
var _frame := 0
var _phase := 0
var _wait := 0
var _lang := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale("en")
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > MAX_FRAMES:
		push_error("f12 ticker: gave up")
		quit(1)
		return false
	var dr := _main.driver
	if dr == null:
		if _frame == 3:
			_main.start_stage()
		return false
	dr.world.actors.invuln[0] = 2
	_wait -= 1
	if _wait <= 0:
		_step(dr)
	return false


func _step(dr: Variant) -> void:
	var hud: Hud = _main.get_node("UI/Hud")
	match _phase:
		0:
			if dr.reader.arriving():
				return
			dr.world.shards = 120
			dr.world.kills = 37
			dr.world.run_ticks = SimTick.seconds_to_ticks(250.0)
			dr.world.catch_up.enemy = M
			_main.toast.visible = false
			_main.hints.set_covered(true)
			_phase = 1
		1:
			if dr.reader.enemies_alive() < MIN_ENEMIES and _frame < 6000:
				return
			hud.phase_hud._queue.append(PackedStringArray(["HUD_NEW_ENEMY", "ENEMY_CHARGER"]))
			_phase = 2
			_wait = CLOSE_IN
		2:
			_lang = 0
			_show(dr, hud)
			_phase = 3
			_wait = 20
		3:
			_save(_lang)
			if _lang == 1:
				print("f12 ticker: done")
				quit(0)
				return
			_lang = 1
			_show(dr, hud)
			_wait = 20


## The same two lines in the current language, held fresh; the sim is paused so the frame is the same for both.
func _show(dr: Variant, hud: Hud) -> void:
	dr.paused = true
	TranslationServer.set_locale(["en", "es"][_lang])
	hud.notices.clear()
	var r: WorldReader = dr.reader
	hud.notices.add_item(ITEM, ItemLooks.color_of_id(ITEM), tr(&"ITEM_GUN_HOMING"))
	var cards := r.pair_card_ids(PAIR)
	hud.notices.add_pair(r.pair_id(PAIR), cards[0], cards[1], tr(r.pair_name_key(PAIR)), 2)
	hud.notices.advance(0.4)  # past the fade in
	hud.phase_hud._left = 4.0


func _save(lang: int) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "ticker_%s.png" % ["en", "es"][lang]
	img.save_png(path)
	print("f12 ticker: ", path, " enemies ", _main.driver.reader.enemies_alive())
