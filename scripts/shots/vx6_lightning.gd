extends SceneTree
## v0.10.0 VX6 (VFX_PACK N1): lightning before (the sprite bolts) and after (the pack-style ZdBolt), from the game
## camera. Three sheets, each the old look on the left and the new on the right, one frame grabbed early in the effect:
##   strikes.png: a strike, a chain of jumps and a long beam (VfxLayer.line);
##   zones.png:   a shock field, a shock ring and a storm blast (VfxLayer.field, .ring, .burst);
##   shock.png:   three enemies with the shock status (VfxLayer.status).
## Each tile is the real game view (WorldViewRoot, the effects layer) of a real World, at Effects density High. A tool,
## not a test. Needs a renderer and a fixed frame time (run it off screen):
##   godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 \
##     -s scripts/shots/vx6_lightning.gd
## Writes build/shots/v0.10.0/vx6/<sheet>.png and prints each path.

const SHEETS: Array[StringName] = [&"strikes", &"zones", &"shock"]
const BIOME := &"ruins"
const AT := Vector2(2.0, 0.0)
const SEED := 4242
const START := 100
const GRAB := 114
const LAST := 116
const TILE := Vector2i(800, 450)
const RENDER := Vector2i(1280, 720)
const BODY_COLOR := Color(0.45, 0.2, 0.2)

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _sheet_k := 0
var _after := false
var _frame := 0
var _sheet: Image
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/v0.10.0/vx6/"
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
	_build()


func _new_sheet() -> void:
	_sheet = Image.create(TILE.x * 2, TILE.y, false, Image.FORMAT_RGB8)
	_sheet.fill(Color(0.05, 0.05, 0.06))


func _build() -> void:
	if _view != null:
		_view.queue_free()
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2(-6.0, -6.0))
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", BIOME)
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 6.0
	_view.rig.camera.size = 6.0
	_view.rig.snap_to(SimPlane.to_3d(AT))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	var layer := _view.attack_forms.vfx
	if not _after:
		layer.pack_fx = null  # the sprite bolts
	layer.drawers.append(_draw.bind(layer))
	if SHEETS[_sheet_k] == &"shock":
		for p: Vector2 in _bodies():
			var m := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.35
			cap.height = 0.9
			m.mesh = cap
			var mat := StandardMaterial3D.new()
			mat.albedo_color = BODY_COLOR
			m.material_override = mat
			m.position = SimPlane.to_3d(p, 0.45)
			_view.add_child(m)
	_frame = 0


func _bodies() -> Array[Vector2]:
	return [AT + Vector2(-1.4, 0.2), AT + Vector2(0.2, -0.5), AT + Vector2(1.5, 0.4)]


func _p(x: float, y: float, h := 0.8) -> Vector3:
	return SimPlane.to_3d(AT + Vector2(x, y), h)


## The sheet's effects, drawn every frame as the game does.
func _draw(_core: VfxCore, fx: VfxLayer) -> void:
	if _frame < START or _sheet_k >= SHEETS.size():
		return
	var age := float(_frame - START)
	match SHEETS[_sheet_k]:
		&"strikes":
			fx.line(&"storm", _p(-2.6, -0.3), _p(-0.6, 0.5), 0.9, age, SEED)
			fx.line(&"storm", _p(-0.6, 0.5), _p(0.6, -0.9), 0.9, age, SEED + 1)
			fx.line(&"storm", _p(0.6, -0.9), _p(2.2, 0.3), 0.9, age, SEED + 2)
			fx.line(&"storm", _p(-2.4, 1.6, 1.1), _p(2.6, 1.2, 0.5), 0.9, age, SEED + 3)
		&"zones":
			fx.field(&"storm", _p(-1.7, 0.2, 0.0), 1.3, 1.0, age, SEED)
			fx.ring(&"storm", _p(1.2, 0.2, 0.0), 1.1, 1.0, age, SEED + 1)
			fx.burst(&"storm", _p(0.0, -1.6, 0.0), 1.3, float(_frame - START) / 30.0, SEED + 2)
		&"shock":
			var k := 0
			for p: Vector2 in _bodies():
				fx.status(SimPlane.to_3d(p, 0.0), 0.35, {&"shock": 2}, SEED + k * 11, 0.9)
				k += 1


func _process(_delta: float) -> bool:
	_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, 0, 0))
	_view.sync()
	_frame += 1
	if _frame == GRAB:
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		_sheet.blit_rect(
			img, Rect2i(Vector2i.ZERO, TILE), Vector2i((1 if _after else 0) * TILE.x, 0)
		)
	if _frame < LAST:
		return false
	if not _after:
		_after = true
	else:
		var path := _dir + "%s.png" % SHEETS[_sheet_k]
		_sheet.save_png(path)
		print("vx6_lightning: ", path)
		_after = false
		_sheet_k += 1
		if _sheet_k >= SHEETS.size():
			return true
		_new_sheet()
	_build()
	return false
