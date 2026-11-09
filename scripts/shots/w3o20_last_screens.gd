extends SceneTree
## v0.10.5 W3-O20: the last screens put in the Astral style, shot in the real game (main.tscn, an empty profile, no
## save), one language per run (`-- --lang=en|es`, and `720` for the 1280 x 720 set):
##   build_picker - the main menu, then (shot setup: Main.show_build_picker, the hub skipped) the start screen,
##                  settled; the padlocked Blade and the Gun;
##   run_tip      - Enter on the Gun (Right first when the Blade has the focus); the run's first floor once the hero
##                  has landed: the first-run tip under the phase line, the build pips, the vent hint;
##   boss_stack   - shot setup: the heat near the vent, the floor's first boss spawned, a phase announcement queued:
##                  the boss bar, the phase line under it, the announcement, the tip under them (the W3-O17 overlap);
##   lockdown / arena / shrine - the run paused (no tick syncs the HUD); shot setup: each banner synced from a posed
##                  reader (ShotReader: the real WorldReader with the banner's read posed), the phase line stacked;
##   panels       - the same paused HUD; shot setup: the threat panel (two curses), the gamble stats (three stats),
##                  the gamble card landed, an item card, a combo card and the training room's DPS meter, each fed by
##                  the posed reader or its own show call;
##   pause_panels - Esc: the pause menu; shot setup: the threat panel and the gamble stats added to it, as Main
##                  adds them when the run has them.
## (The hub's Training and Wardrobe panels, with their Astral cyclers: scripts/shots/w3o19_astral_pages.gd.)
## Writes build/shots/v0.10.5/w3o20/<screen>_<lang>[_720].png. A tool, not a test; it quits on every path. Needs a
## renderer (not --headless); off screen:
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/w3o20_last_screens.gd -- --lang=en

const OUT := "res://build/shots/v0.10.5/w3o20/"
const LAST_MS := 600_000

var _main: Main
var _lang := "en"
var _suffix := ""
var _frame := 0
var _step := 0
var _at := 0
var _landed := 0
var _heat_share := -1.0
var _posed: Array[Control] = []


## The real WorldReader, with the reads a shot poses (a banner's, the curses', the gamble stats') answered from `pose`.
class ShotReader:
	extends WorldReader
	var pose := {}

	func _init(world: World) -> void:
		super(world)

	func has_lockdowns() -> bool:
		return pose.has("lockdown") or super()

	func lockdown() -> Dictionary:
		return pose["lockdown"] if pose.has("lockdown") else super()

	func arenas() -> Dictionary:
		return pose["arenas"] if pose.has("arenas") else super()

	func has_shrines() -> bool:
		return pose.has("shrine") or super()

	func shrine() -> Dictionary:
		return pose["shrine"] if pose.has("shrine") else super()

	func threat() -> int:
		return int(pose.get("threat", super()))

	func curses_owned() -> PackedInt32Array:
		return pose["curses"] if pose.has("curses") else super()

	func gamble_stacks(stat: int) -> int:
		return int(pose["stacks"][stat]) if pose.has("stacks") else super(stat)

	func gamble_cap(_stat: int) -> int:
		return 5

	func gamble_bonus(stat: int) -> int:
		return gamble_stacks(stat) * 40


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
		if a == "720":
			_suffix = "_720"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("w3o20: renderer=%s lang=%s" % [RenderingServer.get_current_rendering_method(), _lang])
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if Time.get_ticks_msec() > LAST_MS:
		print("w3o20: gave up at step %d frame %d" % [_step, _frame])
		quit(1)
		return true
	var since := _frame - _at
	if _main.driver != null:
		var w := _main.driver.world
		w.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
		if _heat_share >= 0.0 and w.heat != null:
			w.heat.milli = int(w.heat.table.max_heat * HeatTable.MILLI * _heat_share)
	match _step:
		0:
			if since == 6:
				TranslationServer.set_locale(_lang)
			if since == 16:
				_main.show_build_picker()  # shot setup: the hub's walk to the portal skipped
			if since == 30:
				var picker := _picker()
				picker.settle()
				for c in picker.cards:
					c.settle()
			if since == 34:
				_shot("build_picker")
				var picker := _picker()
				var f := picker.focused_id()
				for i in picker.cards.size():
					if picker.cards[i].has_focus() and picker.cards[i].is_locked():
						_tap(KEY_RIGHT)
				print("w3o20: focus was ", f)
			if since == 40:
				_tap(KEY_ENTER)
				_next()
		1:
			if _main.driver == null or _main.driver.reader.arriving():
				return false
			_landed += 1
			if _landed == 70:
				_shot("run_tip")
			if _landed == 420:  # the floor card has gone
				_heat_share = 0.86
				var w := _main.driver.world
				w.run_ticks = SimTick.seconds_to_ticks(250.0)
				if not w.boss_tables.is_empty():
					w.spawn_boss(0, w.actors.pos(0) + Vector2(5.0, 0.0))
				var ph := _main._hud.phase_hud
				ph._queue.append(PackedStringArray(["HUD_NEW_ENEMY", "ENEMY_CHARGER"]))
				_next()
		2:
			if since == 160:
				_shot("boss_stack")
				_main.driver.paused = true  # shot setup: no tick syncs the HUD while it is posed
				_heat_share = -1.0
				var hud := _main._hud
				hud.boss_bar.visible = false
				var r := _reader()
				r.pose["lockdown"] = {
					"cleared": PackedInt32Array(),
					"forced": PackedInt32Array(),
					"sealed": 0,
					"kind": WorldReader.LOCKDOWN_HAZARD,
					"wave": 2,
					"waves": 3,
					"alive": 7,
				}
				hud.lockdown_hud.sync(r)
				hud.phase_hud.sync(r)
				hud._stack_top_centre()
			if since == 170:
				_shot("lockdown")
				var hud := _main._hud
				hud.lockdown_hud.visible = false
				var r := _reader()
				r.pose["arenas"] = {
					"active": true,
					"cleared": PackedInt32Array(),
					"sealed": 0,
					"overrun_sealed": true,
					"wave": 2,
					"waves": 4,
					"alive": 9,
					"overrun": 0,
				}
				hud.overrun_hud.sync(r)
				hud._stack_top_centre()
			if since == 180:
				_shot("arena")
				var hud := _main._hud
				hud.overrun_hud.visible = false
				var r := _reader()
				r.pose["shrine"] = {
					"used_tick": -1,
					"denied_tick": -1,
					"clear_tick": -1,
					"fountain_tick": -1,
					"fountain_denied_tick": -1,
					"kind": WorldReader.SHRINE_CHAOS,
					"chaos_phase": 1,
					"chaos_alive": 6,
					"paid": 0,
					"fountain_healed": 0,
				}
				hud.shrine_hud.sync(r)
				hud._stack_top_centre()
			if since == 190:
				_shot("shrine")
				_panels()
			if since == 210:
				_shot("panels")
				_clear_panels()
				_main.driver.paused = false
				_tap(KEY_ESCAPE)
				_next()
		3:
			if since == 14:
				var r := _reader()
				_pose_panels(r)
				var stats := GambleStatsPanel.new()  # shot setup: as Main adds them when the run has them
				_main._pause.add_child(stats)
				stats.place_top_right(84)
				stats.sync(r)
				var threat := ThreatPanel.new()
				_main._pause.add_child(threat)
				threat.place_top_left(84)
				threat.sync(r)
			if since == 30:
				_shot("pause_panels")
				return _done()
	return false


func _done() -> bool:
	print("w3o20: done")
	quit(0)
	return true


func _picker() -> BuildPicker:
	return _main.ui.get_node("BuildPicker") as BuildPicker


func _reader() -> ShotReader:
	if not _main.has_meta(&"shot_reader"):
		_main.set_meta(&"shot_reader", ShotReader.new(_main.driver.world))
	return _main.get_meta(&"shot_reader") as ShotReader


func _pose_panels(r: ShotReader) -> void:
	var w := _main.driver.world
	var n := w.ev.curses.size()
	r.pose["threat"] = 2
	r.pose["curses"] = PackedInt32Array([0, mini(2, n - 1)]) if n > 0 else PackedInt32Array()
	var stacks := []
	for s in r.gamble_stat_count():
		stacks.append(0)
	for s in [0, 2, 4]:
		if s < stacks.size():
			stacks[s] = 2 + s % 3
	r.pose["stacks"] = stacks


func _panels() -> void:
	var hud := _main._hud
	for c: CanvasItem in [hud.shrine_hud, hud.phase_hud, _main.hints, _main.toast]:
		c.visible = false  # shot setup: the panels alone over the game
	var r := _reader()
	_pose_panels(r)
	var threat := ThreatPanel.new()
	hud.add_child(threat)
	threat.place_top_left(160)
	threat.sync(r)
	var stats := GambleStatsPanel.new()
	hud.add_child(stats)
	stats.place_top_right(420)
	stats.sync(r)
	var item := ItemCard.new()
	hud.add_child(item)
	item.place_bottom_centre(-300)
	item.show_item(
		&"vampiric_core",
		tr("ITEM_VAMPIRIC_CORE"),
		tr("ITEM_VAMPIRIC_CORE_DESC"),
		ItemLooks.color_of_id(&"vampiric_core"),
		tr("HUD_PICKED_UP") if TranslationServer.get_locale() == "en" else ""
	)
	var combo := ComboCard.new()
	hud.add_child(combo)
	combo.place_bottom_centre(-460)
	combo.show_combo(
		&"blood_harvest",
		&"vampiric_core",
		&"executioner",
		tr("ITEM_COMBO_BLOOD_HARVEST"),
		tr("ITEM_COMBO_BLOOD_HARVEST_DESC"),
		""
	)
	var meter := DpsMeter.new()
	hud.add_child(meter)
	meter.sync(r)
	meter.position.y += 300.0
	_posed = [threat, stats, item, combo, meter]


func _clear_panels() -> void:
	for c in _posed:
		c.queue_free()
	_posed.clear()
	_main._hud.gamble.roll.clear()


func _next() -> void:
	_step += 1
	_at = _frame


func _shot(screen: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s%s.png" % [screen, _lang, _suffix]
	img.save_png(path)
	var f := root.gui_get_focus_owner()
	print("w3o20: ", path, " ", img.get_size(), " focus=", f.name if f != null else "-")


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
