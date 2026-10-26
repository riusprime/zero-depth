extends SceneTree
## v0.9.5 TX: an altar's cards with the form line under the generic sentence, at 1920 x 1080. Real data from a fixed
## seed: a Gun run (CardPoolSurvey.world, seed 5) holding the Laser form card (taken through BuildSlots.take); the
## offer is Ring, Homing, Big Shot (PickSlot faces from PickPanel.card_face, the game's own).
## A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --language en --path . --resolution 1920x1080 -s scripts/shots/form_card_text.gd
## Writes build/shots/v0.9.5/tx/<lang>.png.

const OUT := "res://build/shots/v0.9.5/tx/"
const SEED := 5
const OFFER: Array[StringName] = [&"gun_ring", &"gun_homing", &"gun_big_shot"]
const LANGS := ["en"]
const SETTLE := 20

var _w: World
var _frame := 0
var _at := -1
var _wait := 0
var _overlay: Control


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var repo := ContentRepository.load_all()
	_w = CardPoolSurvey.world(repo, SEED, &"gun", [])
	_w.wand_table = WandCompiler.from_repo(repo)
	_w.slot_table = WandCompiler.slots(repo, _w.item_tables)
	_w.floor_index = 3
	_w.run_floor = 3
	BuildSlots.take(_w, _code(&"gun_laser"))


func _code(id: StringName) -> int:
	return AttackScenario.item_index(_w.item_tables, id)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 3000:
		print("tx: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_grab()
		return false
	_at += 1
	if _at >= LANGS.size():
		print("tx: done")
		quit(0)
		return true
	TranslationServer.set_locale(LANGS[_at])
	if _overlay != null:
		_overlay.queue_free()
	_overlay = _pick()
	root.add_child(_overlay)
	_wait = SETTLE
	return false


func _pick() -> Control:
	var reader := WorldReader.new(_w)
	var top := Control.new()
	top.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.07)
	bg.size = top.size
	top.add_child(bg)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.size = top.size
	top.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	col.add_child(row)
	for k in OFFER.size():
		var s := PickSlot.new(k)
		s.show_card(PickPanel.card_face(self, reader, _code(OFFER[k])))
		s.set_focused(k == 0)
		row.add_child(s)
	return top


func _grab() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s.png" % LANGS[_at]
	img.save_png(path)
	print("tx: ", path, " ", img.get_size())
