class_name DpsMeter
extends PanelContainer
## The Playground's DPS meter on the right of the screen. DPS over the
## last 5 s, the average since the first hit, the total and the time, then the sources by damage with their share.
## Counted by DpsTally from the event log; Reset starts again. Never takes the mouse.
## UI style Astral; the training room is player-facing: HudStyle's Astral side panel (ink, a contour
## and an inner contour, the accent as a short line on top), the title in letter-spaced Cinzel, the DPS in Cinzel, the
## lines in Atkinson (HudStyle.MIN_LABEL and up) in Astral's silver-white and grey.

const ROWS := 10
const WIDTH := 340

var tally := DpsTally.new()
## A source's name key by its effect id (the cards', abilities' and engines' names; the app layer fills it).
var names := {}
## How many times the lines were written (tests: at most once a frame).
var writes := 0
var _recent: Label
var _summary: Label
var _sources: Label
## The tick the lines were last written for (-1: write them on the next frame). A frame can hold several ticks; the
## lines are written once a frame, from the last one, and a label is set only when its string changed (each set
## shapes the text again and re-lays the panel).
var _written_tick := -1
var _now := 0


func _init() -> void:
	name = "DpsMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	custom_minimum_size = Vector2(WIDTH, 0)
	position = Vector2(-WIDTH - 16, -120)
	add_theme_stylebox_override("panel", HudStyle.side_panel_box(Vector2(18, 14)))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var title := Label.new()
	title.text = "UI_PG_DPS_TITLE"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudStyle.serif_label(title, 18, 4, HudStyle.A_TEXT)
	box.add_child(title)
	_recent = _label(box, "Recent", 30)
	HudStyle.serif_label(_recent, 24, 1, HudStyle.A_LINE_HI)  # fits "0 DPS (ÚLTIMOS 5 S)" in WIDTH
	_recent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary = _label(box, "Summary", 16)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sources = _label(box, "Sources", 16)
	_sources.add_theme_color_override("font_color", HudStyle.A_DIM)


func _draw() -> void:
	HudStyle.draw_side_panel(self, HudStyle.A_ACCENT)


func _label(box: Control, n: String, size: int) -> Label:
	var l := Label.new()
	l.name = n
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HudStyle.style_label(l, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l


## Counts the new events; the lines follow once this frame.
func sync(reader: WorldReader) -> void:
	tally.observe(reader)
	_now = reader.tick()
	if _written_tick != _now:
		_written_tick = -1


func _process(_delta: float) -> void:
	if _written_tick == -1:
		write_lines()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_written_tick = -1


## Writes the lines from the tally at the last synced tick.
func write_lines() -> void:
	_written_tick = _now
	writes += 1
	var now := _now
	_set_text(_recent, "%s  %s" % [_num(tally.dps_recent(now)), tr("UI_PG_DPS_RECENT")])
	_set_text(
		_summary,
		(
			"%s %s   %s %s   %s %.1f s"
			% [
				tr("UI_PG_DPS_AVERAGE"),
				_num(tally.dps_overall(now)),
				tr("UI_PG_DPS_TOTAL"),
				_num(tally.total),
				tr("UI_PG_DPS_TIME"),
				tally.seconds(now),
			]
		)
	)
	var lines: PackedStringArray = []
	var ranked := tally.ranked()
	for k in mini(ROWS, ranked.size()):
		var share := 100.0 * float(ranked[k][1]) / maxi(tally.total, 1)
		lines.append(
			"%3d%%  %s  %s" % [roundi(share), _num(ranked[k][1]), source_name(ranked[k][0])]
		)
	if ranked.size() > ROWS:
		lines.append(tr("UI_PG_DPS_MORE") % (ranked.size() - ROWS))
	_set_text(_sources, "\n".join(lines))


static func _set_text(l: Label, t: String) -> void:
	if l.text != t:
		l.text = t


func reset(reader: WorldReader) -> void:
	tally.reset(reader)
	sync(reader)
	_written_tick = -1


## The shown name of a source: the basic attack, the card or ability or engine whose id it is, else "Other (id)".
func source_name(source: StringName) -> String:
	if source == DpsTally.BASIC:
		return tr("UI_PG_SRC_BASIC")
	if names.has(source):
		return tr(names[source])
	return tr("UI_PG_SRC_OTHER") % String(source)


static func _num(v: float) -> String:
	if v >= 100000.0:
		return "%.0fk" % (v / 1000.0)
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return "%d" % roundi(v)
