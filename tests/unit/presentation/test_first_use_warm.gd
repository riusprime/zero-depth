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
