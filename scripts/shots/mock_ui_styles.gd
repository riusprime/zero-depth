extends SceneTree
## v0.10.5 W3-O13 G2 (owner, 2026-11-04: "For the shop I like mock up A, in shape, but colors and how it shows still
## ugly, the brown background, buttons are not visible, it doesn't quite match the rune ethereal kind of theme of the
## game … can you make 3 new mockups that would also apply to the rest of UI elements"): three UI styles, each drawn
## over the real game frame on four screens (the shop in layout A's shape, the in-run HUD, the pause menu, the card
## pick of three). A prototype for the owner to pick from, not game code: every piece is drawn here with CanvasItem
## calls (the game's own font, item and ability icons, element glyphs, the Futhark rune strokes, the shard), plus two
## small shaders made in code (the glass blur, the sigil vignette). Every word is an existing translated key.
## Needs a renderer (not --headless); open it off screen:
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/mock_ui_styles.gd
## Writes build/shots/v0.10.5/w3o13/<style>_<screen>.png (en), <style>_shop_es.png, <style>_sheet.png (the four
## screens 2 x 2) and styles_compare.png (the three shops side by side). The stage run (Main.STAGE_SEED) is the fixed
## seed, so the stock is the same each time; the HUD's heat and danger values are set for the shot.

const OUT := "res://build/shots/v0.10.5/w3o13/"
const STYLES: Array[String] = ["veil", "obsidian", "sigil"]
const SCREENS: Array[String] = ["hud", "shop", "pause", "pick"]
const MAX_FRAMES := 6000
const VIEW := Vector2(1920, 1080)

const UiScreens := preload("res://scripts/shots/mock_ui/ui_screens.gd")
const Glass := preload("res://scripts/shots/mock_ui/glass.gd")

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 core : source_color = vec4(0.0, 0.02, 0.03, 0.66);
uniform vec4 rim : source_color = vec4(0.0, 0.01, 0.02, 0.9);
void fragment() {
	float d = length((UV - vec2(0.5, 0.5)) * vec2(1.7, 1.0));
	COLOR = mix(core, rim, smoothstep(0.15, 0.95, d));
}
"""

var _main: Main
var _frame := 0
var _step := 0
var _wait := 0
var _jobs: Array = []
var _job := 0
var _layers: Array[CanvasLayer] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("mock_ui_styles: renderer=%s" % RenderingServer.get_current_rendering_method())
	for style in STYLES:
		for screen in SCREENS:
			_jobs.append([style, screen, "en"])
		_jobs.append([style, "shop", "es"])
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


## Waits on the game (as mock_shop.gd): the stage run, its arrival, the setup, E by the shop; once it is open the real
## HUD and panel are hidden and each job is built, then shot 24 frames later.
func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > MAX_FRAMES:
		push_error("mock_ui_styles: gave up at step %d" % _step)
		quit(1)
		return false
	var dr := _main.driver
	if dr == null:
		if _frame == 3:
			_main.start_stage()
		return false
	dr.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
	_wait -= 1
	if _wait > 0:
		return false
	match _step:
		0:
			if dr.reader.arriving():
				return false
			var w := dr.world
			w.shards = 120  # shot setup: enough to afford most of the stock
			w.actors.hp[0] = w.actors.max_hp[0] / 2
			w.actors.set_pos(0, ShopPlacement.front(w.floor_layout) + Vector2(0.4, 0.4))
			_next(50)
		1:
			_tap(KEY_E)
			_next(10)
		2:
			if not dr.reader.shop_open():
				_tap(KEY_E)
				_wait = 20
				return false
			for cl in _main.find_children("*", "CanvasLayer", true, false):  # the real HUD, hints and cards
				(cl as CanvasLayer).visible = false
			_next(20)
		3:
			_build(_jobs[_job])
			_next(24)
		4:
			var j: Array = _jobs[_job]
			_shot("%s_%s%s" % [j[0], j[1], "" if j[2] == "en" else "_" + j[2]])
			_job += 1
			if _job < _jobs.size():
				_step = 3
				_wait = 1
			else:
				_sheets()
				quit(0)
	return false


func _next(frames: int) -> void:
	_step += 1
	_wait = frames


func _clear() -> void:
	for l in _layers:
		l.queue_free()
	_layers.clear()


func _layer(n: int) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.layer = n
	root.add_child(l)
	_layers.append(l)
	return l


func _build(job: Array) -> void:
	_clear()
	var style: String = job[0]
	var screen: String = job[1]
	TranslationServer.set_locale(job[2])
	var data := _gather()
	var hud := _layer(80)
	_paint(hud, style, "hud", data)
	if screen == "hud":
		return
	var over := _layer(90)
	match style:
		"sigil":
			var v := ColorRect.new()
			v.size = VIEW
			var mat := ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = VIGNETTE_SHADER
			mat.shader = sh
			v.material = mat
			over.add_child(v)
		_:
			var dim := ColorRect.new()
			dim.color = (
				Color(0.0, 0.01, 0.03, 0.5) if style == "veil" else Color(0.0, 0.0, 0.0, 0.62)
			)
			dim.size = VIEW
			over.add_child(dim)
	_paint(over, style, screen, data)


func _paint(layer: CanvasLayer, style: String, kind: String, data: Dictionary) -> void:
	var s := UiScreens.new(style, kind, data)
	if style == "veil":
		var g := Glass.new(s)
		g.size = VIEW
		layer.add_child(g)
	layer.add_child(s)


## Everything the screens show, read once per job (the language may have changed): the sim's shop, the HUD's values,
## and the translated words.
func _gather() -> Dictionary:
	var reader := _main.driver.reader
	var w := _main.driver.world
	var s := reader.shop()
	var faces: Array = []
	var prices: Array = []
	var ok: Array = []
	for c: Dictionary in s["stock"]:
		faces.append(PickPanel.card_face(root, reader, int(c["code"])) if not c["sold"] else {})
		prices.append(int(c["price"]))
		ok.append(bool(c["affordable"]))
	var secs := int(reader.run_seconds())
	var biome := root.tr("BIOME_NIGHT_ROCKS")
	var weapon := reader.weapon_id()
	var slots := [
		[&"combo_sword" if weapon == &"combo_sword" else &"pulse_gun", "shoot"],
		[&"skill", "skill"],
		[&"dash", "dash"],
	]
	for sl: Array in slots:
		sl[1] = AbilitySquares.glyph_text(StringName(sl[1]), false)
	return {
		"faces": faces,
		"prices": prices,
		"ok": ok,
		"wallet": reader.shards(),
		"buys_left": int(s["buys_left"]),
		"max_buys": int(s["max_buys"]),
		"heal_price": int(s["heal_price"]),
		"reroll_price": int(s["reroll_price"]),
		"buys_text": root.tr("SHOP_BUYS_LEFT") % int(s["buys_left"]),
		"shop_title": root.tr("SHOP_TITLE"),
		"heal_text": root.tr("SHOP_HEAL") % int(s["heal_amount"]),
		"reroll_text": root.tr("SHOP_REROLL"),
		"shop_hint": root.tr("SHOP_HINT"),
		"pick_title": root.tr("PICK_TITLE_ALTAR"),
		"pick_hint": root.tr("PICK_HINT"),
		"paused": root.tr("UI_PAUSED"),
		"pause_hint": root.tr("UI_PAUSE_HINT"),
		"pause_items":
		[
			root.tr("UI_RESUME"),
			root.tr("UI_BUILD"),
			root.tr("UI_RESTART_RUN"),
			root.tr("UI_OPTIONS"),
			root.tr("UI_CODEX"),
			root.tr("UI_MAIN_MENU"),
		],
		"run_line":
		(
			root.tr("UI_PAUSE_RUN")
			% [reader.floor_index(), secs / 60, secs % 60, reader.kills(), reader.shards()]
		),
		"hp": reader.player_hp(),
		"max_hp": w.actors.max_hp[0],
		"hp_text": root.tr("HUD_HP") % [reader.player_hp(), w.actors.max_hp[0]],
		"heat_text": root.tr("HUD_HEAT"),
		"vent_text": root.tr("HUD_HEAT_VENT"),
		"floor_text": root.tr("HUD_FLOOR") % [reader.floor_index(), biome],
		"biome_text": biome,
		"time_text": root.tr("HUD_TIME") % [secs / 60, secs % 60],
		"kills_text": root.tr("HUD_KILLS") % reader.kills(),
		"danger_text": root.tr("HUD_DANGER_TIER") % 2,
		"calm_text": root.tr("PHASE_CALM"),
		"weapon_text": root.tr("ABILITY_PULSE_GUN").to_upper(),
		"slots": slots,
	}


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _shot(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(OUT + shot_name + ".png")
	img.save_png(path)
	print("mock_ui_styles: shot ", path)


## One 2 x 2 sheet per style (hud, shop / pause, pick at half size) and the three shops side by side.
func _sheets() -> void:
	for style in STYLES:
		var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
		for k in SCREENS.size():
			var img := _half(style + "_" + SCREENS[k])
			if img != null:
				sheet.blit_rect(img, Rect2i(0, 0, 960, 540), Vector2i((k % 2) * 960, (k / 2) * 540))
		_save(sheet, style + "_sheet")
	var cmp := Image.create(2880, 540, false, Image.FORMAT_RGB8)
	for k in STYLES.size():
		var img := _half(STYLES[k] + "_shop")
		if img != null:
			cmp.blit_rect(img, Rect2i(0, 0, 960, 540), Vector2i(k * 960, 0))
	_save(cmp, "styles_compare")


func _half(shot_name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(OUT + shot_name + ".png"))
	if img == null:
		return null
	img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	return img


func _save(img: Image, shot_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT + shot_name + ".png")
	img.save_png(path)
	print("mock_ui_styles: sheet ", path)
