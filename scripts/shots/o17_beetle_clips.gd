extends SceneTree
## v0.11.0 O17e: the Kiln Beetle's clip sheet for the owner: one row per clip, five frames across, each drawn from the
## game camera's angle (iso, orthographic) on a plain floor, the code avatar (KilnBeetleAvatar, the VAT's reference)
## driven by the very calls ActorViews makes (apply_state each tick, the facing it turns, advance in frame time,
## flinch, die) through a made-up sim timeline (CLIPS, the beetle's own timings: data/enemies/kiln_beetle.tres): idle,
## the walk, a turn in place, the heat at five HP shares, the slam's windup and the slam, a hit, the death over the
## burst's fuse, the rise-in, and three clips again with reduced motion. Each frame turns the whole little world so the
## beetle is seen as a row asks (side on, or three-quarter front).
## Needs a renderer (NOT --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 -s scripts/shots/o17_beetle_clips.gd
## Writes build/shots/o17/kiln_beetle_clips.png.

const CELL := Vector2i(240, 200)
const LABEL_W := 150
const DT := 1.0 / 60.0
const OUT := "res://build/shots/o17/kiln_beetle_clips.png"
const MAX_HP := 60
## The slam's windup (telegraph_seconds) and recovery in ticks.
const WINDUP_TICKS := 30
const RECOVER_TICKS := 48
## The rows: [label, clip, the frames (ticks after the clip's event; the heat's: HP shares in %), the view (the body's
## heading on screen, degrees: 45 side on, 0 three-quarter front), reduced motion].
const ROWS := [
	["idle (breath, glances)", "idle", [30, 60, 90, 120, 150], 20.0, false],
	["walk 1.2 m/s (a stride)", "walk", [0, 4, 8, 12, 16], 45.0, false],
	["walk, front three-quarter", "walk", [0, 4, 8, 12, 16], 0.0, false],
	["turning in place 90 deg/s", "turn", [0, 4, 8, 12, 16], 30.0, false],
	["heat: HP 100 75 50 25 5 %", "heat", [100, 75, 50, 25, 5], 20.0, false],
	["slam windup (0.5 s)", "windup", [3, 9, 15, 21, 28], 45.0, false],
	["slam windup, front", "windup", [3, 9, 15, 21, 28], 0.0, false],
	["slam + recovery", "slam", [1, 3, 7, 18, 36], 45.0, false],
	["hit flinch", "hurt", [2, 4, 7, 11, 17], 20.0, false],
	["death over the 1 s fuse", "death", [6, 18, 32, 46, 58], 30.0, false],
	["rise-in", "spawn", [2, 10, 20, 30, 45], 20.0, false],
	["walk, reduced motion", "walk", [0, 4, 8, 12, 16], 45.0, true],
	["windup, reduced motion", "windup", [3, 9, 15, 21, 28], 45.0, true],
	["death, reduced motion", "death", [6, 18, 32, 46, 58], 30.0, true],
]
## Where each clip's event falls (ticks of lead-in before it).
const LEAD := {
	"idle": 0,
	"walk": 120,
	"turn": 60,
	"heat": 90,
	"windup": 60,
	"slam": 60 + WINDUP_TICKS,
	"hurt": 60,
	"death": 60,
	"spawn": 0,
}

var _cells: Array = []  # [SubViewport, row, column]
var _labels: Array = []  # a row's label, drawn in its own SubViewport
var _frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots/o17/"))
	for r in ROWS.size():
		var row: Array = ROWS[r]
		var frames: Array = row[2]
		for c in frames.size():
			_cells.append([_cell(row, int(frames[c])), r, c])


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 10:
		return false
	var sheet := Image.create(LABEL_W + CELL.x * 5, CELL.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#15171c"))
	for e: Array in _cells:
		var img := (e[0] as SubViewport).get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(
			img,
			Rect2i(Vector2i.ZERO, CELL),
			Vector2i(LABEL_W + CELL.x * int(e[2]), CELL.y * int(e[1]))
		)
	for r in ROWS.size():
		var lab := _labels[r] as SubViewport
		var li := lab.get_texture().get_image()
		li.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(
			li, Rect2i(Vector2i.ZERO, Vector2i(LABEL_W, CELL.y)), Vector2i(0, CELL.y * r)
		)
	var path := ProjectSettings.globalize_path(OUT)
	sheet.save_png(path)
	print("clip sheet: " + path)
	quit(0)
	return true


## One frame: a little world (camera, sun, floor) with a beetle driven through `row`'s clip to `at` ticks past its
## event (the heat's row: at `at` % of its HP).
func _cell(row: Array, at: int) -> SubViewport:
	var r := int(_cells.size() / 5.0)
	if _labels.size() <= r:
		_labels.append(_label(String(row[0])))
	var vp := SubViewport.new()
	vp.size = CELL
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
	env.environment.glow_enabled = true
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#5a564f")
	floor_mi.material_override = fm
	scene.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.75
	var look := Vector3(0.0, 0.28, 0)
	var dir := (
		Basis(Vector3.UP, deg_to_rad(45.0))
		* Basis(Vector3.RIGHT, deg_to_rad(-35.26))
		* Vector3.BACK
	)
	scene.add_child(cam)
	cam.look_at_from_position(look + dir * 10.0, look, Vector3.UP)
	cam.current = true
	var actor := Node3D.new()
	scene.add_child(actor)
	var facing := Node3D.new()
	actor.add_child(facing)
	ViewPrefs.reduced_motion = bool(row[4])
	var a := KilnBeetleAvatar.new()
	a.setup(Color("#1A1A22"), &"outline")
	facing.add_child(a)
	a.process_mode = Node.PROCESS_MODE_DISABLED  # (its ready would turn processing back on)
	EnemyShadows.apply(actor, facing, a, a.kind, 0.5, "proxy")
	var clip := String(row[1])
	if clip == "heat":
		_drive(a, facing, clip, int(LEAD[clip]), int(roundf(MAX_HP * at / 100.0)))
	else:
		_drive(a, facing, clip, int(LEAD[clip]) + at, MAX_HP)
	ViewPrefs.reduced_motion = false
	# Seen as the row asks: the body's heading on screen (the camera looks from 45 degrees).
	actor.rotation.y = deg_to_rad(float(row[3])) - facing.rotation.y
	return vp


func _label(text: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(LABEL_W, CELL.y)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#15171c")
	bg.size = Vector2(LABEL_W, CELL.y)
	vp.add_child(bg)
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.position = Vector2(8, CELL.y * 0.4)
	l.size = Vector2(LABEL_W - 12, CELL.y * 0.5)
	vp.add_child(l)
	return vp


## Runs `clip`'s made-up sim timeline for `ticks` ticks: each tick the sim's state (apply_state), the facing ActorViews
## would set, and a frame of time (advance and the flinch).
func _drive(a: KilnBeetleAvatar, facing: Node3D, clip: String, ticks: int, hp0: int) -> void:
	var lead: int = LEAD[clip]
	var pos := Vector2.ZERO
	var hp := hp0
	var dead := false
	var face := 0.0
	for k in ticks + 1:
		var st := WorldReader.STATE_MOVE
		var windup := 0.0
		var e := k - lead  # ticks since the clip's event
		match clip:
			"walk":
				pos += Vector2(1, 0) * 1.2 * DT
			"turn":
				if e >= 0:
					face += deg_to_rad(90.0) * DT
			"windup", "slam":
				var w := k - 60  # the windup's start
				if w >= 0 and w < WINDUP_TICKS:
					st = WorldReader.STATE_WINDUP
					windup = float(w + 1) / WINDUP_TICKS
				elif w == WINDUP_TICKS:
					st = WorldReader.STATE_ACTIVE
				elif w > WINDUP_TICKS and w <= WINDUP_TICKS + RECOVER_TICKS:
					st = WorldReader.STATE_RECOVER
			"hurt":
				if e == 0:
					hp = 46
					a.flinch(Vector2(-1.0, 0.3), 1.0)
			"death":
				hp = 9
				pos += Vector2(1, 0) * 1.2 * DT if e < 0 else Vector2.ZERO
				if e == 0:
					dead = true
					a.die()
			"spawn":
				st = WorldReader.STATE_SPAWN if k < 24 else WorldReader.STATE_MOVE
		facing.rotation.y = face
		if not dead:
			(
				a
				. apply_state(
					{
						"tick": k,
						"state": st,
						"pos": pos,
						"windup": clampf(windup, 0.0, 1.0),
						"hp": hp,
						"max_hp": MAX_HP,
					}
				)
			)
		a.advance(DT)
		a.advance_flinch(DT)
