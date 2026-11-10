class_name SpellSquares
extends Control
## The spell slots,
## four small squares right-aligned just above the ability squares (AbilitySquares). Each held slot shows its
## spell's placeholder icon (SpellLooks) in its element's colour; while it cools, a dark wedge sweeps round clockwise
## over the part still cooling, and the tick it casts the square flashes white for FLASH_SECONDS. An empty slot is a dim
## outline. Hidden until the run holds a spell. Reads WorldReader.spells() only (EI-07).

const SIDE := 40.0
const GAP := 6.0
## The band's height above the ability squares (Hud.ITEMS_LIFT leaves room for it).
const BAND := SIDE + 10.0
const PLATE := Color("#1A1D24", 0.88)
const EMPTY := Color("#C8CCD4", 0.18)
const COVER := Color(0, 0, 0, 0.62)
const FLASH_SECONDS := 0.25
const FLASH_ALPHA := 0.6
const SWEEP_POINTS := 24

var _slots: Array = []
var _max := 4
## Per slot: the last cast tick seen, and the flash left (s).
var _cast_seen: Array[int] = []
var _flash: Array[float] = []


func _init() -> void:
	name = "SpellSquares"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visible = false


func _process(delta: float) -> void:
	var any := false
	for k in _flash.size():
		if _flash[k] > 0.0:
			_flash[k] = maxf(0.0, _flash[k] - delta)
			any = true
	if any:
		queue_redraw()


func sync(reader: WorldReader) -> void:
	var sp := reader.spells()
	_slots = sp["slots"]
	_max = maxi(int(sp["max"]), _slots.size())
	if _cast_seen.size() != _max:
		_cast_seen.resize(_max)
		_flash.resize(_max)
		for k in _max:
			_cast_seen[k] = -1
			_flash[k] = 0.0
	for k in _slots.size():
		var cast := int((_slots[k] as Dictionary)["cast_tick"])
		if cast >= 0 and cast != _cast_seen[k]:
			if _cast_seen[k] != -1 or cast >= int(sp["tick"]) - 2:
				_flash[k] = 0.0 if ViewPrefs.reduced_motion else FLASH_SECONDS
			_cast_seen[k] = cast
	visible = not _slots.is_empty()
	queue_redraw()


## The squares shown (tests): the slot count.
func slot_count() -> int:
	return _max if visible else 0


## Slot k's spell id (&"": empty).
func spell_id(k: int) -> StringName:
	return (_slots[k] as Dictionary)["id"] if k < _slots.size() else &""


## Slot k's sweep: the share of its cooldown still to run (0 ready, 1 just cast).
func sweep(k: int) -> float:
	if k >= _slots.size():
		return 0.0
	var s: Dictionary = _slots[k]
	return clampf(float(s["cooldown"]) / float(maxi(1, int(s["cooldown_total"]))), 0.0, 1.0)


## Slot k flashes now (its cast).
func flashing(k: int) -> bool:
	return k < _flash.size() and _flash[k] > 0.0


func rect_of(k: int) -> Rect2:
	var total := _max * SIDE + maxi(0, _max - 1) * GAP
	var x0 := size.x - AbilitySquares.MARGIN_RIGHT - total
	var y := size.y - AbilitySquares.MARGIN_BOTTOM - AbilitySquares.SIDE - 8.0 - SIDE
	return Rect2(Vector2(x0 + k * (SIDE + GAP), y), Vector2(SIDE, SIDE))


func _draw() -> void:
	for k in _max:
		var r := rect_of(k)
		if k >= _slots.size():
			var empty := StyleBoxFlat.new()
			empty.bg_color = Color(PLATE, 0.4)
			empty.border_color = EMPTY
			empty.set_border_width_all(1)
			empty.set_corner_radius_all(3)
			draw_style_box(empty, r)
			continue
		var s: Dictionary = _slots[k]
		var c := SpellLooks.color(int(s["element"]))
		var box := StyleBoxFlat.new()
		box.bg_color = PLATE
		box.border_color = c if sweep(k) <= 0.0 else Color(c, 0.45)
		box.set_border_width_all(2)
		box.set_corner_radius_all(3)
		draw_style_box(box, r)
		SpellLooks.draw_icon(self, s["id"], r.grow(-r.size.x * 0.2), c)
		var share := sweep(k)
		if share > 0.0:
			for p in wedge(r.grow(-2.0), share):
				draw_colored_polygon(p, COVER)
		if flashing(k):
			draw_rect(r, Color(1, 1, 1, FLASH_ALPHA * _flash[k] / FLASH_SECONDS))
		if int(s["level"]) > 1:
			draw_string(
				ThemeDB.fallback_font,
				r.position + Vector2(r.size.x - 11.0, r.size.y - 3.0),
				str(int(s["level"])),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color.WHITE
			)


## The part of `r` still cooling: a wedge from 12 o'clock, clockwise over `share` of the turn, cut to the square.
static func wedge(r: Rect2, share: float) -> Array[PackedVector2Array]:
	var o := r.get_center()
	var reach := r.size.length()
	var fan := PackedVector2Array([o])
	var from := -PI * 0.5 + TAU * (1.0 - share)
	var n := maxi(2, int(ceil(SWEEP_POINTS * share)) + 1)
	for k in n:
		var a := from + TAU * share * k / float(n - 1)
		fan.append(o + Vector2(cos(a), sin(a)) * reach)
	var square := PackedVector2Array(
		[r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	)
	var out: Array[PackedVector2Array] = []
	for p: PackedVector2Array in Geometry2D.intersect_polygons(fan, square):
		if p.size() >= 3:
			out.append(p)
	return out
