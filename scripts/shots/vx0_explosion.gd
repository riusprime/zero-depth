extends SceneTree
## v0.10.0 VX0 (VFX_PACK R18): the fire explosion before (the sprite fireball) and after (the pack's), in two biomes,
## from the game camera. One sheet per biome: the sprite explosion on the left, the pack's on the right, an early
## frame on top and a late one (the smoke) below; a thin green ring marks the burst radius so the fireball can be
## compared with it. Each tile is the real game view (WorldViewRoot with the biome's palette, mood and prop style, the
## effects layer) of a real World, at Effects density High. A tool, not a test. Needs a renderer (no --headless) and a
## fixed frame time so the sim ticks and the pack's animation agree:
##   godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx0_explosion.gd
## Writes build/shots/v0.10.0/vx0/<biome>.png and prints each path.

const BIOMES: Array[StringName] = [&"ruins", &"frozen_shore"]
const RADIUS := 2.5
const AT := Vector2(2.0, 0.0)
const SEED := 4242
## The frames (60 per second) after the burst starts that are grabbed.
const GRABS := [18, 54]
const LAST := 56
const BURST_FRAMES := 42.0
const SHEET := Vector2i(1280, 720)
const TILE := Vector2i(640, 360)
const RENDER := Vector2i(1280, 720)

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _biome_k := 0
var _after := false
var _frame := 0
var _sheet: Image
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/v0.10.0/vx0/"
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
	_sheet = Image.create(SHEET.x, SHEET.y, false, Image.FORMAT_RGB8)
	_sheet.fill(Color(0.05, 0.05, 0.06))


func _build() -> void:
	if _view != null:
		_view.queue_free()
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", BIOMES[_biome_k])
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 5.0
	_view.rig.camera.size = 5.0
	_view.rig.snap_to(SimPlane.to_3d(AT))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	var layer := _view.attack_forms.vfx
	if not _after:
		layer.pack_fx = null  # the sprite explosion
	layer.drawers.append(_draw_burst.bind(layer))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.03
	torus.outer_radius = RADIUS + 0.03
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 1.0, 0.3)
	ring.material_override = mat
	ring.position = SimPlane.to_3d(AT, 0.04)
	_view.add_child(ring)
	_frame = 0


## The burst, drawn every frame as the game does: u from 0 to 1 over its life.
func _draw_burst(_core: VfxCore, fx: VfxLayer) -> void:
	if _frame > 2 and _frame < 2 + BURST_FRAMES:
		fx.burst(&"fire", SimPlane.to_3d(AT, 0.0), RADIUS, (_frame - 2) / BURST_FRAMES, SEED)


func _process(_delta: float) -> bool:
	_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, 0, 0))
	_view.sync()
	_frame += 1
	var k: int = GRABS.find(_frame - 3)
	if k >= 0:
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		_sheet.blit_rect(
			img, Rect2i(Vector2i.ZERO, TILE), Vector2i((1 if _after else 0) * TILE.x, k * TILE.y)
		)
	if _frame - 3 < LAST:
		return false
	if not _after:
		_after = true
	else:
		var path := _dir + "%s.png" % BIOMES[_biome_k]
		_sheet.save_png(path)
		print("vx0_explosion: ", path)
		_after = false
		_biome_k += 1
		if _biome_k >= BIOMES.size():
			return true
		_new_sheet()
	_build()
	return false
