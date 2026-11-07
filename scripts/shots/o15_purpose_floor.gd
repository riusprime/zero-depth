extends SceneTree
## v0.11.0 O15 (PLAN P1): one shot per purpose in a real generated run floor (as Main builds it: SaveLab.build_floor,
## FloorScenario.add_purposes), drawn by the game's own WorldViewRoot from the iso camera. Nothing is staged but the
## framing: the camera is centred on the room and widened to hold it, and the hero stands at its first doorway for
## scale. The world is never stepped (no enemies).
## Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/o15_purpose_floor.gd
## SHOT CHOICE (labelled): for each target, the first run seed from SEED whose floor 1 (in the target's biome) has a
## room with that purpose. Writes build/shots/v0.11.0/o15/floor_<purpose>_<biome>.png. Quits on every path.

const OUT := "res://build/shots/v0.11.0/o15/"
const SEED := 20261014
const SEARCH := 60
const SETTLE := 24
const TARGETS := [
	[&"camp", &"ruins"], [&"hall", &"ruins"], [&"hall", &"starfall"], [&"quarry", &"red_canyon"]
]

var _repo: ContentRepository
var _target := -1
var _view: WorldViewRoot
var _wait := 0
var _frame := 0
var _stem := ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_repo = ContentRepository.load_all()


func _next() -> bool:
	if _view != null:
		_view.queue_free()
		_view = null
	while true:
		_target += 1
		if _target >= TARGETS.size():
			return false
		var purpose: StringName = TARGETS[_target][0]
		var biome_id: StringName = TARGETS[_target][1]
		for s in SEARCH:
			var run := SaveLab.run_state(SEED + s, 1, &"blade", 0, _repo)
			var w := SaveLab.build_floor(run, biome_id, _repo)
			var f := w.floor_layout
			for room in f.purpose_rooms():
				if f.purpose_of(room) == purpose:
					_show(w, room, biome_id, SEED + s)
					_stem = "floor_%s_%s" % [purpose, biome_id]
					return true
		print("o15_purpose_floor: no %s room in %s within %d seeds" % [purpose, biome_id, SEARCH])
	return false


func _show(w: World, room: int, biome_id: StringName, run_seed: int) -> void:
	var biome: BiomeDefinition = _repo.get_def(&"biomes", biome_id)
	IcePatches.place(w, BiomeCompiler.compile_surface(biome))  # as Main
	var f := w.floor_layout
	var r := f.rooms[room]
	var doors := f.door_approaches(room, 1.6)
	if not doors.is_empty():  # SHOT STAGING (labelled): the hero at the first doorway, for scale
		w.actors.pos_x[0] = doors[0].x
		w.actors.pos_y[0] = doors[0].y
	var reader := WorldReader.new(w)
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(reader, biome.palette, 60.0)
	_view.rig.view_size = maxf(r.size.x, r.size.y) * 0.72
	_view.rig.snap_to(SimPlane.to_3d(r.get_center()))
	print(
		(
			"o15_purpose_floor: %s run_seed=%d floor=1 room=%d cells=%s size=%.1fx%.1f m mirror=%d"
			% [
				f.purpose_of(room),
				run_seed,
				room,
				f.room_cells[room].size,
				r.size.x,
				r.size.y,
				f.room_mirror[room]
			]
		)
	)
	_wait = SETTLE


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 6000:
		print("o15_purpose_floor: gave up")
		quit(1)
		return false
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var path := OUT + "%s.png" % _stem
			var img := root.get_texture().get_image()
			if img == null or img.save_png(path) != OK:
				push_error("o15_purpose_floor: could not save %s" % path)
				quit(1)
				return false
			print("o15_purpose_floor: ", path)
		return false
	if not _next():
		quit(0)
	return false
