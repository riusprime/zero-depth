extends SceneTree
## v0.8.0 N8 (owner O62, D48): the reward cards dealt, flipped and reacting, on the real HUD and pick panel over a
## Gun run's world (CardPoolSurvey.world; an altar's offer forced so each tier shows), one language per run
## (`-- --lang=en` or `-- --lang=es`). A tool, not a test. Shots: the fan face down, a flip midway, the Epic wait
## (darkened background, glowing back), the Epic's flip (punch, flash, rays), a Legendary card's shine, the hover tilt,
## the burn of the cards not picked and the picked icon's flight to its HUD pip; then a chest's one card. It also
## prints the frame cost: the process time per frame (Performance.TIME_PROCESS) idle, while dealing and in the outro,
## and the draw calls; with --headless it only times (no pictures, no draw). Needs a renderer for the shots:
##   xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1600x1000 --fixed-fps 60 -s scripts/shots/reward_cards.gd -- --lang=en
## Writes build/shots/v0.8.0/n8/<name>_<lang>.png. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.8.0/n8/"

var _lang := "en"
var _frame := 0
var _w: World
var _reader: WorldReader
var _hud: Hud
var _panel: PickPanel
var _plan: Array = []
var _at := 0
var _cost := {"idle": [], "deal": [], "outro": []}
var _calls := {"idle": [], "deal": [], "outro": []}
var _panel_us := {"idle": [], "deal": [], "outro": []}
var _phase := "idle"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
	TranslationServer.set_locale(_lang)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("n8: renderer=%s lang=%s" % [RenderingServer.get_current_rendering_method(), _lang])
	var repo := ContentRepository.load_all()
	_w = CardPoolSurvey.world(repo, 5, &"gun", [])
	_w.add_item(_code(&"gun_pierce"))  # a held wand card: its card says "Level 1 → 2"
	_reader = WorldReader.new(_w)
	var view := root.get_visible_rect().size
	var bg := ColorRect.new()  # a stand-in for the game behind the panel
	bg.color = Color(0.13, 0.11, 0.1)
	bg.size = view
	root.add_child(bg)
	_hud = Hud.new()
	root.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = _hud.pick_panel()
	_hud.sync(_reader)
	# [frame offset from the step's start, action]
	_plan = [
		[0, "altar_epic"],
		[30, "shot:fan_facedown"],
		[42, "shot:midflip"],
		[82, "shot:epic_wait"],
		[113, "shot:epic_flip"],
		[150, "hover"],
		[160, "shot:hover_tilt"],
		[170, "pick"],
		[182, "shot:fly"],
		[190, "shot:burn"],
		[230, "altar_legendary"],
		[400, "shot:legendary"],
		[410, "pick"],
		[470, "chest"],
		[560, "shot:chest"],
		[600, "close"],
		[660, "report"],
	]


func _code(id: StringName) -> int:
	for k in _w.item_tables.size():
		if _w.item_tables[k].id == id:
			return k
	return -1


func _stat(id: StringName, rarity: int) -> int:
	for s in _w.stat_tables.size():
		if _w.stat_tables[s] != null and _w.stat_tables[s].id == id:
			return Offers.stat_code(s, rarity)
	return -1


func _altar(cards: PackedInt32Array) -> void:
	_w.add_reward(RewardStore.Kind.ALTAR, _w.player_pos() + Vector2(0.5, 0), 0)
	_w.rewards.set_offer(_w.rewards.size() - 1, cards)
	_w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.INTERACT))
	_hud.sync(_reader)
	_phase = "deal"


func _process(_delta: float) -> bool:
	_frame += 1
	_panel.set_process(false)  # driven here, so its own script time is measured (after its _ready turned it on)
	var t0 := Time.get_ticks_usec()
	_panel._process(1.0 / 60.0)
	_panel_us[_phase].append(float(Time.get_ticks_usec() - t0))
	if _frame > 2:
		var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_cost[_phase].append(ms)
		_calls[_phase].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _phase == "deal" and _panel.deal.done():
		_phase = "idle"
	if _phase == "outro" and not _panel.outro_playing():
		_phase = "idle"
	while _at < _plan.size() and _frame >= 40 + int(_plan[_at][0]):
		_act(String(_plan[_at][1]))
		_at += 1
	if _at >= _plan.size():
		quit(0)
		return true
	if _frame > 2000:
		quit(1)
		return true
	return false


func _act(what: String) -> void:
	if what.begins_with("shot:"):
		_shot(what.trim_prefix("shot:"))
		return
	match what:
		"altar_epic":
			_altar(
				PackedInt32Array(
					[_code(&"gun_pierce"), _stat(&"damage", Stats.Rarity.RARE), _code(&"gun_twin")]
				)
			)
		"altar_legendary":
			_altar(
				PackedInt32Array(
					[
						_stat(&"max_hp", Stats.Rarity.COMMON),
						_code(&"chain_blast"),
						_code(&"gun_spread")
					]
				)
			)
		"hover":
			var r := _panel.slot(1).card.get_global_rect()
			var at := r.get_center() + Vector2(r.size.x * 0.32, -r.size.y * 0.2)
			root.warp_mouse(at)
			var ev := InputEventMouseMotion.new()
			ev.position = at
			ev.global_position = at
			Input.parse_input_event(ev)
			_panel._set_focus(1)
		"pick":
			var k := _panel.focus_index()
			_panel._send(k + 1)
			var f := InputFrame.new()
			f.pick = k + 1
			_w.step(f)
			_hud.sync(_reader)
			_phase = "outro"
		"chest":
			_w.add_reward(RewardStore.Kind.CHEST, _w.player_pos() + Vector2(0.5, 0), 40)
			_w.shards = 40
			_w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.INTERACT))
			_hud.sync(_reader)
			_phase = "deal"
		"close":
			_panel._send(1)
			var f := InputFrame.new()
			f.pick = 1
			_w.step(f)
			_hud.sync(_reader)
			_phase = "outro"
		"report":
			for p: String in ["idle", "deal", "outro"]:
				var a: Array = _cost[p]
				var c: Array = _calls[p]
				if a.is_empty():
					continue
				var s := 0.0
				var mx := 0.0
				for v: float in a:
					s += v
					mx = maxf(mx, v)
				var cs := 0.0
				for v: float in c:
					cs += v
				var us: Array = _panel_us[p]
				var ps := 0.0
				var pm := 0.0
				for v: float in us:
					ps += v
					pm = maxf(pm, v)
				print(
					(
						(
							"n8: frame cost %s: %d frames, process avg %.3f ms, max %.3f ms, draw calls avg %.0f;"
							+ " the panel's own _process avg %.3f ms, max %.3f ms"
						)
						% [
							p,
							a.size(),
							s / a.size(),
							mx,
							cs / c.size(),
							ps / us.size() / 1000.0,
							pm / 1000.0
						]
					)
				)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":  # a timing run (--headless): no pictures
		return
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + "%s_%s.png" % [name, _lang])
	img.save_png(path)
	print("n8: wrote %s" % path)
