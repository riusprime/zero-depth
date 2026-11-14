extends SceneTree
## Shots of kill shards lying on the floor: drops of each size (two, three and four gems) turning slowly
## over a grey floor, lit by one sun, under the game's iso angle, then one taken and pulled into the hero.
## The same frames in two trees compare the drops' look pixel for pixel. Needs a renderer, off screen, at a
## fixed 60 fps:
##   godot --path . --fixed-fps 60 --resolution 960x540 --windowed \
##     --position -10000,-10000 -s scripts/shots/shard_drops.gd -- --out=build/shots/shard_drops
## --diff=<dir a>,<dir b> compares the shots of two runs instead (pixels that differ by more than 2/255 in a
## channel, and the largest channel difference) and prints a line per frame. Writes only under the given folder.

const FRAMES := [4, 20, 60, 63, 65, 67, 69, 72]
## [place, shards]: 1 shard is a drop of two gems, 4 of three, 8 of four.
const DROPS := [
	[Vector2(-2.5, -1.5), 1],
	[Vector2(0, -2), 4],
	[Vector2(2.5, -1.5), 8],
	[Vector2(-2, 1.5), 8],
	[Vector2(0.5, 2), 1],
	[Vector2(3, 1.5), 4],
]
const LAY_AT := 2
## The hero steps next to the last drop on this frame and takes it.
const TAKE_AT := 62
const TAKE_FROM := Vector2(3.5, 2.5)

var _out := "build/shots/shard_drops"
var _frame := 0
var _shards: ShardViews
var _w: World
var _r: WorldReader


func _initialize() -> void:
	var diff := ""
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("out="):
			_out = s.trim_prefix("out=")
		elif s.begins_with("diff="):
			diff = s.trim_prefix("diff=")
	if not diff.is_empty():
		_diff(diff.split(","))
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true  # The drops' crystals cast a shadow; the shots check it too
	stage.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(20, 20)
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.38)
	ground.material_override = mat
	stage.add_child(ground)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.5
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(8, 9.5, 8), Vector3(0.5, 0.2, 0.0))
	_shards = ShardViews.new()
	stage.add_child(_shards)
	if _shards.has_method(&"prepare"):  # The shapes built before the first drop, as a floor's load does
		_shards.call(&"prepare")


func _process(_delta: float) -> bool:
	_frame += 1
	if _w == null:
		_w = CombatLab.world()
		_r = WorldReader.new(_w)
		_w.actors.set_pos(0, Vector2(-6, 6))  # Away from every drop until it takes one
		_shards.sync(_r)
	if _frame == LAY_AT:
		for d: Array in DROPS:
			ShardDrops.drop(_w, d[0], d[1])
	if _frame == TAKE_AT:
		_w.actors.set_pos(0, TAKE_FROM)
		_w.step(InputFrame.new())
	_shards.sync(_r)
	if FRAMES.has(_frame):
		var img := root.get_texture().get_image()
		img.save_png("%s/drops_%02d.png" % [_out, _frame])
		print(
			(
				"shard_drops: frame %d, %d drops, %d pulled"
				% [_frame, _shards.drop_count(), _shards.pulled_count()]
			)
		)
	if _frame >= FRAMES.max():
		quit(0)
		return true
	return false


func _diff(dirs: PackedStringArray) -> void:
	for f: int in FRAMES:
		var a := Image.load_from_file("%s/drops_%02d.png" % [dirs[0], f])
		var b := Image.load_from_file("%s/drops_%02d.png" % [dirs[1], f])
		if a == null or b == null or a.get_size() != b.get_size():
			print("shard_drops diff: frame %d missing or a different size" % f)
			continue
		var differ := 0
		var largest := 0
		var violet := 0
		for y in a.get_height():
			for x in a.get_width():
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				var d := maxi(maxi(absi(ca.r8 - cb.r8), absi(ca.g8 - cb.g8)), absi(ca.b8 - cb.b8))
				largest = maxi(largest, d)
				if d > 2:
					differ += 1
				if ca.b > ca.g + 0.15:
					violet += 1
		print(
			(
				"shard_drops diff: frame %d, %d of %d pixels differ, largest %d/255, %d violet pixels in the first"
				% [f, differ, a.get_width() * a.get_height(), largest, violet]
			)
		)
