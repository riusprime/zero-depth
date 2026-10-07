extends SceneTree
## The v0.3.0 G shots: engine statuses on real enemy models through the iso camera (burn embers, shock pips and a
## discharge, bleed drips, frost crystals, a frozen enemy, guard-charge orbs, a Plasma Arc), a combo card, the HUD
## combo badges and the 8 new item icons. Needs a renderer:
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/combos.gd
## The statuses are set on a still world (no ticks run), so each one shows at a known stack count. Writes
## build/shots/v0.3.0/combos/combos.png (full size) and combos_small.png (for the evidence folder).

const OUT := "res://build/shots/v0.3.0/combos/"
const NEW_ITEMS: Array[StringName] = [
	&"cinder_shot",
	&"wildfire",
	&"conductor",
	&"serrated_edge",
	&"barbed_bolts",
	&"glacial_edge",
	&"cold_snap",
	&"bulwark",
]

var _frames := 0
var _view: WorldViewRoot
var _reader: WorldReader
var _w: World


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print(
		(
			"combos: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	var w := _world()
	_w = w
	_reader = WorldReader.new(w)
	_view = WorldViewRoot.new()
	_view.rig.view_size = 6.5
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(_reader, Gallery.palette_of(&"ruins"), 10.0)
	# Toward sim +x+y moves the scene left on screen, clear of the overlay on the right.
	_view.rig.snap_to(SimPlane.to_3d(Vector2(4.4, 2.6), 0.6))
	_overlay(w)


## The player with every item (so every engine's thresholds exist) and three guard charges; five enemies, one per
## status; a discharge and a Plasma Arc between them.
func _world() -> World:
	var repo := ContentRepository.load_all()
	var t := PlayerTable.starting_values()
	t.utility = PlayerTable.Utility.GUARD
	var w := World.new(9, t)
	w.set_enemy_tables(ContentCompiler.compile_enemies(repo))
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	for k in w.item_tables.size():
		w.add_item(k)
	var spots := [
		[ActorStore.Kind.CHARGER, Vector2(2.2, -2.4)],
		[ActorStore.Kind.NEEDLE, Vector2(3.8, -0.4)],
		[ActorStore.Kind.CHARGER, Vector2(2.6, 2.2)],
		[ActorStore.Kind.WARDEN, Vector2(-0.6, 2.8)],
		[ActorStore.Kind.CHARGER, Vector2(5.0, 2.4)],
	]
	for s: Array in spots:
		w.add_enemy(s[0], s[1])
	var a := w.actors
	for i in range(1, a.size()):
		a.state[i] = EnemyAi.State.MOVE
		a.invuln[i] = 0
		a.facing[i] = Kin.angle_of(w.player_pos() - a.pos(i))
	a.burn_stacks[1] = 5
	a.shock_stacks[2] = 3
	a.bleed_stacks[3] = 8
	a.frost_stacks[4] = 3
	a.frozen_t[5] = 60
	w.guard_charges = 3
	w.discharge_tick = 0
	w.discharge_from = a.pos(2)
	w.discharge_to = PackedVector2Array([a.pos(1), a.pos(3)])
	w.plasma_tick = 0
	w.plasma_from = a.pos(1)
	w.plasma_to = a.pos(4)
	print(
		(
			"combos: statuses burn=%d shock=%d/%d bleed=%d frost=%d/%d frozen=%s charges=%d"
			% [
				a.burn_stacks[1],
				a.shock_stacks[2],
				w.item_mods.shock_threshold,
				a.bleed_stacks[3],
				a.frost_stacks[4],
				w.item_mods.frost_threshold,
				Engines.frozen(w, 5),
				w.guard_charges
			]
		)
	)
	return w


## The combo card, every combo badge, and the 8 new icons with their names, over the right side of the view.
func _overlay(w: World) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.06, 0.07, 0.1, 0.92)
	# UI coordinates are in the project's 1920 × 1080 base size (the window scales them).
	panel.position = Vector2(1430, 0)
	panel.size = Vector2(490, 1080)
	layer.add_child(panel)
	var holder := Control.new()
	holder.position = Vector2(1510, 150)
	layer.add_child(holder)
	var card := ComboCard.new()
	holder.add_child(card)
	card.place_bottom_centre(0)
	var c := _combo(w, &"plasma_arc")
	var pair := _reader.combo_item_ids(c)
	card.show_combo(
		&"plasma_arc",
		pair[0],
		pair[1],
		TranslationServer.translate(_reader.combo_name_key(c)),
		TranslationServer.translate(_reader.combo_desc_key(c)),
		TranslationServer.translate("UI_COMBO_UNLOCKED")
	)
	card._shown = 1.0
	card._apply()
	card.modulate.a = 1.0
	card.position.x = -card.size.x * 0.5 + 165
	var badges := HBoxContainer.new()
	badges.position = Vector2(1450, 180)
	badges.add_theme_constant_override("separation", 10)
	layer.add_child(badges)
	for k in w.combos_owned:
		var ids := _reader.combo_item_ids(k)
		var b := ComboIconView.new(ids[0], ids[1], ItemLooks.combo_color(_reader.combo_id(k)), true)
		b.custom_minimum_size = Vector2(48, 48)
		badges.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(1450, 270)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	layer.add_child(grid)
	for id in NEW_ITEMS:
		var cell := VBoxContainer.new()
		var icon := ItemIconView.new(id, ItemLooks.color_of_id(id), true)
		icon.custom_minimum_size = Vector2(90, 90)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		var l := Label.new()
		l.text = TranslationServer.translate("ITEM_" + String(id).to_upper())
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(104, 0)
		l.add_theme_font_size_override("font_size", 14)
		cell.add_child(l)
		grid.add_child(cell)


func _combo(w: World, id: StringName) -> int:
	for k in w.combo_tables.size():
		if w.combo_tables[k].id == id:
			return k
	return -1


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20:
		# Payoff effects fade in 16 frames: fire them again (a new tick) just before the grab.
		_w.discharge_tick = 1
		_w.plasma_tick = 1
		_view.sync()
	if _frames == 22:
		var img := root.get_texture().get_image()
		img.save_png(OUT + "combos.png")
		print("combos: ", OUT, "combos.png ", img.get_width(), "x", img.get_height())
		var small := img.duplicate() as Image
		small.convert(Image.FORMAT_RGB8)
		small.resize(1200, 675, Image.INTERPOLATE_LANCZOS)
		small.save_png(OUT + "combos_small.png")
		print("combos: ", OUT, "combos_small.png ", small.get_width(), "x", small.get_height())
		quit(0)
	return false
