extends SceneTree
## v0.6.5 Step WN2 screenshots (needs a renderer, not --headless): the pause menu's Build page and the Swap panel at
## eight slots, in the real game.
##   XDG_DATA_HOME=<empty folder> VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json \
##     xvfb-run -a -s "-screen 0 1920x1080x24" timeout 300 \
##     godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/wand_build.gd
## (repeat with --resolution 1280x720; the files carry the window size). Writes to build/shots/v0.6.5/wand/:
##   build_<lang>_<w>x<h>.png  - a Blade run from the menu (Enter, Enter), posed by the script (a tool, not a test:
##                               floor 3's eight slots filled with eight cards, two of them triggers; the hero can't
##                               be hurt), the pause menu opened with Esc and the Build page with Down, Enter;
##   build_moved_en_<w>x<h>.png - the same page after Enter, Right, Right (the first card held two slots on);
##   swap_<lang>_<w>x<h>.png   - Back, Esc, then a ninth card offered (posed): the Swap panel at eight slots;
##   swap_insert_en_<w>x<h>.png - X (the new card placed in the row; pad X as the key I), Right, Enter: which leaves.
## It quits on every path (the frame budget below). Evidence copies are made by hand.

const OUT := "res://build/shots/v0.6.5/wand/"
const EIGHT: Array[StringName] = [
	&"ember_edge",
	&"trigger_on_hit",
	&"long_edge",
	&"twin_arc",
	&"trigger_on_kill",
	&"serrated_edge",
	&"wide_arc",
	&"echo_slash",
]
const LAST_FRAME := 600

var _main: Main
var _frame := 0
var _size := ""
var _base := -1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("wand: renderer=%s" % RenderingServer.get_current_rendering_method())
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > LAST_FRAME or (_base >= 0 and _main.driver == null):
		print("wand: stopped at frame %d" % _frame)
		quit(1)
		return true
	if _size.is_empty():
		var s := root.get_window().size
		_size = "%dx%d" % [s.x, s.y]
	if _frame == 10 or _frame == 20:
		_tap(KEY_ENTER)  # Play, then Blade
	if _main.driver != null and _base < 0:
		_base = _frame
	if _base < 0:
		return false
	_main.driver.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
	match _frame - _base:
		20:
			_pose()
		40:
			_tap(KEY_ESCAPE)
		50:
			_tap(KEY_DOWN)  # to Build
		52:
			_tap(KEY_ENTER)
		80:
			_shot("build_en_" + _size)
			TranslationServer.set_locale("es")
		100:
			_shot("build_es_" + _size)
			TranslationServer.set_locale("en")
		102:
			_tap(KEY_ENTER)
		104, 106:
			_tap(KEY_RIGHT)
		130:
			_shot("build_moved_en_" + _size)
		132:
			_tap(KEY_ENTER)
		134:
			_tap(KEY_ESCAPE)  # back to the pause menu
		138:
			_tap(KEY_ESCAPE)  # resume: the moves reach the sim
		160:
			_offer()
		200:
			_shot("swap_en_" + _size)
			TranslationServer.set_locale("es")
		220:
			_shot("swap_es_" + _size)
			TranslationServer.set_locale("en")
		222:
			_tap(KEY_I)
		224:
			_tap(KEY_RIGHT)
		226:
			_tap(KEY_ENTER)
		250:
			_shot("swap_insert_en_" + _size)
			print("wand: order %s" % [_main.driver.world.mod_slots])
			quit(0)
	return false


func _pose() -> void:
	var w := _main.driver.world
	w.floor_index = 3  # shot setup: floor 3's eight slots
	for id: StringName in EIGHT:
		var k := _item(w, id)
		if k >= 0:
			BuildSlots.take(w, k)
	print("wand: posed %d cards in %d slots" % [w.mod_slots.size(), Wand.slots(w)])


func _offer() -> void:
	var w := _main.driver.world
	var k := _item(w, &"overcharge")
	if k >= 0:
		Offers.apply(w, k)
	print("wand: swapping %s" % BuildSlots.swapping(w))


static func _item(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT + shot_name + ".png")
	print("wand: ", OUT + shot_name + ".png")


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
