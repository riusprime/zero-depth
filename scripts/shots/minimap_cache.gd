extends SceneTree
## v0.10.5 W3-V3: before / after shots of the minimap at one spot, so the cached map layer can be checked to look the
## same. Boots main.tscn, starts a run (seed 4404, every floor red_canyon, as draw_growth), goes on to floor --floor
## (Main._next_floor, what the portal calls), puts the hero at the start room's centre, pauses the sim, and grabs:
##   arrival: the corner map as the floor starts;
##   all: the corner map with every room of the floor known;
##   full: the full map (the map action held) with every room known.
## Each is grabbed twice: as the game shows it ("scene"), and over the bare background ("iso": the world view and the
## rest of the HUD hidden), so a pixel diff shows the map alone and not the world's flicker.
## SHOT HELPERS (labelled): the hero is placed and made invulnerable, the sim paused, every room marked known in the
## minimap's own state (presentation only; it bumps the revision as a found room does), and the map action pressed
## through Input.action_press. Nothing is written to the sim's outcome.
## Needs a renderer, off screen:
##   "$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed \
##     -s scripts/shots/minimap_cache.gd -- --tag=before [--floor=3]
## Then the sheet (no renderer needed beyond loading PNGs):
##   "$G" --headless --path . -s scripts/shots/minimap_cache.gd -- --sheet --a=before --b=after
## Writes only under build/shots/v0.10.5/minimap/.

const SEED := 4404
const BIOME := &"red_canyon"
const OUT := "res://build/shots/v0.10.5/minimap/"
const SETTLE_FRAMES := 60
const GIVE_UP := 6000
const SHOTS: Array[String] = ["arrival", "all", "full"]
const VARIANTS: Array[String] = ["iso", "scene"]
## The corner crop grows the map's rect by this much (Astral's star and diamond sit just outside it).
const CROP_GROW := 24

var _main: Main
var _frame := 0
var _phase := 0
var _wait := 0
var _floor_no := 1
var _target := 3
var _tag := "shot"
var _world_was: World
var _queue: Array = []
var _hidden: Array[CanvasItem] = []


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("sheet"):
		_sheet(str(args.get("a", "before")), str(args.get("b", "after")))
		quit(0)
		return
	_tag = str(args.get("tag", _tag))
	_target = int(args.get("floor", "3"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + _tag))
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > GIVE_UP:
		print("minimap_cache: gave up in phase ", _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frame == 3:
				_main._stage_seed = SEED
				_main.start_stage()
				_main._run_biomes.fill(BIOME)
				_main._restart_floor()
				_phase = 1
				_wait = 0
		1:  # a floor is up: wait for its cover and arrival
			_wait += 1
			if _ready():
				if _floor_no < _target:
					_world_was = _main.driver.world
					_main.driver.world.actors.invuln[0] = 1 << 24
					_floor_no += 1
					_main._next_floor()
					_phase = 2
				else:
					_place()
					_phase = 3
					_wait = 0
		2:
			if _main.driver != null and _main.driver.world != _world_was:
				_phase = 1
				_wait = 0
		3:  # settling at the start room
			_wait += 1
			if _wait == SETTLE_FRAMES:
				_main.driver.paused = true
				_main.view.rig.snap_to(SimPlane.to_3d(_main.driver.world.player_pos()))
				_queue = [
					["arrival", Callable()],
					["all", _reveal_all],
					["full", _hold_map],
				]
				_phase = 4
				_wait = 0
		4:
			return _shoot()
	return false


func _ready() -> bool:
	if _main.driver == null or _main.view == null or _wait < 10:
		return false
	if _main.loads.busy() or _main.loads.cover.showing():
		return false
	return not _main.driver.reader.transit_holds()


func _place() -> void:
	var w := _main.driver.world
	w.actors.invuln[0] = 1 << 24
	w.actors.set_pos(0, w.floor_layout.rooms[w.floor_layout.start_room].get_center())
	w.vel = Vector2.ZERO
	w.aim_angle = 512
	_main.view.rig.snap_to(SimPlane.to_3d(w.player_pos()))


## Each shot: its setup, a few frames, the scene grab, the iso grab (world and other HUD hidden), shown again.
func _shoot() -> bool:
	if _queue.is_empty():
		Input.action_release(&"map")
		var mm: Minimap = _main._hud.minimap
		print(
			(
				"minimap_cache: done tag=%s floor=%d rooms=%d known=%d revision=%d corner_draws=%d"
				% [
					_tag,
					_floor_no,
					_main.driver.reader.floor_room_count(),
					mm.state.discovered_count(),
					mm.state.revision,
					mm.corner.draw_count()
				]
			)
		)
		quit(0)
		return true
	_wait += 1
	var shot: Array = _queue[0]
	if _wait == 1 and (shot[1] as Callable).is_valid():
		(shot[1] as Callable).call()
	elif _wait == 8:
		_grab(shot[0], "scene")
		_isolate(true)
	elif _wait == 14:
		_grab(shot[0], "iso")
		_isolate(false)
	elif _wait == 20:
		_queue.pop_front()
		_wait = 0
	return false


func _reveal_all() -> void:
	var st: MinimapState = _main._hud.minimap.state
	for r in st.discovered.size():
		if not st.hidden.has(r):
			st.discovered[r] = 1
	st.revision += 1


func _hold_map() -> void:
	Input.action_press(&"map")


func _isolate(on: bool) -> void:
	_main.view.visible = not on
	if on:
		for c in _main._hud.get_children():
			if c != _main._hud.minimap and c is CanvasItem and (c as CanvasItem).visible:
				_hidden.append(c)
				(c as CanvasItem).visible = false
	else:
		for c in _hidden:
			c.visible = true
		_hidden.clear()


func _grab(shot: String, variant: String) -> void:
	var img := root.get_texture().get_image()
	var mm: Minimap = _main._hud.minimap
	var path := "%s%s/%s_%s.png" % [OUT, _tag, shot, variant]
	if shot != "full":
		var xf := root.get_final_transform() * mm.corner.get_global_transform_with_canvas()
		var r := Rect2(xf * Vector2.ZERO, xf.basis_xform(mm.corner.size)).grow(CROP_GROW)
		var ri := Rect2i(r.position.floor(), r.size.ceil()).intersection(
			Rect2i(Vector2i.ZERO, img.get_size())
		)
		img = img.get_region(ri)
	img.save_png(ProjectSettings.globalize_path(path))
	print("minimap_cache: wrote ", path, " ", img.get_size())


## Before / after / diff for every shot, in one sheet; prints each pair's differing pixels and largest difference.
func _sheet(a: String, b: String) -> void:
	var rows: Array = []
	var width := 0
	var height := 0
	for shot in SHOTS:
		for variant in VARIANTS:
			var pa := ProjectSettings.globalize_path("%s%s/%s_%s.png" % [OUT, a, shot, variant])
			var pb := ProjectSettings.globalize_path("%s%s/%s_%s.png" % [OUT, b, shot, variant])
			if not FileAccess.file_exists(pa) or not FileAccess.file_exists(pb):
				print("minimap_cache: missing ", pa, " or ", pb)
				continue
			var ia := Image.load_from_file(pa)
			var ib := Image.load_from_file(pb)
			ia.convert(Image.FORMAT_RGBA8)
			ib.convert(Image.FORMAT_RGBA8)
			if shot == "full":  # the full map: half size in the sheet
				for im: Image in [ia, ib]:
					im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_NEAREST)
			var d := _diff(ia, ib, [pa, pb], shot + "_" + variant, shot == "full")
			rows.append([ia, ib, d])
			width = maxi(width, ia.get_width() * 3 + 16)
			height += ia.get_height() + 8
	if rows.is_empty():
		return
	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.5, 0.5, 0.5))
	var y := 0
	for row: Array in rows:
		var x := 0
		for im: Image in row:
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))
			x += im.get_width() + 8
		y += (row[0] as Image).get_height() + 8
	var out := ProjectSettings.globalize_path("%ssheet_%s_vs_%s.png" % [OUT, a, b])
	sheet.save_png(out)
	print(
		"minimap_cache: sheet ",
		out,
		" ",
		sheet.get_size(),
		" (columns: ",
		a,
		" | ",
		b,
		" | diff x8)"
	)


## |a - b| per channel, times 8, as an image; prints the count of pixels that differ and the largest difference.
## For the full map (halved for the sheet) the stats are read on the full-size files.
func _diff(ia: Image, ib: Image, paths: Array, label: String, halved: bool) -> Image:
	var sa := ia
	var sb := ib
	if halved:
		sa = Image.load_from_file(paths[0])
		sb = Image.load_from_file(paths[1])
		sa.convert(Image.FORMAT_RGBA8)
		sb.convert(Image.FORMAT_RGBA8)
	var w := mini(sa.get_width(), sb.get_width())
	var h := mini(sa.get_height(), sb.get_height())
	var differ := 0
	var over2 := 0
	var box := Rect2i()
	var biggest := 0
	for yy in h:
		for xx in w:
			var ca := sa.get_pixel(xx, yy)
			var cb := sb.get_pixel(xx, yy)
			var m := maxi(maxi(absi(ca.r8 - cb.r8), absi(ca.g8 - cb.g8)), absi(ca.b8 - cb.b8))
			if m > 0:
				differ += 1
			if m > 2:
				over2 += 1
				box = Rect2i(xx, yy, 1, 1) if over2 == 1 else box.expand(Vector2i(xx, yy))
			biggest = maxi(biggest, m)
	print(
		(
			"minimap_cache: diff %s: %d x %d px, %d differ, %d by more than 2/255 (within %s), largest %d/255"
			% [label, w, h, differ, over2, box, biggest]
		)
	)
	var dw := mini(ia.get_width(), ib.get_width())
	var dh := mini(ia.get_height(), ib.get_height())
	var d := Image.create(dw, dh, false, Image.FORMAT_RGBA8)
	for yy in dh:
		for xx in dw:
			var ca := ia.get_pixel(xx, yy)
			var cb := ib.get_pixel(xx, yy)
			d.set_pixel(
				xx,
				yy,
				Color(
					minf(absf(ca.r - cb.r) * 8.0, 1.0),
					minf(absf(ca.g - cb.g) * 8.0, 1.0),
					minf(absf(ca.b - cb.b) * 8.0, 1.0),
					1.0
				)
			)
	return d
