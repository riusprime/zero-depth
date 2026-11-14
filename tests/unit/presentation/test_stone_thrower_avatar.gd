extends GutTest
## v0.11.0 O17c (ENEMIES.md R4; owner 2026-11-08: the five models "animated as good as you can"): the Stone Thrower on
## the owner's model (StoneThrowerAvatar, StoneThrowerPoses): its parts load onto their joints, each clip moves the
## parts it should (the idle's breath, the walk's legs, the lift's arms and rock, the throw's release on the sim's
## throw tick, the recovery, the flinch, the death and the rock it drops), reduced motion is smaller, a missing model
## falls back to a code-made body on the same joints; on the VAT path its bake matches the live pose and a VAT avatar
## keeps the old one's drives; ActorViews draws it and plays its death; RuinsRocksViews flies the owner's rock from
## the hands along the sim's arc, tumbling, lands it in the pose it came down in (the impact) and lets it crumble.

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_STONE_THROWER

var _tables: Array[EnemyTable] = []
var _calm := false
var _vat := false


func before_all() -> void:
	_tables = CombatLab.tables()


func before_each() -> void:
	_calm = ViewPrefs.reduced_motion
	_vat = ViewPrefs.enemy_vat
	VatBake.clear_cache()


func after_each() -> void:
	ViewPrefs.reduced_motion = _calm
	ViewPrefs.enemy_vat = _vat
	EnemyModels.dir = EnemyModels.DIR
	EnemyModels.clear_cache()


func _avatar() -> StoneThrowerAvatar:
	var a := StoneThrowerAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


func _state(tick: int, state: int, st := -1, x := 0.0) -> Dictionary:
	var s := {"tick": tick, "pos": Vector2(x, 0), "state": state, "facing": Vector2.RIGHT}
	if st >= 0:
		s["state_ticks"] = st
	return s


func _run(a: StoneThrowerAvatar, frames: int) -> void:
	for k in frames:
		a.advance(DT)
		a.advance_flinch(DT)


## Idles `a` for `n` ticks from tick `t0`; returns the next tick.
func _idle(a: StoneThrowerAvatar, t0: int, n: int) -> int:
	var t := t0
	for k in n:
		t += 1
		a.apply_state(_state(t, WorldReader.STATE_MOVE))
		_run(a, 1)
	return t


## Runs the attack from tick `t0` up to `upto` ticks into `until` (WINDUP, ACTIVE or RECOVER); returns the next tick.
func _attack(a: StoneThrowerAvatar, t0: int, until: int, upto: int) -> int:
	var t := t0
	var order := [WorldReader.STATE_WINDUP, WorldReader.STATE_ACTIVE, WorldReader.STATE_RECOVER]
	var lengths := [
		StoneThrowerAvatar.TICKS.x, StoneThrowerAvatar.TICKS.y, StoneThrowerAvatar.TICKS.z
	]
	for o in order.size():
		var n: int = lengths[o] if order[o] != until else upto + 1
		for k in n:
			t += 1
			a.apply_state(_state(t, order[o], k))
			_run(a, 1)
		if order[o] == until:
			break
	return t


func test_the_model_s_parts_hang_on_their_joints() -> void:
	assert_true(EnemyModels.has_model(&"stone_thrower"), "the owner's model is installed")
	var parts: Dictionary = EnemyModels.get_model(&"stone_thrower")["parts"]
	for p in [
		&"body",
		&"head",
		&"arm_r",
		&"arm_l",
		&"fore_r",
		&"fore_l",
		&"hand_r",
		&"hand_l",
		&"leg_r",
		&"leg_l",
		&"rock"
	]:
		assert_true(parts.has(p), "part %s" % p)
	var a := _avatar()
	assert_true(a.has_model)
	assert_eq(a.head.get_child_count(), 1, "the head on its joint")
	assert_eq(a.rock.get_child_count(), 1, "the rock its own part")
	for k in 2:
		assert_eq(
			a.arms[k].get_child(a.arms[k].get_child_count() - 1).get_class(), "MeshInstance3D"
		)
		assert_eq(a.hands[k].get_child_count(), 1, "hand %d" % k)
		assert_eq(a.legs[k].get_child_count(), 1, "leg %d" % k)
	assert_eq(a.body_materials.size(), 3, "base, the bronze plates and the rock flash on a hit")
	var role := a.body_materials[1]
	assert_eq(role.albedo_color, StoneThrowerAvatar.ROLE, "the plates tinted tank bronze")
	assert_almost_eq(a.height, 1.6, 0.001)


func test_the_idle_breathes_and_the_walk_swings_the_legs() -> void:
	var a := _avatar()
	var t := _idle(a, 0, 30)
	var chest := []
	for k in 80:
		t = _idle(a, t, 1)
		chest.append(a.chest.scale.y)
	assert_gt(chest.max() - chest.min(), 0.02, "the chest heaves")
	assert_almost_eq(a.legs[0].rotation.z, 0.0, 0.001, "the legs still at rest")
	var swing := 0.0
	for k in 60:
		t += 1
		a.apply_state(_state(t, WorldReader.STATE_MOVE, -1, 1.8 * t * DT))
		_run(a, 1)
		swing = maxf(swing, absf(a.legs[0].rotation.z))
	assert_gt(a.walk_amount(), 0.8, "walking at its speed")
	assert_gt(swing, 0.3, "the legs swing on the stride")


func test_the_lift_rips_the_rock_and_holds_it_overhead_then_throws_on_the_tick() -> void:
	var a := _avatar()
	var t := _idle(a, 0, 30)
	var rest_hand := (a.hands[0].global_position as Vector3).y
	t = _attack(a, t, WorldReader.STATE_WINDUP, 8)
	assert_false(a.rock_lifted(), "no rock before the rip")
	for k in range(9, 48):
		t += 1
		a.apply_state(_state(t, WorldReader.STATE_WINDUP, k))
		_run(a, 1)
		if k == 16:
			assert_true(a.rock_lifted(), "ripped out of the floor by the dig")
			assert_lt(a.hands[0].global_position.y, 0.3, "the hands down at the floor")
	assert_true(a.rock_lifted(), "held to the throw")
	assert_gt(a.hands[0].global_position.y, rest_hand + 1.2, "the hands overhead (the tell)")
	var rock := a.rock_position()
	var grips := a.grip_points()
	assert_almost_eq(
		rock, (grips[0] + grips[1]) * 0.5, Vector3(0.001, 0.001, 0.001), "between the hands"
	)
	assert_almost_eq(
		rock,
		StoneThrowerAvatar.RELEASE_AT,
		Vector3(0.06, 0.06, 0.1),
		"where the views start its flight"
	)
	assert_gt(
		a.visor_energy(), StoneThrowerAvatar.VISOR_REST * 2.0, "the visor flares through the lift"
	)
	# never released a frame early: the frame clock waits for the sim's throw tick
	_run(a, 4)
	assert_true(a.rock_lifted(), "still held between the last lift tick and the throw tick")
	t += 1
	a.apply_state(_state(t, WorldReader.STATE_ACTIVE, 0))
	_run(a, 1)
	assert_false(a.rock_lifted(), "it leaves the hands on the throw tick")
	var lean_top: float = a.torso.rotation.z
	for k in range(1, 12):
		t += 1
		a.apply_state(_state(t, WorldReader.STATE_ACTIVE, k))
		_run(a, 1)
	assert_lt(a.torso.rotation.z, lean_top - 0.6, "folded into the follow-through")
	assert_lt(a.arms[0].rotation.z, 0.0, "the arms down past the knees")


func test_the_recovery_returns_to_rest() -> void:
	var a := _avatar()
	var t := _idle(a, 0, 30)
	t = _attack(a, t, WorldReader.STATE_RECOVER, StoneThrowerAvatar.TICKS.z - 1)
	t = _idle(a, t, 30)
	assert_lt(a.attack_time(), 0.0, "the attack's clock stops")
	assert_lt(absf(a.arms[0].rotation.z), 0.15, "the arms hang again")
	assert_almost_eq(a.torso.rotation.z, -0.16, 0.08, "hunched as at rest")


func test_a_hit_snaps_the_head_back_and_flares_the_arms() -> void:
	var a := _avatar()
	_idle(a, 0, 30)
	var nod: float = a.head.rotation.z
	var spread: float = a.arms[0].rotation.x
	a.flinch(Vector2(-1, 0), 1.0)
	_run(a, 3)
	assert_gt(a.head.rotation.z, nod + 0.1, "the head snaps back")
	assert_lt(a.arms[0].rotation.x, spread - 0.05, "the right arm flares out")


func test_the_death_kneels_topples_and_drops_a_held_rock() -> void:
	var a := _avatar()
	var t := _idle(a, 0, 30)
	t = _attack(a, t, WorldReader.STATE_WINDUP, 40)
	assert_true(a.rock_lifted())
	var held := a.rock_position()
	assert_true(a.die(), "it plays its death")
	_run(a, 40)
	assert_lt(a.hips.position.y, StoneThrowerAvatar.PELVIS.y - 0.25, "on its knees")
	_run(a, 50)
	assert_lt(a.rock_position().y, held.y - 1.0, "the rock fell")
	assert_almost_eq(
		a.rock_position().y, 0.38 * StoneThrowerAvatar.ROCK_SCALE, 0.15, "on the floor"
	)
	assert_lt(a.vat_lift(), 0.0, "sinking at the end")
	assert_lt(a.get_node("Body").transform.basis.y.y, 0.3, "toppled forward")


func test_reduced_motion_is_smaller() -> void:
	var amp := {}
	for calm in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _avatar()
		var t := _idle(a, 0, 10)
		var lo := 99.0
		var hi := -99.0
		for k in 150:
			t = _idle(a, t, 1)
			lo = minf(lo, a.chest.scale.y)
			hi = maxf(hi, a.chest.scale.y)
		# the strain's shudder: the torso's wobble over the last ticks of the lift
		t = _attack(a, t, WorldReader.STATE_WINDUP, 38)
		var wob := []
		for k in range(39, 48):
			t += 1
			a.apply_state(_state(t, WorldReader.STATE_WINDUP, k))
			for f in 4:
				a.advance(DT / 4.0)
				wob.append(a.torso.rotation.z)
		amp[calm] = [hi - lo, wob.max() - wob.min()]
	assert_lt(amp[true][0], amp[false][0] * 0.7, "a smaller breath: %s" % [amp])
	assert_lt(amp[true][1], amp[false][1], "no strain shudder: %s" % [amp])


func test_a_missing_model_falls_back_to_a_code_body_on_the_same_joints() -> void:
	EnemyModels.dir = "res://tests/nowhere/"
	EnemyModels.clear_cache()
	var a := _avatar()
	assert_false(a.has_model)
	assert_gt(a.chest.get_child_count(), 0, "a code-made chest")
	assert_gt(a.rock.get_child_count(), 0, "a code-made rock")
	var t := _idle(a, 0, 20)
	t = _attack(a, t, WorldReader.STATE_WINDUP, 40)
	assert_true(a.rock_lifted(), "it still lifts a rock")
	assert_eq(a.vat_texture(), null, "no colour map")
	assert_eq(
		RuinsRocksViews.new()._boulder().has_meta(&"owner_rock"),
		false,
		"the views fly the kit's boulder"
	)


func test_the_vat_bake_matches_the_live_pose() -> void:
	assert_true(VatCrowd.supports(KIND), "on the VAT crowd")
	assert_true(SoloVat.is_solo(KIND))
	for calm in [false, true]:
		ViewPrefs.reduced_motion = calm
		var pose := VatBake.pose_for(KIND)
		var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
		var vat := VatBake.vat_avatar_of(KIND)
		var e := VatVerify.pose_error(live, vat, pose, mesh, 60, 7)
		assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
		assert_lt(float(e["max_m"]), 0.002, "well under a pixel (calm %s): %s" % [calm, e])
		assert_true(pose.has("albedo_tex"), "the model's colour map (the textured look)")
		live.free()
		vat.free()


func test_a_vat_avatar_keeps_the_old_drives_lift_and_glow() -> void:
	var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(KIND)
	add_child_autofree(live)
	add_child_autofree(vat)
	live.set_process(false)
	vat.set_process(false)
	assert_eq(vat.find_children("*", "MeshInstance3D", true, false).size(), 0, "no pieces")
	var plan := [
		[WorldReader.STATE_MOVE, 40], [WorldReader.STATE_WINDUP, 48], [WorldReader.STATE_ACTIVE, 37]
	]
	plan.append([WorldReader.STATE_RECOVER, 48])
	var t := 0
	for p: Array in plan:
		for k in int(p[1]):
			t += 1
			for a: Node in [live, vat]:
				a.call(&"apply_state", _state(t, p[0], k, 0.02 * t))
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)


func test_actor_views_draw_it_and_play_its_death() -> void:
	ViewPrefs.enemy_vat = false
	var w := World.new(5, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = 1 << 24
	var id := w.add_enemy(ActorStore.Kind.STONE_THROWER, Vector2(6, 0))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	var reader := WorldReader.new(w)
	views.sync(reader)
	var node := views.actor_node(id)
	assert_not_null(node)
	var av: Variant = node.get_meta(&"enemy_avatar")
	assert_true(av is StoneThrowerAvatar, "drawn by its own avatar")
	w.actors.dead[w.actors.index_of(id)] = 1
	w.step(InputFrame.new())
	views.sync(reader)
	assert_null(views.actor_node(id), "gone from the sim's views")
	assert_false(node.is_queued_for_deletion(), "but still drawing its death")
	assert_true((av as StoneThrowerAvatar).dying(), "it kneels and topples")
	await wait_seconds(StoneThrowerAvatar.DEATH_SECONDS + 0.3)
	assert_false(is_instance_valid(node), "then freed")


func test_the_views_fly_the_owners_rock_land_it_and_let_it_crumble() -> void:
	var w := World.new(11, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = 1 << 24
	var id := w.add_enemy(ActorStore.Kind.STONE_THROWER, Vector2(7, 0))
	var v := RuinsRocksViews.new()
	add_child_autofree(v)
	var flew := false
	var first_y := -1.0
	var top := 0.0
	var turned := false
	var start := Basis()
	for k in 900:
		var i := w.actors.index_of(id)
		var busy := [EnemyAi.State.WINDUP, EnemyAi.State.ACTIVE, EnemyAi.State.RECOVER]
		if i >= 0 and w.actors.state[i] in busy:
			w.actors.set_pos(0, Vector2(0, 3))  # out of the ring once it has aimed
		w.step(InputFrame.new())
		v.sync(WorldReader.new(w))
		if v.flying_count() > 0:
			var mi: MeshInstance3D = v.get("_flying").values()[0]
			if not flew:
				flew = true
				first_y = mi.position.y
				start = mi.basis.orthonormalized()
			top = maxf(top, mi.position.y)
			turned = turned or mi.basis.orthonormalized().x.dot(start.x) < 0.5
			assert_true(mi.has_meta(&"owner_rock"), "the owner's rock flies")
		if v.rock_count() > 0:
			break
	assert_true(flew, "the rock flew")
	assert_almost_eq(first_y, StoneThrowerAvatar.RELEASE_AT.y, 0.2, "from the hands overhead")
	assert_gt(top, first_y + 0.5, "on its arc")
	assert_true(turned, "tumbling")
	assert_eq(v.rock_count(), 1, "it stands")
	assert_eq(v.settling_count(), 1, "the landing's squash plays")
	assert_gt(RuinsRocksViews.land_squash(0.05, false), 0.1, "flattened by the hit")
	assert_gt(
		RuinsRocksViews.land_squash(0.05, false),
		RuinsRocksViews.land_squash(0.05, true),
		"smaller calm"
	)
	for k in 40:
		await get_tree().process_frame
	assert_eq(v.settling_count(), 0, "settled")
	var rock: MeshInstance3D = v.get("_rocks")[0]
	var stood := rock.position.y
	var t := w.enemy_table(ActorStore.Kind.STONE_THROWER)
	var guard := 0
	while (
		WorldReader.new(w).thrown_rocks().size() > 0
		and int(WorldReader.new(w).thrown_rocks()[0][2]) > 8
	):
		var i := w.actors.index_of(id)
		if i >= 0:
			w.actors.cd[i] = 60  # (no second throw: the cap would swap the rocks)
		w.step(InputFrame.new())
		guard += 1
		if guard > t.rock_ticks + 10:
			break
	v.sync(WorldReader.new(w))
	assert_lt(rock.position.y, stood - 0.05, "cracking down into the floor at its end")
