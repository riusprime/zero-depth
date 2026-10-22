class_name SlotPips
extends HBoxContainer
## v0.9.0 AS2 (owner, step AS's G2: "B: ribbon + pips"; PLAN "Owner decisions" AS): the wand's slot categories as a row
## of pips over the wand, on the Build page and the Swap panel: per limited category its mark (SlotGlyph), its tag and
## one pip per card it may hold, lit for each held ("Pattern ●", "Secondary ●●", "Element ●○"); the Form first with the
## form fired now ("Form: Orbs ●"). The limits are data (data/wand/attack_slots.tres: on a Gun run Form 1, Pattern 1,
## Secondary 2, Element 2; on a Blade run only Pattern 1). It reads the wand read (WorldReader.wand: "form",
## "slot_counts") and decides nothing (EI-07). Hidden on a run without limits.

const TYPE_SIZE := 20
const GLYPH := 18.0
const PIP := 14.0
## The pips' colours: a held card's (the ember) and an empty slot's ring.
const LIT := Color("#EBAE72")
const EMPTY := Color(0.8, 0.72, 0.63, 0.7)

var _counts: Array = []
var _form := ""


## The pips of one category: `held` lit of `limit`.
class Dots:
	extends Control
	var held := 0
	var limit := 0

	func _init(p_held: int, p_limit: int) -> void:
		held = p_held
		limit = p_limit
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(PIP * limit + 5.0 * maxi(0, limit - 1), PIP)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var r := PIP * 0.5
		for k in limit:
			var c := Vector2(r + k * (PIP + 5.0), size.y * 0.5)
			if k < held:
				draw_circle(c, r, LIT)
			else:
				draw_arc(c, r - 1.0, 0.0, TAU, 20, EMPTY, 1.6, true)


func _init() -> void:
	name = "SlotPips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	visible = false


## Shows wand read `wand`'s categories (its "slot_counts": [category, held, limit]) and its form.
func show_wand(wand: Dictionary) -> void:
	_counts = wand.get("slot_counts", []).duplicate()
	_form = String(wand.get("form", ""))
	_rebuild()


## The categories shown, [category, held, limit] each (tests).
func counts() -> Array:
	return _counts


## The row as words ("Form: Orbs ●  ·  Pattern ●  ·  Secondary ●●  ·  Element ●○"; tests and the read-out).
func text() -> String:
	var parts := PackedStringArray()
	for e: Array in _counts:
		var held := _held(e)
		parts.append(
			"%s %s" % [_label_of(int(e[0])), "●".repeat(held) + "○".repeat(int(e[2]) - held)]
		)
	return "  ·  ".join(parts)


## Category entry `e`'s lit pips: its held cards; the Form's is lit by the form fired now (the Orbs need no card).
func _held(e: Array) -> int:
	if int(e[0]) == WorldReader.SLOT_FORM and _form != "":
		return maxi(int(e[1]), 1)
	return int(e[1])


func _label_of(cat: int) -> String:
	if cat == WorldReader.SLOT_FORM and _form != "":
		return tr("UI_BUILD_FORM") % tr("UI_FORM_" + _form.to_upper())
	return tr(WorldReader.SLOT_TAG_KEYS[cat])


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	visible = not _counts.is_empty()
	for e: Array in _counts:
		var cat := int(e[0])
		var held := _held(e)
		var g := SlotGlyph.new(GLYPH)
		g.slot = cat
		g.color = LIT
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(g)
		var l := Label.new()
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text = _label_of(cat)
		l.add_theme_font_size_override("font_size", TYPE_SIZE)
		l.add_theme_color_override("font_color", MenuStyle.TEXT)
		add_child(l)
		var d := Dots.new(held, int(e[2]))
		add_child(d)
		if e != _counts.back():
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(22, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(gap)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _counts.is_empty():
		_rebuild.call_deferred()  # not while the tree is sending the notification
