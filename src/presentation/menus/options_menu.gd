class_name OptionsMenu
extends MenuPanel
## Options stub (v0.0.1): language, volumes, VSync, frame cap. The full Options screen is designed in v0.1.0 (G2).

signal back_pressed

var _profile: ProfileStore


func _init(profile: ProfileStore) -> void:
	super()
	name = "OptionsMenu"
	_profile = profile
	add_title("UI_OPTIONS")
	_add_choice("UI_LANGUAGE", "language", GameSettings.LANGUAGES)
	for key in ["volume_master", "volume_music", "volume_effects"]:
		_add_slider("UI_" + key.to_upper(), key)
	_add_choice("UI_VSYNC", "vsync", ["on", "off"])
	_add_choice("UI_FRAME_CAP", "frame_cap", GameSettings.FRAME_CAPS)
	_add_choice("UI_SHAKE", "shake", ["on", "off"])
	_add_choice("UI_OUTLINE", "outline", ["off", "ink", "sketch", "paper"])
	add_button("UI_BACK", _on_back).name = "Back"


func _row(label_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_key
	l.custom_minimum_size = Vector2(200, 0)
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	box.add_child(row)
	return row


func _add_slider(label_key: String, key: String) -> void:
	var s := HSlider.new()
	s.name = key
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = float(GameSettings.get_value(_profile, key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void: GameSettings.set_value(_profile, key, int(v)))
	_row(label_key).add_child(s)


func _add_choice(label_key: String, key: String, options: Array) -> void:
	var o := OptionButton.new()
	o.name = key
	for opt in options:
		o.add_item("UI_OPT_" + String(opt).to_upper())
	o.selected = maxi(0, options.find(String(GameSettings.get_value(_profile, key))))
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.item_selected.connect(func(i: int) -> void: GameSettings.set_value(_profile, key, options[i]))
	_row(label_key).add_child(o)


func _on_back() -> void:
	_profile.save_file()
	back_pressed.emit()
