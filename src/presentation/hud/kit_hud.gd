class_name KitHud
extends Control
## The Vent hint on the HUD (v0.3.5 K, owner F1 and F18), kept apart from the HP plate and the heat meter so either
## can change look without touching this: "[F] VENT" beside the heat meter, bright while venting would blast (Hot),
## dim otherwise, with the 6 s cooldown as a wedge and the seconds left. v0.9.5 HU: the Skill's pip is gone; the Skill
## is one of the ability squares now (AbilitySquares).
## Reads WorldReader only (EI-07); the keys come from the live bindings (InputRebind), so a remap shows at once.
## v0.5.5 A5: it sits on a small HudFrame slab of its own (the HUD's Ember stone look), beside its anchor.

const GAP := 16.0
const FONT_SIZE := 14
const DIM_ALPHA := 0.4

## The heat meter the Vent plate sits beside (Hud sets it; may be null).
var heat_anchor: Control
var _vent_plate := HudFrame.new(Vector2(10, 4))
var _vent := Label.new()
var _vent_sweep := VentSweep.new()


## The Vent plate's cooldown wedge (v0.9.5 HT): the share still cooling, drawn clockwise from twelve o'clock.
class VentSweep:
	extends Control
	var share := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if share >= 0.01 and size.x > 1.0 and size.y > 1.0:  # a thinner wedge is degenerate (no triangulation)
			AbilitySquares.draw_sweep(self, Rect2(Vector2.ZERO, size), minf(share, 0.99))


func _init() -> void:
	name = "KitHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vent.name = "VentHint"
	_vent.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HudStyle.style_label(_vent, FONT_SIZE, true)
	_vent_plate.name = "VentPlate"
	_vent_plate.add_child(_vent)
	_vent_sweep.name = "VentSweep"
	_vent_sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vent_plate.add_child(_vent_sweep)
	add_child(_vent_plate)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vent.visible = false
	_vent_plate.visible = false


func sync(reader: WorldReader) -> void:
	var h := reader.heat_state()
	_vent.visible = not h.is_empty()
	_vent_plate.visible = _vent.visible
	if _vent.visible:
		_vent.text = tr("HUD_KEY_HINT") % [key_text(&"vent"), tr("HUD_VENT")]
		var hot: bool = h["vent_ready"]
		# v0.9.5 HT: the 6 s cooldown, as the ability squares show theirs: a sweep and the seconds left.
		var left := int(h["vent_cd"])
		_vent_sweep.share = float(left) / maxf(1.0, float(h["vent_cd_total"]))
		_vent_sweep.queue_redraw()
		if left > 0:
			_vent.text += " %d" % ceili(left / float(SimTick.TICKS_PER_SECOND))
		_vent.modulate = Color(HudStyle.HEAT[1], 1.0) if hot else Color(1, 1, 1, DIM_ALPHA)
	_place()


## The bound key's name for `action`: the pad's when a pad is connected, else the keyboard's.
static func key_text(action: StringName) -> String:
	return InputLabels.text(key_spec(action))


## The binding shown for `action`: the pad's when a pad is connected, else the keyboard's.
static func key_spec(action: StringName) -> Array:
	return key_spec_for(action, not Input.get_connected_joypads().is_empty())


## The binding of `action` on the pad (`pad`) or the keyboard; the keyboard's when the pad has none.
static func key_spec_for(action: StringName, pad: bool) -> Array:
	var spec := InputRebind.binding(action, InputRebind.PAD if pad else InputRebind.KBM)
	if spec.is_empty():
		spec = InputRebind.binding(action, InputRebind.KBM)
	return spec


func _place() -> void:
	if heat_anchor != null and heat_anchor.is_inside_tree():
		var m := heat_anchor.get_global_rect()
		var pv := _vent_plate.get_combined_minimum_size()
		_vent_plate.size = pv
		_vent_plate.global_position = Vector2(m.end.x + GAP * 0.5, m.end.y - pv.y)


# --- Reads (tests) ------------------------------------------------------------------------------------------
func vent_visible() -> bool:
	return _vent.visible


## The share of the Vent plate's cooldown wedge still cooling, 1 (just vented) .. 0 (ready).
func vent_sweep_share() -> float:
	return _vent_sweep.share


func vent_text() -> String:
	return _vent.text


## The vent hint is lit (venting now would blast).
func vent_lit() -> bool:
	return _vent.visible and _vent.modulate.a > DIM_ALPHA + 0.01
