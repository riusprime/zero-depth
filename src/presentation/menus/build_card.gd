class_name BuildCard
extends Button
## One card of the build screen (v0.3.0 L15; v0.8.0 MU, owner O14: a carved Ember stone tablet, StoneBox, in place of
## v0.6.1 R2b's crystal frame and emblem): the weapon's symbol (ItemIcons: the Blade's sword, the Gun's pistol) in a
## large socket with a glowing inlay ring in the weapon's accent, and below it the build's name, a glowing groove, its
## one-line description and its damage factor, drawn by the game (en and es; each line steps down in size until it
## fits). A Button, so focus, hover, click, Enter and pad A work like every menu.
## Appear: after `delay` the card rises into place with an ease-out and fades in (reduced motion: in place). Focus:
## the card lifts, the ember glow under it grows, its lower edge and the ring light up and the symbol grows a little.

const SIZE := Vector2(400, 560)
## The symbol's socket (centre and radius) and the text box (px on the card).
const SOCKET_C := Vector2(200, 170)
const SOCKET_R := 100.0
const TEXT_BOX := Rect2(40, 300, 320, 220)
## BuildDefinition.Weapon → its symbol (an ItemIcons id) and accent (0 Blade, 1 Gun).
const WEAPON := {
	0: {"icon": &"combo_sword", "accent": Color("#8FE3FF")},
	1: {"icon": &"pulse_gun", "accent": Color("#FFB85A")},
}
const APPEAR_S := 0.55
const RISE_PX := 120.0
const LIFT_PX := 12.0
const TEXT := Color("#F2F2F2")
const TEXT_DIM := Color(0.92, 0.94, 0.96, 0.82)
const NAME_SIZES := [40, 36, 32, 28, 24]
const DESC_SIZES := [19, 18, 17, 16, 15, 14, 13]
const DAMAGE_SIZE := 18
const DESC_LINES := 3
## An unfocused card is drawn this bright.
const IDLE := 0.82

## BuildDefinition.Weapon: which symbol and accent (WEAPON).
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
var _box := StoneBox.new()


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
	_box.pattern = 17 + p_weapon * 29
	_box.cut = 22.0
	_box.chip = 4.0
	_box.cracks = 3
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
	return TEXT_BOX


## The symbol's square (inside the socket).
static func emblem_rect() -> Rect2:
	var r := SOCKET_R * 0.62
	return Rect2(SOCKET_C - Vector2(r, r), Vector2(r, r) * 2.0)


## The weapon's accent (the ring, the damage line).
static func accent(p_weapon: int) -> Color:
	return WEAPON.get(p_weapon, WEAPON[0])["accent"]


## The card's stone tablet (tests).
func panel_box() -> StoneBox:
	return _box


## The name and description sizes that fit the text box (largest first), for `name_text` and `desc_text`.
static func fit_sizes(name_text: String, desc_text: String) -> Vector2i:
	var r := text_rect()
	var bold := HudStyle.font(true)
	var regular := HudStyle.font(false)
	var ns := TextFit.fit_width(bold, name_text, r.size.x, NAME_SIZES)
	var room := r.size.y - bold.get_height(ns) - 12.0 - regular.get_height(DAMAGE_SIZE) - 8.0
	var ds := TextFit.fit_size(regular, desc_text, r.size.x, room, DESC_SIZES, DESC_LINES)
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
	var lit := lerpf(IDLE, 1.0, _focus_glow)
	self_modulate = Color(lit, lit, lit, alpha)
	var acc := accent(weapon)
	_box.focus = _focus_glow
	_box.under = 0.45
	_box.draw(get_canvas_item(), Rect2(off, SIZE))
	var k := 1.0 + 0.04 * _focus_glow
	InlaySocket.draw_socket(get_canvas_item(), SOCKET_C + off, SOCKET_R, acc, _focus_glow, 1.4)
	var em := emblem_rect()
	var grow := em.size * (k - 1.0)
	ItemIcons.draw(
		self,
		WEAPON.get(weapon, WEAPON[0])["icon"],
		Rect2(em.position + off - grow * 0.5, em.size + grow),
		acc.lerp(Color.WHITE, 0.2)
	)
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
	var at := Vector2(r.position.x, y)
	var shade := Color(0, 0, 0, 0.55)
	draw_string_outline(
		bold, at, name_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, name_size, 5, shade
	)
	draw_string(bold, at, name_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, name_size, TEXT)
	y += bold.get_descent(name_size) + 6.0
	var a := Vector2(r.position.x + r.size.x * 0.2, y)
	var b := Vector2(r.end.x - r.size.x * 0.2, y)
	draw_line(a, b, Color(MenuStyle.EMBER, 0.2), 7.0)
	draw_line(a, b, Color(MenuStyle.EMBER, 0.9), 2.0)
	y += 6.0 + regular.get_ascent(desc_size)
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
	draw_string(
		bold,
		Vector2(r.position.x, r.end.y - regular.get_descent(DAMAGE_SIZE)),
		tr("BUILD_DAMAGE") % damage_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		DAMAGE_SIZE,
		Color(acc, 0.95)
	)


## "+15 %" / "-15 %" from the data's per mille.
func damage_text() -> String:
	var pct := int(round((damage_permille - 1000) / 10.0))
	return ("+%d %%" % pct) if pct >= 0 else ("-%d %%" % -pct)
