extends SceneTree
## v0.9.0 MP: the run summary with its Rune Fragments and the hub's Progression Station, in the real main.tscn on a
## memory-only profile (38 fragments banked before, Canyon owned) and a memory-only floor-2 save that earned 9 on
## floor 1, en then es. A tool, not a test: Continue (Enter), then the end panel is opened directly (the run banks its
## fragments), Down + Enter goes to the hub, the station's panel is opened directly and Night is bought.
## Needs a renderer (the GPU on the owner's PC):
##   godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mp_shots.gd
## Writes build/shots/v0.9.0/mp/<lang>_<shot>.png (copy the ones the owner looks at into the evidence by hand).

const OUT := "res://build/shots/v0.9.0/mp/"
const LANGS: Array[String] = ["en", "es"]
const SETTLE := 70
const SEED := 4242

var main: Main
var _lang := 0
var _step := 0
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_boot()


func _boot() -> void:
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = LANGS[_lang]
	MetaProgress.bank(profile, 38)
	Wardrobe.unlock_robe(profile, &"canyon")
	ProfileStore.use_shared(profile)
	var run := SaveLab.run_state(SEED, 2, &"blade")
	run.fragments_done = 9
	var store := RunSaveStore.new("")
	store.write(RunSaver.payload_of(SaveLab.build_floor(run), run, SEED, PackedByteArray()))
	RunSaveStore.use_shared(store)
	Main.fixed_seed = SEED
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _shot(shot_name: String) -> void:
	var path := OUT + "%s_%s.png" % [LANGS[_lang], shot_name]
	root.get_texture().get_image().save_png(path)
	print("mp_shots: ", path)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == SETTLE:
				_key(KEY_ENTER)  # Continue
				_next()
		1:
			if main.is_playing() and not main.loads.busy() and _frames > 30:
				_next()
		2:
			if _frames == SETTLE * 2:
				main.driver.paused = true
				main.show_end_panel(false)
			if _frames == SETTLE * 3:
				_shot("1_run_summary")
				_key(KEY_DOWN)
				_key(KEY_ENTER)  # the hub
				_next()
		3:
			if main.hub != null and _frames == SETTLE:
				var w := main.hub.driver.world
				var at := main.hub.layout.station(&"progression").at
				w.actors.set_pos(0, HubLayout.to_sim(at + Vector2(1.9, 0.6)))
				w.vel = Vector2.ZERO
				_next()
		4:
			if _frames == 20:
				main.hub.open_progression()
				var p := main.get_node("UI/ProgressionPanel") as ProgressionPanel
				p.buy_requested.emit(&"night")
			if _frames == SETTLE:
				_shot("2_progression_station")
				main.hub.close_overlay()
				_next()
		5:
			main.queue_free()
			_lang += 1
			if _lang >= LANGS.size():
				return true
			TranslationServer.set_locale(LANGS[_lang])
			_step = 6
			_frames = 0
		6:
			if _frames == 2:
				_boot()
				_step = 0
				_frames = 0
	return false


func _next() -> void:
	_step += 1
	_frames = 0
