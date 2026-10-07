extends GutTest
## Hit feel (PLAN v0.1.0 Step 6): shake off means none at all; damage flashes the actor; hit-stop per event.


func test_shake_off_means_none() -> void:
	var rig := IsoRig.new()
	add_child_autofree(rig)
	rig.shake_enabled = false
	rig.shake(1.0)
	assert_eq(rig.shake_level(), 0.0)
	rig.shake_enabled = true
	rig.shake(0.5)
	assert_gt(rig.shake_level(), 0.0)


func test_a_landed_swing_freezes_three_ticks_and_a_hit_on_you_four() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	w.add_dummy(Vector2(1.2, 0), 0.35, 500)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY))
	var seen := 0
	for i in 6:
		w.step(InputFrame.new())
		seen = maxi(seen, w.freeze_ticks)
	assert_eq(seen, w.player.step(0).hitstop_ticks)
	var v := World.new(3, PlayerTable.starting_values())
	Damage.hit(v, 0, 5, 9, 9, 9, 0, Vector2(3, 0), Vector2.ZERO)
	assert_eq(v.freeze_ticks, v.player.hurt_freeze_ticks)


func test_damage_flashes_the_actor_view() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	var id := w.add_dummy(Vector2(1.2, 0), 0.35, 500)
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var feel := HitFeel.new(views, rig)
	add_child_autofree(feel)
	views.sync(reader)
	Damage.hit(w, 1, 5, 1, 1, 1, 0, Vector2.ZERO, Vector2(1.2, 0))
	feel.sync(reader)
	assert_true(views.is_flashing(id))
