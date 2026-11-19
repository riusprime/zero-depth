extends SceneTree
## The Wire Weaver's clip sheet for the owner: one row per clip, five frames across, each frame its own
## WireWeaverAvatar driven from a fresh start to that moment by the calls ActorViews makes (apply_state once a tick,
## advance once a frame, the flinch and the death as HitFeel and ActorViews start them), seen from the game's iso
## camera angle on a plain floor. (The posts it plants are drawn by RuinsRocksAvatar at the cable's ends, not here.)
## Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 --resolution 1200x400 -s scripts/shots/wire_weaver_clips.gd
## Writes build/shots/o17/wire_weaver_clips.png.

const CELL := Vector2i(230, 330)
const FRAMES := 5
const DT := 1.0 / 60.0
const SPACING := 1.3
## The facing node's yaw (a three-quarter view, the front toward the screen's right, so forward moves read).
const FACING := 0.35
const TELL_TICKS := 42
## [label, clip, frame values].
const ROWS := [
	["idle (0.45 s apart)", "idle", [0, 1, 2, 3, 4]],
	["walk 2.6 m/s (0.07 s apart)", "walk", [0, 1, 2, 3, 4]],
	["backing off 2.6 m/s (0.07 s apart)", "back", [0, 1, 2, 3, 4]],
	["tell: 5, 25, 50, 75, 95 %", "tell", [0.05, 0.25, 0.5, 0.75, 0.95]],
	["plant: tell 100 %, +0.03, +0.1, +0.25, +0.45 s", "plant", [-1.0, 0.03, 0.1, 0.25, 0.45]],
	[
		"empty-handed, then the reload: +0.6, +0.85, +1.0, +1.15, +1.4 s",
		"plant",
		[0.6, 0.85, 1.0, 1.15, 1.4]
	],
	["hit flinch: 0, 0.03, 0.06, 0.1, 0.2 s", "hurt", [0.0, 0.03, 0.06, 0.1, 0.2]],
	["death: 0, 15, 35, 60, 100 %", "death", [0.0, 0.15, 0.35, 0.6, 1.0]],
	["rise-in: arriving, then 0.1, 0.2, 0.3, 0.5 s up", "spawn", [0.0, 0.1, 0.2, 0.3, 0.5]],
	[
		"reduced motion: walk, tell 70 %, plant +0.1 s, reload +1.0 s, death 60 %",
		"calm",
		[0, 1, 2, 3, 4]
	],
]

var _rows: Array[SubViewport] = []
var _frame := 0


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://build/shots/o17/")
	DirAccess.make_dir_recursive_absolute(dir)
	print(
		(
			"wire_weaver_clips: renderer=%s model=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				EnemyModels.has_model(WireWeaverAvatar.MODEL)
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
	var png := ProjectSettings.globalize_path("res://build/shots/o17/wire_weaver_clips.png")
	sheet.save_png(png)
	print("wire_weaver_clips: " + png)
	return true


## One clip's row: a little world with five Weavers side by side along the camera's right, each at its frame.
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
	var look := Vector3(0, 0.5, 0)
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
		var a := WireWeaverAvatar.new()
		a.setup()
		facing.add_child(a)
		a.set_process(false)  # (after it enters the tree: ready turns its _process back on)
		_drive(a, String(spec[1]), values[f], f)
		ViewPrefs.reduced_motion = false
	return vp


## Ticks of `state` for `a` (one apply_state and one frame each), `hp` its HP, moving `speed` m a tick along the
## facing (back with a minus); through a windup its progress climbs a TELL_TICKS share a tick.
func _ticks(
	a: WireWeaverAvatar, n: int, state := WorldReader.STATE_MOVE, speed := 0.0, hp := 40
) -> void:
	var t: int = a.get_meta(&"tick", 0)
	var x: float = a.get_meta(&"x", 0.0)
	var dir := Vector2(cos(FACING), sin(FACING))  # the facing's forward on the sim plane (3D +X turned by FACING)
	for k in n:
		t += 1
		x += speed
		var s := {"tick": t, "state": state, "pos": dir * x, "hp": hp, "windup": 0.0}
		if state == WorldReader.STATE_WINDUP:
			var w: int = a.get_meta(&"wind", 0) + 1
			a.set_meta(&"wind", w)
			s["windup"] = float(w) / float(TELL_TICKS)
		a.apply_state(s)
		a.advance(DT)
		a.advance_flinch(DT)
	a.set_meta(&"tick", t)
	a.set_meta(&"x", x)


func _frames(a: WireWeaverAvatar, seconds: float) -> void:
	for k in roundi(seconds / DT):
		a.advance(DT)
		a.advance_flinch(DT)


## The tell to `to` (0..1), then (`after` >= 0) the plant tick and `after` s of the recovery and the walk after it.
func _tell(a: WireWeaverAvatar, to: float, after := -1.0) -> void:
	_ticks(a, roundi(to * TELL_TICKS), WorldReader.STATE_WINDUP)
	if after < 0.0:
		return
	_ticks(a, 1, WorldReader.STATE_ACTIVE)
	var n := roundi(after / DT)
	_ticks(a, mini(n, 30), WorldReader.STATE_RECOVER)
	_ticks(a, maxi(n - 30, 0))


func _drive(a: WireWeaverAvatar, clip: String, v: Variant, f: int) -> void:
	match clip:
		"idle":
			_ticks(a, 60 + int(v) * 27)
		"walk":
			_ticks(a, 60 + int(v) * 4, WorldReader.STATE_MOVE, 2.6 / 60.0)
		"back":
			_ticks(a, 60 + int(v) * 4, WorldReader.STATE_MOVE, -2.6 / 60.0)
		"tell":
			_ticks(a, 60)
			_tell(a, float(v))
		"plant":
			_ticks(a, 60)
			_tell(a, 1.0, float(v))
		"hurt":
			_ticks(a, 60)
			if float(v) > 0.0:
				_ticks(a, 1, WorldReader.STATE_MOVE, 0.0, 30)
				a.flinch(-Vector2(cos(FACING), sin(FACING)), 1.0)  # hit from the front: pushed back
				_ticks(a, maxi(roundi(float(v) / DT) - 1, 0), WorldReader.STATE_MOVE, 0.0, 30)
		"death":
			_ticks(a, 60)
			a.die()
			_frames(a, float(v) * WireWeaverAvatar.DEATH_SECONDS)
		"spawn":
			a.apply_state({"tick": 1, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO})
			a.set_meta(&"tick", 1)
			_ticks(a, 6, WorldReader.STATE_SPAWN)
			_ticks(a, roundi(float(v) / DT))
		"calm":
			ViewPrefs.reduced_motion = true
			_ticks(a, 60)
			match f:
				0:
					_ticks(a, 20, WorldReader.STATE_MOVE, 2.6 / 60.0)
				1:
					_tell(a, 0.7)
				2:
					_tell(a, 1.0, 0.1)
				3:
					_tell(a, 1.0, 1.0)
				4:
					a.die()
					_frames(a, 0.6 * WireWeaverAvatar.DEATH_SECONDS)
