extends GutTest
## The Charger's clawed hooded crawler (v0.2.0 L17): its parts, the legs scuttling while it moves, the wind-up
## pose, the dazed slump, the rise after the spawn, and the ActorViews hook. Presentation only: these drive it with
## plain state and step its frame-time animation by hand.

const DT := 1.0 / 60.0


func _avatar() -> ChargerAvatar:
	var a := ChargerAvatar.new()
	a.setup(Color("#1A1A22"))
	add_child_autofree(a)
	a.set_process(false)  # the test steps advance() itself
	return a


## Runs `ticks` sim ticks in `state` moving at `vel` (m/s) from `from`; one advance(1/60) per tick.
func _run(
	a: ChargerAvatar, t0: int, from: Vector2, vel: Vector2, ticks: int, state: int
) -> Vector2:
	var p := from
	for k in ticks:
		p += vel / 60.0
		a.apply_state({"tick": t0 + k + 1, "pos": p, "state": state})
		a.advance(DT)
	return p


func _tip_motion(a: ChargerAvatar, t0: int, vel: Vector2, state: int) -> float:
	var before := a.leg_tips()
	_run(a, t0, Vector2.ZERO, vel, 7, state)
	var after := a.leg_tips()
	var moved := 0.0
	for k in before.size():
		moved += before[k].distance_to(after[k])
	return moved


func test_builds_hood_visor_and_four_clawed_legs() -> void:
	var a := _avatar()
	assert_not_null(a.body, "body")
	assert_not_null(a.visor, "visor")
	assert_eq(a.legs.size(), 4, "four legs")
	var vm := a.visor.material_override as StandardMaterial3D
	assert_true(vm.emission_enabled, "the visor glows")
	assert_gt(a.body_materials.size(), 6, "hood, mantle, body and leg pieces flash with the body")
	assert_false(a.body_materials.has(vm), "a hit flash never turns the visor's own glow off")
	for m in a.body_materials:
		assert_eq(
			m.stencil_mode, BaseMaterial3D.STENCIL_MODE_OUTLINE, "outlined like the other actors"
		)
		assert_true(m.emission_enabled, "built flashable: a hit changes energy, never the shader")
		assert_eq(m.emission_energy_multiplier, 0.0, "and dark until hit")
	var tips := a.leg_tips()
	for k in tips.size():
		assert_lt(absf(tips[k].y), 0.08, "talon %d stands near the ground" % k)
		assert_lt(
			Vector2(tips[k].x, tips[k].z).length(),
			0.45,
			"talon %d within the actor's footprint" % k
		)
	assert_gt(tips[0].z, 0.0, "the first leg is on the right")
	assert_lt(tips[1].z, 0.0, "the second leg is on the left")
	assert_gt(tips[0].x, tips[2].x, "front legs ahead of back legs")


func test_legs_scuttle_while_moving_and_rest_when_still() -> void:
	var a := _avatar()
	a.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE})
	_run(a, 0, Vector2.ZERO, Vector2.ZERO, 30, WorldReader.STATE_MOVE)
	var still := _tip_motion(a, 30, Vector2.ZERO, WorldReader.STATE_MOVE)
	var b := _avatar()
	b.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE})
	_run(b, 0, Vector2.ZERO, Vector2(3, 0), 30, WorldReader.STATE_MOVE)
	var moving := _tip_motion(b, 30, Vector2(3, 0), WorldReader.STATE_MOVE)
	assert_gt(moving, 0.05, "the talons step while it walks")
	assert_gt(moving, still * 3.0, "far more leg motion walking than standing")


func test_windup_rears_back_and_raises_the_claws() -> void:
	var idle := _avatar()
	idle.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE})
	_run(idle, 0, Vector2.ZERO, Vector2.ZERO, 36, WorldReader.STATE_MOVE)
	var wind := _avatar()
	wind.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_WINDUP})
	_run(wind, 0, Vector2.ZERO, Vector2.ZERO, 36, WorldReader.STATE_WINDUP)
	assert_almost_eq(wind.windup_amount(), 1.0, 0.001, "fully wound up after 0.6 s")
	assert_almost_eq(idle.windup_amount(), 0.0, 0.001, "no wind-up when moving")
	var front_idle := idle.leg_tips()[0]
	var front_wind := wind.leg_tips()[0]
	assert_gt(front_wind.y - front_idle.y, 0.15, "the front claw is raised")
	assert_gt(wind.body.rotation.z, 0.2, "the body rears back (nose up)")
	assert_gt(wind.visor_energy(), idle.visor_energy() * 1.5, "the visor brightens")


func test_lunge_and_daze_poses() -> void:
	var lunge := _avatar()
	lunge.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_ACTIVE})
	_run(lunge, 0, Vector2.ZERO, Vector2(15, 0), 20, WorldReader.STATE_ACTIVE)
	assert_lt(lunge.body.rotation.z, -0.1, "the lunge drops the nose")
	assert_gt(lunge.leg_tips()[0].x, 0.3, "the front claws reach ahead")
	var dazed := _avatar()
	dazed.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_RECOVER})
	_run(dazed, 0, Vector2.ZERO, Vector2.ZERO, 40, WorldReader.STATE_RECOVER)
	assert_lt(dazed.body_lift(), -0.06, "dazed, the body slumps")
	assert_lt(dazed.visor_energy(), ChargerAvatar.VISOR_ENERGY * 0.5, "and the visor dims")


func test_rises_out_of_the_ground_when_the_spawn_ends() -> void:
	var a := _avatar()
	a.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_SPAWN})
	_run(a, 0, Vector2.ZERO, Vector2.ZERO, 10, WorldReader.STATE_SPAWN)
	assert_lt(a.body_lift(), -0.3, "sunk while spawning")
	_run(a, 10, Vector2.ZERO, Vector2.ZERO, 30, WorldReader.STATE_MOVE)
	assert_almost_eq(a.body_lift(), 0.0, 0.03, "standing after the rise")


func test_actor_views_uses_it_for_the_charger() -> void:
	var views := ActorViews.new()
	add_child_autofree(views)
	var node := views._make_actor(WorldReader.KIND_CHARGER, false, 0.4)
	views.add_child(node)
	assert_true(node.has_meta(&"enemy_avatar"), "the hook finds the avatar")
	var avatar: ChargerAvatar = node.get_meta(&"enemy_avatar")
	assert_eq(avatar.get_parent(), node.get_meta(&"facing"), "it turns with the actor's facing")
	assert_eq(
		(node.get_meta(&"mats") as Array).size(),
		avatar.body_materials.size(),
		"hit flash reaches it"
	)
	assert_true(node.has_meta(&"dazed"), "the dazed ring stays")
	var bar: Node3D = node.get_meta(&"bar")
	assert_gt(
		bar.get_parent().position.y, ChargerAvatar.HEIGHT, "the health bar floats above the hood"
	)
