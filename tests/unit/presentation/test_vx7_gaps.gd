# gdlint: disable=max-public-methods
extends GutTest
## v0.10.0 VX7 (VFX_PACK "Gaps built in the pack's style", N2, N4, N5, N8, N9): the bleed status, the Glaive disc, the
## Wave crest, the Nemesis crescent, the void rift, the Tidecaller's water and the lasting floor marks are drawn with
## the pack's effects or materials (PackFx, data/vfx/pack_fx_vx7.tres, assets/vfx_zd). Each has the old look as its
## fallback: no pack, or no room in the effect's family.

const W := preload("res://tests/support/mx4_world.gd")
const DT := 1.0 / 60.0

var _layer: VfxLayer
var _fx: PackFx
var _saved := ""


func before_each() -> void:
	_saved = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	_layer = add_child_autofree(VfxLayer.new())
	_fx = add_child_autofree(PackFx.new())
	_layer.pack_fx = _fx


func after_each() -> void:
	ViewPrefs.effects_density = _saved


func _frame(now: float, draw: Callable) -> void:
	_layer.begin(now)
	draw.call()
	_layer.finish()


func _live(id: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Dictionary in _fx.get(&"_live"):
		if e["id"] == id:
			out.append(e["node"])
	return out


func _fill(family: StringName, id: StringName) -> void:
	for k in _fx.cap_for(family):
		_fx.spawn(id, Vector3.ZERO, 1.0, {}, 0.0)


# --- The table and the new scene -------------------------------------------------------------------------------------
func test_the_table_has_every_vx7_id_and_validates() -> void:
	for id: StringName in [
		&"vx7_bleed_drips",
		&"vx7_glaive_ring",
		&"vx7_wave_wash",
		&"vx7_tide_disc",
		&"vx7_tide_swell",
		&"vx7_tide_bubble",
	]:
		assert_true(_fx.has_id(id), "%s is in the table" % id)
	var def := PackFx.shared_def()
	assert_eq(def.validate().size(), 0)
	for id: StringName in [&"vx7_bleed_splat", &"vx7_mark_frost", &"vx7_mark_splat"]:
		assert_false(
			_fx.has_id(id), "v0.10.0 FX: %s is gone (no pack effect on the floor marks)" % id
		)


func test_the_drips_scene_is_particles_with_gravity_in_bleeds_red() -> void:
	var scene := load("res://assets/vfx_zd/bleed/drips.tscn") as PackedScene
	var n := scene.instantiate()
	add_child_autofree(n)
	var parts := n.find_children("*", "GPUParticles3D", true, false)
	assert_eq(parts.size(), 1)
	var p := parts[0] as GPUParticles3D
	var pm := p.process_material as ParticleProcessMaterial
	assert_lt(pm.gravity.y, -5.0, "they fall")
	assert_lt(float(p.amount) / p.lifetime, 8.0, "a few a second")
	var mat := p.material_override as ShaderMaterial
	var c: Color = mat.get_shader_parameter(&"primary_color")
	assert_gt(c.r, c.g * 3.0, "red")
	assert_lt(c.r, 0.8, "dark")


# --- N2 bleed --------------------------------------------------------------------------------------------------------
func test_a_bleeding_enemy_holds_one_drips_effect_and_it_ends_with_the_bleed() -> void:
	for k in 4:
		_frame(float(k), func() -> void: _layer.status(Vector3.ZERO, 0.4, {&"bleed": 2}, 11, 0.9))
	assert_eq(_live(&"vx7_bleed_drips").size(), 1, "one effect for four frames")
	assert_eq(_fx.live_count(&"status"), 1)
	var n := _live(&"vx7_bleed_drips")[0]
	assert_eq(n.get(&"primary_color"), ElementLooks.core(&"bleed"), "bleed's colour")
	_frame(5.0, func() -> void: pass)
	assert_eq(_live(&"vx7_bleed_drips").size(), 0, "released when the bleed ended")


## v0.10.0 FX (owner: "remove residual ground effects"): a bleeding enemy lays the old splat decal alone.
func test_the_bleed_splat_is_the_decal_alone() -> void:
	for k in 5:
		_frame(float(k), func() -> void: _layer.status(Vector3.ZERO, 0.4, {&"bleed": 1}, 12, 0.9))
	assert_eq(_fx.live_count(&"mark"), 0, "no pack splatter")
	assert_gte(
		(
			_layer.marks_of(&"splat0")
			+ _layer.marks_of(&"splat1")
			+ _layer.marks_of(&"splat2")
			+ _layer.marks_of(&"splat3")
		),
		1,
		"the decal"
	)


func test_a_full_status_family_draws_the_old_drips() -> void:
	_fill(&"status", &"status_poison")
	assert_false(_fx.has_room(&"status"))
	_frame(0.0, func() -> void: _layer.status(Vector3.ZERO, 0.4, {&"bleed": 1}, 13, 0.9))
	assert_eq(_live(&"vx7_bleed_drips").size(), 0, "no slot taken")
	assert_gt(_layer.used(&"splash"), 0, "the old drips draw")


func test_without_a_pack_the_bleed_status_draws_the_old_way() -> void:
	var layer: VfxLayer = add_child_autofree(VfxLayer.new())
	layer.begin(0.0)
	layer.status(Vector3.ZERO, 0.4, {&"bleed": 1}, 14, 0.9)
	layer.finish()
	assert_gt(layer.used(&"splash"), 0)


# --- N5 void ---------------------------------------------------------------------------------------------------------
## v0.10.0 FX (owner: "restore the previous Void"): the patch and the blast are their v0.9.5 sprites again.
func test_the_void_patch_and_blast_are_their_old_sprites() -> void:
	_frame(0.0, func() -> void: _layer.field(&"void", Vector3(1, 0, 1), 2.0, 1.0, 0.0, 5))
	assert_gt(_layer.used(&"rift"), 0, "the rift sprite")
	assert_gt(_layer.used(&"tendril"), 0, "the tendrils")
	_frame(1.0, func() -> void: _layer.burst(&"void", Vector3.ZERO, 2.0, 0.1, 6))
	assert_eq(_fx.spawned, 0, "no pack effect")
	assert_gt(_layer.used(&"rift"), 0)


# --- N9 floor marks --------------------------------------------------------------------------------------------------
## v0.10.0 FX: a lasting mark is its decal alone (the frozen pack effects on them are gone).
func test_a_frost_mark_is_a_decal_alone() -> void:
	_frame(
		0.0, func() -> void: _layer.mark(1, &"frost", Vector3(2, 0, 2), 1.0, VfxLayer.FROST_MARK)
	)
	assert_eq(_layer.marks_of(&"frost"), 1)
	assert_eq(_fx.spawned, 0, "no pack effect")


# --- N4 Glaive, Wave, crescent ---------------------------------------------------------------------------------------
func test_a_glaive_disc_wears_a_held_pack_ring_that_ends_with_the_disc() -> void:
	var view: GlaiveView = add_child_autofree(GlaiveView.new())
	view.pack_fx = _fx
	var w := W.world(&"gun", [&"gun_glaive"])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	view.sync(r)
	view.sync(r)
	assert_eq(view.discs, 1)
	assert_eq(_live(&"vx7_glaive_ring").size(), 1, "one ring on the one disc")
	assert_eq(view.ring_hold.count(), 1)
	var n := _live(&"vx7_glaive_ring")[0]
	assert_eq(n.get(&"primary_color"), view._form.core, "the disc's colours")
	W.run(w, 200, 0, 0)
	view.sync(r)
	assert_eq(view.discs, 0)
	assert_eq(_live(&"vx7_glaive_ring").size(), 0, "caught: the ring went back")


func test_a_glaive_disc_without_a_pack_is_as_before() -> void:
	var view: GlaiveView = add_child_autofree(GlaiveView.new())
	var w := W.world(&"gun", [&"gun_glaive"])
	W.run(w, 1, 0, W.S)
	view.sync(WorldReader.new(w))
	assert_eq(view.discs, 1)
	assert_eq(view.ring_hold.count(), 0)


func test_a_wave_wears_the_pack_crest_and_a_held_ripple_wash() -> void:
	var view: WaveView = add_child_autofree(WaveView.new())
	view.pack_fx = _fx
	var w := W.world(&"gun", [&"gun_wave"])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	view.sync(r)
	assert_true(view.crest_packed)
	var crest := view.get(&"_crests")[0] as MeshInstance3D
	var mat := crest.material_override as ShaderMaterial
	assert_true(mat.shader.resource_path.ends_with("transparent.gdshader"), "the pack's shader")
	assert_eq(mat.get_shader_parameter(&"primary_color"), view._form.edge.lightened(0.3))
	assert_eq(_live(&"vx7_wave_wash").size(), 1, "the wash is the held ripple")
	assert_false((view.get(&"_washes")[0] as MeshInstance3D).visible, "the flat wash hides")
	W.run(w, 200, 0, 0)
	view.sync(r)
	assert_eq(view.waves, 0)
	assert_eq(_live(&"vx7_wave_wash").size(), 0, "gone with the wave")


func test_a_wave_without_a_pack_keeps_the_shader_crest_and_flat_wash() -> void:
	var view: WaveView = add_child_autofree(WaveView.new())
	var w := W.world(&"gun", [&"gun_wave"])
	W.run(w, 1, 0, W.S)
	view.sync(WorldReader.new(w))
	assert_false(view.crest_packed)
	assert_true((view.get(&"_washes")[0] as MeshInstance3D).visible)


func test_the_nemesis_crescent_keeps_its_shape_with_the_pack_rim_material() -> void:
	var w := CombatLab.world()
	var fb := FireballViews.new()
	add_child_autofree(fb)
	w.projectiles.add(731, -1, 1, Vector2(1, 1), Vector2(1, 0), 0.18, 600)
	w.projectiles.set_look(w.projectiles.ids.size() - 1, &"nemesis_crescent")
	fb.sync(WorldReader.new(w))
	assert_eq(fb.core_count(&"nemesis_crescent"), 1)
	var core: MultiMeshInstance3D = fb.get(&"_sets")[&"nemesis_crescent"]["core"]
	var mat := core.material_override as ShaderMaterial
	assert_true(mat.shader.resource_path.ends_with("transparent.gdshader"), "the pack's rim glow")
	var plain := ProjectileMeshes.get_mesh(&"crescent")
	assert_eq(core.multimesh.mesh.get_faces().size(), plain.get_faces().size(), "the same shape")
	assert_gt(core.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size(), 0, "with UVs")
	assert_eq(
		mat.get_shader_parameter(&"primary_color"),
		FireballViews.look_of(&"nemesis_crescent")["core"],
		"its own colours"
	)


# --- N8 water --------------------------------------------------------------------------------------------------------
func _pull_view(with_pack: bool) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"tidecaller")
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(-8, 0))
	var t := BossAi.table_of(w, i)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.sig_every_ticks = 0
	t.punish_ticks = 0
	BossLab.start(w, i, &"the_pull")
	var view := TideViews.new()
	add_child_autofree(view)
	view.set_process(false)
	if with_pack:
		view.pack_fx = _fx
	CombatLab.until(
		w,
		func(x: World) -> bool:
			return x.actors.state[x.actors.index_of(aid)] == EnemyAi.State.ACTIVE
	)
	return [w, view, WorldReader.new(w)]


func test_the_tide_disc_is_a_held_ripple_and_the_spray_pops_in_blue() -> void:
	var r := _pull_view(true)
	var w: World = r[0]
	var view: TideViews = r[1]
	for k in 90:
		w.step(InputFrame.new())
		view.sync(r[2])
		view.advance(DT)
	assert_gt(view.strength(), 0.5)
	assert_eq(_live(&"vx7_tide_disc").size(), 1, "one disc")
	assert_false((view.get(&"_disc") as MeshInstance3D).visible, "the shader disc hides")
	assert_lt(_live(&"vx7_tide_disc")[0].get(&"speed_scale"), 0.0, "the rings run in on a pull")
	assert_gt(view.pops, 0, "bubbles popped")
	assert_eq(view.bubbles_drawn(), 0, "in place of the droplets")
	var n := _fx.spawned
	assert_gt(n, 2)


func test_without_a_pack_the_tide_is_as_before() -> void:
	var r := _pull_view(false)
	var w: World = r[0]
	var view: TideViews = r[1]
	for k in 90:
		w.step(InputFrame.new())
		view.sync(r[2])
		view.advance(DT)
	assert_true((view.get(&"_disc") as MeshInstance3D).visible)
	assert_eq(view.bubbles_drawn(), TideViews.BUBBLES)
	assert_eq(view.pops, 0)


func test_a_full_area_family_keeps_the_shader_disc() -> void:
	var r := _pull_view(true)
	_fill(&"area", &"zone_frost_a")
	var w: World = r[0]
	var view: TideViews = r[1]
	for k in 60:
		w.step(InputFrame.new())
		view.sync(r[2])
		view.advance(DT)
	assert_eq(_live(&"vx7_tide_disc").size(), 0)
	assert_true((view.get(&"_disc") as MeshInstance3D).visible)
