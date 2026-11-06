extends SceneTree
## v0.10.5 W3-O15: the Astral cards (the owner's carved frames and painted icons) in the real pick and shop panels,
## and three frames of the pick dissolve. Real data from fixed seeds: an altar holding Pierce, Fire and Power
## (CardPoolSurvey.world, seed 4242, the reward-card tests' world), the first card focused; the blade build's shop
## (seed 11, the shop tests' world) with 300 shards, its first card focused; then the altar again, card 2 taken by
## key (2, Enter) and the sim stepped, and the outro driven 1/60 s at a time: frames at 0.2, 0.4 and 0.6 of its
## 0.75 s. A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/w3o15_astral_cards.gd
## Writes build/shots/v0.10.5/w3o15/{pick,shop,dissolve_1,dissolve_2,dissolve_3}.png.

const OUT := "res://build/shots/v0.10.5/w3o15/"
const SETTLE := 30
const DISSOLVE_AT := [0.2, 0.4, 0.6]

var _repo: ContentRepository
var _stage := 0
var _wait := 0
var _frame := 0
var _top: Control
var _panel: Control
var _world: World


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale("en")
	_repo = ContentRepository.load_all()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 4000:
		print("w3o15: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		return false
	match _stage:
		0:
			_show_pick(false)
			_wait = SETTLE
		1:
			_grab("pick")
			_show_shop()
			_wait = SETTLE
		2:
			_grab("shop")
			_show_pick(true)
			_wait = SETTLE
		3:
			_take_card()
			_wait = 2
		4, 5, 6:
			if _stage > 4:
				_grab("dissolve_%d" % (_stage - 4))
			_advance_to(DISSOLVE_AT[_stage - 4])
			_wait = 3
		7:
			_grab("dissolve_3")
			print("w3o15: done")
			quit(0)
			return true
	_stage += 1
	return false


func _backdrop() -> void:
	if _top != null:
		_top.queue_free()
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


func _show_pick(fresh: bool) -> void:
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
	p.skip_deal()
	p._set_focus(0)
	p.set_process(fresh)
	if not fresh:
		p.deal.time = p.deal.length() + 3.0  # the deal settled: no rays still turning in
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
	w.input_buffer[3] = 1
	Shop.interact(w)
	var p := ShopPanel.new()
	_top.add_child(p)
	p.sync(WorldReader.new(w))
	p._set_focus(0)
	_panel = p


func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	return ev


## Card 2 taken by key, the sim stepped with the latch's pick, the panel synced: the outro starts.
func _take_card() -> void:
	var p := _panel as PickPanel
	p.set_process(false)
	p._input(_key(KEY_2))
	p._input(_key(KEY_ENTER))
	for k in 2:
		var f := InputFrame.new()
		f.pick = 2 if k == 0 else InputFrame.PICK_NONE
		_world.step(f)
	p.sync(WorldReader.new(_world))
	print("w3o15: outro playing ", p.outro_playing(), " picked ", p.picked_slot())


func _advance_to(t: float) -> void:
	var p := _panel as PickPanel
	while p.outro_playing() and p._outro < t * PickPanel.OUTRO_S:
		p._process(1.0 / 60.0)


func _grab(shot: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s.png" % shot
	img.save_png(path)
	print("w3o15: ", path, " ", img.get_size())
