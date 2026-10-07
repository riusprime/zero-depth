extends GutTest
## The Arc Caster's and the Bomb Drone's models (v0.3.5 AI): code-built low-poly in the enemy style, flashable
## without a shader change, the drone hovering with a ground shadow and losing its bomb as it lobs it, the caster's
## crystal charging through the windup; ActorViews builds them, and the telegraph view draws their spells.

const DT := 1.0 / 60.0
const STATE := EnemyAi.State


func _run(a: Node3D, t0: int, state: int, ticks: int) -> void:
	for k in ticks:
		a.apply_state({"tick": t0 + k, "state": state})
		a.advance(DT)


func test_both_are_built_flashable_and_outlined() -> void:
	var avatars: Array[Node3D] = [ArcCasterAvatar.new(), BombDroneAvatar.new()]
	for avatar in avatars:
		var name: String = avatar.get_script().get_global_name()
		avatar.setup(Color.BLACK, &"xray")
		assert_gt(avatar.body_materials.size(), 5, name)
		for m: StandardMaterial3D in avatar.body_materials:
			assert_true(m.emission_enabled, "%s: a hit flash changes energy only" % name)
			assert_eq(m.emission_energy_multiplier, 0.0, "%s: dark until flashed" % name)
			assert_eq(m.stencil_mode, BaseMaterial3D.STENCIL_MODE_OUTLINE, "%s: outlined" % name)
		avatar.free()


func test_the_drone_hovers_with_a_shadow_on_the_ground() -> void:
	var a := BombDroneAvatar.new()
	a.setup(Color.BLACK)
	add_child_autofree(a)
	a.set_process(false)
	_run(a, 0, STATE.MOVE, 120)
	assert_almost_eq(a.hover_height(), BombDroneAvatar.HOVER_Y, BombDroneAvatar.BOB_M + 0.01)
	assert_lt(a.shadow.position.y, 0.05, "the shadow stays on the ground")
	var heights := {}
	for k in 60:
		_run(a, 120 + k, STATE.MOVE, 1)
		heights[snappedf(a.hover_height(), 0.01)] = true
	assert_gt(heights.size(), 3, "a soft bob")


func test_the_drone_lobs_its_bomb_and_slings_a_new_one() -> void:
	var a := BombDroneAvatar.new()
	a.setup(Color.BLACK)
	add_child_autofree(a)
	a.set_process(false)
	_run(a, 0, STATE.MOVE, 30)
	assert_true(a.bomb_armed(), "a bomb hangs under it")
	_run(a, 30, STATE.WINDUP, 30)
	assert_false(a.bomb_armed(), "the bomb left with the lob")
	_run(a, 60, STATE.RECOVER, 30)
	_run(a, 90, STATE.MOVE, 60)
	assert_true(a.bomb_armed(), "a new one by the next attack")


func test_the_caster_charges_its_crystal_through_the_windup() -> void:
	var a := ArcCasterAvatar.new()
	a.setup(Color.BLACK)
	add_child_autofree(a)
	a.set_process(false)
	_run(a, 0, STATE.MOVE, 30)
	var rest := a.crystal_energy()
	_run(a, 30, STATE.WINDUP, 28)
	assert_gt(a.crystal_energy(), rest + 2.0, "it glows as the spell builds")
	assert_gt(a.staff_raise(), 0.3, "the staff comes up")


func test_actor_views_build_the_new_models() -> void:
	var w := CombatLab.world()
	w.add_enemy(ActorStore.Kind.ARC_CASTER, Vector2(4, 0))
	w.add_enemy(ActorStore.Kind.BOMB_DRONE, Vector2(-4, 0))
	var views := ActorViews.new()
	add_child_autofree(views)
	var reader := WorldReader.new(w)
	views.sync(reader)
	var caster := views.actor_node(w.actors.ids[1])
	var drone := views.actor_node(w.actors.ids[2])
	assert_true(caster.get_meta(&"enemy_avatar") is ArcCasterAvatar)
	assert_true(drone.get_meta(&"enemy_avatar") is BombDroneAvatar)
	var bar: Node3D = drone.get_meta(&"bar")
	assert_gt(
		bar.get_parent().position.y, BombDroneAvatar.HOVER_Y, "the drone's bar sits above its hover"
	)


func test_the_telegraph_view_draws_the_spells() -> void:
	var w := CombatLab.world()
	w.actors.hp[0] = 100000
	var drone := w.add_enemy(ActorStore.Kind.BOMB_DRONE, Vector2(6, 0))
	var caster := w.add_enemy(ActorStore.Kind.ARC_CASTER, Vector2(-8, 0))
	var view := TelegraphViews.new()
	add_child_autofree(view)
	var reader := WorldReader.new(w)
	var styles := {}
	for k in 600:
		w.step(InputFrame.new())
		w.actors.hp[0] = 100000
		view.sync(reader)
		for i in reader.actor_count():
			var tg := reader.telegraph(i)
			if tg.has("style"):
				styles[tg["style"]] = true
	assert_true(styles.has(&"bomb"), "the bomb's circle")
	assert_true(styles.has(&"bolt") or styles.has(&"rune"), "a spell's mark")
	assert_gte(w.actors.index_of(drone) + w.actors.index_of(caster), 0)
