class_name AbilitySquares
extends Control
## The four ability squares, bottom right (v0.9.5 HU; owner: "the abilities with cooldown to the right, blink, dash,
## attack and L2 shot ... a bigger square that help you visualize the cooldown better", Risk of Rain's row; HM design
## A). In order: Attack, Skill, Dash, Blink (the Blade's guard takes the Blink place). A square the build does not
## have is hidden and the rest close up toward the right edge. A dark cover falls over a cooling square with the
## seconds left; a ready square has a lit border and flashes white for 0.15 s the tick it becomes ready. The binding
## glyph (the live binding of the last device used) sits in a pill at the bottom-left corner; Blink's charges at the
## top right. Reads WorldReader only (EI-07).
## UI style Astral: each square holds a round medallion instead of a box (the
## round-2 mock's): an ink disc in a silver ring with a dotted inner ring, four small stars round it while ready;
## cooling, a dark wedge over the part still cooling, a moon-blue arc outside with a diamond at its head, the seconds
## in Cinzel; the binding in a 1 px key cap under it. Same squares, same places, same reads.

const SIDE := 76.0
const GAP := 6.0
## Distance from the right and the bottom edge (px). The HP plate shares the bottom line (owner, 2026-10-26).
const MARGIN_RIGHT := 24.0
const MARGIN_BOTTOM := 20.0
const FLASH_SECONDS := 0.15
const FLASH_ALPHA := 0.45
## Under this many seconds the digits show one decimal.
const DECIMAL_BELOW := 10.0
## The PlayStation names of the pad glyphs.
const PS_NAMES := {"RT": "R2", "LT": "L2", "RB": "R1", "LB": "L1"}
## The medallion's radius inside a square (its cooldown arc runs 6 px outside it).
const A_RADIUS := 29.0

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


## Redraws only when a square's look changed (a ready row with no flash draws nothing a tick).
func sync(reader: WorldReader) -> void:
	var was := _slots.duplicate(true)
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
	if _slots != was:
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
		_medallion(_rect_of(k), _slots[k])


## The square `r` as an Astral medallion (AstralHudParts.medallion), its icon, seconds, flash, charges
## and key cap.
func _medallion(r: Rect2, s: Dictionary) -> void:
	var cooling: bool = s["cooling"]
	var c := (r.get_center() - Vector2(0, 5)).round()
	var rad := A_RADIUS
	AstralHudParts.medallion(self, c, rad, float(s["share"]) if cooling else 0.0)
	var ir := roundf(rad * 0.52)
	var icol := HudStyle.A_TEXT if not cooling else Color(HudStyle.A_METAL, 0.3)
	AbilitySquareIcons.draw(
		self, s["icon"], Rect2(c - Vector2.ONE * ir, Vector2.ONE * ir * 2.0), icol
	)
	if cooling:
		AstralHudParts.serif_text(
			self,
			seconds_text(float(s["seconds"])),
			Vector2(r.position.x, c.y + 8.0),
			22,
			HudStyle.A_TEXT,
			HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x,
			0,
			700
		)
	var f := float(_flash.get(s["id"], 0.0))
	if f > 0.0:
		var a := f / FLASH_SECONDS
		draw_circle(c, rad, Color(HudStyle.A_LINE_HI, FLASH_ALPHA * a))
		draw_arc(c, rad + 1.0, 0.0, TAU, 72, Color(HudStyle.A_LINE_HI, a), 2.0, true)
	AstralHudParts.keycap(self, s["glyph"], Vector2(c.x, r.end.y - 1.0))
	if int(s["charges"]) > 1:
		var cc := c + Vector2(rad * 0.74, -rad * 0.74)
		draw_circle(cc, 10.0, Color(HudStyle.A_INK, 0.92))
		draw_arc(cc, 10.0, 0.0, TAU, 32, HudStyle.A_METAL, 1.0, true)
		AstralHudParts.serif_text(
			self,
			str(s["charges"]),
			cc + Vector2(-10, 5),
			14,
			HudStyle.A_TEXT,
			HORIZONTAL_ALIGNMENT_CENTER,
			20,
			0,
			700
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


## Where the squares draw (global px): their rects (the arcs, stars and key caps reach a few px past them; HudStill
## adds its margin).
func drawn_rect() -> Rect2:
	var out := Rect2()
	for k in _slots.size():
		var r := _rect_of(k)
		out = r if k == 0 else out.merge(r)
	return Rect2(out.position + global_position, out.size)


## Blink's charge count is printed in the corner circle only above one.
func charges_shown(id: StringName) -> bool:
	return int(slot_of(id).get("charges", 0)) > 1
