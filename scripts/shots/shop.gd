extends SceneTree
## v0.5.0 SH screenshots (needs a renderer, not --headless): the shop terminal in its room, and the shop panel open
## (stock, heal, reroll, salvage list). Shot setup only: it grants Bomb Lobber and two stat cards, gives 120 shards,
## lowers HP and places the hero in front of the terminal directly; the real input path is
## tests/e2e/test_e2e_shop.gd.
##   godot --path . -s scripts/shots/shop.gd   -> build/shots/v0.5.0/shop/

const OUT := "res://build/shots/v0.5.0/shop/"

var _main: Main
var _frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("shop: renderer=%s" % RenderingServer.get_current_rendering_method())
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
			Abilities.grant(w, Abilities.index_of_kind(w, AbilityTable.Kind.BOMB_LOBBER))
			Stats.add_card(w, Stats.Stat.DAMAGE, 1)
			Stats.add_card(w, Stats.Stat.AREA, 0)
			w.shards = 120
			w.actors.hp[0] = w.actors.max_hp[0] / 2
			w.actors.set_pos(0, ShopPlacement.front(w.floor_layout) + Vector2(0.4, 0.4))
			print("shop: room %d at %s" % [w.shop.room, w.shop.pos])
		90:
			_shot("01_terminal")
		95:
			_tap(KEY_E)
		125:
			_shot("02_shop_panel")
			print("shop: stock ", _main.driver.world.shop.offer)
		130:
			_tap(KEY_ESCAPE)
		140:
			quit(0)
	return false


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
	print("shop: shot ", path)
