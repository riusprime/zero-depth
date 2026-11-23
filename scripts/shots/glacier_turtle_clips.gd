extends SceneTree
## The Glacier Turtle's clip sheet for the owner: one row per clip, five frames across, each frame its own
## GlacierTurtleAvatar driven from a fresh start to that moment by the calls ActorViews makes (apply_state once a tick,
## advance once a frame, the flinch and the death as HitFeel and ActorViews start them), seen from the game's iso
## camera angle on a plain floor.
## Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 --resolution 1350x400 -s <this script>
## Writes build/shots/glacier_turtle/glacier_turtle_clips.png.

const CELL := Vector2i(270, 250)
const FRAMES := 5
const DT := 1.0 / 60.0
const SPACING := 1.9
## The facing node's yaw (a three-quarter side view, the front toward the screen's right, so the shield held in front,
## the legs and the body's moves read).
const FACING := 0.4
## The windup's length (ticks: within the sim's telegraph, 0.55 to 0.8 s).
const WINDUP_TICKS := 40
const OUT := "res://build/shots/glacier_turtle/glacier_turtle_clips.png"
## [label, clip, frame values].
const ROWS := [
	["idle: breath, looks, the shield's weight (0.6 s apart)", "idle", [0, 1, 2, 3, 4]],
	["walk 1.1 m/s (0.08 s apart)", "walk", [0, 1, 2, 3, 4]],
	["turning to face you, 45 deg/s (0.12 s apart)", "turn", [0, 1, 2, 3, 4]],
	["brace, a hit on the shield: 0, 0.05, 0.1, 0.2, 0.3 s", "brace", [0.0, 0.05, 0.1, 0.2, 0.3]],
	["tell: windup 10, 30, 55, 80, 95 %", "tell", [0.1, 0.3, 0.55, 0.8, 0.95]],
	["slam: windup 100 %, slam, +0.1, +0.3, +0.7 s", "slam", [-1, 0, 6, 18, 42]],
	["break: before, 0.03, 0.15, 0.35, 0.7 s", "break", [-1.0, 0.03, 0.15, 0.35, 0.7]],
	["bare: idle, idle +0.4 s, walk, walk +0.1 s, windup 80 %", "bare", [0, 1, 2, 3, 4]],
	["hit: 0, 0.05, 0.1, 0.18, 0.3 s", "hit", [0.0, 0.05, 0.1, 0.18, 0.3]],
	["death: 0, 20, 40, 60, 100 %", "death", [0.0, 0.2, 0.4, 0.6, 1.0]],
	["rise-in: 0, 0.15, 0.3, 0.5, 0.8 s", "spawn", [0.0, 0.15, 0.3, 0.5, 0.8]],
	["reduced motion: idle, walk, windup 80 %, brace +0.1 s, death 60 %", "calm", [0, 1, 2, 3, 4]],
]

var _rows: Array[SubViewport] = []
var _frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	print(
		(
			"glacier_turtle_clips: renderer=%s model=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				EnemyModels.has_model(GlacierTurtleAvatar.MODEL)
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
	print("glacier_turtle_clips: " + png)
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
		var a := GlacierTurtleAvatar.new()
		a.setup()
		facing.add_child(a)
		a.set_process(false)  # (after it enters the tree: ready turns its _process back on)
		_drive(a, String(spec[1]), values[f], f)
		ViewPrefs.reduced_motion = false
	return vp


## Ticks of `state` for `a` (one apply_state and one frame each): `windup` its progress, `speed` m a tick along the
## facing, `turn` radians a tick of the facing, `hp` its HP, `shell` its shield's.
func _ticks(
	a: GlacierTurtleAvatar,
	n: int,
	state := WorldReader.STATE_MOVE,
	windup := 0.0,
	speed := 0.0,
	turn := 0.0,
	hp := 80,
	shell := 60
) -> void:
	var t: int = a.get_meta(&"tick", 0)
	var x: float = a.get_meta(&"x", 0.0)
	var dir := Vector2(cos(FACING), sin(FACING))  # the facing's forward on the sim plane (3D +X turned by FACING)
	for k in n:
		t += 1
		x += speed
		(a.get_parent() as Node3D).rotation.y += turn
		a.apply_state(
			{"tick": t, "state": state, "pos": dir * x, "windup": windup, "hp": hp, "shell": shell}
		)
		a.advance(DT)
		a.advance_flinch(DT)
	a.set_meta(&"tick", t)
	a.set_meta(&"x", x)


## The windup from its start to `to` (0..1) over WINDUP_TICKS.
func _ramp(a: GlacierTurtleAvatar, to: float, shell := 60) -> void:
	for k in roundi(to * WINDUP_TICKS):
		_ticks(a, 1, WorldReader.STATE_WINDUP, float(k + 1) / WINDUP_TICKS, 0.0, 0.0, 80, shell)


## The windup in full, the slam's tick, then `after` ticks of the recovery.
func _slam(a: GlacierTurtleAvatar, after: int) -> void:
	_ramp(a, 1.0)
	_ticks(a, 1, WorldReader.STATE_ACTIVE)
	_ticks(a, after, WorldReader.STATE_RECOVER)


func _frames(a: GlacierTurtleAvatar, seconds: float) -> void:
	for k in roundi(seconds / DT):
		a.advance(DT)
		a.advance_flinch(DT)


func _drive(a: GlacierTurtleAvatar, clip: String, v: Variant, f: int) -> void:
	var walk := 1.1 / 60.0
	var move := WorldReader.STATE_MOVE
	match clip:
		"idle":
			_ticks(a, 60 + int(v) * 36)
		"walk":
			_ticks(a, 90 + int(v) * 5, move, 0.0, walk)
		"turn":
			_ticks(a, 30)
			_ticks(a, 40 + int(v) * 7, move, 0.0, 0.0, 0.785 / 60.0)
		"brace":
			_ticks(a, 60)
			_ticks(a, 1 + roundi(float(v) / DT), move, 0.0, 0.0, 0.0, 80, 45)
		"tell":
			_ticks(a, 60)
			_ramp(a, float(v))
		"slam":
			_ticks(a, 60)
			if int(v) < 0:
				_ramp(a, 1.0)
			else:
				_slam(a, int(v))
		"break":
			_ticks(a, 60)
			if float(v) >= 0.0:
				_ticks(a, 1 + roundi(float(v) / DT), move, 0.0, 0.0, 0.0, 80, 0)
		"bare":
			_ticks(a, 60, move, 0.0, 0.0, 0.0, 80, 0)
			match f:
				0:
					_ticks(a, 60, move, 0.0, 0.0, 0.0, 80, 0)
				1:
					_ticks(a, 84, move, 0.0, 0.0, 0.0, 80, 0)
				2:
					_ticks(a, 60, move, 0.0, walk, 0.0, 80, 0)
				3:
					_ticks(a, 66, move, 0.0, walk, 0.0, 80, 0)
				4:
					_ticks(a, 60, move, 0.0, 0.0, 0.0, 80, 0)
					_ramp(a, 0.8, 0)
		"hit":
			_ticks(a, 60)
			_ticks(a, 1, move, 0.0, 0.0, 0.0, 60)
			a.flinch(-Vector2(cos(FACING), sin(FACING)), 1.0)  # pushed back
			_ticks(a, roundi(float(v) / DT), move, 0.0, 0.0, 0.0, 60)
		"death":
			_ticks(a, 60)
			a.die()
			_frames(a, float(v) * GlacierTurtleAvatar.DEATH_SECONDS)
		"spawn":
			a.apply_state({"tick": 1, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO})
			a.set_meta(&"tick", 1)
			_ticks(a, roundi(float(v) / DT))
		"calm":
			ViewPrefs.reduced_motion = true
			match f:
				0:
					_ticks(a, 96)
				1:
					_ticks(a, 96, move, 0.0, walk)
				2:
					_ticks(a, 60)
					_ramp(a, 0.8)
				3:
					_ticks(a, 60)
					_ticks(a, 7, move, 0.0, 0.0, 0.0, 80, 45)
				4:
					_ticks(a, 60)
					a.die()
					_frames(a, 0.6 * GlacierTurtleAvatar.DEATH_SECONDS)
