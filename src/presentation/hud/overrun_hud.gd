class_name OverrunHud
extends VBoxContainer
## The Overrun banner (v0.4.0 AB): while you're in the Overrun room, a red "OVERRUN" title near the top of the screen
## with the kills that clear it; when it clears, a line saying what it paid, for a few seconds. Reads
## WorldReader.overrun() only; it decides nothing.

const CLEARED_SECONDS := 4.0
const RED := Color("#FF4A5A")

var title := HudStyle.label(30, true)
var progress := HudStyle.label(18)
var _cleared_shown := false
var _left := 0.0


func _init() -> void:
	name = "OverrunHud"
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	alignment = BoxContainer.ALIGNMENT_CENTER
	offset_top = 96
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l: Label in [title, progress]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		add_child(l)
	title.add_theme_color_override("font_color", RED)
	visible = false


func sync(reader: WorldReader) -> void:
	var o := reader.overrun()
	if not o["active"]:
		visible = false
		return
	if o["cleared"] and not _cleared_shown:
		_cleared_shown = true
		_left = CLEARED_SECONDS
	if o["inside"]:
		title.text = tr("HUD_OVERRUN")
		progress.text = tr("HUD_OVERRUN_PROGRESS") % [o["kills"], o["needed"]]
		visible = true
	elif _left > 0.0:
		title.text = tr("HUD_OVERRUN")
		progress.text = tr("HUD_OVERRUN_CLEARED")
		visible = true
	else:
		visible = false


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta  # the next sync hides the cleared line
