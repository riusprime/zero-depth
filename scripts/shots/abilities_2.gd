extends SceneTree
## v0.4.0 AB screenshots (needs a renderer, not --headless): Arc Field, Frost Nova and Bomb Lobber at level 3 with
## the Storm Bombs / Superconductor combo card up, and the Overrun room seen from just inside its red-framed door.
## Shot setup only (it grants abilities, adds enemies and places the hero directly, as the dev panel would); the real
## input paths are tests/e2e/test_e2e_abilities_ab.gd.
##   godot --path . -s scripts/shots/abilities_2.gd   -> build/shots/v0.4.0/abilities_2/

const OUT := "res://build/shots/v0.4.0/abilities_2/"

var _main: Main
var _frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("abilities_2: renderer=%s" % RenderingServer.get_current_rendering_method())
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
			var p := w.player_pos()
			for k in 6:
				w.add_enemy(ActorStore.Kind.CHARGER, p + Kin.dir(k * 683) * (3.0 + k * 0.4))
		60:
			var w := _main.driver.world
			for id: StringName in [&"bomb_lobber", &"frost_nova", &"arc_field"]:
				for k in 3:
					Abilities.grant(w, _idx(w, id))
		75:
			_shot("01_element_abilities_and_combo")
		160:
			var w := _main.driver.world
			var at := DebugApi.overrun_door_outside(w, -2.5)  # just inside the door
			if at != Vector2.INF:
				w.actors.set_pos(0, at)
		600:
			_shot("02_overrun_room")
		610:
			quit(0)
	return false


func _idx(w: World, id: StringName) -> int:
	for k in w.ability_tables.size():
		if w.ability_tables[k].id == id:
			return k
	return -1


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
	print("abilities_2: shot ", path)
