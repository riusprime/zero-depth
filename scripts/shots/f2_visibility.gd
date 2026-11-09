extends SceneTree
## v0.11.0 F2 (owner's playtest: "Improve enemy visibility without significantly changing their designs."): the five
## new enemies on the Ruins floor (older kinds behind them, to compare) and a small crowd of each biome's critter on its
## own floor, in the real game view (WorldViewRoot with the biome's mood, look and enemy cast) of a real World. Run on a
## renderer, off screen:
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000
##     -s scripts/shots/f2_visibility.gd -- tag=after
## Writes build/shots/f2/<tag>/<case>.png and report.txt (each kind's body against the floor under it, measured on the
## render: the frame against the same frame with the enemy bodies hidden, their shadows kept). With tag=after and a
## build/shots/f2/before/ next to it, also writes pair_<case>.png (before on the left) for the Ruins and Frozen Shore
## crowds.

const CELL := Vector2i(1600, 1120)
const HERO_AT := Vector2(0.0, -6.0)
const K := ActorStore.Kind
const ROW_NEW := [K.SCRAP_HOUND, K.ROCK_LURKER, K.STONE_THROWER, K.KILN_BEETLE, K.CINDER_PRIEST]
const ROW_OLD := [K.CHARGER, K.SPLITTER, K.ARC_CASTER, K.SHIELD_BEARER]
## [case, biome, critter kind (-1: the enemies' line-up)].
const PLAN := [
	["new_enemies_ruins", &"ruins", -1],
	["critters_ruins", &"ruins", K.DUST_MITE],
	["critters_night_rocks", &"night_rocks", K.CAVE_BAT],
	["critters_red_canyon", &"red_canyon", K.EMBER_FLEA],
	["critters_frozen_shore", &"frozen_shore", K.ICE_CRAB],
	["critters_starfall", &"starfall", K.STAR_MOTE],
]
const PAIRS := ["critters_ruins", "critters_frozen_shore"]
const CROWD := 10
const TICKS := 100
## Real seconds for the frame-time poses to settle; frames for a hidden body to leave the picture.
const SETTLE_S := 1.0
const HIDE_FRAMES := 3
## A pixel belongs to a body when any channel moved by more than this (of 255).
const MASK_DELTA := 6
## The body's value is taken at this share of its pixels from the darkest: past the dark outline, on the lit body.
const BODY_Q := 0.7
## The line-up's zoomed contact sheet (a working image: new kinds on top, older ones below).
const ZOOM_W := 232
const ZOOM_H := 256

var _tag := "after"
var _dir := ""
var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _ids: Array[int] = []
var _spots: Array[Vector2] = []
var _k := 0
var _t := 0
var _settle := -1.0
var _hidden := -1
var _shown: Image
var _lines: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.trim_prefix("tag=")
	_dir = "res://build/shots/f2/%s/" % _tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build(0)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	_world = StageScenario.build(
		31 + k, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_world.actors.set_pos(0, HERO_AT)
	_world.actors.invuln[0] = 1 << 24
	_ids.clear()
	_spots.clear()
	if spec[2] < 0:
		for i in ROW_NEW.size():
			_ids.append(_world.add_enemy(ROW_NEW[i], Vector2(-5.0 + 2.5 * i, -3.5)))
		for i in ROW_OLD.size():
			_ids.append(_world.add_enemy(ROW_OLD[i], Vector2(-3.75 + 2.5 * i, 0.0)))
	else:
		for i in CROWD:
			var at := Vector2(float((i * 7) % 5) - 2.0, float((i * 3) % 4) * 1.1 - 1.5)
			_ids.append(_world.add_enemy(spec[2], at + Vector2(0.17 * (i % 3), 0.0)))
	for id in _ids:
		_spots.append(_world.actors.pos(_world.actors.index_of(id)))
	var biome: BiomeDefinition = _repo.get_def(&"biomes", spec[1])
	_view = WorldViewRoot.new()
	_view.stage.prop_style = biome.id
	_view.stage.mood = biome.mood
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_vp.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.actors.cull = null  # (the off-screen rig never marks the bodies seen)
	if spec[2] < 0:
		_view.rig.view_size = 14.0
		_view.rig.camera.size = 14.0
	_view.rig.snap_to(SimPlane.to_3d(Vector2(0.0, 0.6 if spec[2] < 0 else -1.2)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_t = 0
	_settle = -1.0
	_hidden = -1


func _process(delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _t < TICKS:
		_world.actors.set_pos(0, HERO_AT)
		for n in _ids.size():  # (held in place: the line-up stays a line)
			var i := _world.actors.index_of(_ids[n])
			if i >= 0:
				_world.actors.set_pos(i, _spots[n])
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, 0))
		_view.sync()
		_t += 1
		_settle = SETTLE_S
		return false
	if _settle > 0.0:
		_settle -= delta
		return false
	if _hidden < 0:
		_shown = _grab()
		_shown.save_png(_dir + "%s.png" % spec[0])
		print("f2: ", ProjectSettings.globalize_path(_dir + "%s.png" % spec[0]))
		_set_bodies(_view.actors, false)
		_hidden = HIDE_FRAMES
		return false
	_hidden -= 1
	if _hidden > 0:
		return false
	_measure(spec, _grab())
	_k += 1
	if _k == PLAN.size():
		_finish()
		return true
	_build(_k)
	return false


func _grab() -> Image:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Shows or hides every crowd's body draw, the shadows left alone.
func _set_bodies(n: Node, on: bool) -> void:
	for c in n.get_children():
		if c is MultiMeshInstance3D and String(c.name).contains("Bodies"):
			(c as MultiMeshInstance3D).visible = on
		_set_bodies(c, on)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _y(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lstar(y: float) -> float:
	return 903.3 * y if y <= 0.008856 else 116.0 * pow(y, 1.0 / 3.0) - 16.0


## The value at share `q` (0..1) of the sorted values.
func _quantile(vals: Array, q: float) -> float:
	vals.sort()
	return float(vals[int((vals.size() - 1) * q)]) if not vals.is_empty() else 0.0


## The body's lit luminance (BODY_Q) and the floor's median under it inside `rect`.
func _sample(shown: Image, bare: Image, rect: Rect2i) -> Array:
	var part := _collect(shown, bare, rect)
	return [_quantile(part[0], BODY_Q), _quantile(part[1], 0.5), (part[0] as Array).size()]


## The luminances of the pixels a body covers in `rect`, and of the floor under them.
func _collect(shown: Image, bare: Image, rect: Rect2i) -> Array:
	var body: Array = []
	var floor_y: Array = []
	var r := rect.intersection(Rect2i(Vector2i.ZERO, CELL))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var a := shown.get_pixel(x, y)
			var b := bare.get_pixel(x, y)
			var moved := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			if moved * 255.0 > MASK_DELTA:
				body.append(_y(a))
				floor_y.append(_y(b))
	return [body, floor_y]


func _measure(spec: Array, bare: Image) -> void:
	var cam := _view.rig.camera
	if spec[2] < 0:
		var zoom := Image.create(ZOOM_W * 5, ZOOM_H * 2, false, Image.FORMAT_RGBA8)
		for n in _ids.size():
			var i := _world.actors.index_of(_ids[n])
			var p := cam.unproject_position(SimPlane.to_3d(_world.actors.pos(i)))
			var rect := Rect2i(Vector2i(p) - Vector2i(58, 96), Vector2i(116, 128))
			_row(WorldReader.body_kind(_world.actors.kinds[i]), _sample(_shown, bare, rect))
			var cell := _shown.get_region(rect.intersection(Rect2i(Vector2i.ZERO, CELL)))
			cell.resize(ZOOM_W, ZOOM_H, Image.INTERPOLATE_NEAREST)
			zoom.blit_rect(
				cell, Rect2i(0, 0, ZOOM_W, ZOOM_H), Vector2i(n % 5 * ZOOM_W, n / 5 * ZOOM_H)
			)
		zoom.save_png(_dir + "zoom_new_enemies.png")
	else:
		var all := [[], []]
		for id in _ids:
			var i := _world.actors.index_of(id)
			var p := cam.unproject_position(SimPlane.to_3d(_world.actors.pos(i)))
			var rect := Rect2i(Vector2i(p) - Vector2i(26, 34), Vector2i(52, 52))
			var part := _collect(_shown, bare, rect)
			all[0].append_array(part[0])
			all[1].append_array(part[1])
		_row(spec[2], [_quantile(all[0], BODY_Q), _quantile(all[1], 0.5), all[0].size()])


func _row(kind: int, s: Array) -> void:
	var by: float = s[0]
	var fy: float = s[1]
	var hi := maxf(by, fy)
	var lo := minf(by, fy)
	_lines.append(
		(
			"%s kind=%s body_L*=%.1f floor_L*=%.1f dL*=%.1f contrast=%.2f pixels=%d"
			% [
				String(PLAN[_k][0]),
				ActorStore.Kind.find_key(kind),
				_lstar(by),
				_lstar(fy),
				absf(_lstar(by) - _lstar(fy)),
				(hi + 0.05) / (lo + 0.05),
				int(s[2])
			]
		)
	)
	print(_lines[_lines.size() - 1])


func _finish() -> void:
	var f := FileAccess.open(_dir + "report.txt", FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	if _tag == "before":
		return
	for c: String in PAIRS:
		var a := Image.load_from_file("res://build/shots/f2/before/%s.png" % c)
		var b := Image.load_from_file(_dir + "%s.png" % c)
		if a == null or b == null:
			continue
		var out := Image.create(CELL.x * 2 + 8, CELL.y, false, Image.FORMAT_RGBA8)
		out.fill(Color.BLACK)
		out.blit_rect(a, Rect2i(Vector2i.ZERO, CELL), Vector2i.ZERO)
		out.blit_rect(b, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x + 8, 0))
		out.save_png(_dir + "pair_%s.png" % c)
		print("f2: ", ProjectSettings.globalize_path(_dir + "pair_%s.png" % c))
