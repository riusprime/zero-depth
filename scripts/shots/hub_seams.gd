extends SceneTree
## v0.10.5 W3-O5 (owner F1, F2): the hub from the play camera where the floor met the walls and the wall pieces met
## each other, plus one wide view of the void and fog round it. A tool, not a test: the real main.tscn on a
## memory-only profile (en), Play pressed, then the hero placed in the hub's World directly at each spot.
## Needs a renderer (the GPU on the owner's PC), off screen:
##   godot --path . --audio-driver Dummy --resolution 1920x1080 --position -10000,-10000
##     -s scripts/shots/hub_seams.gd -- <tag>
## Writes build/shots/v0.10.5/w3o5/<tag>_<shot>.png (<tag> e.g. before / after; default "shot").

const OUT := "res://build/shots/v0.10.5/w3o5/"
## Frames to let the menu's fade and the hub's cover settle before a shot.
const SETTLE := 70
## The spots (plan m, the hub's frame: +y north) and the camera's view size there (0: the hub's own).
const SPOTS: Array[Dictionary] = [
	{"name": "1_east_wall", "at": Vector2(12.5, 3.0), "view": 0.0},
	{"name": "2_west_wall", "at": Vector2(-12.0, 6.0), "view": 0.0},
	{"name": "3_north_east", "at": Vector2(7.0, 12.5), "view": 0.0},
	{"name": "4_wide", "at": Vector2(0.0, 0.0), "view": 46.0},
]

var main: Main
var _tag := "shot"
var _step := -1
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_tag = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "en"
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _place(i: int) -> void:
	var spot: Dictionary = SPOTS[i]
	var w := main.hub.driver.world
	w.actors.set_pos(0, HubLayout.to_sim(spot["at"]))
	w.vel = Vector2.ZERO
	var rig := main.hub.view.rig
	rig.view_size = spot["view"] if spot["view"] > 0.0 else HubView.VIEW_SIZE


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE:
		return false
	_frames = 0
	if _step == -1:
		_key(KEY_ENTER)  # Play
	elif _step == 0:
		_place(0)
	else:
		var path := OUT + "%s_%s.png" % [_tag, SPOTS[_step - 1]["name"]]
		root.get_texture().get_image().save_png(path)
		print("hub_seams: ", path)
		if _step >= SPOTS.size():
			main.queue_free()
			return true
		_place(_step)
	_step += 1
	return false
