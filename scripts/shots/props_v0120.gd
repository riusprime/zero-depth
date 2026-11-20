extends SceneTree
## The owner's props (scripts/assets/props_v0120_prep.py) for him to look at:
## - sheet.png: the eleven pieces as ShopModels loads them (their own colours, no biome tint), the timed door whole
##   first, a 1.8 m grey capsule in front of it for the hero's scale, lit by one sun and a grey ambient, seen from the
##   game's iso direction;
## - in the real game view (WorldViewRoot over a lab's floor, the iso camera at the game's size): a Lockdown hazard
##   where it landed (Red Canyon's vent, its crack lit and its plume), the containers and the explosive barrel in a
##   room, the barrel mid-explosion, the final plateau's pylons (one locked in) and that pylon close, the timed door
##   shut and open.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --fixed-fps 60 -s scripts/shots/props_v0120.gd
##   -- out=<folder>
## Writes <folder> (default build/shots/models_v0120b/props/) and prints each path. Quits on every path.

const SIZE := Vector2i(1280, 720)
const SHEET := [
	&"timed_door",
	&"container_crate",
	&"container_urn",
	&"container_barrel",
	&"explosive_barrel",
	&"approach_pylon",
	&"hazard_cable",
	&"hazard_rock",
	&"hazard_vent",
	&"hazard_ice",
	&"hazard_star",
]
const GAP := 0.7
## Frames a scene settles before its shot (the packs' scenes load, the lights come on).
const SETTLE := 20
## Ticks from the barrel's blast to its shot (the pack's fireball near its fullest).
const BLAST_AT := 9

var _dir := "res://build/shots/models_v0120b/props/"
var _vp: SubViewport
var _jobs: Array[StringName] = [&"sheet", &"hazard", &"breakables", &"blast", &"pylons", &"door"]
var _job := -1
var _wait := 0
var _world: World
var _root: WorldViewRoot
var _blast_tick := -1
var _door_open := false
var _close := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_dir = a.substr(4).trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_next()


func _next() -> void:
	_job += 1
	if _vp != null:
		_vp.queue_free()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_root = null
	_wait = SETTLE
	if _job >= _jobs.size():
		return
	match _jobs[_job]:
		&"sheet":
			_sheet()
		&"hazard":
			_hazard()
		&"breakables", &"blast":
			_breakables()
		&"pylons":
			_pylons()
		&"door":
			_door()


func _view(w: World, biome_id: StringName, at: Vector2) -> void:
	_world = w
	_root = WorldViewRoot.new()
	_vp.add_child(_root)
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", biome_id)
	_root.stage.mood = biome.mood
	_root.stage.prop_style = biome.id
	_root.stage.look = biome.look
	_root.setup(WorldReader.new(w), biome.palette, 14.0)
	_root.rig.camera.size = _root.rig.view_size * 0.6
	_root.rig.snap_to(SimPlane.to_3d(at))
	_root.rig.set_process(false)
	_root.rig.set_physics_process(false)
	_root.rig.camera.current = true


func _sheet() -> void:
	var scene := Node3D.new()
	_vp.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#3A3F48")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#9AA3B0")
	env.environment.ambient_light_energy = 0.6
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 40)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#7D7468")
	floor_mesh.material_override = fm
	scene.add_child(floor_mesh)
	var hero := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.8
	hero.mesh = cap
	hero.position = Vector3(0.0, 0.9, 3.0)  # in front of the door, not behind it
	scene.add_child(hero)
	var x := 0.3 + GAP
	for id: StringName in SHEET:
		var m := ShopModels.get_model(id)
		if m.is_empty():
			print("props_v0120: %s is missing" % id)
			quit(1)
			return
		var box: AABB = m["aabb"]
		var node := MeshInstance3D.new()
		node.mesh = m["mesh"]
		node.material_override = m["material"]
		node.position = Vector3(x - box.position.x, 0.0, 0.0)
		scene.add_child(node)
		print("props_v0120: %s %.2f x %.2f x %.2f m" % [id, box.size.x, box.size.z, box.size.y])
		x += box.size.x + GAP
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = x * 0.62
	var dir := Basis(Vector3.UP, deg_to_rad(45.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.0))
	cam.transform = Transform3D(dir, Vector3(x * 0.5, 1.0, 0.0) + dir * Vector3(0, 0, 40))
	scene.add_child(cam)
	cam.current = true


## Red Canyon's vent where the first strike landed, held there.
func _hazard() -> void:
	var w := LockLab.world()
	w.floor_layout.lockdown_kinds[0] = WorldReader.LOCKDOWN_HAZARD
	LockLab.enter(w, LockLab.room(w))
	var s := w.lockdown
	while s.landed_tick < 0 and w.tick - s.sealed_tick < 900:
		w.step(InputFrame.new())
	_view(w, &"red_canyon", s.landed_pos)
	_root.sync()


## The crate, the urn, the barrel and the explosive barrel by the hero's start.
func _breakables() -> void:
	var w := CrackLab.world(&"blade", false)
	var b := w.breakables
	var at := w.floor_layout.start_pos + Vector2(0.0, 3.0)
	b.add(at, Breakables.Kind.CRATE, 0, 0, 0)
	b.add(at + Vector2(1.6, 0.0), Breakables.Kind.URN, 0, 0, 0)
	b.add(at + Vector2(3.2, 0.0), Breakables.Kind.BARREL, 0, 0, 0)
	b.add(at + Vector2(5.4, 0.0), Breakables.Kind.EXPLOSIVE, 0, 0, 0)
	w.step(InputFrame.new())
	_view(w, &"ruins", at + Vector2(2.7, 0.0))
	_blast_tick = -1
	if _jobs[_job] == &"blast":
		Breakables.hit(w, b.pos.size() - 1)


func _pylons() -> void:
	var w := FinalLab.approach(FinalLab.run_state(20261022))
	CombatLab.idle(w, 60)
	w.actors.set_pos(0, w.floor_layout.pylons[0])
	w.step(InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT))
	var mid := (w.floor_layout.pylons[0] + w.floor_layout.pylons[1]) * 0.5
	_view(w, &"starfall", mid)
	_root.rig.camera.size = _root.rig.view_size
	_close = false


func _door() -> void:
	var w := TimedLab.world()
	w.step(InputFrame.new())
	_view(w, &"ruins", w.floor_layout.door_centers[w.floor_layout.timed_door])
	_door_open = false


func _process(_delta: float) -> bool:
	if _job >= _jobs.size():
		quit(0)
		return true
	if _jobs[_job] == &"blast":
		_blast_frame()
	elif _wait > 0:
		_wait -= 1
	else:
		_shoot(_jobs[_job])
	return false


## The barrel's job: the world runs from the hit until BLAST_AT ticks past the blast, then the shot.
func _blast_frame() -> void:
	_world.step(InputFrame.new())
	_root.sync()
	if _blast_tick < 0 and _world.breakables.broken[_world.breakables.pos.size() - 1] == 1:
		_blast_tick = _world.tick
	if _blast_tick >= 0 and _world.tick - _blast_tick >= BLAST_AT:
		_save("barrel_blast.png")
		_next()


## A settled scene's shot; the door opens and the camera closes on the lit pylon for a second one.
func _shoot(job: StringName) -> void:
	if job == &"door" and not _door_open:
		_save("door_shut.png")
		TimedLab.switch(_world, 0)
		TimedLab.switch(_world, 1)
		_root.sync()
		_door_open = true
		_wait = int(TimedDoorView.SINK_S * 60.0) + 10
		return
	if job == &"pylons" and not _close:
		_save("pylons.png")
		_close = true
		_root.rig.camera.size = _root.rig.view_size * 0.25
		_root.rig.snap_to(SimPlane.to_3d(_world.floor_layout.pylons[0], 1.2))
		_wait = 4
		return
	var names := {&"door": "door_open.png", &"pylons": "pylon_lit.png"}
	_save(names.get(job, "%s.png" % job))
	_next()


func _save(file: String) -> void:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + file
	if img.save_png(path) != OK:
		push_error("props_v0120: could not save %s" % path)
	print("props_v0120: ", path)
