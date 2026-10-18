extends SceneTree
## v0.8.0 BD (owner O82, O83): each biome's boss door in the real game, the game camera. Boots main.tscn on the first
## run seed whose floor 1 is `biome=<id>` (or `seed=N`), and grabs: the door shut (the hero 3.5 m in front of it, once
## the floor's title card has gone), its prompt (the hero by it), half way down after the interact press (E, by
## Input.parse_input_event), open, and from inside the boss room once
## the boss is dead (sealed, then its seal dark, the hero 6 m in so the slab stands up). Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/boss_doors.gd -- biome=ruins
## (with XDG_DATA_HOME pointed at an empty folder, so a saved run from another build can't turn Enter into Continue).
## SHOT HELPERS (labelled): the hero is held at full HP and set in place (the walk is test_e2e_run_flow's job), and
## the boss is killed directly (the fight is not this shot's subject). Writes <biome>_<shot>.png to
## build/shots/v0.8.0/bd/. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.8.0/bd/"
const GIVE_UP_FRAMES := 6000

var _main: Main
var _frame := 0
var _step := &"boot"
var _step_frame := 0
var _seed := -1
var _biome := &""
var _shots := 0
## `closed_only`: only the shut door (one shot per biome; the rest in one biome).
var _closed_only := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_seed = int(a.substr(5))
		if a == "closed_only":
			_closed_only = true
		if a.begins_with("biome="):
			_biome = StringName(a.substr(6))
	if _seed < 0:
		_seed = _seed_for(_biome)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"boss_doors: renderer=%s device=%s window=%s seed=%d biome=%s"
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


## The first run seed (from 1) whose floor 1 is `biome` (FloorPlan's draw: the run's biome order).
static func _seed_for(biome: StringName) -> int:
	var repo := ContentRepository.load_all()
	var run_def: RunDefinition = repo.get_def(&"run", &"three_floors")
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


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > GIVE_UP_FRAMES:
		print("boss_doors: gave up in step ", _step)
		quit(1)
		return false
	_step_frame += 1
	if _main.driver != null and _main.driver.world != null:
		var w := _world()
		w.actors.hp[0] = w.actors.max_hp[0]  # SHOT HELPER (labelled): see the header.
	match _step:
		&"boot":
			# Enter (Play, then the build pick) until the run on our seed starts: the software renderer is slow to
			# show the menu.
			var started := _main.run != null and _main.run.run_seed == _seed
			if not started and _step_frame % 40 == 8:
				_key(KEY_ENTER, true)
			if not started and _step_frame % 40 == 9:
				_key(KEY_ENTER, false)
			if (
				_main.run != null
				and _main.run.run_seed == _seed
				and _main.driver != null
				and _main.driver.world != null
			):
				var w := _world()
				if w.boss_flow != null and w.boss_flow.arrive_left == 0 and w.tick > 10:
					print(
						(
							"boss_doors: run seed=%d floor biome=%s"
							% [_main.run.run_seed, _main.run_biome_id()]
						)
					)
					if _biome != &"" and _main.run_biome_id() != _biome:
						print("boss_doors: seed %d is not %s" % [_seed, _biome])
						quit(2)
						return false
					_put(w.floor_layout.boss_door_outside(3.5))
					_go(&"closed")
		&"closed":
			if _step_frame < 20 or _world().tick < 330:  # the floor's title card has gone (about 5 s)
				return false
			if _shots == 0:
				_shots = 1
				var d := _main.view.boss_door
				print(
					(
						"boss_doors: model=%s door=%d open=%.2f walls_has_door=%s"
						% [d.from_model, _world().boss_flow.door, d.open_amount, _door_solid()]
					)
				)
				_grab("1_closed")
				if _closed_only:
					quit(0)
					return false
				_put(_world().floor_layout.boss_door_outside(0.9))
				_go(&"prompt")
		&"prompt":
			if _step_frame == 6:
				print("boss_doors: prompt=%s" % _main.get_node("UI/Hud").boss_door.prompt_text())
				_grab("1b_prompt")
			if _step_frame == 8:
				_key(KEY_E, true)
			if _step_frame == 10:
				_key(KEY_E, false)
				_go(&"opening")
		&"opening":
			if _main.view.boss_door.open_amount >= 0.5:
				print(
					(
						"boss_doors: door=%d open=%.2f tick=%d"
						% [_world().boss_flow.door, _main.view.boss_door.open_amount, _world().tick]
					)
				)
				_grab("2_opening")
				_go(&"open")
		&"open":
			if _world().boss_flow.door == BossFlow.Door.OPEN and _step_frame > 10:
				print(
					(
						"boss_doors: door=%d open=%.2f walls_has_door=%s tick=%d"
						% [
							_world().boss_flow.door,
							_main.view.boss_door.open_amount,
							_door_solid(),
							_world().tick
						]
					)
				)
				_grab("3_open")
				_put(_world().floor_layout.boss_door_inside(2.5))
				_go(&"sealed")
		&"sealed":
			var w := _world()
			if w.boss_flow.door_sealed() and w.boss_alive() and _step_frame > 5:
				print("boss_doors: sealed=%s" % w.boss_flow.door_sealed())
				var i := w.actors.index_of(w.boss_id)
				if i >= 0:  # SHOT HELPER (labelled): the boss killed directly
					w.actors.invuln[i] = 0
					Damage.hit(
						w, i, 999999, 0, 0, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i)
					)
				_put(w.floor_layout.boss_door_inside(6.0))
				_go(&"dead")
		&"dead":
			if _main.driver.reader.portal_active() and _step_frame > 20:
				var d := _main.view.boss_door
				print(
					(
						"boss_doors: boss_dead=%s seal_energy=%.2f open=%.2f"
						% [
							not _world().boss_alive(),
							d.seal_material.emission_energy_multiplier,
							d.open_amount
						]
					)
				)
				_grab("4_sealed_boss_dead")
				quit(0)
	return false


func _door_solid() -> bool:
	var door := _world().floor_layout.boss_door_wall
	for x in _world().walls:
		if x.center == door.center and x.half == door.half:
			return true
	return false


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _grab(shot: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s.png" % [_main.view.stage.prop_style, shot]
	img.save_png(path)
	print("boss_doors: ", path, " (frame ", _frame, ", tick ", _world().tick, ")")


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
