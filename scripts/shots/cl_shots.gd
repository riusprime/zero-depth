extends SceneTree
## v0.9.0 CL: the collectibles in the real main.tscn on memory-only profiles, en then es. A tool, not a test:
## 1. run seed 5's floor-2 save (a Blood Shrine) is continued (Enter); the hero is put before the shrine and E takes its
##    deal: the Blood Coin shows beside it (shot 1, the world paused); the pause menu goes to the hub and the Codex is
##    opened on its Collectibles page with five found, the Sand Shell focused (shot 2);
## 2. a profile with 12 found: Play; the hero is put south of the open north gate, the Keystone on its pedestal and 12
##    floor runes lit (shot 3).
## Needs a renderer (the GPU on the owner's PC):
##   godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/cl_shots.gd
## Writes build/shots/v0.9.0/cl/<lang>_<shot>.png (copy the ones the owner looks at into the evidence by hand).

const OUT := "res://build/shots/v0.9.0/cl/"
const LANGS: Array[String] = ["en", "es"]
const SETTLE := 70
const SEED := 5
const FIVE: Array[StringName] = [
	&"cold_lantern", &"frozen_bell", &"sand_shell", &"violet_eye", &"colossus_tooth"
]

var main: Main
var _lang := 0
var _step := 0
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_boot(false)


func _profile(found: int) -> ProfileStore:
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = LANGS[_lang]
	if found == 5:
		for id in FIVE:
			CollectibleBook.record(profile, id, 1)
	else:
		var defs := CollectibleBook.defs(ContentRepository.load_all())
		for k in found:
			CollectibleBook.record(profile, defs[k].id, 1)
	return profile


func _boot(hub_only: bool) -> void:
	ProfileStore.use_shared(_profile(12 if hub_only else 5))
	var store := RunSaveStore.new("")
	if not hub_only:
		var run := SaveLab.run_state(SEED, 2, &"blade")
		store.write(RunSaver.payload_of(SaveLab.build_floor(run), run, SEED, PackedByteArray()))
	RunSaveStore.use_shared(store)
	Main.fixed_seed = SEED
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _shot(shot_name: String) -> void:
	var path := OUT + "%s_%s.png" % [LANGS[_lang], shot_name]
	root.get_texture().get_image().save_png(path)
	print("cl_shots: ", path)


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
			var landed := (
				main.is_playing()
				and not main.loads.busy()
				and main.driver.world.boss_flow != null
				and main.driver.world.boss_flow.arrive_left <= 0
			)
			if landed and _frames > 60:
				var w := main.driver.world
				var f := w.floor_layout
				var at := w.shrine.pos
				var front := Gamble.front(at, f.door_approaches(f.room_of(at), 1.0)[0])
				w.actors.set_pos(0, front)
				w.vel = Vector2.ZERO
				w.actors.hp[0] = w.actors.max_hp[0]
				_next()
		2:
			if _frames == 60:
				_key(KEY_E)  # the Blood Shrine's deal
			if _frames == 100:
				main.driver.paused = true
			if _frames == 130:
				_shot("1_blood_coin_in_a_run")
				main.driver.paused = false
				main.call(&"_show_hub")  # the pause menu's To the Rune Ring (a tool: straight there)
				_next()
		3:
			if main.hub != null and _frames == SETTLE:
				main.show_codex(CodexView.COLLECTIBLES)
				_next()
		4:
			if _frames == 10:
				var c := main.get_node("UI/CodexView") as CodexView
				var t := c.archive_page.tile(&"sand_shell")
				if t != null:
					t.grab_focus()
			if _frames == SETTLE:
				_shot("2_rune_archive_five_found")
				_next()
		5:
			main.queue_free()
			_step = 6
			_frames = 0
		6:
			if _frames == 2:
				_boot(true)
				_next()
		7:
			if _frames == SETTLE:
				_key(KEY_ENTER)  # Play: the hub
				_next()
		8:
			if main.hub != null and _frames == SETTLE:
				var w := main.hub.driver.world
				var hub := main.hub.hub
				w.actors.set_pos(0, HubLayout.to_sim(Vector2(0.0, hub.radius_m - 3.0)))
				w.vel = Vector2.ZERO
				_next()
		9:
			if _frames == SETTLE:
				_shot("3_hub_runes_lit_gate_open")
				_next()
		10:
			main.queue_free()
			_lang += 1
			if _lang >= LANGS.size():
				return true
			TranslationServer.set_locale(LANGS[_lang])
			_step = 11
			_frames = 0
		11:
			if _frames == 2:
				_boot(false)
				_step = 0
				_frames = 0
	return false


func _next() -> void:
	_step += 1
	_frames = 0
