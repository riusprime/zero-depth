extends SceneTree
## v0.8.0 RR (owner O33): the four card tiers on the pick panel's stone cards, one language per run (`-- --lang=en` or
## `-- --lang=es`): Explosive (Common), Wildfire (Rare), Twin (Epic, a Gun card), Chain Blast (Legendary), each face
## built by PickPanel.card_face from a Gun run's world (the game's own face code); then the boss altar's faces
## (PickPanel.legendary_face: a Common card next to Chain Blast and a legendary stat card; v0.8.0 FL: no level-5
## version). A tool, not a test.
## Needs a renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1600x1000 -s scripts/shots/rarity_cards.gd -- --lang=en
## Writes build/shots/v0.8.0/rr/<name>_<lang>.png. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.8.0/rr/"
const TIERS: Array[StringName] = [&"shared_explosive", &"wildfire", &"gun_twin", &"chain_blast"]
const BOSS: Array[StringName] = [&"gun_spread", &"chain_blast"]

var _lang := "en"
var _frame := 0
var _row: HBoxContainer
var _w: World
var _reader: WorldReader
var _shots := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
	TranslationServer.set_locale(_lang)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("rr: renderer=%s lang=%s" % [RenderingServer.get_current_rendering_method(), _lang])
	var repo := ContentRepository.load_all()
	_w = CardPoolSurvey.world(repo, 3, &"gun", [])
	_w.legendary_table = RunContentCompiler.compile_legendary(
		repo.get_def(&"legendary", &"boss"), _w.stat_tables, _w.item_tables
	)
	_reader = WorldReader.new(_w)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.05)
	bg.size = Vector2(1600, 1000)
	root.add_child(bg)
	_row = HBoxContainer.new()
	_row.position = Vector2(40, 120)
	_row.add_theme_constant_override("separation", 28)
	root.add_child(_row)
	_show_tiers()


func _code(id: StringName) -> int:
	for k in _w.item_tables.size():
		if _w.item_tables[k].id == id:
			return k
	return -1


func _clear() -> void:
	for c in _row.get_children():
		c.queue_free()


func _slot(face: Dictionary) -> void:
	var s := PickSlot.new(_row.get_child_count(), 1.2)
	_row.add_child(s)
	s.show_card(face)


func _show_tiers() -> void:
	_clear()
	for id in TIERS:
		_slot(PickPanel.card_face(root, _reader, _code(id)))


func _show_boss() -> void:
	_clear()
	for id in BOSS:
		var face := PickPanel.card_face(root, _reader, _code(id))
		_slot(PickPanel.legendary_face(root, face))  # v0.8.0 FL: no level-5 version any more
	var stat := Offers.stat_code(Stats.Stat.DAMAGE, Offers.LEGENDARY)
	_slot(PickPanel.card_face(root, _reader, stat))


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 40:
		_shot("tiers")
		_show_boss()
	if _frame == 80:
		_shot("boss")
		quit(0)
		return true
	if _frame > 400:
		quit(1)
		return true
	return false


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + "%s_%s.png" % [name, _lang])
	img.save_png(path)
	_shots += 1
	print("rr: wrote %s" % path)
