extends SceneTree
## Checks that the HUD drawn from HudStill's textures looks the same as drawn directly: boots the real game
## (main.tscn), sets up a scene, pauses the sim, and in the same frame-still scene captures the screen with the HUD's
## textures on, then off (every part drawn directly each frame, as before HudStill), then on again; and the same pair
## with the 3D off (the HUD over the plain clear colour). The tree is paused and the clock stopped for the captures.
## Reports, per pair, how many pixels differ and the largest difference of a channel (0-255), over the whole screen
## and per HUD part. The on / on-again pair is the noise floor: what still moves behind the HUD.
## Needs a renderer, off screen:
##   godot --path . --position -10000,-10000 -s scripts/checks/hud_still_diff.gd -- --scene=fight|run
##     [--size=1600x900] [--ui=110]
## Writes the shots and the report under build/shots/hud_still/ (never into docs) and prints the report.

const OUT := "res://build/shots/hud_still/"
const SEED := 4404
const FIGHT_TICKS := 240
const ENEMIES := 20
## Frames from a switch to a capture (a part freezes on its second still frame).
const WAIT := 8
const BUILD_KEYS: Array[StringName] = [
	&"ITEM_GUN_GLAIVE", &"ITEM_GUN_RING", &"ITEM_SPLIT_SHOT", &"ITEM_EMBER_CORE", &"ITEM_STORM_CORE"
]
const HEAVY_KEYS: Array[StringName] = [
	&"ITEM_GUN_TWIN",
	&"ITEM_HALO_SHOT",
	&"ITEM_GUN_RAPID_FIRE",
	&"ITEM_WILDFIRE",
	&"ITEM_CHAIN_BLAST",
	&"ITEM_GUN_RUNE_EXPLOSION",
]

var _scene := "fight"
var _size := Vector2i(1920, 1080)
var _ui := 100
var _main: Main
var _frame := 0
var _phase := 0
var _t0 := 0
var _shots := {}
var _frozen_names: PackedStringArray = []
var _lines: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("scene="):
			_scene = s.trim_prefix("scene=")
		elif s.begins_with("size="):
			var p := s.trim_prefix("size=").split("x")
			_size = Vector2i(int(p[0]), int(p[1]))
		elif s.begins_with("ui="):
			_ui = int(s.trim_prefix("ui="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(_size)
	root.size = _size
	root.content_scale_factor = _ui / 100.0
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "en"
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _tag() -> String:
	return "%s_%dx%d_ui%d" % [_scene, _size.x, _size.y, _ui]


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 6000:
		push_error("hud_still_diff: stuck in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frame == 3:
				if _scene == "fight":
					_main._start_playground(&"gun", &"red_canyon")
				else:
					_main._stage_seed = SEED
					_main.start_stage()
				_phase = 1
				_frame = 0
		1:
			if _frame == 5:
				root.content_scale_factor = _ui / 100.0  # after the settings the game applies at boot
			if _frame == 10:
				if _scene == "fight":
					_setup_fight()
				else:
					_pose_run()
				_t0 = _main.driver.world.tick
				_phase = 2
		2:
			var w := _main.driver.world
			if _scene == "fight":
				_aim(Vector2(960, 540) + Vector2(cos(_frame * 0.02), sin(_frame * 0.02)) * 320.0)
				if _frame % 60 == 0:
					_top_up()
			else:
				_pose_run()
			if w.tick >= _t0 + FIGHT_TICKS - 4:
				w.dash_cooldown_left = _main.driver.reader.dash_cooldown_total() / 2  # a cooldown running in the shot
			var ready := (
				w.tick >= _t0 + FIGHT_TICKS
				and _main._hud.visible
				and not _main.loads.cover.showing()
			)
			if ready:
				_press_fire(false)
				_main.driver.paused = true
				_main.view.rig.snap_to(SimPlane.to_3d(w.player_pos()))
				# Everything behind the HUD holds still too (particles, animations, shaders on the clock), and the
				# notice ticker (not a HudStill part, it fades on its own clock) is hidden.
				paused = true
				Engine.time_scale = 0.0
				_main._hud.notices.visible = false
				_phase = 3
				_frame = 0
		3:
			return _captures()
	return false


## The captures, WAIT frames apart: textures on, off, on again; then the same pair with the 3D off.
func _captures() -> bool:
	var still: HudStill = _main._hud.still
	match _frame:
		WAIT:
			for r in still.roots():
				if still.frozen(r):
					_frozen_names.append(String(r.name))
			_shots["on"] = _grab("on")
			still.set_enabled(false)
		WAIT * 2:
			_shots["off"] = _grab("off")
			still.set_enabled(true)
		WAIT * 3:
			_shots["on_again"] = _grab("on_again")
			root.disable_3d = true
		WAIT * 4:
			_shots["on_no3d"] = _grab("on_no3d")
			still.set_enabled(false)
		WAIT * 5:
			_shots["off_no3d"] = _grab("off_no3d")
			root.disable_3d = false
			paused = false
			Engine.time_scale = 1.0
			_report()
			quit(0)
			return true
	return false


func _grab(n: String) -> Image:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s.png" % [_tag(), n]
	img.save_png(path)
	_lines.append("shot: " + ProjectSettings.globalize_path(path))
	return img


func _report() -> void:
	var sha := ""
	var git: Array = []
	if OS.execute("git", ["rev-parse", "--short", "HEAD"], git) == 0 and git.size() > 0:
		sha = String(git[0]).strip_edges()
	var out: PackedStringArray = [
		"hud_still_diff  sha=%s  scene=%s  window=%s  ui_scale=%d%%" % [sha, _scene, _size, _ui],
		"adapter=%s" % RenderingServer.get_video_adapter_name(),
		"parts frozen at the 'on' capture: %s" % ", ".join(_frozen_names),
	]
	var regions := _part_regions()
	for pair: Array in [["on", "off"], ["on", "on_again"], ["on_no3d", "off_no3d"]]:
		var a: Image = _shots[pair[0]]
		var b: Image = _shots[pair[1]]
		var whole := _diff(a, b, Rect2i(Vector2i.ZERO, a.get_size()))
		out.append(
			(
				"%s vs %s: whole screen %d px differ, max channel diff %d"
				% [pair[0], pair[1], whole[0], whole[1]]
			)
		)
		for n: String in regions:
			var d := _diff(a, b, regions[n])
			if d[0] > 0:
				out.append("    %s %s: %d px differ, max %d" % [n, regions[n], d[0], d[1]])
	out.append_array(_lines)
	var text := "\n".join(out) + "\n"
	print(text)
	var f := FileAccess.open(OUT + "%s_report.txt" % _tag(), FileAccess.WRITE)
	f.store_string(text)


## Each registered part's screen rect (its items' rects grown by HudStill.MARGIN).
func _part_regions() -> Dictionary:
	var still: HudStill = _main._hud.still
	var out := {}
	var final := root.get_final_transform()
	var screen := Rect2i(Vector2i.ZERO, _size)
	for r in still.roots():
		var box := Rect2()
		var first := true
		var stack: Array[Node] = [r]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is Control and (n as Control).is_visible_in_tree():
				var g := (n as Control).get_global_rect()
				if n == r and g.size.x >= 1900.0:
					continue
				box = g if first else box.merge(g)
				first = false
		if first:
			continue
		box = box.grow(HudStill.MARGIN)
		var lo := Vector2i((final * box.position).floor())
		var hi := Vector2i((final * box.end).ceil())
		out[String(r.name)] = Rect2i(lo, hi - lo).intersection(screen)
	return out


## [pixels that differ, the largest channel difference] inside `r`.
static func _diff(a: Image, b: Image, r: Rect2i) -> Array:
	var n := 0
	var mx := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if ca != cb:
				n += 1
				mx = maxi(
					mx, maxi(absi(ca.r8 - cb.r8), maxi(absi(ca.g8 - cb.g8), absi(ca.b8 - cb.b8)))
				)
	return [n, mx]


func _setup_fight() -> void:
	var api: PlaygroundApi = _main.playground.api
	api.god = true
	for e: Dictionary in api.catalog():
		if BUILD_KEYS.has(e["name_key"]):
			api.grant_now(e["code"], 3)
		elif HEAVY_KEYS.has(e["name_key"]):
			api.grant_now(e["code"], 5)
	_top_up()
	_press_fire(true)


## A run's first room, posed as the HUD shots pose it: shards, three items, Hot heat, full HP.
func _pose_run() -> void:
	var w := _main.driver.world
	w.actors.invuln[0] = 1 << 24
	w.shards = 147
	if w.heat == null:
		var repo := ContentRepository.load_all()
		Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	w.heat.milli = 58 * HeatTable.MILLI
	w.heat.idle = 0
	Heat.advance(w)
	if w.items_owned.is_empty():
		for k in 3:
			w.add_item(k)


func _top_up() -> void:
	var api: PlaygroundApi = _main.playground.api
	var w := _main.driver.world
	var a := w.actors
	var alive := 0
	for i in a.ids.size():
		if a.teams[i] == ActorStore.TEAM_ENEMY and a.dead[i] == 0 and a.hp[i] > 0:
			alive += 1
	var kinds := api.enemy_choices()
	var p := w.player_pos()
	var tries := 0
	while not kinds.is_empty() and alive < ENEMIES and tries < 80:
		tries += 1
		var ang := float(tries * 137) * 0.0174533 + float(w.tick) * 0.01
		var dist := 7.0 + float((tries * 53) % 6)
		var kind: int = kinds[(tries + alive) % kinds.size()]["kind"]
		if api.place_enemy_now(kind, p + Vector2(cos(ang), sin(ang)) * dist):
			alive += 1


func _aim(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func _press_fire(on: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = on
	ev.position = Vector2(960, 540)
	ev.global_position = ev.position
	Input.parse_input_event(ev)
