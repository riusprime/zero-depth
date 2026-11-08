extends SceneTree
## v0.11.0 O17c: the Stone Thrower's clip sheet for the owner (StoneThrowerAvatar on the owner's model): one row per
## clip, five moments across each, from the game camera's angle (the iso pitch and yaw) on a plain floor, each cell
## its own little world with the avatar driven by the calls ActorViews makes (apply_state / advance / flinch / die).
## The last row is the real game (WorldViewRoot on the Night Rocks, a real World): the rip, the lift, the rock in
## flight, the impact (the pack's rock impact, dust and debris, the crack mark) and the rock crumbling at the end of
## its 15 s. Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --audio-driver Dummy --resolution 1280x720 --position -10000,-10000
##     -s scripts/shots/o17_stone_thrower_clips.gd
## Writes build/shots/o17/stone_thrower_clips.png (and the game row's moments full size, stone_thrower_game_<k>.png)
## and prints the sheet's path.

const CELL := Vector2i(240, 220)
## The sheet is drawn in its own viewport (any size, whatever the window's).
const SHEET := Vector2i(1220, 2720)
const DT := 1.0 / 60.0
const FACING_YAW := -0.45
const OUT := "res://build/shots/o17/"
## [label, steps, moments (ticks or frames, per the steps)].
const ROWS := [
	["idle (breathing, arms swaying)", "idle", [0, 36, 72, 108, 144]],
	["walk 1.8 m/s (one stride)", "walk", [0, 8, 16, 24, 32]],
	["rip the rock (lift ticks 5-23)", "lift", [5, 12, 16, 19, 23]],
	["lift overhead, the tell (ticks 26-47)", "lift", [26, 31, 37, 43, 47]],
	["throw (release on ACTIVE tick 0)", "throw", [0, 3, 7, 12, 27]],
	["recovery", "recover", [5, 15, 25, 35, 47]],
	["hit flinch", "flinch", [1, 3, 5, 8, 12]],
	["death", "death", [9, 27, 48, 63, 96]],
	["death holding the rock", "death_rock", [9, 27, 48, 63, 96]],
	["reduced motion: lift 37, 47; throw 7; death 48, 96", "calm", [0, 1, 2, 3, 4]],
]
## The game row: [label, what to wait for].
const GAME := [
	["rip", "rip"],
	["lift (ring marked)", "lift"],
	["rock in flight", "flight"],
	["impact", "impact"],
	["crumbles (15 s on)", "crumble"],
]
const GAME_SIZE := Vector2i(800, 560)
const HERO_AT := Vector2(0.0, -4.0)
const HERO_OUT := Vector2(-1.2, -6.4)
## Along the screen's horizontal from the hero (sim +x +y is screen right at the iso yaw), the view centred between.
const THROWER_AT := Vector2(4.4, 0.4)

var _frame := 0
var _sheet: SubViewport
var _phase := 0
var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _id := -1
var _shots: Array[Image] = []
var _g := 0
var _wait := -1.0
var _acc := 0.0
var _landed_at := -1
var _crumble_from := -1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = GAME_SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_world = StageScenario.build(
		47, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_world.actors.set_pos(0, HERO_AT)
	_world.actors.invuln[0] = 1 << 24
	_id = _world.add_enemy(ActorStore.Kind.STONE_THROWER, THROWER_AT)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"night_rocks")
	_view = WorldViewRoot.new()
	_view.stage.prop_style = biome.id
	_view.stage.mood = biome.mood
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_vp.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.actors.cull = null
	_view.rig.view_size = 9.0
	_view.rig.camera.size = 9.0
	_view.rig.snap_to(SimPlane.to_3d(HERO_AT.lerp(THROWER_AT, 0.5)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true


# --- The game row ------------------------------------------------------------------------------------------------


func _thrower() -> int:
	return _world.actors.index_of(_id)


## Whether the game row's moment `what` has come (then the capture waits `_wait` real seconds).
func _ready_for(what: String) -> bool:
	var i := _thrower()
	if i < 0:
		return false
	var a := _world.actors
	var winding := a.state[i] == EnemyAi.State.WINDUP
	var rocks := _view.reader.thrown_rocks()
	var ready := {
		"rip": winding and a.state_t[i] >= 17,
		"lift": winding and a.state_t[i] >= 44,
		"flight": _view.reader.thrower_flight(i) >= 420,
		"impact": _landed_at >= 0,
		"crumble": not rocks.is_empty() and int((rocks[0] as Array)[2]) <= 12,
	}
	return bool(ready.get(what, false))


func _game_step() -> void:
	var i := _thrower()
	if i >= 0 and _world.actors.state[i] != EnemyAi.State.MOVE:
		_world.actors.set_pos(0, HERO_OUT)  # out of the ring once it has aimed: the rock stands
	elif _world.ruins_rocks.rock_count() == 0:
		_world.actors.set_pos(0, HERO_AT)
	_world.actors.hp[0] = _world.actors.max_hp[0]
	var before := _world.ruins_rocks.rock_count()
	var f := InputFrame.new()
	_world.step(f)
	if _world.ruins_rocks.rock_count() > before and _landed_at < 0:
		_landed_at = _world.tick
	if _landed_at >= 0 and _world.ruins_rocks.rock_count() > 0:
		# (after the impact: keep it from throwing again, so the one rock is the one that crumbles)
		var j := _thrower()
		if j >= 0:
			_world.actors.cd[j] = 600
	_view.sync()
	_view.rig.snap_to(SimPlane.to_3d(HERO_AT.lerp(THROWER_AT, 0.5)))  # (its sync aims the camera at the hero)


func _process(delta: float) -> bool:
	_frame += 1
	if _phase == 0:
		return _game(delta)
	if _phase == 1:
		_build_sheet()
		_phase = 2
		_frame = 0
		return false
	if _frame < 14:
		return false
	var sheet := _sheet.get_texture().get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var png := OUT + "stone_thrower_clips.png"
	sheet.save_png(png)
	print("o17c clips: ", ProjectSettings.globalize_path(png))
	return true


func _game(delta: float) -> bool:
	var what: String = GAME[_g][1]
	if _wait < 0.0:
		if _ready_for(what):
			_wait = 0.12 if what == "impact" else 0.04
			return false
		# fast through the 15 s wait, one tick per 1/60 s near the moments
		var fast := what == "crumble" and _view.reader.thrown_rocks().size() > 0
		if fast and int((_view.reader.thrown_rocks()[0] as Array)[2]) > 40:
			for k in 6:
				_game_step()
			return false
		_acc += delta
		if _acc < DT:
			return false
		_acc -= DT
		_game_step()
		if _world.tick > 4000:
			push_error("o17c: the game row never reached " + what)
			_wait = 0.01
		return false
	_wait -= delta
	if _wait > 0.0:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	_shots.append(img)
	img.save_png(OUT + "stone_thrower_game_%d.png" % _g)  # (each game moment full size, beside the sheet)
	_wait = -1.0
	_g += 1
	if _g == GAME.size():
		_vp.queue_free()
		_view = null
		_phase = 1
	return false


# --- The avatar rows ---------------------------------------------------------------------------------------------


func _build_sheet() -> void:
	_sheet = SubViewport.new()
	_sheet.size = SHEET
	_sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sheet.transparent_bg = false
	root.add_child(_sheet)
	var bg := ColorRect.new()
	bg.color = Color("#2a2c33")
	bg.size = Vector2(SHEET)
	_sheet.add_child(bg)
	var col := VBoxContainer.new()
	_sheet.add_child(col)
	for row: Array in ROWS:
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = row[0]
		col.add_child(label)
		var line := HBoxContainer.new()
		col.add_child(line)
		var moments: Array = row[2]
		for m in moments.size():
			_cell(line, row[1], int(moments[m]), m)
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = (
		"in the game (Night Rocks): " + ", ".join(GAME.map(func(g: Array) -> String: return g[0]))
	)
	col.add_child(label)
	var line := HBoxContainer.new()
	col.add_child(line)
	for img in _shots:
		var rect := TextureRect.new()
		var small := img.duplicate() as Image
		var w := CELL.x * 5 / GAME.size()
		small.resize(w, int(w * float(GAME_SIZE.y) / GAME_SIZE.x), Image.INTERPOLATE_LANCZOS)
		rect.texture = ImageTexture.create_from_image(small)
		line.add_child(rect)


func _cell(line: HBoxContainer, steps: String, moment: int, column: int) -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(CELL)
	line.add_child(box)
	var vp := SubViewport.new()
	vp.size = CELL
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var scene := Node3D.new()
	vp.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#1b1d24")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#9aa3b5")
	env.environment.ambient_light_energy = 0.55
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#5a564f")
	floor_mi.material_override = fm
	scene.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.9
	var look := Vector3(0.05, 1.0, 0)
	var dir := (
		Basis(Vector3.UP, deg_to_rad(45.0))
		* Basis(Vector3.RIGHT, deg_to_rad(-35.26))
		* Vector3.BACK
	)
	scene.add_child(cam)
	cam.look_at_from_position(look + dir * 10.0, look, Vector3.UP)
	cam.current = true
	var facing := Node3D.new()
	facing.rotation.y = FACING_YAW
	scene.add_child(facing)
	var a := StoneThrowerAvatar.new()
	a.setup(Color("#1A1A22"))
	facing.add_child(a)
	a.set_process(false)
	_drive(a, steps, moment, column)


func _state(tick: int, x: float, state: int, st := -1) -> Dictionary:
	var s := {"tick": tick, "pos": Vector2(x, 0), "state": state, "facing": Vector2(1, 0)}
	if st >= 0:
		s["state_ticks"] = st
	return s


static func _run(a: StoneThrowerAvatar, frames: int) -> void:
	for k in frames:
		a.advance(DT)
		a.advance_flinch(DT)


## Drives `a` to `moment` of `steps` (see ROWS): ticks of the sim one per frame, as the game gives them.
func _drive(a: StoneThrowerAvatar, steps: String, moment: int, column: int) -> void:
	var tick := 0
	var x := 0.0
	var calm := steps == "calm"
	ViewPrefs.reduced_motion = calm
	var walk := steps == "walk"
	var idle := 60 + (moment if steps in ["idle", "walk"] else 0)
	for k in idle:
		tick += 1
		x += 1.8 * DT if walk else 0.0
		a.apply_state(_state(tick, x, WorldReader.STATE_MOVE))
		_run(a, 1)
	if steps in ["idle", "walk"]:
		ViewPrefs.reduced_motion = false
		return
	if steps in ["flinch"]:
		a.flinch(Vector2(-1.0, 0.3), 1.0)
		_run(a, moment)
		return
	var plan := {
		"lift": [WorldReader.STATE_WINDUP, moment, -1],
		"throw": [WorldReader.STATE_ACTIVE, moment, -1],
		"recover": [WorldReader.STATE_RECOVER, moment, -1],
		"death": [WorldReader.STATE_MOVE, 0, moment],
		"death_rock": [WorldReader.STATE_WINDUP, 40, moment],
	}
	if calm:
		plan = {
			"calm":
			[
				[WorldReader.STATE_WINDUP, 37, -1],
				[WorldReader.STATE_WINDUP, 47, -1],
				[WorldReader.STATE_ACTIVE, 7, -1],
				[WorldReader.STATE_MOVE, 0, 48],
				[WorldReader.STATE_MOVE, 0, 96],
			][column]
		}
	var p: Array = plan[steps]
	var until: int = p[0]
	var order := [WorldReader.STATE_WINDUP, WorldReader.STATE_ACTIVE, WorldReader.STATE_RECOVER]
	var lengths := [
		StoneThrowerAvatar.TICKS.x, StoneThrowerAvatar.TICKS.y, StoneThrowerAvatar.TICKS.z
	]
	if until != WorldReader.STATE_MOVE:
		for o in order.size():
			var last: int = lengths[o] if order[o] != until else int(p[1]) + 1
			for k in last:
				tick += 1
				a.apply_state(_state(tick, x, order[o], k))
				_run(a, 1)
			if order[o] == until:
				break
	if int(p[2]) >= 0:
		a.die()
		_run(a, int(p[2]))
	ViewPrefs.reduced_motion = false
