extends SceneTree
## v0.10.5 O17 (owner P17): the Training Room in the real main.tscn on a memory-only profile (its Codex has met the
## Charger and seen the Gun's first wand card): the hub with its south door (the hero by it), then the room (a tool,
## not a test: it starts the room and places the hero directly) with three Chargers spawned and the terminal's panel
## open beside the dummy. Needs a renderer (the GPU on the owner's PC):
##   godot --path . --audio-driver Dummy --resolution 1920x1080 --position -10000,-10000 \
##     -s scripts/shots/training_room.gd

## Writes build/shots/v0.10.5/o17/en_<shot>.png.

const OUT := "res://build/shots/v0.10.5/o17/"
const SETTLE := 80

var main: Main
var _step := 0
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "en"
	var codex := CodexStore.new(profile)
	codex.unlock(&"enemies", &"charger")
	codex.unlock(&"enemies", &"swarmer")
	var repo := ContentRepository.load_all()
	var w := TrainingScenario.build(repo, &"gun", repo.get_def(&"biomes", HubSession.BIOME))
	for e in PlaygroundApi.new(w).catalog():
		if e["group"] == PlaygroundApi.GROUP_WAND:
			codex.unlock(&"cards", w.item_tables[int(e["code"])].id)
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _shot(shot_name: String) -> void:
	var path := OUT + "en_%s.png" % shot_name
	root.get_texture().get_image().save_png(path)
	print("training_room: ", ProjectSettings.globalize_path(path))


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == SETTLE:
				main._show_hub()
				_next()
		1:
			if _frames == 4:
				var w := main.hub.driver.world
				w.actors.set_pos(0, HubLayout.to_sim(Vector2(0.0, -14.6)))
			if _frames == SETTLE:
				_shot("1_hub_south_door")
				TrainingFlow.start(main, &"gun")
				_next()
		2:
			if _frames == 4:
				var t := main.training
				var room := t.room
				main.driver.world.actors.set_pos(
					0, (TrainingRoom.terminal_point(room) + TrainingRoom.dummy_point(room)) * 0.5
				)
				t.spawn(ActorStore.Kind.CHARGER, 3)
			if _frames == SETTLE:
				main.training.open_panel()
				_next()
		3:
			if _frames == 30:
				_shot("2_training_room_panel")
				return true
	return false


func _next() -> void:
	_step += 1
	_frames = 0
