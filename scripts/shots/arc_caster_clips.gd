extends SceneTree
## The Arc Caster's clip sheet for the owner: one row per clip, five frames across, each frame its own
## ArcCasterAvatar driven from a fresh start to that moment by the calls ActorViews makes (apply_state once a tick,
## advance once a frame, the flinch and the death as HitFeel and ActorViews start them), seen from the game's iso camera
## angle on a plain floor.
## Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 --resolution 1300x400 -s <this script>
## Writes build/shots/models_v0120b/arc_caster_clips.png.

const CELL := Vector2i(260, 320)
const FRAMES := 5
const DT := 1.0 / 60.0
const SPACING := 1.7
## The facing node's yaw (a three-quarter view, the front toward the camera and the screen's right).
const FACING := -0.35
const OUT := "res://build/shots/models_v0120b/arc_caster_clips.png"
## [label, clip, frame values].
const ROWS := [
	["idle: hover, robe sway, shards circling (0.4 s apart)", "idle", [0, 1, 2, 3, 4]],
	["glide at 3 m/s, stepping (0.1 s apart)", "glide", [0, 1, 2, 3, 4]],
	["gather: windup 0, 25, 50, 75, 100 %", "gather", [0.0, 0.25, 0.5, 0.75, 1.0]],
	["cast: 0.03, 0.1, 0.2, 0.4, 0.7 s", "cast", [0.03, 0.1, 0.2, 0.4, 0.7]],
	["hit: 0.03, 0.06, 0.1, 0.15, 0.25 s", "hit", [0.03, 0.06, 0.1, 0.15, 0.25]],
	["death: 5, 25, 50, 75, 100 %", "death", [0.05, 0.25, 0.5, 0.75, 1.0]],
	["rise-in: 0, 0.15, 0.3, 0.5, 0.8 s", "spawn", [0.0, 0.15, 0.3, 0.5, 0.8]],
	["reduced motion: idle, glide, gather 100 %, cast 0.1 s, death 75 %", "calm", [0, 1, 2, 3, 4]],
]

var _rows: Array[SubViewport] = []
var _frame := 0
var _tick := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	print(
		(
			"arc_caster_clips: renderer=%s model=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				EnemyModels.has_model(ArcCasterAvatar.MODEL)
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
	print("arc_caster_clips: " + png)
	return true


## One clip's row: a little world with five nodes side by side along the camera's right, each at its frame.
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
	var look := Vector3(0, 0.95, 0)
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
		var a := ArcCasterAvatar.new()
		a.setup()
		facing.add_child(a)
		a.set_process(false)  # (after it enters the tree: ready turns its _process back on)
		_tick = 0
		_drive(a, String(spec[1]), values[f], f)
		ViewPrefs.reduced_motion = false
	return vp


## `n` ticks of `state` for `a` (one apply_state and one frame each): `windup` its progress, `dx` metres a tick.
func _ticks(
	a: ArcCasterAvatar, n: int, state := WorldReader.STATE_MOVE, windup := 0.0, dx := 0.0
) -> void:
	for k in n:
		_tick += 1
		var s := {"tick": _tick, "state": state, "windup": windup, "pos": Vector2(_tick * dx, 0)}
		a.apply_state(s)
		a.advance(DT)
		a.advance_flinch(DT)


func _frames(a: ArcCasterAvatar, seconds: float) -> void:
	for k in roundi(seconds / DT):
		a.advance(DT)
		a.advance_flinch(DT)


func _cast(a: ArcCasterAvatar, seconds: float) -> void:
	_ticks(a, 40)
	for k in 30:
		_ticks(a, 1, WorldReader.STATE_WINDUP, (k + 1) / 30.0)
	_ticks(a, 1, WorldReader.STATE_ACTIVE)
	_ticks(a, maxi(0, roundi(seconds / DT) - 1), WorldReader.STATE_RECOVER)


func _drive(a: ArcCasterAvatar, clip: String, v: Variant, f: int) -> void:
	match clip:
		"idle":
			_ticks(a, 60 + int(v) * 24)
		"glide":
			_ticks(a, 60 + int(v) * 6, WorldReader.STATE_MOVE, 0.0, 3.0 / 60.0)
		"gather":
			_ticks(a, 40)
			for k in 30:
				_ticks(a, 1, WorldReader.STATE_WINDUP, float(v) * (k + 1) / 30.0)
		"cast":
			_cast(a, float(v))
		"hit":
			_ticks(a, 60)
			a.flinch(-Vector2(cos(FACING), sin(FACING)), 1.0)  # hit from the front: pushed back
			_ticks(a, roundi(float(v) / DT))
		"death":
			_ticks(a, 60)
			a.die()
			_frames(a, float(v) * ArcCasterAvatar.DEATH_SECONDS)
		"spawn":
			_tick += 1
			a.apply_state({"tick": _tick, "state": WorldReader.STATE_SPAWN})
			_frames(a, 0.2)
			_ticks(a, roundi(float(v) / DT))
		"calm":
			ViewPrefs.reduced_motion = true
			match f:
				0:
					_ticks(a, 90)
				1:
					_ticks(a, 90, WorldReader.STATE_MOVE, 0.0, 3.0 / 60.0)
				2:
					_ticks(a, 40)
					for k in 30:
						_ticks(a, 1, WorldReader.STATE_WINDUP, (k + 1) / 30.0)
				3:
					_cast(a, 0.1)
				4:
					_ticks(a, 60)
					a.die()
					_frames(a, 0.75 * ArcCasterAvatar.DEATH_SECONDS)
