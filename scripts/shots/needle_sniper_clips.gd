extends SceneTree
## The Needle's or the Sniper's clip sheet for the owner: one row per clip, five frames across, each frame its own
## avatar (NeedleAvatar / SniperAvatar) driven from a fresh start to that moment by the calls ActorViews makes
## (apply_state once a tick, advance once a frame, the flinch and the death as HitFeel and ActorViews start them), seen
## from the game's iso camera angle on a plain floor.
## Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 --resolution 1300x400 -s <this script> -- --kind=needle
## (or --kind=sniper, --kind=split_sniper, --kind=dim_needle). Writes build/shots/models_v0120b/<kind>_clips.png.

const CELL := Vector2i(260, 250)
const FRAMES := 5
const DT := 1.0 / 60.0
const OUT := "res://build/shots/models_v0120b/%s_clips.png"
## Per kind: [the body's kind, the look's kind, its move speed (m/s), the windup's ticks, the attack's active ticks,
## the frames' spacing (m), the camera's look height (m), the facing node's yaw (a three-quarter view: the Needle's
## front toward the camera, the Sniper's long barrel across the screen to the right)].
const KINDS := {
	"needle": [WorldReader.KIND_NEEDLE, -1, 3.2, 30, 13, 1.55, 0.45, -0.35],
	"dim_needle":
	[WorldReader.KIND_NEEDLE, WorldReader.KIND_DIM_NEEDLE, 3.2, 30, 13, 1.55, 0.45, -0.35],
	"sniper": [WorldReader.KIND_SNIPER, -1, 2.6, 60, 1, 2.2, 0.6, -1.25],
	"split_sniper":
	[WorldReader.KIND_SNIPER, WorldReader.KIND_SPLIT_SNIPER, 2.6, 60, 1, 2.2, 0.6, -1.25],
}
## [label, clip, frame values].
const ROWS := [
	["idle: glances and breath (0.45 s apart)", "idle", [0, 1, 2, 3, 4]],
	["walk (0.033 s apart)", "walk", [0, 1, 2, 3, 4]],
	["turning in place (0.07 s apart)", "turn", [0, 1, 2, 3, 4]],
	["windup 10, 30, 55, 80, 95 %", "tell", [0.1, 0.3, 0.55, 0.8, 0.95]],
	["attack: windup 100 %, +0.02, +0.1, +0.2, +0.45 s", "shot", [-1, 1, 6, 12, 27]],
	["recovery and vent: +0.25, +0.4, +0.55, +0.7, +1.0 s", "shot", [15, 24, 33, 42, 60]],
	["hit: 0, 0.05, 0.1, 0.18, 0.3 s", "hit", [0.0, 0.05, 0.1, 0.18, 0.3]],
	["death: 0, 15, 35, 60, 100 %", "death", [0.0, 0.15, 0.35, 0.6, 1.0]],
	["rise-in: 0, 0.15, 0.3, 0.45, 0.7 s", "spawn", [0.0, 0.15, 0.3, 0.45, 0.7]],
	["reduced motion: idle, walk, windup 80 %, attack +0.1 s, death 60 %", "calm", [0, 1, 2, 3, 4]],
]

var _rows: Array[SubViewport] = []
var _frame := 0
var _name := "needle"
var _spec: Array = KINDS["needle"]
var _facing := -0.35


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind=") and KINDS.has(arg.trim_prefix("--kind=")):
			_name = arg.trim_prefix("--kind=")
	_spec = KINDS[_name]
	_facing = _spec[7]
	var out := OUT % _name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	print(
		(
			"needle_sniper_clips: %s renderer=%s model=%s"
			% [
				_name,
				RenderingServer.get_current_rendering_method(),
				EnemyModels.has_model(
					&"needle" if _spec[0] == WorldReader.KIND_NEEDLE else &"sniper"
				)
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
	var png := ProjectSettings.globalize_path(OUT % _name)
	sheet.save_png(png)
	print("needle_sniper_clips: " + png)
	return true


## One clip's row: a little world with five avatars side by side along the camera's right, each at its frame.
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
	plane.size = Vector2(30, 30)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#8c9aa6")
	floor_mi.material_override = fm
	scene.add_child(floor_mi)
	var iso := Basis(Vector3.UP, deg_to_rad(45.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.26))
	var right := Basis(Vector3.UP, deg_to_rad(45.0)) * Vector3.RIGHT
	var spacing: float = _spec[5]
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = spacing * FRAMES
	scene.add_child(cam)
	var look := Vector3(0, float(_spec[6]), 0)
	cam.look_at_from_position(look + iso * Vector3.BACK * 14.0, look, Vector3.UP)
	cam.current = true
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = "%s: %s" % [_name, String(spec[0])]
	label.position = Vector2(8, 4)
	label.add_theme_font_size_override(&"font_size", 18)
	vp.add_child(label)
	var values: Array = spec[2]
	for f in FRAMES:
		var actor := Node3D.new()
		actor.position = right * (f - (FRAMES - 1) * 0.5) * spacing
		scene.add_child(actor)
		var facing := Node3D.new()
		facing.rotation.y = _facing
		actor.add_child(facing)
		var a: AvatarBase = (
			NeedleAvatar.new() if _spec[0] == WorldReader.KIND_NEEDLE else SniperAvatar.new()
		)
		a.look_kind = int(_spec[1])
		a.call(&"setup")
		facing.add_child(a)
		a.set_process(false)  # (after it enters the tree: ready turns its _process back on)
		_drive(a, String(spec[1]), values[f], f)
		ViewPrefs.reduced_motion = false
	return vp


## Ticks of `state` for `a` (one apply_state and one frame each): `windup` its progress, `speed` m a tick along the
## facing, `turn` radians a tick of the facing, `hp` its HP.
func _ticks(
	a: AvatarBase,
	n: int,
	state := WorldReader.STATE_MOVE,
	windup := 0.0,
	speed := 0.0,
	turn := 0.0,
	hp := 40
) -> void:
	var t: int = a.get_meta(&"tick", 0)
	var x: float = a.get_meta(&"x", 0.0)
	var dir := Vector2(cos(_facing), sin(_facing))  # the facing's forward on the sim plane (3D +X turned by _facing)
	for k in n:
		t += 1
		x += speed
		(a.get_parent() as Node3D).rotation.y += turn
		a.call(
			&"apply_state", {"tick": t, "state": state, "pos": dir * x, "windup": windup, "hp": hp}
		)
		a.advance(DT)
		a.advance_flinch(DT)
	a.set_meta(&"tick", t)
	a.set_meta(&"x", x)


## The windup from its start to `to` (0..1).
func _ramp(a: AvatarBase, to: float) -> void:
	var n: int = _spec[3]
	for k in roundi(to * n):
		_ticks(a, 1, WorldReader.STATE_WINDUP, float(k + 1) / n)


## The windup in full, then `after` ticks of the attack (its active ticks, then the recovery).
func _shot(a: AvatarBase, after: int) -> void:
	_ramp(a, 1.0)
	var active: int = _spec[4]
	for k in after:
		_ticks(a, 1, WorldReader.STATE_ACTIVE if k < active else WorldReader.STATE_RECOVER)


func _frames(a: AvatarBase, seconds: float) -> void:
	for k in roundi(seconds / DT):
		a.advance(DT)
		a.advance_flinch(DT)


func _drive(a: AvatarBase, clip: String, v: Variant, f: int) -> void:
	var speed: float = float(_spec[2]) / 60.0
	var death := NeedleAvatar.DEATH_SECONDS if a is NeedleAvatar else SniperAvatar.DEATH_SECONDS
	match clip:
		"idle":
			_ticks(a, 60 + int(v) * 27)
		"walk":
			_ticks(a, 60 + int(v) * 2, WorldReader.STATE_MOVE, 0.0, speed)
		"turn":
			_ticks(a, 30)
			_ticks(a, 30 + int(v) * 4, WorldReader.STATE_MOVE, 0.0, 0.0, 2.5 / 60.0)
		"tell":
			_ticks(a, 60)
			_ramp(a, float(v))
		"shot":
			_ticks(a, 60)
			if int(v) < 0:
				_ramp(a, 1.0)
			else:
				_shot(a, int(v))
		"hit":
			_ticks(a, 60)
			_ticks(a, 1, WorldReader.STATE_MOVE, 0.0, 0.0, 0.0, 30)
			a.flinch(-Vector2(cos(_facing), sin(_facing)), 1.0)  # hit from the front: pushed back
			_ticks(a, roundi(float(v) / DT), WorldReader.STATE_MOVE, 0.0, 0.0, 0.0, 30)
		"death":
			_ticks(a, 60)
			a.call(&"die")
			_frames(a, float(v) * death)
		"spawn":
			a.call(
				&"apply_state", {"tick": 1, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO}
			)
			a.set_meta(&"tick", 1)
			_ticks(a, roundi(float(v) / DT))
		"calm":
			ViewPrefs.reduced_motion = true
			match f:
				0:
					_ticks(a, 87)
				1:
					_ticks(a, 66, WorldReader.STATE_MOVE, 0.0, speed)
				2:
					_ticks(a, 60)
					_ramp(a, 0.8)
				3:
					_ticks(a, 60)
					_shot(a, 6)
				4:
					_ticks(a, 60)
					a.call(&"die")
					_frames(a, 0.6 * death)
