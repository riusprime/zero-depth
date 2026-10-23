extends SceneTree
## v0.9.0 BV (owner W71): one contact sheet per biome of every Wave 4 interaction in that biome's look, in the real
## game view (WorldViewRoot with the biome's palette, mood and prop_style; the iso camera) of real floors (the tests'
## labs). Nine tiles a sheet, 3 x 3, each 640 x 360, labelled: the timed door and switches, the rune pillars and
## carving, the cracked wall, containers and explosive barrel, the purple-rune dais, a Hazard Lockdown (its bars, a
## strike's warning and the biome's hazard), the Blood shrine, the healing fountain, the Fortune shrine. A tool, not a
## test. Needs a renderer:
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/biome_looks_bv.gd
## Writes build/shots/v0.9.0/bv/<biome>.png.

const TILE := Vector2i(640, 360)
const COLS := 3
const OUT := "res://build/shots/v0.9.0/bv/"
const WARM_FRAMES := 30
const TILES: Array[StringName] = [
	&"timed_door",
	&"rune_puzzle",
	&"cracked_wall",
	&"containers",
	&"purple_dais",
	&"lockdown",
	&"blood_shrine",
	&"fountain",
	&"fortune_shrine",
]
const LONG := 1 << 24
## The camera's view (m) per tile (9 m for the rest).
const VIEW_M := {&"timed_door": 12.0, &"rune_puzzle": 11.0, &"containers": 7.0, &"lockdown": 14.0}

var _vp: SubViewport
var _label: Label
var _view: WorldViewRoot
var _world: World
var _repo: ContentRepository
var _biome_k := 0
var _tile_k := 0
var _frames := 0
var _sheet: Image
var _focus := Vector2.ZERO
var _cache := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("biome_looks_bv: renderer=%s" % RenderingServer.get_current_rendering_method())
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = TILE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_label = Label.new()
	_label.position = Vector2(10, 6)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_vp.add_child(_label)
	_new_sheet()
	_build()


func _new_sheet() -> void:
	var rows := ceili(float(TILES.size()) / COLS)
	_sheet = Image.create(TILE.x * COLS, TILE.y * rows, false, Image.FORMAT_RGBA8)
	_sheet.fill(Color.BLACK)


## The tile's world (a fresh one for the Lockdown, which the tile steps; the others are shared by the five sheets).
func _tile_world(tile: StringName) -> World:
	if tile != &"lockdown" and _cache.has(tile):
		return _cache[tile]
	var w: World = null
	match tile:
		&"timed_door":
			w = TimedLab.world()
			if w != null:
				w.step(InputFrame.new())
				TimedLab.switch(w, 0)  # one switch on: its rune lit in the biome's colour
		&"rune_puzzle":
			w = RuneLab.world()
		&"cracked_wall":
			w = CrackLab.world(&"blade")
		&"containers":
			w = CrackLab.world(&"blade", false)
			var at := w.floor_layout.start_pos + Vector2(-2.0, 3.0)
			w.breakables.add(at, Breakables.Kind.CRATE, 0, 0, 0)
			w.breakables.add(at + Vector2(1.4, 0.0), Breakables.Kind.URN, 0, 0, 0)
			w.breakables.add(at + Vector2(2.8, 0.0), Breakables.Kind.BARREL, 0, 0, 0)
			w.breakables.add(at + Vector2(4.4, 0.0), Breakables.Kind.EXPLOSIVE, 0, 0, 0)
		&"purple_dais":
			for s in range(1, 41):
				var f := SaveLab.floor_world(s, 2)
				if f.purple != null:
					f.actors.invuln[0] = LONG
					f.spawner = null
					f.boss_flow.arrive_left = 0
					f.step(InputFrame.new())
					w = f
					break
		&"lockdown":
			w = LockLab.world()
			if w != null:
				w.floor_layout.lockdown_kinds[0] = WorldReader.LOCKDOWN_HAZARD
		&"blood_shrine":
			w = ShrineLab.with_kind(ShrineTable.Kind.BLOOD)
		&"fountain":
			w = ShrineLab.with_fountain()
		&"fortune_shrine":
			w = ShrineLab.with_kind(ShrineTable.Kind.FORTUNE)
	if w != null and w.tick == 0:
		w.step(InputFrame.new())
	_cache[tile] = w
	return w


func _focus_of(tile: StringName, reader: WorldReader) -> Vector2:
	var at := reader.gamble_pos()
	match tile:
		&"timed_door":
			at = reader.timed_door_center()
			if reader.timed_switch_count() > 0:  # the door and its first switch (lit)
				at = (at + reader.interactable_pos(reader.timed_switch_entry(0))) * 0.5
		&"rune_puzzle":
			at = reader.rune_door_center()
			for k in reader.rune_pillar_count():
				at += reader.interactable_pos(reader.rune_pillar_entry(k))
			at /= float(1 + reader.rune_pillar_count())
		&"cracked_wall":
			at = reader.crack_door_center()
		&"containers":
			at = _world.floor_layout.start_pos + Vector2(0.2, 3.0)
		&"lockdown":
			at = (
				reader.lockdown()["landed_pos"]
				if _world.lockdown.landed_tick >= 0
				else reader.floor_room(LockLab.room(_world)).get_center()
			)
		&"purple_dais":
			at = reader.purple_dais_pos()
		&"blood_shrine":
			at = reader.shrine()["pos"]
		&"fountain":
			at = reader.shrine()["fountain_pos"]
	return at


func _build() -> void:
	if _view != null:
		_view.queue_free()
		_view = null
	var tile := TILES[_tile_k]
	var biome_id := InteractionLooks.BIOMES[_biome_k]
	_world = _tile_world(tile)
	_label.text = "%s  |  %s" % [biome_id, tile]
	if _world == null:
		push_error("biome_looks_bv: no floor for %s" % tile)
		_frames = WARM_FRAMES  # an empty (black) tile, named
		return
	var reader := WorldReader.new(_world)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", biome_id)
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_vp.add_child(_view)
	_view.setup(reader, biome.palette, 60.0)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	var size: float = VIEW_M.get(tile, 9.0)
	_view.rig.view_size = size
	_view.rig.camera.size = size
	_focus = _focus_of(tile, reader)
	_view.rig.snap_to(SimPlane.to_3d(_focus))
	_frames = 0


## The Lockdown tile, once warm: seal the room, step to a strike landing (its hazard shows) and on to the next
## strike's warning, so the tile holds the bars, a warning and the hazard.
func _drive_lockdown() -> void:
	var r := LockLab.room(_world)
	LockLab.enter(_world, r)
	var s := _world.lockdown
	while s.landed_tick < 0 and _world.tick - s.sealed_tick < 900:
		_world.step(InputFrame.new())
	_view.sync()
	var landed := s.landed_tick
	while s.strike_pos.is_empty() and _world.tick - landed < 600:
		_world.step(InputFrame.new())
	_view.sync()
	_view.lockdowns.settle()
	_focus = _focus_of(&"lockdown", _view.reader)  # the hazard where it landed


func _process(_delta: float) -> bool:
	_frames += 1
	if _view != null:
		_view.sync()
		_view.rig.snap_to(SimPlane.to_3d(_focus))
		if TILES[_tile_k] == &"lockdown" and _frames == WARM_FRAMES:
			_drive_lockdown()
	if _frames < WARM_FRAMES + 6:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var at := Vector2i((_tile_k % COLS) * TILE.x, floori(float(_tile_k) / COLS) * TILE.y)
	_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), at)
	_tile_k += 1
	if _tile_k >= TILES.size():
		var path := OUT + "%s.png" % InteractionLooks.BIOMES[_biome_k]
		_sheet.save_png(path)
		print("biome_looks_bv: ", path)
		_tile_k = 0
		_biome_k += 1
		if _biome_k >= InteractionLooks.BIOMES.size():
			return true
		_new_sheet()
	_build()
	return false
