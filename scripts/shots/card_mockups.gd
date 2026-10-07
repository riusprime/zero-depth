extends SceneTree
## Card mockups (v0.3.5 F16, G2): the real main.tscn on a run, and for each CardStyle look a real 3-card pick
## (PickPanel, the second card focused, one rare item), an item card and a combo card built over the same game frame
## from the game's own items and combos (a tool, not a test: the panel is filled directly, not opened in the sim).
## Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/card_mockups.gd
## Writes card_<look>.png (full frames) and card_mockups.png (3 columns, the frame's middle at 1:1) to
## build/shots/v0.3.5/cards/. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.3.5/cards/"
const LOOKS := ["flat", "facet", "rule"]
const SETTLE := 30
## The crop: the screen's middle (window pixels at 1600 x 900).
const CROP := Rect2i(300, 170, 1000, 700)

var main: Main
var _step := 0
var _frames := 0
var _built: Array[Control] = []
var _shots: Array[Image] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("cards: renderer=%s" % RenderingServer.get_current_rendering_method())
	ProfileStore.use_shared(ProfileStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _step == 0:
		if _frames == 3:
			main.start_stage()
			main.driver.world.actors.invuln[0] = 1 << 24
			(main.get_node("UI/Hud") as Hud).visible = false
			_next()
	elif _step <= LOOKS.size():
		if _frames == 2:
			CardStyle.current = (_step - 1) as CardStyle.Look
			_build()
		if _frames == SETTLE:
			_shots.append(_shot("card_%s" % LOOKS[_step - 1]))
			for c in _built:
				c.queue_free()
			_built.clear()
			_next()
	else:
		CardStyle.current = CardStyle.DEFAULT
		_save_sheet()
		quit(0)
	if _frames > 3000:
		push_error("cards: stuck at step %d" % _step)
		quit(1)
	return false


func _next() -> void:
	_step += 1
	_frames = 0


## A pick of three real items (the first rare one in the middle), an item card and a combo card.
func _build() -> void:
	var r: WorldReader = main.driver.reader
	var ui := main.get_node("UI")
	var picks: Array[int] = []
	var rare := -1
	for k in r.item_table_count():
		if r.item_rarity(k) == WorldReader.RARITY_RARE and rare < 0:
			rare = k
		elif picks.size() < 3:
			picks.append(k)
	picks[1] = rare if rare >= 0 else picks[1]
	var panel := PickPanel.new()
	ui.add_child(panel)
	_built.append(panel)
	panel._title.text = tr("PICK_TITLE_CHEST") % 40
	panel._hint.text = tr("PICK_HINT")
	panel._count = 3
	panel.visible = true
	for k in 3:
		var idx := picks[k]
		var id := r.item_id(idx)
		var is_rare := r.item_rarity(idx) == WorldReader.RARITY_RARE
		panel.slot(k).show_item(
			id,
			tr(r.item_name_key(idx)),
			tr(r.item_desc_key(idx)),
			ItemLooks.color_of_id(id),
			is_rare,
			tr("RARITY_RARE") if is_rare else tr("RARITY_COMMON")
		)
	panel._set_focus(1)
	var holder := Control.new()  # full screen, like the HUD the cards live in
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(holder)
	_built.append(holder)
	var item := ItemCard.new()
	item.place_bottom_centre(-110)  # placed before it joins the tree, as the HUD does
	holder.add_child(item)
	var id0 := r.item_id(picks[0])
	item.show_item(
		id0,
		tr(r.item_name_key(picks[0])),
		tr(r.item_desc_key(picks[0])),
		ItemLooks.color_of_id(id0),
		tr("HUD_PICKED_UP")
	)
	if r.combo_table_count() > 0:
		var combo := ComboCard.new()
		combo.place_bottom_centre(-760)
		holder.add_child(combo)
		var pair := r.combo_item_ids(0)
		combo.show_combo(
			r.combo_id(0),
			pair[0],
			pair[1],
			tr(r.combo_name_key(0)),
			tr(r.combo_desc_key(0)),
			tr("UI_COMBO_UNLOCKED")
		)


func _shot(shot_name: String) -> Image:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT + shot_name + ".png")
	print("cards: ", OUT + shot_name + ".png")
	return img


func _save_sheet() -> void:
	var cw := CROP.size.x
	var sheet := Image.create(cw * _shots.size(), CROP.size.y, false, Image.FORMAT_RGB8)
	for i in _shots.size():
		sheet.blit_rect(_shots[i], CROP, Vector2i(i * cw, 0))
	sheet.resize(
		int(sheet.get_width() * 0.75), int(sheet.get_height() * 0.75), Image.INTERPOLATE_LANCZOS
	)
	sheet.save_png(OUT + "card_mockups.png")
	print("cards: sheet ", sheet.get_size())
