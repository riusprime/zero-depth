extends SceneTree
## v0.10.5 W3-S13: the deal moment of an altar pick, the cards face down in the owner's carved backs (card 1
## focused: its icy-rim twin). The same altar as w3o15 (Pierce, Fire, Power; seed 4242); the deal is advanced to
## just after the last card arrives, before the first flip. A tool, not a test. Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/w3s13_card_backs.gd
## Writes build/shots/v0.10.5/w3s13/backs.png.

const OUT := "res://build/shots/v0.10.5/w3s13/"
const DEAL_AT := 0.5

var _repo: ContentRepository
var _stage := 0
var _wait := 0
var _frame := 0
var _top: Control
var _panel: PickPanel
var _world: World


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale("en")
	_repo = ContentRepository.load_all()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 600:
		print("w3s13: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		return false
	match _stage:
		0:
			_show_pick()
			_wait = 20
		1:
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(OUT + "backs.png")
			print("w3s13: ", OUT, "backs.png ", img.get_size(), " deal time ", _panel.deal.time)
			quit(0)
			return true
	_stage += 1
	return false


func _backdrop() -> void:
	_top = Control.new()
	_top.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color("#0A0D18")
	bg.size = _top.size
	_top.add_child(bg)
	root.add_child(_top)


func _item(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


func _stat(w: World, id: StringName, rarity: int) -> int:
	for s in w.stat_tables.size():
		if w.stat_tables[s] != null and w.stat_tables[s].id == id:
			return Offers.stat_code(s, rarity)
	return -1


func _show_pick() -> void:
	_backdrop()
	_world = CardPoolSurvey.world(_repo, 4242, &"gun", [])
	var w := _world
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	w.rewards.set_offer(
		w.rewards.size() - 1,
		PackedInt32Array([_item(w, &"gun_pierce"), _item(w, &"ember_core"), _stat(w, &"damage", 1)])
	)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.INTERACT))
	var p := PickPanel.new()
	_top.add_child(p)
	p.sync(WorldReader.new(w))
	p._set_focus(0)
	p.set_process(false)
	p.deal.time = DEAL_AT
	p._apply_deal()
	_panel = p
