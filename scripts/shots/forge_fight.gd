extends SceneTree
## Renders the Foundry's forge for the owner, in the real game view (WorldViewRoot and the HUD over ForgeLab's walled
## 24 m room, the iso camera) of a real World stepped tick by tick (the canyon's look):
##   a_plate.png   phase 2: the Foundry wearing its plate, a drone's bomb in the air and the faint ring by the Foundry;
##   b_over.png    phase 3: Overpressure burning the floor, the hero on a slab, the safe slabs ringed, the hint
##                 arrows;
##   c_hud.png     the HUD's bottom left, enlarged: the scald gauge half full over the HP plate, the Overclock meter
##                 (SHOT HELPER: the overclock heat enabled and set Hot) beside it at the bottom centre.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/forge_fight.gd
## Writes build/shots/<version>/forge_fight/ and prints each path with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const SETTLE := 14
const NEVER := 9
const BIOME := &"red_canyon"

var _vp: SubViewport
var _world: World
var _view: ForgeFightRig
var _boss := -1
var _stage := 0
var _wait := 12
var _dir := ""
var _hero := Vector2(3.6, 0.0)
var _run := 0


func _initialize() -> void:
	_dir = "res://build/shots/%s/forge_fight/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	TranslationServer.set_locale("en")
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_begin(1, ["plate"])
	_world.boss_fight.fg_plate_due = _world.tick
	var plate := func() -> ForgePlateViews: return _view.root.forge_plate
	_until(
		func() -> bool:
			return (
				bool(_forge().get("plate", {}).get("on", false))
				and plate.call().bombs_shown() > 0
				and _lob_share() >= 0.45
			),
		1500
	)


## A fresh, hushed Foundry at the room's centre in phase index `phase` with only `parts` of its forge on.
func _begin(phase: int, parts: Array) -> void:
	var s := ForgeLab.fight(_hero, Vector2.ZERO)
	_world = s[0]
	_boss = s[1]
	ForgeLab.hush(_world, _boss)
	var f := ForgeLab.forge(_world, _boss)
	for p: Array in [
		["plate", &"plate_phase"],
		["slab", &"slab_phase"],
		["over", &"over_phase"],
		["scald", &"scald_phase"]
	]:
		if not parts.has(p[0]):
			f.set(p[1], NEVER)
	if not parts.has("drop"):
		f.drop_ticks = 0
	ForgeLab.set_phase(_world, _boss, phase)
	_world.step(InputFrame.new())
	if _view != null:
		_view.free_all()
	_view = ForgeFightRig.new(_vp, _world, BIOME)


func _forge() -> Dictionary:
	return _view.reader.boss_forge()


## How far through its flight the first drone's bomb is (0..1; -1 none).
func _lob_share() -> float:
	var r := _view.reader
	for j in r.actor_count():
		if r.actor_kind(j) == WorldReader.KIND_BOMB_DRONE:
			var tg := r.telegraph(j)
			if tg.get("shape", &"") == &"lob":
				return float(tg["progress"]) / 1000.0
	return -1.0


func _step(n: int) -> void:
	for k in n:
		_world.actors.set_pos(0, _hero)
		_world.actors.hp[0] = _world.actors.max_hp[0]
		_world.step(InputFrame.new())
		_view.frame()


func _until(done: Callable, limit: int) -> void:
	for k in limit:
		if done.call():
			return
		_step(1)


func _save(file: String, note: String, crop := Rect2i(), zoom := 1.0) -> void:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if crop.has_area():
		img = img.get_region(crop)
		img.resize(int(crop.size.x * zoom), int(crop.size.y * zoom), Image.INTERPOLATE_LANCZOS)
	var path := _dir + file
	img.save_png(path)
	print("forge_fight: ", ProjectSettings.globalize_path(path), "  ", note)


func _process(_delta: float) -> bool:
	if _run > 0:
		_step(1)
		_run -= 1
		return false
	if _wait > 0:
		_wait -= 1
		_view.frame(false)
		return false
	var plate: ForgePlateViews = _view.root.forge_plate
	var slag: ForgeSlagViews = _view.root.forge_slag
	match _stage:
		0:
			_wait = SETTLE
		1:
			var avatar := _avatar()
			_save(
				"a_plate.png",
				(
					"tick %d plate %s bombs %d ring %s shell %.2f tone %s"
					% [
						_world.tick,
						_forge().get("plate"),
						plate.bombs_shown(),
						plate.reach_read(),
						avatar.plate_amount() if avatar != null else -1.0,
						_view.hud.boss_bar.tone()
					]
				)
			)
			_hero = Vector2(6.0, 6.0)
			_begin(2, ["slab", "over", "scald"])
			ForgeLab.slab(_world, _boss, Vector2(6.0, 6.0), 6000)
			ForgeLab.slab(_world, _boss, Vector2(-6.0, -5.0), 6000)
			ForgeLab.slab(_world, _boss, Vector2(-7.0, 6.0), 6000)
			_world.boss_fight.fg_over_due = _world.tick + 1
			_until(
				func() -> bool: return int(_forge().get("overpressure", {}).get("burn", -1)) >= 0,
				400
			)
			_run = 30
			_wait = SETTLE
		2:
			_save(
				"b_over.png",
				(
					"tick %d over %s slabs %d heat %s hints %d"
					% [
						_world.tick,
						_forge().get("overpressure"),
						slag.slabs().size(),
						slag.heat_read().get("level", -1.0),
						_view.hud.objective_hints.shown().size()
					]
				)
			)
			_hero = Vector2(-4.0, 2.0)
			_begin(2, ["scald"])
			var repo := ContentRepository.load_all()
			Heat.enable(_world, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
			_world.heat.milli = int(_world.heat.table.overclock_threshold * 0.8 * HeatTable.MILLI)
			_world.boss_fight.fg_scald = 500
			_run = 20
			_wait = SETTLE
		3:
			_world.heat.milli = int(_world.heat.table.overclock_threshold * 0.8 * HeatTable.MILLI)
			_view.frame(false)
			_save(
				"c_hud.png",
				(
					"tick %d scald %s fill %.2f state %s heat %s"
					% [
						_world.tick,
						_forge().get("scald"),
						_view.hud.scald.fill(),
						_view.hud.scald.state(),
						_view.reader.heat_state().get("tier")
					]
				),
				Rect2i(0, 520, 1100, 380),
				1.45
			)
			quit(0)
			return true
	_stage += 1
	return false


func _avatar() -> FoundryAvatar:
	var node := _view.root.actors.actor_node(_boss)
	return node.get_meta(&"enemy_avatar") as FoundryAvatar if node != null else null


## The game view and HUD over one World (rebuilt for each fight).
class ForgeFightRig:
	extends RefCounted
	var root: WorldViewRoot
	var hud: Hud
	var reader: WorldReader

	func _init(vp: SubViewport, w: World, biome_id: StringName) -> void:
		var repo := ContentRepository.load_all()
		reader = WorldReader.new(w)
		root = WorldViewRoot.new()
		vp.add_child(root)
		var biome: BiomeDefinition = repo.get_def(&"biomes", biome_id)
		root.stage.mood = biome.mood
		root.stage.prop_style = biome.id
		root.stage.look = biome.look
		root.setup(reader, biome.palette, 14.0)
		root.rig.view_size = 26.0
		root.rig.camera.size = 26.0
		root.rig.snap_to(SimPlane.to_3d(Vector2(1.0, 1.0)))
		root.rig.set_process(false)
		root.rig.set_physics_process(false)
		root.rig.camera.current = true
		hud = Hud.new()
		vp.add_child(hud)
		hud.objective_hints.gate = _always

	func _always(_reason: StringName) -> bool:
		return true

	## One tick's sync (`tick` false: the frame only, for the settle).
	func frame(tick := true) -> void:
		if tick:
			root.sync()
		hud.sync(reader)

	func free_all() -> void:
		root.queue_free()
		hud.queue_free()
