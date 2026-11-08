extends GutTest
## v0.11.0 O13a, O13b (ENEMIES.md R1-R4, V1, V2) in the real game, by input events only (Input.parse_input_event): a
## run started from the menu (hub, portal, Gun) on a Ruins floor, then on a Night Rocks floor (the e2e's fixed-seed
## mode: the first seed whose floor 1 is that biome; SignatureE2e). The floor's roster holds the biome's two
## signatures and its variant. The dev panel (backtick, mouse clicks; God, then each kind spawned at once: the speed-up
## the horde e2e use, as the floor's curve opens them only with the Warden) brings each one in: its model is drawn, its
## tell shows, and the Gun's shot, held with the mouse on it, kills it.
## - Ruins: the Wire Weaver strings a live cable (drawn); the Scrap Hound's visor flashes as it turns in on a hero who
##   shoots away from it; the Rubble Warden wears its crust, which breaks into rocks of cover (drawn).
## - Night Rocks: the Rock Lurker waits as a boulder, its cracks glow brighter as the hero walks near (the stick), it
##   bursts out with a slam whose ring is drawn; the Stone Thrower lifts a rock (its hands), its landing ring is drawn
##   and the rock stands as cover; the Dim Needle's shot is drawn dark while it is far from the hero.

const KILL_FRAMES := 2400


func after_each() -> void:
	Input.action_release(&"shoot")
	E2e.center_sticks()


func _avatar(s: SignatureE2e, id: int) -> Node:
	var node := s.main.view.actors.actor_node(id)
	return (
		node.get_meta(&"enemy_avatar") if node != null and node.has_meta(&"enemy_avatar") else null
	)


func test_the_ruins_signatures_and_variant_on_a_ruins_floor() -> void:
	var s := SignatureE2e.new(self)
	if not await s.start_on(&"ruins"):
		return
	var w := s.e.world()
	var reader := s.main.driver.reader
	var rr: RuinsRocksViews = s.main.view.ruins_rocks_fx
	assert_true(
		s.roster_has(
			[
				ActorStore.Kind.WIRE_WEAVER,
				ActorStore.Kind.SCRAP_HOUND,
				ActorStore.Kind.RUBBLE_WARDEN
			]
		),
		"the Ruins floor's roster: Wire Weaver, Scrap Hound, Rubble Warden"
	)
	# R1 Wire Weaver: a live cable across the hero's way, drawn.
	var weaver: int = await s.spawn(ActorStore.Kind.WIRE_WEAVER, "ENEMY_WIRE_WEAVER")
	var strung: bool = await s.until(func() -> bool: return rr.cable_count() > 0, 900)
	assert_true(strung, "the Weaver's cable is drawn")
	assert_gt(reader.cables().size(), 0, "and live in the sim")
	assert_true(await s.shoot_dead(weaver, KILL_FRAMES), "the Wire Weaver is shot dead")
	# R2 Scrap Hound: it turns in only on a hero who attacks with his back to it; the visor flash is the tell.
	var hound: int = await s.spawn(ActorStore.Kind.SCRAP_HOUND, "ENEMY_SCRAP_HOUND")
	var flashed := false
	s.e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	for k in 1200:
		var i := w.actors.index_of(hound)
		if i < 0:
			break
		var av := _avatar(s, hound) as RuinsRocksAvatar
		if av != null and av.visor_energy() > RuinsRocksAvatar.VISOR_REST + 0.5:
			flashed = true
			break
		var away := w.player_pos() - (w.actors.pos(i) - w.player_pos()).normalized() * 4.0
		await s.aim_at(away)
	s.e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	assert_true(flashed, "the Hound's visor flashes as it turns in on the hero's back")
	assert_true(await s.shoot_dead(hound, KILL_FRAMES), "the Scrap Hound is shot dead")
	# V1 Rubble Warden: its crust, broken by the shots, stands as rocks of cover (drawn).
	var warden: int = await s.spawn(ActorStore.Kind.RUBBLE_WARDEN, "ENEMY_RUBBLE_WARDEN")
	assert_true(reader.crust_on(w.actors.index_of(warden)), "the Rubble Warden wears its crust")
	var vfx: VariantViews = s.main.view.variant_fx
	var rocks := [0]
	var watch := func(_i: int) -> void: rocks[0] = maxi(rocks[0], vfx.rock_count())
	assert_true(
		await s.shoot_dead(warden, KILL_FRAMES * 2, watch, 3.0), "the Rubble Warden is shot dead"
	)
	assert_gt(rocks[0], 0, "its crust broke into rocks of cover, drawn")


func test_the_night_rocks_signatures_and_variant_on_a_night_rocks_floor() -> void:
	var s := SignatureE2e.new(self)
	if not await s.start_on(&"night_rocks"):
		return
	var w := s.e.world()
	var reader := s.main.driver.reader
	var rr: RuinsRocksViews = s.main.view.ruins_rocks_fx
	assert_true(
		s.roster_has(
			[ActorStore.Kind.ROCK_LURKER, ActorStore.Kind.STONE_THROWER, ActorStore.Kind.DIM_NEEDLE]
		),
		"the Night Rocks floor's roster: Rock Lurker, Stone Thrower, Dim Needle"
	)
	# R3 Rock Lurker: a boulder; its cracks glow brighter (the rumble) as the hero walks near; out with a slam.
	var lurker: int = await s.spawn(ActorStore.Kind.ROCK_LURKER, "ENEMY_ROCK_LURKER")
	var hid: bool = await s.until(
		func() -> bool:
			var j := w.actors.index_of(lurker)
			return j >= 0 and reader.lurker_hidden(j),
		240
	)
	assert_true(hid, "the Lurker settles as a boulder once it has arrived")
	var rumbled := false
	var out := false
	var slam_drawn := false
	for k in 900:
		var i := w.actors.index_of(lurker)
		if i < 0:
			break
		var av := _avatar(s, lurker) as RuinsRocksAvatar
		if av != null and reader.lurker_hidden(i):
			rumbled = rumbled or av.crack_energy() >= RuinsRocksAvatar.CRACK_RUMBLE
		if not reader.lurker_hidden(i):
			out = true
		var tg := reader.telegraph(i)
		if out and not tg.is_empty() and s.main.view.telegraphs.count() > 0:
			slam_drawn = true
			break
		var to := w.actors.pos(i) - w.player_pos()
		s.e.stick_toward(to.normalized() if not out and to.length() > 1.2 else Vector2.ZERO)
		await s.e.frames(1)
	s.e.stick_toward(Vector2.ZERO)
	assert_true(rumbled, "its cracks glowed brighter as the hero came near")
	assert_true(out, "it burst out")
	assert_true(slam_drawn, "its slam's ring is drawn")
	assert_true(await s.shoot_dead(lurker, KILL_FRAMES, Callable(), 3.0), "the Rock Lurker dies")
	# R4 Stone Thrower: the rock lifted in its hands, the landing ring drawn, the rock standing as cover.
	var thrower: int = await s.spawn(ActorStore.Kind.STONE_THROWER, "ENEMY_STONE_THROWER")
	var lifted := false
	var ring := false
	var standing := false
	for k in 1200:
		var i := w.actors.index_of(thrower)
		if i < 0:
			break
		var av := _avatar(s, thrower) as StoneThrowerAvatar  # v0.11.0 O17c: on the owner's model
		lifted = lifted or (av != null and av.rock_lifted())
		ring = ring or (not reader.telegraph(i).is_empty() and s.main.view.telegraphs.count() > 0)
		standing = standing or rr.rock_count() > 0
		if lifted and ring and standing:
			break
		await s.e.frames(1)
	assert_true(lifted, "the Thrower lifts a rock")
	assert_true(ring, "its landing ring is drawn")
	assert_true(standing, "the rock stands as cover, drawn")
	assert_true(await s.shoot_dead(thrower, KILL_FRAMES), "the Stone Thrower is shot dead")
	# V2 Dim Needle: its shot is dark beyond 4 m of the hero (the sim's and the view's dark look).
	var needle: int = await s.spawn(ActorStore.Kind.DIM_NEEDLE, "ENEMY_DIM_NEEDLE")
	var fb: FireballViews = s.main.view.fireballs
	var dark := false
	var dark_drawn := false
	for k in 900:
		if not s.alive(needle):
			break
		for p in reader.projectile_count():
			dark = dark or reader.projectile_dark(p)
		dark_drawn = dark_drawn or fb.ball_count(FireballViews.DIM_DARK_LOOK) > 0
		if dark and dark_drawn:
			break
		await s.e.frames(1)
	assert_true(dark, "the Dim Needle's shot is dark far from the hero")
	assert_true(dark_drawn, "and drawn dark")
	assert_true(await s.shoot_dead(needle, KILL_FRAMES), "the Dim Needle is shot dead")
