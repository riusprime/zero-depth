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
## v0.8.0 MU (Ember stone, MenuStyle): the blurred, ember-lit game (or the menu's own ember scene) behind, a carved
## stone slab set to the left, warm type, the focused row and the open category ember-lit slabs.
## v0.10.5 W3-O18 (owner: "the rest of the UI ... should match the new style"): in Astral (AstralMenu; the round-2
## mock's options): the game (or Astral's own night) under cool ink, the screen an ink veil between two fading
## hairlines; the categories a strip of Cinzel tabs (the open one underlined in the accent, the focused one starred);
## field labels in small Cinzel capitals that light with their row; volumes hairline tracks with an accent fill and a
## diamond knob, the value at the right; on/off choices Astral switches, longer choices a field between two chevrons;
## the binding cells thin frames; Back and the resets lozenge plates. The layout, the focus order and the input are
## unchanged.

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
	AstralMenu.apply(self)  # v0.10.5 W3-O18
	var backdrop := MenuBackdrop.new()  # over the game it blurs it; over the main menu, its own scene
	backdrop.astral = true
	add_child(backdrop)
	for id in SECTIONS:
		sections[id] = _build_section(id)
	_build_frame()
	_select(current)


# --- layout ---------------------------------------------------------------------------------------------------


func _build_frame() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1280, 744) if layout != Layout.LIST else Vector2(960, 792)
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = AstralMenu.LEFT - 40.0
	panel.offset_top = -panel.custom_minimum_size.y * 0.5
	panel.offset_bottom = panel.custom_minimum_size.y * 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 0)
	panel.add_child(pad)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	_scroll.add_child(body)
	for id in SECTIONS:
		body.add_child(sections[id])
	_back = _button("UI_BACK", _on_back)
	_link_tabs.call_deferred()
	_back.name = "Back"
	match layout:
		Layout.SIDEBAR:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 40)
			pad.add_child(row)
			var side := VBoxContainer.new()
			side.custom_minimum_size = Vector2(296, 0)
			side.add_theme_constant_override("separation", 8)
			row.add_child(side)
			side.add_child(_title())
			side.add_child(AstralMenu.LeftRule.new(32.0))
			for id in SECTIONS:
				side.add_child(_tab(id))
			var gap := Control.new()
			gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
			side.add_child(gap)
			_back.alignment = HORIZONTAL_ALIGNMENT_LEFT  # v0.6.0 UP: under the categories, left-aligned like them
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


## v0.10.5 W3-O18: the sigil and "OPTIONS" in letter-spaced Cinzel (its label named "Title").
func _title() -> Control:
	var head := AstralMenu.Title.new(AstralMenu.PANEL_TITLE_SIZE)
	head.label.text = "UI_OPTIONS"
	if layout != Layout.SIDEBAR:
		head.alignment = BoxContainer.ALIGNMENT_CENTER
	return head


func _tab(id: StringName) -> Button:
	var b := AstralButton.new(AstralButton.Kind.TAB, 200.0 if layout == Layout.TABS else 0.0)
	b.text = SECTION_KEYS[id]
	b.pressed.connect(func() -> void: _open(id))
	b.name = "Tab" + String(id).capitalize()
	b.toggle_mode = true
	b.focus_entered.connect(func() -> void: _select(id))
	tabs[id] = b
	return b


## v0.10.5 W3-O18: Back and the resets are Astral lozenge plates.
func _button(key: String, on_press: Callable) -> Button:
	var b := AstralButton.new(AstralButton.Kind.PLATE, 296.0)
	b.text = key
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
	box.add_theme_constant_override("separation", 8)
	var head := Label.new()
	head.text = SECTION_KEYS[id]
	AstralMenu.caps(head, AstralMenu.SECTION_SIZE, AstralCardArt.TEXT, 600, 0.28)  # v0.10.5 W3-O18
	box.add_child(head)
	box.add_child(AstralMenu.LeftRule.new(16.0, 0.45))
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
			_cycler(box, "UI_HIT_STOP", "hit_stop", ["on", "off"])  # v0.8.0 GF3: the Blade's hit-stop
			_cycler(box, "UI_COLOUR_MODE", "colour_mode", GameSettings.COLOUR_MODES)
			_cycler(box, "UI_CAPTIONS", "captions", ["off", "on"])
			_cycler(box, "UI_UI_SCALE", "ui_scale", GameSettings.UI_SCALES)  # v0.7.5 SM
			_cycler(box, "UI_SHOW_HINTS", HintStore.SETTING, ["on", "off"])  # v0.7.5 SM: the first-run hints
			_cycler(box, "UI_BOSS_HINTS", MechanicHints.SETTING, ["on", "off"])  # v0.11.0 O2 (Q12)
			_hints_reset(box)
			_note(box, "UI_COLOUR_MODE_NOTE")
		&"language":
			_cycler(box, "UI_LANGUAGE", "language", GameSettings.LANGUAGES)
	return box


## v0.7.5 SM: "Reset hints": every first-run hint shows again (HintStore.reset), with a line that says so.
func _hints_reset(box: Control) -> void:
	var row := _row(box, "UI_RESET_HINTS_LABEL")
	var b := _button("UI_RESET_HINTS", func() -> void: pass)
	b.name = "ResetHints"
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var done := Label.new()
	done.name = "HintsResetDone"
	done.text = "UI_HINTS_RESET_DONE"
	AstralMenu.body(done, AstralMenu.NOTE_SIZE, AstralCardArt.ACCENT)
	done.visible = false
	b.pressed.connect(
		func() -> void:
			HintStore.new(_profile).reset()
			done.visible = true
			setting_changed.emit("hints_reset")
	)
	row.add_child(b)
	row.add_child(done)


func _row(box: Control, label_key: String) -> HBoxContainer:
	var row := AstralMenu.FieldRow.new()  # v0.10.5 W3-O18: lit with its control
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 48)
	var l := Label.new()
	l.name = "Label"
	l.text = label_key
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	AstralMenu.caps(l, AstralMenu.LABEL_SIZE, AstralCardArt.DIM, 600, 0.24)  # v0.10.5 W3-O18
	row.add_child(l)
	box.add_child(row)
	return row


## v0.10.5 W3-O18: a row's label lights while its control has the focus (Astral: focus reads by brightness).
static func _light_label(row: HBoxContainer, c: Control) -> void:
	var l := row.get_node("Label") as Label
	var lit := func(on: bool) -> void:
		l.add_theme_color_override("font_color", AstralCardArt.TEXT if on else AstralCardArt.DIM)
		if row is AstralMenu.FieldRow:
			(row as AstralMenu.FieldRow).lit = on
	c.focus_entered.connect(lit.bind(true))
	c.focus_exited.connect(lit.bind(false))


func _note(box: Control, key: String) -> void:
	var l := Label.new()
	l.text = key
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	AstralMenu.body(l, AstralMenu.NOTE_SIZE, AstralCardArt.DIM)
	box.add_child(l)


func _slider(box: Control, label_key: String, key: String) -> StepSlider:
	var row := _row(box, label_key)
	var s := StepSlider.new()
	s.astral = true  # v0.10.5 W3-O18
	s.name = key.replace("/", "_")
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size = Vector2(0, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value = float(GameSettings.get_value(_profile, key))
	var shown := Label.new()
	shown.name = "Value"
	shown.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	shown.custom_minimum_size = Vector2(56, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	AstralMenu.body(shown, 15, AstralCardArt.TEXT, true)
	shown.text = "%d %%" % int(s.value)
	s.value_changed.connect(
		func(v: float) -> void:
			shown.text = "%d %%" % int(v)
			GameSettings.set_value(_profile, key, int(v))
			setting_changed.emit(key)
	)
	row.add_child(s)
	row.add_child(shown)
	_light_label(row, s)
	return s


func _cycler(box: Control, label_key: String, key: String, values: Array) -> OptionCycler:
	var keys: Array = []
	for v in values:
		keys.append("UI_OPT_" + String(v).to_upper())
	var c := OptionCycler.new(values, keys, String(GameSettings.get_value(_profile, key)))
	c.name = key
	c.astral = true  # v0.10.5 W3-O18
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.changed.connect(
		func(v: String) -> void:
			GameSettings.set_value(_profile, key, v)
			setting_changed.emit(key)
	)
	var row := _row(box, label_key)
	row.add_child(c)
	_light_label(row, c)
	return c


func _controls(box: Control) -> void:
	var head := _row(box, "UI_REMAP_ACTION")
	for k in ["UI_REMAP_KEYBOARD", "UI_REMAP_PAD"]:
		var l := Label.new()
		l.text = k
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		AstralMenu.caps(l, AstralMenu.LABEL_SIZE, AstralCardArt.DIM, 600, 0.24)
		head.add_child(l)
	for action in InputRebind.ACTIONS:
		var row := _row(box, InputLabels.action_key(action))
		for device in [InputRebind.KBM, InputRebind.PAD]:
			var b := Button.new()
			b.name = "%s_%s" % [action, device]
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 40)
			b.add_theme_font_size_override("font_size", 16)
			if InputRebind.has_slot(action, device):
				b.pressed.connect(_start_capture.bind(action, device))
			else:
				b.disabled = true
				b.focus_mode = Control.FOCUS_NONE
			bind_buttons["%s/%s" % [action, device]] = b
			row.add_child(b)
			if not b.disabled:
				_light_label(row, b)
	status.name = "RemapStatus"
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	AstralMenu.body(status, AstralMenu.NOTE_SIZE, AstralCardArt.ACCENT)
	box.add_child(status)
	var reset := _button("UI_REMAP_RESET", _on_reset)
	reset.name = "ResetControls"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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


## v0.6.0 UP: the binding cells hold translated names ("Left click"), so a language switch words them again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not bind_buttons.is_empty() and not capturing():
		_refresh_bindings()


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
