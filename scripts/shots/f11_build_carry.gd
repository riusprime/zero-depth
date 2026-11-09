extends SceneTree
## v0.11.0 F11: the Build page while a card is carried (the real BuildPage, driven by real key events): the lifted card,
## its ghost, the landing bar and arrow, and the forecast as the cards' icons. A Gun run (CardPoolSurvey.world, seed 5)
## holding Big Shot, Split Shot, Ember Core and Twin, like the F10 mock: slot 3 carried to slot 1.
## A tool, not a test. Needs a renderer (not --headless):
##   godot --path . --resolution 1920x1080 --position -10000,-10000 -s scripts/shots/f11_build_carry.gd
## Writes build/shots/v0.11.0/f11/build_carry_en.png.

const OUT := "res://build/shots/v0.11.0/f11/"
const HELD: Array[StringName] = [&"gun_big_shot", &"split_shot", &"ember_core", &"gun_twin"]

var _w: World
var _page: BuildPage
var _frame := 0
var _keys: Array[Key] = [KEY_3, KEY_ENTER, KEY_LEFT, KEY_LEFT]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale("en")
	var repo := ContentRepository.load_all()
	_w = CardPoolSurvey.world(repo, 5, &"gun", [])
	_w.wand_table = WandCompiler.from_repo(repo)
	_w.slot_table = WandCompiler.slots(repo, _w.item_tables)
	for id in HELD:
		BuildSlots.take(_w, AttackScenario.item_index(_w.item_tables, id))
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var reader := WorldReader.new(_w)
	_page = BuildPage.new()
	root.add_child(_page)
	_page.open(reader.wand(), Wand.slots(_w), reader)


func _key(key: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = down
	Input.parse_input_event(ev)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame % 3 == 0 and not _keys.is_empty():
		var key: Key = _keys.pop_front()
		_key(key, true)
		_key(key, false)
	if _frame < 60:
		return false
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "build_carry_en.png"
	img.save_png(path)
	print(
		"f11: ",
		path,
		" ",
		img.get_size(),
		" carrying from ",
		_page.row.ghost_slot(),
		" to ",
		_page.row.marker_slot()
	)
	quit(0)
	return true
