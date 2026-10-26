class_name AbilitySquares
extends Control
## The four ability squares, bottom right (v0.9.5 HU; owner: "the abilities with cooldown to the right, blink, dash,
## attack and L2 shot ... a bigger square that help you visualize the cooldown better", Risk of Rain's row; HM design
## A). In order: Attack, Skill, Dash, Blink (the Blade's guard takes the Blink place). A square the build does not
## have is hidden and the rest close up toward the right edge. A dark cover falls over a cooling square with the
## seconds left; a ready square has a lit border and flashes white for 0.15 s the tick it becomes ready. The binding
## glyph (the live binding of the last device used) sits in a pill at the bottom-left corner; Blink's charges at the
## top right. Reads WorldReader only (EI-07).

const SIDE := 76.0
const GAP := 6.0
## Distance from the right and the bottom edge (px). The HP plate shares the bottom line (owner, 2026-10-26).
const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 20.0
const PLATE := Color("#1A1D24", 0.88)
const BORDER := Color("#C8CCD4", 0.30)
const BORDER_READY := Color("#E8EAEE")
const ICON := Color("#E8EAEE")
const COVER := Color(0, 0, 0, 0.65)
const SECONDS_FONT := 30
const SECONDS_OUTLINE := 3
const GLYPH_FONT := 13
const FLASH_SECONDS := 0.15
const FLASH_ALPHA := 0.45
## Under this many seconds the digits show one decimal.
const DECIMAL_BELOW := 10.0
## The PlayStation names of the pad glyphs.
const PS_NAMES := {"RT": "R2", "LT": "L2", "RB": "R1", "LB": "L1"}

## True while the last device used was a gamepad (tests set it).
var pad_active := false
var _slots: Array[Dictionary] = []
var _flash := {}
var _was_cooling := {}


func _init() -> void:
	name = "AbilitySquares"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pad_active = not Input.get_connected_joypads().is_empty()
	visible = false


func _input(event: InputEvent) -> void:
	var was := pad_active
	pad_active = pad_after(event, pad_active)
	if pad_active != was:
		queue_redraw()


## Whether the pad is the device in use after `event` (a key or mouse event: no; a pad button or a pushed stick: yes).
static func pad_after(event: InputEvent, was: bool) -> bool:
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		return false
	if (
		event is InputEventJoypadButton
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3)
	):
		return true
	return was


func _process(delta: float) -> void:
	if _flash.is_empty():
		return
	for id: StringName in _flash.keys():
		_flash[id] = maxf(0.0, float(_flash[id]) - delta)
		if float(_flash[id]) <= 0.0:
			_flash.erase(id)
	queue_redraw()


func sync(reader: WorldReader) -> void:
	_slots.clear()
	var blade := reader.weapon_id() == &"combo_sword"
	_slots.append(
		_slot(
			&"attack",
			&"combo_sword" if blade else &"pulse_gun",
			&"primary" if blade else &"shoot",
			0,
			1
		)
	)
	var sk := reader.skill_state()
	if not sk.is_empty():
		var lunge := int(sk["kind"]) == WorldReader.SKILL_LUNGE_CLEAVE
		_slots.append(
			_slot(
				&"skill",
				&"lunge_cleave" if lunge else &"skill",
				&"skill",
				int(sk["cooldown"]),
				int(sk["cooldown_total"])
			)
		)
	_slots.append(
		_slot(&"dash", &"dash", &"dash", reader.dash_cooldown(), reader.dash_cooldown_total())
	)
	if reader.has_blink():
		var charges := 0
		var left := reader.blink_cooldown()
		for a in reader.abilities():
			if int(a["kind"]) == WorldReader.ABILITY_BLINK:
				charges = int(a["charges"])
				if a["ready"]:
					left = 0
		_slots.append(
			_slot(&"blink", &"blink", &"utility", left, reader.blink_cooldown_total(), charges)
		)
	elif reader.has_guard():
		_slots.append(_slot(&"blink", &"aegis", &"utility", 0, 1))
	for s in _slots:
		var id: StringName = s["id"]
		var cooling: bool = s["cooling"]
		if _was_cooling.get(id, false) and not cooling and not ViewPrefs.reduced_motion:
			_flash[id] = FLASH_SECONDS
		_was_cooling[id] = cooling
	visible = true
	queue_redraw()


func _slot(
	id: StringName, icon: StringName, action: StringName, left: int, total: int, charges := 0
) -> Dictionary:
	var share := clampf(float(left) / float(maxi(1, total)), 0.0, 1.0)
	return {
		"id": id,
		"icon": icon,
		"action": action,
		"share": share,
		"seconds": float(left) / SimTick.TICKS_PER_SECOND,
		"cooling": left > 0,
		"charges": charges,
		"glyph": glyph_text(action, pad_active),
	}


## The binding name for `action` on the keyboard or the pad. A PlayStation pad's names are R2 / L2 / R1 / L1.
static func glyph_text(action: StringName, pad: bool) -> String:
	var t := InputLabels.short_text(KitHud.key_spec_for(action, pad))
	if pad and is_playstation(Input.get_joy_name(0)) and PS_NAMES.has(t):
		return PS_NAMES[t]
	return t


static func is_playstation(joy_name: String) -> bool:
	var n := joy_name.to_lower()
	for w in ["ps3", "ps4", "ps5", "playstation", "dualshock", "dualsense", "sony"]:
		if n.contains(w):
			return true
	return false


## The seconds as the square prints them: one decimal under 10 s, whole seconds above.
static func seconds_text(secs: float) -> String:
	return "%.1f" % secs if secs < DECIMAL_BELOW else str(ceili(secs))


func _rect_of(k: int) -> Rect2:
	var total := _slots.size() * SIDE + maxi(0, _slots.size() - 1) * GAP
	var x0 := size.x - MARGIN_RIGHT - total
	return Rect2(Vector2(x0 + k * (SIDE + GAP), size.y - MARGIN_BOTTOM - SIDE), Vector2(SIDE, SIDE))


func _draw() -> void:
	for k in _slots.size():
		_square(_rect_of(k), _slots[k])


func _square(r: Rect2, s: Dictionary) -> void:
	var cooling: bool = s["cooling"]
	var box := StyleBoxFlat.new()
	box.bg_color = PLATE
	box.border_color = BORDER if cooling else BORDER_READY
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	draw_style_box(box, r)
	AbilitySquareIcons.draw(self, s["icon"], r.grow(-r.size.x * 0.24), ICON)
	if cooling:
		var inner := r.grow(-2.0)
		draw_rect(
			Rect2(inner.position, Vector2(inner.size.x, inner.size.y * float(s["share"]))), COVER
		)
		_text(
			seconds_text(float(s["seconds"])),
			r.position + Vector2(0, r.size.y * 0.5 - 18.0),
			r.size.x
		)
	var f := float(_flash.get(s["id"], 0.0))
	if f > 0.0:
		var a := f / FLASH_SECONDS
		draw_rect(r, Color(1, 1, 1, FLASH_ALPHA * a))
		draw_rect(r, Color(1, 1, 1, a), false, 2.0)
	_pill(s["glyph"], r.position + Vector2(-5.0, r.size.y - 17.0))
	if int(s["charges"]) > 1:
		var c := r.position + Vector2(r.size.x - 13.0, 13.0)
		draw_circle(c, 11.0, Color(0, 0, 0, 0.85))
		draw_arc(c, 11.0, 0.0, TAU, 24, Color(ICON, 0.9), 1.5)
		draw_string(
			HudStyle.font(true),
			c + Vector2(-11, 6),
			str(s["charges"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			22,
			16,
			Color.WHITE
		)


func _text(t: String, at: Vector2, w: float) -> void:
	var f := HudStyle.font(true)
	var p := at + Vector2(0, SECONDS_FONT)
	draw_string_outline(
		f, p, t, HORIZONTAL_ALIGNMENT_CENTER, w, SECONDS_FONT, SECONDS_OUTLINE, Color(0, 0, 0, 0.85)
	)
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_CENTER, w, SECONDS_FONT, Color.WHITE)


func _pill(t: String, at: Vector2) -> void:
	if t == "":
		return
	var f := HudStyle.font(true)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, GLYPH_FONT).x + 14.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.03, 0.05, 0.92)
	box.border_color = Color(1, 1, 1, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	draw_style_box(box, Rect2(at, Vector2(w, 20)))
	draw_string(
		f,
		at + Vector2(0, 1 + GLYPH_FONT),
		t,
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		GLYPH_FONT,
		Color.WHITE
	)


## The clockwise wedge (the Vent plate's cooldown) on any canvas item.
static func draw_sweep(item: CanvasItem, r: Rect2, share: float) -> void:
	var c := r.get_center()
	var rad := r.size.length() * 0.5
	var pts := PackedVector2Array([c])
	var steps := maxi(2, int(ceil(share * 24.0)))
	for k in steps + 1:
		var a := -PI * 0.5 + TAU * share * k / steps
		var p := c + Vector2(cos(a), sin(a)) * rad
		pts.append(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))
	item.draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, 0.62))


# --- Reads (tests) ------------------------------------------------------------------------------------------
## The shown squares' ids, in order.
func shown() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in _slots:
		out.append(s["id"])
	return out


func slot_of(id: StringName) -> Dictionary:
	for s in _slots:
		if s["id"] == id:
			return s
	return {}


## The cooldown cover's height in px for `id` (0 when ready).
func cover_height(id: StringName) -> float:
	var s := slot_of(id)
	return 0.0 if s.is_empty() or not s["cooling"] else (SIDE - 4.0) * float(s["share"])


func flashing(id: StringName) -> bool:
	return float(_flash.get(id, 0.0)) > 0.0


## The global rect of square `id` (card flights land there); an empty rect when it is not shown.
func rect_of(id: StringName) -> Rect2:
	for k in _slots.size():
		if _slots[k]["id"] == id:
			var r := _rect_of(k)
			return Rect2(r.position + global_position, r.size)
	return Rect2()


## Blink's charge count is printed in the corner circle only above one.
func charges_shown(id: StringName) -> bool:
	return int(slot_of(id).get("charges", 0)) > 1
