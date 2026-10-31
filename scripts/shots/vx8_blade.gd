extends SceneTree
## v0.10.0 VX8 (VFX_PACK N3): the Blade's swings before (the plain ribbon, the old forms) and after (the pack's), from
## the game camera. Three sheets, the old look on the left and the pack's on the right, an early frame on top and a
## later one below: `swing` (the blade's ribbon and the cut's spark, mid-swing and at the cut), `forms` (the Blade's
## cards: crescents, eruption, rings, parry sparks; the frame with the most forms drawn) and `cleave` (the Lunge
## Cleave's sweep and its hit). "Old" is a view with no pack above it (WorldViewRoot.pack_fx null); the world is the
## same. A tool, not a test. Needs a renderer (no --headless) and a fixed frame time so the sim ticks and the pack's
## animation agree:
##   godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720
##     -s scripts/shots/vx8_blade.gd
## Writes build/shots/v0.10.0/vx8/<sheet>.png and prints each path.

const SHEETS: Array[StringName] = [&"swing", &"forms", &"cleave"]
const BIOME := &"ruins"
const LAST := 420
const SHEET := Vector2i(1280, 720)
const TILE := Vector2i(640, 360)
const RENDER := Vector2i(1280, 720)
## The frames (60 per second) of the swing and the cleave that are grabbed, after the press at PRESS.
const PRESS := 3
const SWING_GRABS := [PRESS + 5, PRESS + 9]
const SETTLE := 3

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _sheet_k := 0
var _after := false
var _frame := 0
var _grabs: Array = []
var _stop := 0
var _img: Image
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/v0.10.0/vx8/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	ViewPrefs.effects_density = "high"
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = RENDER
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_new_sheet()
	_begin()


func _new_sheet() -> void:
	_img = Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGB8)
	_img.fill(Color(0.05, 0.05, 0.06))


## A fresh world for the current sheet, and the frames to grab (found by a quiet run of the same world).
func _make_world() -> World:
	var id := SHEETS[_sheet_k]
	if id == &"forms":
		return WandLab.fight(&"blade", [&"fissure", &"counter", &"echo_slash", &"parry_edge"])
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.crit_chance_permille = 0
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	w.actors.invuln[0] = 1 << 20
	w.add_dummy(Vector2(1.6, 0.0) if id == &"swing" else Vector2(5.5, 0.0), 0.35, 1 << 20)
	return w


func _input(frame: int) -> InputFrame:
	match SHEETS[_sheet_k]:
		&"forms":
			return AttackScenario.frame(frame)
		&"cleave":
			return InputFrame.make(
				Vector2i.ZERO, 0, 300, 0, InputFrame.SKILL if frame == PRESS else 0
			)
	return InputFrame.make(
		Vector2i.ZERO, 0, 100, InputFrame.PRIMARY, InputFrame.PRIMARY if frame == PRESS else 0
	)


## The frames to grab: the swing's are fixed, the cleave's follow its hit, the forms' are the busiest frame.
func _find_grabs() -> void:
	var id := SHEETS[_sheet_k]
	if id == &"swing":
		_grabs = SWING_GRABS
		_stop = _grabs[-1] + SETTLE + 1
		return
	var w := _make_world()
	var r := WorldReader.new(w)
	var forms := BladeFormView.new()
	var best := -1
	var best_frame := 0
	var hit := -1
	for f in LAST:
		w.step(_input(f))
		if id == &"forms":
			forms.sync(r)
			var score := forms.baked_drawn()
			for k: StringName in forms.drawn:
				score += int(forms.drawn[k]) * (4 if k != &"crescent" else 1)
			if score > best:
				best = score
				best_frame = f
		elif hit < 0 and int(r.skill_state().get("hit_tick", -1)) >= 0:
			hit = f
			break
	forms.free()
	if id == &"forms":
		_grabs = [best_frame - 3, best_frame]
	else:
		_grabs = [hit - 2, hit + 3]
	_stop = _grabs[-1] + SETTLE + 1


func _begin() -> void:
	if _view != null:
		_view.queue_free()
	if _grabs.is_empty():
		_find_grabs()
	_world = _make_world()
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", BIOME)
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 5.0
	_view.rig.camera.size = 5.0
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	if not _after:  # the old look: no pack above the Blade's views
		_view.pack_fx = null
	_frame = 0


func _process(_delta: float) -> bool:
	_world.step(_input(_frame))
	var reader := WorldReader.new(_world)
	_view.rig.snap_to(SimPlane.to_3d(reader.player_pos() + Vector2(1.5, 0.0)))
	_view.sync()
	_frame += 1
	var k: int = _grabs.find(_frame - SETTLE)
	if k >= 0:
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		_img.blit_rect(
			img, Rect2i(Vector2i.ZERO, TILE), Vector2i((1 if _after else 0) * TILE.x, k * TILE.y)
		)
	if _frame < _stop:
		return false
	if not _after:
		_after = true
	else:
		var path := _dir + "%s.png" % SHEETS[_sheet_k]
		_img.save_png(path)
		print("vx8_blade: ", path)
		_after = false
		_grabs = []
		_sheet_k += 1
		if _sheet_k >= SHEETS.size():
			return true
		_new_sheet()
	_begin()
	return false
