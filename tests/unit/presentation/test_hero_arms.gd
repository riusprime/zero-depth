extends GutTest
## The hero's arms and the Blade in their hands (HeroArms): both hands stay on the sword's grip and its tip stays on
## the slash's tip through every combo step and the Lunge Cleave; the arms rest hidden between swings (summoned, the
## default) or carry the sword in a guard (held, the dev panel's switch); the Gun, a dead hero, reduced motion and a
## missing model keep working; nothing is written to the world.

const DT := 1.0 / 60.0


## A stand-in for WorldViewRoot: the views find the pack on an ancestor's `pack_fx`.
class Host:
	extends Node3D
	var pack_fx: PackFx = null


var _host: Host
var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	ViewPrefs.reduced_motion = false
	ViewPrefs.blade_held = false
	_host = add_child_autofree(Host.new())
	_host.pack_fx = PackFx.new()
	_host.add_child(_host.pack_fx)


func after_each() -> void:
	ViewPrefs.reduced_motion = false
	ViewPrefs.blade_held = false
	ViewPrefs.enemy_vat = false  # apply_settings turns it on (the game default); the later files expect it off
	BossPieceModels.dir = BossPieceModels.DIR
	BossPieceModels.clear_cache()


## A world whose next press starts combo step `step` (aim 0), with no enemies.
func _world_at(step: int) -> World:
	var w := World.new(3, PlayerTable.starting_values())
	for i in step:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
		while w.swing_t > 0:
			w.step(InputFrame.new())
	return w


func _cleave_world() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.crit_chance_permille = 0
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.add_dummy(Vector2(5.5, 0), 0.35, 5000)
	return w


## The hero's view: [the Blade's view, the avatar (its arms reading that Blade)].
func _views() -> Array:
	var kit := KitView.new()
	_host.add_child(kit)
	var a := PlayerAvatar.new()
	a.setup()
	_host.add_child(a)
	a.set_process(false)
	a.arms.blade = kit.summoned
	a.arms.interpolated = false  # the test steps ticks, not frames
	return [kit, a]


## One tick as the game draws it: the avatar and the Blade read the world, then the frame animates.
func _draw(r: WorldReader, kit: KitView, a: PlayerAvatar) -> void:
	a.position = SimPlane.to_3d(r.player_pos())
	a.sync(r)
	kit.sync(r)
	a.advance(DT)


## Both hands on the grip of the sword SummonedBlade draws, and that sword's tip on the slash's tip.
func _assert_gripped(r: WorldReader, kit: KitView, a: PlayerAvatar, what: String) -> void:
	var arms := a.arms
	var b := kit.summoned
	assert_true(arms.visible, what + ": the arms are out")
	for k in 2:
		assert_true(arms.on_grip(k), "%s: hand %d reached the grip" % [what, k])
		assert_lt(arms.hand_point(k).distance_to(arms.grip_point(k)), 0.005, what + ": on it")
		var up := (a.position + arms.grip_point(k)).distance_to(b.hilt_point())
		assert_lt(up, 0.34 * b.span_m(), "%s: hand %d below the cross-guard" % [what, k])
		var on_axis := (a.position + arms.grip_point(k) - b.hilt_point()).normalized()
		assert_gt(on_axis.dot((b.tip_point() - b.hilt_point()).normalized()), 0.999, "on the hilt")
	assert_lt(
		(a.position + arms.sword_tip()).distance_to(b.tip_point()), 0.002, what + ": the tip held"
	)
	assert_lt(
		(a.position + arms.sword_pommel()).distance_to(b.hilt_point()), 0.002, what + ": the hilt"
	)
	var s: Vector3 = b.get_child(0).scale
	assert_almost_eq(s.y, s.x, 0.0001, what + ": never stretched")
	assert_almost_eq(s.z, s.x, 0.0001, what + ": never stretched")
	assert_eq(r.player_dead(), false)


func test_two_blocky_arms_with_gauntlets_rest_hidden() -> void:
	var v := _views()
	var a: PlayerAvatar = v[1]
	assert_eq(a.arms.get_child_count(), 4, "an upper arm and a forearm each side")
	assert_eq(a.arms.get_child(1).get_child_count(), 4, "the forearm, a cuff, a plate and a fist")
	assert_false(a.arms.visible, "hidden under the poncho with no sword out")
	var charcoal := 0
	for m in a.body_materials:
		charcoal += 1 if m.albedo_color.is_equal_approx(PlayerAvatar.LEG_COLOR) else 0
		assert_eq(m.roughness, 1.0, "matte")
	assert_gt(charcoal, 2, "the arms wear the legs' charcoal and flash with the body")


func test_the_hands_hold_the_hilt_and_the_tip_stays_on_the_slash_through_every_combo_step() -> void:
	var motions := {}
	for step in 4:
		var w := _world_at(step)
		var r := WorldReader.new(w)
		var v := _views()
		var kit: KitView = v[0]
		var a: PlayerAvatar = v[1]
		_draw(r, kit, a)
		w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
		var shown := 0
		while r.swing_tick() > 0:
			_draw(r, kit, a)
			assert_true(kit.summoned.blade_visible())
			var c := SimPlane.to_3d(r.player_pos(), KitView.BLADE_HEIGHT)
			var out := Vector3(cos(kit.blade_yaw()), 0, -sin(kit.blade_yaw()))
			var slash_tip := c + out * (kit.blade_tip_m() - kit.blade_offset())
			assert_lt(kit.summoned.tip_point().distance_to(slash_tip), 0.002, "what hits")
			_assert_gripped(r, kit, a, "step %d tick %d" % [step, r.swing_tick()])
			motions[r.swing_motion()] = true
			shown += 1
			w.step(InputFrame.new())
		assert_gt(shown, 5, "step %d: the whole swing" % step)
		kit.queue_free()
		a.queue_free()
	assert_eq(motions.size(), 4, "both slashes, the thrust and the finisher's spin")


func test_the_hands_hold_it_through_the_lunge_cleave() -> void:
	var w := _cleave_world()
	var r := WorldReader.new(w)
	var v := _views()
	var kit: KitView = v[0]
	var a: PlayerAvatar = v[1]
	var out_ticks := 0
	for k in 60:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.SKILL if k == 0 else 0))
		_draw(r, kit, a)
		if kit.summoned.blade_visible():
			_assert_gripped(r, kit, a, "cleave tick %d" % k)
			out_ticks += 1
	assert_gt(out_ticks, int(r.skill_state()["move_ticks"]), "the lunge and the cleave")
	assert_false(a.arms.carrying(), "summoned: nothing carried after")


func test_summoned_the_arms_drop_to_rest_after_the_swing() -> void:
	var w := _world_at(0)
	var r := WorldReader.new(w)
	var v := _views()
	var kit: KitView = v[0]
	var a: PlayerAvatar = v[1]
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	while r.swing_tick() > 0:
		_draw(r, kit, a)
		w.step(InputFrame.new())
	_draw(r, kit, a)
	assert_false(kit.summoned.blade_visible(), "the sword is gone")
	assert_true(a.arms.visible, "the arms are still easing down")
	assert_false(a.arms.on_grip(0), "and hold nothing")
	for k in 30:
		w.step(InputFrame.new())
		_draw(r, kit, a)
	assert_false(a.arms.visible, "at rest, hidden under the poncho")
	assert_false(a.arms.carrying(), "nothing is carried between swings")
	assert_gt(kit.summoned.flashes, 0, "it formed in its rune flash")
	assert_gt(kit.summoned.motes, 0, "and broke into motes")


func test_held_the_sword_stays_in_the_hands_in_a_guard_and_turns_with_the_body() -> void:
	ViewPrefs.blade_held = true
	var w := _world_at(0)
	var r := WorldReader.new(w)
	var v := _views()
	var kit: KitView = v[0]
	var a: PlayerAvatar = v[1]
	for k in 20:
		w.step(InputFrame.new())
		_draw(r, kit, a)
	var arms := a.arms
	assert_true(arms.carrying(), "the sword is carried before any swing")
	assert_true(arms.on_grip(0) and arms.on_grip(1), "both hands on it")
	assert_gt(arms.sword_tip().y, arms.sword_pommel().y + 0.6, "its tip up, across the body")
	var rel := _sword_yaw(arms) - a.body_yaw()
	# A swing: the summoned sword takes over for the arc, with no flash and no motes, and the hands stay on it.
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	while r.swing_tick() > 0:
		_draw(r, kit, a)
		assert_false(arms.carrying(), "one sword at a time")
		_assert_gripped(r, kit, a, "held, tick %d" % r.swing_tick())
		w.step(InputFrame.new())
	_draw(r, kit, a)
	assert_true(arms.carrying(), "back in the hands the tick the swing ends")
	assert_eq(kit.summoned.flashes + kit.summoned.motes, 0, "it never forms or breaks")
	# Walking up the screen turns the body; the guard turns with it.
	for k in 60:
		w.step(InputFrame.make(Vector2i(0, 127), 0, 100, 0, 0))
		_draw(r, kit, a)
		assert_true(arms.on_grip(0) and arms.on_grip(1), "held while walking")
	assert_gt(absf(wrapf(a.body_yaw(), -PI, PI)), 1.0, "the body turned to the walk")
	assert_almost_eq(wrapf(_sword_yaw(arms) - a.body_yaw() - rel, -PI, PI), 0.0, 0.15, "with it")
	var s := arms.get_node("CarriedBlade") as Node3D
	assert_almost_eq(s.scale.x, kit.summoned.carry_scale(), 0.001, "at the size it swings at")
	assert_almost_eq(s.scale.y, s.scale.x, 0.0001, "never stretched")


func _sword_yaw(arms: HeroArms) -> float:
	var d := arms.sword_tip() - arms.sword_pommel()
	return atan2(-d.z, d.x)


func test_the_dev_panel_has_the_switch() -> void:
	ViewPrefs.apply_settings(ProfileStore.new(""))
	assert_false(ViewPrefs.blade_held, "summoned by default")
	assert_true(DebugApi.view_switches.has(&"blade_held"), "the dev panel's switch")
	var sw: Array = DebugApi.view_switches[&"blade_held"]
	assert_eq(sw[0], "UI_DEV_BLADE_HELD")
	assert_ne(tr("UI_DEV_BLADE_HELD"), "UI_DEV_BLADE_HELD", "its text is translated")
	(sw[1] as Callable).call()
	assert_true(ViewPrefs.blade_held, "flipped on")
	assert_true((sw[2] as Callable).call())
	assert_string_contains(DevPanel.switch_text(), "blade_held on")
	(sw[1] as Callable).call()
	assert_false(ViewPrefs.blade_held, "and off again")


func test_the_gun_and_a_dead_hero_keep_the_arms_at_rest() -> void:
	ViewPrefs.blade_held = true
	var v := _views()
	var a: PlayerAvatar = v[1]
	var s := {
		"tick": 1,
		"pos": Vector2.ZERO,
		"aim": 0,
		"dashing": false,
		"swing_t": 0,
		"swing_ticks": 14,
		"swing_angle": 0,
		"combo": 0,
		"guarding": false,
		"dead": false,
		"gun": false,
	}
	a.apply_state(s)
	a.advance(DT)
	assert_true(a.arms.carrying(), "the Blade build carries it")
	s["gun"] = true
	a.apply_state(s)
	a.advance(DT)
	assert_false(a.arms.visible, "the Gun: the arms stay under the poncho")
	assert_false(a.arms.carrying())
	s["gun"] = false
	s["dead"] = true
	a.apply_state(s)
	a.advance(DT)
	assert_false(a.arms.visible, "dead: no arms, no sword")
	assert_false(a.arms.carrying())


func test_reduced_motion_drops_the_arms_at_once() -> void:
	ViewPrefs.reduced_motion = true
	var w := _world_at(0)
	var r := WorldReader.new(w)
	var v := _views()
	var kit: KitView = v[0]
	var a: PlayerAvatar = v[1]
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	while r.swing_tick() > 0:
		_draw(r, kit, a)
		_assert_gripped(r, kit, a, "calm, tick %d" % r.swing_tick())
		w.step(InputFrame.new())
	_draw(r, kit, a)
	assert_false(a.arms.visible, "no easing: hidden the tick the sword is gone")


func test_without_the_model_no_arms_and_no_sword_show() -> void:
	BossPieceModels.dir = "res://tests/fixtures/no_such_dir/"
	BossPieceModels.clear_cache()
	ViewPrefs.blade_held = true
	var w := _world_at(0)
	var r := WorldReader.new(w)
	var v := _views()
	var kit: KitView = v[0]
	var a: PlayerAvatar = v[1]
	assert_false(kit.summoned.has_model())
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	while r.swing_tick() > 0:
		_draw(r, kit, a)
		assert_false(a.arms.visible, "the laser blade needs no hands")
		assert_false(a.arms.carrying())
		assert_true(kit.blade_visible(), "KitView's laser blade draws the swing")
		w.step(InputFrame.new())


func test_the_poncho_lifts_over_the_hands() -> void:
	var w := _world_at(0)
	var r := WorldReader.new(w)
	var v := _views()
	var kit: KitView = v[0]
	var a: PlayerAvatar = v[1]
	for k in 20:
		w.step(InputFrame.new())
		_draw(r, kit, a)
	var rest_front := a.cloak_hem()[0].y
	ViewPrefs.blade_held = true
	for k in 40:
		w.step(InputFrame.new())
		_draw(r, kit, a)
	assert_gt(a.cloak_hem()[0].y, rest_front + 0.06, "the front hem drapes over the arms")
	var back := a.arms.lifted(Vector3(-0.3, 0.4, 0.0))
	assert_almost_eq(back.y, 0.4, 0.0001, "the back hem stays where it hangs")


func test_it_reads_only() -> void:
	ViewPrefs.blade_held = true
	var a := _world_at(0)
	var b := _world_at(0)
	var r := WorldReader.new(a)
	var v := _views()
	for k in 40:
		var f := InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY if k % 12 == 0 else 0)
		a.step(f)
		b.step(f)
		_draw(r, v[0], v[1])
	assert_eq(a.state_hash(), b.state_hash(), "posing the arms changes nothing in the world")
