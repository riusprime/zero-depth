extends SceneTree
## The Mine Layer's clip sheet for the owner: one row per clip, five frames across, each frame its own HordeAvatar on
## the owner's model (MineLayerModel's clips, posed by its nodes: the same numbers the VAT crowd draws) driven from a
## fresh start to that moment by the calls ActorViews makes (apply_state once a tick, advance once a frame, the actor
## moved as the sim moves it, the flinch and the death as HitFeel and ActorViews start them), seen from the game's iso
## camera angle on a plain floor.
## Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 --resolution 1200x400 -s <this script>
## Writes build/shots/models_v0120b/mine_layer_clips.png.

const CELL := Vector2i(240, 220)
const FRAMES := 5
const DT := 1.0 / 60.0
const SPACING := 1.2
## The facing node's yaw (a three-quarter view from behind, so the hopper, its hatch and the mine read).
const FACING := 2.2
## The windup's length (ticks: the sim's drop_seconds, 0.5 s).
const WINDUP_TICKS := 30
const OUT := "res://build/shots/models_v0120b/mine_layer_clips.png"
## [label, clip, frame values].
const ROWS := [
	["idle: breath, looks (0.5 s apart)", "idle", [0, 1, 2, 3, 4]],
	["scuttle 2.4 m/s (0.025 s apart)", "trot", [0, 1, 2, 3, 4]],
	["sidestep and back off (right, left, back, 0.05 s apart)", "side", [0, 1, 2, 3, 4]],
	["windup 10, 30, 55, 80, 100 %", "tell", [0.1, 0.3, 0.55, 0.8, 1.0]],
	["drop: the tick, +0.03, +0.1, +0.17, +0.24 s", "spit", [0, 2, 6, 10, 14]],
	["hit: 0, 0.03, 0.06, 0.1, 0.15 s", "hit", [0.0, 0.03, 0.06, 0.1, 0.15]],
	["death: 0, 25, 50, 75, 100 %", "death", [0.0, 0.25, 0.5, 0.75, 1.0]],
	["rise-in: 0, 0.1, 0.2, 0.3, 0.5 s", "spawn", [0.0, 0.1, 0.2, 0.3, 0.5]],
	[
		"reduced motion: idle, scuttle, windup 80 %, drop +0.1 s, death 60 %",
		"calm",
		[0, 1, 2, 3, 4]
	],
]

var _rows: Array[SubViewport] = []
var _frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	print(
		(
			"mine_layer_clips: renderer=%s model=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				EnemyModels.has_model(MineLayerModel.MODEL)
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
	print("mine_layer_clips: " + png)
	return true


## One clip's row: a little world with five Mine Layers side by side along the camera's right, each at its frame.
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
	var look := Vector3(0, 0.2, 0)
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
		var a := HordeAvatar.new()
		a.setup(WorldReader.KIND_MINE_LAYER)
		facing.add_child(a)
		a.set_process(false)  # (after it enters the tree: ready turns its _process back on)
		_drive(a, actor, String(spec[1]), values[f], f)
		ViewPrefs.reduced_motion = false
	return vp


## Ticks of `state` for `a` (one apply_state and one frame each), its actor moved `step` (m a tick, the facing's
## frame: +X ahead, +Z its right).
func _ticks(
	a: HordeAvatar, actor: Node3D, n: int, state := WorldReader.STATE_MOVE, step := Vector3.ZERO
) -> void:
	var t: int = a.get_meta(&"tick", 0)
	actor.position -= Basis(Vector3.UP, FACING) * step * n  # (so it walks into its slot)
	for k in n:
		t += 1
		actor.position += Basis(Vector3.UP, FACING) * step
		a.apply_state({"tick": t, "state": state})
		a.advance(DT)
		a.advance_flinch(DT)
	a.set_meta(&"tick", t)


func _frames(a: HordeAvatar, seconds: float) -> void:
	for k in roundi(seconds / DT):
		a.advance(DT)
		a.advance_flinch(DT)


## The windup to `to` (0..1 of WINDUP_TICKS); with `drop`, then the drop's tick and `after` ticks of the recovery.
func _drop(a: HordeAvatar, actor: Node3D, to: float, drop := false, after := 0) -> void:
	_ticks(a, actor, roundi(to * WINDUP_TICKS), WorldReader.STATE_WINDUP)
	if drop:
		_ticks(a, actor, 1, WorldReader.STATE_ACTIVE)
		_ticks(a, actor, after, WorldReader.STATE_RECOVER)


func _drive(a: HordeAvatar, actor: Node3D, clip: String, v: Variant, f: int) -> void:
	var run := Vector3(2.4 / 60.0, 0, 0)
	match clip:
		"idle":
			_ticks(a, actor, 60 + int(v) * 30)
		"trot":
			_ticks(a, actor, 60 + int(v) * 2, WorldReader.STATE_MOVE, run)
		"side":
			var way: Vector3 = [
				Vector3(0, 0, 1),
				Vector3(0, 0, 1),
				Vector3(0, 0, -1),
				Vector3(-1, 0, 0),
				Vector3(-1, 0, 0)
			][f]
			_ticks(a, actor, 60 + (f % 2) * 3, WorldReader.STATE_MOVE, way * 2.0 / 60.0)
		"tell":
			_ticks(a, actor, 60)
			_drop(a, actor, float(v))
		"spit":
			_ticks(a, actor, 60)
			_drop(a, actor, 1.0, true, int(v))
		"hit":
			_ticks(a, actor, 60)
			a.flinch(-Vector2(cos(FACING), sin(FACING)), 1.0)
			_ticks(a, actor, roundi(float(v) / DT))
		"death":
			_ticks(a, actor, 60)
			a.die()
			_frames(a, float(v) * HordeAvatar.DEATH_SECONDS)
		"spawn":
			a.apply_state({"tick": 1, "state": WorldReader.STATE_SPAWN})
			a.set_meta(&"tick", 1)
			_ticks(a, actor, roundi(float(v) / DT))
		"calm":
			ViewPrefs.reduced_motion = true
			match f:
				0:
					_ticks(a, actor, 90)
				1:
					_ticks(a, actor, 63, WorldReader.STATE_MOVE, run)
				2:
					_ticks(a, actor, 60)
					_drop(a, actor, 0.8)
				3:
					_ticks(a, actor, 60)
					_drop(a, actor, 1.0, true, 6)
				4:
					_ticks(a, actor, 60)
					a.die()
					_frames(a, 0.6 * HordeAvatar.DEATH_SECONDS)
