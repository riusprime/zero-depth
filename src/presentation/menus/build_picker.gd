class_name BuildPicker
extends Control
## The start screen (v0.3.0 L15: "pick at start, have a two card screen with a cool animation of appearing that
## shows both"): one BuildCard per BuildDefinition (Blade, then Gun), staggered in (each rises and fades in), under
## the title. The last pick has focus.
## v0.6.1 R2b: the owner's art (BuildArt): the title sits in the crystal title plaque, the cards in their crystal
## frames; behind them the menus' Cold-glass backdrop (MenuStyle, MenuBackdrop). No cyan/magenta glitch any more.
## - Mouse: hover focuses a card, a click picks it.
## - Keyboard: Left/Right move the focus, Enter picks, Esc goes back.
## - Pad: d-pad or left stick move the focus, A (Cross) picks, B (Circle) goes back.
## It only reports the choice (`picked`); the app starts the run with it.

signal picked(id: StringName)
signal back_pressed

const STAGGER_S := 0.16
const FIRST_DELAY_S := 0.12
const TITLE_S := 0.45
## The title's type size in the plaque (px); it fits en and es (test_build_art.gd).
const TITLE_FONT := 40

var cards: Array[BuildCard] = []
var _ids: Array[StringName] = []
var _focus_index := 0
var _title := Label.new()
var _plaque := TextureRect.new()
var _hint := Label.new()
var _back := Button.new()
var _t := 0.0
var _backdrop := MenuBackdrop.new()


func _init(builds: Array, last_id: StringName) -> void:
	name = "BuildPicker"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuStyle.apply(self)
	add_child(_backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	centre.add_child(col)
	var head := Control.new()
	head.name = "TitlePlaque"
	head.custom_minimum_size = BuildArt.TITLE_SIZE * BuildArt.TITLE_SCALE
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	col.add_child(head)
	_plaque.texture = BuildArt.title()
	_plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plaque.stretch_mode = TextureRect.STRETCH_SCALE
	_plaque.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_plaque)
	_title.name = "Title"
	_title.text = "UI_CHOOSE_BUILD"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", HudStyle.font(true))
	_title.add_theme_font_size_override("font_size", TITLE_FONT)
	_title.position = BuildArt.TITLE_BOX.position * BuildArt.TITLE_SCALE
	_title.size = BuildArt.TITLE_BOX.size * BuildArt.TITLE_SCALE
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 64)
	col.add_child(row)
	var k := 0
	for def: BuildDefinition in builds:
		var c := BuildCard.new(
			def.weapon,
			def.name_key,
			def.desc_key,
			def.damage_permille,
			FIRST_DELAY_S + STAGGER_S * k
		)
		c.name = String(def.id).capitalize()
		var id := def.id
		c.pressed.connect(func() -> void: picked.emit(id))
		row.add_child(c)
		cards.append(c)
		_ids.append(id)
		if id == last_id:
			_focus_index = k
		k += 1
	for i in cards.size():
		var c := cards[i]
		c.focus_neighbor_left = c.get_path_to(cards[maxi(0, i - 1)])
		c.focus_neighbor_right = c.get_path_to(cards[mini(cards.size() - 1, i + 1)])
		c.focus_neighbor_top = c.get_path_to(c)
	_hint.text = "BUILD_HINT"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.modulate = Color(1, 1, 1, 0.65)
	col.add_child(_hint)
	_back.text = "UI_BACK"
	_back.name = "Back"
	_back.custom_minimum_size = Vector2(220, 46)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_size_override("font_size", 20)
	_back.pressed.connect(func() -> void: back_pressed.emit())
	col.add_child(_back)


func _ready() -> void:
	for c in cards:
		c.focus_neighbor_bottom = c.get_path_to(_back)
	if not cards.is_empty():
		_back.focus_neighbor_top = _back.get_path_to(cards[_focus_index])


func focus_first() -> void:
	if not cards.is_empty():
		cards[_focus_index].grab_focus()


## The id of the focused card (&"" when none has focus).
func focused_id() -> StringName:
	for i in cards.size():
		if cards[i].has_focus():
			return _ids[i]
	return &""


## Ends the appear animation at once (screenshots).
func settle() -> void:
	seek(TITLE_S + 2.0)


## Sets the animation clock of the title, the backdrop and every card (the screenshot tool scrubs with it).
func seek(t: float) -> void:
	_t = t
	for c in cards:
		c.seek(t)
	_animate()


func _process(delta: float) -> void:
	_t += delta
	_animate()


func _animate() -> void:
	# The hint and Back fade in once the last card has landed.
	var last := FIRST_DELAY_S + STAGGER_S * maxi(0, cards.size() - 1) + BuildCard.APPEAR_S
	var a := clampf((_t - last) / 0.25, 0.0, 1.0)
	_hint.modulate.a = 0.65 * a
	_back.modulate.a = a
	# The title plaque fades in.
	var p := clampf(_t / TITLE_S, 0.0, 1.0)
	_plaque.modulate.a = p
	_title.modulate.a = p


## The title label (tests).
func title_label() -> Label:
	return _title


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed(&"ui_cancel")
		or (
			event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
		)
	):
		get_viewport().set_input_as_handled()
		back_pressed.emit()
