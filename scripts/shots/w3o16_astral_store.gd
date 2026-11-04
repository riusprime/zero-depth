extends SceneTree
## v0.10.5 W3-O16: the shop and the altar pick in the Astral style, in the real panels with real data from fixed seeds:
## the altar of W3-O15's shot (CardPoolSurvey.world, seed 4242: Pierce, Fire, Power), the first card focused; the
## blade build's shop (seed 11, the shop tests' world) with 300 shards and half HP, its first card focused, then the
## heal focused; the Swap panel with eight held cards (the wand view tests' world, Thrust offered). A tool, not a
## test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/w3o16_astral_store.gd [-- es]
## Writes build/shots/v0.10.5/w3o16/{pick,shop,shop_heal,swap}[_es].png.

const OUT_DEFAULT := "res://build/shots/v0.10.5/w3o16/"
const SETTLE := 30
const EIGHT: Array = [
	&"heavy",
	&"chain_blast",
	&"whirl",
	&"flurry",
	&"shared_bleed",
	&"parry_edge",
	&"frost_core",
	&"echo_slash",
]

var _out := OUT_DEFAULT
var _repo: ContentRepository
var _stage := 0
var _wait := 0
var _frame := 0
var _top: Control
var _panel: Control
var _suffix := ""


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("w3s12"):
		_out = "res://build/shots/v0.10.5/w3s12/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var lang := "es" if OS.get_cmdline_user_args().has("es") else "en"
	_suffix = "_es" if lang == "es" else ""
	TranslationServer.set_locale(lang)
	_repo = ContentRepository.load_all()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 4000:
		print("w3o16: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		return false
	match _stage:
		0:
			_show_pick()
		1:
			_grab("pick")
			_show_shop()
		2:
			_grab("shop")
			var p := _panel as ShopPanel
			p._set_focus(p.index_of_value(InputFrame.PICK_SHOP_HEAL))
		3:
			_grab("shop_heal")
			_show_swap()
		4:
			_grab("swap")
			print("w3o16: done")
			quit(0)
			return true
	_wait = SETTLE
	_stage += 1
	return false


## A dark scene-like backdrop: the panels' own dims sit over it.
func _backdrop() -> void:
	if _top != null:
		_top.queue_free()
	_top = Control.new()
	_top.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color("#161B2C")
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
	var w := CardPoolSurvey.world(_repo, 4242, &"gun", [])
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	w.rewards.set_offer(
		w.rewards.size() - 1,
		PackedInt32Array([_item(w, &"gun_pierce"), _item(w, &"ember_core"), _stat(w, &"damage", 1)])
	)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.INTERACT))
	var p := PickPanel.new()
	_top.add_child(p)
	p.sync(WorldReader.new(w))
	p.skip_deal()
	p._set_focus(0)
	p.set_process(false)
	p.deal.time = p.deal.length() + 3.0
	_panel = p


func _show_shop() -> void:
	_backdrop()
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(11, t)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.reward_table = ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	w.shop_table = ContentCompiler.compile_shop(_repo.get_def(&"shop", &"terminal"))
	w.shop.id = w.take_root()
	w.shop.pos = Vector2(1.0, 0)
	w.shards = 300
	w.actors.hp[0] = w.actors.max_hp[0] / 2
	w.input_buffer[3] = 1
	Shop.interact(w)
	var p := ShopPanel.new()
	_top.add_child(p)
	p.sync(WorldReader.new(w))
	p._set_focus(0)
	_panel = p


func _show_swap() -> void:
	_backdrop()
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.floor_index = 5
	w.dummy_speed = 0.0
	w.wand_table = WandCompiler.from_repo(_repo)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	for id: StringName in EIGHT:
		BuildSlots.take(w, WandLab.code(w, id))
	Offers.apply(w, AttackScenario.item_index(w.item_tables, &"thrust"))
	var p := SwapPanel.new()
	_top.add_child(p)
	p.sync(WorldReader.new(w))
	_panel = p
	print("w3o16: swapping ", BuildSlots.swapping(w))


func _grab(shot: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _out + "%s%s.png" % [shot, _suffix]
	img.save_png(path)
	print("w3o16: ", path, " ", img.get_size())
