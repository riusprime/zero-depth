class_name OptionsMenu
extends Control
## The Options screen (v0.3.0 O; G2 mockups in docs/roadmap/v0.3.0/evidence/options_mockups.png): Audio, Display,
## Controls, Accessibility and Language. Opens from the main menu and from the pause menu. Every row works with the
## mouse, the keyboard and a pad: choices are OptionCyclers (left / right or press), volumes are sliders (left /
## right), and a binding cell waits for the next key or button (Esc or pad Back cancels). Esc, pad B or the pause
## button goes back: from inside a section to its category, from a category out of Options. Settings save to the
## profile on the way out (GameSettings, InputRebind).
## Three layouts share the same sections: SIDEBAR (the default: categories on the left, one section at a time),
## TABS (categories across the top) and LIST (every section in one scrolling column).
## v0.5.5 A5 (Cold glass, MenuStyle): the blurred, dimmed game (or the dark gradient) behind, a dark glass panel with a
## thin cold top edge set to the left, plain type, the focused row and the open category lit by the glass highlight.

signal back_pressed
## A setting changed (its GameSettings key); Main applies what lives in the view (shake, outline, view prefs).
signal setting_changed(key: String)

enum Layout { SIDEBAR, TABS, LIST }

const SECTIONS: Array[StringName] = [
	&"audio", &"display", &"controls", &"accessibility", &"language"
]
const SECTION_KEYS := {
	&"audio": "UI_SECTION_AUDIO",
	&"display": "UI_SECTION_DISPLAY",
	&"controls": "UI_SECTION_CONTROLS",
	&"accessibility": "UI_SECTION_ACCESSIBILITY",
	&"language": "UI_SECTION_LANGUAGE",
}
const VOLUMES := {
	"audio/master": "UI_AUDIO_MASTER",
	"audio/sfx": "UI_AUDIO_SFX",
	"audio/ambience": "UI_AUDIO_AMBIENCE"
}
const LABEL_W := 300.0

var layout := Layout.SIDEBAR
## The section shown (SIDEBAR and TABS).
var current := &"audio"
## Category buttons and section bodies by section id.
var tabs := {}
var sections := {}
## Binding cells by "action/device".
var bind_buttons := {}
## The remap status line (waiting, swapped).
var status := Label.new()

var _profile: ProfileStore
var _capture_action := &""
var _capture_device := &""
var _scroll := ScrollContainer.new()
var _back: Button


func _init(profile: ProfileStore, p_layout: int = Layout.SIDEBAR, _over_game: bool = false) -> void:
	name = "OptionsMenu"
	_profile = profile
	layout = p_layout
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuStyle.apply(self)
	var backdrop := MenuBackdrop.new()  # over the game it blurs it; over the main menu, the gradient alone
	add_child(backdrop)
	for id in SECTIONS:
		sections[id] = _build_section(id)
	_build_frame()
	_select(current)


# --- layout ---------------------------------------------------------------------------------------------------


func _build_frame() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 680) if layout != Layout.LIST else Vector2(900, 760)
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = MenuStyle.LIST_LEFT - 24.0
	panel.offset_top = -panel.custom_minimum_size.y * 0.5
	panel.offset_bottom = panel.custom_minimum_size.y * 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(pad)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	_scroll.add_child(body)
	for id in SECTIONS:
		body.add_child(sections[id])
	_back = _button("UI_BACK", _on_back)
	_link_tabs.call_deferred()
	_back.name = "Back"
	match layout:
		Layout.SIDEBAR:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 28)
			pad.add_child(row)
			var side := VBoxContainer.new()
			side.custom_minimum_size = Vector2(280, 0)
			side.add_theme_constant_override("separation", 10)
			row.add_child(side)
			side.add_child(_title())
			for id in SECTIONS:
				side.add_child(_tab(id))
			var gap := Control.new()
			gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
			side.add_child(gap)
			side.add_child(_back)
			row.add_child(VSeparator.new())
			row.add_child(_scroll)
		Layout.TABS:
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 14)
			pad.add_child(col)
			col.add_child(_title())
			var bar := HBoxContainer.new()
			bar.add_theme_constant_override("separation", 8)
			bar.alignment = BoxContainer.ALIGNMENT_CENTER
			col.add_child(bar)
			for id in SECTIONS:
				bar.add_child(_tab(id))
			col.add_child(HSeparator.new())
			col.add_child(_scroll)
			col.add_child(_back)
		Layout.LIST:
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 14)
			pad.add_child(col)
			col.add_child(_title())
			col.add_child(_scroll)
			col.add_child(_back)


func _title() -> Label:
	var l := Label.new()
	l.text = "UI_OPTIONS"
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", 44)
	l.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if layout == Layout.SIDEBAR else HORIZONTAL_ALIGNMENT_CENTER
	)
	return l


func _tab(id: StringName) -> Button:
	var b := _button(SECTION_KEYS[id], func() -> void: _open(id))
	b.name = "Tab" + String(id).capitalize()
	b.toggle_mode = true
	b.focus_entered.connect(func() -> void: _select(id))
	if layout == Layout.TABS:
		b.custom_minimum_size = Vector2(200, 48)
	else:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tabs[id] = b
	return b


func _button(key: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(on_press)
	return b


## Right from a sidebar category (down from a tab) goes to the first control of its own section, not to whatever
## happens to sit beside it.
func _link_tabs() -> void:
	for id: StringName in tabs:
		var first := _first_focusable(sections[id])
		if first == null:
			continue
		var b := tabs[id] as Button
		if layout == Layout.SIDEBAR:
			b.focus_neighbor_right = b.get_path_to(first)
		else:
			b.focus_neighbor_bottom = b.get_path_to(first)


## Shows section `id` (SIDEBAR / TABS); LIST shows every section.
func _select(id: StringName) -> void:
	current = id
	for s: StringName in sections:
		(sections[s] as Control).visible = layout == Layout.LIST or s == id
	for t: StringName in tabs:
		(tabs[t] as Button).set_pressed_no_signal(t == id)


## Shows section `id` and moves focus into it.
func _open(id: StringName) -> void:
	_select(id)
	var first := _first_focusable(sections[id])
	if first != null:
		first.grab_focus()


func focus_first() -> void:
	if not tabs.is_empty():
		(tabs[current] as Button).grab_focus()
	else:
		_open(current)


static func _first_focusable(n: Node) -> Control:
	for c in n.get_children():
		if (
			c is Control
			and (c as Control).focus_mode == Control.FOCUS_ALL
			and (c as Control).visible
		):
			if not (c is Button and (c as Button).disabled):
				return c
		var deeper := _first_focusable(c)
		if deeper != null:
			return deeper
	return null


# --- sections -------------------------------------------------------------------------------------------------


func _build_section(id: StringName) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Section" + String(id).capitalize()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	var head := Label.new()
	head.text = SECTION_KEYS[id]
	head.add_theme_font_size_override("font_size", 28)
	head.modulate = Color(0.55, 0.85, 0.95)
	box.add_child(head)
	match id:
		&"audio":
			for key: String in VOLUMES:
				_slider(box, VOLUMES[key], key)
		&"display":
			_cycler(box, "UI_WINDOW_MODE", "window_mode", GameSettings.WINDOW_MODES)
			_cycler(box, "UI_VSYNC", "vsync", ["on", "off"])
			_cycler(box, "UI_FRAME_CAP", "frame_cap", GameSettings.FRAME_CAPS)
			_cycler(box, "UI_RENDER_SCALE", "render_scale", GameSettings.RENDER_SCALES)
			_cycler(box, "UI_OUTLINE", "outline", ["off", "ink", "sketch", "paper"])
			_cycler(box, "UI_LIGHTING", "lighting", StageView.LIGHTING_QUALITIES)
			_cycler(box, "UI_EFFECTS_DENSITY", "effects_density", GameSettings.EFFECTS_DENSITIES)
		&"controls":
			_controls(box)
		&"accessibility":
			_cycler(box, "UI_SHAKE", "shake", ["on", "off"])
			_cycler(box, "UI_REDUCED_MOTION", "reduced_motion", ["off", "on"])
			_cycler(box, "UI_COLOUR_MODE", "colour_mode", GameSettings.COLOUR_MODES)
			_cycler(box, "UI_CAPTIONS", "captions", ["off", "on"])
			_note(box, "UI_COLOUR_MODE_NOTE")
		&"language":
			_cycler(box, "UI_LANGUAGE", "language", GameSettings.LANGUAGES)
	return box


func _row(box: Control, label_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label_key
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	box.add_child(row)
	return row


func _note(box: Control, key: String) -> void:
	var l := Label.new()
	l.text = key
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = Color(1, 1, 1, 0.65)
	box.add_child(l)


func _slider(box: Control, label_key: String, key: String) -> StepSlider:
	var row := _row(box, label_key)
	var s := StepSlider.new()
	s.name = key.replace("/", "_")
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size = Vector2(0, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value = float(GameSettings.get_value(_profile, key))
	var shown := Label.new()
	shown.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	shown.custom_minimum_size = Vector2(56, 0)
	shown.text = "%d" % int(s.value)
	s.value_changed.connect(
		func(v: float) -> void:
			shown.text = "%d" % int(v)
			GameSettings.set_value(_profile, key, int(v))
			setting_changed.emit(key)
	)
	row.add_child(s)
	row.add_child(shown)
	return s


func _cycler(box: Control, label_key: String, key: String, values: Array) -> OptionCycler:
	var keys: Array = []
	for v in values:
		keys.append("UI_OPT_" + String(v).to_upper())
	var c := OptionCycler.new(values, keys, String(GameSettings.get_value(_profile, key)))
	c.name = key
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_font_size_override("font_size", 20)
	c.changed.connect(
		func(v: String) -> void:
			GameSettings.set_value(_profile, key, v)
			setting_changed.emit(key)
	)
	_row(box, label_key).add_child(c)
	return c


func _controls(box: Control) -> void:
	var head := _row(box, "UI_REMAP_ACTION")
	for k in ["UI_REMAP_KEYBOARD", "UI_REMAP_PAD"]:
		var l := Label.new()
		l.text = k
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate = Color(1, 1, 1, 0.7)
		head.add_child(l)
	for action in InputRebind.ACTIONS:
		var row := _row(box, InputLabels.action_key(action))
		for device in [InputRebind.KBM, InputRebind.PAD]:
			var b := Button.new()
			b.name = "%s_%s" % [action, device]
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 40)
			b.add_theme_font_size_override("font_size", 18)
			if InputRebind.has_slot(action, device):
				b.pressed.connect(_start_capture.bind(action, device))
			else:
				b.disabled = true
				b.focus_mode = Control.FOCUS_NONE
			bind_buttons["%s/%s" % [action, device]] = b
			row.add_child(b)
	status.name = "RemapStatus"
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	status.add_theme_font_size_override("font_size", 18)
	status.modulate = Color(1.0, 0.85, 0.45)
	box.add_child(status)
	var reset := _button("UI_REMAP_RESET", _on_reset)
	reset.name = "ResetControls"
	box.add_child(reset)
	_refresh_bindings()


func _refresh_bindings() -> void:
	for k: String in bind_buttons:
		var action := StringName(k.get_slice("/", 0))
		var device := StringName(k.get_slice("/", 1))
		var b: Button = bind_buttons[k]
		if not InputRebind.has_slot(action, device):
			b.text = tr("UI_REMAP_MOUSE_AIMS")
		else:
			var spec := InputRebind.binding(action, device)
			b.text = InputLabels.text(spec) if not spec.is_empty() else tr("UI_REMAP_NONE")


# --- remapping ------------------------------------------------------------------------------------------------


func capturing() -> bool:
	return _capture_action != &""


func _start_capture(action: StringName, device: StringName) -> void:
	_capture_action = action
	_capture_device = device
	(bind_buttons["%s/%s" % [action, device]] as Button).text = tr("UI_REMAP_WAITING")
	status.text = tr("UI_REMAP_PRESS")


func _end_capture() -> void:
	_capture_action = &""
	_capture_device = &""
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	if not capturing() or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	var cancel: bool = (
		(event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE)
		or (
			event is InputEventJoypadButton
			and event.pressed
			and event.button_index == JOY_BUTTON_BACK
		)
	)
	if cancel:
		status.text = ""
		_end_capture()
		return
	var spec := InputRebind.spec_of(event)
	if spec.is_empty() or InputRebind.device_of(spec) != _capture_device:
		return
	var action := _capture_action
	var swapped := InputRebind.rebind(_profile, action, spec)
	status.text = (
		tr("UI_REMAP_SWAPPED") % tr(InputLabels.action_key(swapped)) if swapped != &"" else ""
	)
	_end_capture()
	setting_changed.emit("bindings")


func _on_reset() -> void:
	InputRebind.reset(_profile)
	status.text = ""
	_refresh_bindings()
	setting_changed.emit("bindings")


# --- back -----------------------------------------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if capturing():
		return
	var back: bool = (
		event.is_action_pressed(&"ui_cancel")
		or event.is_action_pressed(&"pause")
		or (
			event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
		)
	)
	if back:
		get_viewport().set_input_as_handled()
		# Inside a section, back returns to its category first (a slider keeps left / right for itself).
		var focus := get_viewport().gui_get_focus_owner()
		if (
			not tabs.is_empty()
			and focus != null
			and (sections[current] as Node).is_ancestor_of(focus)
		):
			(tabs[current] as Button).grab_focus()
		else:
			_on_back()


func _on_back() -> void:
	_profile.save_file()
	back_pressed.emit()
