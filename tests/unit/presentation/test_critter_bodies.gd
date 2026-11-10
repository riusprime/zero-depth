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
		var live := VatBake.reference_avatar(kind, Color(0, 0, 0, 0), 0.0)
		var vat := HordeAvatar.new()
		vat.vat = true
		vat.setup(kind)
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


## v0.11.0 O9c (owner Q16-c: "Batch now"): ActorViews gives every critter to the CritterCrowd: one MultiMesh per kind
## (the same baked look VatCrowd drew), no node of its own, whatever the VAT switch says.
func test_actor_views_draw_every_critter_through_the_crowd() -> void:
	for vat_on in [true, false]:
		ViewPrefs.enemy_vat = vat_on
		var w := CombatLab.world()
		var ids: Array[int] = []
		for k in KINDS.size():
			ids.append(w.add_enemy(KINDS[k], Vector2(2.0 + k * 1.5, 3.0)))
		var views: ActorViews = add_child_autofree(ActorViews.new())
		views.set_process(false)
		views.sync(WorldReader.new(w))
		assert_eq(views.critters.count(), KINDS.size(), "every critter (vat %s)" % vat_on)
		for k in KINDS.size():
			assert_null(views.actor_node(ids[k]), "kind %d: no node of its own" % KINDS[k])
			assert_true(views.draws(ids[k]), "kind %d is drawn" % KINDS[k])
		assert_true(views.vat_crowd == null or views.vat_crowd.count() == 0, "not on the VAT crowd")
		views.critters.advance(DT)
		assert_eq(views.critters.drawn, KINDS.size())
		assert_eq(views.critters.shadows_drawn, KINDS.size(), "their proxy shadows")
		var bodies := 0
		for m in views.critters.instances():
			if String(m.name).begins_with("CritterBodies"):
				bodies += 1
		assert_eq(bodies, KINDS.size(), "one body MultiMesh per kind")


## v0.11.0 O9c: a 120-critter surge makes no node per critter: the crowd's few MultiMesh nodes, the same with 1 or 120.
func test_a_120_critter_surge_makes_no_node_per_critter() -> void:
	ViewPrefs.enemy_vat = true
	var counts: Array[int] = []
	for n in [1, 120]:
		var w := CombatLab.world()
		for k in n:
			w.add_enemy(
				WorldReader.KIND_DUST_MITE, Vector2(2.0 + (k % 12) * 0.6, 3.0 + (k / 12) * 0.6)
			)
		var views: ActorViews = add_child_autofree(ActorViews.new())
		views.set_process(false)
		views.sync(WorldReader.new(w))
		views.critters.advance(DT)
		assert_eq(views.critters.drawn, n, "%d drawn" % n)
		counts.append(views.get_child_count(true) + views.critters.get_child_count(true))
		assert_lte(views.critters.get_child_count(true), 3, "bodies, shadows, bars")
	assert_eq(counts[0], counts[1], "as many nodes for 120 critters as for 1")


## v0.11.0 O9c: a critter's hit flash and status tint reach its instance by id; one gone from the sim is let go.
func test_a_critter_flashes_and_goes() -> void:
	ViewPrefs.enemy_vat = true
	var w := CombatLab.world()
	var a := w.add_enemy(WorldReader.KIND_EMBER_FLEA, Vector2(2.0, 3.0))
	var b := w.add_enemy(WorldReader.KIND_EMBER_FLEA, Vector2(4.0, 3.0))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	views.critters.advance(DT)
	assert_gt((views.critters.instance_of(a)["color"] as Color).a, 0.0, "at rest: its glow")
	views.flash(a)
	assert_true(views.is_flashing(a))
	views.critters.advance(DT)
	assert_lt((views.critters.instance_of(a)["color"] as Color).a, 0.0, "the hit shows")
	assert_gt((views.critters.instance_of(b)["color"] as Color).a, 0.0, "not on the other")
	for f in views.flash_frames:
		views._process(DT)
	views.critters.advance(DT)
	assert_gt((views.critters.instance_of(a)["color"] as Color).a, 0.0, "and ends")
	views.set_tint(b, Color.CYAN, 1.1)
	views.critters.advance(DT)
	assert_lt((views.critters.instance_of(b)["color"] as Color).a, 0.0, "a status tint shows")
	w.actors.hp[w.actors.index_of(b)] = 3
	w.actors.state[w.actors.index_of(b)] = WorldReader.STATE_MOVE
	views.sync(WorldReader.new(w))
	views.critters.advance(DT)
	assert_eq(views.critters.bars_drawn, 1, "a hurt critter shows its bar")
	w.actors.remove_sorted(PackedInt32Array([w.actors.index_of(a)]))
	views.sync(WorldReader.new(w))
	views.critters.advance(DT)
	assert_eq(views.critters.count(), 1, "the dead one is let go")
	assert_false(views.draws(a))
	assert_eq(views.critters.drawn, 1)
	assert_false(views.is_flashing(a))


## v0.11.0 O9c: the instance follows the sim's place and facing, and the bat flies over it.
func test_a_critter_instance_sits_on_its_place() -> void:
	ViewPrefs.enemy_vat = true
	ViewPrefs.reduced_motion = true
	var w := CombatLab.world()
	var id := w.add_enemy(WorldReader.KIND_CAVE_BAT, Vector2(5.0, -2.0))
	var i := w.actors.index_of(id)
	w.actors.state[i] = WorldReader.STATE_MOVE
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	views.critters.advance(DT)
	var xf: Transform3D = views.critters.instance_of(id)["xf"]
	assert_almost_eq(xf.origin.x, 5.0, 0.001)
	assert_almost_eq(xf.origin.z, 2.0, 0.001)
	assert_almost_eq(xf.origin.y, CritterBodies.BAT_FLY_M, 0.001, "the bat flies")


## The disc (CylinderMesh) and ring (TorusMesh) meshes straight under actor node `node`.
static func _rings(node: Node3D) -> int:
	var n := 0
	for c in node.get_children():
		var mi := c as MeshInstance3D
		if mi != null and (mi.mesh is TorusMesh or mi.mesh is CylinderMesh):
			n += 1
	return n


## v0.11.0 O9b (owner Q16-b: "No ring on critters"); v0.11.0 O9c: a critter has no node at all, so no disc and no
## ring; a Swarmer keeps both.
func test_no_ring_on_critters() -> void:
	ViewPrefs.enemy_vat = true
	var w := CombatLab.world()
	var ids: Array[int] = []
	for k in KINDS.size():
		ids.append(w.add_enemy(KINDS[k], Vector2(2.0 + k * 1.5, 3.0)))
	var swarmer := w.add_enemy(WorldReader.KIND_SWARMER, Vector2(2.0, 6.0))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	for k in KINDS.size():
		assert_null(views.actor_node(ids[k]), "kind %d: no node, no disc, no ring" % KINDS[k])
	assert_eq(_rings(views.actor_node(swarmer)), 2, "a Swarmer keeps its disc and its ring")


func test_the_bat_flies_the_mote_floats_the_flea_hops_and_the_crab_slides() -> void:
	ViewPrefs.reduced_motion = false
	var lifts := {}
	for kind in KINDS:
		var a := HordeAvatar.new()
		a.vat = true
		a.setup(kind)
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
