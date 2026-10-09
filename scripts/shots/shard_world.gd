extends SceneTree
## v0.6.1 Step SW: the shard-look altars (and the small shard pieces) in the real game. Boots main.tscn (Enter on the
## menu through Input.parse_input_event), puts the hero beside the floor's nearest altar and grabs it in reach under
## the floor's v0.5.9 lighting mood. Needs a renderer:
##   XDG_DATA_HOME=<empty folder> xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy \
##     --resolution 1920x1080 -s scripts/shots/shard_world.gd
## SHOT HELPERS (labelled; the subject is the look, not how the pieces get there):
## - "near": the hero is placed in front of the altar (ActorStore.set_pos) instead of walked there: under lavapipe on a
##   shared machine a frame took ~4 s and the walk did not fit in the 300 s limit;
## - "tiers": an epic and a legendary altar are added to the sim beside the plain one (World.add_reward), so the three
##   tiers stand side by side;
## - "pieces": a dropped core, a heal orb and a burst of shard gems are built straight in the view (presentation
##   nodes only) next to the hero.
## Writes near.png, tiers.png, pieces.png (+ *_crop.png round the hero) to build/shots/v0.6.1/shard_world/. Quits on
## every path (a give-up after GIVE_UP_FRAMES). Evidence copies are made by hand.

const OUT := "res://build/shots/v0.6.1/shard_world/"
const GIVE_UP_FRAMES := 4000
const CROP := Vector2i(400, 260)

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _altar := -1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"shard_world: renderer=%s device=%s window=%s"
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
		print("shard_world: gave up in step ", _step)
		quit(1)
		return false
	_step_frame += 1
	if _frame % 20 == 0:
		print("shard_world: frame %d step %s" % [_frame, _step])
	match _step:
		&"boot":
			if _frame in [8, 14]:
				_key(KEY_ENTER, true)
			if _frame in [9, 15]:
				_key(KEY_ENTER, false)
			if _main.driver != null and _step_frame > 20:
				var w := _main.driver.world
				var i := _nearest_altar(w)
				if i < 0:
					print("shard_world: no altar on this floor")
					quit(1)
					return false
				_altar = w.rewards.ids[i]
				w.actors.set_pos(0, _front(w))  # SHOT HELPER (labelled): see the header
				_go(&"near")
		&"near":
			if _step_frame == 10:
				_report()
				_grab("near")
				var w := _main.driver.world
				var at := w.rewards.pos(w.rewards.index_of(_altar))
				var side := (at - w.player_pos()).orthogonal().normalized() * 1.7
				w.add_reward(RewardStore.Kind.ALTAR, at + side, 0)  # SHOT HELPER (labelled)
				if w.boss_flow != null:
					w.boss_flow.epic_altar_id = w.rewards.ids[w.rewards.size() - 1]
				w.add_reward(RewardStore.Kind.LEGENDARY, at - side, 0)  # SHOT HELPER (labelled)
				_go(&"tiers")
		&"tiers":
			if _step_frame == 6:
				_grab("tiers")
				_pieces()
				_go(&"pieces")
		&"pieces":
			if _step_frame == 4:
				_grab("pieces")
				print("shard_world: done")
				quit(0)
	return false


func _report() -> void:
	var w := _main.driver.world
	var i := w.rewards.index_of(_altar)
	var node := _main.view.rewards.node_of(_altar)
	var mat: StandardMaterial3D = node.get_meta(&"crystal_mat")
	print(
		(
			"shard_world: altar id=%d sim_pos=%s view_pos=%s tier=%s colour=%s in_reach=%s mood=%s"
			% [
				_altar,
				w.rewards.pos(i),
				node.position,
				node.get_meta(&"tier"),
				mat.albedo_color.to_html(false),
				WorldReader.new(w).reward_in_reach() == i,
				_main.view.stage.mood != null
			]
		)
	)


## SHOT HELPER (labelled): presentation nodes only, beside the hero.
func _pieces() -> void:
	var view := _main.view
	var hero := SimPlane.to_3d(_main.driver.world.player_pos())
	var drop := view.rewards.make_drop(CardFrames.tint(&"pink"))
	drop.position = hero + Vector3(-1.4, 0, 1.0)
	view.rewards.add_child(drop)
	var orb := view.heal_orbs._make()
	orb.position = hero + Vector3(1.3, HealOrbViews.HEIGHT, 1.1)
	view.shards._burst(_main.driver.world.player_pos() + Vector2(0.5, 1.6), 6, 5)


func _nearest_altar(w: World) -> int:
	var best := -1
	for i in w.rewards.size():
		if w.rewards.kind[i] != RewardStore.Kind.ALTAR or Arenas.locked(w, i):
			continue
		var d := w.rewards.pos(i).distance_to(w.player_pos())
		if best < 0 or d < w.rewards.pos(best).distance_to(w.player_pos()):
			best = i
	return best


## A spot just in front of the altar (toward the start point), inside its reach.
func _front(w: World) -> Vector2:
	var at := w.rewards.pos(w.rewards.index_of(_altar))
	var to_start := w.floor_layout.start_pos - at
	return at + to_start.normalized() * 1.1


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _grab(shot: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + shot + ".png"
	img.save_png(path)
	var cam := root.get_camera_3d()
	if cam != null:
		var w := _main.driver.world
		var c := cam.unproject_position(SimPlane.to_3d(w.rewards.pos(w.rewards.index_of(_altar))))
		# The viewport may be stretched to the window: unproject is in the viewport's own size.
		c *= Vector2(img.get_size()) / root.get_visible_rect().size
		var r := Rect2i(Vector2i(c) - CROP / 2, CROP).intersection(
			Rect2i(Vector2i.ZERO, img.get_size())
		)
		var crop := img.get_region(r)
		crop.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(OUT + shot + "_crop.png")
	print("shard_world: ", path, " (frame ", _frame, ", tick ", _main.driver.world.tick, ")")


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
