extends GutTest
## v0.10.5 (owner PERF_PLAYLOG_1: view.fireballs 53.1 ms on f1 and 47.3 ms on f2, view.elite_fx 56.2 ms on f4, each the
## first time the effect showed): after the floor's load (FireballViews.prepare, FireballPack.prefill,
## EliteViews.prepare, PackFx.prefill) the first fireballs and the first elite's effects build no node, mesh or
## material: they come from the pools and caches made behind the cover, which ShaderWarmup draws once.


## A node BossPackHold.find reads a PackFx from (WorldViewRoot's `pack_fx`).
class Holder:
	extends Node3D
	var pack_fx: PackFx


var _density := ""


func before_each() -> void:
	_density = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"


func after_each() -> void:
	ViewPrefs.effects_density = _density


static func _resources() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))


func _fireballs(prepared: bool) -> Array:
	var w := CombatLab.world()
	var fb := FireballViews.new()
	add_child_autofree(fb)
	var pack := PackFx.new()
	add_child_autofree(pack)
	fb.pack_fx = pack
	if prepared:
		fb.prepare()
		for id in FireballPack.ids():
			FireballPack.prefill(pack, id)
	return [w, fb, pack, WorldReader.new(w)]


## A first volley: four shots of two looks (a packed look and the crescent, which keeps its MultiMesh core).
func _volley(w: World) -> void:
	var n := 0
	for key: StringName in [&"arc_plasma", &"nemesis_crescent"]:
		for k in 2:
			w.projectiles.add(900 + n, -1, 1, Vector2(2 + n, 1), Vector2(4, 0), 0.18, 600)
			w.projectiles.set_look(w.projectiles.ids.size() - 1, key)
			n += 1


func test_the_load_makes_every_looks_set_and_fills_the_shot_pools() -> void:
	var r := _fireballs(true)
	var fb: FireballViews = r[1]
	var pack: PackFx = r[2]
	assert_eq((fb.get(&"_sets") as Dictionary).size(), FireballViews.LOOKS.size(), "a set per look")
	assert_eq(fb.get_child_count(), 3 * FireballViews.LOOKS.size(), "three MultiMeshes a look")
	for id in FireballPack.ids():
		assert_eq(pack.pooled(id), FireballPack.PREFILL, "%s: its pool is filled" % id)
	assert_eq(pack.live_count(), 0, "nothing shows")


func test_the_first_fireballs_build_nothing_after_the_load() -> void:
	var r := _fireballs(true)
	var w: World = r[0]
	var fb: FireballViews = r[1]
	var pack: PackFx = r[2]
	var nodes := fb.get_child_count() + pack.get_child_count()
	var res := _resources()
	_volley(w)
	fb.sync(r[3])
	assert_eq(pack.live_count(&"enemy_shot"), 2, "the arc plasma shots are pack effects")
	assert_eq(fb.core_count(&"nemesis_crescent"), 2, "the crescents draw")
	assert_eq(fb.get_child_count() + pack.get_child_count(), nodes, "no node made")
	assert_eq(_resources() - res, 0, "no mesh, material or other resource made")


func test_without_the_load_the_first_fireballs_build_their_sets() -> void:
	var r := _fireballs(false)
	var w: World = r[0]
	var fb: FireballViews = r[1]
	var res := _resources()
	_volley(w)
	fb.sync(r[3])
	assert_eq(fb.get_child_count(), 6, "the old lazy build: two looks' sets on their first shot")
	assert_gt(_resources() - res, 0, "(what the load now does ahead)")


func _elites() -> Array:
	var holder: Holder = add_child_autofree(Holder.new())
	var pack := PackFx.new()
	holder.add_child(pack)
	holder.pack_fx = pack
	var ev := EliteViews.new()
	holder.add_child(ev)
	ev.prepare()
	for id in EliteViews.pack_ids():
		pack.prefill(id, EliteViews.PACK_PREFILL)
	return [ev, pack]


func test_the_load_fills_the_elite_pools() -> void:
	var r := _elites()
	var ev: EliteViews = r[0]
	var pack: PackFx = r[1]
	for use: StringName in EliteViews.PREFILL:
		assert_eq(ev.idle_rings(use), int(EliteViews.PREFILL[use]), "%s rings waiting" % use)
	assert_eq(ev.has_pooled_sigil(), PackFx.available() and MagicArea.kinds().has("circle"))
	for id in EliteViews.pack_ids():
		assert_eq(pack.pooled(id), EliteViews.PACK_PREFILL, "%s waiting" % id)
	assert_true(ev.has_meta(ShaderWarmup.WARM_META), "the warm-up draws its pieces")


func test_the_first_elites_arrival_slam_rift_and_beam_build_nothing_after_the_load() -> void:
	var r := _elites()
	var ev: EliteViews = r[0]
	var pack: PackFx = r[1]
	var nodes := ev.get_child_count() + pack.get_child_count()
	var res := _resources()
	ev._arrival(Vector2(3, 3))
	ev._dust(Vector2(1, 1))
	ev._rift(7, {"radius": 2.0, "center": Vector2(4, 0), "locked": false})
	ev._beam(Obb.make(Vector2(5, 0), Vector2(5.0, 0.8), 0))
	assert_eq(ev.fx_count(), 2, "the arrival's burst and the slam's dust")
	assert_eq(ev.mark_count(), 1, "the rift")
	assert_eq(pack.live_count(&"beam"), 1, "the Conduit's pack beam")
	assert_eq(ev.get_child_count() + pack.get_child_count(), nodes, "no node made")
	assert_eq(_resources() - res, 0, "no mesh, material or other resource made")
	var area: MagicArea = null
	for c in ev.get_children():
		if c is MagicArea and (c as MagicArea).visible:
			area = c
	assert_not_null(area, "the pooled sigil plays")
	assert_eq(area.element, "shadow")
	assert_almost_eq(area.radius, EliteViews.SIGIL_R, 0.001)


func test_the_pooled_sigil_and_rings_go_back_hidden_and_play_again() -> void:
	var r := _elites()
	var ev: EliteViews = r[0]
	ev._arrival(Vector2(3, 3))
	ev._process(1.0)
	assert_eq(ev.fx_count(), 0, "the burst ended")
	assert_eq(ev.idle_rings(&"arrive"), 1, "its ring is back in the pool")
	var area: MagicArea = null
	for c in ev.get_children():
		if c is MagicArea:
			area = c
	assert_not_null(area)
	for k in 120:  # forms, holds, fades (about ARRIVE_S); it hides rather than freeing itself
		area._process(1.0 / 60.0)
	assert_true(is_instance_valid(area) and not area.is_queued_for_deletion(), "kept")
	assert_false(area.visible, "hidden once faded")
	var res := _resources()
	ev._arrival(Vector2(-2, 0))
	assert_true(area.visible, "the next arrival plays it again")
	assert_eq(_resources() - res, 0, "and makes nothing")


func test_the_warmup_draws_the_elite_pools_and_the_looks_sets() -> void:
	if not RenderSwitches.SHADER_WARMUP:
		pass_test("switched off")
		return
	var root := Node3D.new()
	add_child_autofree(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var ev := EliteViews.new()
	root.add_child(ev)
	var bare := ShaderWarmup.build(root, cam, null)
	autofree(bare)
	ev.prepare()
	var fb := FireballViews.new()
	root.add_child(fb)
	fb.prepare()
	var w := ShaderWarmup.build(root, cam, null)
	autofree(w)
	# the three ring meshes, the sigil's disc and sparks; the looks' sets (one proxy per mesh and material)
	assert_gte(w.hidden_proxies - bare.hidden_proxies, 3 + 2 + FireballViews.LOOKS.size())


# --- v0.10.5: every other pack id, the telegraphs and the status rings ------------------------------------------
func test_the_floor_fills_every_other_pack_pool_and_leaves_the_bosses_rows_to_boss_floors() -> void:
	if not PackFx.available():
		pass_test("no pack table")
		return
	var pack: PackFx = add_child_autofree(PackFx.new())
	var plain := PackPrefill.ids(pack, false)
	var boss := PackPrefill.ids(pack, true)
	assert_false(plain.has(&"bx_rail"), "a boss's rail only where a boss is")
	assert_true(boss.has(&"bx_rail"))
	assert_true(plain.has(&"bx_flash"), "the hero's blink flash on any floor")
	for id in FireballPack.ids() + EliteViews.pack_ids():
		assert_false(boss.has(id), "%s: its own prefill" % id)
	assert_true(plain.has(&"vx1_hit_plain") and plain.has(&"status_burn_a"), "hits and statuses")
	for id in plain:
		PackPrefill.fill(pack, id)
	for id in plain:
		assert_eq(pack.idle_count(id), PackPrefill.count(id), "%s: its pool is filled" % id)
	assert_eq(pack.live_count(), 0, "nothing shows")


func test_the_first_use_of_every_floor_pack_id_builds_nothing_after_the_load() -> void:
	if not PackFx.available():
		pass_test("no pack table")
		return
	var pack: PackFx = add_child_autofree(PackFx.new())
	var ids := PackPrefill.ids(pack, true)
	for id in ids:
		PackPrefill.fill(pack, id)
	var nodes := pack.get_child_count()
	var res := _resources()
	var shown := 0
	for id in ids:
		if pack.spawn(id, Vector3(1, 0, 1)) != null:
			shown += 1
	assert_eq(shown, ids.size(), "every id plays")
	assert_eq(pack.get_child_count(), nodes, "no node made")
	assert_eq(_resources() - res, 0, "no mesh, material or other resource made")


func test_an_id_used_more_at_once_earlier_gets_a_bigger_pool() -> void:
	if not PackFx.available():
		pass_test("no pack table")
		return
	var pack: PackFx = add_child_autofree(PackFx.new())
	var id := &"vx1_hit_frost"
	for k in PackPrefill.PER_ID + 2:
		pack.spawn(id, Vector3.ZERO)
	assert_gte(PackFx.peak(id), PackPrefill.PER_ID + 2, "the session's most at once")
	assert_eq(PackPrefill.count(id), mini(PackFx.peak(id), PackPrefill.PEAK_MAX))
	var next: PackFx = add_child_autofree(PackFx.new())
	PackPrefill.fill(next, id)
	assert_eq(next.idle_count(id), PackPrefill.count(id), "the next floor fills that many")


func test_the_load_pools_every_prepared_telegraph_and_the_looks_materials() -> void:
	var tv: TelegraphViews = add_child_autofree(TelegraphViews.new())
	tv.prepare()
	for pair: Array in TelegraphViews.PREPARED:
		assert_eq(tv.idle_count(pair[0], pair[1]), TelegraphViews.POOL_N, "%s/%s pooled" % pair)
	assert_eq(tv.count(), 0, "nothing shows")
	var nodes := tv.get_child_count()
	var res := _resources()
	var taken: Array[Node3D] = []
	for pair: Array in TelegraphViews.PREPARED:
		taken.append(tv._take(pair[0], pair[1]))
	for look: StringName in BossStrikeLooks.LOOKS:
		tv._look_pair(look)
	assert_eq(tv.get_child_count(), nodes, "no node made")
	assert_eq(_resources() - res, 0, "no mesh or material made")
	for n in taken:
		assert_true(n.visible, "shown")
		tv._put_back(n)
		assert_false(n.visible, "back hidden")
	assert_eq(tv.idle_count(&"disc", &"rune"), TelegraphViews.POOL_N, "and pooled again")


func test_a_bosss_first_windup_builds_nothing_after_the_load() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
	w.actors.set_pos(0, Vector2(6, 0))
	w.actors.hp[0] = 1 << 20
	BossLab.start(w, i, &"fist_slam")
	var atk := BossAi.attack_of(w, i)
	CombatLab.idle(w, atk.windup_ticks - atk.lock_ticks + 2)
	var tv: TelegraphViews = add_child_autofree(TelegraphViews.new())
	tv.prepare()
	var nodes := tv.get_child_count()
	var res := _resources()
	tv.sync(WorldReader.new(w))
	assert_eq(tv.count(), 1, "the slam's marks show")
	assert_eq(tv.get_child_count(), nodes, "a pooled telegraph, no node made")
	assert_eq(_resources() - res, 0, "no mesh or material made")
	CombatLab.idle(w, atk.lock_ticks + 60)
	tv.sync(WorldReader.new(w))
	assert_eq(tv.get_child_count(), nodes, "it went back to its pool, not freed")


func test_the_first_payoff_rings_and_bolt_build_nothing_after_the_load() -> void:
	var actors: ActorViews = add_child_autofree(ActorViews.new())
	var fx: StatusVisuals = add_child_autofree(StatusVisuals.new(actors))
	fx.prepare()
	assert_eq(fx.idle_fx(), StatusVisuals.FX_PREFILL)
	var nodes := fx.get_child_count()
	var res := _resources()
	for r in StatusVisuals.RING_RADII:
		fx._ring(Vector2(1, 1), r, Color.RED)
	assert_eq(fx.fx_count(), StatusVisuals.RING_RADII.size(), "the rings fade in")
	assert_eq(fx.get_child_count(), nodes, "pooled rings, no node made")
	assert_eq(_resources() - res, 0, "shared ring meshes, no mesh or material made")
	for k in StatusVisuals.FX_FRAMES:
		fx._process(1.0 / 60.0)
	assert_eq(fx.fx_count(), 0, "faded")
	assert_eq(fx.idle_fx(), StatusVisuals.FX_PREFILL, "back in the pool")
	fx._bolt_line(Vector2.ZERO, Vector2(3, 0), Color.CYAN)
	assert_eq(fx.fx_count(), 4, "a bolt's four segments, from the pool")
	assert_eq(fx.get_child_count(), nodes)
	assert_eq(_resources() - res, 0)
