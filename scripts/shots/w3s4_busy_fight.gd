extends SceneTree
## v0.10.5 W3-S4 (owner F5, F8, F10): a busy fight for the before/after pair: the Gun with Seekers, Split Shot, Fire,
## Bleed and Chain Blast shooting into a crowd of dummies (some die and leave Fire's patches), in the real game view
## (WorldViewRoot on the Ruins stage with its mood: the effects layer and the pack; the iso camera), the pattern of
## glaive_seekers.gd.
## Needs a renderer (no --headless), off screen:
##   godot --path . --audio-driver Dummy --resolution 1280x720 --position -10000,-10000 \
##     -s scripts/shots/w3s4_busy_fight.gd
## Writes build/shots/<version>/w3s4/<n>_<label>.jpg and prints each path with the effect counts.

## [label, cards (wand order), camera size, ticks of Shoot held, ticks let go after, frames to settle].
const PLAN := [
	[
		"busy_fight",
		[&"gun_seekers", &"split_shot", &"ember_core", &"shared_bleed", &"chain_blast"],
		10.0,
		150,
		0,
		2
	],
]
const SIZE := Vector2i(1280, 720)
const DUMMY_HP := 24
## A crowd on the aim's side.
const DUMMIES: Array[Vector2] = [
	Vector2(2.5, 0.2),
	Vector2(3.5, -1.2),
	Vector2(3.6, 1.3),
	Vector2(4.5, -0.2),
	Vector2(5.0, 2.2),
	Vector2(5.2, -2.4),
	Vector2(5.8, 0.9),
	Vector2(6.5, -1.0),
	Vector2(7.0, 1.9),
	Vector2(7.4, -2.6),
	Vector2(8.0, 0.2),
	Vector2(8.6, -1.4),
]
var _repo: ContentRepository
var _tables: Array[ItemTable] = []
var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _reader: WorldReader
var _k := 0
var _ticks := 0
var _settle := -1
var _dir := ""
var _aim := 0


func _initialize() -> void:
	_dir = "res://build/shots/v0.10.5/w3s4/"
	ViewPrefs.effects_density = "high"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_tables = ContentCompiler.compile_items(_repo)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build(0)


func _item(id: StringName) -> int:
	for k in _tables.size():
		if _tables[k].id == id:
			return k
	return -1


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	t.crit_chance_permille = 0
	_world = StageScenario.build(9, t, ContentCompiler.compile_enemies(_repo))
	_world.set_item_tables(_tables)
	for id: StringName in spec[1]:
		_world.add_item(_item(id))
	_world.dummy_speed = 0.0
	_world.actors.set_pos(0, Vector2.ZERO)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	_aim = _open_aim()
	for d in DUMMIES:
		var at := d.rotated(TAU * _aim / 4096.0)
		_world.add_dummy(at, 0.35, DUMMY_HP)
	_reader = WorldReader.new(_world)
	_view = WorldViewRoot.new()
	_vp.add_child(_view)
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	_view.stage.mood = biome.mood  # the effects layer and the pack, as in a run
	_view.stage.prop_style = biome.id
	_view.setup(_reader, biome.palette, 14.0)
	_view.rig.view_size = spec[2]
	_view.rig.camera.size = spec[2]
	_view.rig.snap_to(SimPlane.to_3d(Vector2(4.5, 0.0).rotated(TAU * _aim / 4096.0)))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_ticks = 0
	_settle = -1


## The first of 16 aims (1/4096 turns) whose line from the hero is clear of walls for 9 m, 1.5 m wide.
func _open_aim() -> int:
	var p := _world.player_pos()
	for k in 16:
		var to := p + Kin.dir(k * 256) * 9.0
		var blocked := false
		for i in _world.walls_along(p, to, 1.5):
			if Collide.sweep_vs_obb(p, to, 1.5, _world.walls[i]) >= 0.0:
				blocked = true
				break
		if not blocked:
			return k * 256
	return 0


func _process(_delta: float) -> bool:
	var spec: Array = PLAN[_k]
	var held_n := int(spec[3])
	if _settle < 0:
		var held := InputFrame.SHOOT if _ticks < held_n else 0
		var pressed := InputFrame.SHOOT if _ticks == 0 else 0
		_world.step(InputFrame.make(Vector2i.ZERO, _aim, 500, held, pressed))
		_view.sync()
		_ticks += 1
		if _ticks >= held_n + int(spec[4]):
			_settle = 0
		return false
	_settle += 1
	if _settle < int(spec[5]):
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + "%d_%s.jpg" % [_k + 1, spec[0]]
	img.save_jpg(path, 0.88)
	var forms := _view.attack_forms
	print(
		"w3s4_busy_fight: ",
		path,
		" (tick ",
		_ticks,
		", fire patches in the sim ",
		_world.ab.fire_pos.size(),
		", blasts drawn ",
		_blast_count(forms, "drawn"),
		" pops ",
		_blast_count(forms, "pops"),
		" merged ",
		_blast_count(forms, "merged"),
		" skipped ",
		_blast_count(forms, "skipped"),
		")"
	)
	_k += 1
	if _k >= PLAN.size():
		return true
	_build(_k)
	return false


## A BlastLook count (the "before" tree has none: -1).
func _blast_count(forms: Object, what: String) -> int:
	var b: Variant = forms.get(&"blasts")
	return int((b as Object).get(what)) if b != null else -1
