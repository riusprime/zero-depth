extends SceneTree
## v0.6.0 MX3: the attack forms' shots under the real renderer and the v0.5.9 look. Boots the real game (main.tscn),
## starts a Blade run and, in the first room under the floor's own lighting mood, draws each of the 8 forms in a few
## elements through the game's own AttackFormView (constructed specs through spawn()), one tile per (form, element)
## round the hero, then a contact sheet; then two in-game shots: the Blade with Ember Edge and Conductor swinging
## among training dummies at Hot heat (the live arc layer), and the same fight later with MX2's Orbit Blades, Arc
## Field and Bomb Lobber granted (their live forms, read from the sim, in the weapon's elements). Needs a renderer:
##   XDG_DATA_HOME=<empty dir> xvfb-run -a godot --path . --fixed-fps 60 --audio-driver Dummy \
##     --resolution 1280x720 -s scripts/shots/attack_forms.gd
## Shot setup only (the hero can't be hurt, items, heat and enemies are set as the dev panel would). Writes
## build/shots/v0.6.0/attack_forms/: tiles/<form>_<n>.png, attack_forms_sheet.png, attack_forms_ingame*.png.

const OUT := "res://build/shots/v0.6.0/attack_forms/"
const TILE := 260
const CROP := 480
## The sheet's columns: elements (and a heat tier for the last).
const COLUMNS := [
	[["ember"], HeatLooks.TIER_COOL],
	[["storm"], HeatLooks.TIER_COOL],
	[["frost", "void"], HeatLooks.TIER_COOL],
	[["venom"], HeatLooks.TIER_COOL],
	[["bleed", "storm"], HeatLooks.TIER_HOT],
]

var _main: Main
var _frame := 0
var _script: Array = []
var _tiles: Array[Image] = []
var _heat := -1
var _rows := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "tiles/"))
	print("attack_forms: renderer=%s" % RenderingServer.get_current_rendering_method())
	var profile := ProfileStore.new("")
	profile.section("loadout")["build"] = "blade"
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_script = [[6, _tap.bind(KEY_ENTER)], [14, _tap.bind(KEY_ENTER)], [40, _setup]]
	var f := 200  # after the floor banner
	var rows := _rows_list()
	_rows = rows.size()
	for r in rows.size():
		for c in COLUMNS.size():
			_script.append([f, _spawn_tile.bind(rows[r], COLUMNS[c])])
			_script.append([f + 2, _take_tile.bind("%s_%d" % [rows[r][0], c])])
			f += 4
	_script.append([f, _sheet])
	_script.append([f + 2, _ingame_setup])
	_script.append([f + 20, _set_heat.bind(55)])
	_script.append([f + 24, _mouse.bind(MOUSE_BUTTON_LEFT, true)])
	_script.append([f + 28, _full.bind("attack_forms_ingame_blade")])
	_script.append([f + 66, _full.bind("attack_forms_ingame_forms")])
	_script.append([f + 70, _mouse.bind(MOUSE_BUTTON_LEFT, false)])
	_script.append([f + 72, quit.bind(0)])


## [label, spec extras, display age (ticks)] per row: the 8 forms, then the motion cues on bolts.
func _rows_list() -> Array:
	return [
		["arc", {"form": 0, "half_arc": 1100, "reach_m": 1.9}, 5.0],
		["bolt", {"form": 1, "count": 12, "directions": "circle", "speed": 0.2}, 9.0],
		["ring", {"form": 2, "radius_m": 3.2, "count": 2}, 13.0],
		["beam", {"form": 3, "count": 3, "spread": 700, "reach_m": 4.2, "radius_m": 0.1}, 2.0],
		["zone", {"form": 4, "radius_m": 2.2, "life_ticks": 200}, 40.0],
		["orbiter", {"form": 5, "count": 5, "reach_m": 1.6}, 30.0],
		["lob", {"form": 6, "count": 3, "spread": 900, "reach_m": 3.6, "radius_m": 1.3}, 15.0],
		["burst", {"form": 7, "radius_m": 2.6}, 4.0],
		[
			"cues",
			{"form": 1, "count": 5, "spread": 1400, "speed": 0.2, "pierce": 1, "home": true},
			14.0
		],
	]


func _process(_delta: float) -> bool:
	_frame += 1
	if _main.driver != null and _main.driver.world != null:
		var w := _main.driver.world
		w.actors.invuln[0] = 60
		w.actors.hp[0] = w.actors.max_hp[0]
		if _heat >= 0 and w.heat != null:
			w.heat.milli = _heat * HeatTable.MILLI
			w.heat.idle = 0
	for step: Array in _script.duplicate():
		if step[0] == _frame:
			(step[1] as Callable).call()
	return false


func _forms() -> AttackFormView:
	return _main.view.attack_forms


func _setup() -> void:
	Input.warp_mouse(Vector2(900, 360))


func _spawn_tile(row: Array, col: Array) -> void:
	var v := _forms()
	v.clear()
	var spec: Dictionary = (row[1] as Dictionary).duplicate()
	spec["elements"] = PackedStringArray(col[0])
	var r := WorldReader.new(_main.driver.world)
	var opts := {"start": float(r.tick()) - float(row[2]) + 2.0, "tier": col[1]}
	if row[0] == "cues":
		opts["crit"] = true
	v.spawn(spec, r.player_pos(), 0.35, opts)
	if row[0] == "cues":  # the return tether and a bounce flash beside the curving, piercing fan
		var back := {"form": 1, "speed": 0.2, "return": true, "elements": spec["elements"]}
		v.spawn(back, r.player_pos(), PI + 0.35, opts)
		v.flash(r.player_pos() + Vector2(2.2, -1.2), Color.WHITE, 0.55, float(r.tick()))


func _take_tile(label: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	# The rig keeps the hero at the screen's centre (a little above it for the iso pitch).
	var x := clampi(img.get_width() / 2 - CROP / 2, 0, img.get_width() - CROP)
	var y := clampi(img.get_height() / 2 - 10 - CROP / 2, 0, img.get_height() - CROP)
	var tile := img.get_region(Rect2i(x, y, CROP, CROP))
	tile.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
	tile.save_png(ProjectSettings.globalize_path(OUT + "tiles/" + label + ".png"))
	_tiles.append(tile)
	var v := _forms()
	print(
		(
			"attack_forms: tile %s tick=%d meshes=%d particles=%d"
			% [label, _main.driver.world.tick, v.meshes_drawn(), v.particles_drawn()]
		)
	)


func _sheet() -> void:
	var cols := COLUMNS.size()
	var sheet := Image.create(TILE * cols, TILE * _rows, false, Image.FORMAT_RGB8)
	for k in _tiles.size():
		var t := _tiles[k]
		t.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(t, Rect2i(0, 0, TILE, TILE), Vector2i((k % cols) * TILE, (k / cols) * TILE))
	var path := OUT + "attack_forms_sheet.png"
	sheet.save_png(ProjectSettings.globalize_path(path))
	print(
		(
			"attack_forms: sheet %s %dx%d tiles=%d"
			% [path, sheet.get_width(), sheet.get_height(), _tiles.size()]
		)
	)
	_forms().clear()


func _ingame_setup() -> void:
	var w := _main.driver.world
	for id: StringName in [&"ember_edge", &"conductor"]:
		for k in w.item_tables.size():
			if w.item_tables[k].id == id:
				w.add_item(k)
	# MX2's ability modifiers, granted as the dev panel would: their live forms (orbiters, shock fields, bombs).
	for id: StringName in [&"orbit_blades", &"arc_field", &"bomb_lobber"]:
		for k in w.ability_tables.size():
			if w.ability_tables[k].id == id:
				Abilities.grant(w, k)
	var p := w.player_pos()
	# Still training dummies (no telegraphs over the attacks), tough enough not to die.
	w.dummy_speed = 0.0
	for k in 6:
		w.add_dummy(p + Kin.dir(k * 683 + 200) * (2.2 + 0.5 * (k % 2)), 0.35, 99999)


func _set_heat(points: int) -> void:
	_heat = points


func _full(label: String) -> void:
	var path := OUT + label + ".png"
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	var v := _forms()
	var r := WorldReader.new(_main.driver.world)
	print(
		(
			"attack_forms: %s tick=%d heat_tier=%s swing=%d effects=%d meshes=%d particles=%d"
			% [
				path,
				r.tick(),
				r.heat_state().get("tier", "-"),
				r.swing_tick(),
				v.effect_count(),
				v.meshes_drawn(),
				v.particles_drawn()
			]
		)
	)


func _mouse(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = Vector2(900, 360)
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
