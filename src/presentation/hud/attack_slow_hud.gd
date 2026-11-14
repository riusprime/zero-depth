class_name AttackSlowHud
extends Control
## The attack speed a boss has taken, over the HP plate (WorldReader.boss_attack_slow; the Clockwork Judge's Time
## Wave). While any is taken it shows a small clock, the line "Attacks slowed N%" with what is still lost, and one
## pip per hour orb the loss is worth: a pip turns gold when an orb's share has been won back. It hides when the
## weapon is whole again. The loss is counted from its highest point since the weapon was last whole; an orb's share
## is read from the orbs lying (WorldReader.boss_pickups) and remembered, a third of the loss until one is seen.
## Reads only (EI-07); never takes the mouse.

const GOLD := Color("#FFC94A")
const SIZE := Vector2(250, 40)
const GAP := 8.0
const PIP_R := 6.0
const MAX_PIPS := 6
const FONT_PX := 17

## The plate this one sits over (Hud's HP corner).
var above: Control = null
var _cut := 0
var _peak := 0
var _step := 0


func _init() -> void:
	name = "AttackSlow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	custom_minimum_size = SIZE
	size = SIZE
	visible = false


func sync(reader: WorldReader) -> void:
	var cut := reader.boss_attack_slow()
	if cut <= 0:
		_peak = 0
		_step = 0
	else:
		_peak = maxi(_peak, cut)
		for o: Dictionary in reader.boss_pickups():
			_step = maxi(_step, int(o["amount"]))
	if cut != _cut or visible != (cut > 0):
		_cut = cut
		visible = cut > 0
		queue_redraw()
	if visible and above != null:
		var r := above.get_global_rect()
		global_position = Vector2(r.position.x + 8.0, r.position.y - SIZE.y - GAP)


## The share of the weapon's speed still lost, in percent.
func percent() -> int:
	return roundi(_cut / 10.0)


## The pips drawn, and how many of them are won back.
func pips() -> int:
	if _peak <= 0:
		return 0
	return clampi(roundi(float(_peak) / float(_share())), 1, MAX_PIPS)


func pips_won() -> int:
	if _peak <= 0:
		return 0
	return clampi((_peak - _cut) / _share(), 0, pips())


## The line as shown.
func line() -> String:
	return tr("HUD_ATTACK_SLOW") % percent()


func _share() -> int:
	return _step if _step > 0 else maxi(1, _peak / 3)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	if _cut <= 0:
		return
	var f := HudStyle.font(true)
	var mid := SIZE.y * 0.5
	var c := Vector2(mid, mid)
	draw_circle(c, 15.0, Color(HudStyle.A_INK, 0.85))
	draw_arc(c, 14.0, 0.0, TAU, 32, GOLD, 2.0, true)
	draw_line(c, c + Vector2(0, -10.0), GOLD, 2.0, true)
	draw_line(c, c + Vector2(6.0, 3.0), GOLD, 2.0, true)
	var text := line()
	var at := Vector2(SIZE.y + 4.0, mid - 3.0)
	draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, 4, Color(0, 0, 0, 0.7))
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, HudStyle.text_color())
	var won := pips_won()
	for k in pips():
		var p := Vector2(SIZE.y + 4.0 + PIP_R + k * (PIP_R * 2.0 + 6.0), mid + 11.0)
		if k < won:
			draw_circle(p, PIP_R, GOLD)
		else:
			draw_circle(p, PIP_R, Color(HudStyle.A_INK, 0.85))
			draw_arc(p, PIP_R, 0.0, TAU, 20, HudStyle.dim(), 1.5, true)
