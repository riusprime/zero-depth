extends SceneTree
## v0.10.0 VX1 (VFX_PACK R10, R11, R14-R17, R43): the hits, impacts, sparks and flashes before (the old sprites and
## boxes) and after (the pack's scenes), from the game camera. Four sheets, each the old look on top and the pack's
## below, a row of six effects at the same moment (8 frames after they start):
##   1_bolt_hits.png     a bolt's impact per element: ember, storm, frost, venom, bleed, none (R14)
##   2_heavy_slash.png   heavy bolt impacts (ember, frost, storm) and slash impacts (plain, finisher, frost) (R15, R16)
##   3_sparks.png        guard, deflect, weak-spot, armour, finisher sparks and the enemy death pop (R17, R43)
##   4_casts.png         the volley's muzzle spark per element (ember, storm, frost, venom, bleed) and a heavy cast
##                       flash (R10, R11)
## A tool, not a test. Needs a renderer (no --headless) and a fixed frame time:
##   godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx1_hits.gd
## Writes build/shots/v0.10.0/vx1/ and prints each path.

const BIOME := &"ruins"
const AT := Vector2(2.0, 0.0)
const SEED := 4242
const RENDER := Vector2i(1280, 720)
const BAND := Rect2i(0, 150, 1280, 420)
## The frame each group starts at, and how many frames later it is grabbed.
const STARTS := [4, 100, 196, 292]
const GRAB_AFTER := [8, 8, 8, 3]
const LAST := 312
const SPACING := 1.4
const NAMES := ["1_bolt_hits", "2_heavy_slash", "3_sparks", "4_casts"]

var _repo: ContentRepository
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _after := false
var _frame := 0
var _right := Vector3.RIGHT
var _grabs: Array[Image] = [null, null, null, null]
var _sheets: Array[Image] = [null, null, null, null]
var _casts: Array[Dictionary] = []  # the drawn muzzle sparks and flashes of group 4
var _dir := ""


func _initialize() -> void:
	_dir = "res://build/shots/v0.10.0/vx1/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	ViewPrefs.effects_density = "high"
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = RENDER
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	for k in 4:
		_sheets[k] = Image.create(BAND.size.x, BAND.size.y * 2, false, Image.FORMAT_RGB8)
		_sheets[k].fill(Color(0.05, 0.05, 0.06))
	_build()


func _build() -> void:
	if _view != null:
		_view.queue_free()
	HitPack.clear()
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
	var biome: BiomeDefinition = _repo.get_def(&"biomes", BIOME)
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.setup(WorldReader.new(_world), biome.palette, 14.0)
	_view.rig.view_size = 5.0
	_view.rig.camera.size = 5.0
	_view.rig.snap_to(SimPlane.to_3d(AT))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	var layer := _view.attack_forms.vfx
	if not _after:  # the old look: no pack anywhere
		layer.pack_fx = null
		_view.hit_feel.pack_fx = null
	layer.drawers.append(_draw_casts.bind(layer))
	_casts.clear()
	_frame = 0


## The point `i` of 6 in the row, along the camera's right, at height `h`.
func _spot(i: int, h: float) -> Vector3:
	var off := (float(i) - 2.5) * SPACING
	var p := SimPlane.to_3d(AT) + _right * off
	return Vector3(p.x, h, p.z)


func _spot2(i: int) -> Vector2:
	var p := _spot(i, 0.0)
	return Vector2(p.x, -p.z)


func _start(g: int, layer: VfxLayer) -> void:
	var tick := int(layer.now())
	var fx: ImpactFx = _view.hit_feel.impacts
	var d := Vector3(_right.x, 0.0, _right.z).normalized()
	match g:
		0:
			var kinds: Array[StringName] = [&"ember", &"storm", &"frost", &"venom", &"bleed", &""]
			for i in 6:
				var e := kinds[i]
				var c := AttackFormLooks.element_color(e) if e != &"" else ImpactFx.HERO
				var at := _spot(i, ImpactFx.BOLT_Y)
				fx.add(at, d, at + d * 0.4, c, tick, 1.0, ImpactFx.BOLT, ElementLooks.kind(e))
		1:
			var heavy: Array[StringName] = [&"ember", &"frost", &"storm"]
			for i in 3:
				var e := heavy[i]
				var at := _spot(i, ImpactFx.BOLT_Y)
				var c := AttackFormLooks.element_color(e)
				fx.add(at, d, at + d * 0.4, c, tick, 1.25, ImpactFx.BOLT, ElementLooks.kind(e))
			var cuts: Array = [[&"", 1.1], [&"ember", 1.43], [&"frost", 1.1]]
			for i in 3:
				var e: StringName = cuts[i][0]
				var c := AttackFormLooks.element_color(e) if e != &"" else ImpactFx.HERO
				var at := _spot(i + 3, ImpactFx.SLASH_Y)
				var tan := Vector3(d.z, 0.0, -d.x)  # across the row: the cut goes up the screen
				fx.add(
					at,
					tan,
					at + d * 0.4,
					c,
					tick,
					float(cuts[i][1]),
					ImpactFx.SLASH,
					ElementLooks.kind(e)
				)
		2:
			var feel: HitFeel = _view.hit_feel
			feel._spark(
				HitPack.GUARD, _spot2(0), Color(0.85, 0.9, 1.0), HitFeel.SCALE_GUARD, 4, 0.08
			)
			feel._spark(
				HitPack.DEFLECT, _spot2(1), HitFeel.DEFLECT_COLOR, HitFeel.SCALE_DEFLECT, 3, 0.06
			)
			feel._spark(
				HitPack.WEAK, _spot2(2), Color(1.0, 0.92, 0.55), HitFeel.SCALE_WEAK, 6, 0.09
			)
			feel._spark(
				HitPack.GUARD, _spot2(3), Color(0.45, 0.45, 0.48), HitFeel.SCALE_ARMOUR, 3, 0.07
			)
			feel._spark(
				HitPack.GUARD, _spot2(4), Color(0.85, 1.0, 1.0), HitFeel.SCALE_FINISHER, 6, 0.1
			)
			feel._burst(_spot2(5), ThemePalette.color(&"enemy_body"), HitFeel.SHARDS, 0.16, true)
		3:
			var elements: Array[StringName] = [&"ember", &"storm", &"frost", &"venom", &"bleed"]
			for i in 5:
				_casts.append({"i": i, "start": _frame, "e": elements[i], "flash": false})
			_casts.append({"i": 5, "start": _frame, "e": &"", "flash": true})


## The muzzle sparks and the flash: drawn every frame as the game does, `u` through their life.
func _draw_casts(_core: VfxCore, layer: VfxLayer) -> void:
	var d := Vector3(_right.x, 0.0, _right.z).normalized()
	for c: Dictionary in _casts:
		var age := float(_frame - int(c["start"]))
		var p := _spot(int(c["i"]), ImpactFx.BOLT_Y)
		var e: StringName = c["e"]
		if c["flash"]:
			var u := age / 12.0
			if u < 1.0:
				HeroFx.flash(layer, p, Color(0.9, 0.95, 1.0), Color(0.3, 0.6, 1.0), u, 1.2, 4400, 6)
		else:
			var u := age / 6.0
			if u < 1.0:
				HeroFx.muzzle(
					layer, p, d, ElementLooks.hot(e), ElementLooks.core(e), u, 3300 + int(c["i"])
				)


func _process(_delta: float) -> bool:
	_world.step(InputFrame.make(Vector2i.ZERO, 0, 500, 0, 0))
	if _frame == 1:
		_right = _view.rig.camera.global_transform.basis.x
		_right.y = 0.0
		_right = _right.normalized()
	_view.sync()
	var layer := _view.attack_forms.vfx
	for g in 4:
		if _frame == STARTS[g]:
			_start(g, layer)
		if _frame == STARTS[g] + GRAB_AFTER[g]:
			var img := _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			_sheets[g].blit_rect(img, BAND, Vector2i(0, (1 if _after else 0) * BAND.size.y))
	_frame += 1
	if _frame < LAST:
		return false
	if not _after:
		_after = true
		_build()
		return false
	for g in 4:
		var path: String = _dir + NAMES[g] + ".png"
		_sheets[g].save_png(path)
		print("vx1_hits: ", path)
	return true
