extends SceneTree
## Renders the Warlord's new fight for the owner, in the real game view (WorldViewRoot and the HUD over WarlordLab's
## walled 24 m room, the iso camera) of a real World stepped tick by tick:
##   a_charge.png  its charge winding up: the lane and the end circle where it will burst;
##   b_banner.png  phase 2: the War Banner planted, the hero inside it (its warm hand), the Warlord outside it;
##   c_duel.png    phase 3: the javelin cage closed in from 9 m to 5 m, the shield lowered, the centre's circle filling
##                 with the recall's warning.
## SHOT HELPER: the Warlord is hushed (it starts nothing on its own) and the hero and the Warlord are placed.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/warlord_fight.gd
## Writes build/shots/<version>/warlord_fight/ (or out=<folder>; biome=<id> for another floor) and prints each path
## with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const SETTLE := 14

var _vp: SubViewport
var _world: World
var _view: WarlordFightRig
var _boss := -1
var _stage := 0
var _wait := 12
var _dir := ""
## The floor's look (biome=<id>), and where the stills go (out=<folder>).
var _biome := &"red_canyon"
var _hero := Vector2(-8.0, -2.0)
var _boss_at := Vector2.ZERO
var _run := 0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_biome = StringName(args.get("biome", _biome))
	_dir = (
		args.get("out", "res://build/shots/%s/warlord_fight/" % GameVersion.label()).trim_suffix(
			"/"
		)
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
	_begin(WarlordLab.PLAIN, false)
	BossLab.start(_world, _index(), &"lunge_dash")
	_until(func() -> bool: return int(_tg().get("progress", 0)) >= 750, 60)


## A fresh, hushed Warlord in phase index `phase` (its big mechanic due now with `due`).
func _begin(phase: int, due: bool) -> void:
	var s := WarlordLab.ready(_hero, phase, due)
	_world = s[0]
	_boss = s[1]
	_boss_at = _world.actors.pos(_index())
	if _view != null:
		_view.free_all()
	_view = WarlordFightRig.new(_vp, _world, _biome)


func _index() -> int:
	return _world.actors.index_of(_boss)


func _tg() -> Dictionary:
	return _view.reader.telegraph(_index())


func _wl() -> Dictionary:
	return _view.reader.boss_warlord()


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
	print("warlord_fight: ", ProjectSettings.globalize_path(path), "  ", note)


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
			_wait = SETTLE
		1:
			_save(
				"a_charge.png",
				(
					"tick %d telegraph %s circles %s"
					% [_world.tick, _tg(), _view.root.charge_bursts.circles()]
				)
			)
			_hero = Vector2(1.5, 1.0)
			_begin(WarlordLab.BANNER, true)
			_until(func() -> bool: return int(_wl().get("banner", {}).get("cast", 0)) < 0, 200)
			_world.actors.set_pos(_index(), Vector2(8.5, -3.5))
			_run = 50
			_wait = SETTLE
		2:
			var bv: WarBannerViews = _view.root.war_banner
			_save(
				"b_banner.png",
				(
					"tick %d banner %s hand %s rage %s"
					% [_world.tick, _wl().get("banner"), bv.hero_warmed(), bv.boss_enraged()]
				)
			)
			_hero = Vector2(-4.0, 0.0)
			_begin(WarlordLab.DUEL, true)
			_until(func() -> bool: return int(_wl().get("duel", {}).get("stage", 0)) == 2, 200)
			var c: Vector2 = _wl()["duel"]["centre"]
			_hero = c + Vector2(-2.6, -1.2)
			_until(
				func() -> bool:
					return float(_wl().get("duel", {}).get("zone", {}).get("warn", 0)) >= 450,
				900
			)
			_wait = SETTLE
		3:
			var avatar := _avatar()
			_save(
				"c_duel.png",
				(
					"tick %d duel %s shafts %d lowered %.2f"
					% [
						_world.tick,
						_wl().get("duel"),
						_view.root.duel_cage.shafts_shown(),
						avatar.shield_lowered() if avatar != null else -1.0
					]
				)
			)
			quit(0)
			return true
	_stage += 1
	return false


func _avatar() -> WarlordAvatar:
	var node := _view.root.actors.actor_node(_boss)
	return node.get_meta(&"enemy_avatar") as WarlordAvatar if node != null else null


## The game view and HUD over one World (rebuilt for each fight).
class WarlordFightRig:
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
		root.rig.snap_to(SimPlane.to_3d(Vector2(0.0, 0.0)))
		root.rig.set_process(false)
		root.rig.set_physics_process(false)
		root.rig.camera.current = true
		hud = Hud.new()
		vp.add_child(hud)

	## One tick's sync (`tick` false: the frame only, for the settle).
	func frame(tick := true) -> void:
		if tick:
			root.sync()
		hud.sync(reader)

	func free_all() -> void:
		root.queue_free()
		hud.queue_free()
