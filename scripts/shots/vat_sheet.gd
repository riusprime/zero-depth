extends SceneTree
## v0.10.5 W3-V1 (the enemy VAT pilot, G2: the owner judges the tolerance): one sheet of the pilot kind (the Swarmer) in
## each state it can show, the old path (its pieces as nodes, left) beside VAT (VatCrowd's MultiMesh, right), each pair
## driven by the very same calls (apply_state / advance / flinch / show_hit, as ActorViews and HitFeel make them) and
## drawn in two identical little worlds (iso camera, a sun, a floor, the proxy shadow). Also prints and writes, per
## state, how far the two images differ (max channel difference and the share of pixels off by more than 8 / 255).
## Needs a renderer (NOT --headless); off screen:
##   APPDATA=<temp> godot --path . --resolution 1920x1080 --position -10000,-10000 -s scripts/shots/vat_sheet.gd
## Writes build/shots/<version>/vat/vat_sheet.png and vat_diff.txt.

const CELL := Vector2i(220, 220)
const COLS := 4
const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_SWARMER
const S := WorldReader
## The states: [label, build: {tint, role} or {}, steps].
const PLAN := [
	["idle", {}, "idle"],
	["scuttle (t 1.37 s)", {}, "scuttle"],
	["windup 31 %", {}, "windup_early"],
	["windup 90 % (flash)", {}, "windup_late"],
	["strike snap (0.05 s)", {}, "strike_snap"],
	["strike out (0.15 s)", {}, "strike_out"],
	["strike easing back", {}, "strike_back"],
	["flinch at its peak", {}, "flinch"],
	["Blade knock", {}, "knock"],
	["hit flash", {}, "flash"],
	["status tint (burn)", {}, "tint"],
	["rise-in, half way", {}, "spawn"],
	["biome cast + role glow", {"tint": Color(0.45, 0.65, 1.0, 0.5), "role": 0.45}, "idle"],
	["reduced motion + flinch", {}, "calm"],
]

var _dir := ""
var _pairs: Array = []  # [label, live SubViewport, vat SubViewport]
var _frame := 0


func _initialize() -> void:
	_dir = "res://build/shots/%s/vat/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var grid := GridContainer.new()
	grid.columns = COLS
	root.add_child(grid)
	for spec: Array in PLAN:
		var cell := VBoxContainer.new()
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = "%s   (old | VAT)" % spec[0]
		cell.add_child(label)
		var row := HBoxContainer.new()
		cell.add_child(row)
		grid.add_child(cell)
		var build: Dictionary = spec[1]
		var live := _world(row, false, build, spec[2])
		var vat := _world(row, true, build, spec[2])
		_pairs.append([spec[0], live, vat])


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 12:
		return false
	_finish()
	return true


## One little world showing one avatar (`vat`: drawn by a VatCrowd), driven through `steps`.
func _world(row: HBoxContainer, vat: bool, build: Dictionary, steps: String) -> SubViewport:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(CELL)
	row.add_child(box)
	var vp := SubViewport.new()
	vp.size = CELL
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var scene := Node3D.new()
	vp.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#1b1d24")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#9aa3b5")
	env.environment.ambient_light_energy = 0.5
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#5a564f")
	floor_mi.material_override = fm
	scene.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.85
	var look := Vector3(0, 0.15, 0)
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
	facing.rotation.y = 0.6
	actor.add_child(facing)
	var a := HordeAvatar.new()
	a.enemy_tint = build.get("tint", Color(0, 0, 0, 0))
	a.role_glow = float(build.get("role", 0.0))
	a.vat = vat
	a.setup(KIND, Color("#1A1A22"))
	facing.add_child(a)
	a.set_process(false)
	if vat:
		var crowd := VatCrowd.new()
		scene.add_child(crowd)
		crowd.add(actor, facing, a, Color("#1A1A22"), true)
	else:
		EnemyShadows.apply(actor, facing, a, KIND, 0.25, "proxy")
	_drive(a, steps)
	return vp


## The calls a state is made of (both avatars of a pair get the same ones).
func _drive(a: HordeAvatar, steps: String) -> void:
	var tick := 0
	if steps == "spawn":  # spawned sunk, then half risen (2.5 a second)
		a.apply_state({"tick": 0, "state": S.STATE_SPAWN})
		_run(a, 2)
		for k in 12:
			a.apply_state({"tick": 1 + k, "state": S.STATE_MOVE})
			_run(a, 1)
		return
	if steps == "calm":
		ViewPrefs.reduced_motion = true
	a.apply_state({"tick": tick, "state": S.STATE_MOVE})
	var idle := 82 if steps == "scuttle" else 60
	for k in idle:
		tick += 1
		a.apply_state({"tick": tick, "state": S.STATE_MOVE})
		_run(a, 1)
	match steps:
		"windup_early", "windup_late", "strike_snap", "strike_out", "strike_back":
			var n := 15 if steps == "windup_early" else (43 if steps == "windup_late" else 48)
			for k in n:
				tick += 1
				a.apply_state(
					{"tick": tick, "state": S.STATE_WINDUP, "windup": float(k + 1) / 48.0}
				)
				_run(a, 1)
			if steps.begins_with("strike"):
				var active := 3 if steps == "strike_snap" else 9
				for k in active:
					tick += 1
					a.apply_state({"tick": tick, "state": S.STATE_ACTIVE})
					_run(a, 1)
				if steps == "strike_back":
					for k in 22:  # out of ACTIVE: the hold, then part of the ease back
						tick += 1
						a.apply_state({"tick": tick, "state": S.STATE_RECOVER})
						_run(a, 1)
		"flinch", "calm":
			a.flinch(Vector2(1.0, 0.4), 1.0)
			_run(a, 3)
		"knock":
			a.flinch(Vector2(1.0, 0.4), 1.0, 1.0)
			_run(a, 3)
		"flash":
			a.show_hit(true, Color.WHITE, 1.6)
		"tint":
			a.show_hit(true, Color(1.0, 0.45, 0.1), 1.2)
	ViewPrefs.reduced_motion = false


func _run(a: HordeAvatar, frames: int) -> void:
	for k in frames:
		a.advance(DT)
		a.advance_flinch(DT)


func _finish() -> void:
	var lines: PackedStringArray = []
	lines.append("vat sheet: old (left) vs VAT (right), %dx%d px each, msaa 4x" % [CELL.x, CELL.y])
	lines.append("state | max channel diff (0-255) | pixels off by > 8 | share")
	for p: Array in _pairs:
		var a := (p[1] as SubViewport).get_texture().get_image()
		var b := (p[2] as SubViewport).get_texture().get_image()
		a.convert(Image.FORMAT_RGBA8)
		b.convert(Image.FORMAT_RGBA8)
		var worst := 0
		var off := 0
		for y in a.get_height():
			for x in a.get_width():
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				var d := roundi(
					maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) * 255.0
				)
				worst = maxi(worst, d)
				if d > 8:
					off += 1
		lines.append(
			(
				"%s | %d | %d | %.4f"
				% [p[0], worst, off, float(off) / float(a.get_width() * a.get_height())]
			)
		)
	var sheet := root.get_texture().get_image()
	var png := ProjectSettings.globalize_path(_dir + "vat_sheet.png")
	sheet.save_png(png)
	var text := "\n".join(lines) + "\n"
	print(text)
	print("sheet: " + png)
	var f := FileAccess.open(
		ProjectSettings.globalize_path(_dir + "vat_diff.txt"), FileAccess.WRITE
	)
	if f != null:
		f.store_string(text)
		f.close()
	quit(0)
