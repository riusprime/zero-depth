extends SceneTree
## v0.6.1 Step SW2: the portal shard clusters (owner A1) in the real game. Boots main.tscn (Enter on the menu through
## Input.parse_input_event), puts the hero in front of the gate, then in front of the Deep gate, under the floor's
## v0.5.9 lighting mood. Needs a renderer:
##   XDG_DATA_HOME=<empty folder> xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy \
##     --resolution 1280x720 -s scripts/shots/portal_shards.gd
## SHOT HELPER (labelled; the subject is the look, not how the hero gets there): the hero is placed at the clear spot
## in front of each gate (ActorStore.set_pos) instead of walked there. Both gates show sealed (the boss lives).
## Writes gate.png and deep.png (+ *_crop.png round the gate) to
## build/shots/v0.6.1/portal_shards/. Quits on every path (a give-up after GIVE_UP_FRAMES). Evidence copies are made
## by hand.

const OUT := "res://build/shots/v0.6.1/portal_shards/"
const GIVE_UP_FRAMES := 4000
const CROP := Vector2i(520, 400)

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"portal_shards: renderer=%s device=%s window=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				DisplayServer.window_get_size()
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > GIVE_UP_FRAMES:
		print("portal_shards: gave up in step ", _step)
		quit(1)
		return false
	_step_frame += 1
	if _frame % 20 == 0:
		print("portal_shards: frame %d step %s" % [_frame, _step])
	match _step:
		&"boot":
			if _frame in [8, 14]:
				_key(KEY_ENTER, true)
			if _frame in [9, 15]:
				_key(KEY_ENTER, false)
			if _main.driver != null and _step_frame > 20:
				var w := _main.driver.world
				w.actors.set_pos(0, w.floor_layout.portal_front_point())  # SHOT HELPER (labelled)
				_go(&"gate")
		&"gate":
			if _step_frame == 10:
				_shoot("gate", _main.view.gate)
				var deep := _main.view.deep_gate
				if deep == null:
					print("portal_shards: no Deep gate on this floor")
					print("portal_shards: done")
					quit(0)
					return false
				var w := _main.driver.world
				var p := WorldReader.new(w).deep_portal_pos()
				var front := p + Kin.dir(WorldReader.new(w).deep_portal_angle()) * 2.0
				w.actors.set_pos(0, front)  # SHOT HELPER (labelled)
				_go(&"deep")
		&"deep":
			if _step_frame == 10:
				_shoot("deep", _main.view.deep_gate)
				print("portal_shards: done")
				quit(0)
	return false


func _shoot(shot: String, gate: PortalGate) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + shot + ".png"
	img.save_png(path)
	var cam := root.get_camera_3d()
	if cam != null and gate != null:
		var c := cam.unproject_position(gate.global_position + Vector3(0, 1.6, 0))
		c *= Vector2(img.get_size()) / root.get_visible_rect().size
		var r := Rect2i(Vector2i(c) - CROP / 2, CROP).intersection(
			Rect2i(Vector2i.ZERO, img.get_size())
		)
		var crop := img.get_region(r)
		crop.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(OUT + shot + "_crop.png")
	print(
		(
			"portal_shards: %s (frame %d, tick %d) gate_pos=%s deep=%s sealed=%s shard_colour=%s clusters=%d mood=%s"
			% [
				path,
				_frame,
				_main.driver.world.tick,
				gate.global_position if gate != null else Vector3.ZERO,
				gate.deep if gate != null else false,
				gate.is_sealed() if gate != null else true,
				gate.shard_color().to_html(false) if gate != null else "-",
				gate.shard_clusters.size() if gate != null else 0,
				_main.view.stage.mood != null
			]
		)
	)


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
