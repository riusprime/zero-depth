class_name OverrunHud
extends VBoxContainer
## The arena banner (v0.4.0 AB for the Overrun; v0.5.5 AR for every sealed arena). While you're sealed in, a title
## near the top of the screen (red "OVERRUN" in the Overrun, amber "ARENA" elsewhere) with the wave you're on and how
## many enemies are left; when it clears, a line saying the doors and the reward are open (the Overrun: what it paid),
## for a few seconds. Reads WorldReader.arenas() and overrun() only; it decides nothing.

const CLEARED_SECONDS := 4.0
const RED := Color("#FF4A5A")
const AMBER := Color("#FFB020")

var title := HudStyle.label(30, true)
var progress := HudStyle.label(18)
var _cleared_seen := 0
var _cleared_overrun := false
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
	visible = false


func sync(reader: WorldReader) -> void:
	var a := reader.arenas()
	if not a["active"]:
		visible = false
		return
	var cleared: PackedInt32Array = a["cleared"]
	if cleared.size() > _cleared_seen:
		_cleared_seen = cleared.size()
		_cleared_overrun = cleared[cleared.size() - 1] == int(a["overrun"])
		_left = CLEARED_SECONDS
	if int(a["sealed"]) >= 0:
		var over: bool = a["overrun_sealed"]
		_set_title(over)
		var wave := maxi(1, int(a["wave"]))
		progress.text = tr("HUD_ARENA_WAVE") % [wave, int(a["waves"]), int(a["alive"])]
		visible = true
	elif _left > 0.0:
		_set_title(_cleared_overrun)
		progress.text = tr("HUD_OVERRUN_CLEARED" if _cleared_overrun else "HUD_ARENA_CLEARED")
		visible = true
	else:
		visible = false


func _set_title(over: bool) -> void:
	title.text = tr("HUD_OVERRUN" if over else "HUD_ARENA")
	title.add_theme_color_override("font_color", RED if over else AMBER)


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta  # the next sync hides the cleared line
