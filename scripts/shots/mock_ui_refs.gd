extends SceneTree
## v0.10.5 W3-O13b G2, round 2 (owner, 2026-11-04, after round 1: "the new UIs you built are ugly … we should discard
## all these childish rounded gradient boxes … i am attaching some mock up UI references … build something that goes
## into that style line … the objective is to achieve something layered, structured, polished … the hp bar should be
## a continuous bar not split in parts, it should be like the fourth picture 'runic observatory'. make 4 new mock
## ups."): four UI styles, one after each reference in docs/roadmap/v0.10.5/ui_refs/, drawn over the real game frame
## on the shop (layout A), the in-run HUD, the pause menu with its options panel, the altar's pick of three, plus a
## strip of each style's parts. A prototype for the owner to pick from, not game code (the kit is in
## scripts/shots/mock_ui2/). Every word is an existing translated key. Round 1's plumbing (mock_ui_styles.gd): the
## stage run, the real shop opened with E, the game's own CanvasLayers hidden.
## Needs a renderer (not --headless); open it off screen:
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/mock_ui_refs.gd
##   (-- --styles=slate,astral shoots only those)
## Writes build/shots/v0.10.5/w3o13b/<style>_<screen>.png (en), <style>_shop_es.png, <style>_comp.png (the strip),
## <style>_sheet.png (the four screens 2 x 2 at half size, the strip under them) and compare_shops.png (the four
## shops side by side).

const OUT := "res://build/shots/v0.10.5/w3o13b/"
const STYLES: Array[String] = ["slate", "eclipse", "astral", "observatory"]
const SCREENS: Array[String] = ["hud", "shop", "pause", "pick"]
const MAX_FRAMES := 6000
const VIEW := Vector2(1920, 1080)
const STRIP_H := 200

const Screens := preload("res://scripts/shots/mock_ui2/screens.gd")
const Glass2 := preload("res://scripts/shots/mock_ui2/glass2.gd")

## The world under a menu: darkened toward the edges (alpha at the centre, at the rim).
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 col : source_color = vec4(0.02, 0.03, 0.06, 1.0);
uniform float core = 0.5;
uniform float rim = 0.82;
void fragment() {
	float d = length((UV - vec2(0.5, 0.5)) * vec2(1.6, 1.0));
	COLOR = vec4(col.rgb, mix(core, rim, smoothstep(0.2, 0.95, d)));
}
"""
## How dark each style lays the world under a menu: [centre, rim].
const DIM := {
	"slate": [0.5, 0.8],
	"eclipse": [0.5, 0.82],
	"astral": [0.62, 0.86],
	"observatory": [0.48, 0.8],
}

var _main: Main
var _frame := 0
var _step := 0
var _wait := 0
var _jobs: Array = []
var _job := 0
var _layers: Array[CanvasLayer] = []
var _styles: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("mock_ui_refs: renderer=%s" % RenderingServer.get_current_rendering_method())
	_styles = STYLES.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--styles="):
			_styles.clear()
			for s in a.trim_prefix("--styles=").split(","):
				_styles.append(s)
	for style in _styles:
		for screen in SCREENS:
			_jobs.append([style, screen, "en"])
		_jobs.append([style, "shop", "es"])
		_jobs.append([style, "comp", "en"])
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


## Waits on the game (as mock_ui_styles.gd): the stage run, its arrival, the setup, E by the shop; once it is open
## the real HUD and panel are hidden and each job is built, then shot 24 frames later.
func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > MAX_FRAMES:
		push_error("mock_ui_refs: gave up at step %d" % _step)
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
			_shot("%s_%s%s" % [j[0], j[1], "" if j[2] == "en" else "_" + j[2]], j[1] == "comp")
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
	if screen != "comp":
		_paint(_layer(80), style, "hud", data)
	if screen == "hud":
		return
	var over := _layer(90)
	var v := ColorRect.new()
	v.size = VIEW
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	mat.shader = sh
	mat.set_shader_parameter("core", DIM[style][0] + (0.12 if screen == "pick" else 0.0))
	mat.set_shader_parameter("rim", DIM[style][1])
	v.material = mat
	over.add_child(v)
	_paint(over, style, screen, data)


func _paint(layer: CanvasLayer, style: String, kind: String, data: Dictionary) -> void:
	var s := Screens.new(style, kind, data)
	var g := Glass2.new(s)
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
		"heal_full": root.tr("SHOP_HEAL_FULL"),
		"reroll_text": root.tr("SHOP_REROLL"),
		"shop_hint": root.tr("SHOP_HINT"),
		"pick_title": root.tr("PICK_TITLE_ALTAR"),
		"pick_hint": root.tr("PICK_HINT"),
		"paused": root.tr("UI_PAUSED"),
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
		"options": root.tr("UI_OPTIONS"),
		"tabs":
		[
			root.tr("UI_SECTION_AUDIO"),
			root.tr("UI_SECTION_DISPLAY"),
			root.tr("UI_SECTION_CONTROLS"),
			root.tr("UI_SECTION_ACCESSIBILITY"),
		],
		"opt_rows":
		[
			[root.tr("UI_AUDIO_MASTER"), 0.8],
			[root.tr("UI_VOLUME_MUSIC"), 0.6],
			[root.tr("UI_AUDIO_SFX"), 0.7],
			[root.tr("UI_AUDIO_AMBIENCE"), 0.5],
		],
		"shake": root.tr("UI_SHAKE"),
		"on": root.tr("UI_OPT_ON"),
		"back": root.tr("UI_BACK"),
		"comp_buttons":
		[root.tr("UI_RESUME"), root.tr("UI_OPTIONS"), root.tr("UI_CODEX"), root.tr("UI_BACK")],
		"hp": reader.player_hp(),
		"max_hp": w.actors.max_hp[0],
		"hp_text": root.tr("HUD_HP") % [reader.player_hp(), w.actors.max_hp[0]],
		"heat_text": root.tr("HUD_HEAT"),
		"vent_text": root.tr("HUD_HEAT_VENT"),
		"floor_text": root.tr("HUD_FLOOR") % [reader.floor_index(), biome],
		"time_text": root.tr("HUD_TIME") % [secs / 60, secs % 60],
		"kills_text": root.tr("HUD_KILLS") % reader.kills(),
		"danger_text": root.tr("HUD_DANGER_TIER") % 2,
		"calm_text": root.tr("PHASE_CALM"),
		"weapon_text": root.tr("ABILITY_PULSE_GUN"),
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


func _shot(shot_name: String, strip: bool) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if strip:
		img = img.get_region(Rect2i(0, 0, 1920, STRIP_H))
	var path := ProjectSettings.globalize_path(OUT + shot_name + ".png")
	img.save_png(path)
	print("mock_ui_refs: shot ", path)


## One sheet per style (hud, shop / pause, pick at half size, the strip under them) and the four shops side by side.
func _sheets() -> void:
	for style in _styles:
		var sheet := Image.create(1920, 1080 + STRIP_H, false, Image.FORMAT_RGB8)
		for k in SCREENS.size():
			var img := _half(style + "_" + SCREENS[k])
			if img != null:
				sheet.blit_rect(img, Rect2i(0, 0, 960, 540), Vector2i((k % 2) * 960, (k / 2) * 540))
		var strip := _load(style + "_comp")
		if strip != null:
			sheet.blit_rect(strip, Rect2i(0, 0, 1920, STRIP_H), Vector2i(0, 1080))
		_save(sheet, style + "_sheet")
	var cmp := Image.create(960 * STYLES.size(), 540, false, Image.FORMAT_RGB8)
	for k in STYLES.size():
		var img := _half(STYLES[k] + "_shop")
		if img != null:
			cmp.blit_rect(img, Rect2i(0, 0, 960, 540), Vector2i(k * 960, 0))
	_save(cmp, "compare_shops")


func _load(shot_name: String) -> Image:
	var path := ProjectSettings.globalize_path(OUT + shot_name + ".png")
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(path)


func _half(shot_name: String) -> Image:
	var img := _load(shot_name)
	if img == null:
		return null
	img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	return img


func _save(img: Image, shot_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT + shot_name + ".png")
	img.save_png(path)
	print("mock_ui_refs: sheet ", path)
