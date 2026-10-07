extends SceneTree
## HUD style shots (v0.3.0 UI, L21, L23, L24): the real main.tscn on a run, posed by a script (a tool, not a test:
## it sets the run clock, HP, shards and items directly). For each HudStyle (the G2 mockups) a real Hud in that
## style is built over the same game frame, synced from the run's WorldReader, with floor 1's title card on screen
## and HP under 30 % (the warning on); then the shipped HUD (the game's own) in play: full HP mid-tier, and low HP.
## Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/hud_style.gd
## Writes each shot, hud_mockups.png (3 columns: the frame, the top plate and the HP corner at 1:1) and
## hud_style.png (the shipped HUD, 2 frames) to build/shots/v0.3.0/hud_style/. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.3.0/hud_style/"
const SETTLE := 50
const COL_W := 640
const STYLE_NAMES := ["terminal", "holo_echo", "industrial"]

var main: Main
var _step := 0
var _frames := 0
var _mock: Hud
var _mock_shots: Array[Image] = []
var _play_shots: Array[Image] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"hud_style: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _world() -> World:
	return main.driver.world


func _game_hud() -> Hud:
	return main.get_node("UI/Hud") as Hud


## A posed run: 2 min 15 s in (tier 5 of 6, half-way to the next), some shards and three items.
func _pose(hp: int, run_ticks: int) -> void:
	var w := _world()
	w.actors.invuln[0] = 1 << 24
	w.actors.hp[0] = hp
	w.run_ticks = run_ticks
	w.shards = 147
	if w.items_owned.is_empty():
		for k in 3:
			w.add_item(k)


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == 3:
				main.start_stage()
				_pose(24, 4 * 1800 + 900)
				_next()
		1, 2, 3:
			var s: int = _step - 1
			if _frames == 2:
				_game_hud().visible = false
				HudStyle.current = s as HudStyle.Style
				_mock = Hud.new()
				main.get_node("UI").add_child(_mock)
			if _frames == SETTLE - 4:  # frames are slow on a software renderer: show the card just before
				_mock.show_floor(main.run.floor_index, String(_biome_key()))
			if _mock != null:
				_pose(24, 4 * 1800 + 900 + _frames)
				_mock.sync(main.driver.reader)
			if _frames == SETTLE:
				_mock_shots.append(_shot("mock_%s" % STYLE_NAMES[s]))
				_mock.queue_free()
				_mock = null
				_next()
		4:
			if _frames == 2:
				HudStyle.current = HudStyle.DEFAULT
				_game_hud().visible = true
				_pose(100, 1 * 1800 + 1100)
			if _frames == SETTLE:
				_play_shots.append(_shot("play_full_hp"))
				_pose(22, 1 * 1800 + 1300)
				_game_hud().show_floor(main.run.floor_index, String(_biome_key()))
				_next()
		5:
			if _frames == 30:
				_play_shots.append(_shot("play_low_hp"))
				_save_sheets()
				quit(0)
	if _frames > 4000:
		push_error("hud_style: stuck at step %d" % _step)
		quit(1)
	return false


func _biome_key() -> StringName:
	var b: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", main.run_biome_id())
	return b.name_key


func _next() -> void:
	_step += 1
	_frames = 0


func _shot(shot_name: String) -> Image:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT + shot_name + ".png")
	print("hud_style: ", OUT + shot_name + ".png")
	return img


func _save_sheets() -> void:
	var w := _mock_shots[0].get_width()
	var h := _mock_shots[0].get_height()
	var fh := int(h * float(COL_W) / w)
	var top := Rect2i(w / 2 - COL_W / 2, 0, COL_W, 120)
	var corner := Rect2i(0, h - 200, COL_W, 200)
	var sheet := Image.create(COL_W * 3, fh + top.size.y + corner.size.y, false, Image.FORMAT_RGB8)
	for i in _mock_shots.size():
		var full := _mock_shots[i].duplicate() as Image
		full.resize(COL_W, fh, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(full, Rect2i(0, 0, COL_W, fh), Vector2i(i * COL_W, 0))
		sheet.blit_rect(_mock_shots[i], top, Vector2i(i * COL_W, fh))
		sheet.blit_rect(_mock_shots[i], corner, Vector2i(i * COL_W, fh + top.size.y))
	sheet.save_png(OUT + "hud_mockups.png")
	var pw := 960
	var ph := int(h * float(pw) / w)
	var play := Image.create(pw * 2, ph, false, Image.FORMAT_RGB8)
	for i in _play_shots.size():
		var img := _play_shots[i].duplicate() as Image
		img.resize(pw, ph, Image.INTERPOLATE_LANCZOS)
		play.blit_rect(img, Rect2i(0, 0, pw, ph), Vector2i(i * pw, 0))
	play.save_png(OUT + "hud_style.png")
	print("hud_style: sheets ", sheet.get_size(), " ", play.get_size())
