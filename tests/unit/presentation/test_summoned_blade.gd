extends GutTest
## The rune-summoned Blade (PENDING_ASSETS §9): the owner's model shows only while a swing or the Lunge Cleave is out,
## forms (a flash of runes) at the start of each arc, follows the arc the sim hits with, holds through the finisher's
## spin and the whole cleave, breaks into motes at the end, reads only, is one pooled holder, and keeps no flash or
## motes with reduced motion.


## A stand-in for WorldViewRoot: the views find the pack on an ancestor's `pack_fx`.
class Host:
	extends Node3D
	var pack_fx: PackFx = null


var _host: Host
var _fx: PackFx
var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false
	_host = add_child_autofree(Host.new())
	_fx = PackFx.new()
	_host.add_child(_fx)
	_host.pack_fx = _fx


func after_each() -> void:
	ViewPrefs.effects_density = "medium"
	ViewPrefs.reduced_motion = false


## A world whose next press starts combo step `step` (aim 0), with no enemies.
func _world_at(step: int) -> World:
	var w := World.new(3, PlayerTable.starting_values())
	for i in step:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
		while w.swing_t > 0:
			w.step(InputFrame.new())
	return w


func _kit() -> KitView:
	var kit := KitView.new()
	_host.add_child(kit)
	return kit


## The yaw the slash crosses at swing tick t (KitView's arc: the step's motion, eased, from the sim's angle).
static func _arc_yaw(r: WorldReader) -> float:
	var half: float = TAU * float(r.swing_shape()[0]) / 4096.0
	var p := clampf(float(r.swing_tick() - 1) / r.swing_sweep_ticks(), 0.0, 1.0)
	p = 1.0 - (1.0 - p) * (1.0 - p)
	var aim := SimPlane.yaw_of(r.swing_angle())
	match r.swing_motion():
		WorldReader.MOTION_SLASH_RIGHT_TO_LEFT:
			return aim - half + 2.0 * half * p
		WorldReader.MOTION_SLASH_LEFT_TO_RIGHT:
			return aim + half - 2.0 * half * p
		WorldReader.MOTION_SPIN:
			return aim + TAU * p
	return aim


func test_the_model_is_installed_and_replaces_the_laser_core() -> void:
	var kit := _kit()
	assert_true(kit.summoned.has_model(), "assets/models/fx/hero_blade.glb is listed and loads")
	assert_almost_eq(kit.summoned.length_m(), 1.1, 0.02, "about 1.1 m long")
	assert_false(
		kit.get_node("Blade/BladeCore").visible, "the laser core is not drawn under the model"
	)
	assert_eq(kit.summoned.node_count(), 2, "the steel and its glowing edge")
	assert_true(
		kit.summoned.get_child(0).has_meta(ShaderWarmup.WARM_META),
		"its hidden meshes are drawn behind the loading cover (no stall on the first swing)"
	)


func test_hidden_between_swings_and_forms_on_the_right_side_at_the_arcs_start() -> void:
	for step in 2:
		var w := _world_at(step)
		var r := WorldReader.new(w)
		var kit := _kit()
		kit.sync(r)
		assert_false(kit.summoned.blade_visible(), "nothing shows between swings")
		w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
		kit.sync(r)
		assert_true(kit.summoned.blade_visible(), "it shows on the swing's first tick")
		var half := TAU * float(r.swing_shape()[0]) / 4096.0
		var start := -half if step == 0 else half  # step 1 starts on the right, step 2 on the left
		assert_almost_eq(kit.summoned.yaw(), start, 0.001, "already at the start of the arc")
		assert_eq(kit.summoned.flashes, 1, "in one flash of runes")
		assert_gt(_fx.pooled(SummonedBlade.FLASH_ID), 0)
		kit.queue_free()


func test_it_follows_the_sims_arc_tip_on_the_reach() -> void:
	var w := _world_at(0)
	var r := WorldReader.new(w)
	var kit := _kit()
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	var samples := 0
	while r.swing_tick() > 0:
		kit.sync(r)
		var want := _arc_yaw(r)
		assert_almost_eq(
			kit.summoned.yaw(), want, 0.01, "tick %d on the slash's arc" % r.swing_tick()
		)
		assert_almost_eq(kit.summoned.yaw(), kit.blade_yaw(), 0.0001, "with the slash as drawn")
		var centre := SimPlane.to_3d(r.player_pos(), KitView.BLADE_HEIGHT)
		var shape := r.swing_shape()
		assert_almost_eq(
			kit.summoned.tip_point().distance_to(centre),
			shape[1] + shape[2],
			0.001,
			"tip on the reach"
		)
		samples += 1
		w.step(InputFrame.new())
	assert_gt(samples, 5)


func test_gone_after_the_recovery_in_motes() -> void:
	var w := _world_at(0)
	var r := WorldReader.new(w)
	var kit := _kit()
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	var ticks := r.swing_ticks()
	var shown := 0
	while r.swing_tick() > 0:
		kit.sync(r)
		shown += 1 if kit.summoned.blade_visible() else 0
		assert_eq(kit.summoned.motes, 0, "no motes while the swing is out")
		w.step(InputFrame.new())
	assert_eq(shown, ticks, "out for the whole swing, recovery included")
	kit.sync(r)
	assert_false(kit.summoned.blade_visible(), "gone when the recovery ends")
	assert_eq(kit.summoned.motes, 1, "broken into motes")
	assert_gt(_fx.pooled(SummonedBlade.MOTES_ID), 0)
	kit.sync(r)
	assert_eq(kit.summoned.motes, 1, "once")


func test_it_holds_through_the_finisher_spin() -> void:
	var w := _world_at(3)
	var r := WorldReader.new(w)
	var kit := _kit()
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	assert_true(r.is_finisher())
	var last := 0.0
	while r.swing_tick() > 0:
		kit.sync(r)
		assert_true(kit.summoned.blade_visible(), "out on spin tick %d" % r.swing_tick())
		assert_almost_eq(kit.summoned.yaw(), _arc_yaw(r), 0.01)
		last = kit.summoned.yaw()
		w.step(InputFrame.new())
	assert_almost_eq(last, TAU, 0.001, "one full turn with the blade")
	assert_eq(kit.summoned.forms, 1, "formed once for the whole spin")


func _cleave_world() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.crit_chance_permille = 0
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.add_dummy(Vector2(5.5, 0), 0.35, 5000)
	return w


func test_it_holds_through_the_whole_lunge_cleave() -> void:
	var w := _cleave_world()
	var r := WorldReader.new(w)
	var kit := _kit()
	var fx := SkillVisuals.new()
	_host.add_child(fx)
	var out_ticks := 0
	var swept := false
	var gone_after := false
	for k in 60:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.SKILL if k == 0 else 0))
		kit.sync(r)
		fx.sync(r)
		var s := r.skill_state()
		var running := int(s["running"]) > 0
		var sweep: Array = fx.cleave_sweep()
		if running or float(sweep[1]) > 0.0:
			assert_true(kit.summoned.blade_visible(), "out on cleave tick %d" % k)
			out_ticks += 1
			if float(sweep[0]) > 0.0:
				var half := TAU * float(s["half_arc"]) / 4096.0
				var aim := SimPlane.yaw_of(int(s["angle"]))
				var want := aim - half + 2.0 * half * float(sweep[0])
				assert_almost_eq(kit.summoned.yaw(), want, 0.001, "on the cleave's sweep")
				swept = true
		elif out_ticks > 0 and not kit.summoned.blade_visible():
			gone_after = true
	assert_gt(out_ticks, int(r.skill_state()["move_ticks"]), "out for the lunge and the hold")
	assert_true(swept, "it crossed the cleave's arc")
	assert_true(gone_after, "and is gone after")
	assert_eq(kit.summoned.forms, 1, "formed once for the cleave")
	assert_eq(kit.summoned.motes, 1, "broke into motes once")


func test_it_reads_only() -> void:
	var a := _world_at(0)
	var b := _world_at(0)
	var r := WorldReader.new(a)
	var kit := _kit()
	for k in 40:
		var f := InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY if k % 12 == 0 else 0)
		a.step(f)
		b.step(f)
		kit.sync(r)
	assert_eq(a.state_hash(), b.state_hash(), "syncing the blade changes nothing in the world")


func test_one_pooled_holder_for_every_swing() -> void:
	var w := _world_at(0)
	var r := WorldReader.new(w)
	var kit := _kit()
	var holders := kit.summoned.get_child_count()
	for k in 120:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY if k % 15 == 0 else 0))
		kit.sync(r)
	assert_gt(kit.summoned.forms, 3, "several swings")
	assert_eq(kit.summoned.get_child_count(), holders, "no node made per swing")
	assert_eq(kit.summoned.node_count(), 2)
	kit.free()
	assert_no_new_orphans()


func test_reduced_motion_keeps_the_arc_without_flash_or_motes() -> void:
	ViewPrefs.reduced_motion = true
	var w := _world_at(0)
	var r := WorldReader.new(w)
	var kit := _kit()
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	var shown := 0
	while r.swing_tick() > 0:
		kit.sync(r)
		shown += 1 if kit.summoned.blade_visible() else 0
		w.step(InputFrame.new())
	kit.sync(r)
	assert_gt(shown, 5, "the blade still shows the arc")
	assert_eq(kit.summoned.flashes, 0, "no flash")
	assert_eq(kit.summoned.motes, 0, "no motes")
	assert_eq(_fx.pooled(SummonedBlade.FLASH_ID) + _fx.pooled(SummonedBlade.MOTES_ID), 0)
