class_name StoneCard
extends Control
## A pick card as a carved stone tablet (v0.8.0 MU, owner O14 "we're just throwing away the shard cards"; G2 pick
## "menu style B", docs/roadmap/v0.8.0/evidence/MENU_G2.md; replaces v0.5.5 A4's crystal frames). From the top:
## the card's icon in a round socket with a glowing inlay ring in its element's colour (InlaySocket), the level badge
## top right ("Lv 1", "Lv 2 → 3"), the title in capitals in its family's colour (CardFrames), a glowing inlay groove
## under it, the sentence, and at the foot a carved rarity gem (CardMark) over the rarity words in the rarity's colour.
## An epic or legendary card gets a gold rim inlay; the rarity also shows as the ember glow under the tablet. The
## focused card lifts, its glow grows and its lower bevel lights up (the others are a little dimmer), so the focus
## reads by shape and light, not by colour alone (colour-blind modes; mouse and controller alike).
## Text steps down in size until it fits (TextFit); a sentence too long for the room at the smallest size reflows
## the card (a smaller socket, the title higher), so a long Spanish line never runs into the rarity gem.
## It draws text it is given (already translated); it decides nothing about the game (EI-07).
## v0.8.0 N8 (owner O62, "give it order … the ability's name on top, its icon big in the middle, and below, what gets
## better, with the old value and the new one"): from the top now: the title, the groove, the big socket (its element
## or star glyph badge kept), the gain line (CardGain: the sim's forecast, old → new; it counts up from the old value
## while the card is focused), the sentence, the gem and the rarity's word. The whole tablet is painted in its
## rarity's colour (CardPaint: the stone tinted, a frame line and the glow in it); the face hangs from a pivot
## (CardFx) that the pick panel deals, flips, tilts and burns; a focused card sinks a little instead of lifting.

## The tablet's size at scale 1 (px at the 1920 x 1080 base); the pick draws it at PickSlot.PICK_SCALE.
const SIZE := Vector2(275, 450)
## Side margin, the title's top, the big socket's size, and the compact layout's (a long sentence).
const MARGIN := 20.0
const TITLE_TOP := 36.0
const SOCKET := 112.0
const SOCKET_COMPACT := 44.0
const TITLE_TOP_COMPACT := 30.0
## v0.8.0 N8: the gain line's type size.
const GAIN_SIZE := 18
## v0.9.0 AS2: the ribbon's height and how far it runs past the card's sides (px at scale 1).
const RIBBON_H := 30.0
const RIBBON_OVERHANG := 10.0
## The foot: the rarity gem's size and centre (px above the bottom), the rarity words' band.
const GEM := 18.0
const GEM_Y := 58.0
const TIER_BOTTOM := 16.0
const TIER_SIZE := 14
const TITLE_SIZES := [22, 21, 20, 19, 18, 17, 16, 15, 14, 13]
const DESC_SIZES := [17, 16, 15, 14, 13, 12]
const TITLE_MAX_LINES := 2
const LEVEL_SIZE := 14
const TEXT := Color("#EDE3D6")
## The ember glow under the tablet by tier (PickSlot.TIERS: common, rare, epic, ability, legendary).
const UNDER := [0.18, 0.42, 0.55, 0.42, 0.8]
const IDLE_DIM := 0.84
const FADE_S := 0.15

## Card px → screen px (the pick draws cards larger than the shop and the Codex).
var scale_factor := 1.0
var socket := InlaySocket.new()
## v0.9.0 AS2 (G2 AS = B): the "Replaces <card>" / "Choose one to replace" ribbon (hidden without one, show_ribbon).
var ribbon := SlotRibbon.new()
var gem := CardMark.new(GEM)
var family := &"economy"
## The family's colour id (CardFrames.frame_of: a cursed offer's violet, an epic or legendary card's gold).
var colour_id := &"amber"
var tier := 0
var focused := false
## Sizes picked by the last layout (tests check the text fits), and whether it needed the compact layout.
var title_size := 0
var desc_size := 0
var compact := false
## v0.8.0 N8: the pivot the face hangs from (the deal, flip, tilt, light and burn).
var fx: CardFx
var _root := Control.new()
var _slab := Panel.new()
var _box := StoneBox.new()
var _title := Label.new()
var _desc := Label.new()
var _tier := Label.new()
## v0.7.5 SM (N8): the card's level badge top right ("Lv 1", "Lv 2 → 3"); hidden for a card with none.
var _level := Label.new()
var _level_box := StyleBoxFlat.new()
## v0.8.0 N8: the gain line (old → new) and its numbers (WorldReader.card_forecast), the count-up's progress (1: done).
var _gain := Label.new()
var _gain_data := {}
## v0.8.0 N8: the boxes the layout gave the title and the sentence (a Label grows past its box to hold its text, so
## the fit is checked against these).
var _title_box := Vector2.ZERO
var _desc_box := Vector2.ZERO
var _count := 1.0
var _id := &""
var _shown := 1.0
var _showing := false


func _init(p_scale: float = 1.0) -> void:
	name = "StoneCard"
	scale_factor = p_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE * scale_factor
	_root.name = "Face"
	add_child(_root)
	_slab.name = "Slab"
	_box.cut = 16.0 * p_scale
	_box.chip = 3.5 * p_scale
	_box.cracks = 3
	_slab.add_theme_stylebox_override("panel", _box)
	_root.add_child(_slab)
	_root.add_child(socket)
	_title.name = "Title"
	_title.uppercase = true
	_desc.name = "Desc"
	_tier.name = "Tier"
	for l: Label in [_title, _desc, _tier]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_constant_override("line_spacing", 0)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("outline_size", 3)
		_root.add_child(l)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc.clip_text = true  # v0.8.0 N8: it keeps its box (a stale minimum height could push it into the gem)
	_tier.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tier.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_font_override("font", HudStyle.font(true))
	_tier.add_theme_font_override("font", HudStyle.font(true))
	_desc.add_theme_font_override("font", HudStyle.font(false))
	_desc.add_theme_color_override("font_color", TEXT)
	_level.name = "Level"
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_level.add_theme_font_override("font", HudStyle.font(true))
	_level.add_theme_constant_override("outline_size", 0)
	_level_box.bg_color = Color(0.03, 0.02, 0.015, 0.8)
	_level_box.border_width_bottom = 2
	_level_box.content_margin_left = 8
	_level_box.content_margin_right = 8
	_level_box.content_margin_top = 1
	_level_box.content_margin_bottom = 1
	_level.add_theme_stylebox_override("normal", _level_box)
	_level.visible = false
	_root.add_child(_level)
	_root.add_child(gem)
	_gain.name = "Gain"
	_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gain.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gain.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_gain.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_gain.add_theme_font_override("font", HudStyle.font(true))
	_gain.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_gain.add_theme_constant_override("outline_size", 4)
	_gain.visible = false
	_root.add_child(_gain)
	_root.add_child(ribbon)
	remove_child(_root)
	fx = CardFx.new(_root)  # v0.8.0 N8: the face hangs from the pivot (its shine is the face's last child)
	add_child(fx)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()


## Shows a card: `id`, translated `title` and `sentence`, its `fam` (CardFrames.family), `tier` (PickSlot.TIERS
## index), the tier's colour and its translated line, the level badge's text ("" for none) and the element's colour
## (the icon and its inlay ring; default the family's).
func show_face(
	id: StringName,
	title: String,
	sentence: String,
	fam: StringName,
	p_tier: int,
	tier_color: Color,
	tier_text: String,
	level_text: String = "",
	element: Color = Color(0, 0, 0, 0)
) -> void:
	_id = id
	family = fam
	tier = p_tier
	colour_id = CardFrames.frame_of(fam)
	var c := CardFrames.tint(colour_id)
	if tier == CardFrames.LEGENDARY_TIER:  # v0.5.5 AR (X1b): a paler, brighter gold
		c = CardFrames.LEGENDARY_TINT
	var elem := element if element.a > 0.0 else c
	_title.text = title
	_title.add_theme_color_override("font_color", c.lerp(Color.WHITE, 0.35))
	_desc.text = sentence
	_tier.text = tier_text
	_tier.add_theme_color_override("font_color", tier_color.lightened(0.12))
	_level.text = level_text  # v0.7.5 SM
	_level.visible = level_text != ""
	_level.add_theme_color_override("font_color", EmberStone.EMBER.lightened(0.3))
	_level_box.border_color = Color(EmberStone.EMBER, 0.6)
	socket.show_item(id, elem.lerp(Color.WHITE, 0.15), elem if id != &"" else Color(1, 1, 1, 0.12))
	if tier == CardFrames.LEGENDARY_TIER and id != &"":  # v0.8.0 N1 (D42): the legendary tier's star burst
		socket.element = &"star"
	gem.color = tier_color
	gem.visible = id != &""
	_box.pattern = hash(id) % 997
	_box.inlay = c
	_box.rim = (
		EmberStone.GOLD if tier == 2 or tier == CardFrames.LEGENDARY_TIER else Color(0, 0, 0, 0)
	)
	_box.fill = CardPaint.face(tier_color)  # v0.8.0 N8 (O62): the whole card in its rarity's colour
	_box.edge = tier_color
	_box.glow_color = tier_color
	fx.paint(
		tier,
		tier_color,
		tier == CardFrames.LEGENDARY_TIER and id != &"",
		not HudStyle.reduced_motion
	)
	if not _showing:
		_showing = true
		_shown = 0.0
	_layout()
	_apply()


func set_focused(on: bool) -> void:
	if on and not focused and CardGain.shows(_gain_data):
		_count = 1.0 if HudStyle.reduced_motion else 0.0  # v0.8.0 N8: the numbers count up from the old value
	focused = on
	_apply()


## v0.8.0 N8: the gain line's numbers (WorldReader.card_forecast: kind, old, new; an empty one hides the line).
## v0.9.0 AS2 (G2 AS = B): the ribbon across the card ("" hides it): it sits above the rarity gem and the sentence
## keeps clear of it, so it never covers the name or the icon.
func show_ribbon(text: String) -> void:
	ribbon.text = text
	ribbon.visible = text != ""
	_layout()


func show_gain(gain: Dictionary) -> void:
	_gain_data = gain
	_count = 1.0
	_gain.visible = CardGain.shows(gain)
	_gain.text = CardGain.final_text(self, gain) if _gain.visible else ""
	_gain.add_theme_color_override("font_color", EmberStone.EMBER.lightened(0.35))
	_layout()


## v0.8.0 N8: the gain line as shown now ("" for none), and the new number it shows (counting up while focused).
func gain_text() -> String:
	return _gain.text if _gain.visible else ""


func gain_value() -> int:
	return CardGain.value_at(_gain_data, _count)


func title_text() -> String:
	return _title.text


func desc_text() -> String:
	return _desc.text


func tier_text() -> String:
	return _tier.text


## v0.7.5 SM: the level badge's text ("" when the card shows none).
func level_text() -> String:
	return _level.text if _level.visible else ""


## v0.7.5 SM: the level badge's rect in this card's pixels (tests: it stays on the card).
func level_rect() -> Rect2:
	return Rect2(_level.position, _level.size)


func icon_id() -> StringName:
	return _id


## The tablet's style box (tests: the card is carved stone, focus and rim).
func panel_box() -> StoneBox:
	return _box


## The ember glow's strength now (the rarity's glow, grown by the focus).
func glow_alpha() -> float:
	return _box.under * 0.55 + _box.focus * 0.9


## How far the focused card moves (px; 0 unfocused): v0.8.0 N8 (O62) it sinks a little (and shrinks), so focus still
## reads by shape, not by colour alone.
func lift() -> float:
	return CardFx.SINK_PX * fx.sink * fx.pivot.scale.y


## The sentence's box and the rarity gem's, in this card's pixels (tests: they never overlap).
func desc_rect() -> Rect2:
	return Rect2(_desc.position, _desc.size)


func gem_rect() -> Rect2:
	return Rect2(gem.position, gem.size)


## The text area in this card's pixels (inside the margins).
func content_rect() -> Rect2:
	var s := scale_factor
	return Rect2(Vector2(MARGIN, 0) * s, Vector2(SIZE.x - MARGIN * 2.0, SIZE.y) * s)


## True when the title and the sentence fit their boxes at the sizes picked (tests).
func text_fits() -> bool:
	return _fits(_title, _title_box) and _fits(_desc, _desc_box)


func _fits(l: Label, box: Vector2) -> bool:
	var f := l.get_theme_font("font")
	var t := l.text.to_upper() if l.uppercase else l.text
	return TextFit.text_height(f, t, box.x, l.get_theme_font_size("font_size")) <= box.y + 0.5


func _process(delta: float) -> void:
	if _count < 1.0:  # v0.8.0 N8: the count-up
		_count = minf(1.0, _count + delta / CardGain.COUNT_S)
		_gain.text = CardGain.text(self, _gain_data, gain_value())
	if _shown >= 1.0:
		return
	_shown = move_toward(_shown, 1.0, minf(delta, 1.0 / 30.0) / FADE_S)
	modulate.a = _shown


func _apply() -> void:
	modulate.a = _shown
	_box.under = UNDER[clampi(tier, 0, UNDER.size() - 1)]
	_box.focus = 1.0 if focused else 0.0
	_box.dim = 1.0 if focused else IDLE_DIM
	socket.glow = 1.0 if focused else 0.0
	fx.set_hover(fx.tilt, 1.0 if focused else 0.0)  # v0.8.0 N8: the focused card sinks a little
	_root.modulate = Color.WHITE if focused else Color(0.9, 0.9, 0.9)


## Places the slab, the title, the socket, the gain line, the sentence and the foot for scale_factor and fits the
## text sizes; a sentence that does not fit at the smallest size takes the compact layout (a smaller socket).
func _layout() -> void:
	compact = false
	_place(SOCKET, TITLE_TOP)
	if not text_fits():
		compact = true
		_place(SOCKET_COMPACT, TITLE_TOP_COMPACT)


func _place(socket_px: float, title_top: float) -> void:
	var s := scale_factor
	var full := SIZE * s
	_slab.position = Vector2.ZERO
	_slab.size = full
	fx.lay_out(full)
	var w := (SIZE.x - MARGIN * 2.0) * s
	var x := MARGIN * s
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	# The foot: the gem over the rarity words.
	var g := GEM * s
	gem.custom_minimum_size = Vector2(g, g)
	gem.size = Vector2(g, g)
	gem.position = Vector2((full.x - g) * 0.5, full.y - GEM_Y * s - g * 0.5)
	var tier_size := roundi(TIER_SIZE * s)
	while (
		tier_size > 10
		and bold.get_string_size(_tier.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tier_size).x > w
	):
		tier_size -= 1
	_tier.add_theme_font_size_override("font_size", tier_size)
	var tier_h := bold.get_height(tier_size)
	_tier.position = Vector2(x, full.y - TIER_BOTTOM * s - tier_h)
	_tier.size = Vector2(w, tier_h)
	# v0.8.0 N8: the title on top: one line if it fits at a readable size, else two.
	var y := title_top * s
	var t := _title.text.to_upper()
	var sizes := _scaled(TITLE_SIZES)
	var one: Array = sizes.slice(0, 5)
	title_size = TextFit.fit_size(bold, t, w, bold.get_height(one[0]) + 1.0, one, 1)
	if TextFit.text_height(bold, t, w, title_size) > bold.get_height(title_size) + 1.0:
		title_size = TextFit.fit_size(
			bold, t, w, bold.get_height(sizes[0]) * 2.0 + 1.0, sizes, TITLE_MAX_LINES
		)
	title_size = mini(title_size, TextFit.word_fit_size(bold, t, w, title_size))  # v0.8.0 N18: a long word shrinks
	var th := maxf(TextFit.text_height(bold, t, w, title_size), bold.get_height(title_size))
	_title.add_theme_font_size_override("font_size", title_size)
	_title.position = Vector2(x, y)
	_title.size = Vector2(w, th)
	_title_box = Vector2(w, th)
	y += th + 6.0 * s
	_box.inlay_y = full.y - y  # the glowing groove under the title
	y += 8.0 * s
	# The big icon in the middle.
	var side := socket_px * s
	socket.position = Vector2((full.x - side) * 0.5, y)
	socket.size = Vector2(side, side)
	y += side + 8.0 * s
	# What gets better (old → new), when the card has a number.
	if _gain.visible:
		var gs := maxi(11, roundi(GAIN_SIZE * s))
		while gs > 11 and bold.get_string_size(_gain.text, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x > w:
			gs -= 1
		_gain.add_theme_font_size_override("font_size", gs)
		var gh := bold.get_height(gs)
		_gain.position = Vector2(x, y)
		_gain.size = Vector2(w, gh)
		y += gh + 6.0 * s
	# The sentence: between the gain line and the gem, never into it.
	var bottom := gem.position.y - 10.0 * s
	if ribbon.visible:  # v0.9.0 AS2: the ribbon's band over the gem; the sentence ends above it
		var rh := RIBBON_H * s
		ribbon.scale_factor = s
		ribbon.size = Vector2(full.x + 2.0 * RIBBON_OVERHANG * s, rh)
		ribbon.position = Vector2(-RIBBON_OVERHANG * s, bottom - rh)
		bottom -= rh + 8.0 * s
	var desc_h := maxf(bottom - y, 0.0)
	var dsizes := _scaled(DESC_SIZES)
	desc_size = TextFit.fit_size(regular, _desc.text, w, desc_h, dsizes)
	_desc.add_theme_font_size_override("font_size", desc_size)
	_desc.position = Vector2(x, y)
	_desc.size = Vector2(w, desc_h)
	_desc_box = Vector2(w, desc_h)
	# v0.7.5 SM: the level badge top right, above the title.
	_level.add_theme_font_size_override("font_size", maxi(10, roundi(LEVEL_SIZE * s)))
	_level.reset_size()
	var ls := _level.get_combined_minimum_size()
	_level.size = ls
	_level.position = Vector2(full.x - ls.x - 16.0 * s, 9.0 * s)


func _scaled(sizes: Array) -> Array:
	var out := []
	for v: int in sizes:
		out.append(maxi(10, roundi(v * scale_factor)))
	return out
