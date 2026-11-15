extends SceneTree
## Renders the Hive Lens's drones, Lattice and burnt glass for the owner, in the real game view (WorldViewRoot and the
## HUD over LensLab's walled 24 m room, the iso camera) of a real World stepped tick by tick:
##   a_feed.png     phase 2: three drones feeding the Lens (threads, shield rings, the bar's fed tone and pips) with a
##                  Focus Beam telegraphed across one of them (SHOT HELPER: the drones pinned, the beam started);
##   b_lattice.png  the Lattice standing with one drone killed (SHOT HELPER) and the hero in the gap it opened;
##   c_glass.png    phase 3: the burnt glass after a triple Focus Beam (SHOT HELPER: the beam started).
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/lens_fight.gd
## Writes build/shots/<version>/lens_fight/ and prints each path with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const SETTLE := 14
const BIOME := &"red_canyon"
const FEEDERS := [Vector2(5, 0), Vector2(-3, 6), Vector2(-5, -5)]
const WEB := [Vector2(4, 0), Vector2(0, 8), Vector2(-7.07, -7.07)]

var _vp: SubViewport
var _world: World
var _view: LensFightRig
var _boss := -1
var _stage := 0
var _wait := 12
var _dir := ""
var _hero := Vector2(10.0, 0.0)
var _pins := {}
var _gap: Array = []
var _run := 0


func _initialize() -> void:
	_dir = "res://build/shots/%s/lens_fight/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	TranslationServer.set_locale("en")
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_begin(1, false)
	for at: Vector2 in FEEDERS:
		_pins[LensLab.drone(_world, _boss, at)] = at
	_step(20)
	var i := _world.actors.index_of(_boss)
	BossLab.start(_world, i, &"focus_beam")
	var atk := BossAi.attack_of(_world, i)
	_step(int(atk.windup_ticks * 0.6))


## A fresh, hushed Hive Lens at the room's centre in phase index `phase` (its Lattice off unless `lattice`).
func _begin(phase: int, lattice: bool) -> void:
	var s := LensLab.fight(_hero)
	_world = s[0]
	_boss = s[1]
	LensLab.hush(_world, _boss)
	if not lattice:
		LensLab.lens(_world, _boss).lat_phase = 9
	LensLab.set_phase(_world, _boss, phase)
	_world.step(InputFrame.new())
	_pins = {}
	_gap = []
	if _view != null:
		_view.free_all()
	_view = LensFightRig.new(_vp, _world, BIOME)


func _lens() -> Dictionary:
	return _view.reader.boss_lens()


func _step(n: int) -> void:
	for k in n:
		for id: int in _pins:
			var j := _world.actors.index_of(id)
			if j >= 0 and _world.actors.state[j] != BossLattice.ORBIT:
				_world.actors.set_pos(j, _pins[id])
		if _gap.size() == 2:
			var a := _world.actors.index_of(int(_gap[0]))
			var b := _world.actors.index_of(int(_gap[1]))
			if a >= 0 and b >= 0:
				_hero = (_world.actors.pos(a) + _world.actors.pos(b)) * 0.5
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
	print("lens_fight: ", ProjectSettings.globalize_path(path), "  ", note)


func _process(_delta: float) -> bool:
	if _run > 0:
		_step(1)
		_run -= 1
		return false
	if _wait > 0:
		_wait -= 1
		_view.frame(false)
		return false
	var feed: LensFeedViews = _view.root.lens_feed
	var lat: LensLatticeViews = _view.root.lens_lattice
	match _stage:
		0:
			_wait = SETTLE
		1:
			_save(
				"a_feed.png",
				(
					"tick %d drones %d threads %d rings %d lane glows %s tone %s pips %d"
					% [
						_world.tick,
						_lens().get("drones", []).size(),
						feed.threads().size(),
						feed.layers(),
						feed.lane_glows(),
						_view.hud.boss_bar.tone(),
						_view.hud.boss_bar.shield_pips()
					]
				)
			)
			_hero = Vector2(-10.0, 10.0)
			_begin(1, true)
			var ids: Array[int] = []
			for at: Vector2 in WEB:
				var id := LensLab.drone(_world, _boss, at)
				ids.append(id)
				_pins[id] = at
			_until(func() -> bool: return bool(_lens()["lattice"].get("running", false)), 900)
			_step(60)
			var j := _world.actors.index_of(ids[1])  # SHOT HELPER: the middle drone killed
			_world.actors.hp[j] = 0
			_world.actors.dead[j] = 1
			_gap = [ids[0], ids[2]]
			_run = 45
			_wait = SETTLE
		2:
			_save(
				"b_lattice.png",
				(
					"tick %d strands %d drawn %d trails %d hero %s"
					% [
						_world.tick,
						(_lens()["lattice"].get("strands", []) as Array).size(),
						lat.strands().size(),
						lat.orbit_trails(),
						_hero
					]
				)
			)
			_hero = Vector2(6.0, 0.0)
			_begin(2, false)
			BossLab.start(_world, _world.actors.index_of(_boss), &"focus_beam_3")
			_until(func() -> bool: return (_lens().get("glass", []) as Array).size() == 3, 600)
			_hero = Vector2(-2.0, -6.0)
			_run = 40
			_wait = SETTLE
		3:
			_save(
				"c_glass.png",
				(
					"tick %d glass %d strips %d"
					% [_world.tick, _lens()["glass"].size(), lat.strips().size()]
				)
			)
			quit(0)
			return true
	_stage += 1
	return false


## The game view and HUD over one World (rebuilt for each fight).
class LensFightRig:
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
