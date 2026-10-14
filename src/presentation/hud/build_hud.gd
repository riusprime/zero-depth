class_name BuildHud
extends Control
## The build at a glance (v0.6.0 MX2; owner B7): the weapon, the utility pick and the modifier slot pips (v0.6.5 WN1:
## as many as the wand has now, 4 → 6 → 8), a
## small row above the ability row. A filled pip wears its card family's frame colour (CardFrames) with the card's
## level on it (an attack item: no number); an empty pip is a dim outline. Minimal on purpose (Step UI restyles the
## HUD); reads WorldReader only (EI-07).
## v0.6.0 UP: the row sits on a small Ember stone slab (HudFrame) like the HUD's other plates; a filled pip is its
## family's colour inside a dark stone rim, an empty pip a dim stone chip (as an empty ability slot).
## v0.8.0 MU (Ember stone, owner O14): a pip is a small carved stone chip; a filled one holds a glowing inlay ring in
## its family's colour round its level (InlaySocket's ring), an empty one is an unlit chip.
## v0.6.5 WN2: the pips are the wand's slots in order (left to right, as the wand reads); a trigger card's pip wears a
## small "›" and a thin ember cut stands after it (the cards to its right are what it casts).

const PIP := 20.0
const GAP := 4.0
## v0.6.5 WN2: a trigger's cut between pips (px wide).
const CUT_W := 2.0
## v0.6.5 WN2: the mark on a trigger card's pip.
const TRIGGER_MARK := "›"
## Above the anchor's top edge (px): clears the ability row (AbilityHud).
const LIFT := 12.0 + AbilityHud.SLOT + AbilityHud.PIP * 2.0 + AbilityHud.LIFT + 8.0

## The HP plate the row sits over (Hud sets it; may be null).
var anchor: Control
var _plate := HudFrame.new(Vector2(10, 5))
var _row := HBoxContainer.new()
var _weapon := HudStyle.label(14, true)
var _utility := HudStyle.label(14)
var _pips: Array[Panel] = []
## P-3: each pip's own StoneBox, set once; sync recolours it (a bound StyleBox redraws its panel itself).
var _boxes: Array[StoneBox] = []
var _levels: Array[Label] = []
## v0.6.5 WN2: the cut after each pip (shown after a trigger card's).
var _cuts: Array[ColorRect] = []
var _filled := 0


func _init() -> void:
	name = "BuildHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", int(GAP))
	_plate.name = "BuildPlate"
	_plate.add_child(_row)
	add_child(_plate)
	for l: Label in [_weapon, _utility]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(l)
	for k in WorldReader.MOD_SLOTS:
		var p := Panel.new()
		p.name = "ModPip%d" % (k + 1)
		p.custom_minimum_size = Vector2(PIP, PIP)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StoneBox.new()
		box.pattern = 3 + k * 5
		box.cut = 4.0
		box.chip = 1.0
		box.cracks = 0
		box.under = 0.0
		box.shadow = false
		box.ring = Rect2(Vector2(2.5, 2.5), Vector2(PIP - 5.0, PIP - 5.0))
		p.add_theme_stylebox_override("panel", box)
		_boxes.append(box)
		var lv := HudStyle.label(12, true)
		lv.set_anchors_preset(Control.PRESET_FULL_RECT)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lv.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(lv)
		_row.add_child(p)
		_pips.append(p)
		_levels.append(lv)
		var cut := ColorRect.new()
		cut.name = "ModCut%d" % (k + 1)
		cut.custom_minimum_size = Vector2(CUT_W, PIP)
		cut.color = Color(HudStyle.accent(), 0.85)
		cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut.visible = false
		_row.add_child(cut)
		_cuts.append(cut)
	visible = false


func sync(reader: WorldReader) -> void:
	var weapon := reader.weapon_id()
	var abilities := reader.abilities()
	visible = weapon != &"" or not abilities.is_empty()
	if not visible:
		return
	var names := {}
	for a: Dictionary in abilities:
		names[a["id"]] = a["name_key"]
	_weapon.text = tr(names.get(weapon, &"")) if weapon != &"" else ""
	var util := reader.utility_id()
	_utility.text = "· %s" % tr(names[util]) if util != &"" and names.has(util) else ""
	_utility.visible = _utility.text != ""
	var b := reader.build()
	var slots: Array = b["slots"]
	_filled = mini(slots.size(), _pips.size())
	var shown := maxi(int(b["max"]), slots.size())  # v0.6.5 WN1: the wand's slots now (4 → 6 → 8)
	var cuts: PackedInt32Array = reader.wand()["cuts"]  # v0.6.5 WN2: the trigger cards' slots
	for k in _pips.size():
		_pips[k].visible = k < shown
		var box := _boxes[k]
		if k < slots.size():
			var s: Dictionary = slots[k]
			var tint := CardFrames.tint(
				CardFrames.frame_of(CardFrames.family(s["id"], int(s["type"])))
			)
			box.ring_color = tint
			box.dim = 1.0
			var ability := int(s["type"]) == WorldReader.CARD_ABILITY
			# v0.7.5 SM (N8): a wand card shows its level (1–5) on its pip too
			var levels := ability or bool(reader.card_info(int(s["code"])).get("wand", false))
			_levels[k].text = str(int(s["level"])) if levels else ""
			if k in cuts:
				_levels[k].text = TRIGGER_MARK
		else:
			box.ring_color = Color(0, 0, 0, 0)
			box.dim = 0.55
			_levels[k].text = ""
		_cuts[k].visible = k in cuts and k < shown - 1
	_place()


func _place() -> void:
	var origin := Vector2(28, get_viewport_rect().size.y - 330)
	if anchor != null and anchor.is_inside_tree():
		origin = anchor.get_global_rect().position - Vector2(0, LIFT + PIP)
	_plate.size = _plate.get_combined_minimum_size()
	_plate.global_position = origin - Vector2(0, (_plate.size.y - PIP) * 0.5)


# --- Reads (tests) ------------------------------------------------------------------------------------------
func filled_pips() -> int:
	return _filled


## v0.8.0 MU: pip k's stone chip (its ring is its family's colour).
func pip_box(k: int) -> StoneBox:
	return _boxes[k]


func pip_level_text(k: int) -> String:
	return _levels[k].text


## v0.6.5 WN2: the slots a cut stands after (a trigger card's, not the last slot).
func cut_slots() -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in _cuts.size():
		if _cuts[k].visible:
			out.append(k)
	return out
