class_name PhaseHud
extends VBoxContainer
## The difficulty phase on the HUD (v0.4.0 TU, owner D1–D2 and "distribute presenting them through the first 3
## floors"): a small, dim line under the top plate naming the floor's phase ("Calm", "The hunt"…), and for a few
## seconds a brighter line when a new phase begins or an enemy kind the run hasn't met yet first appears ("New:
## Sniper"). Reads WorldReader only (phase, phase_name_key, new_kinds, kind_alive); it decides nothing. Hidden on a
## floor without a curve.

const ANNOUNCE_SECONDS := 4.0
const NEW_COLOR := Color("#FFD27A")

var phase_label := HudStyle.label(14)
var announce := HudStyle.label(18, true)
var _phase := -1
var _announced := {}
var _queue: PackedStringArray = []
var _left := 0.0


func _init() -> void:
	name = "PhaseHud"
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	alignment = BoxContainer.ALIGNMENT_CENTER
	offset_top = 150
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l: Label in [phase_label, announce]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		add_child(l)
	phase_label.add_theme_color_override("font_color", Color(HudStyle.text_color(), 0.7))
	announce.add_theme_color_override("font_color", NEW_COLOR)
	announce.visible = false
	visible = false


func sync(reader: WorldReader) -> void:
	if not reader.has_curve() or not reader.has_floor():
		visible = false
		return
	visible = true
	var p := reader.phase()
	phase_label.text = tr(reader.phase_name_key())
	if p != _phase:
		if _phase >= 0 and p > _phase:
			_queue.append(tr(reader.phase_name_key()))
		_phase = p
	for kind in reader.new_kinds():
		if not _announced.has(kind) and reader.kind_alive(kind):
			_announced[kind] = true
			_queue.append(tr("HUD_NEW_ENEMY") % tr(reader.enemy_name_key(kind)))
	if _left <= 0.0 and not _queue.is_empty():
		announce.text = _queue[0]
		_queue.remove_at(0)
		_left = ANNOUNCE_SECONDS
	announce.visible = _left > 0.0


## The announcement on screen now ("" when none).
func announcement() -> String:
	return announce.text if announce.visible else ""


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
