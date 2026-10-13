extends SceneTree
## v0.7.5 BM: renders the owner's Warlord, Hive Lens and Foundry models. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1800x400 -s scripts/shots/boss_models.gd -- mode=raw
##   ... --resolution 1600x840 -s scripts/shots/boss_models.gd -- mode=poses [view=side|front]
## Writes build/shots/v0.7.5/boss_models/ and prints each path.
## raw: each model exactly as delivered (no turn, no scale), turned 0/90/180/270 degrees about Y under a camera on
## +Z looking down -Z, then from above (+X right, -Z up); the red stick is the file's +X, the blue its +Z. It prints the
## file's bounds. This is where BossModels.SPECS' yaw and height come from (evidence/BOSS_MODELS.md).
## poses: each boss avatar with its model, from the game's iso camera next to the hero, in eight poses driven
## through BossAvatar.apply_state (the same inputs sync() reads from the sim), two rows of four. view=side or
## view=front: the same poses close up from a low side or three-quarter front camera.

const IDS: Array[StringName] = [&"warlord", &"hive_lens", &"foundry"]
const RAW_CELL := Vector2i(360, 400)
const ROW := Vector2i(1600, 420)
const SHOT_FRAMES := 70
## Per boss, eight poses: [label, state, move, extra keys for apply_state]. "walk" moves it; "die" plays the fall.
const POSES := {
	&"warlord":
	[
		["walk", 1, -1, {"walk": true}],
		["shield lifted (weak point open)", 4, -1, {"weak": 1.0}],
		["spear raised (spear lines windup)", 2, 12, {}],
		["spear planted (spear lines)", 3, 12, {}],
		["spear couched (lunge windup)", 2, 3, {}],
		["javelin drawn (javelin rain windup)", 2, 7, {}],
		["shielded hook", 1, -1, {"shielded": true}],
		["death fall", 1, -1, {"die": true}],
	],
	&"hive_lens":
	[
		["idle", 1, -1, {}],
		["moving (tails trail)", 1, -1, {"walk": true}],
		["open (weak point open)", 4, -1, {"weak": 1.0}],
		["closed (shielded hook)", 1, -1, {"shielded": true}],
		["split (deploy windup)", 2, 10, {"phase": 1}],
		["dive windup", 2, 4, {}],
		["glare (ring windup)", 2, 0, {}],
		["staggered", 5, -1, {}],
	],
	&"foundry":
	[
		["idle", 1, -1, {}],
		["walk (diagonal steps)", 1, -1, {"walk": true}],
		["pour (molten flood windup)", 2, 12, {}],
		["vent crouch (ring windup)", 2, 0, {}],
		["launch (bomb launch windup)", 2, 6, {}],
		["weak point open", 4, -1, {"weak": 1.0}],
		["shielded hook", 1, -1, {"shielded": true}],
		["staggered", 5, -1, {}],
	],
}

var _mode := "poses"
var _view := "iso"
var _dir := ""
var _frame := 0
var _k := 0
var _row := 0
var _vp: SubViewport
var _avatars: Array[BossAvatar] = []
var _rows: Array[Image] = []


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_mode = args.get("mode", _mode)
	_view = args.get("view", _view)
	_dir = "res://build/shots/%s/boss_models/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	print(
		"boss_models: renderer=%s mode=%s" % [RenderingServer.get_current_rendering_method(), _mode]
	)
	_vp = SubViewport.new()
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	if _mode == "raw":
		_vp.size = Vector2i(RAW_CELL.x * 5, RAW_CELL.y)
		_build_raw(0)
	else:
		_vp.size = ROW
		BossModels.preload_all()
		_build_row(0, 0)


func _process(_delta: float) -> bool:
	_frame += 1
	return _raw_process() if _mode == "raw" else _poses_process()


func _scene(bg: Color) -> Node3D:
	for c in _vp.get_children():
		c.queue_free()
	var scene := Node3D.new()
	_vp.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#C9CEDA")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	scene.add_child(light)
	return scene


# --- raw --------------------------------------------------------------------------------------------------------


func _build_raw(k: int) -> void:
	var scene := _scene(Color("#30343C"))
	var ps: PackedScene = load(BossModels.DIR + String(IDS[k]) + ".glb")
	var low := 0.0
	var inst0: Node = ps.instantiate()
	for mi: MeshInstance3D in inst0.find_children("*", "MeshInstance3D", true, false):
		var box := mi.mesh.get_aabb()
		print("boss_models: %s raw mesh bounds %s (skin: %s)" % [IDS[k], box, mi.skin != null])
		low = box.position.y
	inst0.free()
	for v in 5:
		var holder := Node3D.new()
		holder.position = Vector3((v - 2) * 1.05, -minf(low, 0.0), 0)
		scene.add_child(holder)
		holder.add_child(ps.instantiate())
		if v < 4:
			holder.rotation = Vector3(0, v * PI * 0.5, 0)
		else:
			holder.rotation = Vector3(PI * 0.5, 0, 0)
			holder.position.y = 0.5
		for ax: Array in [[Vector3(0.35, 0, 0), Color.RED], [Vector3(0, 0, 0.35), Color.BLUE]]:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.02, 0.02, 0.02) + (ax[0] as Vector3).abs()
			m.mesh = b
			var mat := StandardMaterial3D.new()
			mat.albedo_color = ax[1]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.material_override = mat
			m.position = (ax[0] as Vector3) * 0.5 + Vector3(0, minf(low, 0.0), 0)
			holder.add_child(m)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.2
	cam.position = Vector3(0, 0.5, 5)
	scene.add_child(cam)
	cam.current = true
	_frame = 0


func _raw_process() -> bool:
	if _frame < 30:
		return false
	var path := _dir + "raw_%s.png" % IDS[_k]
	_grab().save_png(path)
	print("boss_models: ", path, " (views: yaw 0, 90, 180, 270 degrees, then from above)")
	_k += 1
	if _k >= IDS.size():
		return true
	_build_raw(_k)
	return false


# --- poses ------------------------------------------------------------------------------------------------------


func _avatar(id: StringName) -> BossAvatar:
	var a: BossAvatar = (
		{&"warlord": WarlordAvatar, &"hive_lens": HiveLensAvatar, &"foundry": FoundryAvatar}[id]
		. new()
	)
	a.setup(Color("#1A1A22"))
	a.set_process(false)
	return a


func _build_row(k: int, row: int) -> void:
	var scene := _scene(Color("#C8A57A"))
	var g := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	g.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#C8A57A")
	gm.roughness = 1.0
	g.material_override = gm
	scene.add_child(g)
	_avatars.clear()
	var rig := IsoRig.new()
	rig.set_process(false)
	scene.add_child(rig)
	rig.view_size = 7.5
	rig.camera.size = 7.5
	var right := Vector3(cos(PI / 4), 0, -sin(PI / 4))
	for j in 4:
		var a := _avatar(IDS[k])
		a.position = right * (float(j) - 1.5) * 4.6
		a.rotation = Vector3(0, -PI * 0.25 + 0.45, 0)
		scene.add_child(a)
		_avatars.append(a)
	var hero := PlayerAvatar.new()
	hero.setup(Color("#1A1A22"))
	hero.position = right * -9.0 + Vector3(1.2, 0, 1.2)
	scene.add_child(hero)
	rig.snap_to(Vector3(0, 1.0, 0) + right * -0.6)
	rig.camera.current = true
	if _view != "iso":
		# A low side view (the boss's right, its spear side) or a three-quarter front view, close up.
		rig.queue_free()
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 4.2
		cam.position = Vector3(0, 1.4, 30)
		scene.add_child(cam)
		cam.current = true
		hero.position = Vector3(-7.4, 0, 0)
		for j in 4:
			_avatars[j].position = Vector3((float(j) - 1.5) * 3.6, 0, 0)
			_avatars[j].rotation = Vector3(0, 0.0 if _view == "side" else -PI * 0.5 + 0.6, 0)
	_k = k
	_row = row
	_frame = 0


func _poses_process() -> bool:
	var poses: Array = POSES[IDS[_k]]
	var t := _frame
	for j in 4:
		var pose: Array = poses[_row * 4 + j]
		var extra: Dictionary = pose[3]
		var state: int = pose[1]
		var st := state
		if state == WorldReader.STATE_ACTIVE and t < 50:
			st = WorldReader.STATE_WINDUP  # an attack winds up first, then goes active before the grab
		var s := {
			"tick": t,
			"pos": Vector2(t * 0.035, 0) if extra.get("walk", false) else Vector2.ZERO,
			"state": st,
			"move": pose[2],
			"windup": clampf(float(t) / 45.0, 0.0, 1.0) * 0.9,
			"phase": extra.get("phase", 0),
			"weak": extra.get("weak", 0.0),
			"shielded": extra.get("shielded", false),
			"state_ticks": maxi(0, t - 50),
			"hp": 1000,
		}
		var a := _avatars[j]
		a.apply_state(s)
		if extra.get("die", false) and t == 10:
			a.die()
		a.advance(1.0 / 60.0)
	if t < SHOT_FRAMES:
		return false
	_rows.append(_grab())
	var labels := []
	for pose: Array in poses.slice(_row * 4, _row * 4 + 4):
		labels.append(pose[0])
	print("boss_models: %s row %d: %s" % [IDS[_k], _row, ", ".join(labels)])
	if _row == 0:
		_build_row(_k, 1)
		return false
	var out := Image.create(ROW.x, ROW.y * 2, false, Image.FORMAT_RGBA8)
	for r in 2:
		out.blit_rect(_rows[r], Rect2i(Vector2i.ZERO, ROW), Vector2i(0, ROW.y * r))
	var path := _dir + "poses_%s%s.png" % [IDS[_k], "" if _view == "iso" else "_" + _view]
	out.save_png(path)
	print("boss_models: ", path)
	_rows.clear()
	if _k + 1 >= IDS.size():
		return true
	_build_row(_k + 1, 0)
	return false


func _grab() -> Image:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
