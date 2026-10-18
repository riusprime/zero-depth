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


## v0.8.0 P1: a windup's progress rises over 48 ticks (the sim's telegraph progress drives the strike pose).
func _run(a: HordeAvatar, t0: int, state: int, ticks: int, healing := false) -> void:
	for k in ticks:
		var p := clampf(float(k + 1) / 48.0, 0.0, 1.0) if state == STATE.WINDUP else 0.0
		a.apply_state({"tick": t0 + k, "state": state, "healing": healing, "windup": p})
		a.advance(DT)


func test_every_kind_is_built_flashable_and_outlined() -> void:
	for kind: int in KINDS:
		var a := HordeAvatar.new()
		a.setup(kind, Color.BLACK, &"xray")
		# v0.8.0 MI: an owner's model has two body materials (its frame, its role plates); a code body more.
		assert_gt(a.body_materials.size(), 1 if a.has_model() else 3, "kind %d has a model" % kind)
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
	_run(a, 52, STATE.RECOVER, 3)  # v0.8.0 P1: the bash snaps out over STRIKE_SNAP_S (about 4 frames) from the hit
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


## v0.8.0 MI: the owner's models (EnemyModels) replace the Splitter's, Shield Bearer's and Mender's code bodies.
func test_the_owners_models_replace_three_code_bodies() -> void:
	for kind: int in KINDS:
		var a := _avatar(kind)
		var want := HordeAvatar.model_id(kind) != &""
		assert_eq(a.has_model(), want, "kind %d: the owner's model when one is delivered" % kind)
		if want:
			for m: StandardMaterial3D in a.body_materials:
				assert_not_null(m.albedo_texture, "kind %d: his colour map" % kind)
				assert_true(m.has_meta(&"enemy_tex"), "kind %d: tinted like a code body" % kind)
			var role: Color = a.body_materials[1].albedo_color
			assert_true(
				role.is_equal_approx(EnemyPalettes.color(kind, &"body")),
				"kind %d: the plates in the role colour" % kind
			)


## v0.8.0 MI: a missing model file keeps the code-made body (L15).
func test_a_missing_model_keeps_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _avatar(WorldReader.KIND_SPLITTER)
	assert_false(a.has_model())
	assert_true(a.parts.has("claws"), "the code-made claws")
	EnemyModels.dir = EnemyModels.DIR
	EnemyModels.clear_cache()


## v0.8.0 MI: the Splitter's claws are raised and held through its windup (O25), then chop; its halves part when it
## dies.
func test_the_splitter_model_raises_its_claws_and_splits_on_death() -> void:
	var a := _avatar(WorldReader.KIND_SPLITTER)
	if not a.has_model():
		pass_test("no model installed")
		return
	var arm: Node3D = a.parts["arm_r"]
	var half_l: Node3D = a.parts["half_l"]
	var half_r: Node3D = a.parts["half_r"]
	_run(a, 0, STATE.MOVE, 20)
	var rest := arm.rotation.z
	_run(a, 20, STATE.WINDUP, 30)
	assert_gt(arm.rotation.z, rest + 0.5, "raised")
	var held := arm.rotation.z
	for k in range(30, 46):  # the same windup going on to its end
		a.apply_state({"tick": 20 + k, "state": STATE.WINDUP, "windup": float(k + 1) / 48.0})
		a.advance(DT)
	assert_almost_eq(arm.rotation.z, held, 0.01, "and held")
	_run(a, 68, STATE.ACTIVE, 3)
	_run(a, 71, STATE.RECOVER, 3)
	assert_lt(arm.rotation.z, rest, "chopped down")
	var gap := half_r.position.z - half_l.position.z
	assert_true(a.die())
	_run(a, 80, STATE.MOVE, 20)
	assert_gt(half_r.position.z - half_l.position.z, gap + 0.3, "the halves part")


## v0.8.0 MI: the Shield Bearer's legs swing while it walks (its pace read from how fast its node moves).
func test_the_shield_bearer_model_walks_on_its_legs() -> void:
	var a := HordeAvatar.new()
	a.setup(WorldReader.KIND_SHIELD_BEARER, Color.BLACK, &"xray")
	var holder := Node3D.new()
	add_child_autofree(holder)
	holder.add_child(a)
	a.set_process(false)
	if not a.has_model():
		pass_test("no model installed")
		return
	var leg: Node3D = a.parts["leg_l"]
	var swing := 0.0
	for k in 60:
		holder.position.x += 2.0 / 60.0  # 2 m/s
		a.apply_state({"tick": k, "state": STATE.MOVE, "windup": 0.0})
		a.advance(DT)
		swing = maxf(swing, absf(leg.rotation.z))
	assert_gt(swing, 0.2, "the legs swing while it walks")


func test_the_mender_model_raises_its_crystals_while_it_heals() -> void:
	var a := _avatar(WorldReader.KIND_MENDER)
	if not a.has_model():
		pass_test("no model installed")
		return
	var crystal: Node3D = a.parts["crystal"]
	_run(a, 0, STATE.MOVE, 30)
	var idle := crystal.position.y
	_run(a, 30, STATE.MOVE, 30, true)
	assert_gt(crystal.position.y, idle + 0.05, "raised while its beam heals")


## v0.8.0 MI: the Lens Drone is the owner's model: its ring of feet spins and its eye flares through a windup.
func test_the_lens_drone_model() -> void:
	var a := LensDroneAvatar.new()
	a.setup(Color.BLACK)
	add_child_autofree(a)
	a.set_process(false)
	if not a.has_model:
		pass_test("no model installed")
		return
	a.apply_state({"tick": 0, "state": STATE.MOVE})
	a.advance(DT)
	var turn := a.ring.rotation.y
	for k in 20:
		a.apply_state({"tick": k, "state": STATE.WINDUP})
		a.advance(DT)
	assert_ne(a.ring.rotation.y, turn, "the ring spins")
	assert_gt(a.body_materials.size(), 1)
