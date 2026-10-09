extends GutTest
## The player's hooded wanderer (v0.2.0 G): its parts, the visor following the aim, the cloak springs settling,
## flaring on a dash, and the slump on death. Presentation only: these drive it through WorldReader or plain
## state, and step its frame-time animation by hand.

const DT := 1.0 / 60.0


func _avatar() -> PlayerAvatar:
	var a := PlayerAvatar.new()
	a.setup(Color("#1A1A22"))
	add_child_autofree(a)
	a.set_process(false)  # the test steps advance() itself
	return a


func _state(tick: int, pos: Vector2, extra: Dictionary = {}) -> Dictionary:
	var s := {
		"tick": tick,
		"pos": pos,
		"aim": 0,
		"dashing": false,
		"swing_t": 0,
		"swing_ticks": 14,
		"swing_angle": 0,
		"combo": 0,
		"guarding": false,
		"dead": false,
	}
	s.merge(extra, true)
	return s


## Runs `ticks` sim ticks moving at `vel` (m/s) from `from`, one advance(1/60) per tick; returns the end position.
func _run(
	a: PlayerAvatar, t0: int, from: Vector2, vel: Vector2, ticks: int, extra: Dictionary = {}
) -> Vector2:
	var p := from
	for k in ticks:
		p += vel / 60.0
		a.apply_state(_state(t0 + k + 1, p, extra))
		a.advance(DT)
	return p


func _horizontal_yaw(n: Node3D) -> float:
	var f := n.global_basis * Vector3.RIGHT
	return atan2(-f.z, f.x)


func test_builds_hood_visor_cloak_and_two_legs() -> void:
	var a := _avatar()
	assert_not_null(a.hood, "hood")
	assert_not_null(a.visor, "visor")
	assert_not_null(a.face, "dark face")
	assert_not_null(a.cloak, "cloak")
	assert_eq(a.legs.size(), 2, "two legs")
	assert_gt((a.cloak.mesh as ArrayMesh).get_surface_count(), 0, "the cloak has a mesh")
	var vm := a.visor.material_override as StandardMaterial3D
	assert_true(vm.emission_enabled, "the visor glows")
	assert_eq(vm.albedo_color, ThemePalette.color(&"player_core"), "in the player's cyan")
	assert_gt(a.body_materials.size(), 3, "hood, cloak and legs flash with the body")
	var top := a.hood.global_position.y
	assert_between(top, 0.8, 1.0, "the hood sits at head height")


func test_poncho_is_a_diamond_pointing_where_the_wanderer_faces() -> void:
	for aim in [0, 1024, 2600]:
		var a := _avatar()
		a.apply_state(_state(0, Vector2.ZERO, {"aim": aim}))
		var hem := a.cloak_hem()
		var front := hem[0]
		var off := wrapf(atan2(-front.z, front.x) - SimPlane.yaw_of(aim), -PI, PI)
		assert_almost_eq(off, 0.0, 0.02, "aim %d: the front corner points where it faces" % aim)
		for k in range(1, hem.size()):
			assert_lt(
				front.y, hem[k].y, "aim %d: the front corner hangs lowest (point %d)" % [aim, k]
			)
		var span := Vector2(hem[2].x - hem[6].x, hem[2].z - hem[6].z).length()
		var hood_w := (a.hood.get_child(0) as MeshInstance3D).get_aabb().size.z
		assert_between(span / hood_w, 1.8, 2.4, "aim %d: about twice the hood's width" % aim)
		var reach := Vector2(hem[2].x, hem[2].z).length()
		assert_gt(
			reach, Vector2(front.x, front.z).length(), "aim %d: side corners reach widest" % aim
		)


func test_visor_is_centred_and_landscape_in_the_upper_face() -> void:
	var a := _avatar()
	var v := (a.visor.mesh as BoxMesh).size
	assert_gt(v.z, v.y, "wider than tall")
	assert_almost_eq(a.visor.position.z, 0.0, 1e-6, "centred")
	var face := a.face.get_aabb()
	assert_gt(a.visor.position.y, face.position.y + face.size.y * 0.5, "in the face's upper half")
	assert_between(v.z / face.size.z, 0.3, 0.5, "about 40% of the face's width")


func test_xray_twins_only_with_the_xray_technique() -> void:
	var xray := _avatar()
	var plain := PlayerAvatar.new()
	plain.setup(Color.BLACK, &"outline")
	add_child_autofree(plain)
	assert_gt(_count_xray(xray), 1, "hood and cloak have an X-ray twin")
	assert_eq(_count_xray(plain), 0)


func _count_xray(n: Node) -> int:
	var c := 0
	for child in n.get_children():
		if child is MeshInstance3D:
			var m := (child as MeshInstance3D).material_override as StandardMaterial3D
			if m != null and m.stencil_mode == BaseMaterial3D.STENCIL_MODE_XRAY:
				c += 1
		c += _count_xray(child)
	return c


## v0.6.0 (owner, 2026-10-09): the body faces the movement, not the aim; a Blade hero turns to the aim only to
## swing. Walking east while aiming elsewhere faces east; a swing turns the visor to the swing's angle.
func test_visor_faces_the_movement_and_turns_to_swing() -> void:
	var w := CombatLab.world()
	var reader := WorldReader.new(w)
	var a := _avatar()
	for k in 40:
		w.step(InputFrame.make(Vector2i(127, 0), 2048, 300, 0, 0))  # walk east (sim +x), aim west
		a.sync(reader)
		a.advance(DT)
	var east := SimPlane.yaw_of(0)
	assert_almost_eq(
		wrapf(_horizontal_yaw(a.visor) - east, -PI, PI), 0.0, 0.1, "faces the movement"
	)
	w.step(InputFrame.make(Vector2i.ZERO, 1024, 300, 0, InputFrame.PRIMARY))
	for k in 8:
		a.sync(reader)
		a.advance(DT)
		w.step(InputFrame.make(Vector2i.ZERO, 1024, 300, 0, 0))
	var swing := SimPlane.yaw_of(reader.swing_angle())
	assert_almost_eq(
		wrapf(_horizontal_yaw(a.visor) - swing, -PI, PI),
		0.0,
		0.6,
		"a swing turns it to the swing (the twist of the slash adds its own turn)"
	)


func test_cloak_settles_after_motion_stops() -> void:
	var a := _avatar()
	a.apply_state(_state(0, Vector2.ZERO))
	var p := _run(a, 0, Vector2.ZERO, Vector2(6, 0), 60)
	p = _run(a, 60, p, Vector2(0, 6), 20)  # a sharp turn
	assert_gt(a.cloak_offset(), 0.02, "the cloak lags while moving and turning")
	_run(a, 80, p, Vector2.ZERO, 180)  # three seconds standing still
	assert_lt(a.cloak_offset(), 0.005, "and settles back to rest")


func test_cloak_stays_bounded_at_any_frame_rate() -> void:
	for fps in [30.0, 60.0, 144.0]:
		var a := _avatar()
		a.apply_state(_state(0, Vector2.ZERO))
		var worst := 0.0
		var p := Vector2.ZERO
		for k in 120:
			p += Vector2(26.0 if k % 40 < 9 else 6.0, 0) / 60.0
			a.apply_state(_state(k + 1, p, {"dashing": k % 40 < 9}))
			for f in int(round(fps / 60.0)) if fps >= 60.0 else 1:
				a.advance(1.0 / fps)
			worst = maxf(worst, a.cloak_offset())
		assert_lte(worst, PlayerAvatar.MAX_OFFSET + 1e-4, "%d fps: within the clamp" % fps)


func test_dash_flares_the_cloak() -> void:
	var walk := _avatar()
	walk.apply_state(_state(0, Vector2.ZERO))
	_run(walk, 0, Vector2.ZERO, Vector2(6, 0), 9)
	var dash := _avatar()
	dash.apply_state(_state(0, Vector2.ZERO))
	_run(dash, 0, Vector2.ZERO, Vector2(26.7, 0), 9, {"dashing": true})
	assert_gt(
		dash.cloak_flare(), walk.cloak_flare() * 1.1, "a dash spreads the cloak wider than a walk"
	)
	assert_gt(dash.cloak_offset(), walk.cloak_offset(), "and streams it further back")


func test_dead_player_slumps() -> void:
	var a := _avatar()
	a.apply_state(_state(0, Vector2.ZERO))
	a.advance(DT)
	var standing := a.hood.global_position.y
	for k in 90:
		a.apply_state(_state(k + 1, Vector2.ZERO, {"dead": true}))
		a.advance(DT)
	assert_almost_eq(a.slump_amount(), 1.0, 1e-4, "fully collapsed")
	assert_lt(a.hood.global_position.y, standing - 0.15, "the hood drops")
	var vm := a.visor.material_override as StandardMaterial3D
	assert_lt(vm.emission_energy_multiplier, 1.0, "the visor dims")


func test_walking_strides_the_legs() -> void:
	var a := _avatar()
	a.apply_state(_state(0, Vector2.ZERO))
	var spread := 0.0
	var p := Vector2.ZERO
	for k in 60:
		p += Vector2(6, 0) / 60.0
		a.apply_state(_state(k + 1, p))
		a.advance(DT)
		spread = maxf(spread, absf(a.legs[0].rotation.z - a.legs[1].rotation.z))
	assert_gt(spread, 0.5, "the legs swing in opposition")
	_run(a, 60, p, Vector2.ZERO, 120)
	assert_almost_eq(
		a.legs[0].rotation.z - a.legs[1].rotation.z, 0.0, 0.02, "and come together at rest"
	)
