class_name CardFly
extends Control
## v0.8.0 N8 (owner O62, "show where it went. When it's picked, its icon flies to its slot on the HUD"): the picked
## card's icon, flown from the card's socket to the HUD slot the card landed in (Hud.slot_rect_for: an ability's slot,
## a wand card's pip, a passive mod's icon in the carried row, a stat or a curse to the HP plate) on an arc, shrinking,
## with a short trail; at the end the slot flashes once. Drawn over the HUD, it takes no input and decides nothing
## (EI-07: the card was already taken by the sim).

const FLY_S := 0.55
const FLASH_S := 0.25

var id := &""
var from := Rect2()
var to := Rect2()
var color := Color.WHITE
var time := 0.0
var _icon := ItemIconView.new()


func _init(p_id: StringName, p_color: Color, p_from: Rect2, p_to: Rect2) -> void:
	name = "CardFly"
	id = p_id
	color = p_color
	from = p_from
	to = p_to
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_item(id, color)
	add_child(_icon)


func _ready() -> void:
	_place()


## 0..1 of the flight (1: landed).
func progress() -> float:
	return clampf(time / FLY_S, 0.0, 1.0)


## The icon's rect now (global px).
func icon_rect() -> Rect2:
	return Rect2(_icon.global_position, _icon.size)


func done() -> bool:
	return time >= FLY_S + FLASH_S


func _process(delta: float) -> void:
	time += delta
	_place()
	queue_redraw()
	if done():
		queue_free()


func _place() -> void:
	var t := progress()
	var e := t * t * (3.0 - 2.0 * t)
	var a := from.get_center()
	var b := to.get_center()
	var mid := (a + b) * 0.5 + Vector2(0, -minf(220.0, a.distance_to(b) * 0.35))
	var p := a.lerp(mid, e).lerp(mid.lerp(b, e), e)  # a quadratic arc
	var side := lerpf(from.size.x, maxf(to.size.x, 18.0), e)
	_icon.size = Vector2(side, side)
	_icon.global_position = p - _icon.size * 0.5
	_icon.modulate.a = 1.0 if t < 1.0 else 1.0 - clampf((time - FLY_S) / FLASH_S, 0.0, 1.0)


func _draw() -> void:
	var t := progress()
	if t < 1.0:
		var c := _icon.global_position + _icon.size * 0.5 - global_position
		draw_circle(c, _icon.size.x * 0.7, Color(color, 0.16 * (1.0 - t * 0.5)))
		return
	var f := 1.0 - clampf((time - FLY_S) / FLASH_S, 0.0, 1.0)
	var r := Rect2(to.position - global_position, to.size).grow(4.0 + 10.0 * (1.0 - f))
	draw_rect(r, Color(color.lightened(0.4), 0.6 * f), false, 3.0)
	draw_circle(r.get_center(), r.size.x * 0.6, Color(color, 0.3 * f))
