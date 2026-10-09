class_name BuildHud
extends Control
## The build at a glance (v0.6.0 MX2; owner B7): the weapon, the utility pick and the six modifier slot pips, a
## small row above the ability row. A filled pip wears its card family's frame colour (CardFrames) with the card's
## level on it (an attack item: no number); an empty pip is a dim outline. Minimal on purpose (Step UI restyles the
## HUD); reads WorldReader only (EI-07).
## v0.6.0 UP: the row sits on a small Ember stone slab (HudFrame) like the HUD's other plates; a filled pip is its
## family's colour inside a dark stone rim, an empty pip a dim stone chip (as an empty ability slot).

const PIP := 20.0
const GAP := 4.0
## Above the anchor's top edge (px): clears the ability row (AbilityHud).
const LIFT := 12.0 + AbilityHud.SLOT + AbilityHud.PIP * 2.0 + AbilityHud.LIFT + 8.0

## The HP plate the row sits over (Hud sets it; may be null).
var anchor: Control
var _plate := HudFrame.new(Vector2(10, 5))
var _row := HBoxContainer.new()
var _weapon := HudStyle.label(14, true)
var _utility := HudStyle.label(14)
var _pips: Array[Panel] = []
var _levels: Array[Label] = []
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
	visible = false


func sync(reader: WorldReader) -> void:
	var weapon := reader.weapon_id()
	visible = weapon != &"" or not reader.abilities().is_empty()
	if not visible:
		return
	var names := {}
	for a: Dictionary in reader.abilities():
		names[a["id"]] = a["name_key"]
	_weapon.text = tr(names.get(weapon, &"")) if weapon != &"" else ""
	var util := reader.utility_id()
	_utility.text = "· %s" % tr(names[util]) if util != &"" and names.has(util) else ""
	_utility.visible = _utility.text != ""
	var slots: Array = reader.build()["slots"]
	_filled = mini(slots.size(), _pips.size())
	for k in _pips.size():
		var box := StyleBoxFlat.new()
		box.set_border_width_all(1)
		if k < slots.size():
			var s: Dictionary = slots[k]
			var tint := CardFrames.tint(
				CardFrames.frame_of(CardFrames.family(s["id"], int(s["type"])))
			)
			box.bg_color = Color(tint, 0.85)
			box.border_color = HudStyle.STONE_EDGE
			var ability := int(s["type"]) == WorldReader.CARD_ABILITY
			_levels[k].text = str(int(s["level"])) if ability else ""
		else:
			box.bg_color = Color(HudStyle.STONE_EDGE, 0.55)
			box.border_color = Color(HudStyle.EMBER_TEXT, 0.22)
			_levels[k].text = ""
		_pips[k].add_theme_stylebox_override("panel", box)
	_place()


func _place() -> void:
	var origin := Vector2(28, get_viewport_rect().size.y - 330)
	if anchor != null and anchor.is_inside_tree():
		origin = anchor.get_global_rect().position - Vector2(0, LIFT + PIP)
	_plate.size = _plate.get_combined_minimum_size()
	_plate.global_position = origin - Vector2(0, (_plate.size.y - PIP) * 0.5)


## The slab's rect on screen (tests: it stays inside the left part of the HUD in every language).
func plate_rect() -> Rect2:
	return _plate.get_global_rect()


# --- Reads (tests) ------------------------------------------------------------------------------------------
func filled_pips() -> int:
	return _filled


func pip_level_text(k: int) -> String:
	return _levels[k].text


func weapon_text() -> String:
	return _weapon.text
