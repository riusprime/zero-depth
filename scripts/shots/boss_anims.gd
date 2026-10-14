extends SceneTree
## v0.8.0 BA: a contact sheet per boss of its animation clips' key poses, from the game's iso camera next to the
## hero. Needs a renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1600x840 -s scripts/shots/boss_anims.gd [-- boss=<id>]
## Writes build/shots/v0.8.0/ba/<boss>.png (two rows of four) and prints each path and its poses. Each boss is driven
## through BossAvatar.apply_state (the same inputs sync() reads from the sim), with an attack's timing given, so the
## poses are the clips' own: idle; its attack's anticipation (late in the windup), its strike (the first active
## tick) and its recovery; its shielded pattern; staggered; the phase gate's roar; and its collapse.
## One boss per run keeps the memory low on a shared machine (boss=<id>); without it, all six in turn.

const IDS: Array[StringName] = [
	&"gatekeeper", &"warlord", &"brood_mother", &"hive_lens", &"siege_engine", &"foundry"
]
## The attack each sheet shows wound up, striking and recovering (a move its data uses).
const ATTACK := {
	&"gatekeeper": WorldReader.MOVE_MARKS,
	&"warlord": WorldReader.MOVE_FLOOD,
	&"brood_mother": WorldReader.MOVE_MARKS,
	&"hive_lens": WorldReader.MOVE_LEAP,
	&"siege_engine": WorldReader.MOVE_SLAM_RING,
	&"foundry": WorldReader.MOVE_ROW_FLOOD,
}
const LABELS := [
	"idle",
	"windup (anticipation)",
	"strike (first active tick)",
	"recovery",
	"shielded pattern",
	"staggered",
	"phase gate roar",
	"death (collapse)",
]
const ROW := Vector2i(1600, 420)
const FRAMES := 70
## The attack's timing given to apply_state: windup, active, recover ticks.
const TICKS := Vector4i(100, 10, 60, 0)

var _classes := {
	&"gatekeeper": GatekeeperAvatar,
	&"warlord": WarlordAvatar,
	&"brood_mother": BroodMotherAvatar,
	&"hive_lens": HiveLensAvatar,
	&"siege_engine": SiegeEngineAvatar,
	&"foundry": FoundryAvatar,
}
var _ids: Array[StringName] = []
var _dir := ""
var _frame := 0
var _k := 0
var _row := 0
var _vp: SubViewport
var _avatars: Array[BossAvatar] = []
var _rows: Array[Image] = []


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var one := StringName(args.get("boss", ""))
	_ids.assign([one] if one != &"" else IDS)
	_dir = "res://build/shots/v0.8.0/ba/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	print("boss_anims: renderer=%s" % RenderingServer.get_current_rendering_method())
	_vp = SubViewport.new()
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = ROW
	root.add_child(_vp)
	BossModels.preload_all()
	_build_row(0, 0)


func _process(_delta: float) -> bool:
	_frame += 1
	return _step()


func _scene() -> Node3D:
	for c in _vp.get_children():
		c.queue_free()
	var scene := Node3D.new()
	_vp.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#C8A57A")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#C9CEDA")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	scene.add_child(light)
	var g := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	g.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#C8A57A")
	gm.roughness = 1.0
	g.material_override = gm
	scene.add_child(g)
	return scene


func _build_row(k: int, row: int) -> void:
	var scene := _scene()
	_avatars.clear()
	var rig := IsoRig.new()
	rig.set_process(false)
	scene.add_child(rig)
	rig.view_size = 9.0
	rig.camera.size = 9.0
	var right := Vector3(cos(PI / 4), 0, -sin(PI / 4))
	for j in 4:
		var a: BossAvatar = _classes[_ids[k]].new()
		a.setup(Color("#1A1A22"))
		a.position = right * (float(j) - 1.5) * 5.6
		a.rotation = Vector3(0, -PI * 0.25 + 0.45, 0)
		if row == 1 and j == 3:
			a.rotation.y += PI * 0.75  # the collapse falls away up the sheet, inside its cell
		scene.add_child(a)
		a.set_process(false)  # after entering the tree (ready would turn it back on): only _step advances it
		_avatars.append(a)
	var hero := PlayerAvatar.new()
	hero.setup(Color("#1A1A22"))
	hero.position = right * -11.0 + Vector3(1.2, 0, 1.2)
	scene.add_child(hero)
	rig.snap_to(Vector3(0, 1.0, 0) + right * -0.6)
	rig.camera.current = true
	_k = k
	_row = row
	_frame = 0


## Pose j's apply_state at frame f (the death, pose 7, starts at frame 16).
func _pose_state(j: int, f: int) -> Dictionary:
	var move: int = ATTACK[_ids[_k]]
	var s := {"tick": f + 1, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE, "hp": 1000}
	s["attack_ticks"] = TICKS
	match j:
		1:  # late in the windup: t = 0.46
			s.merge({"state": WorldReader.STATE_WINDUP, "move": move, "state_ticks": 22 + f}, true)
		2:  # the first active tick
			if f < FRAMES - 1:
				s.merge(
					{"state": WorldReader.STATE_WINDUP, "move": move, "state_ticks": 30 + f}, true
				)
			else:
				s.merge({"state": WorldReader.STATE_ACTIVE, "move": move, "state_ticks": 0}, true)
		3:  # a quarter into the recovery
			if f < 40:
				s.merge(
					{"state": WorldReader.STATE_WINDUP, "move": move, "state_ticks": 60 + f}, true
				)
			elif f < 50:
				s.merge(
					{"state": WorldReader.STATE_ACTIVE, "move": move, "state_ticks": f - 40}, true
				)
			else:
				s.merge(
					{"state": WorldReader.STATE_RECOVER, "move": move, "state_ticks": f - 50}, true
				)
		4:  # its shielded pattern, just after the strike
			s["state"] = WorldReader.STATE_WINDUP if f < 60 else WorldReader.STATE_ACTIVE
			s["move"] = WorldReader.MOVE_PATTERN
			s["state_ticks"] = 40 + f if f < 60 else f - 60
			s["shielded"] = true
		5:
			s["state"] = WorldReader.STATE_STAGGERED
		6:  # the roar, held
			s.merge({"state": WorldReader.STATE_GATE, "gate": 0.6 * float(f) / float(FRAMES)}, true)
	return s


func _step() -> bool:
	if _avatars.size() < 4:
		push_error("boss_anims: no avatars to pose")
		return true
	for j in 4:
		var pose := _row * 4 + j
		var a := _avatars[j]
		a.apply_state(_pose_state(pose, _frame))
		if pose == 7 and _frame == 16:
			a.die()
		a.advance(1.0 / 60.0)
	if _frame < FRAMES:
		return false
	_rows.append(_grab())
	print(
		(
			"boss_anims: %s row %d: %s"
			% [_ids[_k], _row, ", ".join(LABELS.slice(_row * 4, _row * 4 + 4))]
		)
	)
	if _row == 0:
		_build_row(_k, 1)
		return false
	var out := Image.create(ROW.x, ROW.y * 2, false, Image.FORMAT_RGBA8)
	for r in 2:
		out.blit_rect(_rows[r], Rect2i(Vector2i.ZERO, ROW), Vector2i(0, ROW.y * r))
	var path := _dir + "%s.png" % _ids[_k]
	out.save_png(path)
	print("boss_anims: ", path)
	_rows.clear()
	if _k + 1 >= _ids.size():
		return true
	_build_row(_k + 1, 0)
	return false


func _grab() -> Image:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
