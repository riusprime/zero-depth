extends SceneTree
## Stills of each biome's own enemy versions (EnemyPalettes.VERSIONS) beside their bases, in the biome's real game
## view (WorldViewRoot: its mood, floor and cast). Nothing here changes the game.
##   shot=close: the base and its version side by side, the camera zoomed in, both facing the camera;
##   shot=game: a small mixed group around the hero at the game's camera size, as a player sees it.
## The enemies are added to a world that is never stepped, so each is set out of its spawn-in state by hand (a horde
## body rises out of the floor only after it: left spawning, it is drawn sunk under the ground).
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000
##     -s scripts/shots/enemy_versions.gd -- biome=red_canyon shot=close tag=new [out=<absolute dir>]
## Writes <out>/<biome>_<shot>_<tag>.png (default out: build/enemy_versions/).

const CELL := Vector2i(1600, 900)
const CLOSE_SIZE := 3.2
const CLOSE_SPACING := 1.5
## The pairs: the base and its biome version, per biome.
const PAIRS := {
	&"red_canyon": [ActorStore.Kind.CHARGER, ActorStore.Kind.EMBER_CHARGER],
	&"frozen_shore": [ActorStore.Kind.CHARGER, ActorStore.Kind.FROST_CHARGER],
	&"starfall": [ActorStore.Kind.SNIPER, ActorStore.Kind.SPLIT_SNIPER],
	&"night_rocks": [ActorStore.Kind.NEEDLE, ActorStore.Kind.DIM_NEEDLE],
	&"ruins": [ActorStore.Kind.WARDEN, ActorStore.Kind.RUBBLE_WARDEN],
}
## The game still's group around the hero: [kind, sim offset from the hero (m)]; the version twice, its base twice
## (once where the biome has it in its roster), the shared core and the biome's signatures.
const GROUPS := {
	&"red_canyon":
	[
		[ActorStore.Kind.CHARGER, Vector2(-4.0, 1.5)],
		[ActorStore.Kind.EMBER_CHARGER, Vector2(-2.5, 3.2)],
		[ActorStore.Kind.EMBER_CHARGER, Vector2(2.2, 0.2)],
		[ActorStore.Kind.CHARGER, Vector2(4.2, -1.0)],
		[ActorStore.Kind.NEEDLE, Vector2(0.6, 4.4)],
		[ActorStore.Kind.SWARMER, Vector2(-3.8, -2.4)],
		[ActorStore.Kind.CINDER_PRIEST, Vector2(1.5, -4.0)],
		[ActorStore.Kind.KILN_BEETLE, Vector2(-1.2, -4.4)],
	],
	&"frozen_shore":
	[
		[ActorStore.Kind.CHARGER, Vector2(-4.0, 1.5)],
		[ActorStore.Kind.FROST_CHARGER, Vector2(-2.5, 3.2)],
		[ActorStore.Kind.FROST_CHARGER, Vector2(2.2, 0.2)],
		[ActorStore.Kind.CHARGER, Vector2(4.2, -1.0)],
		[ActorStore.Kind.NEEDLE, Vector2(0.6, 4.4)],
		[ActorStore.Kind.SWARMER, Vector2(-3.8, -2.4)],
		[ActorStore.Kind.FROST_SPITTER, Vector2(1.5, -4.0)],
		[ActorStore.Kind.GLACIER_TURTLE, Vector2(-1.2, -4.4)],
	],
	&"starfall":
	[
		[ActorStore.Kind.SNIPER, Vector2(-4.0, 1.5)],
		[ActorStore.Kind.SPLIT_SNIPER, Vector2(-2.5, 3.2)],
		[ActorStore.Kind.SPLIT_SNIPER, Vector2(2.2, 0.2)],
		[ActorStore.Kind.CHARGER, Vector2(4.2, -1.0)],
		[ActorStore.Kind.NEEDLE, Vector2(0.6, 4.4)],
		[ActorStore.Kind.SWARMER, Vector2(-3.8, -2.4)],
		[ActorStore.Kind.STAR_WARPER, Vector2(1.5, -4.0)],
		[ActorStore.Kind.WARDEN, Vector2(-1.2, -4.4)],
	],
	&"night_rocks":
	[
		[ActorStore.Kind.NEEDLE, Vector2(-4.0, 1.5)],
		[ActorStore.Kind.DIM_NEEDLE, Vector2(-2.5, 3.2)],
		[ActorStore.Kind.DIM_NEEDLE, Vector2(2.2, 0.2)],
		[ActorStore.Kind.NEEDLE, Vector2(4.2, -1.0)],
		[ActorStore.Kind.CHARGER, Vector2(0.6, 4.4)],
		[ActorStore.Kind.SWARMER, Vector2(-3.8, -2.4)],
		[ActorStore.Kind.STONE_THROWER, Vector2(1.5, -4.0)],
		[ActorStore.Kind.ROCK_LURKER, Vector2(-1.2, -4.4)],
	],
	&"ruins":
	[
		[ActorStore.Kind.WARDEN, Vector2(-4.0, 1.5)],
		[ActorStore.Kind.RUBBLE_WARDEN, Vector2(-2.5, 3.6)],
		[ActorStore.Kind.RUBBLE_WARDEN, Vector2(2.2, 0.2)],
		[ActorStore.Kind.CHARGER, Vector2(4.2, -1.0)],
		[ActorStore.Kind.NEEDLE, Vector2(0.6, 4.4)],
		[ActorStore.Kind.SWARMER, Vector2(-3.8, -2.4)],
		[ActorStore.Kind.SCRAP_HOUND, Vector2(1.5, -4.0)],
		[ActorStore.Kind.WIRE_WEAVER, Vector2(-1.2, -4.4)],
	],
}

var _out := ""
var _vp: SubViewport
var _view: WorldViewRoot
var _world: World
var _biome_id: StringName = &"red_canyon"
var _shot: StringName = &"close"
var _tag := "new"
var _ids: Array[int] = []
var _t := 0
var _settle := 0.0
var _hero_at := Vector2.ZERO
var _look_at := Vector2.ZERO


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_biome_id = StringName(args.get("biome", _biome_id))
	_shot = StringName(args.get("shot", _shot))
	_tag = String(args.get("tag", _tag))
	_out = String(args.get("out", ProjectSettings.globalize_path("res://build/enemy_versions/")))
	if not _out.ends_with("/"):
		_out += "/"
	DirAccess.make_dir_recursive_absolute(_out)
	var repo := ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_world = StageScenario.build(
		31, PlayerTable.starting_values(), ContentCompiler.compile_enemies(repo)
	)
	_world.actors.invuln[0] = 1 << 24
	var biome: BiomeDefinition = repo.get_def(&"biomes", _biome_id)
	_view = WorldViewRoot.new()
	_view.stage.prop_style = biome.id
	_view.stage.mood = biome.mood
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_vp.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.actors.cull = null
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	if _shot == &"close":
		_view.rig.view_size = CLOSE_SIZE
		_view.rig.camera.size = CLOSE_SIZE
	else:
		_view.rig.camera.size = _view.rig.view_size


## The actors' places: the close pair across the screen with the hero off screen toward the camera (so both face it),
## or the group around the hero in the middle.
func _place() -> void:
	var bx := _view.rig.camera.global_transform.basis.x
	var bz := _view.rig.camera.global_transform.basis.z
	var right := Vector2(bx.x, -bx.z).normalized()
	var toward := Vector2(bz.x, -bz.z).normalized()
	if _shot == &"close":
		_hero_at = (toward - right * 0.8) * 30.0  # (three-quarter: the side and the back show too)
		_look_at = Vector2.ZERO
		var pair: Array = PAIRS[_biome_id]
		for k in pair.size():
			var at := right * ((k - (pair.size() - 1) * 0.5) * CLOSE_SPACING)
			_ids.append(_world.add_enemy(pair[k], at))
		var glow := StageKit.hero_light(_view.stage.mood)  # (the hero is off screen: its light over the pair)
		if glow != null:
			glow.position = SimPlane.to_3d(toward * 1.2) + Vector3(0, 1.2, 0)
			glow.omni_range = 7.0
			_view.add_child(glow)
	else:
		_hero_at = Vector2.ZERO
		_look_at = Vector2.ZERO
		for e: Array in GROUPS[_biome_id]:
			_ids.append(_world.add_enemy(e[0], e[1]))
	_world.actors.set_pos(0, _hero_at)
	for id in _ids:  # (add_enemy faced them at the hero's place before it moved)
		var i := _world.actors.index_of(id)
		_world.actors.facing[i] = Kin.angle_of(_hero_at - _world.actors.pos(i))
	_view.rig.snap_to(SimPlane.to_3d(_look_at))


func _process(delta: float) -> bool:
	_t += 1
	if _t == 1:
		_place()
	for id in _ids:  # Out of the spawn-in: standing, not acting
		var i := _world.actors.index_of(id)
		if i >= 0:
			_world.actors.state[i] = EnemyAi.State.MOVE
			_world.actors.state_t[i] = 600
			_world.actors.invuln[i] = 0
	_world.actors.set_pos(0, _hero_at)
	_view.sync()
	_view.rig.snap_to(SimPlane.to_3d(_look_at))
	if _t < 90:
		return false
	_settle += delta
	if _settle < 0.8:
		return false
	var drawn := 0
	for id in _ids:
		if _view.actors.actor_node(id) != null:
			drawn += 1
	print("enemy_versions: %d of %d enemies have a view" % [drawn, _ids.size()])
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path := _out + "%s_%s_%s.png" % [_biome_id, _shot, _tag]
	img.save_png(path)
	print("enemy_versions: ", path)
	return true
