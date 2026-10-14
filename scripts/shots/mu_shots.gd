extends SceneTree
## v0.8.0 MU (G2, owner O14): the shared driver of the three menu-and-card mockup scripts (mock_main_menu.gd,
## mock_pick.gd, mock_build.gd extend it). It boots main.tscn with an empty profile and no save, sets the run seed to
## the first seed from Main.STAGE_SEED whose first floor is the Ruins (the look reference's biome; a fixed seed), starts
## a Blade run (Enter, Enter), poses floor 3's wand of eight cards (as scripts/shots/wand_build.gd), lets the floor run
## a few seconds, pauses with Esc and hides the pause menu. It then grabs that paused frame once and holds it as a still
## under the UI (the 3D world stops drawing: software GL takes seconds a frame), and for each direction (MuKit: A
## Salvage, B Ember stone, C Field kit) and each language (en, es) lays the screen's mockup over it and saves a shot.
## A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1920x1080 -s scripts/shots/mock_<main_menu|pick|build>.gd
## Writes build/shots/v0.8.0/mu/<a_salvage|b_ember_stone|c_field_kit>_<screen>_<en|es>.png. Evidence copies are made
## by hand.

const Kit := preload("res://scripts/shots/mu_kit.gd")
const OUT := "res://build/shots/v0.8.0/mu/"
## Floor 3's eight-slot wand (two triggers), as the v0.7.0 Build page shots.
const EIGHT: Array[StringName] = [
	&"ember_edge",
	&"trigger_on_hit",
	&"long_edge",
	&"twin_arc",
	&"trigger_on_kill",
	&"serrated_edge",
	&"wide_arc",
	&"echo_slash",
]
const LANGS := ["en", "es"]
## Wall-clock budget, and how long the floor runs before the pause (ms; the start-of-floor banners fade by then).
const LAST_MS := 1_500_000
const RUN_MS := 7000
const SETTLE := 6

var _main: Main
var _frame := 0
var _base := -1
var _base_ms := 0
var _paused_at := -1
var _frozen := false
var _shot := -1
var _wait := 0
var _overlay: Control
var _still: CanvasLayer


## The screen's file-name part ("main_menu", "pick", "build") and its caption.
func _screen() -> String:
	return ""


func _screen_caption() -> String:
	return ""


## Whether the game's HUD stays in the still under the mockup (the pick panel opens over it; the menus cover it).
func _keep_hud() -> bool:
	return false


## The mockup of direction `dir` (MuKit.Dir) over the game; strings through tr() in the locale set now.
func _build(_dir: int) -> Control:
	return Control.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("mu: renderer=%s" % RenderingServer.get_current_rendering_method())
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	var s := ruins_seed()
	_main.set(&"_stage_seed", s)
	print("mu: run seed %d" % s)


## The first run seed from Main.STAGE_SEED whose first floor is the Ruins (RunState's own biome order).
static func ruins_seed() -> int:
	var run_def: RunDefinition = ContentRepository.load_all().get_def(&"run", Main.RUN_ID)
	var table := ContentCompiler.compile_run(run_def)
	for k in 200:
		var r := RunState.start(Main.STAGE_SEED + k, table, &"blade")
		if run_def.biomes[r.biome_of(1)] == &"ruins":
			return Main.STAGE_SEED + k
	return Main.STAGE_SEED


func _process(_delta: float) -> bool:
	_frame += 1
	if Time.get_ticks_msec() > LAST_MS:
		print("mu: gave up at frame %d" % _frame)
		quit(1)
		return true
	if _frame == 10 or _frame == 20:
		_tap(KEY_ENTER)  # Play, then Blade
	if _main.driver != null and _base < 0:
		_base = _frame
		_base_ms = Time.get_ticks_msec()
	if _base < 0:
		return false
	if _paused_at < 0:
		_run_floor()
	elif not _frozen:
		_freeze()
	elif _wait > 0:
		_wait -= 1
		if _wait == 0:
			_grab()
	else:
		_next_shot()
	return false


## Before the pause: the hero can't be hurt, the wand is posed, and after RUN_MS (and 30 frames) Esc pauses the sim.
func _run_floor() -> void:
	_main.driver.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
	if _frame == _base + 1:
		_pose()
	if _frame > _base + 30 and Time.get_ticks_msec() - _base_ms > RUN_MS:
		_tap(KEY_ESCAPE)  # pause: the sim stops under the mockup
		_paused_at = _frame


func _next_shot() -> void:
	_shot += 1
	if _shot >= 3 * LANGS.size():
		print("mu: done")
		quit(0)
		return
	_show(_shot / LANGS.size(), LANGS[_shot % LANGS.size()])
	_wait = SETTLE


## A few frames after the pause: hides the pause menu (and the HUD for the menus), grabs the frame, then holds it as a
## still under the UI and stops the 3D world drawing.
func _freeze() -> void:
	var since := _frame - _paused_at
	if since == 2:
		for c in _main.ui.get_children():
			if c is PauseMenu or not _keep_hud():
				(c as CanvasItem).visible = false
		_hide_transients()
	if since < 6:
		return
	_hide_transients()
	var img := root.get_texture().get_image()
	_still = CanvasLayer.new()
	_still.layer = _main.ui.layer - 1
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(img)
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_still.add_child(tex)
	root.add_child(_still)
	for c in _main.ui.get_children():
		(c as CanvasItem).visible = false
	root.disable_3d = true
	_frozen = true


## The banners that come and go at a floor's start (the floor card, a new enemy's name, an achievement toast): hidden
## so the still shows the HUD at rest.
func _hide_transients() -> void:
	for n in _main.find_children("*", "", true, false):
		if n is AchievementToast or n is PhaseHud:
			n.process_mode = Node.PROCESS_MODE_DISABLED  # so it doesn't show itself again
			(n as CanvasItem).visible = false
		var card: Variant = n.get(&"_floor_card")
		if card is CanvasItem:
			(card as CanvasItem).visible = false


func _show(dir: int, lang: String) -> void:
	TranslationServer.set_locale(lang)
	if _overlay != null:
		_overlay.queue_free()
	_overlay = _build(dir)
	_overlay.add_child(Kit.caption(dir, _screen_caption()))
	_main.ui.add_child(_overlay)


func _grab() -> void:
	var dir := _shot / LANGS.size()
	var lang: String = LANGS[_shot % LANGS.size()]
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s_%s.png" % [Kit.SLUGS[dir], _screen(), lang]
	img.save_png(path)
	print("mu: ", path, " ", img.get_size())


func _pose() -> void:
	var w := _main.driver.world
	w.floor_index = 3  # shot setup: floor 3's eight slots (the wand counts the run's floor)
	w.run_floor = 3
	for id: StringName in EIGHT:
		var k := item_index(w, id)
		if k >= 0:
			BuildSlots.take(w, k)
	print("mu: posed %d cards in %d slots" % [w.mod_slots.size(), Wand.slots(w)])


static func item_index(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


static func ability_index(w: World, id: StringName) -> int:
	for k in w.ability_tables.size():
		if w.ability_tables[k].id == id:
			return k
	return -1


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
