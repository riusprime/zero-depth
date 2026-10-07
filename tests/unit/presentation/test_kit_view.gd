extends GutTest
## The laser blade (v0.2.0 PLAN L1): its tip is the hit reach, it shows only while swinging, a trail follows it,
## and set_look restyles it.


func _swing_world() -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, InputFrame.PRIMARY, InputFrame.PRIMARY))
	return w


func test_blade_tip_is_the_hit_reach() -> void:
	var t := PlayerTable.starting_values()
	var kit: KitView = add_child_autofree(KitView.new())
	kit.set_shape([t.step(0).half_arc, t.step(0).reach_m, t.radius_m])
	assert_almost_eq(
		kit.blade_tip_m(), t.radius_m + t.step(0).reach_m, 0.0001, "tip = own radius + reach"
	)
	assert_almost_eq(KitView.blade_span([100, 2.0, 0.5]).y, 2.5, 0.0001)


func test_blade_follows_the_reader_shape_and_only_shows_while_swinging() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	var reader := WorldReader.new(w)
	var kit: KitView = add_child_autofree(KitView.new())
	kit.sync(reader)
	assert_false(kit.blade_visible(), "no swing, no blade")
	var shape := reader.swing_shape()
	assert_almost_eq(kit.blade_tip_m(), shape[1] + shape[2], 0.0001)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, InputFrame.PRIMARY, InputFrame.PRIMARY))
	assert_gt(reader.swing_tick(), 0, "the press starts a swing")
	kit.sync(reader)
	assert_true(kit.blade_visible(), "the blade ignites with the swing")
	for k in 3:
		w.step(InputFrame.new())
		kit.sync(reader)
	assert_gt(kit.trail_samples(), 2, "the trail keeps the blade's recent positions")
	while reader.swing_tick() > 0:
		w.step(InputFrame.new())
	kit.sync(reader)
	assert_false(kit.blade_visible(), "the blade goes out when the swing ends")
	assert_eq(kit.trail_samples(), 0)


func test_set_look_applies() -> void:
	var t := PlayerTable.starting_values()
	var kit: KitView = add_child_autofree(KitView.new())
	kit.set_shape([t.step(0).half_arc, t.step(0).reach_m, t.radius_m])
	var base_core: float = (kit.get_node("Blade/BladeCore").mesh as CapsuleMesh).radius
	kit.set_look(Color.RED, 1.5, 2.0, 3)
	assert_eq(kit.color, Color.RED)
	assert_eq(kit.trail_count, 3)
	var core: CapsuleMesh = kit.get_node("Blade/BladeCore").mesh
	assert_almost_eq(core.radius, base_core * 2.0, 0.0001, "width_scale thickens the core")
	assert_almost_eq(
		kit.blade_tip_m(), (t.radius_m + t.step(0).reach_m) * 1.5, 0.0001, "length_scale"
	)
	var core_mat: StandardMaterial3D = kit.get_node("Blade/BladeCore").material_override
	assert_almost_eq(
		core_mat.emission.r, Color.RED.lightened(0.75).r, 0.001, "the core takes the colour"
	)
	var w := _swing_world()
	var reader := WorldReader.new(w)
	kit.sync(reader)
	for k in 8:
		w.step(InputFrame.new())
		kit.sync(reader)
	assert_lte(kit.trail_samples(), 4, "trail_count caps the trail")


## Crash on hit (v0.3.0 L28, evidence/CRASH_ON_HIT.md): a hit on the wanderer in the first tick of a swing freezes
## the sim (hurt hit-stop), so the next syncs see swing tick 1 again. The trail used to clear itself on every
## "tick 1" and add nothing (the tick hadn't moved), so the blade's head read the last sample of an empty trail:
## an out-of-bounds read, an error in a debug build and a read of a bad Array in a release one.
func test_a_hit_freeze_on_the_swings_first_tick_keeps_the_trail_head() -> void:
	var w := _swing_world()
	var reader := WorldReader.new(w)
	var kit: KitView = add_child_autofree(KitView.new())
	assert_eq(reader.swing_tick(), 1, "the press started a swing this tick")
	kit.sync(reader)
	var at := w.player_pos() + Vector2(1, 0)
	Damage.hit(w, 0, 1, 999, 999, w.take_root(), 0, at, w.player_pos())
	assert_gt(w.freeze_ticks, 0, "the hit froze the sim (hurt hit-stop)")
	for k in 3:
		w.step(InputFrame.new())
		assert_eq(reader.swing_tick(), 1, "the freeze holds the swing on its first tick")
		kit.sync(reader)
		assert_gt(kit.trail_samples(), 0, "frozen sync %d: the trail keeps the blade's sample" % k)
	await wait_physics_frames(2)  # _process rebuilds the trail from the head too
	assert_eq(get_errors().size(), 0, "no out-of-bounds read of the trail")
	assert_true(kit.blade_visible())
