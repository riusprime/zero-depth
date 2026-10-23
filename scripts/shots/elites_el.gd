extends SceneTree
## v0.9.0 EL: one elite archetype mid-telegraph in the real game view (WorldViewRoot on the floor's biome stage, the
## iso camera) of a real World (SaveLab's floor 4 of run seed SEED, as Main builds it): the elite spawned (the dev
## route's Elites.spawn) a few metres from the hero in the start hall, its ability due at once, stepped until its
## windup is its share through (KINDS) (the Breaker's circle filling, the Rift Hunter's mark locked, the Conduit's line
## locked), then one shot. A tool, not a test. Needs a renderer:
##   godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/elites_el.gd -- breaker
## (breaker | rift_hunter | conduit). Writes build/shots/v0.9.0/el/<archetype>.png.

const SIZE := Vector2i(1280, 720)
const CAMERA_M := 13.0
const OUT := "res://build/shots/v0.9.0/el/"
const SEED := 3
const FLOOR := 4
## [kind, where it spawns from the hero, how far through its windup the shot is] (the Rift Hunter before its vanish:
## mark locked, body still there).
const KINDS := {
	"breaker": [ActorStore.Kind.BREAKER, Vector2(2.6, 1.2), 0.75],
	"rift_hunter": [ActorStore.Kind.RIFT_HUNTER, Vector2(4.5, 1.5), 0.62],
	"conduit": [ActorStore.Kind.CONDUIT, Vector2(7.0, 2.0), 0.75],
}

var _vp: SubViewport
var _world: World
var _view: WorldViewRoot
var _frames := 0
var _name := "breaker"
var _id := -1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and KINDS.has(args[0]):
		_name = args[0]
	print("elites_el: %s renderer=%s" % [_name, RenderingServer.get_current_rendering_method()])
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_world = SaveLab.floor_world(SEED, FLOOR)
	LockLab.calm(_world)
	_world.spawner = null  # the shot shows the elite alone (no horde arrives)
	var spec: Array = KINDS[_name]
	var hero := _world.player_pos()
	_id = Elites.spawn(_world, spec[0], hero + spec[1], Elites.Source.DEV)
	var i := _world.actors.index_of(_id)
	_world.actors.cd[i] = 0
	_world.actors.fire_cd[i] = 1 << 20
	var e := EliteAi.table_of(_world, i)
	for k in 600:
		_world.actors.set_pos(0, hero)
		_world.step(InputFrame.new())
		i = _world.actors.index_of(_id)
		var a := _world.actors
		if (
			a.state[i] == EnemyAi.State.WINDUP
			and a.state_t[i] >= int(e.windup_ticks * float(spec[2]))
		):
			break
	var reader := WorldReader.new(_world)
	var repo := ContentRepository.load_all()
	var run := SaveLab.run_state(SEED, FLOOR)
	var rd: RunDefinition = repo.get_def(&"run", run.table.id)
	var biome: BiomeDefinition = repo.get_def(&"biomes", rd.biomes[run.biome_of()])
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_vp.add_child(_view)
	_view.setup(reader, biome.palette, 60.0)
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	_view.rig.view_size = CAMERA_M
	_view.rig.camera.size = CAMERA_M
	_view.rig.snap_to(SimPlane.to_3d((hero + _world.actors.pos(i)) * 0.5))
	var tg := reader.telegraph(i)
	print(
		(
			"elites_el: %s biome=%s state=%d state_t=%d windup=%d telegraph=%s locked=%s hp=%d"
			% [
				_name,
				biome.id,
				_world.actors.state[i],
				_world.actors.state_t[i],
				_world.actors.windup[i],
				tg.get("shape", &""),
				tg.get("locked", false),
				_world.actors.hp[i]
			]
		)
	)


func _process(_delta: float) -> bool:
	if _view == null:
		return true
	_frames += 1
	_view.sync()
	if _frames < 40:
		return false
	var path := OUT + _name + ".png"
	_vp.get_texture().get_image().save_png(path)
	print("elites_el: ", path)
	return true
