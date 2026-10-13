class_name DpsMeter
extends PanelContainer
## v0.7.5 PG (owner N19; pick "Total + per-source"): the Playground's DPS meter on the right of the screen. DPS over the
## last 5 s, the average since the first hit, the total and the time, then the sources by damage with their share.
## Counted by DpsTally from the event log; Reset starts again. Never takes the mouse.

const ROWS := 10
const WIDTH := 300

var tally := DpsTally.new()
## A source's name key by its effect id (the cards', abilities' and engines' names; the app layer fills it).
var names := {}
var _recent: Label
var _summary: Label
var _sources: Label


func _init() -> void:
	name = "DpsMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	custom_minimum_size = Vector2(WIDTH, 0)
	position = Vector2(-WIDTH - 16, -120)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.09, 0.78)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(10)
	add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var title := Label.new()
	title.text = "UI_PG_DPS_TITLE"
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	box.add_child(title)
	_recent = _label(box, "Recent", 30)
	_summary = _label(box, "Summary", 15)
	_sources = _label(box, "Sources", 14)


func _label(box: Control, n: String, size: int) -> Label:
	var l := Label.new()
	l.name = n
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l


## Counts the new events and redraws.
func sync(reader: WorldReader) -> void:
	tally.observe(reader)
	var now := reader.tick()
	_recent.text = "%s  %s" % [_num(tally.dps_recent(now)), tr("UI_PG_DPS_RECENT")]
	_summary.text = (
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
	var lines: PackedStringArray = []
	var ranked := tally.ranked()
	for k in mini(ROWS, ranked.size()):
		var share := 100.0 * float(ranked[k][1]) / maxi(tally.total, 1)
		lines.append(
			"%3d%%  %s  %s" % [roundi(share), _num(ranked[k][1]), source_name(ranked[k][0])]
		)
	if ranked.size() > ROWS:
		lines.append(tr("UI_PG_DPS_MORE") % (ranked.size() - ROWS))
	_sources.text = "\n".join(lines)


func reset(reader: WorldReader) -> void:
	tally.reset(reader)
	sync(reader)


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
