extends GutTest
## v0.11.0 O13a, O13c, O13d (ENEMIES.md R5-R10, V3-V5) in the real game, by input events only
## (Input.parse_input_event): a run started from the menu (hub, portal, Gun) on a Red Canyon floor, a Frozen Shore
## floor and a Starfall floor (the e2e's fixed-seed mode: the first seed whose floor 1 is that biome; SignatureE2e).
## Each floor's roster holds its biome's two signatures and its variant. The dev panel (backtick, mouse clicks; God,
## then each kind spawned at once, the horde e2e's speed-up) brings each one in: its model is drawn, its tell shows,
## and the Gun's shot, held with the mouse on it, kills it.
## - Red Canyon: the Cinder Priest's lava vent is drawn (v0.11.0 O17d: on its own avatar, its crystal flaring with the
##   vent's pulse); the Kiln Beetle's death leaves its burst (drawn); the Ember
##   Charger leaves a fire trail.
## - Frozen Shore: the Frost Spitter's arc is drawn and its blob leaves a slick; the Glacier Turtle's shell stands and
##   breaks under the shots before it dies; the Frost Charger leaves a slick trail.
## - Starfall: the Star Warper's star mark is drawn; the Gravity Node's swirl is drawn and it bends a hero shot; the
##   Split Sniper's line splits in three (its four lanes drawn).

const KILL_FRAMES := 2400
## A hero shot whose heading turned more than this (radians) near a Gravity Node was bent.
const BENT_RAD := 0.09


func after_each() -> void:
	Input.action_release(&"shoot")
	E2e.center_sticks()


func _trail(reader: WorldReader, kind: int) -> bool:
	var kinds: PackedInt32Array = reader.variant_trails().get("kind", PackedInt32Array())
	return kinds.has(kind)


func _avatar(s: SignatureE2e, id: int) -> Node:
	var node := s.main.view.actors.actor_node(id)
	return (
		node.get_meta(&"enemy_avatar") if node != null and node.has_meta(&"enemy_avatar") else null
	)


func test_the_red_canyon_signatures_and_variant_on_a_red_canyon_floor() -> void:
	var s := SignatureE2e.new(self)
	if not await s.start_on(&"red_canyon"):
		return
	var reader := s.main.driver.reader
	var cs: CanyonShoreViews = s.main.view.canyon_shore_fx
	var vfx: VariantViews = s.main.view.variant_fx
	assert_true(
		s.roster_has(
			[
				ActorStore.Kind.KILN_BEETLE,
				ActorStore.Kind.CINDER_PRIEST,
				ActorStore.Kind.EMBER_CHARGER
			]
		),
		"the Red Canyon floor's roster: Kiln Beetle, Cinder Priest, Ember Charger"
	)
	# R6 Cinder Priest: its lava vent, drawn.
	var priest: int = await s.spawn(ActorStore.Kind.CINDER_PRIEST, "ENEMY_CINDER_PRIEST")
	var vent: bool = await s.until(func() -> bool: return int(cs.counts()["vents"]) > 0, 1200)
	assert_true(vent, "the Priest's vent is drawn")
	assert_gt(reader.lava_vents().size(), 0, "and stands in the sim")
	# v0.11.0 O17d: drawn on the owner's model, its crystal flaring in time with its vent.
	var body := (
		s.main.view.actors.actor_node(priest).get_meta(&"enemy_avatar") as CinderPriestAvatar
	)
	assert_not_null(body, "the Priest is drawn by its own avatar")
	var flare := CinderPriestAvatar.CRYSTAL_REST + 2.0
	var lit: bool = await s.until(func() -> bool: return body.glow_energy() > flare, 600)
	assert_true(lit, "its crystal flares with its vent's pulse")
	assert_true(await s.shoot_dead(priest, KILL_FRAMES), "the Cinder Priest is shot dead")
	# R5 Kiln Beetle: dies into a burst that blows a second later (its circle, drawn).
	var beetle: int = await s.spawn(ActorStore.Kind.KILN_BEETLE, "ENEMY_KILN_BEETLE")
	# v0.11.0 O17e: drawn on the owner's model, it glows hotter as it is shot, and its body plays its death over the
	# burst's fuse.
	var av := _avatar(s, beetle) as KilnBeetleAvatar
	assert_not_null(av, "the Kiln Beetle is drawn by its own avatar")
	var cool := av.heat_energy() if av != null else 0.0
	var hottest := [cool]
	var watch := func(_i: int) -> void:
		if is_instance_valid(av):
			hottest[0] = maxf(hottest[0], av.heat_energy())
	assert_true(
		await s.shoot_dead(beetle, KILL_FRAMES * 2, watch, 3.0), "the Kiln Beetle is shot dead"
	)
	assert_gt(float(hottest[0]), cool + 2.0, "it glowed hotter as its HP dropped")
	var falls: bool = await s.until(func() -> bool: return is_instance_valid(av) and av.dying(), 20)
	assert_true(falls, "its body plays its death over the fuse")
	var burst: bool = await s.until(func() -> bool: return int(cs.counts()["bursts"]) > 0, 30)
	assert_true(burst, "its burst is drawn where it fell")
	# V3 Ember Charger: a fire trail behind its charge.
	var charger: int = await s.spawn(ActorStore.Kind.EMBER_CHARGER, "ENEMY_EMBER_CHARGER")
	var fire: bool = await s.until(
		func() -> bool: return _trail(reader, Variants.TRAIL_FIRE) and vfx.trail_count() > 0, 1200
	)
	assert_true(fire, "the Ember Charger's fire trail is drawn")
	assert_true(await s.shoot_dead(charger, KILL_FRAMES), "the Ember Charger is shot dead")


func test_the_frozen_shore_signatures_and_variant_on_a_frozen_shore_floor() -> void:
	var s := SignatureE2e.new(self)
	if not await s.start_on(&"frozen_shore"):
		return
	var w := s.e.world()
	var reader := s.main.driver.reader
	var cs: CanyonShoreViews = s.main.view.canyon_shore_fx
	var vfx: VariantViews = s.main.view.variant_fx
	assert_true(
		s.roster_has(
			[
				ActorStore.Kind.FROST_SPITTER,
				ActorStore.Kind.GLACIER_TURTLE,
				ActorStore.Kind.FROST_CHARGER
			]
		),
		"the Frozen Shore floor's roster: Frost Spitter, Glacier Turtle, Frost Charger"
	)
	# R7 Frost Spitter: its lob's arc drawn, its blob landing as a slick.
	var spitter: int = await s.spawn(ActorStore.Kind.FROST_SPITTER, "ENEMY_FROST_SPITTER")
	var arc: bool = await s.until(func() -> bool: return int(cs.counts()["arcs"]) > 0, 1200)
	assert_true(arc, "the Spitter's arc is drawn")
	var slick: bool = await s.until(
		func() -> bool: return _trail(reader, Variants.TRAIL_SLICK), 600
	)
	assert_true(slick, "its blob leaves a slick")
	assert_true(await s.shoot_dead(spitter, KILL_FRAMES), "the Frost Spitter is shot dead")
	# R8 Glacier Turtle: its shell stands, and breaks under the shots before the turtle dies.
	var turtle: int = await s.spawn(ActorStore.Kind.GLACIER_TURTLE, "ENEMY_GLACIER_TURTLE")
	assert_true(reader.shell_on(w.actors.index_of(turtle)), "the Turtle's shell stands")
	var broke := [false]
	var watch := func(i: int) -> void: broke[0] = broke[0] or not reader.shell_on(i)
	assert_true(
		await s.shoot_dead(turtle, KILL_FRAMES * 2, watch, 3.0), "the Glacier Turtle is shot dead"
	)
	assert_true(broke[0], "its shell broke first")
	# V4 Frost Charger: a slick trail behind its charge.
	var charger: int = await s.spawn(ActorStore.Kind.FROST_CHARGER, "ENEMY_FROST_CHARGER")
	var trail: bool = await s.until(func() -> bool: return vfx.trail_count() > 0, 1200)
	assert_true(trail, "the Frost Charger's slick trail is drawn")
	assert_true(await s.shoot_dead(charger, KILL_FRAMES), "the Frost Charger is shot dead")


func test_the_starfall_signatures_and_variant_on_a_starfall_floor() -> void:
	var s := SignatureE2e.new(self)
	if not await s.start_on(&"starfall"):
		return
	var w := s.e.world()
	var reader := s.main.driver.reader
	var sf: StarfallViews = s.main.view.starfall_fx
	assert_true(
		s.roster_has(
			[
				ActorStore.Kind.STAR_WARPER,
				ActorStore.Kind.GRAVITY_NODE,
				ActorStore.Kind.SPLIT_SNIPER
			]
		),
		"the Starfall floor's roster: Star Warper, Gravity Node, Split Sniper"
	)
	# R9 Star Warper: its star mark beside the hero, drawn.
	var warper: int = await s.spawn(ActorStore.Kind.STAR_WARPER, "ENEMY_STAR_WARPER")
	var star: bool = await s.until(
		func() -> bool:
			var i := w.actors.index_of(warper)
			return i >= 0 and not reader.warper_star(i).is_empty() and sf.star_count() > 0,
		1200
	)
	assert_true(star, "the Warper's star mark is drawn")
	assert_true(await s.shoot_dead(warper, KILL_FRAMES), "the Star Warper is shot dead")
	# R10 Gravity Node: its swirl drawn; a hero shot aimed past it bends toward it.
	var node: int = await s.spawn(ActorStore.Kind.GRAVITY_NODE, "ENEMY_GRAVITY_NODE")
	var swirl: bool = await s.until(func() -> bool: return sf.swirl_count() > 0, 120)
	assert_true(swirl, "the Node's swirl is drawn")
	var ni := w.actors.index_of(node)
	var at := w.actors.pos(ni)
	var reach := reader.gravity_reach(ni)
	assert_gt(reach, 0.0, "it pulls within its reach")
	var to := at - w.player_pos()
	var past := at + Vector2(-to.y, to.x).normalized() * 1.5 + to.normalized() * 2.0
	var first := {}
	var bent := false
	s.e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	for k in 240:
		await s.aim_at(past)
		for p in reader.projectile_count():
			if reader.projectile_team(p) != ActorStore.TEAM_PLAYER:
				continue
			var pid := reader.projectile_id(p)
			var v := reader.projectile_vel(p)
			if v.length() < 0.001:
				continue
			if not first.has(pid):
				first[pid] = v
			elif (
				reader.projectile_pos(p).distance_to(at) < reach
				and absf((first[pid] as Vector2).angle_to(v)) > BENT_RAD
			):
				bent = true
		if bent:
			break
	s.e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	assert_true(bent, "a hero shot bent toward the Gravity Node")
	assert_true(await s.shoot_dead(node, KILL_FRAMES), "the Gravity Node is shot dead")
	# V5 Split Sniper: its windup is the body's (v0.8.0 TG: the Sniper's line is no ground mark), over the line and
	# the three branches it splits into; the shot draws a tracer down each of the four.
	var sniper: int = await s.spawn(ActorStore.Kind.SPLIT_SNIPER, "ENEMY_SPLIT_SNIPER")
	var hv: HordeVisuals = s.main.view.horde_fx
	var crouched := false
	var four_lanes := false
	var tracers := 0
	for k in 1200:
		var i := w.actors.index_of(sniper)
		if i < 0:
			break
		var tg := reader.telegraph(i)
		if tg.get("style", &"") == &"snipe":
			four_lanes = four_lanes or (tg.get("obbs", []) as Array).size() >= 4
			var body := s.main.view.actors.actor_node(sniper)
			var av := body.get_meta(&"enemy_avatar") as HordeAvatar if body != null else null
			crouched = crouched or (av != null and av.crouch_amount() > 0.0)
		tracers = maxi(tracers, hv.tracer_count())
		if crouched and four_lanes and tracers >= 4:
			break
		await s.e.frames(1)
	assert_true(four_lanes, "the Split Sniper's shot is its line and three branches")
	assert_true(crouched, "its body winds up (the tell)")
	assert_gte(tracers, 4, "the shot draws a tracer down each lane")
	assert_true(await s.shoot_dead(sniper, KILL_FRAMES), "the Split Sniper is shot dead")
