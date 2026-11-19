extends SceneTree
## The Frost Spitter's clip sheet for the owner: one row per clip, five frames across, each frame its own
## FrostSpitterAvatar driven from a fresh start to that moment by the calls ActorViews makes (apply_state once a tick,
## advance once a frame, the flinch and the death as HitFeel and ActorViews start them), seen from the game's iso
## camera angle on a plain floor.
## Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 --resolution 1200x400 -s <this script>
## Writes build/shots/frost_spitter/frost_spitter_clips.png.

const CELL := Vector2i(240, 250)
const FRAMES := 5
const DT := 1.0 / 60.0
const SPACING := 1.45
## The facing node's yaw (a three-quarter view, the face toward the camera and the screen's right, so the sac and
## forward moves read).
const FACING := -0.35
## The windup's length (ticks: within the sim's telegraph, 0.6 to 0.8 s).
const WINDUP_TICKS := 40
const OUT := "res://build/shots/frost_spitter/frost_spitter_clips.png"
## [label, clip, frame values].
const ROWS := [
	["idle: breath and glances (0.45 s apart)", "idle", [0, 1, 2, 3, 4]],
	["trot 2.6 m/s (0.05 s apart)", "trot", [0, 1, 2, 3, 4]],
	["turning in place (0.07 s apart)", "turn", [0, 1, 2, 3, 4]],
	["tell: windup 10, 30, 55, 80, 95 %", "tell", [0.1, 0.3, 0.55, 0.8, 0.95]],
	["spit: windup 100 %, throw, +0.1, +0.3, +0.6 s", "spit", [-1, 0, 6, 18, 36]],
	["hit: 0, 0.05, 0.1, 0.18, 0.3 s", "hit", [0.0, 0.05, 0.1, 0.18, 0.3]],
	["death: 0, 15, 35, 60, 100 %", "death", [0.0, 0.15, 0.35, 0.6, 1.0]],
	["rise-in: 0, 0.15, 0.3, 0.45, 0.7 s", "spawn", [0.0, 0.15, 0.3, 0.45, 0.7]],
	["reduced motion: idle, trot, windup 80 %, spit +0.1 s, death 60 %", "calm", [0, 1, 2, 3, 4]],
]

var _rows: Array[SubViewport] = []
var _frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	print(
		(
			"frost_spitter_clips: renderer=%s model=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				EnemyModels.has_model(FrostSpitterAvatar.MODEL)
			]
		)
	)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:  # (built in the running tree: each avatar's ready has run when its processing is turned off)
		for spec: Array in ROWS:
			_rows.append(_row(spec))
	if _frame < 10:
		return false
	var sheet := Image.create(CELL.x * FRAMES, CELL.y * _rows.size(), false, Image.FORMAT_RGBA8)
	for r in _rows.size():
		var img := _rows[r].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, r * CELL.y))
	var png := ProjectSettings.globalize_path(OUT)
	sheet.save_png(png)
	print("frost_spitter_clips: " + png)
	return true


## One clip's row: a little world with five spitters side by side along the camera's right, each at its frame.
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
	fm.albedo_color = Color("#8c9aa6")
	floor_mi.material_override = fm
	scene.add_child(floor_mi)
	var iso := Basis(Vector3.UP, deg_to_rad(45.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.26))
	var right := Basis(Vector3.UP, deg_to_rad(45.0)) * Vector3.RIGHT
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = SPACING * FRAMES
	scene.add_child(cam)
	var look := Vector3(0, 0.45, 0)
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
		var a := FrostSpitterAvatar.new()
		a.setup()
		facing.add_child(a)
		a.set_process(false)  # (after it enters the tree: ready turns its _process back on)
		_drive(a, String(spec[1]), values[f], f)
		ViewPrefs.reduced_motion = false
	return vp


## Ticks of `state` for `a` (one apply_state and one frame each): `windup` its progress, `speed` m a tick along the
## facing, `turn` radians a tick of the facing, `hp` its HP.
func _ticks(
	a: FrostSpitterAvatar,
	n: int,
	state := WorldReader.STATE_MOVE,
	windup := 0.0,
	speed := 0.0,
	turn := 0.0,
	hp := 40
) -> void:
	var t: int = a.get_meta(&"tick", 0)
	var x: float = a.get_meta(&"x", 0.0)
	var dir := Vector2(cos(FACING), sin(FACING))  # the facing's forward on the sim plane (3D +X turned by FACING)
	for k in n:
		t += 1
		x += speed
		(a.get_parent() as Node3D).rotation.y += turn
		a.apply_state({"tick": t, "state": state, "pos": dir * x, "windup": windup, "hp": hp})
		a.advance(DT)
		a.advance_flinch(DT)
	a.set_meta(&"tick", t)
	a.set_meta(&"x", x)


## The windup from its start to `to` (0..1) over WINDUP_TICKS.
func _ramp(a: FrostSpitterAvatar, to: float) -> void:
	for k in roundi(to * WINDUP_TICKS):
		_ticks(a, 1, WorldReader.STATE_WINDUP, float(k + 1) / WINDUP_TICKS)


## The windup in full, the throw's tick, then `after` ticks of the recovery.
func _spit(a: FrostSpitterAvatar, after: int) -> void:
	_ramp(a, 1.0)
	_ticks(a, 1, WorldReader.STATE_ACTIVE)
	_ticks(a, after, WorldReader.STATE_RECOVER)


func _frames(a: FrostSpitterAvatar, seconds: float) -> void:
	for k in roundi(seconds / DT):
		a.advance(DT)
		a.advance_flinch(DT)


func _drive(a: FrostSpitterAvatar, clip: String, v: Variant, f: int) -> void:
	match clip:
		"idle":
			_ticks(a, 60 + int(v) * 27)
		"trot":
			_ticks(a, 60 + int(v) * 3, WorldReader.STATE_MOVE, 0.0, 2.6 / 60.0)
		"turn":
			_ticks(a, 30)
			_ticks(a, 30 + int(v) * 4, WorldReader.STATE_MOVE, 0.0, 0.0, 2.5 / 60.0)
		"tell":
			_ticks(a, 60)
			_ramp(a, float(v))
		"spit":
			_ticks(a, 60)
			if int(v) < 0:
				_ramp(a, 1.0)
			else:
				_spit(a, int(v))
		"hit":
			_ticks(a, 60)
			_ticks(a, 1, WorldReader.STATE_MOVE, 0.0, 0.0, 0.0, 30)
			a.flinch(-Vector2(cos(FACING), sin(FACING)), 1.0)  # hit from the front: pushed back
			_ticks(a, roundi(float(v) / DT), WorldReader.STATE_MOVE, 0.0, 0.0, 0.0, 30)
		"death":
			_ticks(a, 60)
			a.die()
			_frames(a, float(v) * FrostSpitterAvatar.DEATH_SECONDS)
		"spawn":
			a.apply_state({"tick": 1, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO})
			a.set_meta(&"tick", 1)
			_ticks(a, roundi(float(v) / DT))
		"calm":
			ViewPrefs.reduced_motion = true
			match f:
				0:
					_ticks(a, 87)
				1:
					_ticks(a, 66, WorldReader.STATE_MOVE, 0.0, 2.6 / 60.0)
				2:
					_ticks(a, 60)
					_ramp(a, 0.8)
				3:
					_ticks(a, 60)
					_spit(a, 6)
				4:
					_ticks(a, 60)
					a.die()
					_frames(a, 0.6 * FrostSpitterAvatar.DEATH_SECONDS)
