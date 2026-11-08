extends SceneTree
## v0.11.0 O17a: the Scrap Hound's clip sheet for the owner: one row per clip, five frames across, each drawn from the
## game camera's angle (iso, orthographic) on a plain floor, the code avatar (ScrapHoundAvatar, the VAT's reference)
## driven by the very calls ActorViews makes (apply_state each tick, advance in frame time, flinch, die) through a
## made-up sim timeline (CLIPS): the trot, the gallop and the circling run, the tell turning in from the circle, the
## dart, the bite, the yelp, a plain hit, the death, the rise-in, and three clips again with reduced motion. Each frame
## turns the whole little world so the hound is seen as a row asks (side on, or three-quarter front).
## Needs a renderer (NOT --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 -s scripts/shots/o17_hound_clips.gd
## Writes build/shots/o17/scrap_hound_clips.png.

const CELL := Vector2i(240, 200)
const LABEL_W := 150
const DT := 1.0 / 60.0
const OUT := "res://build/shots/o17/scrap_hound_clips.png"
## The rows: [label, clip, the frames (ticks after the clip's event), the view (the body's heading on screen, degrees:
## 45 side on, 0 three-quarter front), reduced motion].
const ROWS := [
	["idle (panting, glances)", "idle", [36, 72, 108, 144, 180], 20.0, false],
	["trot 2 m/s", "trot", [0, 6, 11, 17, 22], 45.0, false],
	["gallop 6.5 m/s", "gallop", [0, 4, 7, 11, 14], 45.0, false],
	["circling (banked)", "circle", [0, 4, 7, 11, 14], 30.0, false],
	["tell (turns in)", "tell", [1, 6, 11, 16, 22], 0.0, false],
	["tell, side on", "tell", [1, 6, 11, 16, 22], 45.0, false],
	["dart 14 m/s", "dart", [1, 3, 6, 12, 22], 45.0, false],
	["bite + skid stop", "bite", [2, 5, 9, 16, 30], 30.0, false],
	["yelp (hit in the tell)", "yelp", [3, 8, 15, 27, 42], 30.0, false],
	["plain hit (flinch)", "hurt", [2, 4, 7, 11, 16], 20.0, false],
	["death", "death", [6, 15, 27, 39, 57], 30.0, false],
	["rise-in", "spawn", [2, 10, 20, 30, 45], 20.0, false],
	["gallop, reduced motion", "gallop", [0, 4, 7, 11, 14], 45.0, true],
	["tell, reduced motion", "tell", [1, 6, 11, 16, 22], 0.0, true],
	["yelp, reduced motion", "yelp", [3, 8, 15, 27, 42], 30.0, true],
]
## Where each clip's event falls (ticks of lead-in before it).
const LEAD := {
	"idle": 0,
	"trot": 120,
	"gallop": 120,
	"circle": 90,
	"tell": 60,
	"dart": 84,
	"bite": 104,
	"yelp": 72,
	"hurt": 60,
	"death": 40,
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


## One frame: a little world (camera, sun, floor) with a hound driven through `row`'s clip to `at` ticks past its
## event.
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
	cam.size = 1.3
	var look := Vector3(0.0, 0.3, 0)
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
	var a := ScrapHoundAvatar.new()
	a.setup(Color("#1A1A22"), &"outline")
	facing.add_child(a)
	a.process_mode = Node.PROCESS_MODE_DISABLED  # (its ready would turn processing back on)
	EnemyShadows.apply(actor, facing, a, a.kind, 0.35, "proxy")
	_drive(a, facing, String(row[1]), int(LEAD[row[1]]) + at)
	ViewPrefs.reduced_motion = false
	# Seen as the row asks: the body's heading on screen (the camera looks from 45 degrees).
	var heading := facing.rotation.y + a.body_yaw()
	actor.rotation.y = deg_to_rad(float(row[3])) - heading
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
func _drive(a: ScrapHoundAvatar, facing: Node3D, clip: String, ticks: int) -> void:
	var lead: int = LEAD[clip]
	var pos := Vector2.ZERO
	var hp := 30
	var dead := false
	for k in ticks + 1:
		var st := WorldReader.STATE_MOVE
		var windup := 0.0
		var yelped := false
		var face := 0.0
		var e := k - lead  # ticks since the clip's event
		match clip:
			"trot", "gallop":
				var v := 2.0 if clip == "trot" else 6.5
				pos += Vector2(1, 0) * v * DT
			"circle", "tell", "dart", "bite", "yelp":
				var ang := 1.3 * float(k if clip == "circle" else mini(k, 60)) * DT
				pos = Vector2(cos(ang), sin(ang)) * 5.0
				face = atan2(-pos.y, -pos.x)
				if clip != "circle" and k >= 60:
					st = WorldReader.STATE_WINDUP
					windup = float(k - 60 + 1) / 24.0
					if clip == "yelp" and k >= 72:
						st = WorldReader.STATE_RECOVER
						yelped = true
						hp = 20
					elif clip in ["dart", "bite"] and k >= 84:
						st = WorldReader.STATE_ACTIVE
						windup = 0.0
						pos += Vector2(cos(face), sin(face)) * 14.0 * DT * float(mini(k, 103) - 83)
						if clip == "bite" and k >= 104:
							st = WorldReader.STATE_RECOVER
			"hurt":
				if e == 0:
					hp = 24
					a.flinch(Vector2(-1.0, 0.3), 1.0)
			"death":
				pos += Vector2(1, 0) * 6.5 * DT
				if e == 0:
					dead = true
					a.die()
			"spawn":
				st = WorldReader.STATE_SPAWN if k < 24 else WorldReader.STATE_MOVE
		facing.rotation.y = face
		if not dead:
			a.apply_state(
				{
					"tick": k,
					"state": st,
					"pos": pos,
					"windup": clampf(windup, 0.0, 1.0),
					"yelped": yelped,
					"hp": hp
				}
			)
		a.advance(DT)
		a.advance_flinch(DT)
