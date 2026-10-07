extends SceneTree
## v0.4.0 BS screenshots (needs a renderer, not --headless): the ability HUD with abilities firing, and an altar's
## pick with an ability card. Shot setup only (it grants abilities and places the hero by the altar directly, as the
## dev panel would); the real input path is tests/e2e/test_e2e_abilities.gd.
##   godot --path . -s scripts/shots/build_system.gd   -> build/shots/v0.4.0/build_system/

const OUT := "res://build/shots/v0.4.0/build_system/"

var _main: Main
var _frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("build_system: renderer=%s" % RenderingServer.get_current_rendering_method())
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
			for kind in [AbilityTable.Kind.BOMB_LOBBER, AbilityTable.Kind.DRONE_BUDDY]:
				for k in 3:
					Abilities.grant(w, Abilities.index_of_kind(w, kind))
			Abilities.grant(w, Abilities.index_of_kind(w, AbilityTable.Kind.ORBIT_BLADES))
		900:
			_shot("01_ability_hud")
		901:
			var w := _main.driver.world
			for i in w.rewards.size():
				if w.rewards.kind[i] == RewardStore.Kind.ALTAR:
					w.actors.set_pos(0, w.rewards.pos(i) + Vector2(0.8, 0))
					break
		910:
			_tap(KEY_E)
		930:
			_shot("02_pick_with_ability_card")
		940:
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
	print("build_system: shot ", path)
