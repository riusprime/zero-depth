class_name LockdownHud
extends VBoxContainer
## v0.9.0 LK (owner Q21): the Lockdown banner, beside the arena's (OverrunHud, the same place: they never show
## together). While you're sealed in, a title near the top of the screen ("LOCKDOWN", or "HAZARD LOCKDOWN" in a
## Hazard one) with the formation you're on and how many enemies are left; when it opens, a line saying the exits are
## open (or that the bars gave way, when the 90 s cap opened them), for a few seconds. Reads WorldReader.lockdown()
## only; it decides nothing.

const CLEARED_SECONDS := 4.0
const STEEL := Color("#C9D3DD")
const WARN := Color("#FF7A3A")

var title := HudStyle.label(30, true)
var progress := HudStyle.label(18)
var _opened := -1
var _forced := false
var _left := 0.0


func _init() -> void:
	name = "LockdownHud"
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
	if not reader.has_lockdowns():
		visible = false
		return
	var d := reader.lockdown()
	var cleared: PackedInt32Array = d["cleared"]
	if _opened < 0 or cleared.size() < _opened:  # the first sync, or a new floor: earlier opens show no line
		_opened = cleared.size()
	if cleared.size() > _opened:
		_opened = cleared.size()
		_forced = (d["forced"] as PackedInt32Array).has(cleared[cleared.size() - 1])
		_left = CLEARED_SECONDS
	if int(d["sealed"]) >= 0:
		var hazard := int(d["kind"]) == WorldReader.LOCKDOWN_HAZARD
		title.text = tr("HUD_LOCKDOWN_HAZARD" if hazard else "HUD_LOCKDOWN")
		HudStyle.font_color(title, WARN if hazard else STEEL)
		var wave := maxi(1, int(d["wave"]))
		progress.text = tr("HUD_LOCKDOWN_LEFT") % [wave, int(d["waves"]), int(d["alive"])]
		visible = true
	elif _left > 0.0:
		title.text = tr("HUD_LOCKDOWN")
		HudStyle.font_color(title, STEEL)
		progress.text = tr("HUD_LOCKDOWN_FORCED" if _forced else "HUD_LOCKDOWN_CLEARED")
		visible = true
	else:
		visible = false


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta  # the next sync hides the cleared line
