class_name GambleHud
extends Control
## The gamble shrine on the HUD (v0.3.0 L19): the interact prompt by the shrine (its price, red when you can't
## afford it, or a note when every stat is capped), the result card when a use lands (GambleCard), and the stats
## won this run (GambleStatsPanel) while you stand at the shrine or just after a win. Reads only; never takes the
## mouse. v0.8.0 N14 (owner O72): a spent shrine says so; a failed use shows a short "It failed" line. v0.8.0 N18
## (owner O76: the game stops explaining): N14's odds line under the prompt (wins and chance to fail) is gone, and a
## spent shrine's prompt is the one word "Spent".

const POOR := Color("#FF5A4D")
## The stats panel stays this long (s) after a win, even once you walk away.
const STATS_AFTER_WIN_S := 4.0
## v0.8.0 N14: the "It failed" line shows this long (s).
const FAIL_S := 1.6
const FAIL_COLOR := Color("#FF7A5C")

var card := GambleCard.new()
var stats := GambleStatsPanel.new()
var _prompt := InteractPrompt.new()
var _fail := Label.new()
var _seen_tick := -1
var _fail_tick := -1
var _fail_left := 0.0
var _stats_left := 0.0
var _near := false


func _init() -> void:
	name = "Gamble"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	_fail.name = "GambleFailed"  # v0.8.0 N14: a failed use's short line, over the shrine
	_fail.set_anchors_preset(Control.PRESET_CENTER)
	_fail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fail.custom_minimum_size = Vector2(600, 0)
	_fail.position = Vector2(-300, -200)
	_fail.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_fail.add_theme_font_size_override("font_size", 34)
	_fail.add_theme_constant_override("outline_size", 8)
	_fail.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	HudStyle.font_color(_fail, FAIL_COLOR)
	_fail.visible = false
	add_child(_fail)
	# The card rises above the player (the screen's centre): over the shrine, where you stand to use it.
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-GambleCard.WIDTH * 0.5, -280)  # v0.6.1 R1: the wider plaque, centred
	add_child(card)
	stats.place_top_right(84)
	stats.visible = false
	add_child(stats)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(reader: WorldReader) -> void:
	if not reader.has_gamble():
		_prompt.hide_prompt()
		_fail.visible = false
		stats.visible = false
		return
	_near = reader.gamble_in_reach() and not reader.choosing()
	var spent := reader.gamble_spent()
	if _near:
		var price := reader.gamble_price()
		var ok := reader.gamble_affordable() and not reader.gamble_exhausted() and not spent
		var line := ""
		var no_press := false
		if spent:  # v0.8.0 N14 (O72): blocked after its wins
			line = tr("UI_GAMBLE_BLOCKED")
			no_press = true
		elif reader.gamble_exhausted():
			line = tr("UI_GAMBLE_SPENT")
			no_press = true
		else:
			line = tr("UI_GAMBLE_USE") % price  # v0.9.5 PR: short; too poor shows it red
		_prompt.show_prompt(reader, line, not ok, Color.WHITE, not no_press)
	else:
		_prompt.hide_prompt()
	var f := reader.gamble_fail_tick()
	if f != _fail_tick:
		_fail_tick = f
		if f >= 0:
			_fail.text = tr("UI_GAMBLE_FAILED")
			_fail.visible = true
			_fail_left = FAIL_S
	var t := reader.gamble_tick()
	if t != _seen_tick:
		_seen_tick = t
		if t >= 0:
			_play(reader)
	stats.sync(reader)
	stats.visible = _near or _stats_left > 0.0


func _process(delta: float) -> void:
	if _fail_left > 0.0:
		_fail_left = maxf(0.0, _fail_left - delta)
		_fail.modulate.a = minf(1.0, _fail_left / (FAIL_S * 0.4))
		if _fail_left == 0.0:
			_fail.visible = false
	if _stats_left > 0.0:
		_stats_left = maxf(0.0, _stats_left - delta)
		if _stats_left == 0.0 and not _near:
			stats.visible = false


## The prompt by the shrine ("" when none), and whether it shows the can't-afford colour.
func prompt_text() -> String:
	return _prompt.text()


## v0.8.0 N14: the failed use's line ("" when none).
func fail_text() -> String:
	return _fail.text if _fail.visible else ""


func prompt_poor() -> bool:
	return _prompt.is_poor()


func _play(reader: WorldReader) -> void:
	var stat := reader.gamble_last_stat()
	var id := reader.gamble_stat_id(stat)
	var reel: Array[StringName] = []
	for s in reader.gamble_stat_count():
		if s != stat:
			reel.append(reader.gamble_stat_id(s))
	reel.append(id)
	card.play(reel, id, GambleIcons.line(self, id, reader.gamble_amount(stat)))
	_stats_left = STATS_AFTER_WIN_S
