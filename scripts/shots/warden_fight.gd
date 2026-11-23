extends SceneTree
## Renders the Twin Wardens' fight apart for the owner, in the real game view (WorldViewRoot and the HUD over TwinsLab's
## walled 24 m room, the iso camera) of a real World stepped tick by tick (floor 4's look):
##   a_charge.png   phase 1: the amber Warden winding his charge up, its lane and the burst's circle at its end; the
##                  violet Warden standing back under her dome;
##   b_mirror.png   phase 2: the Mirror Ward standing toward the hero, a shot it turned back flying at the hero, the
##                  shadow swords hanging over their lines;
##   c_ward.png     phase 3: the violet Warden under her whole ward, the amber one winding his long charge up across
##                  her (the lane white-hot), the hint arrow over her.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/warden_fight.gd
## Writes build/shots/<version>/warden_fight/ and prints each path with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const SETTLE := 14

var _vp: SubViewport
var _world: World
var _view: WardenFightRig
var _amber := -1
var _violet := -1
var _stage := 0
var _wait := 12
var _dir := ""
var _hero := Vector2(6.0, -3.0)
var _run := 0


func _initialize() -> void:
	_dir = "res://build/shots/%s/warden_fight/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	TranslationServer.set_locale("en")
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_begin(Vector2(-6.0, 3.0), Vector2(-9.0, -4.0), 0)
	BossLab.start(_world, _i(_amber), &"warden_charge")


## A fresh fight in phase index `phase`, the amber Warden at `amber`, the violet at `violet`, the view over it.
func _begin(amber: Vector2, violet: Vector2, phase: int) -> void:
	var s := TwinsLab.fight(_hero, amber)
	_world = s[0]
	_amber = s[1]
	_violet = s[2]
	TwinsLab.hush(_world, _amber)
	if phase > 0:
		TwinsLab.set_phase(_world, _amber, phase)
	_world.actors.set_pos(_i(_amber), amber)
	_world.actors.set_pos(_i(_violet), violet)
	_world.step(InputFrame.new())
	if _view != null:
		_view.free_all()
	_view = WardenFightRig.new(_vp, _world, &"frozen_shore")


func _i(aid: int) -> int:
	return _world.actors.index_of(aid)


func _step(n: int) -> void:
	for k in n:
		_world.actors.set_pos(0, _hero)
		_world.actors.hp[0] = _world.actors.max_hp[0]
		_world.step(InputFrame.new())
		_view.frame()


func _until(effect: StringName, limit: int) -> void:
	var seq := TwinsLab.mark(_world)
	for k in limit:
		if not TwinsLab.effects(_world, effect, seq).is_empty():
			return
		_step(1)


func _save(file: String, note: String) -> void:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + file
	img.save_png(path)
	print("warden_fight: ", ProjectSettings.globalize_path(path), "  ", note)


func _process(_delta: float) -> bool:
	if _run > 0:
		_step(1)
		_run -= 1
		return false
	if _wait > 0:
		_wait -= 1
		_view.frame(false)
		return false
	match _stage:
		0:
			_run = 24  # into the wind-up, the aim locked
			_wait = SETTLE
		1:
			var c: Dictionary = _view.reader.boss_wardens().get("charge", {})
			_save(
				"a_charge.png",
				(
					"tick %d end %s radius %.1f locked %s circles %d resting domes %d dome %s"
					% [
						_world.tick,
						c.get("end"),
						c.get("radius", 0.0),
						c.get("locked"),
						_view.root.charge_bursts.shown(),
						_view.root.warden_wards.resting_domes(),
						_view.root.warden_wards.hold.has([&"rest", &"violet"])
					]
				)
			)
			_hero = Vector2(5.0, -2.0)
			_begin(Vector2(-9.0, 8.0), Vector2(-1.0, 0.0), 1)
			BossLab.start(_world, _i(_violet), &"mirror_ward")
			_until(&"warden_ward_up", 80)
			var from := Vector2(3.5, -1.4)
			_world.queue_projectile(
				_world.actors.ids[0],
				ActorStore.TEAM_PLAYER,
				from,
				(Vector2(-1.0, 0.0) - from).normalized() * 0.3,
				30,
				0.2,
				200,
				SimEvent.TAG_PROJECTILE
			)
			_until(&"warden_reflect", 30)
			BossLab.start(_world, _i(_violet), &"shadow_swords")
			_run = 6
			_wait = SETTLE
		2:
			var ward: Dictionary = _view.reader.boss_wardens()["ward"]
			_save(
				"b_mirror.png",
				(
					"tick %d ward %s centre %d half %d shots %d swords %d blades %d"
					% [
						_world.tick,
						ward["kind"],
						ward["centre"],
						ward["half_arc"],
						_view.reader.projectile_count(),
						(_view.reader.boss_wardens()["swords"] as Array).size(),
						_view.root.warden_blades.blades_shown()
					]
				)
			)
			_hero = Vector2(5.0, 0.0)
			_begin(Vector2(-9.0, 0.0), Vector2.ZERO, 2)
			BossLab.start(_world, _i(_amber), &"warden_charge_long")
			_run = 40
			_wait = SETTLE
		3:
			var c: Dictionary = _view.reader.boss_wardens().get("charge", {})
			_save(
				"c_ward.png",
				(
					"tick %d ward %s breaks %s locked %s hints %d"
					% [
						_world.tick,
						_view.reader.boss_wardens()["ward"]["kind"],
						c.get("breaks"),
						c.get("locked"),
						_view.hud.objective_hints.shown().size()
					]
				)
			)
			quit(0)
			return true
	_stage += 1
	return false


## The game view and HUD over one World (rebuilt for each fight).
class WardenFightRig:
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
		root.rig.snap_to(SimPlane.to_3d(Vector2(-1.0, 2.0)))
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
