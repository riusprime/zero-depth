extends SceneTree
## v0.8.0 HR (owner O89: "lag mostly comes from shooting hordes"): counts what a horde costs the renderer. A scene:
## the iso camera (IsoRig), a sun with shadows, a ground, a wall standing between the camera and part of the crowd
## (the X-ray shows them through it), and N enemies of the horde kinds, Splitlings too (charger=1: all Chargers):
## the real ActorViews over a real World with the compiled enemies, X-ray technique, stepped SPAWN_TICKS past their
## spawn, a third of them flashing as if hit. After `settle` frames it reads, for `frames` frames, RenderingServer's
## draw calls, objects and primitives in the frame and reports their median, plus the actors' MeshInstance3D count.
## Counts, not timings (timings on a busy cloud machine are noise).
## Needs a renderer (Forward+; in a container: xvfb-run with a software Vulkan device):
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/checks/horde_draws.gd \
##     -- [n=120] [frames=30] [settle=30] [tag=after] [shot=1] [charger=1]
## Writes only under build/ (build/perf/horde_draws[_<tag>].txt, with shot=1 build/perf/shots/horde_<tag>.png) and
## prints the same report. Quits on every path.

const OUT_DIR := "res://build/perf"
const KINDS: Array[int] = [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
	WorldReader.KIND_MENDER,
	WorldReader.KIND_MINE_LAYER,
	WorldReader.KIND_SNIPER,
]

## Sim ticks stepped before the view is built (the enemies' spawn is over by then).
const SPAWN_TICKS := 90

var _n := 120
var _frames := 30
var _settle := 30
var _tag := ""
var _shot := false
## charger=1: every enemy a Charger (the perf probe's horde) instead of the horde kinds.
var _charger := false
var _views: ActorViews
var _frame := 0
var _draws: Array[int] = []
var _objects: Array[int] = []
var _prims: Array[int] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"n":
				_n = int(kv[1])
			"frames":
				_frames = int(kv[1])
			"settle":
				_settle = int(kv[1])
			"tag":
				_tag = kv[1]
			"shot":
				_shot = kv[1] == "1"
			"charger":
				_charger = kv[1] == "1"
	var w := World.new(11, PlayerTable.starting_values())
	w.set_enemy_tables(ContentCompiler.compile_enemies(ContentRepository.load_all()))
	var side := ceili(sqrt(float(_n)))
	for k in _n:
		var p := Vector2((k % side) - side * 0.5, (k / side) - side * 0.5) * 1.3 + Vector2(-2, -2)
		w.add_enemy(WorldReader.KIND_CHARGER if _charger else KINDS[k % KINDS.size()], p)
	for t in SPAWN_TICKS:  # past the spawn rise (a spawning enemy is sunk into the ground)
		w.step(InputFrame.new())
	var reader := WorldReader.new(w)
	var scene := Node3D.new()
	root.add_child(scene)
	var rig := IsoRig.new()
	scene.add_child(rig)
	rig.snap_to(Vector3.ZERO)
	rig.camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#2a2622")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.48, 0.45)
	scene.add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#5b544c")
	ground.material_override = gm
	scene.add_child(ground)
	# A wall between the camera (yaw 45: +x +z) and the crowd's near corner.
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(9.0, 2.6, 0.6)
	wall.mesh = box
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("#8d8273")
	wall.material_override = wm
	wall.position = Vector3(3.5, 1.3, 3.5)
	wall.rotation_degrees = Vector3(0, 45, 0)
	scene.add_child(wall)
	_views = ActorViews.new()
	_views.technique = &"xray"
	scene.add_child(_views)
	_views.sync(reader)
	for i in reader.actor_count():  # a third flashing, as if hit
		if reader.actor_team(i) != 0 and i % 3 == 0:
			_views.flash(reader.actor_id(i), 100000)
	_views.set_process(false)  # the flashes hold (the enemy models keep animating: they finish rising)
	print("horde_draws: %d enemies, renderer=%s" % [_n, _renderer()])


func _renderer() -> String:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame <= _settle:
		return false
	_draws.append(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	)
	_objects.append(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	)
	_prims.append(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	)
	if _draws.size() == 1 and _shot:
		_save_shot()
	if _draws.size() < _frames:
		return false
	_report()
	return true


func _save_shot() -> void:
	var dir := OUT_DIR + "/shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/horde_%s.png" % [dir, _tag if not _tag.is_empty() else "shot"]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("shot: ", ProjectSettings.globalize_path(path))


static func _median(a: Array[int]) -> int:
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2] if not s.is_empty() else -1


func _report() -> void:
	var meshes := _views.find_children("*", "MeshInstance3D", true, false).size()
	var lines := PackedStringArray()
	var kinds := "Chargers" if _charger else "%d kinds" % KINDS.size()
	lines.append("horde_draws: %d enemies (%s), tag=%s" % [_n, kinds, _tag])
	(
		lines
		. append(
			(
				"renderer=%s msaa_3d=%d thread_model=%s"
				% [
					_renderer(),
					root.msaa_3d,
					str(ProjectSettings.get_setting("rendering/driver/threads/thread_model")),
				]
			)
		)
	)
	lines.append("frames read: %d (after %d settle)" % [_draws.size(), _settle])
	lines.append(
		"draw_calls median: %d (min %d, max %d)" % [_median(_draws), _draws.min(), _draws.max()]
	)
	lines.append("objects median: %d" % _median(_objects))
	lines.append("primitives median: %d" % _median(_prims))
	lines.append("actor MeshInstance3D nodes: %d" % meshes)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var name := "horde_draws%s.txt" % ("_" + _tag if not _tag.is_empty() else "")
	var f := FileAccess.open(OUT_DIR + "/" + name, FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
