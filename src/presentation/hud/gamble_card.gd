class_name GambleCard
extends PanelContainer
## The gamble shrine's result card (v0.3.0 L19). The sim grants the stat at once; this card replays it: a short spin
## through the stats the shrine could still give (slowing down, frame time, cosmetic only), landing on the one won,
## then its line ("+6 % melee damage") for a moment before it fades. It decides nothing about the game.

const SPIN_S := 0.9
const HOLD_S := 2.4
const FADE_S := 0.25
const ICON := 64.0

var icon := GambleIconView.new(&"", ICON)
var _title := Label.new()
var _line := Label.new()
var _box := StyleBoxFlat.new()
var _reel: Array[StringName] = []
var _result := &""
var _text := ""
## Seconds since play(); < 0 when idle.
var _t := -1.0


func _init() -> void:
	name = "GambleCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(340, 84)
	_box.bg_color = Color(0.03, 0.04, 0.07, 0.86)
	_box.set_corner_radius_all(10)
	_box.border_width_left = 6
	_box.border_width_top = 1
	_box.border_width_bottom = 1
	_box.border_width_right = 1
	_box.content_margin_left = 14
	_box.content_margin_right = 16
	_box.content_margin_top = 8
	_box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", _box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.pivot_offset = Vector2(ICON, ICON) * 0.5
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_line.add_theme_font_size_override("font_size", 24)
	for l: Label in [_title, _line]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(l)
	modulate.a = 0.0
	visible = false


## Replays a win: `reel` the stat ids to spin through, `result` the one won, `line` its translated line.
func play(reel: Array[StringName], result: StringName, line: String) -> void:
	_reel = reel.duplicate()
	if _reel.is_empty():
		_reel.append(result)
	_result = result
	_text = line
	_title.text = tr("UI_GAMBLE_CARD")
	_t = 0.0
	visible = true
	modulate.a = 1.0
	_show(_reel[0], false)


## Still spinning (the result isn't shown yet).
func spinning() -> bool:
	return _t >= 0.0 and _t < SPIN_S


func showing() -> bool:
	return visible and _t >= 0.0


## The stat on the card now, and its line ("" while spinning).
func shown_stat() -> StringName:
	return icon.stat_id


func line_text() -> String:
	return _line.text


## Jumps to the landed result (tests and shot scripts).
func finish_spin() -> void:
	if _t >= 0.0 and _t < SPIN_S:
		_t = SPIN_S
		_land()


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	var before := _t
	_t += delta
	if _t < SPIN_S:
		_show(_reel[_reel_index(_t)], false)
		return
	if before < SPIN_S:
		_land()
	var since := _t - SPIN_S
	icon.scale = Vector2.ONE * (1.0 + 0.3 * maxf(0.0, 1.0 - since / 0.2))
	if since > HOLD_S:
		modulate.a = clampf(1.0 - (since - HOLD_S) / FADE_S, 0.0, 1.0)
		if modulate.a <= 0.0:
			visible = false
			_t = -1.0


## Which reel entry shows at time t: steps that start fast and slow down (step k lasts 0.04 + 0.02 k s).
func _reel_index(t: float) -> int:
	var k := 0
	var at := 0.0
	while true:
		at += 0.04 + 0.02 * k
		if at > t:
			break
		k += 1
	return k % _reel.size()


func _land() -> void:
	_show(_result, true)


func _show(id: StringName, landed: bool) -> void:
	icon.set_stat(id)
	var c := GambleIcons.color(id)
	_box.border_color = c if landed else Color(1, 1, 1, 0.25)
	_line.text = _text if landed else ""
	_line.add_theme_color_override("font_color", c.lerp(Color.WHITE, 0.35))
	if not landed:
		icon.scale = Vector2.ONE
