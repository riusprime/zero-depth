extends RefCounted
## v0.8.0 MU (G2, owner O14: "we're just throwing away the shard cards we're gonna be using a different style that
## matches more the game"): three mockup directions for the menus and the cards, each built here as plain Controls
## over the real game, from real data the shot scripts pass in (card faces from PickPanel.card_face, the wand from
## WorldReader.wand(), every string through tr()). Drawn in code only (MuShaders: no image assets).
##   A "Salvage"     - weathered gunmetal plates, rivets, scratches and rust edges, spray-stencil titles, hazard amber;
##                     a card is a riveted metal tag with a punched hole and its family's colour as worn paint.
##   B "Ember stone" - dark carved stone slabs lit from below by a warm ember glow, chipped bevelled edges; a card is
##                     a stone tablet with a glowing inlay in its element colour (a gold rim when epic).
##   C "Field kit"   - minimal charcoal panels with a thin warm-orange edge light and a soft vignette, faceted hexagon
##                     icon frames like the kit's shapes; a card is a dark faceted plaque with a coloured top band.
## A tool for the G2 shots only (scripts/shots/mock_main_menu.gd, mock_pick.gd, mock_build.gd); nothing in the shipped
## game loads it. Rarity keeps PickSlot.TIERS' colours and the family keeps CardFrames' tints in every direction.

enum Dir { SALVAGE, EMBER, FIELD }

const Shaders := preload("res://scripts/shots/mu_shaders.gd")

## Labels the shots carry (evidence captions, not game text) and the file names' prefixes.
const CAPTIONS := ["A  Salvage", "B  Ember stone", "C  Field kit"]
const SLUGS := ["a_salvage", "b_ember_stone", "c_field_kit"]
## Per direction: the type, the dim type and the accent (A hazard amber, B ember, C warm orange).
const TEXT := [Color("#E9E3D7"), Color("#F3E9DD"), Color("#ECEAE6")]
const DIM := [Color("#ABA396"), Color("#BBA995"), Color("#989A9E")]
const ACCENT := [Color("#F2A81D"), Color("#F28A3A"), Color("#F08A3C")]
## The pick card, a wand tile (px at the 1920 x 1080 base), the gap and a trigger cut's room in the wand row.
const CARD := Vector2(330, 540)
const TILE := Vector2(150, 178)
const TILE_GAP := 10.0
const CUT := 40.0
const LIFT := 14.0
## Room round a pick card for its shadow and focus glow (px).
const CARD_PAD := 30.0

static var _fonts := {}
static var _shader_cache := {}


## The shader for `code` (built once).
static func shader(code: String) -> Shader:
	if not _shader_cache.has(code):
		var s := Shader.new()
		s.code = code
		_shader_cache[code] = s
	return _shader_cache[code]


## The bundled Atkinson type with `spacing` px between glyphs (A spaces its stencil type, C its titles).
static func font(bold: bool, spacing: int = 0) -> Font:
	var key := "%s_%d" % [bold, spacing]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = HudStyle.font(bold).base_font
		v.spacing_glyph = spacing
		_fonts[key] = v
	return _fonts[key]


## A label in the direction's type (text already translated).
static func label(dir: int, text: String, px: int, bold := false, c: Variant = null) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.add_theme_font_override("font", font(bold, 1 if dir == Dir.SALVAGE and bold else 0))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", TEXT[dir] if c == null else c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4 if px < 30 else 6)
	return l


## A screen title in the direction's voice: A spray-stencilled capitals, B warm carved capitals with an ember halo,
## C light spaced type.
static func title(dir: int, text: String, px: int) -> Label:
	var l := label(dir, text, px, dir != Dir.FIELD)
	l.uppercase = true
	match dir:
		Dir.SALVAGE:
			l.add_theme_font_override("font", font(true, 6))
			var m := ShaderMaterial.new()
			m.shader = shader(Shaders.STENCIL_TYPE)
			l.material = m
		Dir.EMBER:
			l.add_theme_font_override("font", font(true, 3))
			l.add_theme_color_override("font_shadow_color", Color(ACCENT[dir], 0.32))
			l.add_theme_constant_override("shadow_outline_size", 16)
			l.add_theme_constant_override("shadow_offset_y", 3)
		Dir.FIELD:
			l.add_theme_font_override("font", font(false, 8))
	return l


## Puts the direction's plate behind `parent` (its shape fills the parent's rect; `pad` px around it hold the shadow
## and the glow). `params` are the shader's uniforms.
static func plate(dir: int, parent: Control, params: Dictionary = {}, pad: float = 18.0) -> Plate:
	var code: String = [Shaders.SALVAGE, Shaders.EMBER_STONE, Shaders.FIELD_KIT][dir]
	var p := Plate.new(shader(code), pad, params)
	parent.add_child(p)
	parent.move_child(p, 0)
	return p


## The full-screen backdrop: the game blurred and dimmed in the direction's light.
static func backdrop(dir: int, strength: float = 1.0, lod: float = 2.4) -> ColorRect:
	var r := ColorRect.new()
	r.name = "MuBackdrop"
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = shader(Shaders.BACKDROP)
	m.set_shader_parameter(&"mode", dir)
	m.set_shader_parameter(&"strength", strength)
	m.set_shader_parameter(&"lod", lod)
	r.material = m
	return r


## The evidence caption ("A  Salvage") at the top centre of a shot.
static func caption(dir: int, screen_name: String) -> Control:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = "%s  ·  %s" % [CAPTIONS[dir], screen_name]
	l.add_theme_font_override("font", font(true))
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.6)
	box.set_content_margin_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	l.add_theme_stylebox_override("normal", box)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = 8
	return l


# --- Main menu ---------------------------------------------------------------------------------------------------


## The main menu: the title, `rows` (translation keys) with row `focus` lit, the hint and the version.
static func menu_screen(dir: int, ci: Object, rows: Array, focus: int, version: String) -> Control:
	var root := _screen_root()
	root.add_child(backdrop(dir))
	var col := Control.new()
	col.position = Vector2(150, 150)
	col.size = Vector2(540, 790)
	root.add_child(col)
	if dir == Dir.SALVAGE:
		plate(dir, col, {&"hazard": 14.0, &"seed": 0.37, &"cut": 18.0}, 22.0)
	elif dir == Dir.EMBER:
		plate(dir, col, {&"under": 0.55, &"seed": 0.21, &"cut": 22.0}, 30.0)
	var t := title(dir, ci.tr("UI_TITLE"), 60 if dir != Dir.FIELD else 54)
	t.position = Vector2(56, 56)
	t.size = Vector2(440, 80)
	col.add_child(t)
	_title_rule(dir, col, Vector2(58, 150), 300.0)
	var y := 200.0
	for k in rows.size():
		var row := _menu_row(dir, ci.tr(rows[k]), k == focus)
		row.position = Vector2(40, y)
		col.add_child(row)
		y += 66.0
	var hint := label(dir, ci.tr("UI_MENU_HINT"), 16, false, Color(DIM[dir], 0.85))
	hint.position = Vector2(58, col.size.y - 62)
	col.add_child(hint)
	var ver := label(dir, version, 16, dir == Dir.SALVAGE, Color(DIM[dir], 0.7))
	ver.position = Vector2(1920 - 220, 1080 - 50)
	root.add_child(ver)
	return root


## Under a title: A a hazard-striped bar, B a glowing ember groove, C a short warm hairline.
static func _title_rule(dir: int, parent: Control, at: Vector2, w: float) -> void:
	var r := Control.new()
	r.position = at
	r.size = Vector2(w, 12)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	r.draw.connect(
		func() -> void:
			match dir:
				Dir.SALVAGE:
					r.draw_rect(Rect2(0, 0, w, 10), Color(0.06, 0.05, 0.04))
					var x := -10.0
					while x < w:
						var pts := PackedVector2Array(
							[
								Vector2(maxf(x, 0), 10),
								Vector2(minf(x + 10, w), 0),
								Vector2(minf(x + 20, w), 0),
								Vector2(minf(x + 10, w), 10)
							]
						)
						if x + 10 > 0:
							r.draw_colored_polygon(pts, Color(ACCENT[dir], 0.85))
						x += 20.0
				Dir.EMBER:
					r.draw_rect(Rect2(0, 4, w, 3), Color(ACCENT[dir], 0.9))
					r.draw_rect(Rect2(0, 0, w, 11), Color(ACCENT[dir], 0.14))
				Dir.FIELD:
					r.draw_rect(Rect2(0, 5, w * 0.35, 2), Color(ACCENT[dir], 0.95))
	)


## One menu row: the label, and when focused the direction's mark (A an amber-painted tag plate with a chevron,
## B a small ember-lit slab with an inlay groove, C a charcoal plaque with the warm edge light and a hex marker).
static func _menu_row(dir: int, text: String, focused: bool) -> Control:
	var row := Control.new()
	row.size = Vector2(440, 56)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(dir, text, 28, true, TEXT[dir] if focused else Color(DIM[dir], 0.92))
	if dir == Dir.SALVAGE:
		l.uppercase = true
		l.add_theme_font_override("font", font(true, 3))
		l.add_theme_font_size_override("font_size", 25)
	l.position = Vector2(46, 0)
	l.size = Vector2(380, 56)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	if not focused:
		return row
	match dir:
		Dir.SALVAGE:
			plate(
				dir,
				row,
				{
					&"base": Color(0.5, 0.36, 0.12),
					&"stripe": ACCENT[dir],
					&"stripe_w": 14.0,
					&"focus": 0.7,
					&"rust": 0.6,
					&"cut": 8.0,
					&"rivets": 0.0,
					&"seed": 0.8
				},
				14.0
			)
			l.add_theme_color_override("font_color", Color("#FFF4DC"))
		Dir.EMBER:
			plate(
				dir,
				row,
				{
					&"under": 0.4,
					&"focus": 0.9,
					&"inlay": ACCENT[dir],
					&"inlay_y": 14.0 + 50.0,
					&"seed": 0.6,
					&"cut": 8.0
				},
				14.0
			)
		Dir.FIELD:
			plate(dir, row, {&"focus": 0.85, &"cut": 12.0}, 14.0)
	_row_marker(dir, row)
	return row


static func _row_marker(dir: int, row: Control) -> void:
	var m := Control.new()
	m.position = Vector2(16, 16)
	m.size = Vector2(22, 24)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(m)
	m.draw.connect(
		func() -> void:
			var c := Vector2(11, 12)
			match dir:
				Dir.SALVAGE:
					m.draw_colored_polygon(
						PackedVector2Array([Vector2(4, 2), Vector2(18, 12), Vector2(4, 22)]),
						Color("#1A1206")
					)
				Dir.EMBER:
					var pts := PackedVector2Array(
						[
							c + Vector2(0, -10),
							c + Vector2(7, 0),
							c + Vector2(0, 10),
							c + Vector2(-7, 0)
						]
					)
					m.draw_colored_polygon(pts, ACCENT[dir])
					m.draw_colored_polygon(
						PackedVector2Array([pts[0], pts[1], c]), Color(1, 0.9, 0.7, 0.8)
					)
				Dir.FIELD:
					_draw_hex(m, c, 10.0, ACCENT[dir])
	)


# --- Shapes ------------------------------------------------------------------------------------------------------


## A faceted hexagon on `ci`: six facets in two tones of `c` around a darker core (C's icon frames and marker).
static func _draw_hex(ci: CanvasItem, c: Vector2, r: float, col: Color, core: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for k in 6:
		var a := deg_to_rad(60.0 * k - 90.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	for k in 6:
		var shade := [1.0, 0.82, 0.62, 0.55, 0.7, 0.9][k] as float
		ci.draw_colored_polygon(
			PackedVector2Array([c, pts[k], pts[(k + 1) % 6]]), Color(col * shade, col.a)
		)
	if core > 0.0:
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * core)
		ci.draw_colored_polygon(inner, Color(0.07, 0.075, 0.085))


## A rarity gem: a faceted diamond in `col` (lit and shaded halves), with a glow on B.
static func _draw_gem(ci: CanvasItem, dir: int, c: Vector2, r: float, col: Color) -> void:
	if dir == Dir.EMBER:
		for k in 4:
			ci.draw_circle(c, r * (2.2 - k * 0.35), Color(col, 0.06))
	var top := c + Vector2(0, -r)
	var right := c + Vector2(r * 0.8, 0)
	var bottom := c + Vector2(0, r)
	var left := c + Vector2(-r * 0.8, 0)
	ci.draw_colored_polygon(PackedVector2Array([top, right, bottom]), col.darkened(0.3))
	ci.draw_colored_polygon(PackedVector2Array([top, bottom, left]), col.lightened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([top, right, c]), col.lightened(0.4))


## The icon's frame, `px` square at `at` in `parent`, with the card's icon in its element colour inside: A a riveted
## square socket sunk into the metal, B a round carved socket (the inlay ring is the plate's), C a faceted hexagon.
static func icon_frame(
	dir: int, parent: Control, at: Vector2, px: float, id: StringName, col: Color
) -> void:
	var f := Control.new()
	f.position = at
	f.size = Vector2(px, px)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(f)
	f.draw.connect(
		func() -> void:
			var r := Rect2(Vector2.ZERO, f.size)
			var c := f.size * 0.5
			match dir:
				Dir.SALVAGE:
					f.draw_rect(r, Color(0.05, 0.05, 0.05, 0.95))
					f.draw_rect(Rect2(3, 3, px - 6, px - 6), Color(0.1, 0.1, 0.095))
					f.draw_line(Vector2(0, px - 1), Vector2(px, px - 1), Color(1, 1, 1, 0.16), 2.0)
					f.draw_line(Vector2(px - 1, 0), Vector2(px - 1, px), Color(1, 1, 1, 0.1), 2.0)
					for p: Vector2 in [
						Vector2(8, 8),
						Vector2(px - 8, 8),
						Vector2(8, px - 8),
						Vector2(px - 8, px - 8)
					]:
						f.draw_circle(p, 3.0, Color(0.55, 0.52, 0.48))
						f.draw_circle(p + Vector2(-0.8, -0.8), 1.4, Color(0.85, 0.82, 0.76))
				Dir.EMBER:
					f.draw_circle(c, px * 0.5 - 3.0, Color(0.035, 0.028, 0.024))
					f.draw_arc(
						c, px * 0.5 - 4.0, PI * 0.1, PI * 0.9, 24, Color(ACCENT[dir], 0.35), 2.0
					)
				Dir.FIELD:
					_draw_hex(f, c, px * 0.5, Color(col.darkened(0.35), 1.0), 0.8)
	)
	var icon := ItemIconView.new()
	var inset := px * (0.2 if dir == Dir.SALVAGE else 0.24)
	icon.position = Vector2(inset, inset)
	icon.size = Vector2(px - inset * 2, px - inset * 2)
	icon.set_item(id, col)
	f.add_child(icon)


# --- The pick panel ------------------------------------------------------------------------------------------------


## The 3-card pick over the paused game: `title`, the cards (`faces` from PickPanel.card_face; `focus` lit and
## lifted) and the hint.
static func pick_screen(
	dir: int, faces: Array, focus: int, title_text: String, hint_text: String
) -> Control:
	var root := _screen_root()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.color = [
		Color(0.04, 0.035, 0.03, 0.5), Color(0.03, 0.015, 0.01, 0.55), Color(0.02, 0.025, 0.03, 0.5)
	][dir]
	var total := CARD.x * faces.size() + 34.0 * (faces.size() - 1)
	var x0 := (1920.0 - total) * 0.5
	var y0 := 250.0
	var head := title(dir, title_text, 34)
	head.uppercase = dir != Dir.FIELD
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, y0 - 104)
	head.size = Vector2(1920, 50)
	root.add_child(head)
	_title_rule(dir, root, Vector2(960 - 150, y0 - 46), 300.0)
	for k in faces.size():
		var card := _card(dir, faces[k], k == focus)
		card.position = Vector2(x0 + k * (CARD.x + 34.0), y0 + (0.0 if k == focus else LIFT))
		root.add_child(card)
	var hint := label(dir, hint_text, 17, false, Color(DIM[dir], 0.95))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, y0 + CARD.y + 52)
	hint.size = Vector2(1920, 30)
	root.add_child(hint)
	return root


## One pick card in the direction's look: the family colour (CardFrames), the element colour on the icon (and B's
## inlay), the rarity colour on the gem and the rarity line, the level badge, and the focus.
static func _card(dir: int, face: Dictionary, focused: bool) -> Control:
	var card := Control.new()
	card.size = CARD
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tier := int(face["tier"])
	var fam := CardFrames.family(face["id"], int(face["type"]), tier)
	var fam_col := CardFrames.tint(CardFrames.frame_of(fam))
	var rarity: Color = PickSlot.TIERS[clampi(tier, 0, PickSlot.TIERS.size() - 1)]
	var elem: Color = face["color"]
	var grand := tier == 2 or tier == CardFrames.LEGENDARY_TIER
	var icon_px := 96.0
	var icon_at := Vector2((CARD.x - icon_px) * 0.5, 0)
	var title_y := 0.0
	match dir:
		Dir.SALVAGE:
			plate(
				dir,
				card,
				{
					&"band": fam_col.darkened(0.15),
					&"band_h": 58.0,
					&"hole": 1.0,
					&"hazard": 14.0 if grand else 0.0,
					&"focus": 1.0 if focused else 0.0,
					&"seed": float(hash(face["id"]) % 97) / 9.7,
					&"cut": 16.0
				},
				CARD_PAD
			)
			icon_at.y = 80.0
			title_y = 190.0
		Dir.EMBER:
			icon_at.y = 62.0
			title_y = 180.0
			plate(
				dir,
				card,
				{
					&"inlay": elem,
					&"inlay_rect":
					Vector4(
						CARD_PAD + icon_at.x - 6,
						CARD_PAD + icon_at.y - 6,
						icon_px + 12,
						icon_px + 12
					),
					&"inlay_round": 1.0,
					&"inlay_y": CARD_PAD + 262.0,
					&"rim": CardFrames.tint(&"gold") if grand else Color(0, 0, 0, 0),
					&"under": 0.3,
					&"focus": 1.0 if focused else 0.0,
					&"seed": float(hash(face["id"]) % 97) / 9.7,
					&"cut": 18.0
				},
				CARD_PAD
			)
		Dir.FIELD:
			plate(
				dir,
				card,
				{
					&"band": fam_col.darkened(0.1),
					&"band_h": 70.0,
					&"focus": 1.0 if focused else 0.0,
					&"edge": 0.5,
					&"cut": 22.0
				},
				CARD_PAD
			)
			icon_at.y = 22.0
			title_y = 140.0
	icon_frame(dir, card, icon_at, icon_px, face["id"], elem)
	_level_badge(dir, card, face)
	var m := 26.0
	var w := CARD.x - m * 2
	var head_col: Color = TEXT[dir] if dir != Dir.EMBER else fam_col.lerp(Color.WHITE, 0.35)
	var t := label(dir, face["title"], 24, true, head_col)
	t.uppercase = true
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tf := t.get_theme_font("font")
	var ts := CrystalCard.fit_size(
		tf, face["title"].to_upper(), w, 64.0, [26, 24, 22, 20, 18, 17, 16], 2
	)
	t.add_theme_font_size_override("font_size", ts)
	t.position = Vector2(m, title_y)
	t.size = Vector2(w, 66)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(t)
	if dir != Dir.EMBER:
		_hairline(dir, card, Vector2(m + 30, title_y + 74), w - 60, fam_col)
	var desc_y := title_y + 88.0
	var desc_h := CARD.y - desc_y - 96.0
	var d := label(dir, face["sentence"], 19, false, Color(TEXT[dir], 0.9))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ds := CrystalCard.fit_size(
		d.get_theme_font("font"), face["sentence"], w, desc_h, [20, 19, 18, 17, 16, 15, 14, 13]
	)
	d.add_theme_font_size_override("font_size", ds)
	d.position = Vector2(m, desc_y)
	d.size = Vector2(w, desc_h)
	card.add_child(d)
	_rarity_line(dir, card, face["tier_text"], rarity)
	card.modulate = Color.WHITE if focused else Color(0.84, 0.84, 0.86)
	return card


## A thin rule in the card's family colour: A an engraved line (dark over light), C the colour at low alpha.
static func _hairline(dir: int, parent: Control, at: Vector2, w: float, col: Color) -> void:
	var r := Control.new()
	r.position = at
	r.size = Vector2(w, 4)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	r.draw.connect(
		func() -> void:
			if dir == Dir.SALVAGE:
				r.draw_line(Vector2(0, 0), Vector2(w, 0), Color(0, 0, 0, 0.7), 2.0)
				r.draw_line(Vector2(0, 2), Vector2(w, 2), Color(1, 1, 1, 0.12), 1.0)
			else:
				r.draw_line(Vector2(0, 1), Vector2(w, 1), Color(col, 0.55), 1.0)
	)


## The card's level badge ("Lv 1", "Lv 1 → 2") top right: A a stamped dark plate, B carved warm type, C a dark pill
## on the band.
static func _level_badge(dir: int, card: Control, face: Dictionary) -> void:
	var text: String = face.get("level_text", "")
	if text.is_empty():
		return
	var l := label(
		dir, text, 16, true, TEXT[dir] if dir != Dir.EMBER else ACCENT[dir].lightened(0.3)
	)
	var box := StyleBoxFlat.new()
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	match dir:
		Dir.SALVAGE:
			box.bg_color = Color(0.06, 0.06, 0.055, 0.92)
			box.border_color = Color(1, 1, 1, 0.14)
			box.border_width_bottom = 1
		Dir.EMBER:
			box.bg_color = Color(0.03, 0.02, 0.015, 0.75)
			box.border_color = Color(ACCENT[dir], 0.55)
			box.border_width_bottom = 2
		Dir.FIELD:
			box.bg_color = Color(0.05, 0.055, 0.06, 0.9)
			box.set_corner_radius_all(3)
	l.add_theme_stylebox_override("normal", box)
	l.position = Vector2(CARD.x - 30 - 84, 76 if dir == Dir.SALVAGE else 28)
	l.size = Vector2(84, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(l)


## The rarity line at the card's foot: the gem and the rarity words in the rarity colour (A on a stamped strip with a
## painted tab, B under a carved glowing gem, C after a thin rarity rule).
static func _rarity_line(dir: int, card: Control, text: String, col: Color) -> void:
	var foot := Control.new()
	foot.position = Vector2(26, CARD.y - 84)
	foot.size = Vector2(CARD.x - 52, 56)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(foot)
	var w := foot.size.x
	foot.draw.connect(
		func() -> void:
			match dir:
				Dir.SALVAGE:
					foot.draw_rect(Rect2(0, 12, w, 34), Color(0.05, 0.05, 0.045, 0.9))
					foot.draw_rect(Rect2(0, 12, 34, 34), col.darkened(0.25))
					_draw_gem(foot, dir, Vector2(17, 29), 10.0, col.lightened(0.2))
					foot.draw_line(Vector2(0, 46), Vector2(w, 46), Color(1, 1, 1, 0.12), 1.0)
				Dir.EMBER:
					_draw_gem(foot, dir, Vector2(w * 0.5, 10), 11.0, col)
				Dir.FIELD:
					foot.draw_line(Vector2(0, 12), Vector2(w, 12), Color(col, 0.6), 1.0)
					_draw_gem(foot, dir, Vector2(12, 33), 9.0, col)
	)
	var l := label(dir, text, 16, true, col.lightened(0.1))
	l.uppercase = dir == Dir.SALVAGE
	if dir == Dir.SALVAGE:
		l.add_theme_font_override("font", font(true, 2))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	match dir:
		Dir.SALVAGE:
			l.position = Vector2(44, 12)
			l.size = Vector2(w - 50, 34)
		Dir.EMBER:
			l.position = Vector2(0, 24)
			l.size = Vector2(w, 30)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Dir.FIELD:
			l.position = Vector2(28, 18)
			l.size = Vector2(w - 28, 30)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(l)


# --- The Build page ----------------------------------------------------------------------------------------------


## The pause menu's Build page: the title, the slot note, the wand (`wand`: WorldReader.wand(); tile `focus` lit),
## the brackets, the read-back, the hint and Back. `ci` translates.
static func build_screen(dir: int, ci: Object, wand: Dictionary, focus: int) -> Control:
	var root := _screen_root()
	root.add_child(backdrop(dir))
	var cards: Array = wand.get("cards", [])
	var slots := maxi(int(wand.get("slots", cards.size())), cards.size())
	var left := 180.0
	var t := title(dir, ci.tr("UI_BUILD_TITLE"), 56)
	t.position = Vector2(left, 168)
	t.size = Vector2(900, 70)
	root.add_child(t)
	_title_rule(dir, root, Vector2(left + 2, 246), 300.0)
	var note := label(dir, ci.tr("UI_BUILD_SLOTS") % [cards.size(), slots], 19, false, DIM[dir])
	note.position = Vector2(left, 270)
	root.add_child(note)
	var row := _wand_row(dir, ci, cards, slots, focus)
	row.position = Vector2(left, 330)
	root.add_child(row)
	var lines := WorldReader.wand_describe(wand)
	var text := WorldReader.wand_render(lines, func(k: StringName) -> String: return ci.tr(k))
	var rb := label(dir, text, 22, false, TEXT[dir])
	rb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rb.position = Vector2(left, 330 + row.size.y + 36)
	rb.size = Vector2(1240, 0)
	root.add_child(rb)
	var hint := label(dir, ci.tr("UI_BUILD_HINT"), 15, false, Color(DIM[dir], 0.85))
	hint.position = Vector2(left, 950)
	root.add_child(hint)
	var back := label(dir, ci.tr("UI_BACK"), 26, true, Color(DIM[dir], 0.92))
	back.uppercase = dir == Dir.SALVAGE
	back.position = Vector2(left, 985)
	root.add_child(back)
	return root


## The wand as a row of tiles, a cut after each trigger card and a bracket under each part (WandRow's layout).
static func _wand_row(dir: int, ci: Object, cards: Array, slots: int, focus: int) -> Control:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 0.0
	var seg_from := 0.0
	var depth := 0
	var spans: Array = []
	var cuts: Array[float] = []
	var keys: Array[String] = ["UI_WAND_CUT_FIRE"]
	for k in slots:
		var tile := _tile(dir, ci, cards[k] if k < cards.size() else {}, k, k == focus)
		tile.position = Vector2(x, 0.0 if k == focus else LIFT)
		row.add_child(tile)
		x += TILE.x
		var trig := int(cards[k]["trigger"]) if k < cards.size() else -1
		if trig >= 0 and k < slots - 1:
			spans.append([seg_from, x, depth])
			depth += 1
			var key: String = WandRow.CUT_KEYS.get(trig, "UI_WAND_CUT_ON_HIT")
			keys.append(key if depth <= WandRow.MAX_DEPTH else "UI_WAND_CUT_UNUSED")
			cuts.append(x + CUT * 0.5)
			x += CUT
			seg_from = x
		elif k < slots - 1:
			x += TILE_GAP
	spans.append([seg_from, x, depth])
	var bottom := LIFT + TILE.y
	for b in spans.size():
		var span: Array = spans[b]
		var l := label(
			dir, ci.tr(keys[b]), 15, b > 0, DIM[dir] if b == 0 else Color(ACCENT[dir], 0.95)
		)
		l.position = Vector2(float(span[0]), bottom + 18)
		l.size = Vector2(maxf(float(span[1]) - float(span[0]), TILE.x), 24)
		l.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER if b == 0 else HORIZONTAL_ALIGNMENT_LEFT
		)
		row.add_child(l)
	row.size = Vector2(x, bottom + 46)
	var deco := Control.new()
	deco.size = row.size
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(deco)
	deco.draw.connect(func() -> void: _draw_cuts(dir, deco, cuts, spans, bottom))
	if dir == Dir.SALVAGE:  # the wand rack: a long riveted board behind the tiles
		var board := Control.new()
		board.position = Vector2(-26, -20)
		board.size = Vector2(x + 52, bottom + 76)
		row.add_child(board)
		row.move_child(board, 0)
		plate(dir, board, {&"base": Color(0.17, 0.17, 0.16), &"seed": 2.3, &"cut": 14.0}, 18.0)
	elif dir == Dir.EMBER:  # a long stone shelf the tablets stand on
		var shelf := Control.new()
		shelf.position = Vector2(-30, bottom - 6)
		shelf.size = Vector2(x + 60, 58)
		row.add_child(shelf)
		row.move_child(shelf, 0)
		plate(dir, shelf, {&"under": 0.8, &"seed": 4.1, &"cut": 10.0}, 22.0)
	return row


## The cuts (A a hazard-striped post and an amber arrow, B a glowing ember groove and arrow, C a warm hairline and a
## faceted arrow) and the brackets under each part.
static func _draw_cuts(
	dir: int, ci: Control, cuts: Array[float], spans: Array, bottom: float
) -> void:
	var acc: Color = ACCENT[dir]
	var mid := (LIFT + bottom) * 0.5
	for cx in cuts:
		match dir:
			Dir.SALVAGE:
				ci.draw_rect(Rect2(cx - 4, LIFT - 4, 8, bottom - LIFT + 8), Color(0.06, 0.05, 0.04))
				var y := LIFT - 4.0
				while y < bottom:
					ci.draw_rect(Rect2(cx - 4, y, 8, 6), Color(acc, 0.85))
					y += 14.0
			Dir.EMBER:
				for k in 3:
					ci.draw_line(
						Vector2(cx, LIFT), Vector2(cx, bottom), Color(acc, 0.12), 8.0 - k * 2.5
					)
				ci.draw_line(Vector2(cx, LIFT), Vector2(cx, bottom), Color(acc, 0.9), 2.0)
			Dir.FIELD:
				ci.draw_line(Vector2(cx, LIFT - 6), Vector2(cx, bottom + 6), Color(acc, 0.85), 1.5)
		var head := PackedVector2Array(
			[Vector2(cx + 13, mid), Vector2(cx - 5, mid - 12), Vector2(cx - 5, mid + 12)]
		)
		ci.draw_colored_polygon(head, acc if dir != Dir.SALVAGE else acc.lightened(0.1))
		ci.draw_colored_polygon(
			PackedVector2Array([head[0], head[1], Vector2(cx, mid)]), Color(1, 1, 1, 0.3)
		)
	for span: Array in spans:
		var a := float(span[0]) + 4.0
		var b := float(span[1]) - 4.0
		var y := bottom + 10.0
		var c: Color = Color(DIM[dir], 0.8) if int(span[2]) == 0 else Color(acc, 0.75)
		var wdt := 2.0 if dir == Dir.SALVAGE else 1.0
		ci.draw_line(Vector2(a, y - 6.0), Vector2(a, y), c, wdt)
		ci.draw_line(Vector2(a, y), Vector2(b, y), c, wdt)
		ci.draw_line(Vector2(b, y - 6.0), Vector2(b, y), c, wdt)


## One wand tile: its key number, its icon in its frame, its name and level; the family colour (A a painted band,
## B the inlay ring, C the top band) and the focus.
static func _tile(dir: int, ci: Object, card: Dictionary, k: int, focused: bool) -> Control:
	var t := Control.new()
	t.size = TILE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := card.is_empty()
	var id: StringName = card.get("id", &"")
	var ability := not empty and int(card["type"]) == WorldReader.CARD_ABILITY
	var col := (
		Color(DIM[dir], 0.4)
		if empty
		else (AbilityIcons.color(id) if ability else ItemLooks.color_of_id(id))
	)
	var fam_col := (
		Color(DIM[dir], 0.3)
		if empty
		else CardFrames.tint(CardFrames.frame_of(CardFrames.family(id, int(card["type"]))))
	)
	var f := 1.0 if focused else 0.0
	var icon_px := 56.0
	var icon_at := Vector2((TILE.x - icon_px) * 0.5, 34)
	match dir:
		Dir.SALVAGE:
			plate(
				dir,
				t,
				{
					&"band": fam_col.darkened(0.2),
					&"band_h": 26.0,
					&"focus": f,
					&"rivets": 0.0,
					&"seed": 0.7 + k * 1.3,
					&"cut": 10.0
				},
				12.0
			)
		Dir.EMBER:
			plate(
				dir,
				t,
				{
					&"inlay": col if not empty else Color(0, 0, 0, 0),
					&"inlay_rect":
					Vector4(12 + icon_at.x - 5, 12 + icon_at.y - 5, icon_px + 10, icon_px + 10),
					&"inlay_round": 1.0,
					&"under": 0.25,
					&"focus": f,
					&"seed": 1.1 + k * 0.9,
					&"cut": 10.0
				},
				12.0
			)
		Dir.FIELD:
			plate(
				dir,
				t,
				{&"band": fam_col.darkened(0.1), &"band_h": 24.0, &"focus": f, &"cut": 12.0},
				12.0
			)
	var key := label(
		dir, str(k + 1), 14, true, Color(0.05, 0.04, 0.03) if dir != Dir.EMBER else DIM[dir]
	)
	key.position = Vector2(10, 2)
	t.add_child(key)
	if not empty:
		icon_frame(dir, t, icon_at, icon_px, id, col)
	var levels := not empty and (ability or bool(card.get("wand", false)))
	var nm := label(dir, ci.tr("UI_WAND_EMPTY") if empty else ci.tr(card["name_key"]), 15, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.max_lines_visible = 2
	nm.position = Vector2(8, 96)
	nm.size = Vector2(TILE.x - 16, 44)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_child(nm)
	if levels:
		var lv := label(dir, ci.tr("UI_WAND_LEVEL") % int(card["level"]), 13, false, DIM[dir])
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.position = Vector2(8, 142)
		lv.size = Vector2(TILE.x - 16, 20)
		t.add_child(lv)
	t.modulate = Color.WHITE if focused else Color(0.88, 0.88, 0.9)
	return t


static func _screen_root() -> Control:
	var root := Control.new()
	root.name = "MuMock"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root


## A plate drawn by one of MuShaders' plate shaders over its parent's rect grown by `pad`.
class Plate:
	extends ColorRect

	var pad := 18.0

	func _init(s: Shader, p_pad: float, params: Dictionary) -> void:
		pad = p_pad
		name = "Plate"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		offset_left = -pad
		offset_top = -pad
		offset_right = pad
		offset_bottom = pad
		var m := ShaderMaterial.new()
		m.shader = s
		m.set_shader_parameter(&"pad", pad)
		for k: StringName in params:
			m.set_shader_parameter(k, params[k])
		material = m
		resized.connect(_sync)

	func _sync() -> void:
		(material as ShaderMaterial).set_shader_parameter(&"rect_size", size)
