extends SceneTree
## Shots of instant shard payouts: bursts of violet gems over a grey floor, lit by one
## sun, under the game's iso angle, at fixed frames of their flight (the burst, the hang,
## the flight to the hero). The same frames in two trees compare the gems' look pixel for
## pixel. Needs a renderer, off screen, at a fixed 60 fps:
##   godot --path . --fixed-fps 60 --resolution 960x540 --windowed \
##     --position -10000,-10000 -s scripts/shots/shard_burst.gd -- --out=build/shots/shard_burst
## --diff=<dir a>,<dir b> compares the shots of two runs instead (pixels that differ by more
## than 2/255 in a channel) and prints a line per frame. Writes only under the given folder.

const FRAMES := [3, 9, 16, 24, 34, 37, 39, 41, 44, 50, 56, 80]
## [frame, place, gems]: a first wave, then a second while the first lands (new gems in
## freed places).
const BURSTS := [
	[2, Vector2(3, -1), 8],
	[2, Vector2(2.5, 2), 8],
	[2, Vector2(-2, 3), 6],
	[36, Vector2(-3, -2), 8],
	[38, Vector2(4, 1), 5],
]

var _out := "build/shots/shard_burst"
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
	cam.size = 9.0
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(8, 9.5, 8), Vector3(0.5, 0.6, 0.5))
	_shards = ShardViews.new()
	stage.add_child(_shards)


func _process(_delta: float) -> bool:
	_frame += 1
	if _w == null:
		_w = CombatLab.world()
		_r = WorldReader.new(_w)
		_shards.sync(_r)
	var me := _w.actors.ids[0]
	for b: Array in BURSTS:
		if b[0] == _frame:
			var e := _w.emit_event(SimEvent.Kind.SHARDS, me, me, me, b[1])
			e.amount = b[2]
	_shards.sync(_r)
	if FRAMES.has(_frame):
		var img := root.get_texture().get_image()
		img.save_png("%s/burst_%02d.png" % [_out, _frame])
		print("shard_burst: frame %d, %d gems in flight" % [_frame, _shards.count()])
	if _frame >= FRAMES.max():
		quit(0)
		return true
	return false


func _diff(dirs: PackedStringArray) -> void:
	for f: int in FRAMES:
		var a := Image.load_from_file("%s/burst_%02d.png" % [dirs[0], f])
		var b := Image.load_from_file("%s/burst_%02d.png" % [dirs[1], f])
		if a == null or b == null or a.get_size() != b.get_size():
			print("shard_burst diff: frame %d missing or a different size" % f)
			continue
		var differ := 0
		var violet := 0
		for y in a.get_height():
			for x in a.get_width():
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				if (
					maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b))
					> 2.0 / 255.0
				):
					differ += 1
				if ca.b > ca.g + 0.15:
					violet += 1
		print(
			(
				"shard_burst diff: frame %d, %d of %d pixels differ, %d violet pixels in the first"
				% [f, differ, a.get_width() * a.get_height(), violet]
			)
		)
