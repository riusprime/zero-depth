extends SceneTree
## Renders The Fallen holding a card of yours for the owner, in the real game view (WorldViewRoot and the HUD over the
## final arena, the iso camera) of a real World stepped tick by tick (NemesisLab: a Gun run holding four wand cards,
## The Fallen fighting): a_theft.png, the taken card's pip dark under its violet glow on the HUD's wand row and the
## violet mark on The Fallen's back with its ring of pips (three hits already counted: five left).
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/fallen_theft.gd
## Writes build/shots/<version>/fallen_theft/ and prints the path with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const SETTLE := 20
const PREP := 8
const SEED := 951
const CARDS := [[&"gun_twin", 2], [&"split_shot", 5], [&"ember_core", 3], [&"halo_shot", 1]]

var _vp: SubViewport
var _world: World
var _root: WorldViewRoot
var _hud: Hud
var _reader: WorldReader
var _wait := -1
var _prep := 0
var _dir := ""
var _hero := Vector2.ZERO


func _initialize() -> void:
	_dir = "res://build/shots/%s/fallen_theft/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	TranslationServer.set_locale("en")
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)


func _begin() -> void:
	_world = NemesisLab.world(SEED, &"gun", CARDS, true, true)
	_hero = _world.final_fight.home + Vector2(4.0, -3.0)
	_world.actors.set_pos(0, _hero)
	var repo := ContentRepository.load_all()
	_reader = WorldReader.new(_world)
	_root = WorldViewRoot.new()
	_vp.add_child(_root)
	var arena: BiomeDefinition = repo.get_def(&"final_arena", &"hollow_arena")
	_root.stage.mood = arena.mood
	_root.stage.prop_style = arena.id
	_root.stage.look = arena.look
	_root.setup(_reader, arena.palette, _reader.final_arena_radius() + 4.0)
	_root.rig.view_size = 30.0
	_root.rig.camera.size = 30.0
	_root.rig.snap_to(SimPlane.to_3d(_world.final_fight.home))
	_root.rig.set_process(false)
	_root.rig.set_physics_process(false)
	_root.rig.camera.current = true
	_hud = Hud.new()
	_vp.add_child(_hud)
	_prep = PREP


## The theft made due (its gate reached, the remembered mechanics' gates met) and stepped until the card is held, then
## three hits on its back.
func _into() -> void:
	var fs := _world.boss_fight
	fs.fl_gates = 3
	fs.fl_open = _world.tick
	fs.fl_next = _world.tick + 1000000
	var i := FinalLab.body(_world)
	_world.actors.hp[i] = _world.actors.max_hp[i] * 650 / 1000
	for k in 900:
		if not fs.fl_tk_code.is_empty():
			break
		_step(1)
	i = FinalLab.body(_world)
	var pid := _world.actors.ids[0]
	for k in 3:
		var at := _world.actors.pos(i)
		var from := at - Kin.dir(_world.actors.facing[i]) * 2.0
		Damage.hit(_world, i, 1, pid, pid, _world.take_root(), 0, from, at)
	_step(2)
	_wait = SETTLE


func _step(n: int) -> void:
	for k in n:
		_world.actors.set_pos(0, _hero)
		_world.actors.hp[0] = _world.actors.max_hp[0]
		_world.step(InputFrame.new())
		_root.sync()
		_hud.sync(_reader)


func _process(_delta: float) -> bool:
	if _wait < 0:
		_wait = 0
		_begin()
		return false
	if _prep > 0:
		_prep -= 1
		_hud.sync(_reader)
		if _prep == 0:
			_into()
		return false
	if _wait > 0:
		_wait -= 1
		_hud.sync(_reader)
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "a_theft.png"
	img.save_png(path)
	var st := _reader.boss_fallen()
	print(
		"fallen_theft: ",
		ProjectSettings.globalize_path(path),
		(
			"  tick %d taken %s dark %s mark %s pips %d"
			% [
				_world.tick,
				st.get("taken", []),
				_hud.theft_hud.dark_slots(),
				_root.fallen_remembered.mark.shown(),
				_root.fallen_remembered.mark.pips(),
			]
		)
	)
	quit(0)
	return true
