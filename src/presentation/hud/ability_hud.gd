class_name AbilityHud
extends Control
## The four ability slots (v0.4.0 BS, owner F8), a row above the HP plate: each slot a flat square (CardStyle's
## look) with the ability's code-drawn symbol (AbilityIcons), a cooldown sweep that empties clockwise as it
## recharges, five level pips under it, and for a manual ability its bound key (the live binding, so a remap shows
## at once). Empty slots are dim outlines. Reads WorldReader only (EI-07).
## Owner, 2026-10-07: "spell cooldowns have to be a bit bigger": the slots are 52 px (the dash and utility squares
## are 12 px), with the seconds left over the sweep while more than 1 s remains; the frame follows CardStyle.current.

const SLOT := 52.0
const SECONDS_FONT := 17
const GAP := 10.0
const PIP := 6.0
const KEY_FONT := 12
## Above the anchor's top edge (px).
const LIFT := 12.0
const SWEEP := Color(0.0, 0.0, 0.0, 0.62)

## The HP plate the row sits on (Hud sets it; may be null).
var anchor: Control
var _slots: Array[AbilitySlot] = []


func _init() -> void:
	name = "AbilityHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in WorldReader.ABILITY_SLOTS:
		var s := AbilitySlot.new()
		s.name = "AbilitySlot%d" % (k + 1)
		s.size = Vector2(SLOT, SLOT)
		add_child(s)
		_slots.append(s)
	visible = false


func sync(reader: WorldReader) -> void:
	var owned := reader.abilities()
	visible = not owned.is_empty()
	if not visible:
		return
	for k in _slots.size():
		var s := _slots[k]
		if k >= owned.size():
			s.show_empty()
			continue
		var a: Dictionary = owned[k]
		var key := ""
		if not a["auto"]:
			key = KitHud.key_text(_action_of(int(a["kind"])))
		var fill := 1.0 - clampf(float(a["cooldown"]) / float(a["cooldown_total"]), 0.0, 1.0)
		var secs := float(a["cooldown"]) / SimTick.TICKS_PER_SECOND
		s.show_ability(a["id"], int(a["level"]), fill, a["ready"], key, int(a["charges"]), secs)
	_place()


## The input action a manual ability answers.
static func _action_of(kind: int) -> StringName:
	match kind:
		WorldReader.ABILITY_COMBO_SWORD:
			return &"primary"
		WorldReader.ABILITY_PULSE_GUN:
			return &"shoot"
	return &"utility"


func _place() -> void:
	var origin := Vector2(28, get_viewport_rect().size.y - 260)
	if anchor != null and anchor.is_inside_tree():
		var r := anchor.get_global_rect()
		origin = Vector2(r.position.x, r.position.y - LIFT - SLOT - PIP * 2.0)
	for k in _slots.size():
		_slots[k].global_position = origin + Vector2(k * (SLOT + GAP), 0)


# --- Reads (tests) ------------------------------------------------------------------------------------------
func slot(k: int) -> AbilitySlot:
	return _slots[k]


func filled_count() -> int:
	var n := 0
	for s in _slots:
		n += 1 if s.ability_id != &"" else 0
	return n
