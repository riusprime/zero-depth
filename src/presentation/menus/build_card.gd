class_name BuildCard
extends Button
## One card of the build screen (v0.3.0 L15; v0.8.0 MU, owner O14: a carved Ember stone tablet in place of v0.6.1
## R2b's crystal frame and emblem): the weapon's symbol in a large medallion, and below it the build's name, a rule,
## its one-line description and its damage factor, drawn by the game (en and es; each line steps down in size until it
## fits). A Button, so focus, hover, click, Enter and pad A work like every menu.
## v0.10.5 W3-O20 (owner 2026-11-04 night: "remake every single UI element into this new style"; Astral,
## W3_O13_UI_STYLE_G2.md round 2 and 3): an Astral card. The owner's carved slate frame (AstralCardArt.frame, its
## focused twin on focus) as a 9-slice over the whole card; the weapon's painted icon (AstralCardArt.icon: the combo
## sword, the pulse gun) in a medallion (a 1 px contour and a dotted inner ring, four small stars round it on focus);
## the name in letter-spaced Cinzel, a fading hairline with a star under it, the sentence in Atkinson in Astral's
## silver-white, the damage lines in the weapon's Astral tone (the Blade the lilac accent, the Gun the muted amber).
## A padlocked build: a silver padlock over the medallion (it flashes Astral's rose on a denied pick) and its
## condition in place of the damage lines.
## Appear: after `delay` the card rises into place with an ease-out and fades in (reduced motion: in place). Focus:
## the card lifts, its frame turns to the focused twin, the medallion lights and the symbol grows a little.

const SIZE := Vector2(400, 560)
## The symbol's medallion (centre and radius) and the text box (px on the card), inside the frame's body.
const SOCKET_C := Vector2(200, 180)
const SOCKET_R := 92.0
const TEXT_BOX := Rect2(70, 298, 260, 178)
## BuildDefinition.Weapon → its painted icon (an AstralCardArt icon id) and Astral tone (0 Blade, 1 Gun).
const WEAPON := {
	0: {"icon": &"combo_sword", "accent": Color("#B5BDF0"), "frame": 1},
	1: {"icon": &"pulse_gun", "accent": Color("#D6A878"), "frame": 3},
}
const APPEAR_S := 0.55
const RISE_PX := 120.0
const LIFT_PX := 12.0
const TEXT := Color("#ECEEFA")
const TEXT_DIM := Color("#C9CCE6")
const NAME_SIZES := [40, 36, 32, 28, 24]
const DESC_SIZES := [19, 18, 17, 16, 15, 14, 13]
const DAMAGE_SIZE := 18
const DESC_LINES := 3
## An unfocused card is drawn this bright.
const IDLE := 0.86
const DOTS := 40

## BuildDefinition.Weapon: which symbol and tone (WEAPON).
var weapon := 0
var title_key := &""
var desc_key := &""
var damage_permille := 1000
## The build's damage taken, per mille (1000 draws no line; the Blade's 750 reads "-25 %").
var taken_permille := 1000
## A padlocked build (the Blade until Sword Unbound) shows this condition line (a tr key) instead of its
## damage lines, a padlock over its symbol, and can't be picked (BuildPicker). &"" is a build that can be picked.
var locked_key := &""
var delay := 0.0
## Sizes picked by the last draw (tests check the text fits).
var name_size := 0
var desc_size := 0
## How lit the card is now (0 idle.. 1 focused), as drawn.
var lit := 0.0
var _t := 0.0
var _deny := 0.0
var _focus_glow := 0.0
var _frames: Array[StyleBoxTexture] = []


func _init(
	p_weapon: int, p_name_key: StringName, p_desc_key: StringName, p_damage: int, p_delay: float
) -> void:
	weapon = p_weapon
	title_key = p_name_key
	desc_key = p_desc_key
	damage_permille = p_damage
	delay = p_delay
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	flat = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var variant: int = WEAPON.get(p_weapon, WEAPON[0])["frame"]
	for focused in [false, true]:
		var box := StyleBoxTexture.new()
		box.texture = AstralCardArt.frame(variant, focused)
		box.texture_margin_left = AstralCardArt.MARGIN_X
		box.texture_margin_right = AstralCardArt.MARGIN_X
		box.texture_margin_top = AstralCardArt.MARGIN_Y
		box.texture_margin_bottom = AstralCardArt.MARGIN_Y
		_frames.append(box)
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	mouse_entered.connect(grab_focus)


## 0 before the card starts, 1 once it has landed.
func appear() -> float:
	return clampf((_t - delay) / APPEAR_S, 0.0, 1.0)


## Skips the animation (screenshots of the settled screen, reduced motion later).
func settle() -> void:
	seek(delay + APPEAR_S + 0.01)


## Sets the animation clock (seconds since the screen opened); the screenshot tool scrubs with it.
func seek(t: float) -> void:
	_t = t
	_focus_glow = 1.0 if has_focus() else 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_focus_glow = move_toward(_focus_glow, 1.0 if has_focus() else 0.0, delta * 6.0)
	_deny = move_toward(_deny, 0.0, delta * 4.0)
	queue_redraw()


## True while the build is padlocked.
func is_locked() -> bool:
	return locked_key != &""


## A pick of a padlocked build: the padlock flashes rose for a moment (the card does nothing else).
func deny() -> void:
	_deny = 1.0
	queue_redraw()


## The padlock drawn over the medallion (centre `c`): a shackle, a body and a keyhole, in Astral's silver line work
## over ink.
func _draw_padlock(c: Vector2) -> void:
	var tint := AstralCardArt.METAL.lerp(HudStyle.A_WARN, _deny)
	var ink := Color(AstralChrome.INK, 0.92)
	draw_circle(c, SOCKET_R * 0.86, Color(AstralChrome.INK, 0.62))
	var body := Rect2(c + Vector2(-28, -2), Vector2(56, 44))
	draw_arc(c + Vector2(0, -2), 18.0, PI, TAU, 32, tint, 3.0, true)
	draw_line(c + Vector2(-18, -2), c + Vector2(-18, 4), tint, 3.0)
	draw_line(c + Vector2(18, -2), c + Vector2(18, 4), tint, 3.0)
	draw_rect(body, ink)
	draw_rect(body, tint, false, 1.4)
	draw_rect(body.grow(-5), Color(tint, 0.3), false, 1.0)
	AstralChrome.dia(self, c + Vector2(0.5, 18.5), 5.0, tint, tint)


## The text box on the card (px): where the name, the description and the damage line go.
static func text_rect() -> Rect2:
	return TEXT_BOX


## The symbol's square (inside the medallion).
static func emblem_rect() -> Rect2:
	var r := SOCKET_R * 0.78
	return Rect2(SOCKET_C - Vector2(r, r), Vector2(r, r) * 2.0)


## The weapon's Astral tone (the damage lines, the medallion's focus).
static func accent(p_weapon: int) -> Color:
	return WEAPON.get(p_weapon, WEAPON[0])["accent"]


## The card's frame as drawn now (the focused twin while lit; tests).
func panel_box() -> StyleBoxTexture:
	return _frames[1] if lit >= 0.5 else _frames[0]


## The name's face, letter-spaced Cinzel (the fit measures with it).
static func name_font() -> Font:
	return AstralCardArt.serif(650, 3)


## The name and description sizes that fit the text box (largest first), for `name_text` and `desc_text`.
static func fit_sizes(name_text: String, desc_text: String) -> Vector2i:
	var r := text_rect()
	var head := name_font()
	var regular := HudStyle.font(false)
	var ns := TextFit.fit_width(head, name_text, r.size.x, NAME_SIZES)
	var room := r.size.y - head.get_height(ns) - 16.0 - regular.get_height(DAMAGE_SIZE) - 8.0
	var ds := TextFit.fit_size(regular, desc_text, r.size.x, room, DESC_SIZES, DESC_LINES)
	return Vector2i(ns, ds)


## True when the name (one line), the description and the damage line fit the text box at the sizes picked.
static func fits(name_text: String, desc_text: String) -> bool:
	var r := text_rect()
	var sz := fit_sizes(name_text, desc_text)
	var head := name_font()
	var regular := HudStyle.font(false)
	var wide := head.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz.x).x
	var h := (
		head.get_height(sz.x)
		+ 16.0
		+ TextFit.text_height(regular, desc_text, r.size.x, sz.y)
		+ 8.0
		+ regular.get_height(DAMAGE_SIZE)
	)
	return wide <= r.size.x + 0.5 and h <= r.size.y + 0.5


func _draw() -> void:
	var p := appear()
	if p <= 0.0:
		self_modulate.a = 0.0
		return
	var e := 1.0 - pow(1.0 - p, 3.0)
	var off := Vector2(0, RISE_PX * (1.0 - e) - LIFT_PX * _focus_glow)
	var alpha := clampf(p * 1.6, 0.0, 1.0)
	var bright := lerpf(IDLE, 1.0, _focus_glow)
	self_modulate = Color(bright, bright, bright, alpha)
	lit = _focus_glow
	var acc := accent(weapon)
	draw_style_box(panel_box(), Rect2(off, SIZE))
	_draw_medallion(SOCKET_C + off, acc)
	var k := 1.0 + 0.04 * _focus_glow
	var em := emblem_rect()
	var grow := em.size * (k - 1.0)
	var icon_rect := Rect2(em.position + off - grow * 0.5, em.size + grow)
	var tint := Color.WHITE if not is_locked() else Color(1, 1, 1, 0.35)
	draw_texture_rect(
		AstralCardArt.icon(WEAPON.get(weapon, WEAPON[0])["icon"]), icon_rect, false, tint
	)
	if is_locked():
		_draw_padlock(SOCKET_C + off)
	var r := text_rect()
	r.position += off
	var name_text := tr(title_key)
	var desc_text := tr(desc_key)
	var sz := fit_sizes(name_text, desc_text)
	name_size = sz.x
	desc_size = sz.y
	var head := name_font()
	var regular := HudStyle.font(false)
	var bold := HudStyle.font(true)
	var ink := Color(AstralChrome.INK, 0.7)
	var y := r.position.y + head.get_ascent(name_size)
	var at := Vector2(r.position.x, y)
	draw_string_outline(
		head, at, name_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, name_size, 5, ink
	)
	draw_string(head, at, name_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, name_size, TEXT)
	y += head.get_descent(name_size) + 8.0
	var cx := roundf(r.get_center().x)
	var line := AstralCardArt.LINE_HI if _focus_glow > 0.5 else AstralCardArt.METAL
	AstralChrome.rule(self, cx, roundf(y), r.size.x * 0.32, Color(line, 0.6), 12.0)
	AstralChrome.star4(self, Vector2(cx + 0.5, roundf(y) + 0.5), 5.0, Color(line, 0.9), 0.2)
	y += 8.0 + regular.get_ascent(desc_size)
	draw_multiline_string_outline(
		regular,
		Vector2(r.position.x, y),
		desc_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		desc_size,
		DESC_LINES,
		4,
		ink
	)
	draw_multiline_string(
		regular,
		Vector2(r.position.x, y),
		desc_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		desc_size,
		DESC_LINES,
		TEXT_DIM
	)
	if is_locked():  # The condition in place of the damage lines
		var cond := tr(locked_key)
		var cs := 17
		var top := r.end.y - 3.0 * bold.get_height(cs) - 4.0
		draw_multiline_string(
			bold,
			Vector2(r.position.x, top + bold.get_ascent(cs)),
			cond,
			HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x,
			cs,
			3,
			AstralCardArt.ACCENT
		)
		return
	draw_string(
		bold,
		Vector2(r.position.x, r.end.y - regular.get_descent(DAMAGE_SIZE)),
		tr("BUILD_DAMAGE") % damage_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		DAMAGE_SIZE,
		Color(acc, 0.95)
	)
	if taken_permille != 1000:  # The line above the damage factor
		draw_string(
			bold,
			Vector2(r.position.x, r.end.y - regular.get_descent(DAMAGE_SIZE) - DAMAGE_SIZE - 8.0),
			tr("BUILD_TAKEN") % taken_text(),
			HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x,
			DAMAGE_SIZE,
			Color(acc, 0.95)
		)


## The medallion round the symbol: an ink disc, a 1 px contour and a dotted inner ring; lit, the contour brightens,
## a second contour sits outside it in the weapon's tone and four small stars ring it.
func _draw_medallion(c: Vector2, acc: Color) -> void:
	var on := _focus_glow
	var line := AstralCardArt.LINE.lerp(AstralCardArt.LINE_HI, on)
	draw_circle(c, SOCKET_R, Color(AstralChrome.INK, 0.5))
	draw_arc(c, SOCKET_R, 0.0, TAU, 96, Color(line, 0.6 + 0.35 * on), 1.0 + 0.4 * on, true)
	if on > 0.01:
		draw_arc(c, SOCKET_R + 7.0, 0.0, TAU, 96, Color(acc, 0.35 * on), 1.0, true)
	for i in DOTS:
		var a := TAU * i / DOTS
		draw_circle(
			c + Vector2(cos(a), sin(a)) * (SOCKET_R - 6.0), 0.9, Color(line, 0.3 + 0.3 * on)
		)
	if on > 0.01:
		for i in 4:
			var a := PI * 0.25 + PI * 0.5 * i
			AstralChrome.star4(
				self, c + Vector2(cos(a), sin(a)) * (SOCKET_R + 9.0), 4.5, Color(line, on), 0.2
			)
	AstralChrome.crescent(
		self, c + Vector2(0, -SOCKET_R - 12.0), 6.0, Color(AstralCardArt.METAL, 0.7 + 0.3 * on)
	)


## "-25 %" from the build's damage taken per mille.
func taken_text() -> String:
	var pct := int(round((taken_permille - 1000) / 10.0))
	return ("+%d %%" % pct) if pct >= 0 else ("-%d %%" % -pct)


## "+15 %" / "-15 %" from the data's per mille.
func damage_text() -> String:
	var pct := int(round((damage_permille - 1000) / 10.0))
	return ("+%d %%" % pct) if pct >= 0 else ("-%d %%" % -pct)
