extends SceneTree
## The clip sheet of the Hatchling, the Swarmer or a walking critter (the Dust Mite, Ember Flea, Ice Crab) on the
## owner's model, for the owner: one row per clip, five frames
## across, each frame its own avatar (HatchlingAvatar; the others' HordeAvatar) driven from a fresh start to that
## moment by the calls ActorViews makes (apply_state once a tick, advance once a frame, the flinch and the death as
## HitFeel and ActorViews start them), seen from the game's iso camera angle on a plain floor.
## Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 --resolution 1200x400 -s <this script> -- kind=hatchling
## Writes build/shots/models_v0120b/<kind>_clips.png.

const CELL := Vector2i(240, 230)
const FRAMES := 5
const DT := 1.0 / 60.0
## The facing node's yaw (a three-quarter view, the front toward the camera and the screen's right).
const FACING := -0.35
const WINDUP_TICKS := 40
const OUT := "res://build/shots/models_v0120b/%s_clips.png"
## Per kind: [the sim kind, its move speed (m/s), the frames' spacing (m), the camera's look height (m)].
const KINDS := {
	"hatchling": [WorldReader.KIND_HATCHLING, 3.6, 0.85, 0.18],
	"swarmer": [WorldReader.KIND_SWARMER, 4.6, 0.7, 0.12],
	"dust_mite": [WorldReader.KIND_DUST_MITE, 5.0, 0.55, 0.1],
	"ember_flea": [WorldReader.KIND_EMBER_FLEA, 5.2, 0.75, 0.24],
	"ice_crab": [WorldReader.KIND_ICE_CRAB, 4.8, 0.6, 0.08],
}
## [label, clip, frame values].
const ROWS := [
	["idle (0.3 s apart)", "idle", [0, 1, 2, 3, 4]],
	["run (0.03 s apart)", "run", [0, 1, 2, 3, 4]],
	["tell: windup 10, 30, 55, 80, 95 %", "tell", [0.1, 0.3, 0.55, 0.8, 0.95]],
	["strike: windup 100 %, +0.03, +0.1, +0.25, +0.5 s", "strike", [-1, 2, 6, 15, 30]],
	["hit: 0, 0.05, 0.1, 0.18, 0.3 s", "hit", [0.0, 0.05, 0.1, 0.18, 0.3]],
	["death: 0, 15, 35, 60, 100 %", "death", [0.0, 0.15, 0.35, 0.6, 1.0]],
	["rise-in: 0, 0.1, 0.2, 0.3, 0.5 s", "spawn", [0.0, 0.1, 0.2, 0.3, 0.5]],
	["reduced motion: idle, run, windup 80 %, strike +0.1 s, death 60 %", "calm", [0, 1, 2, 3, 4]],
]
## The critters' clips (no windup: they only touch).
const CRITTER_ROWS := [
	["idle (0.15 s apart)", "idle_fast", [0, 1, 2, 3, 4]],
	["run (one frame apart)", "run_fine", [0, 1, 2, 3, 4]],
	["stop after a run: 0, 0.08, 0.16, 0.24, 0.32 s", "stop", [0, 5, 10, 14, 19]],
	["hit: 0, 0.05, 0.1, 0.18, 0.3 s", "hit", [0.0, 0.05, 0.1, 0.18, 0.3]],
	["death: 0, 15, 35, 60, 100 %", "death", [0.0, 0.15, 0.35, 0.6, 1.0]],
	["rise-in: 0, 0.1, 0.2, 0.3, 0.5 s", "spawn", [0.0, 0.1, 0.2, 0.3, 0.5]],
	["reduced motion: idle, idle +0.3 s, run, hit, death 60 %", "calm_critter", [0, 1, 2, 3, 4]],
]
## The Hatchling's daze after its charge (s into the recovery).
const DAZE_ROW := ["daze after the charge: 0.1, 0.3, 0.5, 0.7, 0.9 s", "daze", [6, 18, 30, 42, 54]]

var _rows: Array[SubViewport] = []
var _frame := 0
var _name := "hatchling"
var _spec: Array = KINDS["hatchling"]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("kind=") and KINDS.has(arg.trim_prefix("kind=")):
			_name = arg.trim_prefix("kind=")
	_spec = KINDS[_name]
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT % _name).get_base_dir()
	)
	print(
		(
			"horde_model_clips: kind=%s renderer=%s model=%s"
			% [_name, RenderingServer.get_current_rendering_method(), EnemyModels.has_model(_name)]
		)
	)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		var rows: Array = (
			CRITTER_ROWS.duplicate() if CritterModel.takes(_spec[0]) else ROWS.duplicate()
		)
		if _name == "hatchling":
			rows.insert(4, DAZE_ROW)
		for spec: Array in rows:
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
	print("horde_model_clips: " + png)
	return true


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
	var spacing: float = _spec[2]
	var iso := Basis(Vector3.UP, deg_to_rad(45.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.26))
	var right := Basis(Vector3.UP, deg_to_rad(45.0)) * Vector3.RIGHT
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = spacing * FRAMES
	scene.add_child(cam)
	var look := Vector3(0, float(_spec[3]), 0)
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
		var at := right * (f - (FRAMES - 1) * 0.5) * spacing
		actor.position = at
		scene.add_child(actor)
		var facing := Node3D.new()
		facing.rotation.y = FACING
		actor.add_child(facing)
		var a: AvatarBase
		if _name == "hatchling":
			a = HatchlingAvatar.new()
			(a as HatchlingAvatar).setup()
		else:
			a = HordeAvatar.new()
			(a as HordeAvatar).setup(_spec[0])
		facing.add_child(a)
		a.set_process(false)  # (after it enters the tree: ready turns its _process back on)
		_drive(a, String(spec[1]), values[f], f)
		actor.position = at  # (a run carried it forward: back to its cell, its pose kept)
		ViewPrefs.reduced_motion = false
	return vp


## `n` ticks of `state` for `a` (one apply_state and one frame each): `windup` its progress, `speed` m a tick along the
## facing (its actor carried along: the Swarmer reads its pace from how fast it moves on screen).
func _ticks(
	a: AvatarBase, n: int, state := WorldReader.STATE_MOVE, windup := 0.0, speed := 0.0
) -> void:
	var t: int = a.get_meta(&"tick", 0)
	var x: float = a.get_meta(&"x", 0.0)
	var dir := Vector2(cos(FACING), -sin(FACING))  # the facing's forward on the floor (x, z)
	var actor := a.get_parent().get_parent() as Node3D
	for k in n:
		t += 1
		x += speed
		actor.position += Vector3(dir.x, 0, dir.y) * speed
		a.apply_state({"tick": t, "state": state, "pos": dir * x, "windup": windup})
		a.advance(DT)
		a.advance_flinch(DT)
	a.set_meta(&"tick", t)
	a.set_meta(&"x", x)


func _ramp(a: AvatarBase, to: float) -> void:
	for k in roundi(to * WINDUP_TICKS):
		_ticks(a, 1, WorldReader.STATE_WINDUP, float(k + 1) / WINDUP_TICKS)


## The windup in full, then `after` ticks of the strike (the Hatchling charges at 13 m/s through its active ticks)
## and its recovery.
func _strike(a: AvatarBase, after: int) -> void:
	_ramp(a, 1.0)
	var active := 23 if _name == "hatchling" else 10
	var dash := 13.0 / 60.0 if _name == "hatchling" else 0.0
	for k in after:
		if k < active:
			_ticks(a, 1, WorldReader.STATE_ACTIVE, 0.0, dash)
		else:
			_ticks(a, 1, WorldReader.STATE_RECOVER)


func _frames(a: AvatarBase, seconds: float) -> void:
	for k in roundi(seconds / DT):
		a.advance(DT)
		a.advance_flinch(DT)


func _drive(a: AvatarBase, clip: String, v: Variant, f: int) -> void:
	var run: float = float(_spec[1]) / 60.0
	var death_s: float = (
		HatchlingAvatar.DEATH_SECONDS if _name == "hatchling" else HordeAvatar.DEATH_SECONDS
	)
	match clip:
		"idle":
			_ticks(a, 60 + int(v) * 18)
		"idle_fast":
			_ticks(a, 60 + int(v) * 9)
		"run":
			_ticks(a, 60 + int(v) * 2, WorldReader.STATE_MOVE, 0.0, run)
		"run_fine":
			_ticks(a, 60 + int(v), WorldReader.STATE_MOVE, 0.0, run)
		"stop":
			_ticks(a, 60, WorldReader.STATE_MOVE, 0.0, run)
			_ticks(a, 1 + int(v))
		"calm_critter":
			ViewPrefs.reduced_motion = true
			match f:
				0, 1:
					_ticks(a, 60 + 18 * f)
				2:
					_ticks(a, 63, WorldReader.STATE_MOVE, 0.0, run)
				3:
					_ticks(a, 60)
					a.flinch(-Vector2(cos(FACING), -sin(FACING)), 1.0)
					_ticks(a, 6)
				4:
					_ticks(a, 60)
					a.call(&"die")
					_frames(a, 0.6 * death_s)
		"tell":
			_ticks(a, 60)
			_ramp(a, float(v))
		"strike":
			_ticks(a, 60)
			if int(v) < 0:
				_ramp(a, 1.0)
			else:
				_strike(a, int(v))
		"daze":
			_ticks(a, 60)
			_strike(a, 23 + int(v))
		"hit":
			_ticks(a, 60)
			a.flinch(-Vector2(cos(FACING), -sin(FACING)), 1.0)  # hit from the front: pushed back
			_ticks(a, roundi(float(v) / DT))
		"death":
			_ticks(a, 60)
			a.call(&"die")
			_frames(a, float(v) * death_s)
		"spawn":
			a.apply_state({"tick": 1, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO})
			a.set_meta(&"tick", 1)
			_frames(a, 0.1)
			_ticks(a, roundi(float(v) / DT))
		"calm":
			ViewPrefs.reduced_motion = true
			match f:
				0:
					_ticks(a, 87)
				1:
					_ticks(a, 66, WorldReader.STATE_MOVE, 0.0, run)
				2:
					_ticks(a, 60)
					_ramp(a, 0.8)
				3:
					_ticks(a, 60)
					_strike(a, 6)
				4:
					_ticks(a, 60)
					a.call(&"die")
					_frames(a, 0.6 * death_s)
