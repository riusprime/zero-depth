extends GutTest
## v0.10.5 W3-S4 (owner F5, F8, F10, 2026-11-04): a player hit's pack scenes are gone by ~0.3 s of sim time (F10); the
## hero's fire patches draw smaller and dimmer than the sim's, and at most PATCH_MAX at once, the oldest faded (F5);
## a hook blast is drawn at its damage's weight and a burst of them keeps to the second's budget (F8). The sim's numbers
## are untouched (presentation only).

const MX4 := preload("res://tests/support/mx4_world.gd")

var _layer: VfxLayer
var _fx: PackFx
var _saved := ""


func before_each() -> void:
	_saved = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	HitPack.clear()
	_layer = add_child_autofree(VfxLayer.new())
	_fx = add_child_autofree(PackFx.new())
	_layer.pack_fx = _fx


func after_each() -> void:
	ViewPrefs.effects_density = _saved


func _frame(now: float, draw: Callable = Callable()) -> void:
	_layer.begin(now)
	if draw.is_valid():
		draw.call()
	_layer.finish()


func _live(id: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Dictionary in _fx._live:
		if e["id"] == id:
			out.append(e["node"])
	return out


# --- F10: hits clear in ~0.2 s ---------------------------------------------------------------------------------
func test_every_hit_scene_the_code_spawns_is_short() -> void:
	var ids: Array = [HitPack.SLASH, HitPack.GUARD, HitPack.WEAK, HitPack.DEFLECT]
	for kind: StringName in [&"fire", &"frost", &"storm", &"venom", &"bleed", &"void", &""]:
		ids.append(HitPack.hit_id(kind, false))
		ids.append(HitPack.hit_id(kind, true))
	ids.append_array([&"vx2_hit_rune", &"vx2_hit_bounce", &"vx2_hit_crit"])
	for id: StringName in ids:
		assert_true(PackFx.SHORT.has(id), "%s is capped" % id)
		var cap: Array = PackFx.SHORT[id]
		assert_lte(float(cap[0]), 0.25, "%s plays within 0.25 s" % id)
		assert_lte(float(cap[1]) / 60.0, 0.3, "%s is gone by 0.3 s of sim time" % id)
	assert_lte(ImpactFx.LIFE_TICKS / 60.0, 0.25, "the old sprites too")


func test_a_bolt_hit_is_gone_by_its_ticks_and_plays_sped_up() -> void:
	_frame(100.0, func() -> void: HitPack.hit(_layer, &"fire", Vector3.ZERO, 0.0, 5, 1.0))
	var nodes := _live(&"vx1_hit_ember")
	assert_eq(nodes.size(), 1, "spawned")
	assert_gt(float(nodes[0].get("speed_scale")), 3.0, "its 0.8 s scene sped up to fit 0.2 s")
	_frame(110.0)
	assert_eq(_fx.live_count(&"hit"), 1, "still there 10 ticks on")
	_frame(115.0)
	assert_eq(_fx.live_count(&"hit"), 0, "gone 15 ticks (0.25 s) on")
	assert_false(nodes[0].visible)


func test_a_heavy_impact_and_a_slash_go_too_and_a_pause_keeps_them() -> void:
	_frame(
		200.0,
		func() -> void:
			HitPack.hit(_layer, &"frost", Vector3.ZERO, 0.0, 6, 1.5)
			HitPack.slash(_layer, &"", Vector3(2, 0, 0), Vector3.RIGHT, 0.0, 7, 1.5)
	)
	assert_eq(_fx.live_count(&"impact"), 2, "the heavy hit's and the finisher's impact")
	assert_eq(_live(HitPack.SLASH).size(), 1)
	_frame(200.0)  # the sim did not move (a pause, a hit-stop): nothing ages on the sim's clock
	assert_eq(_fx.live_count(&"impact"), 2)
	_frame(218.0)
	assert_eq(_fx.live_count(&"impact"), 0, "the impacts gone by 18 ticks (0.3 s)")
	assert_eq(_fx.live_count(&"hit"), 0, "the slash by 15")


func test_a_short_scene_also_ends_on_real_time_without_frames() -> void:
	_fx.spawn(&"vx1_hit_plain", Vector3.ZERO)
	_fx.advance(0.31)
	assert_eq(_fx.live_count(&"hit"), 0, "within 0.3 s even when no draw time comes")


func test_an_explosion_keeps_its_own_length() -> void:
	_frame(300.0, func() -> void: _fx.spawn(&"explosion_fire_a", Vector3.ZERO))
	_frame(330.0)
	assert_eq(_fx.live_count(&"explosion"), 1, "not a hit: its scene's own life")


# --- F5: quieter fire patches ----------------------------------------------------------------------------------
func test_a_hero_fire_patch_draws_inside_the_sims_radius_dim_and_flat() -> void:
	var r := 1.6
	_layer.begin(0.0)  # (one frame: a patch not drawn in a frame goes back to its pool)
	_layer.field(&"fire", Vector3.ZERO, r, 1.0, 0.0, 4)
	_layer.field(&"fire", Vector3(9, 0, 9), r, 1.0, 0.0, 5, true)
	var hero := _live(&"zone_fire_a")[0]
	var foe := _live(&"zone_fire_foe_b")[0]
	var full := r * float(VfxPackViews.ZONE_PER_M[&"zone_fire_a"])
	assert_almost_eq(
		hero.scale.x, full * VfxPackViews.FIRE_DRAW_R, 0.001, "drawn at 0.8 of the sim's"
	)
	assert_lt(hero.scale.x, full)
	assert_almost_eq(
		foe.scale.x,
		r * float(VfxPackViews.ZONE_PER_M[&"zone_fire_foe_b"]),
		0.001,
		"a threat's as was"
	)
	var wave := hero.get_node("WaveMesh") as MeshInstance3D
	var mat := wave.material_override as ShaderMaterial
	var glow: Color = mat.get_shader_parameter(&"glow_color")
	var edge: Color = mat.get_shader_parameter(&"edge_color")
	assert_eq(glow, edge, "no white-hot core: the glow is the edge's colour")
	assert_lte(maxf(glow.r, maxf(glow.g, glow.b)), VfxPackViews.FIRE_DIM + 0.001, "dimmed")
	assert_almost_eq(wave.transparency, 1.0 - VfxPackViews.FIRE_ALPHA, 0.001, "low alpha")
	var sparks := hero.get_node("sparks") as GPUParticles3D
	assert_almost_eq(sparks.amount_ratio, VfxPackViews.FIRE_SPARKS, 0.001, "fewer rising sparks")
	_layer.finish()


func test_a_hero_fire_patch_lights_the_room_less() -> void:
	_layer.begin(0.0)
	_layer.field(&"fire", Vector3.ZERO, 1.6, 1.0, 0.0, 4)
	var hero: float = _layer._light_wants[0][2]
	_layer.finish()
	_layer.begin(1.0)
	_layer.field(&"fire", Vector3.ZERO, 1.6, 1.0, 0.0, 4, true)
	var foe: float = _layer._light_wants[0][2]
	_layer.finish()
	assert_almost_eq(hero, foe * VfxPackViews.FIRE_LIGHT, 0.001)


func test_patch_caps_scale_with_the_effects_density() -> void:
	assert_eq(AttackFormView.patch_caps("high"), [5, 8])
	assert_eq(AttackFormView.patch_caps("medium"), [4, 6])
	assert_eq(AttackFormView.patch_caps("low"), [3, 4])


func test_at_most_patch_max_fire_patches_draw_the_newest_and_the_older_faded() -> void:
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"gun"))
	t.crit_chance_permille = 0
	var w := World.new(9, t)
	w.dummy_speed = 0.0
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	Abilities.grant_start(w)
	w.add_item(AttackScenario.item_index(w.item_tables, &"ember_core"))
	Abilities.start_floor(w)
	w.add_dummy(Vector2(2.5, 0), 0.35, 4)
	var view: AttackFormView = add_child_autofree(AttackFormView.new())
	var r := WorldReader.new(w)
	for k in 90:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, InputFrame.SHOOT, 0))
		if not w.ab.fire_pos.is_empty():
			break
	assert_eq(w.ab.fire_pos.size(), 1, "a kill left one patch with a spec")
	var key: String = w.ab.fire_spec[0]
	var end: int = w.ab.fire_end[0]
	for k in 11:  # eleven more (the sim's cap allows them: a busy Fire fight)
		ElementAbilities.add_fire(w, Vector2(k * 3.0, 6.0), 1.2, end, 1, 1, 0)
		w.ab.fire_spec[w.ab.fire_spec.size() - 1] = key
	var n := w.ab.fire_pos.size()
	view.sync(r)
	var zones: Array = view._live_forms.filter(
		func(f: Dictionary) -> bool: return f["kind"] == &"zone"
	)
	assert_eq(zones.size(), mini(n, AttackFormView.PATCH_MAX), "at most PATCH_MAX drawn")
	var newest: Dictionary = zones[zones.size() - 1]
	assert_eq(newest["pos"], w.ab.fire_pos[n - 1], "the newest is among them")
	var faded := zones.filter(
		func(f: Dictionary) -> bool: return float(f["fade"]) <= AttackFormView.PATCH_DIM + 0.001
	)
	assert_eq(
		faded.size(), AttackFormView.PATCH_MAX - AttackFormView.PATCH_FULL, "the older ones faded"
	)
	assert_eq(w.ab.fire_pos.size(), n, "the sim's patches untouched")
	ViewPrefs.effects_density = "low"
	view.sync(r)
	zones = view._live_forms.filter(func(f: Dictionary) -> bool: return f["kind"] == &"zone")
	assert_eq(zones.size(), 4, "fewer at Low")


# --- F8: Chain Blast sized by its damage --------------------------------------------------------------------------
## A second of the hero's direct hits: `n` hits of `dmg`, ending at tick 59.
func _hits(b: BlastLook, n: int, dmg: int) -> void:
	for k in n:
		b.note(59 - k * (59 / maxi(1, n)), dmg, Vector2(5, 5), false)


func test_a_blast_grows_with_its_damage() -> void:
	var b := BlastLook.new()
	_hits(b, 6, 10)  # a fast Gun: 60 a second
	b.note(59, 6, Vector2(1, 0), true)  # Chain Blast's 0.6 of a 10
	var light := b.weight(59, Vector2.ZERO, 1.4)
	var c := BlastLook.new()
	_hits(c, 1, 60)  # a slow heavy hit: the same 60 a second in one shot
	c.note(59, 36, Vector2(1, 0), true)
	var heavy := c.weight(59, Vector2.ZERO, 1.4)
	assert_almost_eq(light, 0.4, 0.001)
	assert_eq(heavy, 1.0, "a heavy hit's blast is the full one")
	assert_lt(BlastLook.radius_k(light), BlastLook.radius_k(heavy))
	assert_eq(BlastLook.radius_k(1.0), 1.0, "at most the sim's radius")
	assert_eq(BlastLook.radius_k(0.0), BlastLook.MIN_R)


func test_a_blast_that_hit_nothing_reads_its_trigger_hit() -> void:
	var b := BlastLook.new()
	_hits(b, 6, 10)
	assert_almost_eq(b.weight(59, Vector2(5, 5), 1.4), 0.4, 0.001, "0.6 of the 10 that set it off")


func test_the_view_draws_a_light_blast_small_and_a_heavy_one_full() -> void:
	var view: AttackFormView = add_child_autofree(AttackFormView.new())
	var look := {"radius": 1.4}
	_hits(view.blasts, 6, 10)
	view.blasts.note(59, 6, Vector2(1, 0), true)
	var small := view._blast_look(look, Vector2.ZERO, 59)
	assert_almost_eq(float(small["radius"]), 1.4 * BlastLook.radius_k(0.4), 0.001)
	assert_almost_eq(float(small["w"]), 0.4, 0.001)
	assert_eq(float(look["radius"]), 1.4, "the cached look is not changed")
	view.blasts.note(59, 200, Vector2(9, 0), true)
	var big := view._blast_look(look, Vector2(9, 0), 59)
	assert_almost_eq(float(big["radius"]), 1.4, 0.001, "a heavy one at the sim's radius")


func test_a_burst_of_blasts_keeps_to_the_seconds_budget() -> void:
	var b := BlastLook.new()
	var full := 0
	var shown := 0
	for k in 30:  # thirty blasts in one second (Seekers + Split + Chain Blast), spread over the room
		var a := b.admit(k * 2, Vector2(k % 6, k / 6) * 2.0, "high")
		if a != BlastLook.NONE:
			shown += 1
		if a == BlastLook.FULL:
			full += 1
	assert_eq(full, BlastLook.FULL_PER_S, "at most FULL_PER_S at their weight")
	assert_lte(shown, BlastLook.MAX_PER_S, "at most MAX_PER_S drawn in the second")
	assert_eq(b.drawn, shown)
	var low := BlastLook.new()
	var low_shown := 0
	for k in 30:
		if low.admit(k * 2, Vector2(k % 6, k / 6) * 2.0, "low") != BlastLook.NONE:
			low_shown += 1
	assert_lt(low_shown, shown, "fewer at Low")


func test_blasts_on_one_spot_past_the_full_ones_merge() -> void:
	var b := BlastLook.new()
	for k in BlastLook.FULL_PER_S:
		assert_eq(b.admit(k, Vector2.ZERO, "high"), BlastLook.FULL)
	assert_eq(
		b.admit(5, Vector2(0.5, 0), "high"), BlastLook.NONE, "merged into the one drawn there"
	)
	assert_eq(b.admit(6, Vector2(8, 0), "high"), BlastLook.POP, "one elsewhere is a small pop")
	assert_eq(
		b.admit(70, Vector2.ZERO, "high"), BlastLook.FULL, "a second later the budget is back"
	)


func test_a_light_blast_draws_no_light_and_a_full_one_does() -> void:
	_layer.begin(0.0)
	_layer.burst(&"fire", Vector3.ZERO, 1.4, 0.1, 3, 0.2)
	var pop := _layer._light_wants.size()
	_layer.finish()
	_layer.begin(1.0)
	_layer.burst(&"fire", Vector3(20, 0, 0), 1.4, 0.1, 4, 1.0)
	var full := _layer._light_wants.size()
	_layer.finish()
	assert_eq(pop, 0, "a small pop has no light")
	assert_gt(full, 0)
