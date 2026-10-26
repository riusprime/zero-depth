class_name MainMenu
extends MenuPanel
## v0.9.0 HB (owner Q27: "You will have a small menu, with options, continue and play, and the rest of the thing go
## into the hub"): Continue, Play, Options, Credits, Exit and the version label. Continue resumes the saved run (focused
## first while a run save exists; greyed out and skipped by the focus when there is none: HUB_MOCKUPS "Shared"); Play
## goes to the hub. v0.9.5 RS1: the Credits are an item here again; the galleries moved to the master dev panel (F10).
## v0.9.5 MM (owner, 2026-10-26: "make the main menu look closer to this", docs/art/reference/v0.9.5_main_menu.webp):
## black, the owner's logo over a column of cracked dark-stone plates on the left (StoneButton, the focused one lit
## blue), and on the right the owner's picture (assets/ui/menu/backdrop.png: the ruined portal, its red beam and the
## hero), drifting very slowly. Both pictures are cut by scripts/art/cut_menu_backdrop.py.
signal continue_pressed
signal play_pressed
signal options_pressed
signal credits_pressed
signal quit_pressed

## The column's left edge (the plate starts StoneButton.SIDE further in) and the gap between plates (1920 x 1080 base).
const LEFT := 100.0
const GAP := 17
const LOGO := "res://assets/ui/menu/logo.png"
const LOGO_W := 448.0  # owner, 2026-10-26: "make it 30% smaller and move it up a bit" (640 -> 448)
const LOGO_LIFT := 56.0  # the space under the logo, so it sits higher over the plates
const BACKDROP := "res://assets/ui/menu/backdrop.png"
const DRIFT := 0.012
const DRIFT_SECONDS := 20.0

var version_label := Label.new()
var backdrop: TextureRect
var _t := 0.0
var _rows := 0


func _init(version: String, show_continue: bool = false) -> void:
	super()
	name = "MainMenu"
	slab.add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # no slab: the plates are the list
	slab.offset_left = LEFT
	_column.add_theme_constant_override("separation", 30)
	box.add_theme_constant_override("separation", GAP)
	box.custom_minimum_size = Vector2(StoneButton.PLATE.x + StoneButton.SIDE * 2.0, 0)
	_column.custom_minimum_size = box.custom_minimum_size
	box.add_child(_logo())
	var lift := Control.new()
	lift.name = "LogoLift"
	lift.custom_minimum_size = Vector2(0, LOGO_LIFT)
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lift)
	var cont := add_button("UI_CONTINUE", func() -> void: continue_pressed.emit())
	cont.name = "Continue"
	cont.disabled = not show_continue
	if cont.disabled:
		cont.focus_mode = Control.FOCUS_NONE
		cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_button("UI_PLAY", func() -> void: play_pressed.emit()).name = "Play"
	add_button("UI_OPTIONS", func() -> void: options_pressed.emit()).name = "Options"
	add_button("MENU_CREDITS", func() -> void: credits_pressed.emit()).name = "Credits"  # v0.9.5 RS1
	add_button("UI_QUIT", func() -> void: quit_pressed.emit()).name = "Quit"
	backdrop = _make_backdrop()
	add_child(backdrop)
	move_child(backdrop, 0)
	var hint := add_hint("UI_MENU_HINT")
	hint.modulate = Color(1, 1, 1, 0.55)
	version_label.text = version
	version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.position = Vector2(-140, -44)
	version_label.add_theme_font_size_override("font_size", MenuStyle.HINT_SIZE)
	version_label.add_theme_color_override("font_color", MenuStyle.HINT)
	version_label.modulate = Color(1, 1, 1, 0.55)
	add_child(version_label)


## The plates are StoneButtons (drawn in code), in the order they are added.
func add_button(key: String, on_press: Callable) -> Button:
	var b := StoneButton.new(_rows)
	_rows += 1
	b.text = key
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(on_press)
	box.add_child(b)
	return b


## The logo (the owner's transparent PNG, used as sent) over the column; its accessible name is the game's title.
func _logo() -> TextureRect:
	var l := TextureRect.new()
	l.name = "Logo"
	l.texture = load(LOGO) as Texture2D
	l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	l.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	l.custom_minimum_size = Vector2(LOGO_W, LOGO_W * 910.0 / 1728.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.accessibility_name = tr("UI_TITLE")
	return l


## The owner's picture behind everything, covering the screen and anchored to the right (the portal and the hero stay
## in view at other shapes of window), drifting very slowly (at most 1.2 % zoom over 20 s; still if reduced).
func _make_backdrop() -> TextureRect:
	var t := TextureRect.new()
	t.name = "Backdrop"
	t.texture = load(BACKDROP) as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## The first row that can take focus (Continue only while a save exists).
func focus_first() -> void:
	for c in box.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).grab_focus()
			return


## No ember marker beside the rows (the lit plate says where the focus is); the backdrop drifts.
func _process(delta: float) -> void:
	if backdrop == null or ViewPrefs.reduced_motion:
		return
	_t += delta
	var z := 1.0 + DRIFT * 0.5 * (1.0 - cos(_t * TAU / DRIFT_SECONDS))
	backdrop.pivot_offset = Vector2(backdrop.size.x, backdrop.size.y * 0.5)
	backdrop.scale = Vector2(z, z)
