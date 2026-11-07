extends GutTest
## v0.11.0 O9 (PLAN H1, M4; ENEMIES.md H1-H5; owner Q14: "same rules, its own body"): the five horde critters' code-made
## stand-in bodies (CritterBodies on HordeAvatar), each drawn through VAT (HordeVat's path: the bake matches the live
## pose within 2 mm) and through ActorViews' crowd, one look each; each a body of its own (not the Swarmer's, not each
## other's); the bat flies, the mote floats, the flea hops, the crab slides as it stops. A surge's cue plays a sound and
## shows its HUD line (en and es).

const DT := 1.0 / 60.0
const KINDS: Array[int] = [
	WorldReader.KIND_DUST_MITE,
	WorldReader.KIND_CAVE_BAT,
	WorldReader.KIND_EMBER_FLEA,
	WorldReader.KIND_ICE_CRAB,
	WorldReader.KIND_STAR_MOTE,
]

var _vat := false
var _calm := false
var _locale := "en"


func before_each() -> void:
	_vat = ViewPrefs.enemy_vat
	_calm = ViewPrefs.reduced_motion
	_locale = TranslationServer.get_locale()
	VatBake.clear_cache()


func after_each() -> void:
	ViewPrefs.enemy_vat = _vat
	ViewPrefs.reduced_motion = _calm
	TranslationServer.set_locale(_locale)


func test_each_biome_critter_bakes_within_2_mm() -> void:
	for kind in KINDS:
		assert_true(VatCrowd.supports(kind), "kind %d is drawn by VAT" % kind)
		assert_true(HordeAvatar.is_horde_kind(kind), "kind %d is a horde body" % kind)
		var pose := VatBake.pose_for(kind)
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var live := VatBake.reference_avatar(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var vat := HordeAvatar.new()
		vat.vat = true
		vat.setup(kind, Color.BLACK)
		var e := VatBake.pose_error_full(live, vat, pose, mesh, 40, 11)
		assert_eq(e["vertices"], mesh.surface_get_array_len(0), "kind %d: every vertex" % kind)
		assert_lt(float(e["max_m"]), 0.002, "kind %d within 2 mm: %s" % [kind, e])
		live.free()
		vat.free()


func test_each_body_is_its_own() -> void:
	var bodies := {}
	for kind in [WorldReader.KIND_SWARMER] + KINDS:
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var key := "%d / %.3v" % [mesh.surface_get_array_len(0), mesh.get_aabb().size]
		assert_false(bodies.has(key), "kind %d: a body of its own (%s)" % [kind, key])
		bodies[key] = kind
		if kind != WorldReader.KIND_SWARMER:
			assert_ne(
				CritterBodies.color(kind, &"body"),
				ThemePalette.UNKNOWN,
				"kind %d has its own colours" % kind
			)
	assert_eq(bodies.size(), 6, "six different meshes (the Swarmer and the five critters)")


func test_actor_views_draw_every_critter_through_the_crowd() -> void:
	ViewPrefs.enemy_vat = true
	var w := CombatLab.world()
	var ids: Array[int] = []
	for k in KINDS.size():
		ids.append(w.add_enemy(KINDS[k], Vector2(2.0 + k * 1.5, 3.0)))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	assert_eq(views.vat_crowd.count(), KINDS.size(), "every critter")
	assert_eq(views.vat_crowd.looks(), KINDS.size(), "one look (one MultiMesh) per kind")
	for k in KINDS.size():
		var avatar := views.actor_node(ids[k]).get_meta(&"enemy_avatar") as HordeAvatar
		assert_true(avatar.vat, "kind %d" % KINDS[k])
		assert_eq(avatar.find_children("*", "MeshInstance3D", true, false).size(), 0)
	views.vat_crowd._process(DT)
	assert_eq(views.vat_crowd.drawn, KINDS.size())


func test_the_bat_flies_the_mote_floats_the_flea_hops_and_the_crab_slides() -> void:
	ViewPrefs.reduced_motion = false
	var lifts := {}
	for kind in KINDS:
		var a := HordeAvatar.new()
		a.vat = true
		a.setup(kind, Color.BLACK)
		a.apply_state({"tick": 0, "state": WorldReader.STATE_MOVE})
		var lo := 99.0
		var hi := -99.0
		for f in 60:
			a.advance(DT)
			var y := a.vat_offset().origin.y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		lifts[kind] = [lo, hi]
		a.free()
	assert_gt(lifts[WorldReader.KIND_CAVE_BAT][0], CritterBodies.BAT_FLY_M * 0.8, "the bat flies")
	assert_gt(
		lifts[WorldReader.KIND_STAR_MOTE][0], CritterBodies.MOTE_FLOAT_M * 0.8, "the mote floats"
	)
	assert_gt(lifts[WorldReader.KIND_EMBER_FLEA][1], CritterBodies.HOP_M * 0.8, "the flea hops up")
	assert_lt(lifts[WorldReader.KIND_EMBER_FLEA][0], 0.03, "and lands")
	assert_lt(lifts[WorldReader.KIND_DUST_MITE][1], 0.05, "the mite stays on the ground")
	var slide: Array = CritterBodies.body_move(WorldReader.KIND_ICE_CRAB, 0.0, 0.5, false)
	assert_almost_eq(
		(slide[0] as Vector3).x, CritterBodies.SLIDE_M, 0.001, "the crab slides forward as it stops"
	)
	var none: Array = CritterBodies.body_move(WorldReader.KIND_ICE_CRAB, 0.0, -1.0, false)
	assert_eq((none[0] as Vector3).x, 0.0, "and not while it walks")
	var calm: Array = CritterBodies.body_move(WorldReader.KIND_EMBER_FLEA, 0.3, -1.0, true)
	assert_eq((calm[0] as Vector3).y, 0.0, "reduced motion: no hop")


func test_a_surge_plays_its_sound_and_shows_its_line() -> void:
	var w := SaveLab.floor_world(3, 1)
	w.critter_kind = WorldReader.KIND_DUST_MITE
	w.actors.invuln[0] = 1 << 24
	if w.boss_flow != null:
		w.boss_flow.arrive_left = 0
	var r := WorldReader.new(w)
	var ev := AudioEvents.new()
	ev.prime(r)
	var hud := PhaseHud.new()
	add_child_autofree(hud)
	hud.sync(r)
	w.surge_at = PackedInt32Array([w.run_ticks + 2])
	w.surge_sizes = PackedInt32Array([30])
	var cues := []
	for k in 4:
		w.step(InputFrame.new())
		for c: Array in ev.collect(r):
			cues.append(c[0])
	assert_true(r.surge_running(), "the surge began")
	assert_has(cues, &"ambush_start", "its sound")
	TranslationServer.set_locale("en")
	hud.sync(r)
	assert_eq(hud.current_entry(), PackedStringArray(["HUD_SURGE", ""]), "its HUD line")
	assert_eq(hud.announcement(), "A horde is coming!")
	TranslationServer.set_locale("es")
	assert_eq(hud.line(PackedStringArray(["HUD_SURGE", ""])), "¡Se acerca una horda!")
