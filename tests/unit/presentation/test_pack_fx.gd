extends GutTest
## v0.10.0 VX0 (VFX_PACK I2, I3, I5, I6, I8, I9): PackFx, the one pooled way to spawn a pack effect: the caps per
## family and the oldest reused past one, the density scale, the lights off, the colours, the return to the pool after
## an effect's life, the warm-up and the pause.

const EXPLOSION := &"explosion_fire_a"
const SMOKE := &"smoke_after"

var _saved_density := ""


func before_each() -> void:
	_saved_density = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"


func after_each() -> void:
	ViewPrefs.effects_density = _saved_density


func _fx() -> PackFx:
	return add_child_autofree(PackFx.new())


func test_the_table_is_found_and_valid() -> void:
	assert_true(PackFx.available(), "data/vfx/pack_fx.tres is discovered")
	var fx := _fx()
	for id: StringName in [EXPLOSION, &"explosion_fire_b", &"explosion_fire_c", SMOKE]:
		assert_true(fx.has_id(id), "%s is in the table" % id)
	assert_null(fx.spawn(&"no_such_effect", Vector3.ZERO), "an unknown id spawns nothing")


func test_a_spawn_is_placed_scaled_and_shown() -> void:
	var fx := _fx()
	var n := fx.spawn(EXPLOSION, Vector3(3, 0, -2), 2.0)
	assert_not_null(n)
	assert_true(n.visible)
	assert_eq(n.global_position, Vector3(3, 0, -2))
	assert_eq(n.scale, Vector3.ONE * 2.0)
	assert_eq(fx.live_count(&"explosion"), 1)
	assert_eq(fx.live_count(&"cloud"), 0)


func test_the_family_cap_holds_and_the_oldest_is_reused() -> void:
	var fx := _fx()
	var first := fx.spawn(EXPLOSION, Vector3.ZERO)
	for k in 11:
		fx.spawn(EXPLOSION, Vector3(k, 0, 0))
	assert_eq(fx.live_count(&"explosion"), PackFx.CAPS[&"explosion"], "at the cap")
	var next := fx.spawn(EXPLOSION, Vector3(50, 0, 0))
	assert_eq(fx.live_count(&"explosion"), PackFx.CAPS[&"explosion"], "still at the cap")
	assert_eq(next, first, "the oldest instance is the one reused")
	assert_eq(fx.pooled(EXPLOSION), PackFx.CAPS[&"explosion"], "no thirteenth scene was made")
	assert_eq(fx.reused, 1)


func test_the_cap_counts_the_family_not_the_id() -> void:
	var fx := _fx()
	var a := fx.spawn(EXPLOSION, Vector3.ZERO)
	for k in 12:
		fx.spawn(&"explosion_fire_b", Vector3(k, 0, 0))
	assert_eq(fx.live_count(&"explosion"), 12)
	assert_false(a.visible, "the oldest, of another id, went back to its pool")


func test_density_scales_the_caps_rounded_up_and_never_below_one() -> void:
	var fx := _fx()
	ViewPrefs.effects_density = "low"
	assert_eq(fx.cap_for(&"explosion"), 3, "12 x 0.25")
	assert_eq(fx.cap_for(&"cloud"), 1, "4 x 0.25")
	ViewPrefs.effects_density = "medium"
	assert_eq(fx.cap_for(&"explosion"), 7, "12 x 0.55 = 6.6 up")
	assert_eq(fx.cap_for(&"cloud"), 3, "4 x 0.55 = 2.2 up")
	ViewPrefs.effects_density = "high"
	assert_eq(fx.cap_for(&"explosion"), 12)
	assert_eq(fx.cap_for(&"projectile"), 96)
	ViewPrefs.effects_density = "low"
	for k in 6:
		fx.spawn(EXPLOSION, Vector3(k, 0, 0))
	assert_eq(fx.live_count(&"explosion"), 3, "the low cap holds in play")


func test_every_light_is_off() -> void:
	var fx := _fx()
	for id: StringName in [EXPLOSION, &"explosion_fire_b", &"explosion_fire_c", SMOKE]:
		var n := fx.spawn(id, Vector3.ZERO)
		for l in n.find_children("*", "Light3D", true, false):
			assert_false((l as Light3D).visible, "%s: %s is hidden" % [id, l.name])
		if "light_enable" in n:
			assert_false(n.get("light_enable"), "%s: the controller's light is off" % id)


func test_colours_are_applied_and_the_scenes_own_come_back() -> void:
	var fx := _fx()
	var n := fx.spawn(EXPLOSION, Vector3.ZERO)
	var own: Color = n.get("primary_color")
	fx.advance(10.0)  # back to the pool
	var red := Color(1, 0, 0)
	var blue := Color(0, 0, 1)
	var m := fx.spawn(EXPLOSION, Vector3.ZERO, 1.0, {&"primary": red, &"tertiary": blue})
	assert_eq(m, n, "the pooled instance")
	assert_eq(m.get("primary_color"), red)
	assert_eq(m.get("tertiary_color"), blue)
	fx.advance(10.0)
	var again := fx.spawn(EXPLOSION, Vector3.ZERO)
	assert_eq(again.get("primary_color"), own, "no colour asked: the scene's own")


func test_an_instance_returns_to_its_pool_after_its_life() -> void:
	var fx := _fx()
	var n := fx.spawn(EXPLOSION, Vector3.ZERO)
	fx.advance(0.3)
	assert_eq(fx.live_count(), 1, "still playing")
	fx.advance(5.0)
	assert_eq(fx.live_count(), 0, "its life is over")
	assert_false(n.visible, "hidden in its pool")
	assert_eq(fx.pooled(EXPLOSION), 1)
	assert_eq(fx.spawn(EXPLOSION, Vector3.ZERO), n, "and reused by the next spawn")


func test_smoke_without_an_animation_also_ends() -> void:
	var fx := _fx()
	var n := fx.spawn(SMOKE, Vector3.ZERO)
	assert_eq(fx.live_count(&"cloud"), 1)
	fx.advance(20.0)
	assert_eq(fx.live_count(&"cloud"), 0)
	assert_false(n.visible)


func test_warm_all_spawns_every_id_once_and_leaves_none_live() -> void:
	var fx := _fx()
	fx.warm_all()
	var ids := fx.warm_ids().size()  # (every VX step adds rows: no fixed count)
	assert_gte(ids, 4)
	assert_eq(fx.spawned, ids, "every id spawned once")
	assert_gt(
		fx.live_count(), 0, "they are up for the warm-up frames (a full family reuses its oldest)"
	)
	await wait_frames(PackFx.WARM_FRAMES + 2)
	assert_eq(fx.live_count(), 0, "and none after them")
	assert_eq(fx.pooled(EXPLOSION), 1, "kept in their pools")


func test_warm_one_id_at_a_time_for_a_queue() -> void:
	var fx := _fx()
	assert_gte(fx.warm_ids().size(), 4, "every id of the table")
	fx.warm(SMOKE)
	assert_eq(fx.live_count(&"cloud"), 1, "only that one is up")
	assert_eq(fx.live_count(&"explosion"), 0)
	await wait_frames(PackFx.WARM_FRAMES + 2)
	assert_eq(fx.live_count(), 0, "and it goes back after its frames")


func test_a_pause_stops_the_effects_and_a_resume_runs_them() -> void:
	var fx := _fx()
	var n := fx.spawn(EXPLOSION, Vector3.ZERO)
	assert_eq(n.get("speed_scale"), 1.0)
	fx.set_held(true)
	assert_eq(n.get("speed_scale"), 0.0, "held: speed_scale 0")
	var m := fx.spawn(&"explosion_fire_b", Vector3.ZERO)
	assert_eq(m.get("speed_scale"), 0.0, "one spawned while held starts held")
	fx.advance(10.0)
	assert_eq(fx.live_count(), 2, "a held effect does not age")
	fx.set_held(false)
	assert_eq(n.get("speed_scale"), 1.0, "resumed")
	assert_eq(m.get("speed_scale"), 1.0)


func test_follow_sees_a_tick_that_stopped_as_a_pause() -> void:
	var fx := _fx()
	fx.spawn(EXPLOSION, Vector3.ZERO)
	fx.follow(100.0)
	assert_false(fx.is_held())
	await wait_seconds(PackFx.HOLD_S + 0.1)
	fx.follow(100.4)  # the same tick, a while later
	assert_true(fx.is_held(), "no new tick for HOLD_S")
	fx.follow(101.0)
	assert_false(fx.is_held(), "a new tick runs it again")


## v0.10.0 lead: life 0 holds an effect until the caller's release(); has_room says whether a family has a free slot.
func test_a_held_effect_stays_until_released_and_has_room_reads_the_cap() -> void:
	var fx := _fx()
	var n := fx.spawn(SMOKE, Vector3.ZERO, 1.0, {}, 0.0)
	fx.advance(1000.0)
	assert_true(n.visible, "life 0: still live after any time")
	assert_eq(fx.live_count(&"cloud"), 1)
	fx.release(n)
	assert_false(n.visible, "release() returns it to its pool")
	assert_eq(fx.live_count(&"cloud"), 0)
	for k in fx.cap_for(&"cloud"):
		assert_true(fx.has_room(&"cloud"))
		fx.spawn(SMOKE, Vector3.ZERO, 1.0, {}, 0.0)
	assert_false(fx.has_room(&"cloud"), "full at the cap")


## v0.10.0 lead: two instances of one scene recolour on their own (each has its own material copies).
func test_two_instances_of_one_scene_keep_their_own_colours() -> void:
	var fx := _fx()
	var a := fx.spawn(SMOKE, Vector3.ZERO, 1.0, {"primary": Color.RED}, 0.0)
	var b := fx.spawn(SMOKE, Vector3(2, 0, 0), 1.0, {"primary": Color.BLUE}, 0.0)
	assert_true(fx.is_live(a) and fx.is_live(b))
	var ma := _first_material(a)
	var mb := _first_material(b)
	assert_not_null(ma)
	assert_ne(ma, mb, "each instance has its own material")
	fx.release(a)
	assert_false(fx.is_live(a), "released: not live")


func _first_material(n: Node) -> Material:
	if n is GeometryInstance3D and (n as GeometryInstance3D).material_override != null:
		return (n as GeometryInstance3D).material_override
	for c in n.get_children():
		var m := _first_material(c)
		if m != null:
			return m
	return null
