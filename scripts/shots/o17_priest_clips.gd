extends SceneTree
## v0.11.0 O17d: the Cinder Priest's clip sheet for the owner: one row per clip, five frames across, each frame its own
## CinderPriestAvatar driven from a fresh start to that moment by the calls ActorViews makes (apply_state once a tick,
## advance once a frame, the flinch and the death as HitFeel and ActorViews start them), seen from the game's iso
## camera angle on a plain floor. The vent (an orange disc) stands where the cycle's rows turn the body to.
## Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 --resolution 1200x400 -s scripts/shots/o17_priest_clips.gd
## Writes build/shots/o17/cinder_priest_clips.png.

const CELL := Vector2i(230, 330)
const FRAMES := 5
const DT := 1.0 / 60.0
const SPACING := 1.3
## The facing node's yaw (a three-quarter view, the front toward the screen's right, so forward moves read) and the
## vent's direction from it (radians).
const FACING := 0.35
const VENT_YAW := 0.5
const VENT_M := 2.0
## [label, clip, frame values].
const ROWS := [
	["idle chant (0.45 s apart)", "idle", [0, 1, 2, 3, 4]],
	["glide 2.4 m/s (0.15 s apart)", "glide", [0, 1, 2, 3, 4]],
	["gather: vent warning 5, 20, 45, 70, 88 %", "gather", [0.05, 0.2, 0.45, 0.7, 0.88]],
	["slam 95 %, eruption tick, +0.08, +0.3, +0.7 s", "strike", [-1, 0, 5, 18, 42]],
	["hit flinch: 0, 0.03, 0.05, 0.1, 0.16 s", "flinch", [0.0, 0.03, 0.05, 0.1, 0.16]],
	["death: 0, 15, 35, 60, 100 %", "death", [0.0, 0.15, 0.35, 0.6, 1.0]],
	["rise-in: 0, 0.15, 0.3, 0.45, 0.65 s", "spawn", [0.0, 0.15, 0.3, 0.45, 0.65]],
	["reduced motion: idle, gather 70 %, eruption, +0.3 s, death 60 %", "calm", [0, 1, 2, 3, 4]],
]

var _rows: Array[SubViewport] = []
var _frame := 0


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://build/shots/o17/")
	DirAccess.make_dir_recursive_absolute(dir)
	print(
		(
			"o17_priest_clips: renderer=%s model=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				EnemyModels.has_model(CinderPriestAvatar.MODEL_ID)
			]
		)
	)
	for spec: Array in ROWS:
		_rows.append(_row(spec))


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 10:
		return false
	var sheet := Image.create(CELL.x * FRAMES, CELL.y * _rows.size(), false, Image.FORMAT_RGBA8)
	for r in _rows.size():
		var img := _rows[r].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, r * CELL.y))
	var png := ProjectSettings.globalize_path("res://build/shots/o17/cinder_priest_clips.png")
	sheet.save_png(png)
	print("o17_priest_clips: " + png)
	return true


## One clip's row: a little world with five priests side by side along the camera's right, each at its frame.
func _row(spec: Array) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL.x * FRAMES, CELL.y)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
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
	plane.size = Vector2(20, 20)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#6a5a4c")
	floor_mi.material_override = fm
	scene.add_child(floor_mi)
	var iso := Basis(Vector3.UP, deg_to_rad(45.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.26))
	var right := Basis(Vector3.UP, deg_to_rad(45.0)) * Vector3.RIGHT
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = SPACING * FRAMES
	scene.add_child(cam)
	var look := Vector3(0, 0.75, 0)
	cam.look_at_from_position(look + iso * Vector3.BACK * 12.0, look, Vector3.UP)
	cam.current = true
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = String(spec[0])
	label.position = Vector2(8, 4)
	label.add_theme_font_size_override(&"font_size", 18)
	vp.add_child(label)
	var values: Array = spec[2]
	for f in FRAMES:
		var actor := Node3D.new()
		actor.position = right * (f - (FRAMES - 1) * 0.5) * SPACING
		scene.add_child(actor)
		var facing := Node3D.new()
		facing.rotation.y = FACING
		actor.add_child(facing)
		var a := CinderPriestAvatar.new()
		a.setup()
		facing.add_child(a)
		a.set_process(false)  # (after it enters the tree: ready turns its _process back on)
		if String(spec[1]) in ["gather", "strike", "calm"]:
			_vent(actor)
		_drive(a, String(spec[1]), values[f], f)
		ViewPrefs.reduced_motion = false
	return vp


## The vent's place, a flat orange disc (the sheet's marker; the game draws its own).
func _vent(actor: Node3D) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 0.02
	disc.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#ff7a2e")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = m
	var yaw := FACING + VENT_YAW
	disc.position = Vector3(cos(yaw), 0.0, -sin(yaw)) * VENT_M * 0.45
	actor.add_child(disc)


## Ticks of state for `a` (one apply_state and one frame each): `pulse` permille, `age` ticks since the eruption (-1:
## none; it counts on by itself), `speed` m a tick along the facing.
func _ticks(a: CinderPriestAvatar, n: int, pulse := 0, age := -1, speed := 0.0) -> void:
	var t: int = a.get_meta(&"tick", 0)
	var x: float = a.get_meta(&"x", 0.0)
	var dir := Vector2(cos(FACING), sin(FACING))  # the facing's forward on the sim plane (3D +X turned by FACING)
	for k in n:
		t += 1
		x += speed
		var s := {
			"tick": t,
			"state": WorldReader.STATE_MOVE,
			"pos": dir * x,
			"pulse": pulse,
			"facing": FACING,
			"vent_yaw": VENT_YAW,
		}
		if age >= 0:
			s["erupt_age"] = age + k
		a.apply_state(s)
		a.advance(DT)
		a.advance_flinch(DT)
	a.set_meta(&"tick", t)
	a.set_meta(&"x", x)


## The warning's ramp from its start to `to` (0..1) over the vent's 45 warning ticks.
func _ramp(a: CinderPriestAvatar, to: float) -> void:
	for k in roundi(to * 45.0):
		_ticks(a, 1, clampi(roundi(float(k + 1) * 1000.0 / 45.0), 1, 1000))


func _frames(a: CinderPriestAvatar, seconds: float) -> void:
	for k in roundi(seconds / DT):
		a.advance(DT)
		a.advance_flinch(DT)


func _drive(a: CinderPriestAvatar, clip: String, v: Variant, f: int) -> void:
	match clip:
		"idle":
			_ticks(a, 60 + int(v) * 27)
		"glide":
			_ticks(a, 60 + int(v) * 9, 0, -1, 2.4 / 60.0)
		"gather":
			_ticks(a, 60)
			_ramp(a, float(v))
		"strike":
			_ticks(a, 60)
			if int(v) < 0:
				_ramp(a, 0.95)
			else:
				_ramp(a, 1.0)
				_ticks(a, int(v) + 1, 0, 0)
		"flinch":
			_ticks(a, 60)
			if float(v) > 0.0:
				a.flinch(-Vector2(cos(FACING), sin(FACING)), 1.0)  # hit from the front: pushed back
				_frames(a, float(v))
		"death":
			_ticks(a, 60)
			a.die()
			_frames(a, float(v) * CinderPriestAvatar.DEATH_SECONDS)
		"spawn":
			a.apply_state({"tick": 1, "state": WorldReader.STATE_SPAWN})
			a.set_meta(&"tick", 1)
			_ticks(a, roundi(float(v) / DT))
		"calm":
			ViewPrefs.reduced_motion = true
			_ticks(a, 60 + 27)
			match f:
				1:
					_ramp(a, 0.7)
				2:
					_ramp(a, 1.0)
					_ticks(a, 1, 0, 0)
				3:
					_ramp(a, 1.0)
					_ticks(a, 19, 0, 0)
				4:
					a.die()
					_frames(a, 0.6 * CinderPriestAvatar.DEATH_SECONDS)
