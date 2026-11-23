extends SceneTree
## Renders The Fallen remembering each boss for the owner, in the real game view (WorldViewRoot and the HUD over the
## final arena, the iso camera) of a real World stepped tick by tick (FallenLab: The Fallen fighting, no source boss in
## the room):
##   a_time.png     the Time Wave's cast: the Clockwork Judge's gold ghost rising over The Fallen, its pillar of light;
##   b_riptide.png  the Riptide running: the four strips inside the round floor, the dry one marked, a wall of water;
##   c_quake.png    the quake pillars standing, The Fallen's dash line aimed through one, white-hot where it meets it;
##   d_ward.png     the ward on The Fallen, the amber Warden's shade winding its charge up across it (the lane
##                  white-hot), the end circle.
## Needs a renderer (no --headless); run it off screen:
##   godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/fallen_remembered.gd
## Writes build/shots/<version>/fallen_remembered/ and prints each path with what the sim held at that moment.

const SIZE := Vector2i(1600, 900)
const SETTLE := 14
const PREP := 8
const SEED := 811
const KINDS := [1, 2, 3, 4]  # BossRemembered.TIME, RIPTIDE, QUAKE, WARD
const FILES := ["a_time.png", "b_riptide.png", "c_quake.png", "d_ward.png"]

var _vp: SubViewport
var _world: World
var _view: FallenRig
var _stage := 0
var _wait := 0
var _prep := 0
var _dir := ""
var _hero := Vector2.ZERO


func _initialize() -> void:
	_dir = "res://build/shots/%s/fallen_remembered/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	TranslationServer.set_locale("en")
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_wait = -1  # The first fight is built on the first frame, once the viewport is in the tree


## A fresh fight for mechanic `k` of KINDS, the view over it.
func _begin(k: int) -> void:
	var kind: int = KINDS[k]
	_world = FallenLab.world(SEED, &"blade", [BossRemembered.SOURCES[kind]], true)
	var home := _world.final_fight.home
	var i := FallenLab.body(_world)
	_hero = home + Vector2(4.0, -3.0)
	_world.actors.set_pos(0, _hero)
	if kind == BossRemembered.WARD:
		_world.actors.set_pos(i, home + Vector2(0.0, 5.0))
		_hero = home + Vector2(4.0, 0.0)
	_world.step(InputFrame.new())
	if _view != null:
		_view.free_all()
	_view = FallenRig.new(_vp, _world)
	_prep = PREP  # A few frames first: the floor's pack warm-up gives its effects back


## Mechanic `k` of KINDS made due and stepped to the moment its shot shows.
func _into(k: int) -> void:
	var kind: int = KINDS[k]
	var i := FallenLab.body(_world)
	FallenLab.due(_world, kind)
	_until_stage(BossRemembered.STAGE_CAST, 300)
	match kind:
		BossRemembered.TIME:
			_step(60)  # two thirds into the cast
		BossRemembered.RIPTIDE:
			_until_stage(BossRemembered.STAGE_RUN, 200)
			_until_wave(400)
			_step(14)
		BossRemembered.QUAKE:
			_until_stage(BossRemembered.STAGE_RUN, 200)
			_step(30)
			_aim_through_pillar(i)
		BossRemembered.WARD:
			_until_stage(BossRemembered.STAGE_RUN, 200)
			var sh: Dictionary = _view.reader.boss_fallen()["shade"]
			var line := (_world.actors.pos(i) - Vector2(sh["position"])).normalized()
			_hero = _world.actors.pos(i) + line * 4.0
			_step(70)
	_wait = SETTLE


## The hero across a pillar from The Fallen, and its dash made due: the line shows through the pillar.
func _aim_through_pillar(i: int) -> void:
	var mine := BossQuake.pillars_of(_world, _world.actors.ids[i])
	if mine.is_empty():
		return
	var q := BossAi.table_of(_world, i).quake
	var c := BossQuake.center(_world.bosses, mine[0])
	var way := (c - _world.final_fight.home).normalized()
	if way == Vector2.ZERO:
		way = Vector2.RIGHT
	_world.actors.set_pos(i, c - way * (q.half_m + _world.actors.radius[i] + 2.5))
	_hero = c + way * (q.half_m + _world.player.radius_m + 1.5)
	_world.boss_fight.fl_dash_at = _world.tick
	for k in 60:
		_step(1)
		if not (_view.reader.boss_fallen().get("pillar_dash", {}) as Dictionary).is_empty():
			_step(8)
			return


func _until_stage(stage: int, limit: int) -> void:
	for k in limit:
		if _world.boss_fight.fl_stage == stage:
			return
		_step(1)


func _until_wave(limit: int) -> void:
	for k in limit:
		var rip: Dictionary = _view.reader.boss_dance().get("riptide", {})
		if not rip.is_empty() and int(rip["wave"]) >= 0:
			return
		_step(1)


func _step(n: int) -> void:
	for k in n:
		_world.actors.set_pos(0, _hero)
		_world.actors.hp[0] = _world.actors.max_hp[0]
		_world.step(InputFrame.new())
		_view.frame()


func _save(file: String, note: String) -> void:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := _dir + file
	img.save_png(path)
	print("fallen_remembered: ", ProjectSettings.globalize_path(path), "  ", note)


func _process(_delta: float) -> bool:
	if _wait < 0:
		_wait = 0
		_begin(0)
		return false
	if _prep > 0:
		_prep -= 1
		_view.frame(false)
		if _prep == 0:
			_into(_stage)
		return false
	if _wait > 0:
		_wait -= 1
		_view.frame(false)
		return false
	var st := _view.reader.boss_fallen()
	var v := _view.root
	_save(
		FILES[_stage],
		(
			(
				"tick %d stage %d source %s cast %d emblem %s aura %s orbs %d strips %d pillars %d line %s hot %s"
				+ " ward %s shade %s lane_hot %s circles %d held %d"
			)
			% [
				_world.tick,
				int(st.get("stage", -1)),
				st.get("source", &""),
				int(st.get("cast", -1)),
				v.fallen_remembered.emblem_shown(),
				v.fallen_remembered.aura_shown(),
				v.judge_time.orbs_shown(),
				v.tide_dance.strips_shown(),
				v.spikes.quake_count(),
				v.fallen_remembered.line_shown(),
				v.fallen_remembered.line_hot(),
				v.warden_wards.full_shown(),
				v.fallen_remembered.shade_shown(),
				v.warden_wards.lane_breaks(),
				v.charge_bursts.shown(),
				v.fallen_remembered.hold.count(),
			]
		)
	)
	_stage += 1
	if _stage >= KINDS.size():
		quit(0)
		return true
	_begin(_stage)
	return false


## The game view and HUD over one World (rebuilt for each fight), in the final arena's own look.
class FallenRig:
	extends RefCounted
	var root: WorldViewRoot
	var hud: Hud
	var reader: WorldReader

	func _init(vp: SubViewport, w: World) -> void:
		var repo := ContentRepository.load_all()
		reader = WorldReader.new(w)
		root = WorldViewRoot.new()
		vp.add_child(root)
		var arena: BiomeDefinition = repo.get_def(&"final_arena", &"hollow_arena")
		root.stage.mood = arena.mood
		root.stage.prop_style = arena.id
		root.stage.look = arena.look
		root.setup(reader, arena.palette, reader.final_arena_radius() + 4.0)
		root.rig.view_size = 30.0
		root.rig.camera.size = 30.0
		root.rig.snap_to(SimPlane.to_3d(w.final_fight.home))
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
