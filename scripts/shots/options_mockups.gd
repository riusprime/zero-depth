extends SceneTree
## The Options screen's G2 mockups (v0.3.0 O): the three layouts OptionsMenu can build (A sidebar, the shipped
## default; B tabs across the top; C one scrolling list), each over a paused floor, plus the shipped layout's
## Controls section. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/options_mockups.gd
## Boots main.tscn, presses Enter twice (Play, then the utility) and Esc (pause), then shows each layout; frames are
## grabbed in _process. Writes each shot and options_mockups.png (2 x 2) to build/shots/v0.3.0/options/. Evidence
## copies are made by hand.

const OUT := "res://build/shots/v0.3.0/options/"
const SHEET_SCALE := 0.5
const SHOTS := [
	["a_sidebar", OptionsMenu.Layout.SIDEBAR, &"accessibility", "A  Sidebar (shipped)"],
	["b_tabs", OptionsMenu.Layout.TABS, &"accessibility", "B  Tabs across the top"],
	["c_list", OptionsMenu.Layout.LIST, &"audio", "C  One scrolling list"],
	["a_controls", OptionsMenu.Layout.SIDEBAR, &"controls", "A  Controls section"],
]

var _main: Main
var _frame := 0
var _shot := -1
var _wait := 0
var _menu: OptionsMenu
var _caption: Label
var _images: Array[Image] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 3000:
		print("options_mockups: gave up")
		quit(1)
		return false
	if _frame in [8, 14]:
		_key(KEY_ENTER, true)
	if _frame in [9, 15]:
		_key(KEY_ENTER, false)
	if _frame == 90:
		_key(KEY_ESCAPE, true)
	if _frame == 91:
		_key(KEY_ESCAPE, false)
	if _frame < 100:
		return false
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_grab()
		return false
	_shot += 1
	if _shot >= SHOTS.size():
		_sheet()
		quit(0)
		return false
	_show(SHOTS[_shot])
	_wait = 20
	return false


func _show(s: Array) -> void:
	if _menu != null:
		_menu.queue_free()
	var pause := _main.get_node_or_null("UI/PauseMenu") as Control
	if pause != null:
		pause.visible = false
	_menu = OptionsMenu.new(_main.profile, s[1], true)
	_main.ui.add_child(_menu)
	_menu.focus_first()
	if _menu.tabs.has(s[2]):
		(_menu.tabs[s[2]] as Button).grab_focus()
	if _caption == null:
		_caption = Label.new()
		_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_caption.add_theme_font_size_override("font_size", 30)
		_caption.position = Vector2(20, 12)
		_main.ui.add_child(_caption)
	_caption.text = s[3]
	_main.ui.move_child(_caption, _main.ui.get_child_count() - 1)


func _grab() -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + "%s.png" % SHOTS[_shot][0])
	_images.append(img)
	print("options_mockups: ", SHOTS[_shot][0], " ", img.get_size())


func _sheet() -> void:
	var w := int(_images[0].get_width() * SHEET_SCALE)
	var h := int(_images[0].get_height() * SHEET_SCALE)
	var sheet := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for k in _images.size():
		var img := _images[k].duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((k % 2) * w, (k / 2) * h))
	sheet.save_png(OUT + "options_mockups.png")
	print("options_mockups: sheet ", sheet.get_size())


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
