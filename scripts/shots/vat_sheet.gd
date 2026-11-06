extends SceneTree
## v0.10.5 W3-V1 (the enemy VAT pilot, G2: the owner judges the tolerance): one sheet of the pilot kind (the Swarmer) in
## each state it can show, the old path (its pieces as nodes, left) beside VAT (VatCrowd's MultiMesh, right), each pair
## driven by the very same calls (apply_state / advance / flinch / show_hit, as ActorViews and HitFeel make them) and
## drawn in two identical little worlds (iso camera, a sun, a floor, the proxy shadow). Also prints and writes, per
## state, how far the two images differ (max channel difference and the share of pixels off by more than 8 / 255).
## Needs a renderer (NOT --headless); off screen:
##   APPDATA=<temp> godot --path . --resolution 1920x1080 --position -10000,-10000 -s scripts/shots/vat_sheet.gd
## Writes build/shots/<version>/vat/vat_sheet.png and vat_diff.txt.
## v0.10.5 W3-V4b: `-- --kind=<name>` (splitter, splitling, shield_bearer, mender, mine_layer, sniper; swarmer the
## default) draws that kind in its own states (KIND_PLANS: the walk, the death, the heal, the mine dropped, the muzzle)
## into vat_sheet_<name>.png and vat_diff_<name>.txt; `--version-dir=<v>` writes under build/shots/<v>/vat/.

const CELL := Vector2i(220, 220)
const COLS := 4
const DT := 1.0 / 60.0
const KINDS := {
	"swarmer": WorldReader.KIND_SWARMER,
	"splitter": WorldReader.KIND_SPLITTER,
	"splitling": WorldReader.KIND_SPLITLING,
	"shield_bearer": WorldReader.KIND_SHIELD_BEARER,
	"mender": WorldReader.KIND_MENDER,
	"mine_layer": WorldReader.KIND_MINE_LAYER,
	"sniper": WorldReader.KIND_SNIPER,
}
const CAST := {"tint": Color(0.45, 0.65, 1.0, 0.5), "role": 0.45}
## v0.10.5 W3-V4b: the other kinds' states (the Swarmer's: PLAN).
const KIND_PLANS := {
	"melee_model":
	[
		["idle", {}, "idle"],
		["walking", {}, "walk"],
		["windup 31 %", {}, "windup_early"],
		["windup 90 % (flash)", {}, "windup_late"],
		["strike snap (0.05 s)", {}, "strike_snap"],
		["strike out (0.15 s)", {}, "strike_out"],
		["strike easing back", {}, "strike_back"],
		["death, 0.1 s in", {}, "death_early"],
		["death, 0.3 s in", {}, "death_late"],
		["flinch at its peak", {}, "flinch"],
		["Blade knock", {}, "knock"],
		["hit flash", {}, "flash"],
		["status tint (burn)", {}, "tint"],
		["rise-in, half way", {}, "spawn"],
		["biome cast + role glow", CAST, "idle"],
		["reduced motion + flinch", {}, "calm"],
	],
	"mender":
	[
		["idle", {}, "idle"],
		["idle, 1.3 s later", {}, "idle_late"],
		["walking (floats)", {}, "walk"],
		["healing", {}, "heal"],
		["healing, later", {}, "heal_late"],
		["death, 0.1 s in", {}, "death_early"],
		["death, 0.3 s in", {}, "death_late"],
		["flinch at its peak", {}, "flinch"],
		["Blade knock", {}, "knock"],
		["hit flash", {}, "flash"],
		["status tint (burn)", {}, "tint"],
		["rise-in, half way", {}, "spawn"],
		["biome cast + role glow", CAST, "idle"],
		["reduced motion + flinch", {}, "calm"],
	],
	"mine_layer":
	[
		["idle", {}, "idle"],
		["windup 31 % (hopper lowers)", {}, "windup_early"],
		["windup 90 %", {}, "windup_late"],
		["mine dropped (active)", {}, "strike_snap"],
		["active, 0.15 s", {}, "strike_out"],
		["recovering (mine back)", {}, "strike_back"],
		["flinch at its peak", {}, "flinch"],
		["Blade knock", {}, "knock"],
		["hit flash", {}, "flash"],
		["status tint (burn)", {}, "tint"],
		["rise-in, half way", {}, "spawn"],
		["biome cast + role glow", CAST, "idle"],
		["reduced motion + flinch", {}, "calm"],
	],
	"sniper":
	[
		["idle", {}, "idle"],
		["windup 31 % (muzzle)", {}, "windup_early"],
		["windup 90 % (flash)", {}, "windup_late"],
		["shot (0.05 s)", {}, "strike_snap"],
		["shot (0.15 s)", {}, "strike_out"],
		["easing back", {}, "strike_back"],
		["flinch at its peak", {}, "flinch"],
		["Blade knock", {}, "knock"],
		["hit flash", {}, "flash"],
		["status tint (burn)", {}, "tint"],
		["rise-in, half way", {}, "spawn"],
		["biome cast + role glow", CAST, "idle"],
		["reduced motion + flinch", {}, "calm"],
	],
}
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
var _kind := WorldReader.KIND_SWARMER
var _name := "swarmer"
var _pairs: Array = []  # [label, live SubViewport, vat SubViewport]
var _frame := 0


func _initialize() -> void:
	var version := GameVersion.label()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			_name = arg.trim_prefix("--kind=")
		elif arg.begins_with("--version-dir="):
			version = arg.trim_prefix("--version-dir=")
	_kind = KINDS[_name]
	_dir = "res://build/shots/%s/vat/" % version
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var grid := GridContainer.new()
	grid.columns = COLS
	root.add_child(grid)
	var plan: Array = PLAN
	match _name:
		"splitter", "splitling", "shield_bearer":
			plan = KIND_PLANS["melee_model"]
		"mender", "mine_layer", "sniper":
			plan = KIND_PLANS[_name]
	for spec: Array in plan:
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
	cam.size = 1.15
	var look := Vector3(0.15, 0.12, 0)
	if _kind != WorldReader.KIND_SWARMER:  # v0.10.5 W3-V4b: framed to the kind's height
		var h := HordeAvatar.height_of(_kind)
		cam.size = maxf(1.15, h * 1.7)
		look = Vector3(0.0, h * 0.5, 0)
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
	a.setup(_kind, Color("#1A1A22"))
	facing.add_child(a)
	a.set_process(false)
	if vat:
		var crowd := VatCrowd.new()
		scene.add_child(crowd)
		crowd.add(actor, facing, a, Color("#1A1A22"), true)
	else:
		EnemyShadows.apply(actor, facing, a, _kind, 0.25, "proxy")
	_drive(a, steps, actor)
	if vat:
		print(
			(
				"%s: lift %.3f m, raise %.2f, strike %.2f"
				% [steps, a.vat_lift(), a.windup_pose(), a.strike_pose()]
			)
		)
	return vp


## The calls a state is made of (both avatars of a pair get the same ones).
func _drive(a: HordeAvatar, steps: String, actor: Node3D) -> void:
	var tick := 0
	if steps == "spawn":  # spawned sunk, then half risen (2.5 a second)
		a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN})
		_run(a, 2)
		for k in 12:
			a.apply_state({"tick": 1 + k, "state": WorldReader.STATE_MOVE})
			_run(a, 1)
		return
	if steps == "calm":
		ViewPrefs.reduced_motion = true
	a.apply_state({"tick": tick, "state": WorldReader.STATE_MOVE})
	var idle := 82 if steps == "scuttle" else (138 if steps in ["idle_late", "heal_late"] else 60)
	var healing := steps.begins_with("heal")
	for k in idle:
		tick += 1
		a.apply_state({"tick": tick, "state": WorldReader.STATE_MOVE, "healing": healing})
		_run(a, 1)
	match steps:
		"walk":  # v0.10.5 W3-V4b: the actor walks 1.6 m/s (the models' stride comes from how fast they move)
			actor.position.x = -0.4
			for k in 30:
				tick += 1
				a.apply_state({"tick": tick, "state": WorldReader.STATE_MOVE})
				actor.position.x += 1.6 * DT
				_run(a, 1)
		"death_early", "death_late":
			a.die()
			_run(a, 6 if steps == "death_early" else 18)
		"windup_early", "windup_late", "strike_snap", "strike_out", "strike_back":
			var n := 15 if steps == "windup_early" else (43 if steps == "windup_late" else 48)
			for k in n:
				tick += 1
				a.apply_state(
					{"tick": tick, "state": WorldReader.STATE_WINDUP, "windup": float(k + 1) / 48.0}
				)
				_run(a, 1)
			if steps.begins_with("strike"):
				var active := 3 if steps == "strike_snap" else 9
				for k in active:
					tick += 1
					a.apply_state({"tick": tick, "state": WorldReader.STATE_ACTIVE})
					_run(a, 1)
				if steps == "strike_back":
					for k in 22:  # out of ACTIVE: the hold, then part of the ease back
						tick += 1
						a.apply_state({"tick": tick, "state": WorldReader.STATE_RECOVER})
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


## v0.10.5 W3-V4b: the largest distance (m) between the old avatar's posed vertices and the VAT one's, the shader's
## arithmetic run on the CPU (VatBake.eval_vertices_at) at the drives it was drawn with; a hidden piece is skipped.
func _vertex_error(live_vp: SubViewport, vat_vp: SubViewport) -> float:
	var live := live_vp.find_children("*", "HordeAvatar", true, false)[0] as HordeAvatar
	var vat := vat_vp.find_children("*", "HordeAvatar", true, false)[0] as HordeAvatar
	var pose := VatBake.pose_for(_kind)
	var mesh := VatBake.mesh_for(_kind, vat.enemy_tint, vat.role_glow, Color("#1A1A22"))
	var a := VatBake.live_vertices(live)
	var b := VatBake.eval_vertices_at(pose, mesh, vat.vat_drives(pose), vat.vat_offset())
	var worst := 0.0
	var k0 := 0
	for p: Dictionary in VatBake.pieces(live, VatBake.joints(live)):
		var mi: MeshInstance3D = p["node"]
		var nv := (
			(mi.mesh.surface_get_arrays(p["surface"])[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			. size()
		)
		if mi.name == EnemyShadows.PROXY_NAME:  # the old path's shadow stand-in, not the body
			continue
		if mi.is_visible_in_tree():
			for k in range(k0, k0 + nv):
				worst = maxf(worst, a[k].distance_to(b[k]))
		k0 += nv
	return worst


func _finish() -> void:
	var lines: PackedStringArray = []
	lines.append("vat sheet: old (left) vs VAT (right), %dx%d px each, msaa 4x" % [CELL.x, CELL.y])
	lines[0] += "  kind=%s (%d)" % [_name, _kind]
	var proxy := VatCrowd.shadow_mesh(_kind)  # the old path's shadow stand-in (EnemyShadows), cached per kind
	lines.append(
		(
			"%s shadow proxy aabb (avatar space, m): %s (top y %.3f; the floor is y 0)"
			% [_name, proxy.get_aabb(), proxy.get_aabb().end.y]
		)
	)
	lines.append(
		"state | max channel diff (0-255) | pixels off by > 8 | share | max vertex error (mm, CPU)"
	)
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
				"%s | %d | %d | %.4f | %.3f"
				% [
					p[0],
					worst,
					off,
					float(off) / float(a.get_width() * a.get_height()),
					_vertex_error(p[1], p[2]) * 1000.0
				]
			)
		)
	var sheet := root.get_texture().get_image()
	var suffix := "" if _name == "swarmer" else "_" + _name
	var png := ProjectSettings.globalize_path(_dir + "vat_sheet%s.png" % suffix)
	sheet.save_png(png)
	var text := "\n".join(lines) + "\n"
	print(text)
	print("sheet: " + png)
	var f := FileAccess.open(
		ProjectSettings.globalize_path(_dir + "vat_diff%s.txt" % suffix), FileAccess.WRITE
	)
	if f != null:
		f.store_string(text)
		f.close()
	quit(0)
