class_name BuildCard
extends Button
## One card of the build screen (v0.3.0 L15; v0.6.1 R2b: the owner's art): the weapon's crystal frame (BuildArt), its
## emblem in the top half of the dark panel, and below it the build's name, a hairline, its one-line description and
## its damage factor, drawn by the game (en and es; each line steps down in size until it fits). A Button, so focus,
## hover, click, Enter and pad A work like every menu.
## Appear: after `delay` the card rises into place with an ease-out and fades in. Focus: the card lifts, its frame and
## emblem brighten and the emblem grows a little. No glitch, no colour split.

const SCALE := BuildArt.CARD_SCALE
const SIZE := BuildArt.FRAME_SIZE * SCALE
const APPEAR_S := 0.55
const RISE_PX := 120.0
const LIFT_PX := 12.0
const TEXT := Color("#F2F2F2")
const TEXT_DIM := Color(0.92, 0.94, 0.96, 0.82)
const NAME_SIZES := [40, 36, 32, 28, 24]
const DESC_SIZES := [19, 18, 17, 16, 15, 14, 13]
const DAMAGE_SIZE := 18
const DESC_LINES := 3
## An unfocused card's frame is drawn this bright; a focused one overbright.
const IDLE := Color(0.78, 0.78, 0.8)
const FOCUS := Color(1.12, 1.12, 1.12)

## BuildDefinition.Weapon: which frame and emblem (BuildArt.WEAPON).
var weapon := 0
var title_key := &""
var desc_key := &""
var damage_permille := 1000
var delay := 0.0
## Sizes picked by the last draw (tests check the text fits).
var name_size := 0
var desc_size := 0
var _t := 0.0
var _focus_glow := 0.0


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
	queue_redraw()


## The text box on the card (px): where the name, the description and the damage line go.
static func text_rect() -> Rect2:
	return Rect2(BuildArt.TEXT_BOX.position * SCALE, BuildArt.TEXT_BOX.size * SCALE)


static func emblem_rect() -> Rect2:
	return Rect2(BuildArt.EMBLEM_BOX.position * SCALE, BuildArt.EMBLEM_BOX.size * SCALE)


## The name and description sizes that fit the text box (largest first), for `name_text` and `desc_text`.
static func fit_sizes(name_text: String, desc_text: String) -> Vector2i:
	var r := text_rect()
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	var ns: int = NAME_SIZES[NAME_SIZES.size() - 1]
	for s: int in NAME_SIZES:
		if bold.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= r.size.x:
			ns = s
			break
	var room := r.size.y - bold.get_height(ns) - 12.0 - regular.get_height(DAMAGE_SIZE) - 8.0
	var ds := CrystalCard.fit_size(regular, desc_text, r.size.x, room, DESC_SIZES, DESC_LINES)
	return Vector2i(ns, ds)


## True when the name (one line), the description and the damage line fit the text box at the sizes picked.
static func fits(name_text: String, desc_text: String) -> bool:
	var r := text_rect()
	var sz := fit_sizes(name_text, desc_text)
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	var wide := bold.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz.x).x
	var h := (
		bold.get_height(sz.x)
		+ 12.0
		+ CrystalCard.text_height(regular, desc_text, r.size.x, sz.y)
		+ 8.0
		+ regular.get_height(DAMAGE_SIZE)
	)
	return wide <= r.size.x + 0.5 and h <= r.size.y + 0.5


func _draw() -> void:
	var p := appear()
	if p <= 0.0:
		return
	var e := 1.0 - pow(1.0 - p, 3.0)
	var off := Vector2(0, RISE_PX * (1.0 - e) - LIFT_PX * _focus_glow)
	var alpha := clampf(p * 1.6, 0.0, 1.0)
	var lit := IDLE.lerp(FOCUS, _focus_glow)
	draw_texture_rect(BuildArt.frame(weapon), Rect2(off, SIZE), false, Color(lit, alpha))
	var em := emblem_rect()
	var grow := em.size * (0.06 * _focus_glow)
	draw_texture_rect(
		BuildArt.emblem(weapon),
		Rect2(em.position + off - grow * 0.5, em.size + grow),
		false,
		Color(lit, alpha)
	)
	var accent := BuildArt.accent(weapon)
	var r := text_rect()
	r.position += off
	var name_text := tr(title_key)
	var desc_text := tr(desc_key)
	var sz := fit_sizes(name_text, desc_text)
	name_size = sz.x
	desc_size = sz.y
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	var y := r.position.y + bold.get_ascent(name_size)
	draw_string(
		bold,
		Vector2(r.position.x, y),
		name_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		name_size,
		Color(TEXT, alpha)
	)
	y += bold.get_descent(name_size) + 6.0
	draw_line(
		Vector2(r.position.x + r.size.x * 0.25, y),
		Vector2(r.end.x - r.size.x * 0.25, y),
		Color(accent, 0.7 * alpha),
		2.0
	)
	y += 6.0 + regular.get_ascent(desc_size)
	draw_multiline_string(
		regular,
		Vector2(r.position.x, y),
		desc_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		desc_size,
		DESC_LINES,
		Color(TEXT_DIM, alpha)
	)
	draw_string(
		bold,
		Vector2(r.position.x, r.end.y - regular.get_descent(DAMAGE_SIZE)),
		tr("BUILD_DAMAGE") % damage_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		DAMAGE_SIZE,
		Color(accent, 0.95 * alpha)
	)


## "+15 %" / "-15 %" from the data's per mille.
func damage_text() -> String:
	var pct := int(round((damage_permille - 1000) / 10.0))
	return ("+%d %%" % pct) if pct >= 0 else ("-%d %%" % -pct)
