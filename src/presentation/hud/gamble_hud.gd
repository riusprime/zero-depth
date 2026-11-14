class_name GambleHud
extends Control
## The gamble shrine on the HUD: the interact prompt by the shrine (its price, red when you can't
## afford it, or a note when every stat is capped), the reward rolled above the shrine when a use lands
## (GambleRoll, v0.11.0 F13: it replaced the big centre card and the "It failed" line) and the stats
## won this run (GambleStatsPanel) while you stand at the shrine or just after a win. Reads only; never takes the
## mouse. a spent shrine says so; a failed use shows a short "It failed" line. v0.8.0 N18
## (owner O76: the game stops explaining): N14's odds line under the prompt (wins and chance to fail) is gone, and a
## spent shrine's prompt is the one word "Spent".
## UI style Astral: the "It failed" line is letter-spaced Cinzel in Astral's rose;
## the card and the stats panel draw their own Astral look.

const POOR := Color("#FF5A4D")
## The stats panel stays this long (s) after a win, even once you walk away.
const STATS_AFTER_WIN_S := 4.0

var roll := GambleRoll.new()
var stats := GambleStatsPanel.new()
var _prompt := InteractPrompt.new()
var _seen_tick := -1
var _fail_tick := -1
var _stats_left := 0.0
var _near := false
var _arrived := 0


func _init() -> void:
	name = "Gamble"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	stats.place_top_right(84)
	stats.visible = false
	add_child(stats)
	roll.panel = stats
	add_child(roll)  # last: the symbol flies over the panel
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(reader: WorldReader) -> void:
	if not reader.has_gamble():
		_prompt.hide_prompt()
		roll.clear()
		stats.release_all()
		_stats_left = 0.0
		stats.visible = false
		return
	_near = reader.gamble_in_reach() and not reader.choosing()
	var spent := reader.gamble_spent()
	if _near:
		var price := reader.gamble_price()
		var ok := reader.gamble_affordable() and not reader.gamble_exhausted() and not spent
		var line := ""
		var no_press := false
		if spent:  # Blocked after its wins
			line = tr("UI_GAMBLE_BLOCKED")
			no_press = true
		elif reader.gamble_exhausted():
			line = tr("UI_GAMBLE_SPENT")
			no_press = true
		else:
			line = tr("UI_GAMBLE_USE") % price  # Short; too poor shows it red
		_prompt.show_prompt(reader, line, not ok, Color.WHITE, not no_press)
	else:
		_prompt.hide_prompt()
	stats.sync(reader)  # first: a win below holds its row until the symbol arrives
	var f := reader.gamble_fail_tick()
	if f != _fail_tick:
		_fail_tick = f
		if f >= 0:
			roll.start(reader, -1)
	var t := reader.gamble_tick()
	if t != _seen_tick:
		_seen_tick = t
		if t >= 0:
			roll.start(reader, reader.gamble_last_stat())
			stats.sync(reader)
			_stats_left = STATS_AFTER_WIN_S if ViewPrefs.reduced_motion else 0.0
	stats.visible = _near or _stats_left > 0.0 or roll.holding()


func _process(delta: float) -> void:
	if roll.arrived != _arrived:  # a symbol landed: the panel stays up from now
		_arrived = roll.arrived
		_stats_left = STATS_AFTER_WIN_S
		stats.visible = true
	if _stats_left > 0.0:
		_stats_left = maxf(0.0, _stats_left - delta)
		if _stats_left == 0.0 and not _near:
			stats.visible = false


## The prompt by the shrine ("" when none), and whether it shows the can't-afford colour.
func prompt_text() -> String:
	return _prompt.text()


func prompt_poor() -> bool:
	return _prompt.is_poor()
