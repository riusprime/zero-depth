extends SceneTree
## v0.11.0 O13a: the five biome variants for the owner (ENEMIES.md V1-V5), each in the real game view (WorldViewRoot
## with its biome's mood, look and enemy cast; ActorViews, VariantViews, FireballViews, HordeVisuals) of a real World,
## at the moment its twist shows. Run on a renderer, off screen:
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000
##     -s scripts/shots/o13a_variants.gd
## Writes build/shots/<version>/o13a/<id>.png (one per variant) and prints each path. Cells:
## - rubble_warden: one in its crust (full HP) and one whose crust fell at half HP (a rubble patch, the dust);
## `-- only=<id>` shoots just that cell.
## - dim_needle: its burst in flight, the far shots dark, the near ones lit;
## - ember_charger / frost_charger: just after a charge, its fire trail / ice slick behind it;
## - split_sniper: the frame its shot fires (the line and its three branches, the spark at the split).

const CELL := Vector2i(800, 560)
const HERO_AT := Vector2(0.0, -6.0)
## [id, biome, kind, enemy at, wait (the condition _ready_now checks)].
const PLAN := [
	["rubble_warden", &"ruins", ActorStore.Kind.RUBBLE_WARDEN, Vector2(-1.6, 0.5), &"crust"],
	["dim_needle", &"night_rocks", ActorStore.Kind.DIM_NEEDLE, Vector2(0.0, 3.0), &"shots"],
	["ember_charger", &"red_canyon", ActorStore.Kind.EMBER_CHARGER, Vector2(0.0, 1.5), &"charged"],
	[
		"frost_charger",
		&"frozen_shore",
		ActorStore.Kind.FROST_CHARGER,
		Vector2(0.0, 1.5),
		&"charged"
	],
	["split_sniper", &"starfall", ActorStore.Kind.SPLIT_SNIPER, Vector2(0.0, 5.0), &"fired"],
]

var _dir := ""
var _vp: SubViewport
var _repo: ContentRepository
var _world: World
var _view: WorldViewRoot
var _id := -1
var _settle := -1.0
var _acc := 0.0
var _k := 0
var _t := 0
var _seen := -1
var _only := false


func _initialize() -> void:
	_dir = "res://build/shots/%s/o13a/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			for j in PLAN.size():
				if PLAN[j][0] == arg.substr(5):
					_k = j
					_only = true
	_build(_k)


func _build(k: int) -> void:
	if _view != null:
		_view.queue_free()
	var spec: Array = PLAN[k]
	_world = StageScenario.build(
		31 + k, PlayerTable.starting_values(), ContentCompiler.compile_enemies(_repo)
	)
	_world.actors.set_pos(0, HERO_AT)
	_world.actors.invuln[0] = 1 << 24
	_id = _world.add_enemy(spec[2], spec[3])
	if spec[2] == ActorStore.Kind.RUBBLE_WARDEN:  # a second one whose crust will fall
		var b := _world.add_enemy(spec[2], spec[3] + Vector2(3.4, 0.0))
		var bi := _world.actors.index_of(b)
		_world.actors.hp[bi] = _world.actors.max_hp[bi] * 2 / 5
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
	_seen = -1


func _ready_now(wait: StringName) -> bool:
	var i := _world.actors.index_of(_id)
	var a := _world.actors
	match wait:
		&"crust":
			return _t >= 40
		&"shots":
			for j in _world.projectiles.size():
				if _world.projectiles.team[j] == ActorStore.TEAM_ENEMY:
					_seen = _t if _seen < 0 else _seen
			return _seen >= 0 and _t - _seen >= 26
		&"charged":
			if i >= 0 and a.state[i] == EnemyAi.State.RECOVER:
				_seen = _t if _seen < 0 else _seen
			return _seen >= 0 and _t - _seen >= 8
		&"fired":
			return i >= 0 and a.state[i] == EnemyAi.State.ACTIVE
	return false


func _process(delta: float) -> bool:
	var spec: Array = PLAN[_k]
	if _settle < 0.0:
		if _ready_now(spec[4]):
			_settle = 0.03 if spec[4] == &"fired" else 1.2  # (real seconds: the bodies' frame-time poses)
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
			print("o13a: %s never got ready" % spec[0])
			_settle = 0.01
		return false
	_settle -= delta
	if _settle > 0.0:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path: String = _dir + "%s.png" % spec[0]
	img.save_png(path)
	print("o13a: ", ProjectSettings.globalize_path(path))
	_k += 1
	if _only or _k == PLAN.size():
		return true
	_build(_k)
	return false
