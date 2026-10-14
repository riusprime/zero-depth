extends GutTest
## v0.8.0 TG (owner O4, Q3): the kinds whose ground mark is gone tell their windup with the body (AvatarBase
## tell_crouch / tell_glow): a crouch that deepens with the windup's progress, an eye / visor / muzzle glow that climbs
## and flashes from TELL_FLASH_FROM to the strike, steady under reduced motion; and the body faces the attack's
## locked direction, holding it still for the commit window before the strike.

const DT := 0.05

var _calm := false


func before_each() -> void:
	_calm = ViewPrefs.reduced_motion


func after_each() -> void:
	ViewPrefs.reduced_motion = _calm


## [name, a built avatar] for each avatar with a tell: Charger (and Hatchling), the horde kinds, Warden, Needle.
func _avatars() -> Array:
	var out := []
	var charger := ChargerAvatar.new()
	charger.setup(Color.BLACK)
	out.append(["charger", charger])
	for kind: int in HordeAvatar.TELL_KINDS:
		var h := HordeAvatar.new()
		h.setup(kind, Color.BLACK)
		out.append(["horde %d" % kind, h])
	var warden := WardenAvatar.new()
	warden.setup(Color.BLACK)
	out.append(["warden", warden])
	var needle := NeedleAvatar.new()
	needle.setup(Color.BLACK)
	out.append(["needle", needle])
	for e: Array in out:
		add_child_autofree(e[1])
		(e[1] as Node).set_process(false)
	return out


func _glow(a: AvatarBase) -> float:
	if a is ChargerAvatar:
		return (a as ChargerAvatar).visor_energy()
	if a is HordeAvatar:
		return (a as HordeAvatar).glow_energy()
	if a is WardenAvatar:
		return (a as WardenAvatar).visor_energy()
	return (a as NeedleAvatar).eye_energy()


## Holds the avatar in `state` at windup progress p for `frames` frames; returns its glow and crouch.
func _hold(a: AvatarBase, tick: int, state: int, p: float, frames := 40) -> Array:
	var s := {"tick": tick, "pos": Vector2.ZERO, "state": state, "windup": p}
	for k in frames:
		s["tick"] = tick + k
		a.apply_state(s)
		a.advance(DT)
	return [_glow(a), a.call(&"crouch_amount")]


func test_the_tell_curves() -> void:
	assert_eq(AvatarBase.tell_crouch(0.0), 0.0)
	assert_eq(AvatarBase.tell_crouch(AvatarBase.TELL_CROUCH_BY), 1.0, "full crouch")
	assert_false(AvatarBase.tell_flashing(AvatarBase.TELL_FLASH_FROM - 0.01))
	assert_true(AvatarBase.tell_flashing(AvatarBase.TELL_FLASH_FROM))
	assert_eq(AvatarBase.tell_glow(0.0, 0.0, true), 1.0, "no extra glow at the start")
	var before := AvatarBase.tell_glow(AvatarBase.TELL_FLASH_FROM - 0.01, 0.0, true)
	var flash := AvatarBase.tell_glow(AvatarBase.TELL_FLASH_FROM, 0.0, true)
	assert_gt(flash, before * 1.5, "the flash is a clear step up: %.2f -> %.2f" % [before, flash])
	for t in [0.0, 0.03, 0.11, 0.27]:
		assert_eq(AvatarBase.tell_glow(0.9, t, true), flash, "steady with reduced motion")
		assert_gte(
			AvatarBase.tell_glow(0.9, t, false), before, "the flicker never dips under the climb"
		)


func test_each_avatar_crouches_brightens_and_flashes_through_its_windup() -> void:
	ViewPrefs.reduced_motion = true  # steady glow, so the frames compare exactly
	for e: Array in _avatars():
		var a: AvatarBase = e[1]
		var rest: Array = _hold(a, 100, WorldReader.STATE_MOVE, 0.0)
		var early: Array = _hold(a, 200, WorldReader.STATE_WINDUP, 0.1)
		var mid: Array = _hold(a, 240, WorldReader.STATE_WINDUP, 0.5, 6)
		var late: Array = _hold(a, 250, WorldReader.STATE_WINDUP, 0.75, 6)
		var flash: Array = _hold(a, 260, WorldReader.STATE_WINDUP, 0.9, 6)
		assert_eq(rest[1], 0.0, "%s: no crouch at rest" % e[0])
		assert_gt(mid[1], early[1], "%s: the crouch deepens" % e[0])
		assert_gt(late[1], 0.9, "%s: crouched before the strike" % e[0])
		assert_gt(mid[0], rest[0], "%s: the glow climbs" % e[0])
		assert_gt(flash[0], late[0] * 1.3, "%s flashes: %.2f -> %.2f" % [e[0], late[0], flash[0]])
		var active: Array = _hold(a, 300, WorldReader.STATE_RECOVER, 0.0)
		assert_eq(active[1], 0.0, "%s: the crouch ends with the windup" % e[0])


func test_the_flash_flickers_only_without_reduced_motion() -> void:
	for calm in [true, false]:
		ViewPrefs.reduced_motion = calm
		var a := ChargerAvatar.new()
		a.setup(Color.BLACK)
		add_child_autofree(a)
		a.set_process(false)
		_hold(a, 0, WorldReader.STATE_WINDUP, 0.9, 60)
		var seen := {}
		for k in 8:
			_hold(a, 100 + k, WorldReader.STATE_WINDUP, 0.9, 1)
			seen[snappedf(a.visor_energy(), 0.001)] = true
		if calm:
			assert_eq(seen.size(), 1, "steady: %s" % [seen.keys()])
		else:
			assert_gt(seen.size(), 1, "it flickers")


func test_the_snipers_muzzle_charges_in_the_air() -> void:
	ViewPrefs.reduced_motion = true
	var a := HordeAvatar.new()
	a.setup(WorldReader.KIND_SNIPER, Color.BLACK)
	add_child_autofree(a)
	a.set_process(false)
	_hold(a, 0, WorldReader.STATE_MOVE, 0.0)
	assert_eq(a.muzzle_energy(), 0.0, "cold at rest")
	_hold(a, 100, WorldReader.STATE_WINDUP, 0.5, 6)
	var mid := a.muzzle_energy()
	_hold(a, 110, WorldReader.STATE_WINDUP, 0.95, 6)
	assert_gt(mid, 0.0, "it charges")
	assert_gt(a.muzzle_energy(), mid * 1.5, "and flares before the shot")
	var muzzle: Node3D = a.parts["muzzle"]
	assert_gt(muzzle.global_position.y, 0.5, "at the barrel's tip, in the air")
	for other: int in [WorldReader.KIND_SWARMER, WorldReader.KIND_SHIELD_BEARER]:
		var h := HordeAvatar.new()
		h.setup(other, Color.BLACK)
		add_child_autofree(h)
		_hold(h, 0, WorldReader.STATE_WINDUP, 0.95, 6)
		assert_eq(h.muzzle_energy(), 0.0, "kind %d has no muzzle" % other)


func test_the_body_faces_the_locked_attack_and_holds_it_before_the_strike() -> void:
	for spec in [
		[ActorStore.Kind.CHARGER, Vector2(3, 0)],
		[ActorStore.Kind.SWARMER, Vector2(2, 0)],
		[ActorStore.Kind.SPLITTER, Vector2(1.2, 0)],
		[ActorStore.Kind.SHIELD_BEARER, Vector2(1.8, 0)],
		[ActorStore.Kind.WARDEN, Vector2(1.5, 0)],
		[ActorStore.Kind.SNIPER, Vector2(12, 0)],
		[ActorStore.Kind.NEEDLE, Vector2(8, 0)],
	]:
		var w := CombatLab.world()
		w.actors.hp[0] = 1 << 20
		w.actors.max_hp[0] = 1 << 20
		var id := w.add_enemy(spec[0], spec[1])
		var views := ActorViews.new()
		add_child_autofree(views)
		var reader := WorldReader.new(w)
		var windup := 0
		var held := []
		for t in 900:
			# The player strafes, so a tracking aim keeps turning until it commits.
			w.actors.set_pos(0, Vector2(0, 2.0 * sin(t * 0.05)))
			w.step(InputFrame.new())
			w.actors.hp[0] = w.actors.max_hp[0]
			views.sync(reader)
			var i := w.actors.index_of(id)
			if w.actors.state[i] != EnemyAi.State.WINDUP:
				if windup > 0:
					break
				continue
			windup += 1
			var facing: Node3D = views.actor_node(id).get_meta(&"facing")
			var want := SimPlane.yaw_of(w.actors.facing[i])
			assert_almost_eq(
				facing.rotation.y, want, 0.0001, "kind %d: drawn as the sim faces" % spec[0]
			)
			if spec[0] != ActorStore.Kind.WARDEN:  # its slam is a disc round itself: no aim to face
				var lock := SimPlane.yaw_of(w.actors.lock_a[i])
				assert_almost_eq(facing.rotation.y, lock, 0.0001, "kind %d faces its aim" % spec[0])
			var commit := w.tuning.ai_commit_ticks
			if spec[0] == ActorStore.Kind.SNIPER:
				commit = w.tuning.ai_snipe_commit_ticks
			if w.actors.state_t[i] >= w.actors.windup[i] - commit:
				held.append(facing.rotation.y)
		assert_gt(windup, 5, "kind %d wound up" % spec[0])
		assert_gt(held.size(), 0, "kind %d: its last ticks" % spec[0])
		for y: float in held:
			assert_almost_eq(y, held[0], 0.0001, "kind %d holds still before the strike" % spec[0])
