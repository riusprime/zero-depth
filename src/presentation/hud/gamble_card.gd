class_name GambleCard
extends PanelContainer
## The gamble shrine's result card (v0.3.0 L19). The sim grants the stat at once; this card replays it: a short spin
## through the stats the shrine could still give (slowing down, frame time, cosmetic only), landing on the one won,
## then its line ("+6 % melee damage") for a moment before it fades. It decides nothing about the game.
## v0.6.1 R1: the card is one of the owner's crystal plaques (PlaqueBox) in the stat's family colour
## (Plaques.GAMBLE_FAMILY → the card frames' table), dimmer while it spins; the line steps down in size to fit.

const SPIN_S := 0.9
const HOLD_S := 2.4
const FADE_S := 0.25
const ICON := 56.0
const WIDTH := 560.0
const HEIGHT := 140.0
const GAP := 14
const TITLE_SIZE := 14
const LINE_SIZES := [24, 23, 22, 21, 20, 19, 18, 17, 16]

var icon := GambleIconView.new(&"", ICON)
## The line's size picked by the last landing (tests check it fits).
var line_size := 0
var _title := Label.new()
var _line := Label.new()
var _box := Plaques.box(&"amber", HEIGHT)
var _reel: Array[StringName] = []
var _result := &""
var _text := ""
## Seconds since play(); < 0 when idle.
var _t := -1.0


func _init() -> void:
	name = "GambleCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_theme_stylebox_override("panel", _box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	add_child(row)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.pivot_offset = Vector2(ICON, ICON) * 0.5
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_title.add_theme_font_override("font", HudStyle.font(false))
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_line.add_theme_font_override("font", HudStyle.font(true))
	_line.add_theme_font_size_override("font_size", LINE_SIZES[0])
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
	_box.set_plaque(Plaques.of_gamble(id))
	_box.set_focused(landed)  # brighter once it lands
	_line.text = _text if landed else ""
	if landed:
		line_size = fit_line(_text)
		_line.add_theme_font_size_override("font_size", line_size)
	_line.add_theme_color_override("font_color", c.lerp(Color.WHITE, 0.35))
	if not landed:
		icon.scale = Vector2.ONE


## The plaque this card is drawn on.
func plaque_box() -> PlaqueBox:
	return _box


## The text column's width (px): the plaque's text box less the icon.
static func text_width() -> float:
	return Plaques.content_size(HEIGHT, WIDTH).x - ICON - GAP


## The largest line size at which `text` fits one line of the text column.
static func fit_line(text: String) -> int:
	var f := HudStyle.font(true)
	for s: int in LINE_SIZES:
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= text_width():
			return s
	return LINE_SIZES[LINE_SIZES.size() - 1]


## True when `text` fits one line of the text column at its fitted size, under the title (tests).
static func line_fits(text: String) -> bool:
	var f := HudStyle.font(true)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_line(text)).x
	var h := f.get_height(fit_line(text)) + HudStyle.font(false).get_height(TITLE_SIZE)
	return w <= text_width() + 0.5 and h <= Plaques.content_size(HEIGHT, WIDTH).y + 0.5
