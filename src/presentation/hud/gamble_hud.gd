class_name GambleHud
extends Control
## The gamble shrine on the HUD (v0.3.0 L19): the interact prompt by the shrine (its price, red when you can't
## afford it, or a note when every stat is capped), the result card when a use lands (GambleCard), and the stats
## won this run (GambleStatsPanel) while you stand at the shrine or just after a win. Reads only; never takes the
## mouse.

const POOR := Color("#FF5A4D")
## The stats panel stays this long (s) after a win, even once you walk away.
const STATS_AFTER_WIN_S := 4.0

var card := GambleCard.new()
var stats := GambleStatsPanel.new()
var _prompt := Label.new()
var _seen_tick := -1
var _stats_left := 0.0
var _near := false


func _init() -> void:
	name = "Gamble"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.name = "GamblePrompt"
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size = Vector2(900, 0)
	_prompt.position = Vector2(-450, -112)
	_prompt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.visible = false
	add_child(_prompt)
	# The card rises above the player (the screen's centre): over the shrine, where you stand to use it.
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-170, -250)
	add_child(card)
	stats.place_top_right(84)
	stats.visible = false
	add_child(stats)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(reader: WorldReader) -> void:
	if not reader.has_gamble():
		_prompt.visible = false
		stats.visible = false
		return
	_near = reader.gamble_in_reach() and not reader.choosing()
	_prompt.visible = _near
	if _near:
		var price := reader.gamble_price()
		var ok := reader.gamble_affordable() and not reader.gamble_exhausted()
		if reader.gamble_exhausted():
			_prompt.text = tr("UI_GAMBLE_SPENT")
		elif reader.gamble_affordable():
			_prompt.text = tr("UI_GAMBLE_USE") % price
		else:
			_prompt.text = tr("REWARD_TOO_POOR") % [reader.shards(), price]
		_prompt.add_theme_color_override("font_color", Color.WHITE if ok else POOR)
	var t := reader.gamble_tick()
	if t != _seen_tick:
		_seen_tick = t
		if t >= 0:
			_play(reader)
	stats.sync(reader)
	stats.visible = _near or _stats_left > 0.0


func _process(delta: float) -> void:
	if _stats_left > 0.0:
		_stats_left = maxf(0.0, _stats_left - delta)
		if _stats_left == 0.0 and not _near:
			stats.visible = false


## The prompt by the shrine ("" when none), and whether it shows the can't-afford colour.
func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""


func prompt_poor() -> bool:
	return _prompt.get_theme_color(&"font_color") == POOR


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
