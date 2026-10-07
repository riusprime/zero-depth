extends GutTest
## The Needle's walking-turret model (v0.2.0 L17): its parts, its flash materials, the legs stepping while it moves
## and the wind-up and recoil poses. Presentation only: these drive it with plain state and step its frame-time
## animation by hand.

const DT := 1.0 / 60.0


func _avatar() -> NeedleAvatar:
	var a := NeedleAvatar.new()
	a.setup(Color("#1A1A22"))
	add_child_autofree(a)
	a.set_process(false)  # the test steps advance() itself
	return a


## Runs `ticks` ticks in `state` from tick t0, moving at `vel` (m/s); one advance(1/60) per tick.
func _run(a: NeedleAvatar, t0: int, state: int, ticks: int, vel := Vector2.ZERO) -> void:
	var p := Vector2.ZERO
	for k in ticks:
		p += vel / 60.0
		a.apply_state({"tick": t0 + k, "pos": p, "state": state})
		a.advance(DT)


func _snapshot(a: NeedleAvatar) -> Array:
	var out := []
	for leg in a.legs:
		out.append(leg.position)
		out.append(leg.rotation)
	out.append(a.body.transform)
	out.append(a.barrel.position)
	return out


func test_builds_body_barrel_and_four_legs() -> void:
	var a := _avatar()
	assert_not_null(a.body, "body")
	assert_not_null(a.barrel, "barrel")
	assert_eq(a.legs.size(), 4, "four legs")
	assert_eq(a.feet.size(), 4, "four feet")
	assert_gt(NeedleAvatar.HEIGHT, 0.6, "a height for the health bar")
	assert_lt(NeedleAvatar.HEIGHT, 1.0, "shorter than the old pillar")


func test_exposes_outlined_body_materials_for_the_hit_flash() -> void:
	var a := _avatar()
	assert_gt(a.body_materials.size(), 10, "every body piece has a material")
	for m in a.body_materials:
		assert_eq(m.stencil_mode, BaseMaterial3D.STENCIL_MODE_OUTLINE, "outlined")
	var reds := a.body_materials.filter(func(m): return m.albedo_color == NeedleAvatar.RED)
	assert_eq(reds.size(), 1, "one red cube")


func test_xray_twins_only_with_xray() -> void:
	var with_x := NeedleAvatar.new()
	with_x.setup(Color.BLACK, &"xray")
	var without := NeedleAvatar.new()
	without.setup(Color.BLACK, &"outline")
	var count := func(n: Node) -> int:
		var c := 0
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null and mat.stencil_mode == BaseMaterial3D.STENCIL_MODE_XRAY:
				c += 1
		return c
	assert_gt(count.call(with_x), 0, "xray adds twins")
	assert_eq(count.call(without), 0, "outline has none")
	with_x.free()
	without.free()


func test_feet_stand_on_the_ground_at_rest() -> void:
	var a := _avatar()
	_run(a, 0, WorldReader.STATE_MOVE, 60)
	for f in a.foot_positions():
		assert_almost_eq(f.y, 0.0225, 0.01, "the foot block sits on the ground")
		assert_lt(Vector2(f.x, f.z).length(), 0.6, "within the contact ring")


func test_legs_step_while_moving_and_settle_when_still() -> void:
	var a := _avatar()
	_run(a, 0, WorldReader.STATE_MOVE, 30)
	var still := a.foot_positions()
	_run(a, 30, WorldReader.STATE_MOVE, 30)
	var still2 := a.foot_positions()
	for k in 4:
		assert_almost_eq(still[k].distance_to(still2[k]), 0.0, 0.01, "idle feet stay put")
	# Walk forward at the sim's speed: the feet move around their rest spots and some lift.
	var lifted := false
	var spread := 0.0
	var p := Vector2.ZERO
	for k in 40:
		p += Vector2(3.2, 0) / 60.0
		a.apply_state({"tick": 60 + k, "pos": p, "state": WorldReader.STATE_MOVE})
		a.advance(DT)
		var now := a.foot_positions()
		for j in 4:
			spread = maxf(spread, now[j].distance_to(still2[j]))
			lifted = lifted or now[j].y > 0.03
	assert_gt(spread, 0.08, "the feet stride")
	assert_true(lifted, "a swinging foot lifts")


func test_windup_braces_and_glows() -> void:
	var a := _avatar()
	_run(a, 0, WorldReader.STATE_MOVE, 30)
	var idle_y := a.body.position.y
	var idle_eyes := a.eye_energy()
	assert_almost_eq(a.muzzle_energy(), 0.0, 0.01, "a cold muzzle at rest")
	_run(a, 30, WorldReader.STATE_WINDUP, 30)
	assert_lt(a.body.position.y, idle_y - 0.02, "the body crouches")
	assert_gt(a.eye_energy(), idle_eyes + 2.0, "the eyes brighten")
	assert_gt(a.muzzle_energy(), 2.0, "the muzzle charges")


func test_each_shot_kicks_the_barrel_back_then_it_returns() -> void:
	var a := _avatar()
	_run(a, 0, WorldReader.STATE_MOVE, 20)
	var idle := _snapshot(a)
	assert_almost_eq(a.barrel_recoil(), 0.0, 0.001, "barrel at rest")
	_run(a, 20, WorldReader.STATE_WINDUP, 30)
	_run(a, 50, WorldReader.STATE_ACTIVE, 2)
	assert_gt(a.barrel_recoil(), 0.04, "the first shot kicks the barrel back")
	assert_ne(_snapshot(a), idle, "the firing pose differs from idle")
	var first := a.barrel_recoil()
	_run(a, 52, WorldReader.STATE_ACTIVE, 4)
	assert_lt(a.barrel_recoil(), first, "it slides back out")
	_run(a, 56, WorldReader.STATE_ACTIVE, 2)
	assert_gt(a.barrel_recoil(), 0.04, "the second shot kicks again")
	_run(a, 58, WorldReader.STATE_RECOVER, 12)
	_run(a, 70, WorldReader.STATE_MOVE, 90)
	assert_almost_eq(a.barrel_recoil(), 0.0, 0.001, "the barrel is home after the cool-down")
	assert_almost_eq(a.muzzle_energy(), 0.0, 0.05, "the muzzle cools")


func test_spawn_starts_folded_and_rises() -> void:
	var a := _avatar()
	a.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_SPAWN})
	a.advance(DT)
	var low := a.body.position.y
	_run(a, 1, WorldReader.STATE_MOVE, 60)
	assert_gt(a.body.position.y, low + 0.15, "it rises in once spawned")
