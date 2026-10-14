extends SceneTree
## v0.8.0 EC G2 (owner O2, Q1 "By role"): the 14 normal enemy kinds in a 7 x 2 grid, lit in the real game view
## (WorldViewRoot: the biome's mood, look and stage, the iso camera, ActorViews) of a real World, once per palette in
## EnemyPalettes (current, A, B, C), each kind labelled with its name and role. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mock_enemy_colours.gd
## Options after `--`: palettes=current,a,b,c  biomes=ruins,frozen_shore  modes=off,deuteranopia,tritanopia
## (the colour-blind modes are ThemePalette's: the views build with that mode on, as a player with it set would see).
## Writes build/shots/<version>/ec/<palette>_<biome>_<mode>.png and prints each path. The world is stepped only until
## every kind has risen out of the ground (each held on its grid spot), then frozen while the frame-time animation
## settles. Labels are drawn by this script (English). Quits on every path.

const SETTLE := 40
const STEP_LIMIT := 600
const COLUMNS := 7
const SPACING := 2.05
const ROW_GAP := 3.2
const VIEW_SIZE := 8.8
## [kind, label]. The hovering drones sit in the top row, so they float into the empty space above it.
const PLAN := [
	[ActorStore.Kind.NEEDLE, "Needle"],
	[ActorStore.Kind.ARC_CASTER, "Arc Caster"],
	[ActorStore.Kind.SNIPER, "Sniper"],
	[ActorStore.Kind.LENS_DRONE, "Lens Drone"],
	[ActorStore.Kind.BOMB_DRONE, "Bomb Drone"],
	[ActorStore.Kind.MINE_LAYER, "Mine Layer"],
	[ActorStore.Kind.MENDER, "Mender"],
	[ActorStore.Kind.CHARGER, "Charger"],
	[ActorStore.Kind.HATCHLING, "Hatchling"],
	[ActorStore.Kind.SWARMER, "Swarmer"],
	[ActorStore.Kind.SPLITTER, "Splitter"],
	[ActorStore.Kind.SPLITLING, "Splitling"],
	[ActorStore.Kind.WARDEN, "Warden"],
	[ActorStore.Kind.SHIELD_BEARER, "Shield Bearer"],
]
const TITLES := {
	&"current": "Today (shipped default): red and grey",
	&"a": "A: saturated role colours",
	&"b": "B: muted, weathered role colours on the plates",
	&"c": "C: grey bodies, role colour on trims and glow",
}
const ROLE_NAMES := {
	&"melee": "melee rusher",
	&"ranged": "ranged caster",
	&"bomber": "bomber / mines",
	&"support": "support",
	&"tank": "tank",
}
## Screen right and screen down on the sim plane under the fixed iso yaw (IsoRig.YAW_DEG = 45).
const RIGHT := Vector2(0.70710678, 0.70710678)
const DOWN := Vector2(0.70710678, -0.70710678)
## The hero stands below the grid's middle, so the kinds face the camera and the hero's warm light reaches them, as
## in play.
const PLAYER_AT := Vector2(3.75, -3.75)

var _dir := ""
var _repo: ContentRepository
var _jobs: Array = []
var _job := -1
var _world: World
var _view: WorldViewRoot
var _labels: CanvasLayer
var _spots: Array[Vector2] = []
var _ids: Array[int] = []
var _ticks := 0
var _settle := -1
var _frame := 0


func _initialize() -> void:
	var palettes: Array = ["current", "a", "b", "c"]
	var biomes: Array = ["ruins", "frozen_shore"]
	var modes: Array = ["off"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("palettes="):
			palettes = a.trim_prefix("palettes=").split(",")
		elif a.begins_with("biomes="):
			biomes = a.trim_prefix("biomes=").split(",")
		elif a.begins_with("modes="):
			modes = a.trim_prefix("modes=").split(",")
	for p in palettes:
		for b in biomes:
			for m in modes:
				_jobs.append([StringName(p), StringName(b), StringName(m)])
	_dir = "res://build/shots/v0.8.0/ec/"  # the step's version (the project still reads v0.7.5-dev here)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	for k in PLAN.size():
		var col := k % COLUMNS - (COLUMNS - 1) * 0.5
		var row := float(k / COLUMNS) - 0.5
		_spots.append(RIGHT * col * SPACING + DOWN * row * ROW_GAP + DOWN * 0.6)
	_next()


func _next() -> bool:
	if _view != null:
		_view.queue_free()
		_view = null
	if _labels != null:
		_labels.queue_free()
		_labels = null
	_job += 1
	if _job >= _jobs.size():
		EnemyPalettes.active = EnemyPalettes.CURRENT
		ThemePalette.mode = &"off"
		return false
	var job: Array = _jobs[_job]
	if not EnemyPalettes.TABLE.has(job[0]):
		push_error("mock_enemy_colours: no palette %s" % job[0])
		return false
	EnemyPalettes.active = job[0]
	ThemePalette.mode = job[2] if ThemePalette.MODES.has(job[2]) else &"off"
	var biome: BiomeDefinition = _repo.get_def(&"biomes", job[1])
	_world = World.new(7, PlayerTable.starting_values())
	_world.set_enemy_tables(ContentCompiler.compile_enemies(_repo))
	var walls: Array[Obb] = []
	walls.append(Obb.make(Vector2(0, 9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(0, -9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(9.5, 0), Vector2(0.4, 9), 0))
	walls.append(Obb.make(Vector2(-9.5, 0), Vector2(0.4, 9), 0))
	_world.set_walls(walls)
	_world.actors.set_pos(0, PLAYER_AT)
	_ids.clear()
	for k in PLAN.size():
		_ids.append(_world.add_enemy(PLAN[k][0], _spots[k]))
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	if biome.look != null:  # the first three biomes have no look (Ruins draws as before)
		_view.stage.look = biome.look
		_view.actors.enemy_tint = biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.rig.view_size = VIEW_SIZE
	_view.rig.camera.size = VIEW_SIZE
	_view.rig.snap_to(SimPlane.to_3d(Vector2.ZERO))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_ticks = 0
	_settle = -1
	return true


func _hold() -> void:
	var a := _world.actors
	a.set_pos(0, PLAYER_AT)
	a.hp[0] = a.max_hp[0]
	for k in _ids.size():
		var i := a.index_of(_ids[k])
		if i >= 0:
			a.set_pos(i, _spots[k])


func _all_risen() -> bool:
	var a := _world.actors
	for id in _ids:
		var i := a.index_of(id)
		if i < 0 or a.state[i] == EnemyAi.State.SPAWN:
			return false
	return true


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 20000 or _view == null:
		quit(1 if _view == null and _job < _jobs.size() else 0)
		return false
	if _settle < 0:
		_hold()
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, 0))
		_hold()
		_view.sync()
		_ticks += 1
		if (_all_risen() and _ticks > 60) or _ticks > STEP_LIMIT:
			_settle = SETTLE
			_draw_labels()
		return false
	_settle -= 1
	if _settle > 0:
		return false
	var job: Array = _jobs[_job]
	var path := _dir + "%s_%s_%s.png" % job
	var img := root.get_texture().get_image()
	if img == null or img.save_png(path) != OK:
		push_error("mock_enemy_colours: could not save %s" % path)
		quit(1)
		return false
	print(
		(
			"mock_enemy_colours: %s (ticks=%d risen=%s projectiles=%d size=%s)"
			% [path, _ticks, _all_risen(), _world.projectiles.size(), img.get_size()]
		)
	)
	if not _next():
		quit(0)
	return false


func _draw_labels() -> void:
	_labels = CanvasLayer.new()
	root.add_child(_labels)
	var job: Array = _jobs[_job]
	var title := Label.new()
	title.text = (
		"%s  |  %s  |  colour mode: %s"
		% [TITLES.get(job[0], String(job[0])), String(job[1]).capitalize(), job[2]]
	)
	title.label_settings = _settings(30)
	title.position = Vector2(32, 20)
	_labels.add_child(title)
	var cam := _view.rig.camera
	for k in PLAN.size():
		var id := EnemyPalettes.KIND_IDS[int(PLAN[k][0])] as StringName
		var role: StringName = EnemyPalettes.ROLES[id]
		var at := cam.unproject_position(SimPlane.to_3d(_spots[k]))
		var l := Label.new()
		l.text = "%s\n%s" % [PLAN[k][1], ROLE_NAMES[role]]
		l.label_settings = _settings(20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(220, 60)
		l.position = at + Vector2(-110, 34)
		_labels.add_child(l)


func _settings(size: int) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = Color("#F3E9DD")
	s.outline_size = 6
	s.outline_color = Color(0, 0, 0, 0.9)
	return s
