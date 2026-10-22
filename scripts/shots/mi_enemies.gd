extends SceneTree
## v0.8.0 MI: the owner's four enemy models in the game's avatars (HordeAvatar, LensDroneAvatar), each in six poses
## driven through apply_state (the same values sync() reads from the sim), from the game's iso camera on a flat
## ground. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1800x420 -s scripts/shots/mi_enemies.gd
## Writes build/shots/<version>/mi_enemies/<kind>.png (one row of six) and prints each path. Poses: idle; walking
## (the node moved 2 m/s); the windup at 70 % (the raise held); the strike (ACTIVE, the snap); a hit flash (the body
## materials' flash, as ActorViews sets it); the death half-way. The Mender's third and fourth: healing (the crystals
## raised and lit); the Lens Drone's: charging (the eye flaring, the feet spinning).

const ROWS := [
	["shield_bearer", WorldReader.KIND_SHIELD_BEARER],
	["splitter", WorldReader.KIND_SPLITTER],
	["splitling", WorldReader.KIND_SPLITLING],
	["mender", WorldReader.KIND_MENDER],
	["lens_drone", WorldReader.KIND_LENS_DRONE],
]
const LABELS := ["idle", "walk", "windup 70%", "strike", "hit flash", "death"]
const FRAMES := 64
const SPACING := 2.2

var _dir := ""
var _vp: SubViewport
var _row := 0
var _frame := 0
var _avatars: Array = []
var _holders: Array[Node3D] = []


func _initialize() -> void:
	_dir = "res://build/shots/%s/mi_enemies/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1800, 420)
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	print("mi_enemies: renderer=%s" % RenderingServer.get_current_rendering_method())
	_build(0)


func _build(r: int) -> void:
	for c in _vp.get_children():
		c.queue_free()
	var scene := Node3D.new()
	_vp.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#5A524C")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#C9CEDA")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 35, 0)
	light.shadow_enabled = true
	scene.add_child(light)
	var g := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	g.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#8C8278")
	g.material_override = gm
	scene.add_child(g)
	var rig := IsoRig.new()
	rig.set_process(false)
	scene.add_child(rig)
	rig.view_size = 3.4
	rig.camera.size = 3.4
	var right := Vector3(cos(PI / 4), 0, -sin(PI / 4))
	_avatars.clear()
	_holders.clear()
	var kind: int = ROWS[r][1]
	for j in 6:
		var holder := Node3D.new()
		holder.position = right * (float(j) - 2.5) * SPACING
		holder.rotation = Vector3(0, -PI * 0.25 + 0.5, 0)  # three-quarters toward the camera
		scene.add_child(holder)
		var a: AvatarBase
		if kind == WorldReader.KIND_LENS_DRONE:
			var l := LensDroneAvatar.new()
			l.setup(Color("#1A1A22"))
			a = l
		else:
			var h := HordeAvatar.new()
			h.setup(kind, Color("#1A1A22"))
			a = h
		holder.add_child(a)
		_avatars.append(a)
		_holders.append(holder)
	rig.snap_to(Vector3(0, 0.6, 0))
	rig.camera.current = true
	_row = r
	_frame = 0


func _process(_delta: float) -> bool:
	_frame += 1
	var kind: int = ROWS[_row][1]
	for j in 6:
		var a: AvatarBase = _avatars[j]
		var state := WorldReader.STATE_MOVE
		var windup := 0.0
		var healing := false
		match j:
			1:
				_holders[j].position += (
					Vector3(cos(PI / 4), 0, -sin(PI / 4))
					* (2.0 / 60.0)
					* (1.0 if _frame % 40 < 20 else -1.0)
				)
			2:
				state = WorldReader.STATE_WINDUP
				windup = clampf(float(_frame) / 40.0, 0.0, 0.7)
				healing = kind == WorldReader.KIND_MENDER
			3:
				state = WorldReader.STATE_WINDUP if _frame < 50 else WorldReader.STATE_ACTIVE
				windup = clampf(float(_frame) / 45.0, 0.0, 1.0)
				healing = kind == WorldReader.KIND_MENDER
		var s := {"tick": _frame, "state": state, "windup": windup, "healing": healing}
		if a is HordeAvatar:
			(a as HordeAvatar).apply_state(s)
		elif a is LensDroneAvatar:
			(a as LensDroneAvatar).apply_state(s)
		if j == 4 and _frame > FRAMES - 4:
			for m: StandardMaterial3D in a.body_materials:  # ActorViews' flash
				m.emission = Color.WHITE
				m.emission_energy_multiplier = 1.6
		if j == 5 and _frame == FRAMES - 12 and a is HordeAvatar:
			(a as HordeAvatar).die()
	if _frame < FRAMES:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path := _dir + "%s.png" % ROWS[_row][0]
	img.save_png(path)
	print("mi_enemies: ", path, " (", ", ".join(LABELS), ")")
	if _row + 1 >= ROWS.size():
		return true
	_build(_row + 1)
	return false
