extends GutTest
## v0.8.0 GF2 (owner O20, O21): the hit feel. A player's hit on an enemy throws an impact (a flash and sparks where it
## hit, a spray out of the far side along the hit) in the effects layer's pools, merged and thinned past its budget
## and by the Effects density; the hit enemy's model flinches away from the hit (a pose only: the sim body and the
## node never move), settles back to rest, and a new hit restarts it only once the last has run a moment (bosses:
## their flinch clip, rate-limited, lighter over an attack); the white flash still fires on every enemy and boss
## model; damage numbers are 15 % bigger, thrown up and out (alternating sides), crits big, shaking, vanishing;
## reduced motion: a smaller flinch, no shake, a short rise. Presentation only: nothing is written back.

const DT := 1.0 / 60.0
const K := ActorStore.Kind
const NORMAL_KINDS := [
	K.CHARGER,
	K.WARDEN,
	K.NEEDLE,
	K.ARC_CASTER,
	K.BOMB_DRONE,
	K.LENS_DRONE,
	K.HATCHLING,
	K.SWARMER,
	K.SPLITTER,
	K.SPLITLING,
	K.SHIELD_BEARER,
	K.MENDER,
	K.MINE_LAYER,
	K.SNIPER,
]
const BOSS_KINDS := [
	K.GATEKEEPER,
	K.BROOD_MOTHER,
	K.SIEGE_ENGINE,
	K.WARLORD,
	K.HIVE_LENS,
	K.FOUNDRY,
	K.COLOSSUS,
	K.PRISM,
	K.NEMESIS,
]


func after_each() -> void:
	ViewPrefs.reduced_motion = false
	ViewPrefs.effects_density = "high"


## [world, reader, views, feel, enemy index, enemy id] with one enemy of `kind` at (3, 0), ready to be hit.
func _setup(kind: int) -> Array:
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 20
	var id := w.add_enemy(kind, Vector2(3, 0))
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	w.actors.hp[i] = 1 << 20
	w.actors.max_hp[i] = 1 << 20
	w.actors.facing[i] = 0  # turned away: the hit lands on its back (a Shield Bearer's shield would block it)
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	views.set_process(false)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var feel := HitFeel.new(views, rig)
	add_child_autofree(feel)
	feel.set_process(false)
	views.sync(reader)
	feel.sync(reader)
	return [w, reader, views, feel, i, id]


## The player's bolt-like hit on actor i, travelling +x (from (2, 0) to its near side).
func _hit(w: World, i: int, tags: int = SimEvent.TAG_PROJECTILE) -> void:
	var pid := w.actors.ids[0]
	var at := w.actors.pos(i) - Vector2(w.actors.radius[i], 0)
	Damage.hit(w, i, 5, pid, pid, w.take_root(), tags, at - Vector2(0.3, 0), at)


func test_every_enemy_kind_flinches_away_from_a_hit_and_settles_without_moving() -> void:
	for kind: int in NORMAL_KINDS:
		var s := _setup(kind)
		var w: World = s[0]
		var views: ActorViews = s[2]
		var feel: HitFeel = s[3]
		var i: int = s[4]
		var node := views.actor_node(s[5])
		var av := node.get_meta(&"enemy_avatar") as AvatarBase
		assert_not_null(av, "kind %d has a flinching avatar" % kind)
		if av == null:
			continue
		av.set_process(false)
		var rest := av.transform
		var sim_before := w.actors.pos(i)
		var node_before := node.position
		_hit(w, i)
		feel.sync(s[1])
		assert_eq(feel.flinches, 1, "kind %d flinches on the hit" % kind)
		assert_true(views.is_flashing(s[5]), "kind %d flashes white" % kind)
		for f in 4:
			av.advance_flinch(DT)
		assert_gt(av.flinch_amount(), 0.4, "kind %d: well into the flinch" % kind)
		# The body's top leans away from the hit (+x on the sim plane is +x in 3D).
		var facing := av.get_parent() as Node3D
		var top := Vector3(0, av._flinch_pivot() + 1.0, 0)
		var moved := facing.transform * av.transform * top - facing.transform * rest * top
		assert_gt(moved.x, 0.05, "kind %d leans away from the hit" % kind)
		for f in 30:
			av.advance_flinch(DT)
		assert_false(av.flinching(), "kind %d: the flinch is over" % kind)
		assert_eq(av.transform, rest, "kind %d is back at rest" % kind)
		assert_eq(w.actors.pos(i), sim_before, "kind %d: the sim body never moved" % kind)
		assert_eq(node.position, node_before, "kind %d: nor did its node" % kind)


func test_a_flinch_restarts_only_once_the_last_has_run_a_moment() -> void:
	var a := HordeAvatar.new()
	a.setup(WorldReader.KIND_SWARMER, Color.BLACK)
	add_child_autofree(a)
	a.set_process(false)
	assert_true(a.flinch(Vector2.RIGHT))
	a.advance_flinch(DT)
	assert_false(a.flinch(Vector2.RIGHT), "too fresh: no restart")
	var frames := 0
	while not a.flinch(Vector2.RIGHT):
		a.advance_flinch(DT)
		frames += 1
	assert_almost_eq(
		(frames + 1) * DT, AvatarBase.FLINCH_RETRIGGER_S, DT * 1.5, "after the retrigger time"
	)
	# Steady fire (a hit every frame) keeps it moving: its envelope goes out and comes back, not held bent.
	var lo := 1.0
	var hi := 0.0
	for f in 60:
		a.flinch(Vector2.RIGHT)
		a.advance_flinch(DT)
		lo = minf(lo, a.flinch_amount())
		hi = maxf(hi, a.flinch_amount())
	assert_gt(hi, 0.8)
	assert_lt(lo, 0.6, "it twitches under steady fire instead of freezing")


func test_reduced_motion_flinches_smaller() -> void:
	var peak := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := ChargerAvatar.new()
		a.setup(Color.BLACK, &"xray")
		add_child_autofree(a)
		a.set_process(false)
		a.flinch(Vector2.UP)
		var best := 0.0
		for f in 12:
			a.advance_flinch(DT)
			best = maxf(best, a.flinch_amount())
		peak.append(best)
	assert_almost_eq(peak[1], peak[0] * AvatarBase.FLINCH_CALM, 0.05)


func test_bosses_flinch_through_their_clip_rate_limited_and_lighter_over_an_attack() -> void:
	var views := ActorViews.new()
	add_child_autofree(views)
	for kind: int in BOSS_KINDS:
		var node := views._make_actor(kind, false, 1.2)
		add_child_autofree(node)
		var b := node.get_meta(&"enemy_avatar") as BossAvatar
		b.set_process(false)
		b.apply_state({"tick": 1, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE})
		b.advance(DT)
		assert_true(b.flinch(Vector2.RIGHT), "kind %d flinches" % kind)
		b.advance(DT)
		if b.animator != null:
			assert_gt(
				b.animator.slot_w[BossAnimator.FLINCH], 0.9, "kind %d: its flinch clip" % kind
			)
		assert_false(b.flinch(Vector2.RIGHT), "kind %d: too fresh to restart" % kind)
		var restarts := 0
		var t_max := 0.0
		for f in 60:  # steady fire: a hit every frame
			if b.flinch(Vector2.RIGHT):
				restarts += 1
			b.advance(DT)
			t_max = maxf(t_max, 1.0 - b.flinch_amount())
		assert_between(restarts, 3, 12, "kind %d: rate-limited restarts" % kind)
		assert_gt(
			t_max, BossAvatar.FLINCH_RETRIGGER, "kind %d: the clip plays on, not frozen" % kind
		)
		if b.animator != null:
			b.apply_state(
				{"tick": 2, "pos": Vector2.ZERO, "state": WorldReader.STATE_WINDUP, "move": 0}
			)
			b._flinch = 0.0
			b.flinch()
			b.advance(DT)
			if b._clip_move >= 0:
				assert_almost_eq(
					b.animator.slot_w[BossAnimator.FLINCH],
					BossAvatar.FLINCH_ATTACK_WEIGHT,
					0.001,
					"kind %d: lighter over an attack" % kind
				)


func test_a_real_hit_on_a_boss_flinches_it() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(4, 0))
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	views.set_process(false)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var feel := HitFeel.new(views, rig)
	add_child_autofree(feel)
	views.sync(reader)
	feel.sync(reader)
	var b := views.actor_node(w.actors.ids[i]).get_meta(&"enemy_avatar") as BossAvatar
	b.set_process(false)
	_hit(w, i)
	feel.sync(reader)
	assert_true(views.is_flashing(w.actors.ids[i]), "the boss flashes")
	assert_eq(feel.flinches, 1)
	assert_gt(b.flinch_amount(), 0.9, "and flinches")


func test_the_white_flash_reaches_every_enemy_and_boss_model_in_palette_a() -> void:
	assert_eq(EnemyPalettes.active, EnemyPalettes.SHIPPED)
	var views := ActorViews.new()
	add_child_autofree(views)
	for kind: int in NORMAL_KINDS + BOSS_KINDS:
		var node := views._make_actor(kind, false, 0.5)
		add_child_autofree(node)
		var mats: Array = node.get_meta(&"mats", [])
		assert_gt(mats.size(), 0, "kind %d has flashable materials" % kind)
		views._set_flash(node, true)
		for m: StandardMaterial3D in mats:
			assert_true(m.emission_enabled, "kind %d: emission on from the start" % kind)
			assert_gt(m.emission_energy_multiplier, 1.0, "kind %d glows white" % kind)
			assert_eq(m.emission, Color.WHITE)
		views._set_flash(node, false)
		for m: StandardMaterial3D in mats:
			assert_eq(m.emission_energy_multiplier, 0.0, "kind %d: the flash ends" % kind)


func test_a_bolt_hit_throws_an_impact_with_a_spray_out_of_the_far_side() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	var id := w.add_dummy(Vector2(3, 0), 0.35, 5000)
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var feel := HitFeel.new(views, rig)
	add_child_autofree(feel)
	var pid := w.actors.ids[0]
	w.queue_projectile(
		pid,
		ActorStore.TEAM_PLAYER,
		Vector2(1, 0),
		Vector2(0.2, 0),
		10,
		0.1,
		60,
		SimEvent.TAG_PROJECTILE,
		0,
		String(WorldReader.ATTACK_BOLT)
	)
	for t in 30:
		w.step(InputFrame.new())
		views.sync(reader)
		feel.sync(reader)
		if feel.impacts.added > 0:
			break
	assert_eq(feel.impacts.added, 1, "one impact for the hit")
	assert_true(views.is_flashing(id), "the flash still fires")
	var imp: Array = feel.impacts._live[0]
	assert_gt((imp[1] as Vector3).x, 0.95, "along the bolt's flight")
	assert_gt((imp[2] as Vector3).x, 3.0, "its spray leaves the far side")
	var layer := VfxLayer.new()
	add_child_autofree(layer)
	layer.begin(float(w.tick) + 4.0)
	feel.impacts.draw(layer)
	assert_gt(feel.impacts.last_pieces, 10)
	assert_gt(layer.used(&"spark"), 8, "flash, sparks and spray")
	assert_gt(layer.used(&"debris"), 0, "chunks")
	assert_gt(layer.used(&"smoke"), 0, "a puff")
	for j in ImpactFx.SPRAY:
		var p := ImpactFx.spray_at(imp, j, 0.5)
		assert_gt(p.x, 3.6, "spray piece %d flies on behind the body" % j)
		assert_lt(absf(p.z), absf(p.x - 3.35), "along the hit, spread a little")
	layer.begin(float(w.tick) + ImpactFx.LIFE_TICKS + 1.0)
	feel.impacts.draw(layer)
	assert_eq(feel.impacts.live(), 0, "and it goes")


func test_a_slash_is_smaller_and_an_area_hit_smaller_still() -> void:
	var pieces := []
	for kind: int in [ImpactFx.BOLT, ImpactFx.SLASH, ImpactFx.OTHER]:
		var fx := ImpactFx.new()
		fx.add(Vector3.ZERO, Vector3.RIGHT, Vector3(0.4, 0, 0), ImpactFx.HERO, 0, 1.0, kind)
		fx._live[0][5] = ImpactFx.STRENGTH[kind]
		var layer := VfxLayer.new()
		add_child_autofree(layer)
		layer.begin(3.0)
		fx.draw(layer)
		pieces.append(fx.last_pieces)
	assert_gt(pieces[0], pieces[1])
	assert_gt(pieces[1], pieces[2])


func test_impacts_merge_and_thin_within_the_budget() -> void:
	var fx := ImpactFx.new()
	for k in 100:
		fx.add(Vector3(0, 0.5, 0), Vector3.RIGHT, Vector3(0.4, 0.5, 0), ImpactFx.HERO, 10, 1.0, 0)
	assert_eq(fx.live(), 1, "a burst on one spot draws once")
	assert_eq(fx.merged, 99)
	var many := ImpactFx.new()
	for k in 100:
		many.add(
			Vector3(k, 0.5, 0), Vector3.RIGHT, Vector3(k + 0.4, 0.5, 0), ImpactFx.HERO, 10, 1.0, 0
		)
	assert_eq(many.live(), ImpactFx.MAX_LIVE, "at most MAX_LIVE live")
	assert_eq(many.dropped, 100 - ImpactFx.MAX_LIVE)
	var layer := VfxLayer.new()
	add_child_autofree(layer)
	layer.begin(12.0)
	many.draw(layer)
	var full := ImpactFx.new()
	full.add(Vector3.ZERO, Vector3.RIGHT, Vector3(0.4, 0, 0), ImpactFx.HERO, 10, 1.0, 0)
	var one := VfxLayer.new()
	add_child_autofree(one)
	one.begin(12.0)
	full.draw(one)
	assert_lt(many.last_pieces, ImpactFx.MAX_LIVE * full.last_pieces * 0.6, "past FULL they thin")
	for id: StringName in [&"spark", &"debris", &"smoke"]:
		assert_lte(layer.used(id), int(layer.pools[id]["cap"]), "within the pool")
	# Effects density low (the canvas sets VfxCore.density from it) thins them.
	var low := VfxLayer.new()
	add_child_autofree(low)
	low.begin(12.0)
	low.density = AttackFormCanvas.DENSITY_PARTICLES["low"]
	var thin := ImpactFx.new()
	thin.add(Vector3.ZERO, Vector3.RIGHT, Vector3(0.4, 0, 0), ImpactFx.HERO, 10, 1.0, 0)
	thin.draw(low)
	assert_lt(thin.last_pieces, full.last_pieces * 0.5, "low density: fewer pieces")
	assert_gt(thin.last_pieces, 0, "but still an impact")


func test_the_hit_s_element_tints_its_impact() -> void:
	assert_ne(
		AttackFormLooks.element_color(&"fire"),
		ImpactFx.HERO,
		"a fire hit is not the hero's blue-white"
	)


# --- Damage numbers (O21) ------------------------------------------------------------------------------------
func _numbers() -> DamageNumbers:
	var n := DamageNumbers.new()
	add_child_autofree(n)
	n.set_process(false)
	return n


## The sideways (along the screen) and height offsets of label k over its life.
func _track(n: DamageNumbers, k: int, frames: int) -> Array:
	var out := []
	for f in frames:
		n._process(DT)
		var la: Array = n.label_at(k)
		var l: Label3D = la[0]
		var d: Vector3 = l.position - (la[1] as Vector3)
		out.append([d.dot(n._right), d.y, l.scale.x, l.modulate.a, l.visible])
	return out


func test_numbers_are_15_percent_bigger() -> void:
	assert_eq(DamageNumbers.SIZE, roundi(32 * 1.15))
	assert_eq(DamageNumbers.CRIT_SIZE, roundi(60 * 1.15))


func test_numbers_are_thrown_up_and_out_alternating_sides_and_fade_as_they_fall() -> void:
	var n := _numbers()
	n.show_number(Vector2.ZERO, 12, false)
	n.show_number(Vector2.ZERO, 13, false)
	var a := _track(n, 0, 40)
	n = _numbers()
	n.show_number(Vector2.ZERO, 12, false)
	n.show_number(Vector2.ZERO, 13, false)
	var b := _track(n, 1, 40)
	var a_mid: Array = a[20]
	var b_mid: Array = b[20]
	assert_gt(absf(a_mid[0]), 0.3, "out to the side")
	assert_lt(a_mid[0] * b_mid[0], 0.0, "the next one to the other side")
	var peak := 0
	for f in a.size():
		if a[f][1] > a[peak][1]:
			peak = f
	assert_gt(a[peak][1], 0.5, "up")
	assert_between(peak, 10, 30, "an arc that peaks and falls")
	assert_lt(a[39][1], a[peak][1] - 0.3, "it falls")
	assert_lt(a[39][3], a[peak][3], "fading as it falls")
	n._process(1.0)
	assert_eq(n.showing(), 0)


func test_a_crit_spawns_big_shakes_then_vanishes() -> void:
	var n := _numbers()
	n.show_number(Vector2.ZERO, 99, true)
	assert_eq(n.shown()[0][2], DamageNumbers.CRIT_SIZE)
	var c := _track(n, 0, 60)
	assert_gt(c[0][2], 1.4, "spawns big")
	var jitter := 0.0
	for f in range(1, 10):
		jitter = maxf(jitter, absf(c[f][0] - c[f - 1][0]))
	assert_gt(jitter, 0.01, "a shake")
	assert_lt(absf(c[30][0]), 0.001, "the shake is over")
	assert_lt(c[45][2], 0.8, "shrinking away")
	assert_lt(c[46][3], 0.3, "and vanishing")


func test_reduced_motion_no_shake_and_a_short_rise() -> void:
	ViewPrefs.reduced_motion = true
	var n := _numbers()
	n.show_number(Vector2.ZERO, 12, false)
	n.show_number(Vector2.ZERO, 99, true)
	var plain := _track(n, 0, 40)
	n = _numbers()
	n.show_number(Vector2.ZERO, 99, true)
	var crit := _track(n, 0, 40)
	for r: Array in plain + crit:
		assert_almost_eq(float(r[0]), 0.0, 0.0001, "no arc, no shake")
	for f in range(1, plain.size()):
		assert_gte(plain[f][1], plain[f - 1][1], "a straight rise")
	assert_lte(plain[39][1], DamageNumbers.RISE_M + 0.001, "a short one")


func test_the_pool_holds_40() -> void:
	var n := _numbers()
	for k in 60:
		n.show_number(Vector2(k, 0), k + 1, k % 7 == 0)
	assert_eq(n.showing(), DamageNumbers.POOL)
	assert_eq(n.get_child_count(), DamageNumbers.POOL, "no label beyond the pool")
