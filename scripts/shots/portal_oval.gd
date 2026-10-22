extends SceneTree
## v0.9.0 PT (owner C1-C5, Q15): the oval portals in the real game, the game camera, one biome per run. Boots main.tscn
## on the first run seed whose floor 1 is `biome=<id>` (Enter on the menu through Input.parse_input_event), and grabs
## the boss room's gates growing (half way through the sim's forming) and formed. Needs a renderer (not --headless):
##   godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/portal_oval.gd -- biome=ruins
## (with APPDATA / XDG_DATA_HOME pointed at an empty folder, so a saved run can't turn Enter into Continue).
## SHOT HELPERS (labelled; the subject is the look, not how the hero gets there): the hero is held at full HP and set
## in place inside the boss room (the walk is the e2e's job), and the boss is killed directly. Writes
## <biome>_growing.png and <biome>_formed.png to build/shots/v0.9.0/pt/. Quits on every path (a give-up after
## GIVE_UP_FRAMES). Evidence copies are made by hand.
## Replaces v0.6.1 SW2's portal_shards.gd (the shards went with the stone frame).

const OUT := "res://build/shots/v0.9.0/pt/"
const GIVE_UP_FRAMES := 6000

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _seed := -1
var _biome := &""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_seed = int(a.substr(5))
		if a.begins_with("biome="):
			_biome = StringName(a.substr(6))
	if _seed < 0:
		_seed = _seed_for(_biome)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"portal_oval: renderer=%s device=%s window=%s seed=%d biome=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				DisplayServer.window_get_size(),
				_seed,
				_biome
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	Main.fixed_seed = _seed
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


## The first run seed (from 2) whose floor 1 is `biome` (FloorPlan's draw: the run's biome order).
static func _seed_for(biome: StringName) -> int:
	var repo := ContentRepository.load_all()
	var run_def: RunDefinition = repo.get_def(&"run", RunSaver.RUN_ID)
	for s in range(2, 2000):  # not 1: the main menu's backdrop runs seed 1, and would pass for ours
		var run := RunState.start(s, ContentCompiler.compile_run(run_def), &"blade")
		if run_def.biomes[run.biome_of()] == biome:
			return s
	return 1


func _world() -> World:
	return _main.driver.world


## SHOT HELPER (labelled): sets the hero at `p`, at rest, the camera on it.
func _put(p: Vector2) -> void:
	var w := _world()
	w.actors.set_pos(0, p)
	w.vel = Vector2.ZERO
	_main.view.rig.snap_to(SimPlane.to_3d(p))


## Between the two gates' fronts (or in front of the gate alone), a little back so both read.
func _gates_view_spot() -> Vector2:
	var r := _main.driver.reader
	var f := _world().floor_layout
	var a := r.portal_pos() + f.portal_facing() * 3.2
	if not r.has_deep_portal():
		return a
	var b := r.deep_portal_pos() + Kin.dir(r.deep_portal_angle()) * 3.2
	return (a + b) * 0.5


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > GIVE_UP_FRAMES:
		print("portal_oval: gave up in step ", _step)
		quit(1)
		return false
	_step_frame += 1
	if _main.driver != null and _main.driver.world != null:
		var w := _world()
		w.actors.hp[0] = w.actors.max_hp[0]  # SHOT HELPER (labelled): see the header.
	match _step:
		&"boot":
			var started := _main.run != null and _main.run.run_seed == _seed
			if not started and _step_frame % 40 == 8:
				_key(KEY_ENTER, true)
			if not started and _step_frame % 40 == 9:
				_key(KEY_ENTER, false)
			if started and _main.driver != null and _main.driver.world != null:
				var w := _world()
				if w.boss_flow != null and w.boss_flow.arrive_left == 0 and w.tick > 10:
					print(
						(
							"portal_oval: run seed=%d floor biome=%s"
							% [_main.run.run_seed, _main.run_biome_id()]
						)
					)
					if _biome != &"" and _main.run_biome_id() != _biome:
						print("portal_oval: seed %d is not %s" % [_seed, _biome])
						quit(2)
						return false
					_put(w.floor_layout.boss_door_inside(2.5))
					_go(&"fight")
		&"fight":
			var w := _world()
			# The floor's title card has gone (about 5 s) before the boss dies, so it doesn't cover the gates.
			if w.boss_flow.door_sealed() and w.boss_alive() and _step_frame > 5 and w.tick >= 330:
				print("portal_oval: gate shown during the fight=%s" % _main.view.gate.visible)
				var i := w.actors.index_of(w.boss_id)
				if i >= 0:  # SHOT HELPER (labelled): the boss killed directly
					w.actors.invuln[i] = 0
					Damage.hit(
						w, i, 999999, 0, 0, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i)
					)
				_go(&"opened")
		&"opened":
			if _main.driver.reader.portal_active():
				_put(_gates_view_spot())
				_go(&"growing")
		&"growing":
			var k := _main.driver.reader.portal_form_progress(WorldReader.ROUTE_NORMAL)
			if k >= 0.5:
				_grab("growing", k)
				_go(&"formed")
		&"formed":
			var k := _main.driver.reader.portal_form_progress(WorldReader.ROUTE_NORMAL)
			if k >= 1.0 and _step_frame > 30:
				_grab("formed", k)
				print("portal_oval: done")
				quit(0)
	return false


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _grab(shot: String, k: float) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s.png" % [_main.run_biome_id(), shot]
	img.save_png(path)
	var g := _main.view.gate
	var d := _main.view.deep_gate
	var f := _world().floor_layout
	print(
		(
			"portal_oval: wall clearance (m) gate=%.2f deep=%.2f"
			% [
				_clearance(f.portal_pos, f.portal_angle),
				_clearance(f.deep_portal_pos, f.deep_portal_angle) if d != null else -1.0
			]
		)
	)
	print(
		(
			"portal_oval: %s (frame %d, tick %d) form_progress=%.2f gate_form=%.2f deep_form=%s motes=%s"
			% [
				path,
				_frame,
				_world().tick,
				k,
				g.form(),
				"%.2f" % d.form() if d != null else "-",
				g.motes.emitting
			]
		)
	)


## The oval's clearance to the world's walls (m, to 0.05; the gates' own colliders left out): the largest radius a
## circle along the oval's width keeps off every wall.
func _clearance(pos: Vector2, angle: int) -> float:
	var n := Kin.dir(angle)
	var t := Vector2(-n.y, n.x)
	var gate_half := Routes.collider_at(pos, angle).half
	var radius := 0.0
	while radius < 5.0:
		for k in 17:
			var q := pos + t * (-FloorLayout.OVAL_HALF_W + FloorLayout.OVAL_HALF_W * k / 8.0)
			for w in _world().walls:
				if w.half == gate_half:
					continue
				if Collide.circle_vs_obb(q, radius + 0.05, w) != Vector2.ZERO:
					return radius
		radius += 0.05
	return radius


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
