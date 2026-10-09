extends SceneTree
## v0.6.0 Step UP screenshots (needs a renderer, not --headless): the UI polish in the real game. The HUD's slot
## keys ("LMB" / "Clic izq."), the phase banner turned to Spanish on a live language switch, the shrine stats and
## threat panels (Ember stone on the HUD, Cold glass on the pause screen) and every Options section in en and es.
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json XDG_DATA_HOME=<empty dir> timeout 300 \
##     xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/ui_polish.gd
## (repeat with --resolution 1280x720; the files carry the window size). Writes to build/shots/v0.5.5/polish/:
##   ui_polish_hud_<lang>_<w>x<h>.png      - a run from the menu (Enter, Enter), posed by the script (a tool, not a
##                                           test: HP at 72 %, Overclock heat at Hot, Blink granted, two shrine
##                                           stats won, two curses held, the hero can't be hurt); English first,
##                                           then the language switched to Spanish while the banner shows;
##   ui_polish_pause_<lang>_<w>x<h>.png    - the pause menu opened with Esc over that run;
##   ui_polish_options_<section>_<lang>_<w>x<h>.png - Options opened from the pause menu (Down, Down, Enter), each
##                                           section reached with Down from the sidebar;
##   ui_polish_pause_switched_es_<w>x<h>.png - back in the pause menu after Spanish was chosen in its Options;
##   ui_polish_hud_build_<lang>_<w>x<h>.png - back in the run, the six modifier slots filled through the dev panel's
##                                           DebugApi (the six ability modifiers, as tests/e2e/test_e2e_swap.gd does):
##                                           the build row's pips on its slab;
##   ui_polish_swap_<lang>_<w>x<h>.png     - a seventh modifier granted (DebugApi.grant_mod): the Swap panel.
## Evidence copies are made by hand.

const OUT := "res://build/shots/v0.5.5/polish/"
const HEAT := 58
## Wall-clock cap (ms): the script quits by itself before a `timeout 300` would kill it.
const LIMIT_MS := 285000
const SIX: Array[StringName] = [
	&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field", &"frost_nova", &"flame_trail"
]

var _main: Main
var _frame := 0
var _size := ""
## The frame the run started on (-1 until then).
var _base := -1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("polish: renderer=%s" % RenderingServer.get_current_rendering_method())
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if Time.get_ticks_msec() > LIMIT_MS or (_base < 0 and _frame > 600):
		print("polish: stopped at frame %d (time or start limit); shots so far are kept" % _frame)
		quit(2)  # always ends: a slow software renderer never leaves it running
		return true
	if _main.driver == null and _base >= 0:
		print("polish: the run ended early at frame %d" % _frame)
		quit(3)
		return true
	if _size.is_empty():
		var s := root.get_window().size
		_size = "%dx%d" % [s.x, s.y]
	if _frame == 10 or _frame == 20:
		_tap(KEY_ENTER)  # Play, then Blade
	if _main.driver != null and _base < 0:
		_base = _frame  # the run has started (a software renderer may take a while)
	if _base < 0:
		return false
	if _main.driver != null:
		_main.driver.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
		var w := _main.driver.world
		if _frame - _base > 20 and w.heat != null:
			w.heat.milli = HEAT * HeatTable.MILLI  # shot setup: hold the heat at Hot
			w.heat.idle = 0
	match _frame - _base:
		20:
			_pose()
		80:
			_shot("hud_en")
			print("polish: banner en = '%s'" % _main._hud.phase_hud.announcement())
			TranslationServer.set_locale("es")
		110:
			print("polish: banner es = '%s'" % _main._hud.phase_hud.announcement())
			_shot("hud_es")
			_tap(KEY_ESCAPE)
		150:
			_shot("pause_es")
			_tap(KEY_ESCAPE)
			TranslationServer.set_locale("en")
		160:
			_tap(KEY_ESCAPE)
		200:
			_shot("pause_en")
		202, 204:
			_tap(KEY_DOWN)  # to Options
		206:
			_tap(KEY_ENTER)
		250:
			_shot("options_audio_en")
			TranslationServer.set_locale("es")
		280:
			_shot("options_audio_es")
			_tap(KEY_DOWN)  # Display
		310:
			_shot("options_display_es")
			TranslationServer.set_locale("en")
		340:
			_shot("options_display_en")
			_tap(KEY_DOWN)  # Controls
		370:
			_shot("options_controls_en")
			TranslationServer.set_locale("es")
		400:
			_shot("options_controls_es")
			_tap(KEY_DOWN)  # Accessibility
		430:
			_shot("options_accessibility_es")
			TranslationServer.set_locale("en")
		460:
			_shot("options_accessibility_en")
			_tap(KEY_DOWN)  # Language
		490:
			_shot("options_language_en")
			TranslationServer.set_locale("es")
		520:
			_shot("options_language_es")  # Spanish chosen while the pause menu is open
			_tap(KEY_ESCAPE)  # out of Options (the focus is on the category), back to the pause menu
		570:
			_shot("pause_switched_es")  # its run line and panels worded again
			TranslationServer.set_locale("en")
			_main.close_pause()  # shot setup: back to the run
		590:
			_tap(KEY_QUOTELEFT)  # the dev panel (its DebugApi grants at a tick boundary)
		600:
			_grant_six()
		630:
			_tap(KEY_QUOTELEFT)
		660:
			_shot("hud_build_en")
			TranslationServer.set_locale("es")
		690:
			_shot("hud_build_es")
			_tap(KEY_QUOTELEFT)
		700:
			if _main.driver.debug != null:
				_main.driver.debug.grant_mod()  # a seventh modifier: the Swap opens
		710:
			_tap(KEY_QUOTELEFT)
		750:
			_shot("swap_es")
			TranslationServer.set_locale("en")
		780:
			_shot("swap_en")
			print("polish: swap open %s" % _main._hud.swap.is_open())
			quit(0)
	return false


## Fills the six modifier slots with the six ability modifiers (as the MX2 e2e does through the dev panel).
func _grant_six() -> void:
	var debug := _main.driver.debug
	if debug == null:
		print("polish: no dev panel")
		return
	var w := _main.driver.world
	for id: StringName in SIX:
		for i in w.ability_tables.size():
			if w.ability_tables[i].id == id:
				debug.ability_choice = i
				debug.grant_ability()
	print("polish: queued %d modifiers" % SIX.size())


func _pose() -> void:
	var w := _main.driver.world
	if w.heat == null:
		var repo := ContentRepository.load_all()
		Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	w.heat.milli = HEAT * HeatTable.MILLI
	w.heat.idle = 0
	for i in w.ability_tables.size():
		if w.ability_tables[i].kind == AbilityTable.Kind.BLINK:
			Abilities.grant(w, i)
	if Gamble.present(w):
		Gamble.grant(w, GambleTable.Stat.MELEE)
		Gamble.grant(w, GambleTable.Stat.MAX_HP)
	for c in mini(2, w.ev.curses.size()):
		Curses.add(w, c)
	w.actors.hp[0] = w.actors.max_hp[0] * 72 / 100
	print(
		(
			"polish: posed hp %d / %d, abilities %d, gamble %s, curses %d"
			% [
				w.actors.hp[0],
				w.actors.max_hp[0],
				w.ability_owned.size(),
				Gamble.present(w),
				w.curses_owned.size()
			]
		)
	)


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "ui_polish_" + shot_name + "_" + _size + ".png"
	img.save_png(path)
	print("polish: ", path)


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
