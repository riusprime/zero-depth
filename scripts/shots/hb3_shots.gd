extends SceneTree
## v0.9.0 HB2 / HB3 (owner: the walk into the portal; the bigger Rune Ring, its stations along the top facing the middle,
## the owner's eight hub pieces): the real main.tscn on a memory-only profile, in English. Shots: the hub from the
## spawn (Play, an Enter press), the top half seen from above (a tool view: the camera lifted and pitched down, over
## the stations), then the hero placed before the Portal Machine, E, Enter on the Blade: the walk up the steps
## (mid-climb) and the crossing (the portal's flare). `--lit` also lights six runes for a check shot (not evidence).
## Needs a renderer (the GPU on the owner's PC):
##   godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/hb3_shots.gd
## Writes build/shots/v0.9.0/hb3/<shot>.png (copy the ones the owner looks at into the evidence by hand).

const OUT := "res://build/shots/v0.9.0/hb3/"
## Frames to let the menu's fade and the hub's cover settle before a shot.
const SETTLE := 70
## The tool view of the top half: the camera's pitch (degrees) and where it looks (plan m).
const TOP_PITCH := 52.0
const TOP_AT := Vector2(0.0, 7.0)

var main: Main
var _step := 0
var _frames := 0
var _lit := false


func _initialize() -> void:
	_lit = "--lit" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "en"
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _shot(shot_name: String) -> void:
	var path := OUT + "%s.png" % shot_name
	root.get_texture().get_image().save_png(path)
	print("hb3_shots: ", path)


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
				_key(KEY_ENTER)  # Play
				_next()
		1:
			if _frames == SETTLE - 10 and _lit:
				var lit: Array[bool] = []
				for i in 16:
					lit.append(i < 6)
				main.hub.view.set_runes(lit)
			if _frames == SETTLE:
				_shot("1_hub_spawn" if not _lit else "check_runes_lit")
				if _lit:
					return true
				var rig := main.hub.view.rig
				rig.set_pitch(TOP_PITCH)
				rig.snap_to(SimPlane.to_3d(HubLayout.to_sim(TOP_AT)))
				main.hub.driver.paused = true  # the tool view holds (a tick would lean it back)
				_next()
		2:
			if _frames == 20:
				_shot("2_hub_top_half")
				var rig := main.hub.view.rig
				rig.set_pitch(35.26)
				main.hub.driver.paused = false
				var w := main.hub.driver.world
				w.actors.set_pos(0, HubLayout.to_sim(Vector2(0.0, -3.4)))
				w.vel = Vector2.ZERO
				_next()
		3:
			if _frames == 30:
				_key(KEY_E)  # the Portal Machine's build screen
			if _frames == 50:
				_key(KEY_ENTER)  # the Blade: the walk
				_next()
		4:
			var walk := main.hub.view.walk if main.hub != null else null
			if walk != null and walk.height() > 0.7:
				_shot("3_walk_up_the_steps")
				_next()
		5:
			var walk := main.hub.view.walk if main.hub != null else null
			if walk != null and walk.shrink() > 0.35:
				_shot("4_walk_through_the_portal")
				_next()
		6:
			if _frames == 10:
				return true
	return false


func _next() -> void:
	_step += 1
	_frames = 0
