class_name DepthsTag
extends HBoxContainer
## v0.10.5 O6 (owner P4, 2026-11-01: "Danger, plus a separate tag"; owner D4 flipped from "hidden" to shown): a small
## tag beside the danger bar that names the floor's catch-up, "The depths answer ×1.4" (HUD_DEPTHS_ANSWER), hidden at
## ×1. A small ember rune (a downward chevron drawn here) leads it. `short` words it as the multiplier alone (a G2
## variant). It shows WorldReader.catch_up_permille() and decides nothing.

const COLOR := Color("#F2B33D")
const FONT_SIZE := 13
const RUNE := Vector2(10, 9)

## True: "×1.41" alone; false: the full line.
var short := false
var label := HudStyle.label(FONT_SIZE)
var rune := _Rune.new()
var _m := 1000


class _Rune:
	extends Control

	func _init() -> void:
		custom_minimum_size = RUNE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var w := RUNE.x
		var h := RUNE.y
		draw_colored_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.5, h)]),
			Color(COLOR, 0.95)
		)
		draw_rect(Rect2(w * 0.5 - 1, 2, 2, 3), Color(0.08, 0.05, 0.03, 0.9))


func _init() -> void:
	name = "DepthsTag"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 5)
	add_child(rune)
	label.name = "DepthsLabel"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR)
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


## The tag's line at m (also the pause menu's lead).
static func text_of(node: Object, m_permille: int, is_short: bool = false) -> String:
	var x := multiplier_text(m_permille)
	return ("×" + x) if is_short else node.tr("HUD_DEPTHS_ANSWER") % x


func set_multiplier(m_permille: int) -> void:
	_m = m_permille
	visible = shows(m_permille)
	if visible:
		label.text = text_of(self, m_permille, short)


func multiplier() -> int:
	return _m


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and visible:
		label.text = text_of(self, _m, short)
