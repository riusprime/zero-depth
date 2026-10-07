extends SceneTree
## The v0.3.0 L18 shots: Overclock heat through the iso camera with the real HUD meter, one tile per state (cool,
## Hot with the VENT prompt, Overclock with embers, overheat with steam, a vent blast) plus the three heat
## item icons. Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/heat.gd
## The heat is set on the world between shots; the vent and the overheat come from real ticks (a Vent press; a
## landed swing at 99 heat). Writes build/shots/v0.3.0/heat/heat_<n>.png (full frames) and heat.png (the sheet).

const OUT := "res://build/shots/v0.3.0/heat/"
const TILE := Vector2i(560, 420)
const COLS := 3
## The crop around the hero and the meter, in window pixels (1600 x 900).
const CROP := Rect2i(400, 300, 800, 600)
const STEPS: Array = [
	["cool", 22],
	["hot", 52],
	["overclock", 88],
	["overheat", 99],
	["vent", 70],
	["items", 0],
]

var _frames := 0
var _step := 0
var _wait := 0
var _view: WorldViewRoot
var _hud: Hud
var _reader: WorldReader
var _w: World
var _caption := Label.new()
var _items := Control.new()
var _shots: Array[Image] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("heat: renderer=%s" % RenderingServer.get_current_rendering_method())
	_w = _world()
	_reader = WorldReader.new(_w)
	_view = WorldViewRoot.new()
	_view.rig.view_size = 7.0
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(_reader, Gallery.palette_of(&"night_rocks"), 10.0)
	_view.rig.snap_to(SimPlane.to_3d(Vector2(0.9, 0.0), 0.6))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	_hud = Hud.new()
	layer.add_child(_hud)
	_hud.sync(_reader)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	# UI coordinates are in the project's 1920 x 1080 base size; the crop's top left is (480, 360) there.
	_caption.position = Vector2(500, 370)
	layer.add_child(_caption)
	_build_items(layer)


func _world() -> World:
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	var w := World.new(11, t)
	var enemies := ContentCompiler.compile_enemies(repo)
	for e in enemies:
		e.speed = 0.0  # still targets: they stand and never wind up between shots
	w.set_enemy_tables(enemies)
	w.set_item_tables(ContentCompiler.compile_items(repo))
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	for at: Vector2 in [Vector2(1.3, 0.3), Vector2(2.0, -1.4), Vector2(2.6, 1.3)]:
		w.add_enemy(ActorStore.Kind.CHARGER, at)
	for i in range(1, w.actors.size()):
		w.actors.state[i] = EnemyAi.State.MOVE
		w.actors.cd[i] = 1 << 30
		w.actors.invuln[i] = 0
		w.actors.hp[i] = 9999
		w.actors.max_hp[i] = 9999
		w.actors.facing[i] = Kin.angle_of(w.player_pos() - w.actors.pos(i))
	return w


func _build_items(layer: CanvasLayer) -> void:
	_items.visible = false
	layer.add_child(_items)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1, 1.0)
	bg.position = Vector2(480, 360)
	bg.size = Vector2(960, 720)
	_items.add_child(bg)
	var x := 560.0
	for id: StringName in [&"heat_sink", &"thermal_edge", &"meltdown"]:
		var icon := ItemIconView.new(id, ItemLooks.color_of_id(id), true)
		icon.position = Vector2(x, 520)
		icon.size = Vector2(200, 200)
		_items.add_child(icon)
		var l := Label.new()
		l.text = TranslationServer.translate("ITEM_" + String(id).to_upper())
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.position = Vector2(x - 40, 740)
		l.custom_minimum_size = Vector2(280, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 28)
		_items.add_child(l)
		x += 290.0


func _f(pressed: int = 0, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, 0, 300, 0, pressed)


func _tick(f: InputFrame) -> void:
	_w.step(f)
	_view.sync()
	_hud.sync(_reader)


func _set_heat(points: int) -> void:
	_w.heat.stall = 0
	_w.heat.milli = points * HeatTable.MILLI
	_w.heat.idle = 0
	Heat.advance(_w)
	_view.sync()
	_hud.sync(_reader)


## Sets up step `_step`; returns how many frames to wait before the grab.
func _begin() -> int:
	var name: String = STEPS[_step][0]
	var heat: int = STEPS[_step][1]
	match name:
		"cool", "hot":
			_set_heat(heat)
			_caption.text = "%s  (heat %d)" % [_tier_word(), heat]
			return 6
		"overclock":
			_set_heat(heat)
			_tick(_f(InputFrame.PRIMARY))
			for k in 4:
				_tick(_f())
			_caption.text = (
				"%s  (heat %d, an Overclock hit: embers)" % [_tier_word(), Heat.points(_w)]
			)
			return 3
		"overheat":
			for k in 60:  # let the last swing end, so the press starts a new one at once
				if _w.swing_t == 0 and _w.freeze_ticks == 0:
					break
				_tick(_f())
			_set_heat(heat)
			_tick(_f(InputFrame.PRIMARY))
			for k in 14:
				_tick(_f())
			_caption.text = (
				"%s  (stalled %d / %d ticks)"
				% [_tier_word(), _w.heat.stall_total - _w.heat.stall, _w.heat.stall_total]
			)
			return 10
		"vent":
			_set_heat(heat)
			_tick(_f(InputFrame.VENT, Vector2i(-127, 0)))  # v0.3.5 K: the Vent button
			_caption.text = (
				"VENT  (Vent at heat %d: %d heat vented, %.2f m blast)"
				% [heat, _w.heat.vent_heat, _w.heat.vent_radius]
			)
			return 5
		_:
			_items.visible = true
			_caption.text = "Heat items"
			return 3
	return 3


func _tier_word() -> String:
	return _hud.heat_meter.tier_text()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	if _wait == 0:
		_wait = _frames + _begin()
		return false
	if _frames < _wait:
		return false
	var img := root.get_texture().get_image()
	img.save_png(OUT + "heat_%d.png" % _step)
	print("heat: %s %s" % [STEPS[_step][0], _reader.heat_state()])
	var crop := img.get_region(CROP)
	crop.convert(Image.FORMAT_RGB8)
	crop.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	_shots.append(crop)
	_step += 1
	_wait = 0
	if _step >= STEPS.size():
		_sheet()
		quit(0)
	return false


func _sheet() -> void:
	var rows := ceili(_shots.size() / float(COLS))
	var sheet := Image.create(TILE.x * COLS, TILE.y * rows, false, Image.FORMAT_RGB8)
	for k in _shots.size():
		var at := Vector2i((k % COLS) * TILE.x, (k / COLS) * TILE.y)
		sheet.blit_rect(_shots[k], Rect2i(Vector2i.ZERO, TILE), at)
	sheet.save_png(OUT + "heat.png")
	print("heat: ", OUT, "heat.png ", sheet.get_width(), "x", sheet.get_height())
