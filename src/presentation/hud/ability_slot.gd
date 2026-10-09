class_name AbilitySlot
extends Control
## One ability slot on the HUD (v0.4.0 BS; AbilityHud): the symbol, a cooldown sweep, level pips and the key.
## v0.5.5 A5 (Ember stone): in HudStyle.EMBER the slot is a chipped stone slab with the ability's colour as a line
## along its bottom (the B mockup); other styles keep CardStyle's square.

const LEVELS := WorldReader.ABILITY_MAX_LEVEL
## The key corner's width (px) and the smallest size a long key name shrinks to.
const KEY_W := AbilityHud.SLOT - 6.0
const KEY_FONT_MIN := 9

var ability_id := &""
var level := 0
## 0 (just used) .. 1 (ready).
var fill := 1.0
var is_ready := true
var key_text := ""
var charges := 0
## Seconds of cooldown left (shown over the sweep while above 1 s).
var seconds := 0.0
var _key := Label.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudStyle.style_label(_key, AbilityHud.KEY_FONT, true)
	_key.position = Vector2(3, -2)
	_key.clip_text = true  # the last resort; the short name (InputLabels.short_text) and fit_key() come first
	_key.size = Vector2(KEY_W, AbilityHud.KEY_FONT + 4)
	add_child(_key)


## The key's font size for `text`: KEY_FONT, or smaller (down to KEY_FONT_MIN) until it fits KEY_W (v0.6.0 UP: the
## owner saw "Left clic" cut off; long key names such as "Backspace" shrink instead).
static func fit_key(text: String) -> int:
	var f := HudStyle.font(true)
	for s in range(AbilityHud.KEY_FONT, KEY_FONT_MIN - 1, -1):
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= KEY_W:
			return s
	return KEY_FONT_MIN


## Whether `text` fits the slot's key corner at its fitted size (tests).
static func key_fits(text: String) -> bool:
	var f := HudStyle.font(true)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_key(text)).x <= KEY_W


## The key label's font size now (tests).
func key_font_size() -> int:
	return _key.get_theme_font_size("font_size")


func show_empty() -> void:
	if ability_id == &"" and level == 0:
		return
	ability_id = &""
	level = 0
	key_text = ""
	_key.text = ""
	queue_redraw()


func show_ability(
	id: StringName,
	lvl: int,
	p_fill: float,
	p_ready: bool,
	key: String,
	p_charges: int,
	p_seconds: float = 0.0
) -> void:
	if (
		ceili(p_seconds) == ceili(seconds)
		and id == ability_id
		and lvl == level
		and is_equal_approx(p_fill, fill)
		and p_ready == is_ready
		and key == key_text
		and p_charges == charges
	):
		return
	ability_id = id
	level = lvl
	fill = p_fill
	is_ready = p_ready
	key_text = key
	charges = p_charges
	seconds = p_seconds
	if _key.text != key:
		_key.text = key
		_key.add_theme_font_size_override("font_size", fit_key(key))
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := AbilityIcons.color(ability_id)
	if HudStyle.current == HudStyle.Style.EMBER:
		if ability_id == &"":
			HudStyle.draw_plate(self, r, false, HudStyle.STONE_EDGE, Color(HudStyle.STONE, 0.55))
			return
		HudStyle.draw_plate(self, r)
		var line := Rect2(Vector2(7, size.y - 5), Vector2(size.x - 14, 2.5))
		draw_rect(line, Color(c, 0.95 if is_ready else 0.4))
	else:
		var box := CardStyle.box(Vector4.ZERO)
		if ability_id == &"":
			box.bg_color = Color(CardStyle.BG, 0.4)
			draw_style_box(box, r)
			return
		CardStyle.apply(box, c, is_ready)
		box.border_color = Color(c, 0.9 if is_ready else 0.45)
		draw_style_box(box, r)
	var icon_c := c if is_ready else c.darkened(0.35)
	ItemIcons.draw(self, ability_id, r.grow(-size.x * 0.2), icon_c)
	if fill < 1.0:
		_sweep(r, 1.0 - fill)
	if seconds > 1.0:
		draw_string(
			get_theme_default_font(),
			Vector2(0, size.y * 0.5 + AbilityHud.SECONDS_FONT * 0.35),
			str(ceili(seconds)),
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			AbilityHud.SECONDS_FONT,
			Color.WHITE
		)
	if charges > 1:
		draw_string(
			get_theme_default_font(),
			Vector2(size.x - 12, size.y - 4),
			str(charges),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			AbilityHud.KEY_FONT,
			Color.WHITE
		)
	var pip := AbilityHud.PIP
	var span := LEVELS * pip + (LEVELS - 1) * 2.0
	var x0 := (size.x - span) * 0.5
	for k in LEVELS:
		var pr := Rect2(Vector2(x0 + k * (pip + 2.0), size.y + 4.0), Vector2(pip, pip))
		draw_rect(pr, c if k < level else Color(1, 1, 1, 0.18))


## The share still cooling, as a dark wedge from twelve o'clock, clockwise.
func _sweep(r: Rect2, share: float) -> void:
	var c := r.get_center()
	var rad := r.size.length() * 0.5
	var pts := PackedVector2Array([c])
	var steps := maxi(2, int(ceil(share * 24.0)))
	for k in steps + 1:
		var a := -PI * 0.5 + TAU * share * k / steps
		var p := c + Vector2(cos(a), sin(a)) * rad
		pts.append(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))
	draw_colored_polygon(pts, AbilityHud.SWEEP)
