extends SceneTree
## G2 "Rooms" mockup (v0.5.9 PLAN L8, step 7): themed rooms built from vignettes, laid by hand the way the
## generator would lay them, drawn by the game's own StageView, StageDresser and StageKit (look B), with the hero
## for scale. Not generated: these are the proposals the owner picks from before the generator changes.
## Spacing rule (keeps today's mobility): a vignette either touches a wall or keeps EDGE (2.6 m) from it, and
## vignettes keep the slab gap (2.2 m) between them; pieces inside one vignette touch.
## Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mock_rooms.gd
## Writes build/shots/<version>/rooms/<n>_<theme>.png.

const HALF := Vector2(11.0, 8.0)
const WALL := 1.2
## Doorways: the left wall's middle and the top wall's right part (sim y up = the top of the room).
const DOOR_LEFT := Vector2(-1.5, 1.5)
const DOOR_TOP := Vector2(3.0, 6.0)
const SETTLE := 40

## Each theme: its biome, then its vignettes' boxes [piece, x0, y0, x1, y1] (sim metres, blocking) and decoration
## [piece, x, y, scale]. Comments name the vignette and its anchor.
const THEMES := [
	{
		"name": "scrapyard",
		"biome": &"ruins",
		"boxes":
		# Corners: a supply pile (crates in an L), a wreck with a crate, a burn barrel with a crate, a wreck
		[
			# along the left wall.
			[&"crate_stack", -11.0, -8.0, -9.8, -6.8],
			[&"crate_stack", -9.8, -8.0, -8.6, -6.8],
			[&"crate_stack", -11.0, -6.8, -9.8, -5.6],
			[&"car_wreck", 6.6, -8.0, 11.0, -6.0],
			[&"crate_stack", 9.8, -6.0, 11.0, -4.8],
			[&"fire_barrel", 10.3, 7.3, 11.0, 8.0],
			[&"crate_stack", 9.1, 6.8, 10.3, 8.0],
			[&"car_wreck", -11.0, 3.8, -9.0, 8.0],
			# Walls: barricades (a low broken wall, a crate at its end) and a slab pair.
			[&"wall_broken", -4.5, -8.0, -1.0, -7.4],
			[&"crate_stack", -1.0, -8.0, 0.2, -6.8],
			[&"slab_wide", 10.0, -1.6, 11.0, 1.6],
			[&"wall_broken", -6.5, 7.4, -3.0, 8.0],
			# Free: a crate, a second wreck, a crate.
			[&"crate_stack", -4.6, -1.6, -3.4, -0.4],
			[&"car_wreck", 2.4, -4.0, 6.4, -2.0],
			[&"crate_stack", 0.0, 2.6, 1.2, 3.8],
		],
		"decor":
		[
			[&"debris_low", 9.0, 6.4, 1.0],
			[&"debris_low", 1.8, -1.4, 1.1],
			[&"rubble_small", -2.6, -1.0, 0.9],
		],
	},
	{
		"name": "ruined_hall",
		"biome": &"ruins",
		"boxes":
		[
			# A collapsed wall stub off the top wall, a pillar at its end.
			[&"wall_1m", -8.0, 4.6, -6.8, 8.0],
			[&"wall_pillar", -8.2, 3.2, -6.6, 4.6],
			# Pilasters against the walls.
			[&"wall_pillar", -5.0, -8.0, -3.8, -6.8],
			[&"wall_pillar", 0.0, -8.0, 1.2, -6.8],
			[&"wall_pillar", 5.0, -8.0, 6.2, -6.8],
			[&"wall_pillar", -3.0, 6.8, -1.8, 8.0],
			[&"wall_pillar", 8.6, 6.8, 9.8, 8.0],
			# Two pillar pairs framing the long lane.
			[&"slab_concrete", -2.6, -4.2, -1.4, -3.0],
			[&"slab_concrete", -2.6, 3.0, -1.4, 4.2],
			[&"slab_concrete", 3.4, -4.2, 4.6, -3.0],
			[&"slab_concrete", 3.4, 3.0, 4.6, 4.2],
			# Broken corner (an L of low walls) and fallen blocks against the side walls.
			[&"wall_broken", 8.4, -8.0, 11.0, -7.4],
			[&"wall_broken", 10.4, -7.4, 11.0, -5.0],
			[&"wall_1m", -11.0, -6.5, -9.8, -4.5],
			[&"wall_1m", 8.6, -0.6, 11.0, 0.6],
		],
		"decor":
		[
			[&"rubble_small", -6.0, 2.8, 1.2],
			[&"rubble_small", -5.4, 3.6, 0.9],
			[&"rubble_small", 1.0, 0.4, 0.8],
			[&"debris_low", 7.6, 0.0, 1.0],
		],
	},
	{
		"name": "camp",
		"biome": &"red_canyon",
		"boxes":
		[
			# The burn barrel in the middle, barricades either side.
			[&"fire_barrel", -0.4, -0.4, 0.4, 0.4],
			[&"wall_broken", -1.5, -4.3, 1.5, -3.7],
			[&"wall_broken", -1.5, 3.7, 1.5, 4.3],
			# Corners: a supply pile, crates, a wreck, a mesa block with a crate.
			[&"crate_stack", -11.0, 6.8, -9.8, 8.0],
			[&"crate_stack", -9.8, 6.8, -8.6, 8.0],
			[&"crate_stack", -11.0, 5.6, -9.8, 6.8],
			[&"crate_stack", 9.8, -8.0, 11.0, -6.8],
			[&"crate_stack", 8.6, -8.0, 9.8, -6.8],
			[&"car_wreck", -11.0, -8.0, -7.0, -6.0],
			[&"rock_large", 9.4, 6.4, 11.0, 8.0],
			[&"crate_stack", 8.2, 6.8, 9.4, 8.0],
			# A mesa block against the right wall; crates and a rock around the fire.
			[&"rock_large", 9.4, -0.8, 11.0, 0.8],
			[&"crate_stack", -6.0, -0.6, -4.8, 0.6],
			[&"rock_large", 4.6, -1.0, 6.2, 0.6],
		],
		"decor":
		[
			[&"debris_low", 1.0, 0.9, 0.8],
			[&"debris_low", -1.1, -0.9, 0.8],
			[&"rubble_small", 1.0, -1.0, 0.7],
			[&"rubble_small", -1.0, 1.0, 0.7],
		],
	},
	{
		"name": "overgrown",
		"biome": &"night_rocks",
		"boxes":
		[
			# Outcrops (a large rock and a dead tree) in every corner.
			[&"rock_large", -11.0, 6.2, -9.2, 8.0],
			[&"dead_tree", -9.2, 6.8, -8.0, 8.0],
			[&"rock_large", 9.2, -8.0, 11.0, -6.2],
			[&"dead_tree", 8.0, -8.0, 9.2, -6.8],
			[&"rock_large", 9.4, 6.2, 11.0, 8.0],
			[&"dead_tree", -11.0, -8.0, -9.8, -6.8],
			[&"rock_large", -9.8, -8.0, -8.0, -6.4],
			# Free outcrops and rocks; a lone tree on the top wall; a rock on the right wall.
			[&"rock_large", 2.4, -2.6, 4.2, -0.8],
			[&"dead_tree", 4.2, -2.2, 5.2, -1.2],
			[&"rock_large", -5.0, 1.6, -3.4, 3.2],
			[&"dead_tree", -3.0, 7.0, -2.0, 8.0],
			[&"rock_large", 9.4, -1.0, 11.0, 0.6],
			# A shrine: two slabs framing a gap on the bottom wall.
			[&"slab_concrete", -5.6, -8.0, -4.4, -7.0],
			[&"slab_concrete", -2.6, -8.0, -1.4, -7.0],
		],
		"decor":
		[
			[&"rubble_small", -3.5, -6.4, 0.9],
			[&"rubble_small", 0.6, 4.0, 0.8],
		],
	},
]

var _frame := 0
var _theme := -1
var _wait := 0
var _dir := ""
var _scene: Node3D


func _initialize() -> void:
	_dir = "res://build/shots/%s/rooms/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func _process(_delta: float) -> bool:
	_frame += 1
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var path := _dir + "%d_%s.png" % [_theme + 1, THEMES[_theme]["name"]]
			root.get_texture().get_image().save_png(path)
			print("mock_rooms: ", path)
		return false
	_theme += 1
	if _theme >= THEMES.size():
		quit(0)
		return false
	_build(THEMES[_theme])
	_wait = SETTLE
	return false


func _build(theme: Dictionary) -> void:
	if _scene != null:
		_scene.queue_free()
	_scene = Node3D.new()
	root.add_child(_scene)
	var biome: BiomeDefinition = load("res://data/biomes/%s.tres" % theme["biome"])
	var stage := StageView.new()
	stage.palette = biome.palette
	stage.mood = biome.mood
	stage.prop_style = biome.id
	_scene.add_child(stage)
	stage._build_environment()
	stage._build_light()
	var room := Rect2(-HALF, HALF * 2.0)
	stage._ground_rects = [room.grow(WALL)] as Array[Rect2]
	stage._build_room_ground()
	# Structural walls (with the two doorways cut), then the vignettes' boxes.
	var walls: Array = []
	for b: Array in _structure():
		walls.append(_box(b[0], b[1], b[2], b[3], 0, &""))
	for b: Array in theme["boxes"]:
		walls.append(_box(b[1], b[2], b[3], b[4], 1, b[0]))
	for w: Array in walls:
		stage.wall_specs.append([w[0], w[1], w[2], 1.0 if w[3] == 0 else 1.8])
		stage._wall_classes.append(w[3])
	stage._build_contact_shadows()
	var doors: Array = [
		Rect2(-HALF.x - WALL, DOOR_LEFT.x, WALL, DOOR_LEFT.y - DOOR_LEFT.x),
		Rect2(DOOR_TOP.x, HALF.y, DOOR_TOP.y - DOOR_TOP.x, WALL),
	]
	var placements := (
		StageDresser
		. dress(
			{
				"walls": walls,
				"rooms": [room],
				"start_room": 0,
				"doors": doors,
				"keep_clear": [],
				"biome": biome.id,
				"seed": 4242 + _theme,
			}
		)
	)
	for d: Array in theme["decor"]:
		var size := Vector3(0.6, 0.25, 0.6) * float(d[3])
		if d[0] == &"grass_tuft":
			size = Vector3(0.5, 0.4, 0.5) * float(d[3])
		elif d[0] == &"debris_low":
			size = Vector3(0.8, 0.2, 0.4) * float(d[3])
		var basis := Basis(Vector3.UP, float(d[1] * 1.7 + d[2])) * Basis.from_scale(size)
		placements.append(
			{
				"piece": d[0],
				"xform": Transform3D(basis, SimPlane.to_3d(Vector2(d[1], d[2]))),
				"wall": -1,
				"kind": &"decor"
			}
		)
	var kit := StageKit.new()
	stage.add_child(kit)
	kit.build(placements, stage.wall_specs.size(), biome.palette["cover"], biome.mood)
	stage.kit = kit
	# The hero for scale, with its light, by the left doorway.
	var hero := Node3D.new()
	hero.position = SimPlane.to_3d(Vector2(-7.5, -2.2))
	_scene.add_child(hero)
	var avatar := PlayerAvatar.new()
	avatar.setup(biome.palette["outline"])
	hero.add_child(avatar)
	var glow := StageKit.hero_light(biome.mood)
	if glow != null:
		hero.add_child(glow)
	var rig := IsoRig.new()
	rig.view_size = 21.0
	rig.dead_zone_m = 1.0e6
	_scene.add_child(rig)
	rig.snap_to(Vector3(0.5, 0, 0.0))
	var ink := InkPass.new()
	rig.camera.add_child(ink)
	ink.position = Vector3(0, 0, -1)
	ink.set_style(InkPass.style_from_setting("ink"))


## The room's four walls, the doorways cut out: [x0, y0, x1, y1].
func _structure() -> Array:
	var x0 := -HALF.x - WALL
	var x1 := HALF.x + WALL
	var y0 := -HALF.y - WALL
	var y1 := HALF.y + WALL
	return [
		[x0, y0, x1, -HALF.y],  # bottom
		[HALF.x, -HALF.y, x1, HALF.y],  # right
		[x0, HALF.y, DOOR_TOP.x, y1],  # top, left of the doorway
		[DOOR_TOP.y, HALF.y, x1, y1],  # top, right of the doorway
		[x0, -HALF.y, -HALF.x, DOOR_LEFT.x],  # left, below the doorway
		[x0, DOOR_LEFT.y, -HALF.x, HALF.y],  # left, above the doorway
	]


## A dresser wall entry from corners: [center, half, yaw, kind, piece].
func _box(x0: float, y0: float, x1: float, y1: float, kind: int, piece: StringName) -> Array:
	var c := Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
	return [c, Vector2(absf(x1 - x0), absf(y1 - y0)) * 0.5, 0.0, kind, piece]
