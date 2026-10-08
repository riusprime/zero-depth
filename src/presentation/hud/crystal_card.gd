class_name CrystalCard
extends Control
## A pick card in the owner's crystal frame (v0.5.5 A4; reference docs/roadmap/v0.5.5/refs/card_style_reference.webp):
## the frame (CardFrames: its colour is the card's family) with the crystals on top, and inside its dark panel the
## title in coloured capitals, a hairline, the card's sentence, the rarity line, a hairline and two small icons (the
## card's own symbol and the rarity gem, CardMark). Rarity also shows as a glow behind the frame (none on a common
## card). Text that would overflow the panel steps down in size (fit_size), so long Spanish lines stay inside.
## It draws text it is given (already translated); it decides nothing about the game (EI-07).

## Where the text sits inside every frame (frame pixels at scale 1): one box for all twelve, inside the dark panel.
const CONTENT := Rect2(38, 230, 175, 238)
const PAD := 7.0
const TITLE_SIZES := [19, 18, 17, 16, 15, 14, 13]
const DESC_SIZES := [16, 15, 14, 13, 12]
const TITLE_MAX_LINES := 2
## The title tries one line down this many sizes before it wraps to two.
const TITLE_ONE_LINE_STEPS := 4
const ICON := 30.0
const GEM := 20.0
const TIER_SIZE := 13
const TEXT := Color(0.86, 0.88, 0.92)
## Glow strength behind the frame by tier (PickSlot.TIERS: common, rare, epic, ability); focus adds FOCUS_GLOW.
const GLOW := [0.0, 0.26, 0.4, 0.26]
const FOCUS_GLOW := 0.14
const FADE_S := 0.15
const LIFT_PX := 8.0

## Frame pixels → screen pixels (the pick panel draws cards larger than the shop).
var scale_factor := 1.0
var icon := ItemIconView.new()
var gem := CardMark.new(GEM)
var frame_id := &"amber"
var family := &"economy"
var tier := 0
var focused := false
## Sizes picked by the last layout (tests check the text fits).
var title_size := 0
var desc_size := 0
var _root := Control.new()
var _glow := TextureRect.new()
var _frame := TextureRect.new()
var _panel := Panel.new()
var _box := CardStyle.box(Vector4(0, 0, 0, 0))
var _title := Label.new()
var _desc := Label.new()
var _tier := Label.new()
var _rule_top := ColorRect.new()
var _rule_bottom := ColorRect.new()
var _icons := HBoxContainer.new()
var _id := &""
var _shown := 1.0
var _showing := false


func _init(p_scale: float = 1.0) -> void:
	name = "CrystalCard"
	scale_factor = p_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = CardFrames.SIZE * scale_factor
	_root.name = "Face"
	add_child(_root)
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_frame.name = "Frame"
	for t: TextureRect in [_glow, _frame]:
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		_root.add_child(t)
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override("panel", _box)
	_root.add_child(_panel)
	_title.name = "Title"
	_title.uppercase = true
	_desc.name = "Desc"
	_tier.name = "Tier"
	for l: Label in [_title, _desc, _tier]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_constant_override("outline_size", 0)
		l.add_theme_constant_override("line_spacing", 0)
		if l != _tier:
			_root.add_child(l)
	_tier.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.add_theme_font_override("font", HudStyle.font(true))
	_tier.add_theme_font_override("font", HudStyle.font(true))
	_desc.add_theme_font_override("font", HudStyle.font(false))
	_desc.add_theme_color_override("font_color", TEXT)
	for r: ColorRect in [_rule_top, _rule_bottom]:
		_root.add_child(r)
	_icons.name = "Icons"
	_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_icons)
	icon.custom_minimum_size = Vector2(ICON, ICON) * scale_factor
	gem.custom_minimum_size = Vector2(GEM, GEM) * scale_factor
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icons.add_child(icon)
	_icons.add_child(_tier)
	_icons.add_child(gem)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_frame(frame_id)
	_layout()


## Shows a card: `id`, translated `title` and `sentence`, its `fam` (CardFrames.family), `tier` (PickSlot.TIERS
## index), the tier's colour and its translated line.
func show_face(
	id: StringName,
	title: String,
	sentence: String,
	fam: StringName,
	p_tier: int,
	tier_color: Color,
	tier_text: String
) -> void:
	_id = id
	family = fam
	tier = p_tier
	_set_frame(CardFrames.frame_of(fam))
	var c := CardFrames.tint(frame_id)
	_title.text = title
	_title.add_theme_color_override("font_color", c.lerp(Color.WHITE, 0.15))
	_desc.text = sentence
	_tier.text = tier_text
	_tier.add_theme_color_override("font_color", Color(tier_color, 0.9))
	icon.set_item(id, c.lerp(Color.WHITE, 0.2))
	icon.visible = id != &""
	gem.color = tier_color
	gem.visible = id != &""
	for r: ColorRect in [_rule_top, _rule_bottom]:
		r.color = Color(c, 0.4)
	if not _showing:
		_showing = true
		_shown = 0.0
	_layout()
	_apply()


func set_focused(on: bool) -> void:
	focused = on
	_apply()


func title_text() -> String:
	return _title.text


func desc_text() -> String:
	return _desc.text


func tier_text() -> String:
	return _tier.text


func icon_id() -> StringName:
	return _id


func frame_texture() -> Texture2D:
	return _frame.texture


## The glow's strength now (0 on an unfocused common card).
func glow_alpha() -> float:
	return _glow.modulate.a


## The text panel's style box (inside the frame).
func panel_box() -> StyleBoxFlat:
	return _box


## The text box in this card's pixels.
func content_rect() -> Rect2:
	return Rect2(CONTENT.position * scale_factor, CONTENT.size * scale_factor)


## True when the title and the sentence fit their boxes at the sizes picked (tests).
func text_fits() -> bool:
	return _fits(_title, _title.size) and _fits(_desc, _desc.size)


## The largest size in `sizes` at which `text` wrapped to `width` is at most `max_h` tall and `max_lines` lines
## (0: any), or the smallest size when none fits.
static func fit_size(
	font: Font, text: String, width: float, max_h: float, sizes: Array, max_lines: int = 0
) -> int:
	for s: int in sizes:
		var h := text_height(font, text, width, s)
		var lines := roundi(h / font.get_height(s)) if not text.is_empty() else 0
		if h <= max_h and (max_lines <= 0 or lines <= max_lines):
			return s
	return sizes[sizes.size() - 1]


static func text_height(font: Font, text: String, width: float, s: int) -> float:
	if text.is_empty():
		return 0.0
	var flags := (
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, s, -1, flags).y


func _fits(l: Label, box: Vector2) -> bool:
	var f := l.get_theme_font("font")
	var s := l.get_theme_font_size("font_size")
	var t := l.text.to_upper() if l.uppercase else l.text
	return text_height(f, t, box.x, s) <= box.y + 0.5


func _set_frame(f: StringName) -> void:
	frame_id = f
	var tex := CardFrames.texture(f)
	_frame.texture = tex
	_glow.texture = tex


func _process(delta: float) -> void:
	if _shown >= 1.0:
		return
	_shown = move_toward(_shown, 1.0, minf(delta, 1.0 / 30.0) / FADE_S)
	modulate.a = _shown


func _apply() -> void:
	modulate.a = _shown
	var g: float = GLOW[clampi(tier, 0, GLOW.size() - 1)] + (FOCUS_GLOW if focused else 0.0)
	var gc := gem.color if tier > 0 else Color.WHITE
	_glow.modulate = Color(gc, g)
	_frame.self_modulate = Color(1, 1, 1) if focused else Color(0.8, 0.8, 0.82)
	_root.position = Vector2(0, -LIFT_PX * scale_factor if focused else 0.0)
	CardStyle.apply(_box, CardFrames.tint(frame_id), focused)
	_box.bg_color = Color(0.015, 0.018, 0.026, 0.62 if focused else 0.55)
	_box.border_color = Color(CardFrames.tint(frame_id), 0.3 if focused else 0.14)


## Places the frame, the panel and the text for scale_factor and fits the text sizes.
func _layout() -> void:
	var s := scale_factor
	var full := CardFrames.SIZE * s
	_frame.position = Vector2.ZERO
	_frame.size = full
	var grow := full * 0.06
	_glow.position = -grow * 0.5
	_glow.size = full + grow
	var box := content_rect()
	_panel.position = box.position
	_panel.size = box.size
	var inner := box.grow(-PAD * s)
	var w := inner.size.x
	var y := inner.position.y
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	# The title: one line if it fits at a readable size, else two lines.
	var t := _title.text.to_upper()
	var one: Array = _scaled(TITLE_SIZES).slice(0, TITLE_ONE_LINE_STEPS)
	title_size = fit_size(bold, t, w, bold.get_height(one[0]) + 1.0, one, 1)
	if text_height(bold, t, w, title_size) > bold.get_height(title_size) + 1.0:
		title_size = fit_size(bold, t, w, inner.size.y * 0.3, _scaled(TITLE_SIZES), TITLE_MAX_LINES)
	var th := maxf(text_height(bold, t, w, title_size), bold.get_height(title_size))
	_title.add_theme_font_size_override("font_size", title_size)
	_title.position = Vector2(inner.position.x, y)
	_title.size = Vector2(w, th)
	y += th + 3.0 * s
	_rule_top.position = Vector2(inner.position.x + w * 0.15, y)
	_rule_top.size = Vector2(w * 0.7, maxf(1.0, s))
	y += 5.0 * s
	# The bottom row: the card's icon, the rarity line and the rarity gem.
	var bottom := inner.end.y
	var icon_h := ICON * s
	var gap := roundi(7 * s)
	_icons.position = Vector2(inner.position.x, bottom - icon_h)
	_icons.size = Vector2(w, icon_h)
	_icons.add_theme_constant_override("separation", gap)
	var room := w - (ICON + GEM) * s - gap * 2
	var tier_size := roundi(TIER_SIZE * s)
	while (
		tier_size > 9
		and bold.get_string_size(_tier.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tier_size).x > room
	):
		tier_size -= 1
	_tier.add_theme_font_size_override("font_size", tier_size)
	var rule_y := bottom - icon_h - 4.0 * s
	_rule_bottom.position = Vector2(inner.position.x + w * 0.15, rule_y)
	_rule_bottom.size = Vector2(w * 0.7, maxf(1.0, s))
	var desc_h := rule_y - 3.0 * s - y
	desc_size = fit_size(regular, _desc.text, w, desc_h, _scaled(DESC_SIZES))
	_desc.add_theme_font_size_override("font_size", desc_size)
	_desc.position = Vector2(inner.position.x, y)
	_desc.size = Vector2(w, desc_h)


func _scaled(sizes: Array) -> Array:
	var out := []
	for v: int in sizes:
		out.append(maxi(10, roundi(v * scale_factor)))
	return out
