extends SceneTree
## A sheet of the owner's sixteen room pieces (OWNER_TODO §3.6; scripts/assets/rooms_v0120_prep.py) as the kit
## loads them (KitModels: at natural size, their own colours, no biome tint), in rows by where they go: the camp's and
## the hall's, the quarry's, the Ruins' and Frozen Shore's. A 1.8 m grey capsule stands at each row's start for the
## hero's scale.
## Lit by one sun and a grey ambient, seen from the game's iso direction (yaw 45, orthographic).
## Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/room_pieces_sheet.gd
## Writes build/shots/v0.12.0/rooms/room_pieces_sheet.png. Quits on every path.

const OUT := "res://build/shots/v0.12.0/rooms/"
const ROWS := [
	[
		&"camp_tent",
		&"log_seat",
		&"cook_pot",
		&"statue_whole",
		&"statue_broken",
		&"column_round",
		&"column_drum"
	],
	[&"quarry_crane", &"mine_cart", &"stone_block", &"tool_rack"],
	[&"metal_post", &"dumpster", &"cable_spool", &"sign_frame", &"ice_floe"],
]
const GAP := 0.9
const ROW_STEP := 6.0
const SETTLE := 12

var _wait := SETTLE


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#3A3F48")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#9AA3B0")
	env.environment.ambient_light_energy = 0.6
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 40)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#7D7468")
	floor_mesh.material_override = fm
	scene.add_child(floor_mesh)
	var widest := 0.0
	for r in ROWS.size():
		var z := (r - 1) * ROW_STEP
		var x := 0.0
		var hero := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.3
		cap.height = 1.8
		hero.mesh = cap
		hero.position = Vector3(x, 0.9, z)
		scene.add_child(hero)
		x += 0.3 + GAP
		for id: StringName in ROWS[r]:
			var piece := KitModels.get_piece(id)
			if piece.is_empty():
				print("room_pieces_sheet: %s is missing" % id)
				quit(1)
				return
			var size: Vector3 = piece["size"]
			var node := MeshInstance3D.new()
			node.mesh = piece["mesh"]
			node.material_override = piece["material"]
			node.transform = Transform3D(Basis.from_scale(size), Vector3(x + size.x * 0.5, 0.0, z))
			scene.add_child(node)
			print("room_pieces_sheet: %s %.2f x %.2f x %.2f m" % [id, size.x, size.z, size.y])
			x += size.x + GAP
		widest = maxf(widest, x)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = widest * 0.62
	var centre := Vector3(widest * 0.5, 1.0, 0.0)
	var dir := Basis(Vector3.UP, deg_to_rad(45.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.0))
	cam.transform = Transform3D(dir, centre + dir * Vector3(0, 0, 40))
	scene.add_child(cam)
	cam.current = true


func _process(_delta: float) -> bool:
	_wait -= 1
	if _wait > 0:
		return false
	var path := OUT + "room_pieces_sheet.png"
	var img := root.get_texture().get_image()
	if img == null or img.save_png(path) != OK:
		push_error("room_pieces_sheet: could not save %s" % path)
		quit(1)
		return true
	print("room_pieces_sheet: ", path)
	quit(0)
	return true
