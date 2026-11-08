extends SceneTree
## v0.11.0 O17b: the Rock Lurker's clip sheet for the owner: one row per clip, five frames across each, from the game
## camera's angle (iso, 35 degrees down) on a plain floor. The avatar is driven by the same calls ActorViews makes
## (apply_state each tick, advance and advance_flinch in frame time, flinch, die), at 60 frames a second; each frame
## shown is the pose at the time under it. Needs a renderer (NOT --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 -s scripts/shots/o17_rock_lurker_clips.gd
## Writes build/shots/o17/rock_lurker_clips.png. Options (after --): `--zoom` draws bigger frames (a closer look, into
## rock_lurker_clips_zoom.png); `--only=<n,n,...>` draws only those rows (0-based).

const OUT := "res://build/shots/o17/rock_lurker_clips.png"
const OUT_ZOOM := "res://build/shots/o17/rock_lurker_clips_zoom.png"
const DT := 1.0 / 60.0
const SPEED := 2.2
const MOVE := WorldReader.STATE_MOVE
const WINDUP := WorldReader.STATE_WINDUP
const ACTIVE := WorldReader.STATE_ACTIVE
const RECOVER := WorldReader.STATE_RECOVER
const SPAWN := WorldReader.STATE_SPAWN

var _cell := Vector2i(230, 200)
var _cam_size := 2.0
var _only: Array = []
var _out := OUT
var _row := -1
var _vp: SubViewport
var _facing: Node3D
var _a: RockLurkerAvatar
var _tick := 0
var _x := 0.0
var _rows: Array = []  # [label, [[Image, caption], ...]]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--zoom":
			_cell = Vector2i(420, 380)
			_cam_size = 1.7
			_out = OUT_ZOOM
		elif arg.begins_with("--only="):
			for n in arg.trim_prefix("--only=").split(","):
				_only.append(int(n))
	_build_world()
	_run.call_deferred()


func _build_world() -> void:
	_vp = SubViewport.new()
	_vp.size = _cell
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#1b1d24")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#9aa3b5")
	env.environment.ambient_light_energy = 0.55
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	_vp.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#4d4a45")
	floor_mi.material_override = fm
	_vp.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = _cam_size
	var look := Vector3(0.1, 0.45, 0)
	var dir := (
		Basis(Vector3.UP, deg_to_rad(45.0))
		* Basis(Vector3.RIGHT, deg_to_rad(-35.26))
		* Vector3.BACK
	)
	_vp.add_child(cam)
	cam.look_at_from_position(look + dir * 10.0, look, Vector3.UP)
	cam.current = true
	var actor := Node3D.new()
	_vp.add_child(actor)
	_facing = Node3D.new()
	_facing.rotation.y = 0.75
	actor.add_child(_facing)


## Whether the next row is drawn (--only).
func _want() -> bool:
	_row += 1
	return _only.is_empty() or _row in _only


func _fresh(hidden: bool, state := MOVE) -> void:
	if _a != null:
		_a.free()
	_a = RockLurkerAvatar.new()
	_a.setup(Color("#1A1A22"))
	_a.set_process(false)
	_facing.add_child(_a)
	_tick = 0
	_x = 0.0
	_step({"state": state, "hidden": hidden})


## One sim tick in state `s` (state, hidden, rumbling, windup) and one frame of frame time.
func _step(s: Dictionary, moving := false) -> void:
	_tick += 1
	if moving:
		_x += SPEED * DT
	var d := s.duplicate()
	d["tick"] = _tick
	d["pos"] = Vector2(_x, 0)
	_a.apply_state(d)
	_frame()


func _frame() -> void:
	_a.advance(DT)
	_a.advance_flinch(DT)


func _snap(caption: String) -> Array:
	await process_frame
	await process_frame
	await process_frame
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return [img, caption]


## Runs `ticks` ticks of state `s`, snapping at the ticks listed (a tick count from the start of this run).
func _play(
	s: Dictionary, ticks: int, at: Array, out: Array, label_of: Callable, moving := false
) -> void:
	for k in range(1, ticks + 1):
		_step(s, moving)
		if k in at:
			out.append(await _snap(label_of.call(k)))


static func _sec(k: int) -> String:
	return "%.2f s" % (k * DT)


func _run() -> void:
	ViewPrefs.reduced_motion = false
	await _clip_disguised()
	await _clip_rumble("rumble (the hero within 4 m)", false)
	await _clip_burst_walk()
	await _clip_burst_slam()
	await _clip_windup("slam windup (out): rears on its hind legs, the beat", false)
	await _clip_strike("slam: the smash, the shell's follow-through, the recovery", false)
	await _clip_walk()
	await _clip_idle()
	await _clip_flinch()
	await _clip_death()
	ViewPrefs.reduced_motion = true
	await _clip_rumble("reduced motion: rumble (no shudder)", true)
	await _clip_windup("reduced motion: slam windup (no tremble)", true)
	await _clip_strike("reduced motion: smash (no wobble)", true)
	ViewPrefs.reduced_motion = false
	_compose()


func _clip_disguised() -> void:
	if not _want():
		return
	_fresh(true, SPAWN)
	var out: Array = []
	for k in 40:
		_step({"state": SPAWN, "hidden": true})
	await _play({"state": MOVE, "hidden": true}, 240, [1, 60, 120, 180, 240], out, _sec)
	_rows.append(["arrival (the rock rises from the ground), then disguised: a still boulder", out])


func _clip_rumble(label: String, _calm: bool) -> void:
	if not _want():
		return
	_fresh(true)
	var out: Array = []
	await _play(
		{"state": MOVE, "hidden": true, "rumbling": true}, 40, [6, 14, 22, 30, 40], out, _sec
	)
	_rows.append([label, out])


func _clip_burst_walk() -> void:
	if not _want():
		return
	_fresh(true)
	var out: Array = []
	for k in 30:
		_step({"state": MOVE, "hidden": true, "rumbling": true})
	await _play({"state": MOVE, "hidden": false}, 34, [3, 9, 15, 22, 34], out, _sec)
	_rows.append(["burst (woken by a hit): the beat, the heave, claws out, the landing", out])


func _clip_burst_slam() -> void:
	if not _want():
		return
	_fresh(true)
	var out: Array = []
	for k in 30:
		_step({"state": MOVE, "hidden": true, "rumbling": true})
	for k in range(1, 31):
		_step({"state": WINDUP, "hidden": false, "windup": float(k) / 30.0})
		if k in [4, 10, 17, 24, 30]:
			out.append(await _snap("windup %d %%" % roundi(k * 100.0 / 30.0)))
	_rows.append(["burst into the slam (the hero within 2 m): out and rearing in 0.5 s", out])


func _clip_windup(label: String, _calm: bool) -> void:
	if not _want():
		return
	_fresh(false)
	for k in 30:
		_step({"state": MOVE})
	var out: Array = []
	for k in range(1, 31):
		_step({"state": WINDUP, "windup": float(k) / 30.0})
		if k in [3, 8, 15, 23, 30]:
			out.append(await _snap("windup %d %%" % roundi(k * 100.0 / 30.0)))
	_rows.append([label, out])


func _clip_strike(label: String, _calm: bool) -> void:
	if not _want():
		return
	_fresh(false)
	for k in 30:
		_step({"state": MOVE})
	for k in range(1, 31):
		_step({"state": WINDUP, "windup": float(k) / 30.0})
	var out: Array = []
	_step({"state": ACTIVE})
	out.append(await _snap("hit tick +1"))
	var k := 1
	for n in 48:
		k += 1
		_step({"state": RECOVER})
		if k in [4, 9, 24, 46]:
			out.append(await _snap("hit +%.2f s" % (k * DT)))
	_rows.append([label, out])


func _clip_walk() -> void:
	if not _want():
		return
	_fresh(false)
	for k in 90:
		_step({"state": MOVE}, true)
	var out: Array = []
	await _play({"state": MOVE}, 30, [1, 7, 13, 19, 25], out, _sec, true)
	_rows.append(["knuckle walk 2.2 m/s (one cycle: 0.5 s)", out])


func _clip_idle() -> void:
	if not _want():
		return
	_fresh(false)
	for k in 30:
		_step({"state": MOVE})
	var out: Array = []
	await _play({"state": MOVE}, 150, [1, 36, 72, 108, 144], out, _sec)
	_rows.append(["idle awake: heavy breathing, the head scanning", out])


func _clip_flinch() -> void:
	if not _want():
		return
	_fresh(false)
	for k in 30:
		_step({"state": MOVE})
	var out: Array = []
	_a.flinch(Vector2(-1.0, 0.3), 1.0)
	out.append(await _snap("hit"))
	await _play({"state": MOVE}, 14, [2, 4, 8, 14], out, _sec)
	_rows.append(["hit flinch: the lean, the face recoiling, the arms flaring", out])


func _clip_death() -> void:
	if not _want():
		return
	_fresh(false)
	for k in 30:
		_step({"state": MOVE})
	var out: Array = []
	_a.die()
	for k in range(1, 67):
		_frame()
		if k in [1, 15, 28, 40, 66]:
			out.append(await _snap("death +%.2f s" % (k * DT)))
	_rows.append(["death: collapses back into a rock, the glow fading", out])


func _compose() -> void:
	var sheet := SubViewport.new()
	var cols := 5
	var row_h := _cell.y + 44
	sheet.size = Vector2i(_cell.x * cols + 12, row_h * _rows.size() + 8)
	sheet.transparent_bg = false
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var bg := ColorRect.new()
	bg.color = Color("#101116")
	bg.size = Vector2(sheet.size)
	sheet.add_child(bg)
	var y := 4
	for r: Array in _rows:
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = r[0]
		label.position = Vector2(8, y)
		label.add_theme_font_size_override(&"font_size", 15)
		sheet.add_child(label)
		var x := 6
		for cell: Array in r[1]:
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(cell[0])
			tr.position = Vector2(x, y + 20)
			sheet.add_child(tr)
			var cap := Label.new()
			cap.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			cap.text = cell[1]
			cap.position = Vector2(x + 4, y + 22)
			cap.add_theme_font_size_override(&"font_size", 12)
			cap.modulate = Color(1, 1, 1, 0.8)
			sheet.add_child(cap)
			x += _cell.x
		y += row_h
	for k in 4:
		await process_frame
	var img := sheet.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots/o17/"))
	img.save_png(ProjectSettings.globalize_path(_out))
	print("o17 clips: wrote %s (%d rows)" % [_out, _rows.size()])
	quit(0)
