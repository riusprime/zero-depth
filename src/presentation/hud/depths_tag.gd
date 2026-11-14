class_name DepthsTag
extends HBoxContainer
## The floor's catch-up, hidden at ×1.
## A small skull whose colour heats from
## bone to red with the level, and the multiplier beside it ("×1.41"). No sentence, no card, no pips. The level is
## the multiplier's step (LIMITS); the five colours step in lightness as well as hue, so they read without colour.
## It shows WorldReader.catch_up_permille() and decides nothing (EI-07). Also the pause menu's line.

const FONT_SIZE := 16
const SKULL := Vector2(19, 19)
## Named data: a multiplier (per mille) up to LIMITS[k] is level k + 1; above the last is the top level.
const LIMITS: Array[int] = [1150, 1400, 1800, 2500]
## Bone, pale gold, amber, orange-red, deep red: lightness falls with every step.
const COLORS: Array[Color] = [
	Color("#EFE8D6"), Color("#E6CD8A"), Color("#E2A24E"), Color("#D2582F"), Color("#B02430")
]
const INK := Color("#070913")
const TEXT := Color("#D8D2C4")

var label := HudStyle.label(FONT_SIZE)
var skull := _Skull.new()
var _m := 1000


class _Skull:
	extends Control
	var level := 1

	func _init() -> void:
		custom_minimum_size = SKULL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var c := COLORS[clampi(level, 1, COLORS.size()) - 1]
		var h := SKULL.y
		var mid := Vector2(SKULL.x * 0.5, h * 0.42)
		var r := h * 0.42
		var jaw := Rect2(mid.x - r * 0.62, h * 0.62, r * 1.24, h * 0.34)
		draw_circle(mid, r + 0.8, Color(INK, 0.75))
		draw_rect(jaw.grow(0.8), Color(INK, 0.75))
		draw_circle(mid, r, c)
		draw_rect(jaw, c)
		var eye := r * 0.36
		draw_circle(mid + Vector2(-r * 0.42, r * 0.1), eye, INK)
		draw_circle(mid + Vector2(r * 0.42, r * 0.1), eye, INK)
		for k in 3:
			var x := jaw.position.x + jaw.size.x * (k + 1) / 4.0
			draw_line(Vector2(x, jaw.position.y + 1), Vector2(x, jaw.end.y), INK, 1.0)


func _init() -> void:
	name = "DepthsTag"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 5)
	skull.name = "DepthsSkull"
	add_child(skull)
	label.name = "DepthsLabel"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	AstralUi.caps(label, FONT_SIZE, TEXT)
	add_child(label)
	visible = false


## "1.41", "1.4", "2": the multiplier per mille as the tag writes it (two decimals at most, no trailing zeros).
static func multiplier_text(m_permille: int) -> String:
	var s := "%.2f" % (maxi(0, m_permille) / 1000.0)
	s = s.rstrip("0")
	return s.rstrip(".")


## Shown only when m > ×1.
static func shows(m_permille: int) -> bool:
	return m_permille > 1000


## 1 to 5: the step of `m_permille` (LIMITS).
static func level_of(m_permille: int) -> int:
	for k in LIMITS.size():
		if m_permille <= LIMITS[k]:
			return k + 1
	return LIMITS.size() + 1


## The skull's colour at `m_permille`.
static func color_of(m_permille: int) -> Color:
	return COLORS[level_of(m_permille) - 1]


## The tag's text: "×1.41".
static func text_of(m_permille: int) -> String:
	return "×" + multiplier_text(m_permille)


func set_multiplier(m_permille: int) -> void:
	_m = m_permille
	visible = shows(m_permille)
	if visible:
		label.text = text_of(m_permille)
		skull.level = level_of(m_permille)
		skull.queue_redraw()


func multiplier() -> int:
	return _m


func level() -> int:
	return skull.level
