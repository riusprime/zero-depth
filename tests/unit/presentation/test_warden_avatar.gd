extends GutTest
## The Warden's rock golem (v0.2.0 L17): its parts, its materials for the hit flash, no shield, and the slam's
## poses (fists overhead in the windup, on the ground after the slam). Presentation only: these drive it with plain
## state and step its frame-time animation by hand.

const DT := 1.0 / 60.0


func _avatar(technique: StringName = &"outline") -> WardenAvatar:
	var a := WardenAvatar.new()
	a.setup(Color("#1A1A22"), technique)
	add_child_autofree(a)
	a.set_process(false)  # the test steps advance() itself
	return a


## Runs `ticks` sim ticks in `state` (windup progress rising over 48 ticks), one advance(1/60) per tick.
func _run(a: WardenAvatar, t0: int, state: int, ticks: int, pos := Vector2.ZERO) -> int:
	for k in ticks:
		var t := t0 + k + 1
		a.apply_state(
			{"tick": t, "pos": pos, "state": state, "windup": clampf(float(k + 1) / 48.0, 0.0, 1.0)}
		)
		a.advance(DT)
	return t0 + ticks


func _all_nodes(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out


func test_builds_shell_visor_weak_spot_two_arms_and_two_legs() -> void:
	var a := _avatar()
	assert_not_null(a.shell, "shell")
	assert_not_null(a.visor, "visor")
	assert_not_null(a.weak_spot, "weak spot on the back")
	assert_eq(a.arms.size(), 2, "two arms")
	assert_eq(a.fists.size(), 2, "two fists")
	assert_eq(a.legs.size(), 2, "two legs")
	var vm := a.visor.material_override as StandardMaterial3D
	assert_true(vm.emission_enabled, "the visor glows")
	assert_lt(a.weak_spot.position.x, 0.0, "the weak spot is behind the middle (+X is the front)")


func test_exposes_body_materials_for_the_hit_flash() -> void:
	var a := _avatar()
	assert_gt(a.body_materials.size(), 8, "every body piece has a material")
	for m in a.body_materials:
		assert_eq(m.stencil_mode, ActorLooks.outline_mode(), "body pieces are outlined")


func test_no_xray_twins() -> void:
	var o := _avatar(&"outline")
	for c in _all_nodes(o):
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).material_override as StandardMaterial3D
			if m != null:
				assert_ne(m.stencil_mode, BaseMaterial3D.STENCIL_MODE_XRAY, "no X-ray (v0.9.5 PF1)")


func test_has_no_shield() -> void:
	var a := _avatar()
	for n in _all_nodes(a):
		assert_false(String(n.name).to_lower().contains("shield"), "no shield node: %s" % n.name)
	# Nothing stands out far in front like the old slab did (radius 0.55; fists may stick out a little).
	for n in _all_nodes(a):
		if n is MeshInstance3D and (n as MeshInstance3D).visible:  # v0.8.0 P1: not the hidden dust ring
			var mi := n as MeshInstance3D
			var box := a.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			assert_lt(box.end.x, 0.8, "%s stays near the body" % mi.name)


func test_windup_raises_the_fists_overhead() -> void:
	var a := _avatar()
	var t := _run(a, 0, WorldReader.STATE_MOVE, 30)
	var idle := a.fist_height()
	_run(a, t, WorldReader.STATE_WINDUP, 45)
	assert_gt(a.raise_amount(), 0.8, "raised by late windup")
	assert_gt(a.fist_height(), idle + 0.8, "fists well above where they hang")
	assert_gt(a.fist_height(), 1.1, "fists over the head")


func test_slam_puts_the_fists_on_the_ground_then_they_rise() -> void:
	var a := _avatar()
	var t := _run(a, 0, WorldReader.STATE_WINDUP, 45)
	t = _run(a, t, WorldReader.STATE_ACTIVE, 1)
	t = _run(a, t, WorldReader.STATE_RECOVER, 6)
	assert_gt(a.slam_amount(), 0.9, "slammed")
	assert_lt(a.fist_height(), 0.3, "fists down at the ground")
	_run(a, t, WorldReader.STATE_MOVE, 60)
	assert_lt(a.slam_amount(), 0.1, "back up after the recovery")


func test_walking_swings_the_legs() -> void:
	var a := _avatar()
	var t := _run(a, 0, WorldReader.STATE_MOVE, 5)
	var rest: float = a.legs[0].rotation.z
	var p := Vector2.ZERO
	var widest := 0.0
	for k in 60:
		p += Vector2(1.6, 0) / 60.0
		t = _run(a, t, WorldReader.STATE_MOVE, 1, p)
		widest = maxf(widest, absf(a.legs[0].rotation.z - rest))
	assert_gt(widest, 0.15, "the legs stride")


func test_spawn_starts_underground_and_rises() -> void:
	var a := _avatar()
	var t := _run(a, 0, WorldReader.STATE_SPAWN, 10)
	assert_lt(a.fist_height(), 0.0, "below the floor while spawning")
	_run(a, t, WorldReader.STATE_MOVE, 40)
	assert_gt(a.fist_height(), 0.1, "risen")
