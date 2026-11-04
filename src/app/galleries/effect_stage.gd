class_name EffectStage
extends SubViewportContainer
## v0.10.5 W3-O12 (docs/roadmap/v0.10.5/W3_O12_VFX_GALLERY.md): one Effects gallery entry (EffectsCatalog) playing
## live and looping in a small lit stage: its own World (PlaygroundScenario's room, the Ruins) drawn by the real game
## view (WorldViewRoot) in its own SubViewport.
## - A sim entry: the stage drives its World like a player and the Playground would (EffectsCatalog's recipe: the
##   build, a card or ability, the buttons, the targets; the hero can't be hurt). Its views draw what the sim does.
## - A pack entry: the effect's scene through a PackFx of its own (the game's table for a used row, so its colours and
##   scale are the game's; a one-row-per-scene table for an unused one), beside the idle hero for scale. Flying
##   families cross the stage, held ones loop where they stand, the rest play again every LOOP_S.
## Only this tool's own World is driven (input frames, its setup); the views read it (EI-07).

const TICK_S := 1.0 / 60.0
## Seconds between two plays of a pack effect; a flying one crosses in FLY_S of it.
const LOOP_S := 2.0
const FLY_S := 1.2
const FLY_M := 5.0
## A sim entry: Shoot held this many ticks, then let go for SHOOT_GAP (charged forms release).
const SHOOT_HOLD := 100
const SHOOT_GAP := 20
## Melee: a swing pressed every MELEE_EVERY ticks.
const MELEE_EVERY := 30
## The recipe's buttons are pressed every PRESS_EVERY ticks (held HOLD_TICKS for the held ones).
const PRESS_EVERY := 120
const HOLD_TICKS := 30
## The hero's targets: where, as offsets from the hero (m), and their HP (0: endless).
const DUMMY_AT: Array[Vector2] = [Vector2(3.4, 0.0), Vector2(3.0, 1.4), Vector2(3.0, -1.4)]
const DUMMY_HP: Array[int] = [0, 1500, 1500]
const ENEMY_AT := Vector2(3.6, 0.0)
const BOSS_AT: Array[Vector2] = [
	Vector2(4.5, 0.0), Vector2(3.5, 2.5), Vector2(0.0, 4.5), Vector2(-4.5, 0.0)
]
## Ticks before a gone target comes back.
const RESPAWN_TICKS := 45
## The camera's width (m): a hero or enemy, a boss, a pack effect.
const VIEW_M := {&"sim": 6.0, &"boss": 13.0, &"pack": 5.5}

var entry: Dictionary
var catalog: EffectsCatalog
var vp := SubViewport.new()
var world: World
var view: WorldViewRoot
var api: PlaygroundApi
var fx: PackFx
var ticks := 0
var caption: Label
## A pack entry: its plays so far, and the seconds into the current one.
var loops := 0
var loop_t := 0.0
var _home := Vector2.ZERO
var _node: Node3D
var _gone := 0
var _synced := -1


func _init(p_entry: Dictionary, p_catalog: EffectsCatalog, with_caption := false) -> void:
	entry = p_entry
	catalog = p_catalog
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(320, 240)
	add_child(vp)
	if with_caption:
		caption = Label.new()
		caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		caption.text = "%s\n%s" % [entry["title"], entry["source"]]
		caption.add_theme_font_size_override("font_size", 13)
		caption.add_theme_color_override("font_outline_color", Color.BLACK)
		caption.add_theme_constant_override("outline_size", 4)
		caption.set_anchors_preset(Control.PRESET_TOP_WIDE)
		caption.offset_left = 6
		caption.clip_text = true
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(caption)


func _ready() -> void:
	_build()


func _build() -> void:
	var r: Dictionary = entry.get("recipe", {})
	var build_id: StringName = r.get("build", &"gun")
	var cells := Vector2i(4, 4) if r.has("boss") else Vector2i(2, 2)
	world = PlaygroundScenario.build(catalog.repo, build_id, catalog.biome, cells, false)
	api = PlaygroundApi.new(world)
	api.god = true
	world.dummy_speed = 0.0
	_home = world.player_pos()
	_setup_sim(r)
	view = WorldViewRoot.new()
	var biome := catalog.biome
	view.stage.prop_style = biome.id
	view.stage.mood = biome.mood
	view.stage.look = biome.look
	if biome.look != null:
		view.actors.enemy_tint = biome.look.enemy_tint
	vp.add_child(view)
	view.setup(WorldReader.new(world), biome.palette, 12.0)
	var focus := _home + Vector2(1.7, 0.0)
	var width: float = VIEW_M[&"sim"]
	if entry["kind"] == &"pack":
		width = VIEW_M[&"pack"]
		focus = _home + Vector2(2.2, 0.0)
		fx = PackFx.new(entry["def"])
		fx.camera = view.rig.camera
		view.add_child(fx)
	elif r.has("boss"):
		width = VIEW_M[&"boss"]
		focus = _home + Vector2(2.2, 0.0)
	view.rig.view_size = width
	view.rig.camera.size = width
	view.rig.snap_to(SimPlane.to_3d(focus))
	view.rig.set_process(false)
	view.rig.camera.current = true
	view.sync()


## The recipe's card, ability, targets (only this stage's World, as the Playground's commands would).
func _setup_sim(r: Dictionary) -> void:
	if r.has("item"):
		for k in world.item_tables.size():
			if world.item_tables[k].id == r["item"]:
				if not api.grant_now(k, 1):
					world.add_item(k)
				break
	if r.has("ability"):
		for k in world.ability_tables.size():
			if world.ability_tables[k].id == r["ability"]:
				Abilities.grant(world, k)
				break
	_place_targets(r)


func _place_targets(r: Dictionary) -> void:
	if entry["kind"] == &"pack":
		return
	if r.get("target", &"") == &"dummies":
		for n in DUMMY_AT.size():
			if not _occupied(_home + DUMMY_AT[n]):
				api.place_dummy_now(_home + DUMMY_AT[n], DUMMY_HP[n])
	elif r.has("enemy"):
		api.place_enemy_now(r["enemy"], _home + ENEMY_AT)
	elif r.has("boss"):
		for at in BOSS_AT:
			if api.place_boss_now(r["boss"], _home + at):
				break
		var i := world.actors.size() - 1
		if r.get("late", false) and i > 0 and BossAi.is_boss_kind(world.actors.kinds[i]):
			var t := BossAi.table_of(world, i)
			if t != null and not t.phase_threshold.is_empty():
				var last: int = t.phase_threshold[t.phase_threshold.size() - 1]
				world.actors.hp[i] = maxi(1, world.actors.max_hp[i] * last / 1000 - 1)


func _occupied(at: Vector2) -> bool:
	for i in range(1, world.actors.size()):
		if world.actors.pos(i).distance_to(at) < 0.5:
			return true
	return false


func _targets_alive() -> int:
	return world.actors.size() - 1


func _physics_process(_delta: float) -> void:
	if world == null:
		return
	_step()


func _step() -> void:
	var r: Dictionary = entry.get("recipe", {})
	if int(r.get("heat", 0)) > 0 and world.heat != null:
		world.heat.milli = maxi(world.heat.milli, int(r["heat"]) * HeatTable.MILLI)
	if entry["kind"] != &"pack":
		var want := DUMMY_AT.size() if r.get("target", &"") == &"dummies" else 1
		if _targets_alive() < want:
			_gone += 1
			if _gone >= RESPAWN_TICKS:
				_gone = 0
				_place_targets(r)
	api.apply_pending()
	world.step(_frame(r))
	ticks += 1


## This tick's input: the attack (Shoot held in long presses, or a melee swing now and then), the recipe's buttons
## every PRESS_EVERY ticks, aimed at the first target, and a walk back home after a dash.
func _frame(r: Dictionary) -> InputFrame:
	var held := 0
	var pressed := 0
	if r.get("attack", false):
		if r.get("build", &"gun") == &"blade":
			if ticks % MELEE_EVERY == 0:
				pressed |= InputFrame.PRIMARY
			if ticks % MELEE_EVERY < 4:
				held |= InputFrame.PRIMARY
		else:
			var at := ticks % (SHOOT_HOLD + SHOOT_GAP)
			if at < SHOOT_HOLD:
				held |= InputFrame.SHOOT
			if at == 0:
				pressed |= InputFrame.SHOOT
	var press: int = r.get("press", 0)
	if press != 0:
		var at := (ticks + PRESS_EVERY / 2) % PRESS_EVERY
		if at == 0:
			pressed |= press
		if at < HOLD_TICKS:
			held |= press & (InputFrame.UTILITY | InputFrame.SKILL)
	var me := world.player_pos()
	var aim_at := _home + ENEMY_AT
	if world.actors.size() > 1:
		aim_at = world.actors.pos(1)
	var to := aim_at - me
	var aim := roundi(to.angle() / TAU * 4096.0)
	var move := Vector2i.ZERO
	var back := _home - me
	if pressed & InputFrame.DASH:  # a dash across the aim, one side then the other
		move = Vector2i(0, 110 if (ticks / PRESS_EVERY) % 2 == 0 else -110)
	elif back.length() > 0.6:
		var d := back.normalized() * 110.0
		move = Vector2i(roundi(d.x), roundi(d.y))
	return InputFrame.make(move, aim, roundi(to.length() * 100.0), held, pressed)


func _process(delta: float) -> void:
	if view == null:
		return
	if fx != null:
		_play_pack(delta)
	if ticks != _synced:
		_synced = ticks
		view.sync()


## The pack effect's loop: spawned again every LOOP_S (a held one once), a flying one moved across FLY_M in FLY_S.
func _play_pack(delta: float) -> void:
	fx.follow(float(ticks))
	var family: StringName = entry["family"]
	var start := SimPlane.to_3d(_home + Vector2(0.6, 0.0), 0.6)
	var mid := SimPlane.to_3d(_home + Vector2(2.6, 0.0), 0.0)
	var fly := EffectsCatalog.FLY_FAMILIES.has(family)
	var held := EffectsCatalog.HELD_FAMILIES.has(family)
	if _node == null or (not held and loop_t >= LOOP_S):
		loop_t = 0.0
		loops += 1
		if _node != null and fly:
			fx.release(_node)
		if _node == null or not held:
			_node = fx.spawn(
				entry["id"], start if fly else mid, 1.0, {}, 0.0 if (fly or held) else -1.0
			)
			if _node != null and (fly or held):  # as the game's held effects (x along the flight: +x)
				FireballPack.keep_playing(_node, _node.scale.x)
	loop_t += delta
	if _node != null and fly and is_instance_valid(_node):
		var k := minf(loop_t / FLY_S, 1.0)
		var was := _node.global_position
		_node.global_position = start + Vector3(FLY_M * k, 0.0, 0.0)
		PackFx.settle(_node, was, _node.global_position)
		_node.visible = loop_t <= FLY_S


## The pack effect ids this stage's views have drawn so far (the game's own table; a pack entry: its own id).
func pack_ids_seen() -> PackedStringArray:
	var out := PackedStringArray()
	var p := view.pack_fx if view != null else null
	if p == null:
		return out
	for id in p.warm_ids():
		if p.pooled(id) > 0:
			out.append(String(id))
	return out
