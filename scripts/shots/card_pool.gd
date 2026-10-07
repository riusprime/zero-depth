extends SceneTree
## v0.5.0 CP screenshots (needs a renderer, not --headless): the pick panel showing the new cards' faces (the five
## rule stat cards and the four ability mods). Shot setup only: it grants abilities, sets an altar's offer to the
## cards to show and places the hero by it directly; the real input path is tests/e2e/test_e2e_card_pool.gd.
##   godot --path . -s scripts/shots/card_pool.gd   -> build/shots/v0.5.0/card_pool/

const OUT := "res://build/shots/v0.5.0/card_pool/"
## Each shot's three cards: [kind ("stat" with a rarity, or "mod"), id].
const SHOTS := [
	[
		"01_rule_cards",
		[["stat", &"glass_cannon", 2], ["stat", &"hoarder", 1], ["stat", &"overkill", 0]]
	],
	[
		"02_rule_and_mod",
		[["stat", &"onrush", 1], ["stat", &"fast_hands", 2], ["mod", &"cluster_payload", 0]]
	],
	[
		"03_ability_mods",
		[["mod", &"razor_orbit", 0], ["mod", &"afterimage", 0], ["mod", &"overclocked_drone", 0]]
	],
]

var _main: Main
var _frame := 0
var _altar := -1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("card_pool: renderer=%s" % RenderingServer.get_current_rendering_method())
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _main.driver != null:
		_main.driver.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
	match _frame:
		10, 20:
			_tap(KEY_ENTER)  # Play, then Blade
		40:
			var w := _main.driver.world
			for kind in [
				AbilityTable.Kind.BOMB_LOBBER,
				AbilityTable.Kind.DRONE_BUDDY,
				AbilityTable.Kind.ORBIT_BLADES
			]:
				Abilities.grant(w, Abilities.index_of_kind(w, kind))
			for i in w.rewards.size():
				if w.rewards.kind[i] == RewardStore.Kind.ALTAR:
					_altar = i
					break
			w.actors.set_pos(0, w.rewards.pos(_altar) + Vector2(0.8, 0))
	for k in SHOTS.size():
		var at: int = 100 + k * 60
		if _frame == at:
			_offer(SHOTS[k][1])
		elif _frame == at + 5:
			_tap(KEY_E)
		elif _frame == at + 30:
			_shot(SHOTS[k][0])
		elif _frame == at + 35:
			_tap(KEY_ESCAPE)
	if _frame == 100 + SHOTS.size() * 60 + 10:
		quit(0)
	return false


func _offer(cards: Array) -> void:
	var w := _main.driver.world
	var codes := PackedInt32Array()
	for c: Array in cards:
		if c[0] == "stat":
			for s in w.stat_tables.size():
				if w.stat_tables[s] != null and w.stat_tables[s].id == c[1]:
					codes.append(Offers.stat_code(s, c[2]))
		else:
			for k in w.item_tables.size():
				if w.item_tables[k].id == c[1]:
					codes.append(k)
	w.rewards.set_offer(_altar, codes)
	w.rewards.rolled[_altar] = 1
	print("card_pool: offer ", codes)


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	img.save_png(path)
	print("card_pool: shot ", path)
