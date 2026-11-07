extends SceneTree
## v0.11.0 O13c: the Red Canyon's and the Frozen Shore's signature enemies for the owner (ENEMIES.md R5-R8), each in
## the real game view (WorldViewRoot with its biome's mood and look; ActorViews, CanyonShoreViews, VariantViews) of a
## real World, at the moment its tell shows. Run on a renderer, off screen:
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000
##     -s scripts/shots/o13c_signatures.gd
## Writes build/shots/<version>/o13c/<id>.png (one per enemy) and prints each path. Cells:
## - kiln_beetle: one at a fifth of its HP glowing hot, and one just killed: its burst's circle filling;
## - cinder_priest: its vent's pulse near its end (the eruption next), the staff raised;
## - frost_spitter: its blob in the air on the blue arc, the landing ring;
## - glacier_turtle: one facing the hero behind its ice shell, and one whose shell just broke: its chunks sliding.

const CELL := Vector2i(800, 560)
const HERO_AT := Vector2(0.0, -6.0)
## [id, biome, kind, enemy at, wait (the condition _ready_now checks)].
const PLAN := [
	["kiln_beetle", &"red_canyon", ActorStore.Kind.KILN_BEETLE, Vector2(-1.6, 0.5), &"burst"],
	["cinder_priest", &"red_canyon", ActorStore.Kind.CINDER_PRIEST, Vector2(0.0, 0.5), &"pulse"],
	["frost_spitter", &"frozen_shore", ActorStore.Kind.FROST_SPITTER, Vector2(0.0, 1.5), &"blob"],
	[
		"glacier_turtle",
		&"frozen_shore",
		ActorStore.Kind.GLACIER_TURTLE,
		Vector2(-1.6, 0.5),
		&"chunks"
	],
]

var _dir := ""
var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _id := -1
var _second := -1
var _settle := -1.0
var _acc := 0.0
var _k := 0
var _t := 0


func _initialize() -> void:
	_dir = "res://build/shots/%s/o13c/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_build(0)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	_world = StageScenario.build(
		41 + k, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_world.actors.set_pos(0, HERO_AT)
	_world.actors.invuln[0] = 1 << 24
	_id = _world.add_enemy(spec[2], spec[3])
	_second = -1
	if spec[4] == &"burst" or spec[4] == &"chunks":  # a second one: killed / its shell broken
		_second = _world.add_enemy(spec[2], spec[3] + Vector2(3.4, 0.0))
	if spec[4] == &"burst":  # the first one hot: a fifth of its HP left
		var i := _world.actors.index_of(_id)
		_world.actors.hp[i] = _world.actors.max_hp[i] / 5
	var biome: BiomeDefinition = _repo.get_def(&"biomes", spec[1])
	_view = WorldViewRoot.new()
	_view.stage.prop_style = biome.id
	_view.stage.mood = biome.mood
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_vp.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.actors.cull = null  # (the off-screen rig never marks the bodies seen: animate them by distance)
	_view.rig.view_size = 10.0
	_view.rig.camera.size = 10.0
	_view.rig.snap_to(SimPlane.to_3d((HERO_AT + (spec[3] as Vector2)) * 0.5))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_settle = -1.0
	_t = 0


func _ready_now(wait: StringName) -> bool:
	var s := _world.canyon_shore
	match wait:
		&"burst":
			if _t == 40:
				_hit(_second, 99999, true)
			return s.burst_count() > 0 and _world.tick - s.burst_born[0] >= 36
		&"pulse":
			var k := s.vent_of(_id)
			return k >= 0 and CanyonShore.vent_pulse(_world, k) >= 750
		&"blob":
			return s.blob_count() > 0 and s.blob_land[0] - _world.tick <= 22
		&"chunks":
			if _t == 40:
				var t := _world.enemy_table(ActorStore.Kind.GLACIER_TURTLE)
				_hit(_second, t.shell_hp, false)
			return _t >= 40 and s.chunk_count() > 0 and _world.tick - s.chunk_born[0] >= 7
	return false


## Hits actor `id` for `amount`: from its own spot (`own`), or from the hero's side (its front: the shell).
func _hit(id: int, amount: int, own: bool) -> void:
	var i := _world.actors.index_of(id)
	if i < 0:
		return
	var at := _world.actors.pos(i)
	var from := at if own else at + (HERO_AT - at).normalized()
	var hero := _world.actors.ids[0]
	Damage.hit(_world, i, amount, hero, hero, _world.take_root(), 0, from, at)


func _process(delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _settle < 0.0:
		if _ready_now(spec[4]):
			_settle = 0.03
			return false
		_acc += delta  # one sim tick per 1/60 s of real time, so the frame-time animation keeps up
		if _acc < 1.0 / 60.0:
			return false
		_acc -= 1.0 / 60.0
		_world.actors.set_pos(0, HERO_AT)
		_world.actors.hp[0] = _world.actors.max_hp[0]
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, 0))
		_t += 1
		_view.sync()
		if _t > 1200:
			print("o13c: %s never got ready" % spec[0])
			_settle = 0.01
		return false
	_settle -= delta
	if _settle > 0.0:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path: String = _dir + "%s.png" % spec[0]
	img.save_png(path)
	print("o13c: ", ProjectSettings.globalize_path(path))
	_k += 1
	if _k == PLAN.size():
		return true
	_build(_k)
	return false
