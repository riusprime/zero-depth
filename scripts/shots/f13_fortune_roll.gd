extends SceneTree
## v0.11.0 F13 shots: the Fortune shrine's reward rolling above the shrine (mid-roll) and the corner panel after the
## symbol landed. A tool, not a test: it puts the hero at the shrine and grants the shards directly (SHOT HELPER), then
## presses E through Input. Needs a renderer:
##   godot --path . --position -10000,-10000 --resolution 1600x900 -s scripts/shots/f13_fortune_roll.gd
## Writes build/shots/v0.11.0/f13/.

const OUT := "res://build/shots/v0.11.0/f13/"
const SEED := 385
const GIVE_UP := 3000

var main: Main
var _frames := 0
var _step := 0
var _at := 0
var _shot_roll := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Main.fixed_seed = SEED
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(OUT + shot_name + ".png")
	print("f13: ", OUT + shot_name + ".png")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > GIVE_UP:
		print("f13: gave up in step ", _step)
		quit(1)
		return false
	var hud: Hud = main._hud
	match _step:
		0:
			if _frames == 3:
				main.start_stage()
				_step = 1
		1:
			if (
				main.driver != null
				and not main.loads.cover.showing()
				and main.driver.world.tick > 480
			):
				var w: World = main.driver.world
				var f := w.floor_layout
				var p := Gamble.front(
					w.gamble_pos, f.door_approaches(f.room_of(w.gamble_pos), 1.0)[0]
				)
				w.actors.set_pos(0, p)
				w.vel = Vector2.ZERO
				main.view.rig.snap_to(SimPlane.to_3d(p))
				w.shards = Gamble.price(w)  # SHOT HELPER (labelled): exactly one use
				_at = _frames
				_step = 2
		2:
			var w: World = main.driver.world
			if (_frames - _at) % 40 == 20 and w.gamble_uses == 0:
				_key(KEY_E, true)
			if (_frames - _at) % 40 == 24:
				_key(KEY_E, false)
			if w.gamble_uses > 0:
				print("f13: use at frame ", _frames - _at, ", win ", w.gamble_wins)
				_step = 3
		3:
			var roll := hud.gamble.roll
			if roll.count() > 0 and roll.phase_of(0) == GambleRoll.Phase.SPIN and not _shot_roll:
				_shot_roll = true
				_shot("1_mid_roll")
			if roll.arrived >= 1 and roll.count() == 0:
				_at = _frames
				_step = 4
		4:
			if _frames == _at + 12:
				_shot("2_panel_after_landing")
				print("f13: rows=", hud.gamble.stats.row_count())
				quit(0)
	return false
