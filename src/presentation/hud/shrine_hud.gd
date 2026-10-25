class_name ShrineHud
extends VBoxContainer
## v0.9.0 SH, HF (owner Q29b, W36): the Blood and Chaos shrines' and the healing fountain's result lines, near the top
## of the screen like the Lockdown banner (LockdownHud). The cost is shown before the press by the shared interact
## prompt; this shows what the press did, for a few seconds: Blood's price paid and its altar risen (or that you are
## too weak), the Chaos challenge's enemies left while it is fought and then its altar, the fountain's heal (or that
## you are at full health). Reads WorldReader.shrine() only; it decides nothing.

const LINE_SECONDS := 3.5
const BLOOD := Color("#FF5A6A")
const CHAOS := Color("#C79BFF")
const WATER := Color("#8FE3FF")

var title := HudStyle.label(26, true)
var detail := HudStyle.label(18)
var _seen: Array = []
var _left := 0.0


func _init() -> void:
	name = "ShrineHud"
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	alignment = BoxContainer.ALIGNMENT_CENTER
	offset_top = 96
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l: Label in [title, detail]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		add_child(l)
	visible = false


func sync(reader: WorldReader) -> void:
	if not reader.has_shrines():
		visible = false
		_seen = []
		return
	var d := reader.shrine()
	var now := [
		int(d["used_tick"]),
		int(d["denied_tick"]),
		int(d["clear_tick"]),
		int(d["fountain_tick"]),
		int(d["fountain_denied_tick"])
	]
	if _seen.is_empty():  # the first sync (or a resumed floor): what happened before shows no line
		_seen = now
	var blood := int(d["kind"]) == WorldReader.SHRINE_BLOOD
	for k in now.size():
		if now[k] != _seen[k] and now[k] >= 0:
			_show(k, d, blood)
	_seen = now
	if int(d["chaos_phase"]) == 1:
		title.text = tr("SHRINE_CHAOS_NAME")
		HudStyle.font_color(title, CHAOS)
		detail.text = tr("SHRINE_CHAOS_LEFT") % int(d["chaos_alive"])
		visible = true
	else:
		visible = _left > 0.0


func _show(k: int, d: Dictionary, blood: bool) -> void:
	_left = LINE_SECONDS
	match k:
		0:  # used: Blood paid (Chaos's start shows the count instead)
			title.text = tr("SHRINE_BLOOD_NAME" if blood else "SHRINE_CHAOS_NAME")
			HudStyle.font_color(title, BLOOD if blood else CHAOS)
			detail.text = tr("SHRINE_BLOOD_DONE") % int(d["paid"]) if blood else ""
		1:
			title.text = tr("SHRINE_BLOOD_NAME")
			HudStyle.font_color(title, BLOOD)
			detail.text = tr("SHRINE_BLOOD_DENIED")
		2:
			title.text = tr("SHRINE_CHAOS_NAME")
			HudStyle.font_color(title, CHAOS)
			detail.text = tr("SHRINE_CHAOS_DONE")
		3:
			title.text = tr("FOUNTAIN_NAME")
			HudStyle.font_color(title, WATER)
			detail.text = tr("FOUNTAIN_DONE") % int(d["fountain_healed"])
		_:
			title.text = tr("FOUNTAIN_NAME")
			HudStyle.font_color(title, WATER)
			detail.text = tr("FOUNTAIN_DENIED")


## The line shown now ("" when none), for tests.
func line() -> String:
	return "%s · %s" % [title.text, detail.text] if visible else ""


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta  # the next sync hides the line
