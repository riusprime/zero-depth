extends GutTest
## The horde kinds' models and visuals (v0.4.0 EN): code-built low-poly in the enemy style, flashable without a shader
## change, each with a windup pose; ActorViews builds them; the telegraph view draws the new styles; HordeVisuals
## draws mines, heal beams and sniper tracers.

const DT := 1.0 / 60.0
const STATE := EnemyAi.State
const KINDS := [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
	WorldReader.KIND_MENDER,
	WorldReader.KIND_MINE_LAYER,
	WorldReader.KIND_SNIPER,
]


func _avatar(kind: int) -> HordeAvatar:
	var a := HordeAvatar.new()
	a.setup(kind, Color.BLACK, &"xray")
	add_child_autofree(a)
	a.set_process(false)
	return a


func _run(a: HordeAvatar, t0: int, state: int, ticks: int, healing := false) -> void:
	for k in ticks:
		a.apply_state({"tick": t0 + k, "state": state, "healing": healing})
		a.advance(DT)


func test_every_kind_is_built_flashable_and_outlined() -> void:
	for kind: int in KINDS:
		var a := HordeAvatar.new()
		a.setup(kind, Color.BLACK, &"xray")
		assert_gt(a.body_materials.size(), 3, "kind %d has a model" % kind)
		assert_gt(a.height, 0.3, "kind %d: a height for its bar" % kind)
		for m: StandardMaterial3D in a.body_materials:
			assert_true(m.emission_enabled, "kind %d: a hit flash changes energy only" % kind)
			assert_eq(m.emission_energy_multiplier, 0.0, "kind %d: dark until flashed" % kind)
			assert_eq(
				m.stencil_mode, BaseMaterial3D.STENCIL_MODE_OUTLINE, "kind %d: outlined" % kind
			)
		a.free()


func test_each_kind_winds_up_visibly() -> void:
	for kind: int in KINDS:
		if kind == WorldReader.KIND_MENDER:
			continue  # no attack
		var a := _avatar(kind)
		_run(a, 0, STATE.MOVE, 30)
		var rest := a.glow_energy()
		_run(a, 30, STATE.WINDUP, 24)
		assert_gt(a.windup_pose(), 0.5, "kind %d leans into its windup" % kind)
		assert_gt(a.glow_energy(), rest + 1.0, "kind %d: its accent glows up" % kind)


func test_the_splitling_is_a_smaller_splitter() -> void:
	var big := _avatar(WorldReader.KIND_SPLITTER)
	var small := _avatar(WorldReader.KIND_SPLITLING)
	assert_almost_eq(small.height, big.height * HordeAvatar.SPLITLING_SCALE, 0.001)
	assert_almost_eq(small.body.scale.x, HordeAvatar.SPLITLING_SCALE, 0.001)


func test_the_shield_draws_back_then_slams_forward() -> void:
	var a := _avatar(WorldReader.KIND_SHIELD_BEARER)
	var shield: Node3D = a.parts["shield"]
	_run(a, 0, STATE.MOVE, 20)
	var rest := shield.position.x
	_run(a, 20, STATE.WINDUP, 30)
	assert_lt(shield.position.x, rest - 0.1, "drawn back")
	_run(a, 50, STATE.ACTIVE, 2)
	assert_gt(shield.position.x, rest, "bashed forward")


func test_the_mender_crystal_flares_while_it_heals() -> void:
	var a := _avatar(WorldReader.KIND_MENDER)
	_run(a, 0, STATE.MOVE, 30)
	var idle := a.glow_energy()
	_run(a, 30, STATE.MOVE, 30, true)
	assert_gt(a.glow_energy(), idle + 0.5, "brighter while its beam heals")


func test_actor_views_build_every_horde_model() -> void:
	var w := CombatLab.world()
	for k in KINDS.size():
		w.add_enemy(KINDS[k], Vector2(3 + k, 2))
	var views := ActorViews.new()
	add_child_autofree(views)
	views.sync(WorldReader.new(w))
	for k in KINDS.size():
		var node := views.actor_node(w.actors.ids[k + 1])
		var avatar: HordeAvatar = node.get_meta(&"enemy_avatar")
		assert_eq(avatar.kind, KINDS[k])
		var bar: Node3D = node.get_meta(&"bar")
		assert_gt(
			bar.get_parent().position.y, avatar.height, "kind %d: its bar above it" % KINDS[k]
		)


func test_the_telegraph_view_draws_the_new_styles() -> void:
	var w := CombatLab.world()
	w.actors.hp[0] = 100000
	w.add_enemy(WorldReader.KIND_SNIPER, Vector2(12, 0))
	w.add_enemy(WorldReader.KIND_SHIELD_BEARER, Vector2(-1.6, 0))
	var layer := w.add_enemy(WorldReader.KIND_MINE_LAYER, Vector2(0, 6))
	var view := TelegraphViews.new()
	add_child_autofree(view)
	var reader := WorldReader.new(w)
	var styles := {}
	for k in 900:
		if w.mines.size() > 0:
			w.actors.set_pos(0, w.mines.pos(0))  # step on the mine
		w.step(InputFrame.new())
		w.actors.hp[0] = 100000
		view.sync(reader)
		for i in reader.actor_count():
			var tg := reader.telegraph(i)
			if tg.has("style"):
				styles[tg["style"]] = true
	assert_true(styles.has(&"snipe"), "the sniper's line: %s" % [styles])
	assert_true(styles.has(&"bash"), "the shield bash")
	assert_true(styles.has(&"mine"), "an armed mine")
	assert_gte(w.actors.index_of(layer), 0)


func test_horde_visuals_draw_mines_beams_and_tracers() -> void:
	var w := CombatLab.world()
	w.actors.hp[0] = 100000
	w.add_enemy(WorldReader.KIND_MINE_LAYER, Vector2(6, 0))
	var mender := w.add_enemy(WorldReader.KIND_MENDER, Vector2(0, 7))
	var ally := w.add_enemy(WorldReader.KIND_SHIELD_BEARER, Vector2(0, 9))
	w.add_enemy(WorldReader.KIND_SNIPER, Vector2(-12, 0))
	var fx := HordeVisuals.new()
	add_child_autofree(fx)
	var reader := WorldReader.new(w)
	var seen := {"mine": false, "beam": false, "tracer": false}
	for k in 600:
		w.step(InputFrame.new())
		w.actors.hp[0] = 100000
		var j := w.actors.index_of(ally)
		if j >= 0:
			w.actors.hp[j] = 10  # keep it hurt, so the Mender keeps healing it
		fx.sync(reader)
		seen["mine"] = seen["mine"] or fx.mine_count() > 0
		seen["beam"] = seen["beam"] or fx.beam_count() > 0
		seen["tracer"] = seen["tracer"] or fx.tracer_count() > 0
	assert_eq(seen, {"mine": true, "beam": true, "tracer": true})
	assert_gte(w.actors.index_of(mender), 0)
