extends GutTest
## v0.10.0 VX1 (VFX_PACK R10, R11, R14-R17, R43): hits, impacts, sparks and flashes are the pack's scenes. Each replaced
## effect spawns its pack id once (not once per frame) in the element's colours; a full family draws the old look for
## that instance; the old look stays without a pack; the death pop adds to the chunks.

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


func _ids() -> Array:
	var out: Array = []
	for l: Dictionary in _fx._live:
		out.append(l["id"])
	return out


func _node(id: StringName) -> Node3D:
	for l: Dictionary in _fx._live:
		if l["id"] == id:
			return l["node"]
	return null


func _fill(family: StringName, id: StringName) -> void:
	while _fx.has_room(family):
		_fx.spawn(id, Vector3(50, 0, 50))


func test_the_vx1_table_names_every_id_the_code_uses() -> void:
	var all: Array = [
		HitPack.HIT_PLAIN,
		HitPack.IMPACT_OTHER,
		HitPack.SLASH,
		HitPack.GUARD,
		HitPack.WEAK,
		HitPack.DEFLECT,
		HitPack.MUZZLE_NEUTRAL,
		HitPack.FLASH_BIG,
	]
	all.append_array(HitPack.HIT_IDS.values())
	all.append_array(HitPack.MUZZLE_IDS.values())
	all.append_array(HitPack.IMPACT_IDS.values())
	for id: StringName in all:
		assert_true(_fx.has_id(id), String(id))


func test_a_bolt_impact_spawns_the_elements_hit_once() -> void:
	var want := {
		&"fire": &"vx1_hit_ember",
		&"frost": &"vx1_hit_frost",
		&"storm": &"vx1_hit_storm",
		&"venom": &"vx1_hit_venom",
		&"bleed": &"vx1_hit_bleed",
		&"": &"vx1_hit_plain",
	}
	var sd := 100
	for kind: StringName in want:
		sd += 1
		for k in 6:  # six frames of one impact
			assert_true(HitPack.hit(_layer, kind, Vector3.ZERO, k / 10.0, sd, 1.0))
		assert_eq(_ids().count(want[kind]), 1, "%s: one scene, not one per frame" % kind)
	assert_eq(_fx.spawned, want.size())


func test_the_hit_is_recoloured_to_the_element() -> void:
	HitPack.hit(_layer, &"storm", Vector3.ZERO, 0.0, 1, 1.0)
	var node := _node(&"vx1_hit_storm")
	assert_not_null(node)
	var want := {
		&"primary_color": ElementLooks.core(&"storm"),
		&"secondary_color": ElementLooks.hot(&"storm"),
		&"tertiary_color": ElementLooks.deep(&"storm"),
	}
	var seen := 0
	for key: StringName in want:
		if key in node:
			seen += 1
			assert_eq(node.get(key), want[key], String(key))
	assert_gt(seen, 0, "the scene has colour parameters")


func test_a_heavy_hit_is_an_impact_scene_per_element() -> void:
	HitPack.hit(_layer, &"fire", Vector3.ZERO, 0.0, 1, 1.3)
	HitPack.hit(_layer, &"", Vector3.ZERO, 0.0, 2, 1.3)
	HitPack.hit(_layer, &"frost", Vector3.ZERO, 0.0, 3, 1.3)
	HitPack.hit(_layer, &"venom", Vector3.ZERO, 0.0, 4, 1.3)
	assert_eq(_ids().count(&"vx1_impact_ember"), 2, "ember and plain")
	assert_eq(_ids().count(&"vx1_impact_frost"), 1)
	assert_eq(_ids().count(&"vx1_impact_other"), 1)
	assert_eq(_fx.live_count(&"impact"), 4)
	assert_eq(_fx.live_count(&"hit"), 0)


func test_a_slash_is_turned_to_the_cut_and_a_finisher_adds_the_impact() -> void:
	var tan := Vector3(0, 0, -1)
	HitPack.slash(_layer, &"", Vector3.ZERO, tan, 0.0, 1, 1.1)
	var node := _node(HitPack.SLASH)
	assert_not_null(node)
	assert_almost_eq(node.rotation.y, HitPack.yaw_of(tan), 0.001)
	assert_eq(_fx.live_count(&"impact"), 0, "a plain slash: no impact")
	HitPack.slash(_layer, &"fire", Vector3(5, 0, 0), Vector3.RIGHT, 0.0, 2, 1.43)
	assert_eq(_fx.live_count(&"impact"), 1, "the finisher adds it")


func test_a_full_family_draws_the_old_look_for_that_instance() -> void:
	_fill(&"hit", &"vx1_hit_plain")
	var n := _fx.spawned
	for k in 4:
		assert_false(
			HitPack.hit(_layer, &"fire", Vector3.ZERO, k / 10.0, 9, 1.0), "old look every frame"
		)
	assert_eq(_fx.spawned, n, "nothing spawned, nothing evicted")
	assert_false(HitPack.slash(_layer, &"", Vector3.ZERO, Vector3.RIGHT, 0.0, 10, 1.0))
	var white := Color.WHITE
	assert_false(HitPack.muzzle(_layer, Vector3.ZERO, Vector3.RIGHT, white, white, 0.0, 11))
	assert_false(HitPack.spark(_fx, HitPack.GUARD, Vector3.ZERO, 0.5, white))
	_fill(&"impact", &"vx1_impact_other")
	assert_false(HitPack.flash(_layer, Vector3.ZERO, white, white, 0.0, 1.2, 12))


func test_without_a_pack_the_old_look_draws() -> void:
	_layer.pack_fx = null
	assert_false(HitPack.hit(_layer, &"fire", Vector3.ZERO, 0.0, 1, 1.0))
	assert_false(HitPack.flash(_layer, Vector3.ZERO, Color.WHITE, Color.WHITE, 0.0, 1.2, 2))
	assert_eq(_fx.spawned, 0)


func test_the_same_seed_coming_again_is_a_new_impact() -> void:
	HitPack.hit(_layer, &"fire", Vector3.ZERO, 0.8, 5, 1.0)
	HitPack.hit(_layer, &"fire", Vector3.ZERO, 0.1, 5, 1.0)  # u went back: a Lance wall, a rune slot
	assert_eq(_fx.spawned, 2)


func test_the_muzzle_spark_is_the_elements_short_flash() -> void:
	var want := {
		&"ember": &"vx1_muzzle_01",
		&"storm": &"vx1_muzzle_02",
		&"frost": &"vx1_muzzle_03",
		&"venom": &"vx1_muzzle_04",
		&"bleed": &"vx1_muzzle_06",
	}
	var sd := 0
	for e: StringName in want:
		sd += 1
		for k in 3:
			var hot := ElementLooks.hot(e)
			HitPack.muzzle(
				_layer, Vector3.ZERO, Vector3.RIGHT, hot, ElementLooks.core(e), k / 6.0, sd
			)
		assert_eq(_ids().count(want[e]), 1, String(e))
	HitPack.muzzle(_layer, Vector3.ZERO, Vector3.RIGHT, Color.WHITE, Color(0.2, 0.5, 1.0), 0.0, 99)
	assert_eq(_ids().count(&"vx1_muzzle_05"), 1, "no element: the neutral base")
	var node := _node(&"vx1_muzzle_05")
	assert_almost_eq(node.rotation.y, 0.0, 0.001, "turned along the aim (+X)")


func test_hero_fx_muzzle_and_flash_go_through_the_pack() -> void:
	_layer.begin(0.0)
	var ember := ElementLooks.core(&"ember")
	HeroFx.muzzle(_layer, Vector3.ZERO, Vector3.RIGHT, Color.WHITE, ember, 0.1, 3)
	HeroFx.muzzle(_layer, Vector3.ZERO, Vector3.RIGHT, Color.WHITE, ember, 0.3, 3)
	assert_eq(_ids(), [&"vx1_muzzle_01"])
	HeroFx.flash(_layer, Vector3.ZERO, Color.WHITE, Color.CYAN, 0.1, 1.2, 4)
	HeroFx.flash(_layer, Vector3.ZERO, Color.WHITE, Color.CYAN, 0.2, 1.2, 4)
	assert_eq(_ids().count(&"vx1_flash_big"), 1, "a heavy flash is one scene")
	var before := _fx.spawned
	HeroFx.flash(_layer, Vector3.ZERO, Color.WHITE, Color.CYAN, 0.1, 0.7, 5)
	assert_eq(_fx.spawned, before, "a small flash keeps the old sprites")
	_layer.finish()


func test_hero_fx_impact_goes_through_the_pack_for_the_lance_and_the_laser() -> void:
	_layer.begin(0.0)
	HeroFx.impact(_layer, &"frost", Vector3.ZERO, Vector3.RIGHT, 0.2, 6)
	HeroFx.impact(_layer, &"frost", Vector3.ZERO, Vector3.RIGHT, 0.4, 6)
	assert_eq(_ids(), [&"vx1_hit_frost"])
	_layer.finish()


func test_the_impact_fx_draws_a_bolt_as_the_pack_scene_and_keeps_its_sparks() -> void:
	var fx := ImpactFx.new()
	var hero := ImpactFx.HERO
	fx.add(Vector3.ZERO, Vector3.RIGHT, Vector3(1, 0, 0), hero, 0, 1.0, ImpactFx.BOLT, &"fire")
	fx.add(Vector3(6, 0, 0), Vector3.RIGHT, Vector3(7, 0, 0), hero, 0, 1.43, ImpactFx.SLASH, &"")
	_layer.begin(2.0)
	fx.draw(_layer)
	_layer.finish()
	assert_eq(_ids().count(&"vx1_hit_ember"), 1)
	assert_eq(_ids().count(HitPack.SLASH), 1)
	assert_eq(_ids().count(&"vx1_impact_ember"), 1, "the finisher slash adds an impact")
	assert_gt(fx.last_pieces, 0, "the sparks and the spray stay")
	_layer.begin(3.0)
	fx.draw(_layer)
	_layer.finish()
	assert_eq(_fx.spawned, 3, "not one per frame")
	var area := ImpactFx.new()  # an area hit keeps its old flash
	area.add(
		Vector3(20, 0, 0), Vector3.RIGHT, Vector3(21, 0, 0), hero, 0, 0.45, ImpactFx.OTHER, &""
	)
	_layer.begin(2.0)
	area.draw(_layer)
	_layer.finish()
	assert_eq(_fx.spawned, 3, "an area hit is not the pack's")


func test_the_impact_fx_keeps_the_old_look_when_the_family_is_full() -> void:
	_fill(&"hit", &"vx1_hit_plain")
	var fx := ImpactFx.new()
	fx.add(Vector3.ZERO, Vector3.RIGHT, Vector3(1, 0, 0), ImpactFx.HERO, 0, 1.0, ImpactFx.BOLT, &"")
	var n := _fx.spawned
	_layer.begin(2.0)
	fx.draw(_layer)
	_layer.finish()
	assert_eq(_fx.spawned, n)
	assert_gt(fx.last_pieces, 4, "the old flash and its pieces draw")


func test_hit_feel_sparks_are_pack_scenes_with_a_box_fallback() -> void:
	var feel := HitFeel.new(null, null)
	add_child_autofree(feel)
	feel.pack_fx = _fx
	feel._spark(HitPack.GUARD, Vector2.ZERO, Color(0.85, 0.9, 1.0), 0.5, 4, 0.08)
	feel._spark(HitPack.WEAK, Vector2.ZERO, Color(1, 0.9, 0.5), 0.7, 6, 0.09)
	feel._spark(HitPack.DEFLECT, Vector2.ZERO, HitFeel.DEFLECT_COLOR, 0.45, 3, 0.06)
	assert_eq(_ids(), [&"vx1_guard", &"vx1_weak", &"vx1_deflect"])
	assert_eq(feel.spark_count(), 0, "no boxes")
	_fill(&"hit", &"vx1_hit_plain")
	feel._spark(HitPack.GUARD, Vector2.ZERO, Color.WHITE, 0.5, 4, 0.08)
	assert_eq(feel.spark_count(), 4, "the family is full: the boxes")
	feel.pack_fx = null
	feel._spark(HitPack.GUARD, Vector2.ZERO, Color.WHITE, 0.5, 4, 0.08)
	assert_eq(feel.spark_count(), 8, "no pack: the boxes")


## v0.10.0 FX (owner: no death explosions or smoke): a kill is the lit chunks alone, no pack effect.
func test_a_death_is_the_chunks_alone() -> void:
	var feel := HitFeel.new(null, null)
	add_child_autofree(feel)
	feel.pack_fx = _fx
	feel._burst(Vector2.ZERO, ThemePalette.color(&"enemy_body"), HitFeel.SHARDS, 0.16, true)
	assert_eq(feel.spark_count(), HitFeel.SHARDS, "the chunks")
	assert_false(_fx.has_id(&"vx1_death_smoke"), "the death smoke is gone from the table")
	assert_false(_fx.has_id(&"vx1_death_pop"), "and the death flash")


func test_the_cast_spark_at_the_hand_is_a_pack_flash_on_every_shot() -> void:
	var cast := HeroCastFx.new()
	add_child_autofree(cast)
	cast.pack_fx = _fx
	assert_true(cast._pack_spark(Vector3.ZERO, Vector2.RIGHT))
	assert_eq(_ids(), [&"vx1_muzzle_05"])
	_fill(&"hit", &"vx1_hit_plain")
	assert_false(cast._pack_spark(Vector3.ZERO, Vector2.RIGHT), "full: the old spark")
	cast.pack_fx = null
	assert_false(cast._pack_spark(Vector3.ZERO, Vector2.RIGHT))


func test_a_released_scene_returns_to_its_pool() -> void:
	HitPack.hit(_layer, &"fire", Vector3.ZERO, 0.0, 1, 1.0)
	var node := _node(&"vx1_hit_ember")
	_fx.release(node)
	assert_eq(_fx.live_count(&"hit"), 0)
	assert_eq(_fx.pooled(&"vx1_hit_ember"), 1)
