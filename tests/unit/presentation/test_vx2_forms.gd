extends GutTest
## v0.10.0 VX2 (VFX_PACK R1-R13): the hero's shots and forms draw with the pack. Each replaced effect spawns its pack
## id in the element's colours; a held bolt effect follows the bolt and is released when the bolt ends; a full family
## keeps the old look (and never takes a live one over); no pack keeps the old look.

const W := preload("res://tests/support/mx4_world.gd")

var _fx: PackFx


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_fx = add_child_autofree(PackFx.new())


func after_each() -> void:
	ViewPrefs.effects_density = "medium"


func _fill(id: StringName, family: StringName) -> void:
	for k in _fx.cap_for(family):
		_fx.spawn(id, Vector3(k, 0, 0), 1.0, {}, 0.0)


func test_colours_follow_the_elements() -> void:
	var none := PackLooks.colors(PackedStringArray())
	assert_eq(none[&"primary"], ElementLooks.energy_core())
	assert_eq(none[&"tertiary"], ElementLooks.energy_deep())
	var two := PackLooks.colors(PackedStringArray(["ember", "frost"]))
	assert_eq(two[&"primary"], ElementLooks.core(&"ember"), "the first element's core")
	assert_eq(two[&"secondary"], ElementLooks.hot(&"frost"), "the second element's hot centre")
	assert_eq(two[&"tertiary"], ElementLooks.deep(&"ember"))
	assert_eq(PackLooks.id_of("bolt", &""), &"vx2_bolt_storm", "a plain shot is the blue scene")
	assert_eq(PackLooks.laser_id(&"void"), &"vx2_laser_void")
	assert_eq(PackLooks.laser_id(&"venom"), &"vx2_laser_venom")


func test_every_vx2_row_exists() -> void:
	for kind in ["bolt", "jav", "small", "big", "flare", "laser"]:
		for e in [&"ember", &"frost", &"venom", &"storm", &"bleed", &""]:
			assert_true(_fx.has_id(PackLooks.id_of(kind, e)), "%s %s" % [kind, e])
	for id in [
		&"vx2_laser_void",
		&"vx2_laser_venom",
		&"vx2_muzzle_big",
	]:
		assert_true(_fx.has_id(id), String(id))
	for id in [
		&"vx2_rune_dome", &"vx2_hit_rune", &"vx2_hit_crit", &"vx2_hit_bounce", &"vx2_lob_body"
	]:
		assert_true(_fx.has_id(id), String(id))


func test_a_hold_follows_and_is_released_when_unseen() -> void:
	var hold := FormPackHold.new()
	hold.pack = _fx
	hold.begin()
	var n := hold.put(
		5,
		&"vx2_bolt_venom",
		&"projectile",
		Transform3D(Basis.IDENTITY, Vector3(1, 0, 2)),
		{&"primary": Color.RED}
	)
	assert_not_null(n)
	assert_eq(n.get("primary_color"), Color.RED, "spawned in the asked colour")
	hold.end()
	assert_eq(_fx.live_count(&"projectile"), 1)
	hold.begin()
	hold.put(5, &"vx2_bolt_venom", &"projectile", Transform3D(Basis.IDENTITY, Vector3(3, 0, 4)))
	hold.end()
	assert_eq(_fx.live_count(&"projectile"), 1, "the same effect, moved")
	assert_eq(n.global_position, Vector3(3, 0, 4))
	var anim := n.get_node("AnimationPlayer") as AnimationPlayer
	assert_eq(anim.get_animation(PackFx.ANIM).loop_mode, Animation.LOOP_LINEAR, "held scenes loop")
	hold.begin()
	hold.end()
	assert_eq(_fx.live_count(&"projectile"), 0, "released when the thing ended")


func test_a_full_family_keeps_the_old_look_and_a_live_one_is_kept() -> void:
	var hold := FormPackHold.new()
	hold.pack = _fx
	hold.begin()
	var xf := Transform3D()
	assert_not_null(hold.put(1, &"vx2_bolt_storm", &"projectile", xf))
	_fill(&"vx2_bolt_storm", &"projectile")
	assert_false(_fx.has_room(&"projectile"))
	assert_null(
		hold.put(2, &"vx2_bolt_storm", &"projectile", xf), "a new one finds no room: the old look"
	)
	assert_true(hold.refused(2))
	assert_not_null(
		hold.put(1, &"vx2_bolt_storm", &"projectile", xf), "the live one keeps its effect"
	)
	assert_null(hold.put(2, &"vx2_bolt_storm", &"projectile", xf), "and stays old for its flight")


func test_shots_in_flight_are_pack_projectiles_that_end_with_the_shot() -> void:
	var view: HeroPulseViews = add_child_autofree(HeroPulseViews.new())
	view.pack_fx = _fx
	var w := W.world(&"gun", [], [[Vector2(6.0, 0.0), 100000]])
	var r := WorldReader.new(w)
	W.run(w, 2, 0, W.S)
	view.sync(r)
	assert_gt(view.count(), 0)
	assert_eq(view.hold.count(), 0, "S10: a plain shot (no element) keeps its pulse")
	assert_eq(view.ball_count(view.looks()[0]), view.count())
	for id: int in view._pk.keys():  # an element shot's pack effect (the elements need the form view: set by hand)
		view._pk[id] = [&"vx2_bolt_storm", {}, 3.2]
	view._draw(1.0)
	assert_eq(view.hold.count(), view.count(), "every shot has its effect")
	W.run(w, 90, 0, 0)
	view.sync(r)
	view._draw(1.0)
	assert_eq(view.hold.count(), 0, "released when the shots ended")
	assert_eq(_fx.live_count(&"projectile"), 0)


func test_shots_keep_the_pulse_when_the_family_is_full() -> void:
	var view: HeroPulseViews = add_child_autofree(HeroPulseViews.new())
	view.pack_fx = _fx
	_fill(&"vx2_bolt_storm", &"projectile")
	var w := W.world(&"gun", [], [[Vector2(6.0, 0.0), 100000]])
	W.run(w, 2, 0, W.S)
	view.sync(WorldReader.new(w))
	assert_gt(view.count(), 0)
	assert_eq(view.hold.count(), 0, "no room: the pulse draws them")
	assert_gt(view.part(view.looks()[0], &"core").multimesh.visible_instance_count, 0)


func test_without_a_pack_the_pulses_draw() -> void:
	var view: HeroPulseViews = add_child_autofree(HeroPulseViews.new())
	var w := W.world(&"gun", [], [[Vector2(6.0, 0.0), 100000]])
	W.run(w, 2, 0, W.S)
	view.sync(WorldReader.new(w))
	assert_eq(view.hold.count(), 0)
	assert_gt(view.part(view.looks()[0], &"core").multimesh.visible_instance_count, 0)


func test_seekers_are_javelins_held_on_the_darts() -> void:
	var view: SeekersView = add_child_autofree(SeekersView.new())
	view.pack_fx = _fx
	var w := W.world(&"gun", [&"gun_seekers"])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	view.sync(r)
	assert_eq(view.hold.count(), 3)
	assert_eq(_fx.pooled(&"vx2_jav_storm"), 3)
	W.run(w, 80, 0, 0)
	view.sync(r)
	assert_eq(view.hold.count(), 0, "released with the darts")


## v0.10.0 FX: the laser went back to its own ribbons (a bent beam was a pack scene per leg, each with a flare).
func test_the_laser_draws_no_pack_beam() -> void:
	var view: LaserView = add_child_autofree(LaserView.new())
	view.pack_fx = _fx
	var w := W.world(&"gun", [&"gun_laser"], [[Vector2(4.0, 0.0), 100000]])
	var r := WorldReader.new(w)
	W.run(w, 3, 0, W.S)
	view.sync(r)
	assert_eq(view.shown, 1, "the ribbon draws")
	assert_eq(_fx.live_count(&"beam"), 0, "no pack beam")


## v0.10.0 FX (owner: "restore the previous Void"): no pack orb or flash; the old body draws.
func test_void_shots_draw_no_pack_effect() -> void:
	var view: VoidView = add_child_autofree(VoidView.new())
	view.pack_fx = _fx
	var w := W.world(&"gun", [&"gun_void"])
	var r := WorldReader.new(w)
	W.run(w, 2, 0, W.S)
	view.sync(r)
	assert_eq(view.hold.count(), 0)
	W.run(w, 200, 0, 0)
	view.sync(r)
	assert_eq(_fx.spawned, 0, "no body, no collapse flash")


func test_the_rune_explosion_has_a_pack_dome() -> void:
	var view: RuneExplosionView = add_child_autofree(RuneExplosionView.new())
	view.pack_fx = _fx
	var w := W.world(&"gun", [&"gun_rune_explosion"])
	w.add_dummy(Vector2(2.0, 0.0), 0.35, 1000000)
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	W.run(w, 10, 0, 0)
	view.sync(r)
	assert_eq(view.hold.count(), 1)
	assert_eq(_fx.live_count(&"area"), 1)


func test_the_wisps_are_pack_orbs() -> void:
	var view: WispsView = add_child_autofree(WispsView.new())
	view.pack_fx = _fx
	var w := W.world(&"gun", [&"gun_wisps"])
	W.run(w, 5, 0, 0)
	view.sync(WorldReader.new(w))
	assert_gt(view.wisps, 0)
	assert_eq(view.hold.count(), view.wisps)


func test_crit_and_bounce_flashes_are_pack_hits_and_fall_back_when_full() -> void:
	var canvas: AttackFormCanvas = add_child_autofree(AttackFormCanvas.new())
	canvas.pack_fx = _fx
	canvas.flash(Vector2.ZERO, AttackFormLooks.CRIT_FLASH, 0.8, -1.0, &"crit")
	assert_eq(_fx.pooled(&"vx2_hit_crit"), 1)
	canvas.flash(Vector2.ONE, Color.CYAN, 0.55, -1.0, &"bounce")
	assert_eq(_fx.pooled(&"vx2_hit_bounce"), 1)
	assert_eq(canvas.effect_count(), 0, "no old flash")
	_fill(&"vx2_hit_crit", &"hit")
	canvas.flash(Vector2.ZERO, Color.WHITE, 0.8, -1.0, &"crit")
	assert_eq(canvas.effect_count(), 1, "the old flash when the family is full")


func test_zone_ground_colours_pass_ground_safe() -> void:
	var canvas: AttackFormCanvas = add_child_autofree(AttackFormCanvas.new())
	canvas.pack_fx = _fx
	var look := {"elements": ["ember"]}
	assert_true(canvas.forms_pack.ground(1, &"vx2_zone_basic", Vector3.ZERO, 1.0, look))
	var n := canvas.forms_pack.hold.node(1 * 8 + 2)
	assert_eq(n.get("primary_color"), AttackFormLooks.ground_safe(ElementLooks.core(&"ember")))


func test_the_trigger_sigil_is_a_magic_area_and_orbiters_are_pack_orbs() -> void:
	var canvas: AttackFormCanvas = add_child_autofree(AttackFormCanvas.new())
	canvas.pack_fx = _fx
	canvas.flash(Vector2.ZERO, AttackFormLooks.CAST_SIGIL, 0.75, -1.0, &"sigil")
	assert_eq(canvas.forms_pack.sigils, 1)
	assert_true(canvas.forms_pack.orbiter(3, Vector3.ZERO, 0.1, {"elements": ["venom"]}))
	assert_eq(_fx.pooled(&"vx2_small_venom"), 1)
