class_name KitHud
extends Control
## The Vent and Skill buttons on the HUD (v0.3.5 K, owner F1 and F18), kept apart from the HP plate and the heat
## meter so either can change look without touching this:
## - the skill pip, beside the HP bar: a square that fills as the cooldown runs out, then "[Q] LUNGE CLEAVE" (the
##   bound key and the build's skill name); lit when the skill is ready;
## - the vent hint, beside the heat meter: "[F] VENT", bright while venting would blast (Hot), dim otherwise.
## Reads WorldReader only (EI-07); the keys come from the live bindings (InputRebind), so a remap shows at once.

const PIP := 22.0
const GAP := 16.0
const FONT_SIZE := 14
const DIM_ALPHA := 0.4

## The HP bar and the heat meter the two sit beside (Hud sets them; either may be null).
var hp_anchor: Control
var heat_anchor: Control
var _skill := HBoxContainer.new()
var _skill_back := ColorRect.new()
var _skill_fill := ColorRect.new()
var _skill_label := Label.new()
var _vent := Label.new()
var _ready := 0.0


func _init() -> void:
	name = "KitHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill.name = "SkillPip"
	_skill.add_theme_constant_override("separation", 8)
	_skill_back.custom_minimum_size = Vector2(PIP, PIP)
	_skill_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skill_back.color = HudStyle.dim()
	_skill_fill.color = ThemePalette.color(&"player_core")
	_skill_fill.size = Vector2(PIP, PIP)
	_skill_back.add_child(_skill_fill)
	_skill.add_child(_skill_back)
	_skill_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HudStyle.style_label(_skill_label, FONT_SIZE, true)
	_skill.add_child(_skill_label)
	add_child(_skill)
	_vent.name = "VentHint"
	_vent.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HudStyle.style_label(_vent, FONT_SIZE, true)
	add_child(_vent)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill.visible = false
	_vent.visible = false


func sync(reader: WorldReader) -> void:
	var s := reader.skill_state()
	_skill.visible = not s.is_empty()
	if _skill.visible:
		var cd := float(s["cooldown"])
		_ready = 1.0 - clampf(cd / maxf(1.0, float(s["cooldown_total"])), 0.0, 1.0)
		_skill_fill.size = Vector2(PIP, PIP * _ready)
		_skill_fill.position = Vector2(0, PIP * (1.0 - _ready))
		_skill_fill.color = ThemePalette.color(&"player_core").lightened(
			0.35 if s["ready"] else 0.0
		)
		var key := (
			"SKILL_LUNGE_CLEAVE"
			if int(s["kind"]) == WorldReader.SKILL_LUNGE_CLEAVE
			else "SKILL_SCATTER_BLAST"
		)
		_skill_label.text = tr("HUD_KEY_HINT") % [key_text(&"skill"), tr(key)]
		_skill_label.modulate.a = 1.0 if s["ready"] else 0.7
	var h := reader.heat_state()
	_vent.visible = not h.is_empty()
	if _vent.visible:
		_vent.text = tr("HUD_KEY_HINT") % [key_text(&"vent"), tr("HUD_VENT")]
		var hot: bool = h["vent_ready"]
		_vent.modulate = Color(HudStyle.HEAT[1], 1.0) if hot else Color(1, 1, 1, DIM_ALPHA)
	_place()


## The bound key's name for `action`: the pad's when a pad is connected, else the keyboard's.
static func key_text(action: StringName) -> String:
	var pad := not Input.get_connected_joypads().is_empty()
	var spec := InputRebind.binding(action, InputRebind.PAD if pad else InputRebind.KBM)
	if spec.is_empty():
		spec = InputRebind.binding(action, InputRebind.KBM)
	return InputLabels.text(spec)


func _place() -> void:
	if hp_anchor != null and hp_anchor.is_inside_tree():
		var r := hp_anchor.get_global_rect()
		_skill.global_position = Vector2(r.end.x + GAP, r.position.y + (r.size.y - PIP) * 0.5)
	if heat_anchor != null and heat_anchor.is_inside_tree():
		var m := heat_anchor.get_global_rect()
		_vent.global_position = Vector2(m.end.x + GAP * 0.5, m.end.y - _vent.size.y - 8.0)


# --- Reads (tests) ------------------------------------------------------------------------------------------
func skill_visible() -> bool:
	return _skill.visible


## The pip's fill, 0 (just used) .. 1 (ready).
func skill_fill() -> float:
	return _ready


func skill_text() -> String:
	return _skill_label.text


func vent_visible() -> bool:
	return _vent.visible


func vent_text() -> String:
	return _vent.text


## The vent hint is lit (venting now would blast).
func vent_lit() -> bool:
	return _vent.visible and _vent.modulate.a > DIM_ALPHA + 0.01
