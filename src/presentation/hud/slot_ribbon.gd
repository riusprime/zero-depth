class_name SlotRibbon
extends Control
## v0.9.0 AS2 (owner, step AS's G2: "B: ribbon + pips"; PLAN "Owner decisions" AS): the ember-red ribbon across a
## reward card whose slot is full: "REPLACES TWIN" (a Form or Pattern card: the held card it replaces, which burns
## when this one is picked) or "CHOOSE ONE TO REPLACE" (a full Secondary or Element slot: the Swap panel asks which
## card goes). StoneCard lays it across the card above the rarity gem, below the sentence, so it never covers the
## card's name or icon. One canvas item (the band and the words drawn here), so a burn material on it dissolves it
## whole (PickSlot.burn_replaced). It draws the text it is given (already translated); it decides nothing (EI-07).

## The band's colour (G2 mockup B), its darker hem and the words' colour.
const BAND := Color("#B8471E")
const HEM := Color("#5E200C")
const INK := Color("#FFF1E2")
## The band's tilt (radians) and the words' largest and smallest size at scale 1.
const TILT := -0.035
const FONT_MAX := 17
const FONT_MIN := 10

var text := "":
	set(v):
		text = v
		queue_redraw()
var scale_factor := 1.0:
	set(v):
		scale_factor = v
		queue_redraw()


func _init() -> void:
	name = "SlotRibbon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	rotation = TILT
	resized.connect(func() -> void: pivot_offset = size * 0.5)


## The words as drawn (upper case: the ribbon shouts, like the mockup's).
func shown_text() -> String:
	return text.to_upper()


## The words' size: the largest that fits the band's width (between its hems).
func font_size() -> int:
	var f := HudStyle.font(true)
	var w := size.x - 28.0 * scale_factor
	var fs := roundi(FONT_MAX * scale_factor)
	while (
		fs > FONT_MIN and f.get_string_size(shown_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w
	):
		fs -= 1
	return fs


func _draw() -> void:
	if text == "" or size.x < 4.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(r.position + Vector2(0, 3.0 * scale_factor), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, BAND)
	var hem := maxf(1.0, 2.0 * scale_factor)
	draw_rect(Rect2(r.position, Vector2(r.size.x, hem)), BAND.lightened(0.25))
	draw_rect(Rect2(Vector2(0, r.size.y - hem), Vector2(r.size.x, hem)), HEM)
	var f := HudStyle.font(true)
	var fs := font_size()
	var t := shown_text()
	var asc := f.get_ascent(fs)
	var base := Vector2(0, (r.size.y - f.get_height(fs)) * 0.5 + asc)
	draw_string_outline(
		f, base, t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, 3, Color(0, 0, 0, 0.5)
	)
	draw_string(f, base, t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, INK)
