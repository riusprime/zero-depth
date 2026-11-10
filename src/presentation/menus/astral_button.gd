class_name AstralButton
extends Button
## v0.10.5 W3-O18: a menu button in the Astral style (AstralMenu), drawn in code; it stays a Button (focus, keys, pad,
## mouse, the disabled state and the press work as for any button), only its look is its own:
## - ROW (a menu list's row): the label in letter-spaced Cinzel capitals, dim with a small diamond before it; lit
##   (focused, or hovered: a hover takes the focus, so the mouse, the keys and the pad move one focus) it turns bright
##   with a four-point star before it and a tapered streak of light under it. Disabled: faint, a hollow diamond.
## - TAB (Options' categories): Cinzel capitals; the open one bright with an accent underline and a diamond on it;
##   focused or hovered: a star before it and the label in moonlight.
## - PLATE (Back, the resets): a slim lozenge plate (AstralChrome.plate) with the label centred; focus and hover alike
##   brighten its contour, add a second contour outside and light its tip stars.
## The Button's own text is hidden (transparent colours); `text` stays the translation key. Presentation only.
## v0.11.1 Step 13: a ROW with an `icon` (the Progression Station's robe swatches) draws it after its marker, the label
## after the icon; the Button's own icon is hidden like its text.

enum Kind { ROW, TAB, PLATE }

## The room before a row's label (its marker) and a tab's.
const ROW_PAD := 44.0
## The room between a row's icon and its label.
const ICON_GAP := 12.0
const TAB_PAD := 28.0
const FLASH_RATE := 5.0

var kind := Kind.ROW
## The label's size (px) and the narrowest the button may be (the label's own width can make it wider).
var font_px := AstralMenu.ROW_SIZE
var min_w := 0.0
## A press flashes it a little brighter (0..1).
var flash := 0.0


func _init(p_kind: int = Kind.ROW, p_min_w: float = 0.0) -> void:
	kind = p_kind
	min_w = p_min_w
	focus_mode = Control.FOCUS_ALL
	match kind:
		Kind.ROW:
			font_px = AstralMenu.ROW_SIZE
			alignment = HORIZONTAL_ALIGNMENT_LEFT
		Kind.TAB:
			font_px = AstralMenu.TAB_SIZE
			alignment = HORIZONTAL_ALIGNMENT_LEFT
		Kind.PLATE:
			font_px = AstralMenu.PLATE_SIZE
	var none := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, none)
	for c in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_hover_pressed_color",
		"font_disabled_color",
		"font_outline_color"
	]:
		add_theme_color_override(c, Color(0, 0, 0, 0))
	for c in [
		"icon_normal_color",
		"icon_hover_color",
		"icon_pressed_color",
		"icon_focus_color",
		"icon_hover_pressed_color",
		"icon_disabled_color"
	]:
		add_theme_color_override(c, Color(0, 0, 0, 0))
	add_theme_constant_override("outline_size", 0)
	mouse_entered.connect(_on_mouse_entered)
	button_down.connect(_on_down)
	set_process(false)
	_fit()


## Lit: focused or hovered, and not disabled.
func is_lit() -> bool:
	return not disabled and (has_focus() or is_hovered())


## The label as drawn: the translated text in capitals.
func shown_text() -> String:
	return (
		tr(text).to_upper()
		if auto_translate_mode != AUTO_TRANSLATE_MODE_DISABLED
		else text.to_upper()
	)


func label_font() -> Font:
	var lit := is_lit() or (kind == Kind.TAB and button_pressed)
	match kind:
		Kind.ROW:
			return AstralMenu.serif(font_px, 600 if lit else 500, 0.3)
		Kind.TAB:
			return AstralMenu.serif(font_px, 700 if lit else 600, 0.33)
	return AstralMenu.serif(font_px, 600, 0.27)


func _on_mouse_entered() -> void:
	if kind == Kind.ROW and not disabled and is_inside_tree() and focus_mode != FOCUS_NONE:
		grab_focus()
	queue_redraw()


func _on_down() -> void:
	flash = 1.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	flash = move_toward(flash, 0.0, delta * FLASH_RATE)
	queue_redraw()
	if flash <= 0.0:
		set_process(false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_ENTER_TREE:
			_fit()
			queue_redraw()
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_MOUSE_EXIT:
			queue_redraw()
		NOTIFICATION_DISABLED, NOTIFICATION_ENABLED:
			queue_redraw()


func _toggled(_on: bool) -> void:
	queue_redraw()


## Wide enough for the label in capitals (Spanish runs longer), and at least `min_w`.
func _fit() -> void:
	var f := AstralMenu.serif(font_px, 700, 0.33)
	var w := f.get_string_size(shown_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var pad := ROW_PAD + 16.0 + _icon_room()
	match kind:
		Kind.TAB:
			pad = TAB_PAD + 12.0
		Kind.PLATE:
			pad = 120.0
	var h := AstralMenu.ROW_H if kind == Kind.ROW else 48.0
	custom_minimum_size = Vector2(maxf(min_w, ceilf(w + pad)), h)


func _draw() -> void:
	var lit := is_lit()
	var cy := roundf(size.y * 0.5)
	var font := label_font()
	var label := shown_text()
	var ascent := font.get_ascent(font_px)
	var descent := font.get_descent(font_px)
	var base := roundf((size.y + ascent - descent) * 0.5)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	match kind:
		Kind.ROW:
			_draw_row(lit, cy, base, tw, font, label)
		Kind.TAB:
			_draw_tab(lit, cy, base, tw, font, label)
		Kind.PLATE:
			var r := Rect2(24, 4, size.x - 48, size.y - 8)
			AstralChrome.plate(self, r, lit, not disabled)
			var col := AstralCardArt.TEXT if not disabled else Color(AstralCardArt.DIM, 0.5)
			if lit:
				col = AstralCardArt.LINE_HI.lerp(Color.WHITE, 0.3 * flash)
			_text(font, label, roundf((size.x - tw) * 0.5), base, col)


## The room a row's icon takes before its label (none without one).
func _icon_room() -> float:
	return icon.get_width() + ICON_GAP if kind == Kind.ROW and icon != null else 0.0


func _draw_row(lit: bool, cy: float, base: float, tw: float, font: Font, label: String) -> void:
	var m := Vector2(18.5, cy + 0.5)
	var x := ROW_PAD + _icon_room()
	var col := AstralCardArt.DIM
	if disabled:
		col = Color(AstralCardArt.DIM, 0.38)
		AstralChrome.dia(self, m, 2.5, Color(AstralCardArt.LINE, 0.4))
	elif lit:
		col = AstralCardArt.TEXT.lerp(Color.WHITE, 0.4 * flash)
		AstralMenu.wash(self, Rect2(0, 6, size.x, size.y - 12), 0.11 + 0.08 * flash)
		AstralChrome.star4(self, m, 11.0, AstralCardArt.LINE_HI, 0.16)
		# The tapered streak: bright under the label's start, fading out past its end.
		var x0 := ROW_PAD - 14.0
		var x1 := x + tw + 56.0
		var y := base + 9.0
		var hi := Color(AstralCardArt.LINE_HI, 0.85)
		var lo := Color(AstralCardArt.LINE_HI, 0.0)
		draw_polygon(
			PackedVector2Array(
				[
					Vector2(x0, y + 1.0),
					Vector2(x0 + 18.0, y - 1.0),
					Vector2(x1, y + 0.5),
					Vector2(x0 + 18.0, y + 3.0),
				]
			),
			PackedColorArray([Color(hi, 0.0), hi, lo, hi])
		)
		AstralChrome.rule1(
			self, x0 + 18.0, y + 6.0, (x1 - x0) * 0.6, Color(AstralCardArt.LINE, 0.35)
		)
	else:
		var c := Color(AstralCardArt.LINE, 0.8)
		AstralChrome.dia(self, m, 2.5, c, c)
	if icon != null:
		var at := Vector2(ROW_PAD, roundf(cy - icon.get_height() * 0.5))
		draw_texture(icon, at, Color(1, 1, 1, 0.5 if disabled else 1.0))
	_text(font, label, x, base, col)


func _draw_tab(lit: bool, cy: float, base: float, tw: float, font: Font, label: String) -> void:
	var open := button_pressed
	var col := AstralCardArt.DIM
	if open:
		col = AstralCardArt.TEXT
	if lit:
		col = AstralCardArt.LINE_HI
	var m := Vector2(10.5, cy + 0.5)
	if lit:
		AstralChrome.star4(self, m, 8.0, AstralCardArt.LINE_HI, 0.18)
	elif open:
		AstralChrome.dia(self, m, 3.0, AstralCardArt.ACCENT, AstralCardArt.ACCENT)
	var uy := base + 9.0
	if open:
		AstralChrome.hline(self, TAB_PAD, TAB_PAD + tw, uy, AstralCardArt.ACCENT, 2.0)
		AstralChrome.dia(
			self,
			Vector2(roundf(TAB_PAD + tw * 0.5) + 0.5, uy + 1.0),
			3.5,
			AstralCardArt.LINE_HI,
			AstralChrome.INK
		)
	elif lit:
		AstralChrome.rule1(self, TAB_PAD, uy, tw, Color(AstralCardArt.LINE_HI, 0.45))
	_text(font, label, TAB_PAD, base, col)


func _text(font: Font, label: String, x: float, base: float, col: Color) -> void:
	draw_string_outline(
		font,
		Vector2(roundf(x), base),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_px,
		4,
		Color(AstralChrome.INK, 0.55)
	)
	draw_string(font, Vector2(roundf(x), base), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, col)
