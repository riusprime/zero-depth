extends SceneTree
## Renders the Siege Engine's fight apart for the owner, in the real game view (WorldViewRoot and the HUD over
## SiegeLab's walled 24 m room, the iso camera) of a real World stepped tick by tick (the night rocks' look):
##   a_lock.png     phase 2: a Target Lock's reticle on the hero, one boulder already standing;
##   b_cover.png    phase 3: a Shockwave winding up, the hero covered behind a boulder, the shadow behind it;
##   c_cart.png     phase 2: the ammo cart rolling home on its track, the Engine's countdown ring nearly full;
##   d_stunned.png  the Gatekeeper stunned (SHOT HELPER: its stagger set directly, as a broken quake pillar leaves it):
##                  the wordless vulnerable read on it and the bar's gold shimmer.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/siege_fight.gd
## Writes build/shots/<version>/siege_fight/ (or out=<folder>; biome=<id> for another floor) and prints each path
## with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const SETTLE := 14

var _vp: SubViewport
var _world: World
var _view: SiegeFightRig
var _boss := -1
var _stage := 0
var _wait := 12
var _dir := ""
## The floor's look (biome=<id>), and where the stills go (out=<folder>).
var _biome := &"night_rocks"
var _hero := Vector2(-5.0, 3.0)
var _run := 0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_biome = StringName(args.get("biome", _biome))
	_dir = (
		args.get("out", "res://build/shots/%s/siege_fight/" % GameVersion.label()).trim_suffix("/")
		+ "/"
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	TranslationServer.set_locale("en")
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_begin(Vector2(6.0, 0.0), 1, ["lock"])
	SiegeLab.boulder(_world, _boss, Vector2(-1.0, -4.0))
	_until(func() -> bool: return int(_siege().get("lock", {}).get("left", 999)) <= 70, 900)


## A fresh siege in phase index `phase` with only `parts` of it on, the Engine at `at`, the view over it.
func _begin(at: Vector2, phase: int, parts: Array) -> void:
	var s := SiegeLab.only(_hero, at, phase, parts)
	_world = s[0]
	_boss = s[1]
	_world.step(InputFrame.new())
	if _view != null:
		_view.free_all()
	_view = SiegeFightRig.new(_vp, _world, _biome)


func _siege() -> Dictionary:
	return _view.reader.boss_siege()


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


func _save(file: String, note: String) -> void:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + file
	img.save_png(path)
	print("siege_fight: ", ProjectSettings.globalize_path(path), "  ", note)


func _process(_delta: float) -> bool:
	if _run > 0:
		_step(1)
		_run -= 1
		return false
	if _wait > 0:
		_wait -= 1
		_view.frame(false)
		return false
	var field: SiegeFieldViews = _view.root.siege_field
	match _stage:
		0:
			_wait = SETTLE
		1:
			_save(
				"a_lock.png",
				(
					"tick %d lock %s drawn %s boulders %d"
					% [
						_world.tick,
						_siege().get("lock"),
						field.lock_circle(),
						field.boulders_shown()
					]
				)
			)
			_hero = Vector2(9.0, 0.0)
			_begin(Vector2.ZERO, 2, [])
			SiegeLab.boulder(_world, _boss, Vector2(5.0, 0.0))
			SiegeLab.boulder(_world, _boss, Vector2(-4.0, 6.0))
			BossLab.start(_world, _world.actors.index_of(_boss), &"shockwave")
			_run = 40
			_wait = SETTLE
		2:
			_save(
				"b_cover.png",
				(
					"tick %d covered %s read %s shadows %d hints %d"
					% [
						_world.tick,
						_siege().get("covered"),
						field.hero_read(),
						field.shadows().size(),
						_view.hud.objective_hints.shown().size()
					]
				)
			)
			_hero = Vector2(-7.0, 7.0)
			_begin(Vector2(6.0, 0.0), 1, ["doom"])
			_until(
				func() -> bool: return int(_siege().get("cart", {}).get("progress", 0)) >= 880, 1600
			)
			_wait = SETTLE
		3:
			var cart: SiegeCartViews = _view.root.siege_cart
			_save(
				"c_cart.png",
				(
					"tick %d cart %s shown %s ring %.2f blast %s"
					% [
						_world.tick,
						_siege().get("cart", {}).get("progress"),
						cart.cart_shown(),
						cart.cast_share(),
						cart.blast_circle()
					]
				)
			)
			_stun_gatekeeper()
			_run = 20
			_wait = SETTLE
		4:
			_save(
				"d_stunned.png",
				(
					"tick %d stunned %s tone %s vulnerable %d"
					% [
						_world.tick,
						_view.reader.boss_stunned(_view.reader.boss_index()),
						_view.hud.boss_bar.tone(),
						_view.root.boss_vulnerable.shown()
					]
				)
			)
			quit(0)
			return true
	_stage += 1
	return false


## SHOT HELPER: a still Gatekeeper staggered as a broken quake pillar leaves it (its stagger set directly).
func _stun_gatekeeper() -> void:
	_hero = Vector2(-5.0, 2.0)
	_world = JudgeLab.world(11)
	var i := BossLab.ready_boss(_world, &"gatekeeper", Vector2(3.0, 0.0))
	_boss = _world.actors.ids[i]
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	var t := BossAi.table_of(_world, i)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.speed = 0.0
	EnemyAi.enter_state(_world.actors, i, BossAi.STAGGERED)
	_world.bosses.stagger_t[BossAi.entry_of(_world, i)] = 600
	if _view != null:
		_view.free_all()
	_view = SiegeFightRig.new(_vp, _world, _biome)


## The game view and HUD over one World (rebuilt for each fight).
class SiegeFightRig:
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
